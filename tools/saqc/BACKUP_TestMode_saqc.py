"""
Create a wrapper for SaQC from the SaQC sources.

Usage: call from an environment with saqc (and typing_inspect, galaxyxml) installed
"""

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
# KEIN Import für Filter mehr

import matplotlib as mpl
import numpy as np
import pandas as pd
import saqc
from saqc.core import SaQC, DictOfSeries
from saqc.funcs.curvefit import FILL_METHODS
from saqc.funcs.drift import LinkageString
from saqc.funcs.generic import GenericFunction
#from saqc.funcs.interpolation import INTERPOLATION_METHODS
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
    doc_str = doc_str.strip(" .,")
    return doc_str


def parse_docstring(method: Callable) -> Dict[str, str]:
    docstring = method.__doc__
    if not docstring:
        return {}

    sections: Dict[str, str] = {}
    section_pattern = r"^(?P<title>[^\s\n][^\n]*)\n(?:-|=){3,}\n"
    
    first_match = re.search(section_pattern, docstring, re.MULTILINE)
    if first_match:
        if first_match.start() > 0:
            sections[""] = docstring[:first_match.start()].strip()
    elif docstring: 
        sections[""] = docstring.strip()
        return {k:v for k,v in sections.items() if v}

    current_title = ""
    current_content_start = 0
    if first_match: 
        current_title = first_match.group("title").strip()
        current_content_start = first_match.end()

    for match in list(re.finditer(section_pattern, docstring, re.MULTILINE))[1:]: 
        sections[current_title] = docstring[current_content_start:match.start()].strip()
        current_title = match.group("title").strip()
        current_content_start = match.end()
    
    if current_title: 
        sections[current_title] = docstring[current_content_start:].strip()
            
    return {k:v for k,v in sections.items() if v}


def parse_parameter_docs(sections: Dict[str, str]) -> Dict[str, str]:
    parameter_doc: Dict[str, str] = {}
    parameters_text = sections.get("Parameters", "")
    if not parameters_text:
        return parameter_doc

    current_param = None
    current_lines: list[str] = []
    param_start_pattern = re.compile(r"^(?P<param_name>[a-zA-Z_][a-zA-Z0-9_]*)\s*(:.*)?")

    for line in parameters_text.splitlines():
        original_line_stripped = line.strip()
        
        match = None
        if not line.startswith("    "): 
            match = param_start_pattern.match(original_line_stripped)

        if match:
            if current_param:
                parameter_doc[current_param] = "\n".join(current_lines).strip()
            
            current_param = match.group("param_name")
            current_lines = [original_line_stripped]
        elif current_param:
            current_lines.append(original_line_stripped)
    
    if current_param:
        parameter_doc[current_param] = "\n".join(current_lines).strip()

    for pname, pdoc in parameter_doc.items():
        lines = pdoc.split('\n')
        if lines:
            cleaned_first_line = re.sub(r"^\s*{}\s*:\s*[^-\n]+\s*".format(re.escape(pname)), "", lines[0], count=1).strip()
            if lines[0].strip() != cleaned_first_line: 
                 lines[0] = cleaned_first_line
            elif lines[0].strip().startswith(pname): 
                 lines[0] = re.sub(r"^\s*{}\s*:\s*".format(re.escape(pname)),"", lines[0], count=1).strip()
                 lines[0] = re.sub(r"^\s*{}".format(re.escape(pname)),"", lines[0], count=1).strip()
            parameter_doc[pname] = "\n".join(l.strip() for l in lines if l.strip()).strip()
            
    return parameter_doc


def get_label_help(param_name, parameter_docs):
    parameter_doc_entry = parameter_docs.get(param_name)
    if not parameter_doc_entry:
        return param_name, ""

    full_help = parameter_doc_entry.strip()
    label = param_name

    if full_help:
        sentence_match = re.match(r"([^.!?]+(?:[.!?](?=\s|$)|[.!?]$|$))", full_help.replace('\n', ' '))
        if sentence_match:
            label_candidate = sentence_match.group(1).strip()
            if len(label_candidate) > 100 and '\n' in full_help:
                label = full_help.split('\n')[0].strip()
                if len(label) > 80 : label = label[:77] + "..."
            else:
                label = label_candidate
                if len(label) > 80 : label = label[:77] + "..."
        else:
            label = full_help.split('\n')[0].strip()
            if len(label) > 80: label = label[:77] + "..."
        if not label.strip():
            label = param_name
            
    return label, full_help

def get_modules() -> Tuple[str, "ModuleType"]:
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
         sys.stderr.write(f"Warning: Could not get signature for {method.__name__}: {e}. Skipping params.\n")
         return xml_params

    for param_name, param in parameters.items():
        if param_name in ["self", "kwargs", "store_kwargs", "ax_kwargs"]:
            continue
        annotation = param.annotation

        if isinstance(annotation, str):
             try:
                 eval_context = {**globals(), **module.__dict__, **saqc.__dict__, **saqc.lib.types.__dict__}
                 eval_context.update({'pd': pd, 'np': np, 'mpl': mpl, 'Union': Union, 'Literal': Literal, 'Sequence': Sequence, 'Callable': Callable, 'Any': Any, 'Tuple': Tuple, 'Dict': Dict})
                 annotation = eval(annotation, eval_context)
             except Exception:
                 sys.stderr.write(f"Warning: Could not evaluate annotation '{param.annotation}' for {param_name} in {method.__name__}. Treating as Any.\n")
                 annotation = Any
        elif isinstance(annotation, ForwardRef):
             try:
                 eval_context = {**globals(), **module.__dict__, **saqc.__dict__, **saqc.lib.types.__dict__}
                 eval_context.update({'pd': pd, 'np': np, 'mpl': mpl, 'Union': Union, 'Literal': Literal, 'Sequence': Sequence, 'Callable': Callable, 'Any': Any, 'Tuple': Tuple, 'Dict': Dict})
                 annotation = annotation._evaluate(eval_context, locals(), frozenset())
             except Exception:
                 sys.stderr.write(f"Warning: Could not evaluate ForwardRef '{param.annotation.__forward_arg__}' for {param_name} in {method.__name__}. Treating as Any.\n")
                 annotation = Any

        if annotation is inspect.Parameter.empty:
             sys.stderr.write(f"Warning: missing type annotation for {param_name} in {method.__name__}. Treating as Any.\n")
             annotation = Any

        if isinstance(annotation, str):
             sys.stderr.write(f"Warning: Annotation '{annotation}' for {param_name} in {method.__name__} resolved to string type. Treating as TextParam.\n")
             annotation = str

        origin = get_origin(annotation)
        args = get_args(annotation)

        if param.default is inspect.Parameter.empty:
            default = None
        else:
            default = param.default

        value = ""
        if param.default is not inspect.Parameter.empty and param.default is not None and not isinstance(param.default, bool):
             value = str(param.default)

        label, help_text = get_label_help(param_name, param_docs)
        kwargs = {"label": label, "help": help_text}

        is_union = is_union_type(annotation)

        if param.default is None:
            optional = True
        elif is_union and any(a is type(None) for a in args):
            optional = True
        else:
            optional = False

        kwargs['optional'] = optional

        if is_union:
            args_wo_none = [a for a in args if a is not type(None)]
            if len(args_wo_none) == 1:
                annotation = args_wo_none[0]
                origin = get_origin(annotation)
                args = get_args(annotation)
                is_union = False
            elif len(args_wo_none) > 1:
                 annotation = Union[tuple(args_wo_none)]
                 origin = get_origin(annotation)
                 args = get_args(annotation)
            else:
                 annotation = Any
                 origin = None
                 args = ()
                 is_union = False
        
        # Parameter generation logic (aus der Version, die keine XSD-Fehler für readonly/when hatte)
        if param_name in ["field", "target"]:
            is_multi = False
            if origin in (list, Sequence) and args and args[0] == str: is_multi = True
            elif annotation == list[str] or annotation == Sequence[str]: is_multi = True

            if annotation != str and is_multi:
                 parent = Repeat(name=f"{param_name}_repeat", title=f"{param_name.capitalize()}(s)", min=1)
                 inner_kwargs = {"label": f"Name for {param_name}", "help": help_text, "optional": False}
                 parent.append(TextParam(argument=param_name, value="", **inner_kwargs))
                 xml_params.append(parent)
            elif annotation == str:
                 xml_params.append(TextParam(argument=param_name, value=str(value), **kwargs))
            else: # Fallback to TextParam, might produce warnings already present
                 xml_params.append(TextParam(argument=param_name, value=str(value), **kwargs))

        elif origin is None and not is_union :
            if annotation == bool:
                cli_argument_format = f"--{param_name}"
                xml_params.append(BooleanParam(argument=cli_argument_format, truevalue=cli_argument_format, falsevalue="", checked=True if default is True else False, **kwargs))
            elif annotation == str:
                xml_params.append(TextParam(argument=param_name, value=str(value), **kwargs))
            elif annotation == int:
                 xml_params.append(IntegerParam(argument=param_name, value=str(value) if value is not None and value != "" else "", **kwargs))
            elif annotation == float:
                 xml_params.append(FloatParam(argument=param_name, value=str(value) if value is not None and value != "" else "", **kwargs))
            elif is_callable_type(annotation) or annotation in (GenericFunction, CurveFitter, Any, slice, mpl.axes.Axes):
                 if is_callable_type(annotation):
                    callable_args_repr = str(get_args(annotation)) if hasattr(annotation, '__args__') else '(...)'
                    kwargs["help"] += f"\n(Expects a function reference: {callable_args_repr}. Default: {default})"
                    xml_params.append(TextParam(argument=param_name, value="", **kwargs))
                 else:
                    sys.stderr.write(f"Ignoring {annotation} simple parameter {param_name} ({method.__name__})\n")
            elif hasattr(annotation, '__mro__') and pd.Timedelta in annotation.__mro__:
                 kwargs["help"] += "\n(Pandas timedelta string, e.g., '1D', '2H30M')"
                 xml_params.append(TextParam(argument=param_name, value=str(value), **kwargs))
            else: 
                 xml_params.append(TextParam(argument=param_name, value=str(value), **kwargs)) # Fallback to TextParam

        elif origin is Union and str in args and pd.Timedelta in args:
             kwargs["help"] += "\n(Pandas timedelta string or offset, e.g., '1D', '2H30M')"
             xml_params.append(TextParam(argument=param_name, value=str(value), **kwargs))

        elif origin is Union and all(el_type in args for el_type in (str, Tuple[str,str])) and len(args)==2 :
            kwargs["help"] += "\n(String or two comma-separated strings, e.g., val1,val2)"
            xml_params.append(TextParam(argument=param_name, value=str(value), **kwargs))

        elif origin is Union and all(el_type in args for el_type in (int, Tuple[int,int])) and len(args)==2 :
            kwargs["help"] += "\n(Integer or two comma-separated integers, e.g., 1,2)"
            xml_params.append(TextParam(argument=param_name, value=str(value), **kwargs))

        elif origin is Union and int in args and str in args and param_name in ["limit", "window"]:
            cond = Conditional(name=f"{param_name}_cond")
            select_param_name = f"{param_name}_select_type"
            cond_options = {"number": "Number", "timedelta": "Timedelta"}
            if optional: cond_options["none"] = "None (use default)"

            select_default = None
            if isinstance(default, int): select_default = 'number'
            elif isinstance(default, str): select_default = 'timedelta'
            elif optional and default is None: select_default = 'none'
            if select_default not in cond_options and cond_options: select_default = list(cond_options.keys())[0]

            cond.append(SelectParam(name=select_param_name, label=f"{label} Input Mode", options=cond_options, value=select_default, optional=False))

            when_number = When(value="number")
            kwargs_number = {**kwargs, "optional": False, "label": f"{label} (as number)"}
            when_number.append(IntegerParam(argument=param_name, value=str(default) if isinstance(default, int) else "", **kwargs_number))
            cond.append(when_number)

            when_timedelta = When(value="timedelta")
            kwargs_timedelta = {**kwargs, "optional": False, "label": f"{label} (as timedelta string)"}
            when_timedelta.append(TextParam(argument=param_name, value=str(default) if isinstance(default, str) else "", **kwargs_timedelta))
            cond.append(when_timedelta)

            if "none" in cond_options:
                when_none = When(value="none")
                when_none.append(HiddenParam(name=param_name, value="__none__"))
                cond.append(when_none)
            xml_params.append(cond)

        elif origin is Union and float in args and str in args and param_name in ["cutoff", "freq"]:
            cond = Conditional(name=f"{param_name}_cond")
            select_param_name = f"{param_name}_select_type"
            cond_options = {}
            num_label, str_label = "Value (float)", "Offset string"
            if param_name == "cutoff": cond_options = {"number": f"Cutoff as {num_label}", "offset": f"Cutoff as {str_label}"}
            elif param_name == "freq": cond_options = {"number": f"Frequency as {num_label}", "offset": f"Frequency as {str_label}"}
            if optional: cond_options["none"] = "None (use default)"

            select_default = None
            if isinstance(default, float): select_default = 'number'
            elif isinstance(default, str): select_default = 'offset'
            elif optional and default is None: select_default = 'none'
            if select_default not in cond_options and cond_options: select_default = list(cond_options.keys())[0]

            cond.append(SelectParam(name=select_param_name, label=f"{label} Input Mode", options=cond_options, value=select_default, optional=False))

            when_number = When(value="number")
            kwargs_float = {**kwargs, "optional": False, "label": f"{label} ({cond_options.get('number', num_label)})"}
            when_number.append(FloatParam(argument=param_name, value=str(default) if isinstance(default, float) else "", **kwargs_float))
            cond.append(when_number)

            when_str = When(value="offset")
            kwargs_str = {**kwargs, "optional": False, "label": f"{label} ({cond_options.get('offset', str_label)})"}
            when_str.append(TextParam(argument=param_name, value=str(default) if isinstance(default, str) else "", **kwargs_str))
            cond.append(when_str)

            if "none" in cond_options:
                when_none = When(value="none")
                when_none.append(HiddenParam(name=param_name, value="__none__"))
                cond.append(when_none)
            xml_params.append(cond)

        elif origin is Union and any(get_origin(a) is Literal and "auto" in get_args(a) for a in args) and float in args:
             has_callable_opt = any(is_callable_type(a) for a in args)
             cond = Conditional(name=f"{param_name}_cond")
             select_param_name = f"{param_name}_select_type"
             cond_options = {"auto": "Automatic ('auto')", "float": "Specific Value (float)"}
             if has_callable_opt: cond_options["custom"] = "Custom Callable"
             if optional: cond_options["none"] = "None (use default)"

             select_default=None
             if default == "auto": select_default = "auto"
             elif isinstance(default, float): select_default = "float"
             elif has_callable_opt and (callable(default) or (isinstance(default, str) and default not in ["auto"])): select_default = "custom"
             elif optional and default is None: select_default = "none"
             if select_default not in cond_options and cond_options: select_default = list(cond_options.keys())[0]

             cond.append(SelectParam(name=select_param_name, label=f"{label} Mode", options=cond_options, value=select_default, optional=False))

             when_auto = When(value="auto"); when_auto.append(HiddenParam(name=param_name, value="auto")); cond.append(when_auto)

             when_float = When(value="float")
             kwargs_floatval = {**kwargs, "optional": False, "label": f"{label} (float value)"}
             when_float.append(FloatParam(argument=param_name, value=str(default) if isinstance(default,float) else "", **kwargs_floatval))
             cond.append(when_float)

             if has_callable_opt:
                 when_custom = When(value="custom")
                 kwargs_customval = {**kwargs, "optional": False, "label": f"{label} (custom callable name)"}
                 custom_default_val = str(default) if isinstance(default, str) and default!="auto" else ""
                 when_custom.append(TextParam(argument=param_name, value=custom_default_val, **kwargs_customval))
                 cond.append(when_custom)

             if "none" in cond_options:
                 when_none = When(value="none"); when_none.append(HiddenParam(name=param_name, value="__none__")); cond.append(when_none)
             xml_params.append(cond)

        elif origin is Union and all(a in args for a in (Literal['valid', 'complete'], list[str])):
            cond = Conditional(name=f"{param_name}_cond")
            select_param_name = f"{param_name}_select_type"
            options_dict_local = {
                "valid": "Valid", "complete": "Complete", "list": "Custom List"
            }
            if optional: options_dict_local["none"] = "None (use default)"

            select_default_key = None
            if isinstance(default, str) and default in options_dict_local: select_default_key = default
            elif isinstance(default, list): select_default_key = 'list'
            elif optional and default is None: select_default_key = 'none'
            if select_default_key not in options_dict_local and options_dict_local: select_default_key = list(options_dict_local.keys())[0]

            cond.append(SelectParam(name=select_param_name, label=f"{label} Mode", options=options_dict_local, value=select_default_key, optional=False))

            for opt_key in options_dict_local.keys():
                current_when = When(value=opt_key)
                if opt_key == "list":
                    list_val = ",".join(map(str,default)) if isinstance(default, list) else ""
                    current_when.append(TextParam(argument=param_name, value=list_val, **{**kwargs, "optional":False, "label": f"{label} (comma-separated)"}))
                elif opt_key == "none":
                    current_when.append(HiddenParam(name=param_name, value="__none__"))
                else:
                    current_when.append(HiddenParam(name=param_name, value=opt_key))
                cond.append(current_when)
            xml_params.append(cond)

        elif origin is Literal:
             literal_options = dict([(str(o), str(o)) for o in args])
             select_val = str(default) if default in args else None
             xml_params.append(SelectParam(argument=param_name, options=literal_options, value=select_val, **kwargs))

        elif (origin is Union and any(is_callable_type(a) for a in args) and
              any(get_origin(a) is Literal and all(lit_val in get_args(a) for lit_val in ("linear", "exponential")) for a in args)):
            cond = Conditional(name=f"{param_name}_cond")
            select_param_name = f"{param_name}_select_type"
            cond_options = {"linear": "Linear Model", "exponential": "Exponential Model", "custom": "Custom Callable"}
            if optional: cond_options["none"] = "None (use default)"

            select_default=None
            if default in ("linear", "exponential"): select_default = default
            elif callable(default) or (isinstance(default, str) and default not in ("linear", "exponential")): select_default = "custom"
            elif optional and default is None: select_default = "none"
            if select_default not in cond_options and cond_options: select_default = list(cond_options.keys())[0]

            cond.append(SelectParam(name=select_param_name, label=f"{label} Model Type", options=cond_options, value=select_default, optional=False))

            when_linear = When(value="linear"); when_linear.append(HiddenParam(name=param_name, value="linear")); cond.append(when_linear)
            when_exp = When(value="exponential"); when_exp.append(HiddenParam(name=param_name, value="exponential")); cond.append(when_exp)

            when_custom = When(value="custom")
            kwargs_custom_call = {**kwargs, "optional": False, "label": f"{label} (Custom Callable Name)"}
            custom_default_val = str(default) if isinstance(default, str) and default not in ("linear", "exponential") else ""
            when_custom.append(TextParam(argument=param_name, value=custom_default_val, **kwargs_custom_call))
            cond.append(when_custom)

            if "none" in cond_options:
                when_none = When(value="none"); when_none.append(HiddenParam(name=param_name, value="__none__")); cond.append(when_none)
            xml_params.append(cond)

        elif origin in (pd.Series, pd.DataFrame, DictOfSeries, list, np.ndarray) or \
             (origin is Union and any(o_arg in (pd.Series, pd.DataFrame, DictOfSeries, list, np.ndarray) for o_arg in args)):
            kwargs["help"] += "\n(Name of another data field/column or comma-separated list of columns)"
            xml_params.append(TextParam(argument=param_name, value=str(value), **kwargs))

        elif origin is Sequence and not (isinstance(annotation, type) and annotation == Sequence[ForwardRef("SaQC")]): # type: ignore
             kwargs["help"] += "\n(Enter items separated by commas, e.g., val1,val2,val3)"
             default_seq_val = ",".join(map(str, default)) if isinstance(default, Sequence) and not isinstance(default, str) else str(value)
             xml_params.append(TextParam(argument=param_name, value=default_seq_val, **kwargs))

        elif isinstance(annotation, type) and (annotation == Sequence[ForwardRef("SaQC")] or annotation == dict[ForwardRef("SaQC"), Union[str, Sequence[str]]]): # type: ignore
            sys.stderr.write(f"Ignoring specific complex SaQC sequence/dict parameter {param_name} ({method.__name__})\n")

        else:
             sys.stderr.write(f"Warning: Parameter '{param_name}' of type {annotation} (origin: {origin}, args: {args}) in method '{method.__name__}' is falling back to TextParam.\n")
             xml_params.append(TextParam(argument=param_name, value=str(value), **kwargs))
    return xml_params

def build_methods_repeat_structure():
    methods_repeat = Repeat(name="methods_repeat", title="QC Methods", min=1, default=0, help="Add one or more Quality Control methods to apply sequentially.")

    module_conditional = Conditional(name="module_cond", label="Module")
    module_select_options = []
    available_modules = get_modules()

    for module_name, module in available_modules:
        module_doc = _get_doc(module.__doc__)
        module_doc_display = f": {module_doc.split('.')[0]}" if module_doc else ""
        module_select_options.append((module_name, f"{module_name}{module_doc_display}"))

    if not module_select_options:
        error_notice = TextParam(name="no_modules_error", type="text", value="Critical Error: No SaQC modules found to populate methods.", label="Configuration Error")
        methods_repeat.append(error_notice)
        return methods_repeat

    module_select = SelectParam(name="module_select", label="SaQC Module", options=dict(module_select_options), optional=False, help="Select the SaQC module.")
    module_conditional.append(module_select)

    for module_name, module in available_modules:
        module_when = When(value=module_name)
        methods = get_methods(module)
        if methods:
            methods_conditional_section = get_methods_conditional(methods, module)
            if methods_conditional_section:
                 module_when.append(methods_conditional_section)
            else:
                 no_methods_notice = TextParam(name=f"{module_name}_no_configurable_methods", type="text", value=f"Info: No configurable methods were processed for module '{module_name}'.", label="Module Info")
                 module_when.append(no_methods_notice)
        else:
             no_methods_found_notice = TextParam(name=f"{module_name}_no_methods", type="text", value=f"Info: No SaQC methods were detected for module '{module_name}'.", label="Module Info")
             module_when.append(no_methods_found_notice)
        module_conditional.append(module_when)

    methods_repeat.append(module_conditional)
    return methods_repeat

def get_methods_conditional(methods, module):
    method_conditional = Conditional(name="method_cond", label="Method")
    method_select_options = []
    if not methods:
        return None

    for method_obj in methods:
        method_name = method_obj.__name__
        method_doc = _get_doc(method_obj.__doc__)
        method_doc_display = f": {method_doc.split('.')[0]}" if method_doc else ""
        method_select_options.append((method_name, f"{method_name}{method_doc_display}"))

    if not method_select_options:
        return None

    method_select = SelectParam(name="method_select", label="Method", options=dict(method_select_options), optional=False)
    method_conditional.append(method_select)

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
            sys.stderr.write(f"Skipping params for {method_name} in {module.__name__} due to ValueError: {e}\n")
            param_error_notice = TextParam(name=f"{method_name}_param_error", type="text", value=f"Error generating parameters for this method: {e}", label="Parameter Error")
            method_when.append(param_error_notice)
        method_conditional.append(method_when)

    return method_conditional


# --- Tool Definition ---
tool = Tool(
    "SaQC",
    "saqc",
    version="@TOOL_VERSION@+galaxy@VERSION_SUFFIX@",
    description="quality control pipelines for environmental sensor data",
    executable="saqc",
    macros=["macros.xml"],
    profile="22.01",
    version_command="python -c 'import saqc; print(saqc.__version__)'",
)
tool.help = """
**SaQC: Standardized Quality Control for Sensor Data**

This tool allows you to build and apply quality control pipelines to your data using the SaQC library.

**Execution Modes:**

* **Productive Mode:** For actual data processing. You will provide input data, configure QC methods, and receive processed data, a configuration file, and optional plots.
* **Test Mode:** For exploring parameters and pipeline structure without input data. You can configure QC methods, and the tool will output a JSON file containing all your parameter settings. This is useful for understanding the tool's capabilities and for debugging configurations.

**General Workflow (Productive Mode):**

1.  Select "Productive Mode".
2.  Upload your input data table(s) (CSV format). (This is the parameter named 'Input table' in this mode).
3.  Click "Insert QC Methods" to add one or more quality control steps.
4.  For each method:
    * Choose the SaQC **Module** (e.g., `outliers`, `generic`).
    * Choose the specific **Method** from that module (e.g., `flagRange`, `processGeneric`).
    * Configure the parameters for the selected method. Help text is available for most parameters.
5.  Run the tool.

**Test Mode Workflow:**

1.  Select "Test Mode".
2.  (No input data is uploaded in this mode)
3.  Click "Insert QC Methods" and configure methods and parameters as you would in productive mode.
    You can enter dummy values for parameters like 'field' or 'target'.
4.  Run the tool.
5.  The output will be a JSON file detailing all the parameters you selected.
"""

# Command block handles mode switching
tool.command_override = ["""
#set $mode_cond = $execution_mode_cond
#set $mode = $mode_cond.mode_select
#set $param_conf_file = "params.json"

echo "$param_conf" > $param_conf_file &&

#if $mode == "productive"
  '$__tool_directory__'/json_to_saqc_config.py --config-json $param_conf_file --productive-mode --saqc-config-out saqc_config.json &&

  #set $productive_data_inputs = $mode_cond.data 
  #if not isinstance($productive_data_inputs, list)
    #set $productive_data_inputs = [$productive_data_inputs]
  #end if

  #for $i, $d in enumerate($productive_data_inputs)
    #if $d
        ln -s '$d' '${i}.csv' &&
    #end if
  #end for

  saqc --config saqc_config.json
  #for $i, $d in enumerate($productive_data_inputs)
    #if $d
        --data '${i}.csv:"${d.element_identifier}"'
    #end if
  #end for
  --outfile output.csv 

#elif $mode == "test"
  cp $param_conf_file test_parameter_summary.json &&
  echo "Test mode: Parameters collected in test_parameter_summary.json. You can download this file from the outputs." >&2
#end if
"""]


tool.configfiles = Configfiles()
tool.configfiles.append(ConfigfileDefaultInputs(name="param_conf"))

inputs_obj = tool.inputs = Inputs()

execution_mode_cond = Conditional(name="execution_mode_cond")
options_for_mode_select = {
    "productive": "Productive Mode",
    "test": "Test Mode"
}
mode_select_param = SelectParam(
    name="mode_select", 
    label="Execution Mode",
    help="Choose 'Productive' for actual data processing or 'Test' to explore parameters without data.",
    options=options_for_mode_select,
    value="productive"
)
execution_mode_cond.append(mode_select_param)

# --- Productive Mode Inputs ---
productive_when = When(value="productive")
# KORRIGIERT: name="data" für Test-Kompatibilität (wird zu $execution_mode_cond.data)
productive_when.append(DataParam(name="data", 
                                  type="data", format="csv", multiple=True,
                                  label="Input table", # Ursprüngliches Label
                                  help="One or more CSV files for SaQC processing."))
productive_when.append(build_methods_repeat_structure())
execution_mode_cond.append(productive_when)

# --- Test Mode Inputs ---
test_when = When(value="test")
# KORRIGIERT: area als kwarg, readonly entfernt
test_mode_info_text = TextParam(name="test_mode_info", type="text",
                                value="Test Mode: Configure methods and parameters below. No input data is required. Parameter settings will be collected.",
                                label="Test Mode Information", area=True)
test_when.append(test_mode_info_text)
test_when.append(build_methods_repeat_structure())
execution_mode_cond.append(test_when)

inputs_obj.append(execution_mode_cond)


# --- Outputs (Alle deklariert, Command erzeugt sie selektiv, keine XML-Filter) ---
outputs_obj = tool.outputs = Outputs()

# Produktive Outputs mit ursprünglichen Namen
outputs_obj.append(OutputData(name="output", format="csv", from_work_dir="output.csv", 
                              label="${tool.name} on ${on_string}: Processed Data"))
outputs_obj.append(OutputData(name="config", format="txt", from_work_dir="saqc_config.json", 
                              label="${tool.name} on ${on_string}: SaQC Configuration File (JSON)")) # from_work_dir angepasst
productive_plots_collection = OutputCollection(name="plots", type="list", 
                                            label="${tool.name} on ${on_string}: Plots")
productive_plots_collection.append(DiscoverDatasets(pattern=r".*\.png", ext="png", visible=True))
outputs_obj.append(productive_plots_collection)

# Test Mode Output
outputs_obj.append(OutputData(name="test_parameter_summary", format="json", from_work_dir="test_parameter_summary.json",
                              label="${tool.name}: Collected Test Parameters (JSON)"))

print(tool.export())