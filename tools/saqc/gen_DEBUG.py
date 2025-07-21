import inspect
import re
import sys
from copy import deepcopy
from typing import (
    get_args,
    get_origin,
    Any,
    Callable,
    Dict,
    ForwardRef,
    Literal,
    Optional,
    Sequence,
    Tuple,
    TYPE_CHECKING,
    Union,
)
import argparse
import math
import xml.etree.ElementTree as ET


from galaxyxml.tool import Tool
from galaxyxml.tool.parameters import (
    BooleanParam,
    Conditional,
    Configfiles,
    ConfigfileDefaultInputs,
    DataParam,
    DiscoverDatasets,
    IntegerParam,
    FloatParam,
    HiddenParam,
    Inputs,
    OutputCollection,
    OutputData,
    Outputs,
    Repeat,
    SelectParam,
    TextParam,
    ValidatorParam,
    When,
)
import matplotlib as mpl
import numpy as np
import pandas as pd
import saqc
from saqc.core import SaQC, DictOfSeries
from saqc.funcs.curvefit import FILL_METHODS
from saqc.funcs.drift import LinkageString
from saqc.funcs.generic import GenericFunction
from saqc.funcs.resampling import *
from saqc.lib.types import CurveFitter
from typing_inspect import is_callable_type, is_union_type


if TYPE_CHECKING:
    from types import ModuleType

def _get_doc(doc_str: Optional[str]) -> str:
    if not doc_str:
        return ""
    doc_str = str(doc_str)
    doc_str_lines = [x for x in doc_str.split("\n") if x.strip() != ""]
    if not doc_str_lines:
        return ""
    doc_str = doc_str_lines[0]
    doc_str = doc_str.strip(" .,").replace(':py:attr:', '').replace('&#10;', ' ').replace('<', ' ').replace('>', ' ').replace('"', ' ')

    return doc_str


def parse_docstring(method: Callable) -> Dict[str, str]:
    """
    parse sections from rst formatted doc string

    returns a mapping from section titles to section contents
    1st section title may be ''
    """

    docstring = method.__doc__
    if not docstring:
        return {}

    sections = {}
    section_pattern = r"^([^\S\n]*)(?P<title>\S.*?)(\n\1([=-])+\n)"
    section_matches = list(re.finditer(section_pattern, docstring, re.MULTILINE))

    end = 0
    title_key = ""
    first_section_processed_by_title = False
    start_index_of_first_match = -1


    for i, match in enumerate(section_matches):
        if i == 0:
            start_index_of_first_match = match.start()
            if match.start() > 0:
                sections[""] = docstring[:match.start()].strip()
                first_section_processed_by_title = True

        if title_key or (i == 0 and not first_section_processed_by_title and match.start() == 0) :
             if title_key or "" not in sections or (i==0 and match.start()==0) :
                sections[title_key] = docstring[end:match.start()].strip()

        title_key = match.group("title").strip()
        end = match.end()
        if i==0 : first_section_processed_by_title = True

    if title_key or (not sections and docstring):
        sections[title_key] = docstring[end:].strip()
    elif not sections and not docstring:
        return {}

    return {k:v for k,v in sections.items() if v or k==""}


def parse_parameter_docs(sections: Dict[str, str]) -> Dict[str, str]:
    parameter_doc = {}
    parameters_text = sections.get("Parameters", "")
    if not parameters_text:
        return parameter_doc

    current_param = None
    current_lines = []
    param_start_pattern = re.compile(r"^(?P<param_name>[a-zA-Z_][a-zA-Z0-9_]*)\s*(:.*)?")

    for line in parameters_text.splitlines():
        original_line_stripped = line.strip()

        match = None
        if not line.startswith("    ") and not line.startswith("\t\t"):
            match = param_start_pattern.match(original_line_stripped)

        if match:
            if current_param:
                parameter_doc[current_param] = "\n".join(current_lines).strip()

            current_param = match.group("param_name")
            current_lines = [original_line_stripped] 
        elif current_param:
            if line.startswith("    ") or line.startswith("\t\t") or not param_start_pattern.match(original_line_stripped):
                 current_lines.append(original_line_stripped)
            else:
                if current_param:
                    parameter_doc[current_param] = "\n".join(current_lines).strip()
                new_match = param_start_pattern.match(original_line_stripped)
                if new_match:
                    current_param = new_match.group("param_name")
                    current_lines = [original_line_stripped]
                else:
                    current_param = None
                    current_lines = []


    if current_param:
        parameter_doc[current_param] = "\n".join(current_lines).strip()

    for pname, pdoc in parameter_doc.items():
        lines = pdoc.split('\n')
        if lines:
            first_line = lines[0]
            cleaned_first_line = re.sub(r"^\s*{}\s*:\s*[^-\n]+?\s*--\s*".format(re.escape(pname)), "", first_line, count=1).strip()
            if first_line.strip() == cleaned_first_line and ":" in first_line:
                 cleaned_first_line = re.sub(r"^\s*{}\s*:\s*".format(re.escape(pname)), "", first_line, count=1).strip()

            if cleaned_first_line.startswith(pname):
                cleaned_first_line = re.sub(r"^\s*{}".format(re.escape(pname)),"", cleaned_first_line, count=1).strip()

            lines[0] = cleaned_first_line
            parameter_doc[pname] = "\n".join(l.strip() for l in lines if l.strip() or l == "").strip()

    return parameter_doc


def get_label_help(param_name, parameter_docs):
    """
    Extrahiert Label und Hilfetext aus der Parameter-Dokumentation.
    Das Label wird der erste Satz der Doku.
    Der Hilfetext ist der Rest der Doku ohne den ersten Satz.
    FALLS es nur einen Satz gibt, wird dieser auch als Hilfetext verwendet.
    """
    parameter_doc_entry = parameter_docs.get(param_name)
    full_help = parameter_doc_entry.strip() if parameter_doc_entry else ""

    if not full_help:
        return param_name, ""

    label = param_name
    remaining_help = full_help
    sentence_match = re.match(r"([^.!?]+(?:[.!?](?=\s|$)|[.!?]$|$))", full_help)

    label_candidate = ""
    if sentence_match:
        label_candidate = sentence_match.group(1).strip()

    is_bad_label = False
    if not label_candidate or '|' in label_candidate or '[' in label_candidate or not label_candidate[0].isupper() or ' ' not in label_candidate or len(label_candidate) > 80:
        is_bad_label = True

    if not is_bad_label and label_candidate:
        label = label_candidate

        if full_help.startswith(label_candidate):
            remaining_help = full_help[len(label_candidate):].strip()
            remaining_help = remaining_help.lstrip('.\n\r').strip()

        if not remaining_help:
            remaining_help = full_help

    label = label.replace('\n', ' ').replace('&#10;', ' ').replace(':py:attr:', '').removesuffix('.').strip()
    remaining_help = remaining_help.replace('\n', ' ').replace('&#10;', ' ').replace(':py:attr:', '').removesuffix('.').strip()

    label = label.replace('<', ' ').replace('>', ' ').replace('"', ' ')
    remaining_help = remaining_help.replace('<', ' ').replace('>', ' ').replace('"', ' ')

    return label, remaining_help

def get_modules() -> list[Tuple[str, "ModuleType"]]:
    return inspect.getmembers(saqc.funcs, inspect.ismodule)


def get_methods(module):
    methods_with_saqc = []
    classes = inspect.getmembers(module, inspect.isclass)
    for name, cls in classes:
        if inspect.ismodule(cls):
            continue
        methods = inspect.getmembers(cls, inspect.isfunction)
        for method_name, method in methods:
            try:
                parameters = inspect.signature(method).parameters
                if "self" in parameters:
                    self_param = parameters["self"]
                    annotation_str = None
                    if isinstance(self_param.annotation, str):
                         annotation_str = self_param.annotation.strip("'")
                    elif isinstance(self_param.annotation, ForwardRef):
                         annotation_str = self_param.annotation.__forward_arg__.strip("'")
                    elif hasattr(self_param.annotation, '__name__'):
                         annotation_str = self_param.annotation.__name__

                    if annotation_str == 'SaQC':
                         methods_with_saqc.append(method)
            except (ValueError, TypeError) as e:
                 sys.stderr.write(f"Warning: Could not inspect signature for {cls.__name__}.{method_name}: {e}\n")
                 continue
    return methods_with_saqc


def get_method_params(method, module):
    sections = parse_docstring(method)
    param_docs = parse_parameter_docs(sections)

    xml_params = []
    try:
        parameters = inspect.signature(method).parameters
    except (ValueError, TypeError) as e:
         sys.stderr.write(f"Warning: Could not get signature for {method.__name__}: {e}. Skipping params for this method.\n")
         return xml_params

    # NEU: Hilfsfunktion, die den Debug-Text an den Help-String anhängt
    def add_debug_info_to_help(kwargs, trace_list):
        new_kwargs = kwargs.copy()
        debug_string = " | DEBUG PATH: " + " -> ".join(trace_list)
        new_kwargs['help'] = new_kwargs.get('help', '') + debug_string
        return new_kwargs

    for param_name, param in parameters.items():
        if param_name in ["self", "kwargs", "store_kwargs", "ax_kwargs"]:
            continue
        
        # NEU: Initialisierung des Pfad-Trackers
        path_trace = [f"Param: '{param_name}'", f"Annotation: '{param.annotation}'"]
        
        annotation = param.annotation

        if isinstance(annotation, str):
             try:
                 eval_context = {**globals(), **module.__dict__, **saqc.__dict__, **saqc.lib.types.__dict__, **saqc.funcs.__dict__}
                 eval_context.update({'pd': pd, 'np': np, 'mpl': mpl, 'Union': Union, 'Literal': Literal, 'Sequence': Sequence, 'Callable': Callable, 'Any': Any, 'Tuple': Tuple, 'Dict': Dict})
                 for m_name, m_obj in inspect.getmembers(saqc.funcs, inspect.ismodule):
                     eval_context[m_name] = m_obj
                 annotation = eval(annotation, eval_context)
             except Exception:
                 sys.stderr.write(f"Warning: Could not evaluate annotation string '{param.annotation}' for param '{param_name}' in method '{method.__name__}'. Treating as Any.\n")
                 annotation = Any
        elif isinstance(annotation, ForwardRef):
             try:
                 eval_context = {**globals(), **module.__dict__, **saqc.__dict__, **saqc.lib.types.__dict__, **saqc.funcs.__dict__}
                 eval_context.update({'pd': pd, 'np': np, 'mpl': mpl, 'Union': Union, 'Literal': Literal, 'Sequence': Sequence, 'Callable': Callable, 'Any': Any, 'Tuple': Tuple, 'Dict': Dict})
                 for m_name, m_obj in inspect.getmembers(saqc.funcs, inspect.ismodule):
                     eval_context[m_name] = m_obj
                 annotation = annotation._evaluate(eval_context, locals(), frozenset())
             except Exception:
                 sys.stderr.write(f"Warning: Could not evaluate ForwardRef '{param.annotation.__forward_arg__}' for param '{param_name}' in method '{method.__name__}'. Treating as Any.\n")
                 annotation = Any

        if annotation is inspect.Parameter.empty:
             sys.stderr.write(f"Warning: Missing type annotation for parameter '{param_name}' in method '{method.__name__}'. Treating as Any.\n")
             annotation = Any

        if isinstance(annotation, str):
             sys.stderr.write(f"Warning: Annotation '{annotation}' for parameter '{param_name}' in method '{method.__name__}' resolved to a string. Treating as Any.\n")
             annotation = Any

        origin = get_origin(annotation)
        args = get_args(annotation)
        default = param.default if param.default is not inspect.Parameter.empty else None
        label, help_text = get_label_help(param_name, param_docs)
        param_constructor_args = {"label": label, "help": help_text}

        is_python_optional = (param.default is not inspect.Parameter.empty)
        is_union_with_none = is_union_type(annotation) and type(None) in args
        optional = is_python_optional or is_union_with_none
        param_constructor_args['optional'] = optional
        param_constructor_args['require_non_empty'] = not optional

        has_explicit_value_for_xml = False
        if param.default is not inspect.Parameter.empty and param.default is not None:
            if not isinstance(param.default, bool):
                 param_constructor_args['value'] = str(param.default)
                 has_explicit_value_for_xml = True

        if not optional and not has_explicit_value_for_xml:
            param_constructor_args['value'] = ""

        if is_union_with_none:
            path_trace.append("is_union_with_none")
            args_wo_none = [a for a in args if a is not type(None)]
            if len(args_wo_none) == 1:
                annotation = args_wo_none[0]
                origin = get_origin(annotation)
                args = get_args(annotation)
            elif len(args_wo_none) > 1:
                 annotation = Union[tuple(args_wo_none)]
                 origin = get_origin(annotation)
                 args = get_args(annotation)
            else:
                 annotation = Any
                 origin = None
                 args = ()

        if param_name in ["field", "target"]:
            path_trace.append("is_field_or_target")
            is_multi = False
            if origin in (list, Sequence) and args and args[0] == str:
                is_multi = True
            elif annotation == list[str] or annotation == Sequence[str]:
                is_multi = True
            if is_multi:
                path_trace.append("is_multi_repeat")
                parent = Repeat(name=f"{param_name}_repeat", title=f"{param_name.capitalize()}(s)", min=1)
                inner_param_attrs = {
                    "label": f"Name for {param_name}",
                    "help": "Name of the variable to process.",
                    "optional": False,
                    "value": ""
                }
                parent.append(TextParam(argument=param_name, **add_debug_info_to_help(inner_param_attrs, path_trace)))
                xml_params.append(parent)

            elif annotation == str:
                path_trace.append("is_single_str")
                single_param_attrs = {
                    "label": param_name.capitalize(),
                    "help": "The name of the variable to process.",
                    "optional": optional,
                    "value": "" if not optional else None,
                    "require_non_empty": not optional
                }
                if 'value' in param_constructor_args and param_constructor_args['value'] is not None:
                    single_param_attrs['value'] = param_constructor_args['value']
                xml_params.append(TextParam(argument=param_name, **add_debug_info_to_help(single_param_attrs, path_trace)))
            else:
                path_trace.append("fallback_as_text")
                sys.stderr.write(f"Warning: Parameter '{param_name}' expected str or List[str], got {annotation}. Treating as TextParam.\n")
                fallback_attrs = {
                    "label": param_name.capitalize(),
                    "help": "The name of the variable to process.",
                    "optional": optional,
                    "value": "" if not optional else None,
                    "require_non_empty": not optional
                }
                xml_params.append(TextParam(argument=param_name, **add_debug_info_to_help(fallback_attrs, path_trace)))
            continue


        if origin is None and not is_union_type(annotation) :
            path_trace.append("is_simple_type")
            if annotation == bool:
                path_trace.append("type_is_bool")
                bool_attrs = {k:v for k,v in param_constructor_args.items() if k != 'value'}
                bool_attrs['checked'] = True if param.default is True else False
                xml_params.append(BooleanParam(argument=param_name, **add_debug_info_to_help(bool_attrs, path_trace)))
            elif annotation == str:
                path_trace.append("type_is_str")
                xml_params.append(TextParam(argument=param_name, **add_debug_info_to_help(param_constructor_args, path_trace)))
            elif annotation == int:
                path_trace.append("type_is_int")
                xml_params.append(IntegerParam(argument=param_name, **add_debug_info_to_help(param_constructor_args, path_trace)))
            elif annotation == float:
                path_trace.append("type_is_float")
                xml_params.append(FloatParam(argument=param_name, **add_debug_info_to_help(param_constructor_args, path_trace)))
            elif is_callable_type(annotation) or annotation in (GenericFunction, CurveFitter, Any, slice, mpl.axes.Axes):
                path_trace.append("type_is_callable_or_special")
                current_callable_attrs = param_constructor_args.copy()
                if is_callable_type(annotation):
                    callable_args_repr = str(get_args(annotation)) if hasattr(annotation, '__args__') else '(...)'
                    help_suffix = f" (Expects a function reference: {callable_args_repr}."
                    if param.default is not inspect.Parameter.empty and param.default is not None:
                        help_suffix += f" Default: {param.default})"
                    else:
                        help_suffix += ")"
                    current_callable_attrs["help"] += help_suffix
                if not isinstance(param.default, str) or param.default is inspect.Parameter.empty:
                    if not current_callable_attrs.get('optional', False):
                            current_callable_attrs['value'] = ""
                    elif 'value' in current_callable_attrs :
                            del current_callable_attrs['value']
                xml_params.append(TextParam(argument=param_name, **add_debug_info_to_help(current_callable_attrs, path_trace)))
            elif hasattr(annotation, '__mro__') and pd.Timedelta in annotation.__mro__:
                path_trace.append("type_is_timedelta_string")
                param_constructor_args["help"] += " (Pandas timedelta string, e.g., '1D', '2H30M')"
                xml_params.append(TextParam(argument=param_name, **add_debug_info_to_help(param_constructor_args, path_trace)))
            else:
                path_trace.append("type_is_unknown_simple_fallback_text")
                xml_params.append(TextParam(argument=param_name, **add_debug_info_to_help(param_constructor_args, path_trace)))

        elif origin is Union and str in args and pd.Timedelta in args:
             path_trace.append("is_union_str_timedelta")
             param_constructor_args["help"] += " (Pandas timedelta string or offset, e.g., '1D', '2H30M')"
             xml_params.append(TextParam(argument=param_name, **add_debug_info_to_help(param_constructor_args, path_trace)))

        elif origin is Union and all(el_type in args for el_type in (str, Tuple[str,str])) and len(args)==2 :
            path_trace.append("is_union_str_tuplestr")
            param_constructor_args["help"] += " (String or two comma-separated strings, e.g., val1,val2)"
            xml_params.append(TextParam(argument=param_name, **add_debug_info_to_help(param_constructor_args, path_trace)))

        elif origin is Union and all(el_type in args for el_type in (int, Tuple[int,int])) and len(args)==2 :
            path_trace.append("is_union_int_tupleint")
            param_constructor_args["help"] += " (Integer or two comma-separated integers, e.g., 1,2)"
            xml_params.append(TextParam(argument=param_name, **add_debug_info_to_help(param_constructor_args, path_trace)))

        elif origin is Union and int in args and str in args and param_name in ["limit", "window"]:
            path_trace.append("is_union_int_str_conditional")
            cond = Conditional(name=f"{param_name}_cond")
            select_param_name = f"{param_name}_select_type"
            cond_options = {"number": "Number", "timedelta": "Timedelta"}
            if optional: cond_options["none"] = "None (use default)"
            select_default_choice = None
            if isinstance(param.default, int): select_default_choice = 'number'
            elif isinstance(param.default, str): select_default_choice = 'timedelta'
            elif optional and param.default is None: select_default_choice = 'none'
            if select_default_choice not in cond_options and cond_options: select_default_choice = list(cond_options.keys())[0]
            
            select_help = add_debug_info_to_help(param_constructor_args, path_trace)["help"]
            cond.append(SelectParam(name=select_param_name, label=f"{label} Input Mode", help=select_help, options=cond_options, value=select_default_choice, optional=False))
            
            when_number = When(value="number")
            num_attrs = {k:v for k,v in param_constructor_args.items() if k not in ['value', 'help']}
            num_attrs.update({"optional": False, "label": f"{label} (as number)"})
            if isinstance(param.default, int): num_attrs['value'] = str(param.default)
            else: num_attrs['value'] = ""
            when_number.append(IntegerParam(argument=param_name, **num_attrs))
            cond.append(when_number)

            when_timedelta = When(value="timedelta")
            td_attrs = {k:v for k,v in param_constructor_args.items() if k not in ['value', 'help']}
            td_attrs.update({"optional": False, "label": f"{label} (as timedelta string)"})
            if isinstance(param.default, str): td_attrs['value'] = param.default
            else: td_attrs['value'] = ""
            when_timedelta.append(TextParam(argument=param_name, **td_attrs))
            cond.append(when_timedelta)

            if "none" in cond_options:
                when_none = When(value="none")
                when_none.append(HiddenParam(name=param_name, value="__none__"))
                cond.append(when_none)
            xml_params.append(cond)

        elif origin is Union and float in args and str in args and param_name in ["cutoff", "freq"]:
            path_trace.append("is_union_float_str_conditional")
            cond = Conditional(name=f"{param_name}_cond")
            select_param_name = f"{param_name}_select_type"
            cond_options = {}
            num_label, str_label = "Value (float)", "Offset string"
            if param_name == "cutoff": cond_options = {"number": f"Cutoff as {num_label}", "offset": f"Cutoff as {str_label}"}
            elif param_name == "freq": cond_options = {"number": f"Frequency as {num_label}", "offset": f"Frequency as {str_label}"}
            else: cond_options = {"number": num_label, "offset": str_label}
            if optional: cond_options["none"] = "None (use default)"
            select_default_choice = None
            if isinstance(param.default, float): select_default_choice = 'number'
            elif isinstance(param.default, str): select_default_choice = 'offset'
            elif optional and param.default is None: select_default_choice = 'none'
            if select_default_choice not in cond_options and cond_options: select_default_choice = list(cond_options.keys())[0]
            
            select_help = add_debug_info_to_help(param_constructor_args, path_trace)["help"]
            cond.append(SelectParam(name=select_param_name, label=f"{label} Input Mode", help=select_help, options=cond_options, value=select_default_choice, optional=False))
            
            when_number = When(value="number")
            float_attrs = {k:v for k,v in param_constructor_args.items() if k not in ['value', 'help']}
            float_attrs.update({"optional": False, "label": f"{label} ({cond_options.get('number', num_label)})"})
            if isinstance(param.default, float): float_attrs['value'] = str(param.default)
            else: float_attrs['value'] = ""
            when_number.append(FloatParam(argument=param_name, **float_attrs))
            cond.append(when_number)

            when_str_offset = When(value="offset")
            str_attrs = {k:v for k,v in param_constructor_args.items() if k not in ['value', 'help']}
            str_attrs.update({"optional": False, "label": f"{label} ({cond_options.get('offset', str_label)})"})
            if isinstance(param.default, str): str_attrs['value'] = param.default
            else: str_attrs['value'] = ""
            when_str_offset.append(TextParam(argument=param_name, **str_attrs))
            cond.append(when_str_offset)

            if "none" in cond_options:
                when_none = When(value="none")
                when_none.append(HiddenParam(name=param_name, value="__none__"))
                cond.append(when_none)
            xml_params.append(cond)

        elif origin is Union and all(a in args for a in (Literal['valid', 'complete'], list[str])):
            path_trace.append("is_union_literal_list_conditional")
            cond = Conditional(name=f"{param_name}_cond")
            select_param_name = f"{param_name}_select_type"
            options_dict_local = {"valid": "Valid", "complete": "Complete", "list": "Custom List"}
            if optional: options_dict_local["none"] = "None (use default)"
            select_default_key = None
            if isinstance(param.default, str) and param.default in options_dict_local: select_default_key = param.default
            elif isinstance(param.default, list): select_default_key = 'list'
            elif optional and param.default is None: select_default_key = 'none'
            if select_default_key not in options_dict_local and options_dict_local: select_default_key = list(options_dict_local.keys())[0]
            
            select_help = add_debug_info_to_help(param_constructor_args, path_trace)["help"]
            cond.append(SelectParam(name=select_param_name, label=f"{label} Mode", help=select_help, options=options_dict_local, value=select_default_key, optional=False))
            
            for opt_key in options_dict_local.keys():
                current_when = When(value=opt_key)
                if opt_key == "list":
                    list_attrs = {k:v for k,v in param_constructor_args.items() if k not in ['value', 'help']}
                    list_attrs.update({"optional":False, "label": f"{label} (comma-separated)"})
                    if isinstance(param.default, list): list_attrs['value'] = ",".join(map(str,param.default))
                    else: list_attrs['value'] = ""
                    current_when.append(TextParam(argument=param_name, **list_attrs))
                elif opt_key == "none":
                    current_when.append(HiddenParam(name=param_name, value="__none__"))
                else:
                    current_when.append(HiddenParam(name=param_name, value=opt_key))
                cond.append(current_when)
            xml_params.append(cond)

        elif origin is Union and any(get_origin(a) is Literal and "auto" in get_args(a) for a in args) and float in args:
            path_trace.append("is_union_literal_auto_float_conditional")
            has_callable_opt = any(is_callable_type(a) for a in args)
            cond = Conditional(name=f"{param_name}_cond")
            select_param_name = f"{param_name}_select_type"
            cond_options = {"auto": "Automatic ('auto')", "float": "Specific Value (float)"}
            if has_callable_opt: cond_options["custom"] = "Custom Callable"
            if optional: cond_options["none"] = "None (use default)"
            select_default_choice = None
            if param.default == "auto": select_default_choice = "auto"
            elif isinstance(param.default, float): select_default_choice = "float"
            elif has_callable_opt and (is_callable_type(param.default) or (isinstance(param.default, str) and param.default not in ["auto"])):
                 select_default_choice = "custom"
            elif optional and param.default is None: select_default_choice = "none"
            if select_default_choice not in cond_options and cond_options: select_default_choice = list(cond_options.keys())[0]
             
            select_help = add_debug_info_to_help(param_constructor_args, path_trace)["help"]
            cond.append(SelectParam(name=select_param_name, label=f"{label} Mode", help=select_help, options=cond_options, value=select_default_choice, optional=False))
             
            when_auto = When(value="auto"); when_auto.append(HiddenParam(name=param_name, value="auto")); cond.append(when_auto)
            when_float = When(value="float")
            float_attrs = {k:v for k,v in param_constructor_args.items() if k not in ['value', 'help']}
            float_attrs.update({"optional": False, "label": f"{label} (float value)"})
            if isinstance(param.default, float): float_attrs['value'] = str(param.default)
            else: float_attrs['value'] = ""
            when_float.append(FloatParam(argument=param_name, **float_attrs))
            cond.append(when_float)
            if has_callable_opt:
                 when_custom = When(value="custom")
                 custom_attrs = {k:v for k,v in param_constructor_args.items() if k not in ['value', 'help']}
                 custom_attrs.update({"optional": False, "label": f"{label} (custom callable name)"})
                 if isinstance(param.default, str) and param.default!="auto" and not isinstance(param.default, (float, int)):
                      custom_attrs['value'] = param.default
                 elif is_callable_type(param.default) and hasattr(param.default, '__name__'):
                      custom_attrs['value'] = param.default.__name__
                 else:
                      custom_attrs['value'] = ""
                 when_custom.append(TextParam(argument=param_name, **custom_attrs))
                 cond.append(when_custom)
            if "none" in cond_options:
                 when_none = When(value="none"); when_none.append(HiddenParam(name=param_name, value="__none__")); cond.append(when_none)
            xml_params.append(cond)

        elif origin is Literal:
            path_trace.append("is_literal")
            literal_options = dict([(str(o), str(o)) for o in args])
            current_literal_attrs = {**param_constructor_args}
            if param.default is not inspect.Parameter.empty and str(param.default) in literal_options:
                 current_literal_attrs['value'] = str(param.default)
            elif not optional:
                 if 'value' not in current_literal_attrs or current_literal_attrs['value'] is None :
                     if literal_options:
                         current_literal_attrs['value'] = str(list(literal_options.keys())[0])
                     else:
                         current_literal_attrs['value'] = ""
            elif 'value' in current_literal_attrs and current_literal_attrs['value'] is None:
                del current_literal_attrs['value']
            xml_params.append(SelectParam(argument=param_name, options=literal_options, **add_debug_info_to_help(current_literal_attrs, path_trace)))

        elif (origin is Union and any(is_callable_type(a) for a in args) and
              any(get_origin(a) is Literal and all(lit_val in get_args(a) for lit_val in ("linear", "exponential")) for a in args)):
            path_trace.append("is_union_callable_literal_model_conditional")
            cond = Conditional(name=f"{param_name}_cond")
            select_param_name = f"{param_name}_select_type"
            cond_options = {"linear": "Linear Model", "exponential": "Exponential Model", "custom": "Custom Callable"}
            if optional: cond_options["none"] = "None (use default)"
            select_default_choice = None
            if isinstance(param.default, str) and param.default in ("linear", "exponential"): select_default_choice = param.default
            elif is_callable_type(param.default) or (isinstance(param.default, str) and param.default not in ("linear", "exponential")):
                select_default_choice = "custom"
            elif optional and param.default is None: select_default_choice = "none"
            if select_default_choice not in cond_options and cond_options: select_default_choice = list(cond_options.keys())[0]
            
            select_help = add_debug_info_to_help(param_constructor_args, path_trace)["help"]
            cond.append(SelectParam(name=select_param_name, label=f"{label} Model Type", help=select_help, options=cond_options, value=select_default_choice, optional=False))
            
            when_linear = When(value="linear"); when_linear.append(HiddenParam(name=param_name, value="linear")); cond.append(when_linear)
            when_exp = When(value="exponential"); when_exp.append(HiddenParam(name=param_name, value="exponential")); cond.append(when_exp)
            
            when_custom = When(value="custom")
            custom_attrs = {k:v for k,v in param_constructor_args.items() if k not in ['value', 'help']}
            custom_attrs.update({"optional": False, "label": f"{label} (Custom Callable Name)"})
            if isinstance(param.default, str) and param.default not in ("linear", "exponential"):
                custom_attrs['value'] = param.default
            elif is_callable_type(param.default) and hasattr(param.default, '__name__'):
                custom_attrs['value'] = param.default.__name__
            else:
                custom_attrs['value'] = ""
            when_custom.append(TextParam(argument=param_name, **custom_attrs))
            cond.append(when_custom)
            
            if "none" in cond_options:
                when_none = When(value="none"); when_none.append(HiddenParam(name=param_name, value="__none__")); cond.append(when_none)
            xml_params.append(cond)

        elif origin in (pd.Series, pd.DataFrame, DictOfSeries, list, np.ndarray) or \
             (origin is Union and any(o_arg in (pd.Series, pd.DataFrame, DictOfSeries, list, np.ndarray) for o_arg in args)):
            path_trace.append("is_data_like_text")
            param_constructor_args["help"] += " (Name of another data field/column or comma-separated list of columns)"
            xml_params.append(TextParam(argument=param_name, **add_debug_info_to_help(param_constructor_args, path_trace)))

        elif origin is Sequence and not (annotation == Sequence[ForwardRef("SaQC")] if isinstance(annotation, type) else False):
             path_trace.append("is_generic_sequence_text")
             param_constructor_args["help"] += " (Enter items separated by commas, e.g., val1,val2,val3)"
             current_seq_attrs = {**param_constructor_args}
             if isinstance(param.default, Sequence) and not isinstance(param.default, str) :
                 current_seq_attrs['value'] = ",".join(map(str, param.default))
             elif not optional and ('value' not in current_seq_attrs or current_seq_attrs['value'] is None):
                 current_seq_attrs['value'] = ""
             elif optional and 'value' in current_seq_attrs and current_seq_attrs['value'] is None:
                 del current_seq_attrs['value']
             xml_params.append(TextParam(argument=param_name, **add_debug_info_to_help(current_seq_attrs, path_trace)))

        elif isinstance(annotation, type) and (annotation == Sequence[ForwardRef("SaQC")] or annotation == dict[ForwardRef("SaQC"), Union[str, Sequence[str]]]):
            path_trace.append("is_complex_saqc_sequence_ignored")
            sys.stderr.write(f"Ignoring specific complex SaQC sequence/dict parameter {param_name} ({method.__name__})\n")

        else:
             path_trace.append("final_catch_all_fallback_text")
             xml_params.append(TextParam(argument=param_name, **add_debug_info_to_help(param_constructor_args, path_trace)))
    return xml_params


def get_methods_conditional(methods, module):
    method_conditional = Conditional(name="method_cond", label="Method")
    method_select_options = []
    if not methods:
        return None

    for method_obj in methods:
        method_name = method_obj.__name__
        method_doc = _get_doc(method_obj.__doc__)
        if not method_doc:
            method_doc = method_name
        method_select_options.append((method_name, f"{method_name}: {method_doc}"))

    if method_select_options:
        method_select = SelectParam(
            name="method_select", label="Method", options=dict(method_select_options), optional=False
        )
        if method_select_options:
            method_select.value = method_select_options[0][0]
        method_conditional.append(method_select)
    else:
         no_options_notice = TextParam(name="no_method_options_notice", type="text", value="No methods available for selection.", label="Info")
         method_conditional.append(no_options_notice)

    for method_obj in methods:
        method_name = method_obj.__name__
        method_when = When(value=method_name)
        try:
            params = get_method_params(method_obj, module)
            if not params :
                 no_params_notice = TextParam(name=f"{method_name}_no_params_notice", type="text", value="This method has no configurable parameters.", label="Info")
                 method_when.append(no_params_notice)
            else:
                for p in params:
                    method_when.append(p)
        except ValueError as e:
            sys.stderr.write(
                f"Skipping params for method {method_name} in module {module.__name__} due to: {e}\n"
            )
            param_error_notice = TextParam(name=f"{method_name}_param_error_notice", type="text", value=f"Error generating parameters for this method: {e}", label="Parameter Generation Error")
            method_when.append(param_error_notice)
        method_conditional.append(method_when)

    return method_conditional


REPEAT_FIELD_FUNCS = [
    'flagDriftFromNorm', 'flagDriftFromReference', 'flagLOF', 'flagMVScores',
    'flagZScore', 'assignKNNScore', 'assignLOF', 'assignUniLOF'
]

def get_param_info(method: Callable) -> Dict[str, Any]:
    """
    Inspects a callable and returns a dictionary with detailed information
    about its parameters, resolving type annotations and default values.
    Diese Funktion ist eine Adaption aus testGen.py.
    """
    param_info = {}
    try:
        parameters = inspect.signature(method).parameters
    except (ValueError, TypeError):
        return {}

    for name, param in parameters.items():
        if name in ["self", "kwargs", "store_kwargs", "ax_kwargs"]: continue
        annotation = param.annotation

        if isinstance(annotation, (str, ForwardRef)):
            try:

                eval_context = {
                    **globals(), **saqc.__dict__, **saqc.lib.types.__dict__,
                    **saqc.funcs.__dict__, 'pd': pd, 'np': np, 'mpl': mpl,
                    'Union': Union, 'Literal': Literal, 'Sequence': Sequence,
                    'Callable': Callable, 'Any': Any, 'Tuple': Tuple, 'Dict': Dict
                }
                for mod_name, mod_obj in get_modules():
                    eval_context[mod_name] = mod_obj
                if isinstance(annotation, ForwardRef):
                    annotation = annotation._evaluate(eval_context, globals(), frozenset())
                else:
                    annotation = eval(annotation, eval_context)
            except Exception:
                annotation = Any

        if annotation is param.empty:
            annotation = Any


        origin = get_origin(annotation)
        args = get_args(annotation)
        is_union_with_none = is_union_type(annotation) and type(None) in args
        if is_union_with_none:
            non_none_args = [a for a in args if a is not type(None)]
            annotation = Union[tuple(non_none_args)] if len(non_none_args) > 1 else (non_none_args[0] if non_none_args else Any)
            origin, args = get_origin(annotation), get_args(annotation)

        param_info[name] = {
            'annotation': annotation, 'origin': origin, 'args': args,
            'default': param.default if param.default is not param.empty else inspect.Parameter.empty
        }
    return param_info

def generate_test_variants(method: Callable) -> list:
    """
    Generates a list of test case variants for a given method based on its
    parameter types and default values.
    """
    param_info = get_param_info(method)
    if not param_info: return []

    variants, base_params, complex_params_to_vary = [], {}, set()


    for name, info in param_info.items():
        default = info['default']
        annotation = info['annotation']
        origin = get_origin(annotation)
        args = get_args(annotation)

        if (origin is Literal and len(args) > 1) or \
           (origin is Union and len(args) > 1 and not (is_callable_type(args[0]) or is_callable_type(args[1]))):
            complex_params_to_vary.add(name)


        if default is not inspect.Parameter.empty and default is not None and default != "":
            if annotation is bool:
                base_params[name] = not default
            else:
                base_params[name] = default
        else:

            assigned = False
            possible_types = args if origin is Union else [annotation]

            if name in ['field', 'target']:
                base_params[name] = 'test_variable'
                assigned = True
            elif origin is Literal and args:
                base_params[name] = args[0]
                assigned = True

            if not assigned:
                if any(t is int for t in possible_types):
                    base_params[name] = 1
                elif any(t is float for t in possible_types):
                    base_params[name] = 1.0
                elif any(t is bool for t in possible_types):
                    base_params[name] = True
                elif any(t is pd.Timedelta for t in possible_types):
                    base_params[name] = "1D"
                elif any(t is str for t in possible_types):
                     base_params[name] = "default_string"
                else:
                    base_params[name] = "default_string"


    variants.append({"description": f"Test mit Defaults für {method.__name__}", "params": base_params})

    # Create variants for complex parameters
    for name in complex_params_to_vary:
        info, options_to_test = param_info[name], []
        if info['origin'] is Literal:
            options_to_test = info['args']
        elif info['origin'] is Union:
            for arg_type in info['args']:
                if arg_type is type(None): continue
                if arg_type is int: options_to_test.append(123)
                elif arg_type is float: options_to_test.append(45.6)
                elif arg_type is str: options_to_test.append("a_string")
                elif pd and hasattr(pd, 'Timedelta') and arg_type == pd.Timedelta: options_to_test.append("2H")

        for option in options_to_test:
            if option is None: continue
            variant_params = base_params.copy()

            if name == 'thresh' and isinstance(option, float):
                variant_params['thresh_cond'] = {'thresh_select_type': 'float', 'thresh': option}
                if 'thresh' in variant_params: del variant_params['thresh']
            elif name == 'density' and isinstance(option, float):
                 variant_params['density_cond'] = {'density_select_type': 'float', 'density': option}
                 if 'density' in variant_params: del variant_params['density']
            else:
                variant_params[name] = option

            variants.append({"description": f"Test-Variante für '{name}' mit Wert '{str(option)}'", "params": variant_params})

    # Prepare final structure for XML generation
    final_variants = []
    for variant in variants:
        galaxy_params = {}
        for name, value in variant['params'].items():
            info = param_info.get(name, {})
            is_union_cond = info.get('origin') is Union and any(t in info.get('args', []) for t in [int, float]) and str in info.get('args', [])

            if name in ["field", "target"]:
                if method.__name__ in REPEAT_FIELD_FUNCS:
                    val_list = [value] if not isinstance(value, list) else value
                    galaxy_params[f"{name}_repeat"] = [{name: v} for v in val_list]
                    galaxy_params[name] = value
                else:
                    galaxy_params[name] = value
            elif name.endswith('_cond') and isinstance(value, dict):
                 galaxy_params[name] = value
            elif is_union_cond:
                type_map = {int: 'number', float: 'number', str: 'timedelta'}
                val_type = type_map.get(type(value), 'offset')
                galaxy_params[f"{name}_cond"] = {f"{name}_select_type": val_type, name: value}
            else:
                galaxy_params[name] = value

        final_variants.append({
            "description": variant["description"],
            "galaxy_params": galaxy_params,
            "saqc_call_params": variant["params"]
        })
    return final_variants

def build_param_xml(parent: ET.Element, name: str, value: Any):
    """Recursively builds the XML <param> structure for Galaxy tests."""
    name_str = str(name)
    if name_str.endswith("_repeat") and isinstance(value, list):
        repeat = ET.SubElement(parent, "repeat", {"name": name_str})
        for item_dict in value:
            if isinstance(item_dict, dict):
                for sub_name, sub_value in item_dict.items():
                    build_param_xml(repeat, sub_name, sub_value)
    elif name_str.endswith("_cond") and isinstance(value, dict):
        conditional = ET.SubElement(parent, "conditional", {"name": name_str})
        param_name_base = name_str.replace("_cond", "")
        selector_name = f"{param_name_base}_select_type"
        selector_value = value.get(selector_name)
        if selector_value is not None:
            ET.SubElement(conditional, "param", {"name": selector_name, "value": str(selector_value)})
            build_param_xml(conditional, param_name_base, value.get(param_name_base))
    else:
        val_str = str(value).lower() if isinstance(value, bool) else str(value) if value is not None else ""
        ET.SubElement(parent, "param", {"name": name_str, "value": val_str})

def format_value_for_regex(value: Any, param_name: str) -> str:
    """Formats a Python value into a regex string for assertion."""
    empty_is_none_params = [
        "reduce_window", "tolerance", "maxna", "maxna_group", "sub_window", "sub_thresh",
        "min_periods", "min_residuals", "min_offset", "stray_range", "path", "ax",
        "marker_kwargs", "plot_kwargs", "freq", "group", "xscope", "yscope"
    ]
    if param_name in empty_is_none_params and (value is None or value == ""):
        return '(None|"")'

    if value is None: return "None"
    if isinstance(value, bool): return f"({str(value)}|None)"
    if isinstance(value, str) and value.startswith('<function'):
        sanitized_val = value.replace('<', '__lt__').replace('>', '__gt__')
        return re.escape(sanitized_val)

    if isinstance(value, int):
        escaped_val = re.escape(str(value))
        return f'(?:["\']?{escaped_val}["\']?)'

    if isinstance(value, float):
        if math.isinf(value): return r"float\(['\"]-?inf['\"]\)"
        if math.isnan(value): return r"float\(['\"]nan['\"]\)"
        return re.escape(str(value))

    if isinstance(value, str):
        return f'["\']{re.escape(str(value))}["\']'

    return re.escape(str(value))

def generate_test_macros():
    """Main function to generate the Galaxy test macros XML."""
    macros_root = ET.Element("macros")
    all_tests_macro = ET.SubElement(macros_root, "xml", {"name": "config_tests"})
    print("--- Starting Test Macro Generation ---", file=sys.stderr)

    modules = get_modules()
    for module_name, module_obj in modules:
        methods = get_methods(module_obj)
        for method_obj in methods:
            method_name = method_obj.__name__
            try:
                test_variants = generate_test_variants(method_obj)
            except Exception as e:
                print(f"Error generating variants for {method_name}: {e}", file=sys.stderr)
                continue

            for i, variant in enumerate(test_variants):
                test_elem = ET.SubElement(all_tests_macro, "test")
                ET.SubElement(test_elem, "param", {"name": "data", "value": "test1/data.csv", "ftype": "csv"})
                ET.SubElement(test_elem, "param", {"name": "run_test_mode", "value": "true"})
                repeat = ET.SubElement(test_elem, "repeat", {"name": "methods_repeat"})
                mod_cond = ET.SubElement(repeat, "conditional", {"name": "module_cond"})
                ET.SubElement(mod_cond, "param", {"name": "module_select", "value": module_name})
                meth_cond = ET.SubElement(mod_cond, "conditional", {"name": "method_cond"})
                ET.SubElement(meth_cond, "param", {"name": "method_select", "value": method_name})

                for p_name, p_value in variant['galaxy_params'].items():
                    build_param_xml(meth_cond, p_name, p_value)

                output_elem = ET.SubElement(test_elem, "output", {"name": "config_out", "ftype": "txt"})
                assert_contents = ET.SubElement(output_elem, "assert_contents")
                params_to_check = variant['saqc_call_params']

                field_val = params_to_check.get('field', params_to_check.get('target'))
                field_name = field_val if not isinstance(field_val, list) else (field_val[0] if field_val else "test_variable")

                field_regex_part = re.escape(str(field_name))

                lookaheads = []

                if variant['description'].startswith('Test mit Defaults'):
                    full_regex = f"{field_regex_part};\\s*{method_name}\\(.*\\)$"
                else:
                    match = re.search(r"Test-Variante für '([^']+)'.*", variant['description'])
                    if match:
                        varied_param_name = match.group(1)
                        if varied_param_name in params_to_check:
                            p_value = params_to_check[varied_param_name]

                            if varied_param_name not in ['field', 'target']:
                                formatted_value = format_value_for_regex(p_value, varied_param_name)
                                lookaheads.append(f'(?=.*{varied_param_name}\\s*=\\s*{formatted_value})')

                    if not lookaheads:
                         full_regex = f"{field_regex_part};\\s*{method_name}\\(.*\\)$"
                    else:
                         full_regex = f"{field_regex_part};\\s*{method_name}\\({ ''.join(lookaheads)}.*\\)$"

                ET.SubElement(assert_contents, "has_text_matching", {"expression": full_regex})

    try:
        ET.indent(macros_root, space="  ")
        sys.stdout.buffer.write(b'<?xml version="1.0" encoding="utf-8"?>\n')
        sys.stdout.buffer.write(ET.tostring(macros_root, encoding='utf-8', xml_declaration=False))
        print("\nSuccessfully generated test macro XML.", file=sys.stderr)
    except Exception as e:
        print(f"\nXML Serialization failed. Error: {e}", file=sys.stderr)



def generate_tool_xml():
    """Generiert und druckt die XML-Definition des Galaxy-Tools."""

    # --- Tool Definition ---
    command_override = ["""
#if str($run_test_mode) == "true":
  '$__tool_directory__'/json_to_saqc_config.py '$param_conf' > config.csv
#else
  '$__tool_directory__'/json_to_saqc_config.py '$param_conf' > config.csv &&
  #for $i, $d in enumerate($data)
      ##maybe link to element_identifier
      ln -s '$d' '${i}.csv' &&
  #end for
  saqc --config config.csv
  #for $i, $d in enumerate($data)
      --data '${i}.csv'
  #end for
  --outfile output.csv
#end if
"""]

    tool = Tool(
        "SaQC",
        "saqc",
        version="@TOOL_VERSION@+galaxy@VERSION_SUFFIX@",
        description="quality control pipelines for environmental sensor data",
        executable="saqc",
        macros=["macros.xml", "test_macros.xml"],
        command_override=command_override,
        profile="22.01",
        version_command="python -c 'import saqc; print(saqc.__version__)'",
    )
    tool.help = "This tool provides access to SaQC functions for quality control of time series data. Select a module and method, then configure its parameters."

    tool.configfiles = Configfiles()
    tool.configfiles.append(ConfigfileDefaultInputs(name="param_conf"))

    inputs_section = tool.inputs = Inputs()
    inputs_section.append(DataParam(argument="--data", format="csv", multiple=True, label="Input table(s)"))
    inputs_section.append(HiddenParam(name="run_test_mode", value="false"))


    modules = get_modules()
    module_repeat = Repeat(name="methods_repeat", title="Methods (add multiple QC steps)")
    inputs_section.append(module_repeat)

    module_conditional = Conditional(name="module_cond", label="SaQC Module")
    module_select_options = []
    for module_name, module_obj in modules:
        module_doc = _get_doc(module_obj.__doc__)
        if not module_doc:
            module_doc = module_name
        module_select_options.append((module_name, f"{module_name}: {module_doc}"))

    if module_select_options:
        module_select = SelectParam(
            name="module_select", label="Select SaQC module", options=dict(module_select_options), optional=False
        )
        if module_select_options:
            module_select.value = module_select_options[0][0]
        module_conditional.append(module_select)
    else:
         module_conditional.append(TextParam(name="no_modules_found", type="text", value="No SaQC modules found.", label="Error"))

    for module_name, module_obj in modules:
        module_when = When(value=module_name)
        methods = get_methods(module_obj)
        if methods:
            methods_conditional_obj = get_methods_conditional(methods, module_obj)
            if methods_conditional_obj:
                 module_when.append(methods_conditional_obj)
            else:
                 module_when.append(TextParam(name=f"{module_name}_no_methods_conditional", type="text", value=f"Could not generate method selection for module '{module_name}'.", label="Notice"))
        else:
            module_when.append(TextParam(name=f"{module_name}_no_methods_found", type="text", value=f"No SaQC methods detected for module '{module_name}'.", label="Notice"))
        module_conditional.append(module_when)

    if module_select_options:
        module_repeat.append(module_conditional)


    outputs_section = tool.outputs = Outputs()
    outputs_section.append(OutputData(name="output", format="csv", from_work_dir="output.csv", label="${tool.name} on ${on_string}: Processed Data"))
    plot_outputs = OutputCollection(
        name="plots", type="list", label="${tool.name} on ${on_string}: Plots (if any generated)"
    )
    plot_outputs.append(DiscoverDatasets(pattern=r"(?P<name>.*)\.png", ext="png", visible=True))
    outputs_section.append(plot_outputs)
    outputs_section.append(OutputData(name="config_out", format="txt", from_work_dir="config.csv", label="${tool.name} on ${on_string}: Generated SaQC Configuration"))

    tool_xml = tool.export()


    print(tool_xml)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generate Galaxy XML for SaQC tool or its test macros.")
    parser.add_argument(
        '--generate-tool',
        action='store_true',
        help='Generate the main tool XML file (saqc.xml).'
    )
    parser.add_argument(
        '--generate-tests',
        action='store_true',
        help='Generate the test macros file (test_macros.xml).'
    )

    args = parser.parse_args()


    if args.generate_tool:
        print("--- Generating Galaxy Tool XML ---", file=sys.stderr)
        generate_tool_xml()
    elif args.generate_tests:
        print("--- Generating Galaxy Test Macros XML ---", file=sys.stderr)
        generate_test_macros()
    else:

        print("--- No argument specified, generating Galaxy Tool XML by default. ---", file=sys.stderr)
        generate_tool_xml()