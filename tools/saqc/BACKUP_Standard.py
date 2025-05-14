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
    doc_str_lines = [x for x in doc_str.split("\n") if x.strip() != ""] # Geändert auf strip()
    if not doc_str_lines:
        return ""
    doc_str = doc_str_lines[0]
    doc_str = doc_str.strip(" .,")
    return doc_str


def parse_docstring(method: Callable) -> Dict[str, str]:
    """
    parse sections from rst formatted doc string

    returns a mapping from section titles to section contents
    1st section title may be ''
    """

    docstring = method.__doc__
    if not docstring:
        return {} # KORRIGIERT

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
            parameter_doc[pname] = "\n".join(l.strip() for l in lines if l.strip() or l == "").strip()
            
    return parameter_doc


def get_label_help(param_name, parameter_docs):
    parameter_doc_entry = parameter_docs.get(param_name)
    if not parameter_doc_entry:
        return param_name, ""

    full_help = parameter_doc_entry.strip()
    label = param_name

    if full_help:
        first_line_of_help = full_help.split('\n')[0].strip()
        sentence_match = re.match(r"([^.!?]+(?:[.!?](?=\s|$)|[.!?]$|$))", first_line_of_help) 
        if sentence_match:
            label_candidate = sentence_match.group(1).strip()
            if len(label_candidate) < 80 : 
                label = label_candidate
            else: 
                label = (first_line_of_help[:77] + "...") if len(first_line_of_help) > 80 else first_line_of_help
        elif first_line_of_help: 
            label = (first_line_of_help[:77] + "...") if len(first_line_of_help) > 80 else first_line_of_help
        
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
    sections = parse_docstring(method) # Korrekter Aufruf
    param_docs = parse_parameter_docs(sections)

    xml_params = []
    try:
        parameters = inspect.signature(method).parameters
    except (ValueError, TypeError) as e:
         sys.stderr.write(f"Warning: Could not get signature for {method.__name__}: {e}. Skipping params.\n")
         return xml_params

    for param_name, param in parameters.items():
        if param_name in ["self", "kwargs", "store_kwargs", "ax_kwargs"]: # Beibehaltung der Ignorierliste
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
             sys.stderr.write(f"Warning: Annotation '{annotation}' for {param_name} in {method.__name__} resolved to string. Treating as Any.\n") # Beibehaltung Warnung
             annotation = Any # Fallback, wenn eval zu string führt

        origin = get_origin(annotation)
        args = get_args(annotation)

        if param.default is inspect.Parameter.empty:
            default = None
        else:
            default = param.default

        label, help_text = get_label_help(param_name, param_docs) # help umbenannt zu help_text
        param_constructor_args = {"label": label, "help": help_text} # Umbenannt von kwargs

        is_union = is_union_type(annotation)

        if param.default is None:
            optional = True
        elif is_union and any(a is type(None) for a in args):
            optional = True
        else:
            optional = False
        
        param_constructor_args['optional'] = optional

        # KORRIGIERTE Logik für 'value' Zuweisung
        # Ziel: 'value' nur setzen, wenn es einen sinnvollen Default gibt.
        # Für optionale Parameter mit Default=None, 'value' nicht setzen.
        # Für nicht-optionale Parameter ohne Default, 'value=""' setzen.
        has_explicit_value = False
        if param.default is not inspect.Parameter.empty:
            if param.default is not None:
                if not isinstance(param.default, bool): # Booleans werden über 'checked' gehandhabt
                     param_constructor_args['value'] = str(param.default)
                     has_explicit_value = True
            # else: Python default ist None. Wenn optional, wollen wir keinen 'value' im XML.
            #       Wenn nicht-optional, muss 'value=""' gesetzt werden (siehe unten).
        
        if not optional and not has_explicit_value:
            # Parameter ist nicht optional und hat keinen (Nicht-None) Default aus Python.
            # Er MUSS einen 'value' im XML haben, um planemo test zu bestehen.
            param_constructor_args['value'] = ""


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
        
        # --- Parametergenerierungslogik (basierend auf Nutzer-Skript, mit angepassten param_constructor_args) ---
        if param_name in ["field", "target"]:
            is_multi = False
            if origin in (list, Sequence) and args and args[0] == str: is_multi = True
            elif annotation == list[str] or annotation == Sequence[str]: is_multi = True

            if annotation != str and is_multi:
                 parent = Repeat(name=f"{param_name}_repeat", title=f"{param_name.capitalize()}(s)", min=1)
                 inner_param_attrs = {"label": f"Name for {param_name}", "help": help_text, "optional": False, "value": ""}
                 parent.append(TextParam(argument=param_name, **inner_param_attrs))
                 xml_params.append(parent)
            elif annotation == str:
                 xml_params.append(TextParam(argument=param_name, **param_constructor_args))
            else: 
                 xml_params.append(TextParam(argument=param_name, **param_constructor_args))
                 # sys.stderr.write(f"Warning: Treating complex type {annotation} for parameter '{param_name}' as TextParam.\n") # War im Original

        elif origin is None and not is_union :
            if annotation == bool:
                cli_argument_format = f"--{param_name}"
                # 'value' aus param_constructor_args für BooleanParam entfernen, da 'checked' verwendet wird
                bool_attrs = {k:v for k,v in param_constructor_args.items() if k != 'value'}
                xml_params.append(BooleanParam(argument=cli_argument_format, truevalue=cli_argument_format, falsevalue="", 
                                               checked=True if default is True else False, **bool_attrs))
            elif annotation == str:
                xml_params.append(TextParam(argument=param_name, **param_constructor_args))
            elif annotation == int:
                 xml_params.append(IntegerParam(argument=param_name, **param_constructor_args))
            elif annotation == float:
                 xml_params.append(FloatParam(argument=param_name, **param_constructor_args))
            elif is_callable_type(annotation) or annotation in (GenericFunction, CurveFitter, Any, slice, mpl.axes.Axes):
                 if is_callable_type(annotation):
                    callable_args_repr = str(get_args(annotation)) if hasattr(annotation, '__args__') else '(...)'
                    param_constructor_args["help"] += f"\n(Expects a function reference: {callable_args_repr}. Default: {default})"
                    # Für Callables, die als Text eingegeben werden, ist ein leerer Default-Wert oft besser
                    # es sei denn, der SaQC-Default ist ein sinnvoller String (z.B. Name einer Builtin-Funktion)
                    current_callable_attrs = {**param_constructor_args}
                    if 'value' not in current_callable_attrs or not isinstance(default, str) : 
                        current_callable_attrs['value'] = "" 
                    xml_params.append(TextParam(argument=param_name, **current_callable_attrs))
                 # else: Original-Skript hatte hier ein sys.stderr.write, das spezifische Typen ignoriert
            elif hasattr(annotation, '__mro__') and pd.Timedelta in annotation.__mro__:
                 param_constructor_args["help"] += "\n(Pandas timedelta string, e.g., '1D', '2H30M')"
                 xml_params.append(TextParam(argument=param_name, **param_constructor_args))
            else: 
                 # sys.stderr.write(f"Warning: Unknown simple parameter type {annotation}: {param_name} in {method.__name__}. Treating as TextParam.\n") # War im Original
                 xml_params.append(TextParam(argument=param_name, **param_constructor_args)) # Fallback

        elif origin is Union and str in args and pd.Timedelta in args:
             param_constructor_args["help"] += "\n(Pandas timedelta string or offset, e.g., '1D', '2H30M')"
             xml_params.append(TextParam(argument=param_name, **param_constructor_args))

        elif origin is Union and all(el_type in args for el_type in (str, Tuple[str,str])) and len(args)==2 :
            param_constructor_args["help"] += "\n(String or two comma-separated strings, e.g., val1,val2)"
            xml_params.append(TextParam(argument=param_name, **param_constructor_args))

        elif origin is Union and all(el_type in args for el_type in (int, Tuple[int,int])) and len(args)==2 :
            param_constructor_args["help"] += "\n(Integer or two comma-separated integers, e.g., 1,2)"
            xml_params.append(TextParam(argument=param_name, **param_constructor_args))
        
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
            number_param_attrs = {**param_constructor_args, "optional": False, "label": f"{label} (as number)"}
            if isinstance(default, int): number_param_attrs['value'] = str(default)
            elif 'value' not in number_param_attrs : number_param_attrs['value'] = "" 
            when_number.append(IntegerParam(argument=param_name, **number_param_attrs))
            cond.append(when_number)

            when_timedelta = When(value="timedelta")
            timedelta_param_attrs = {**param_constructor_args, "optional": False, "label": f"{label} (as timedelta string)"}
            if isinstance(default, str): timedelta_param_attrs['value'] = default
            elif 'value' not in timedelta_param_attrs: timedelta_param_attrs['value'] = ""
            when_timedelta.append(TextParam(argument=param_name, **timedelta_param_attrs))
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
            float_param_attrs = {**param_constructor_args, "optional": False, "label": f"{label} ({cond_options.get('number', num_label)})"}
            if isinstance(default, float): float_param_attrs['value'] = str(default)
            elif 'value' not in float_param_attrs: float_param_attrs['value'] = ""
            when_number.append(FloatParam(argument=param_name, **float_param_attrs))
            cond.append(when_number)

            when_str_offset = When(value="offset") 
            str_param_attrs = {**param_constructor_args, "optional": False, "label": f"{label} ({cond_options.get('offset', str_label)})"}
            if isinstance(default, str): str_param_attrs['value'] = default
            elif 'value' not in str_param_attrs: str_param_attrs['value'] = ""
            when_str_offset.append(TextParam(argument=param_name, **str_param_attrs))
            cond.append(when_str_offset)

            if "none" in cond_options:
                when_none = When(value="none")
                when_none.append(HiddenParam(name=param_name, value="__none__"))
                cond.append(when_none)
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
                    list_val_str = ",".join(map(str,default)) if isinstance(default, list) else ""
                    list_param_attrs = {**param_constructor_args, "optional":False, "label": f"{label} (comma-separated)"}
                    if list_val_str: list_param_attrs['value'] = list_val_str
                    elif 'value' not in list_param_attrs: list_param_attrs['value'] = ""
                    current_when.append(TextParam(argument=param_name, **list_param_attrs))
                elif opt_key == "none":
                    current_when.append(HiddenParam(name=param_name, value="__none__"))
                else: 
                    current_when.append(HiddenParam(name=param_name, value=opt_key))
                cond.append(current_when)
            xml_params.append(cond)

        elif origin is Union and any(get_origin(a) is Literal and "auto" in get_args(a) for a in args) and float in args:
             has_callable_opt = any(is_callable_type(a) for a in args)
             cond = Conditional(name=f"{param_name}_cond")
             select_param_name = f"{param_name}_select_type"
             cond_options = {"auto": "Automatic ('auto')", "float": "Specific Value (float)"}
             if has_callable_opt: cond_options["custom"] = "Custom Callable"
             if optional: cond_options["none"] = "None (use default)"
             
             select_default_val=None 
             if default == "auto": select_default_val = "auto"
             elif isinstance(default, float): select_default_val = "float"
             elif has_callable_opt and (callable(default) or (isinstance(default, str) and default not in ["auto"])): select_default_val = "custom"
             elif optional and default is None: select_default_val = "none"
             if select_default_val not in cond_options and cond_options: select_default_val = list(cond_options.keys())[0]

             cond.append(SelectParam(name=select_param_name, label=f"{label} Mode", options=cond_options, value=select_default_val, optional=False))
             
             when_auto = When(value="auto"); when_auto.append(HiddenParam(name=param_name, value="auto")); cond.append(when_auto)
             
             when_float = When(value="float")
             kwargs_floatval = {**param_constructor_args, "optional": False, "label": f"{label} (float value)"}
             if isinstance(default,float): kwargs_floatval['value'] = str(default)
             elif 'value' not in kwargs_floatval: kwargs_floatval['value'] = ""
             when_float.append(FloatParam(argument=param_name, **kwargs_floatval))
             cond.append(when_float)
             
             if has_callable_opt:
                 when_custom = When(value="custom")
                 kwargs_customval = {**param_constructor_args, "optional": False, "label": f"{label} (custom callable name)"}
                 custom_default_val_str = str(default) if isinstance(default, str) and default!="auto" else ""
                 if custom_default_val_str : kwargs_customval['value'] = custom_default_val_str
                 elif 'value' not in kwargs_customval: kwargs_customval['value'] = ""
                 when_custom.append(TextParam(argument=param_name, **kwargs_customval))
                 cond.append(when_custom)

             if "none" in cond_options:
                 when_none = When(value="none"); when_none.append(HiddenParam(name=param_name, value="__none__")); cond.append(when_none)
             xml_params.append(cond)
        
        elif origin is Literal:
             literal_options = dict([(str(o), str(o)) for o in args]) 
             select_val = str(default) if default in args else None 
             current_literal_attrs = {**param_constructor_args} 
             if select_val is not None: current_literal_attrs['value'] = select_val
             elif 'value' in current_literal_attrs and not optional : current_literal_attrs['value'] = "" 
             elif 'value' in current_literal_attrs and optional : del current_literal_attrs['value']
             xml_params.append(SelectParam(argument=param_name, options=literal_options, **current_literal_attrs))

        elif (origin is Union and any(is_callable_type(a) for a in args) and
              any(get_origin(a) is Literal and all(lit_val in get_args(a) for lit_val in ("linear", "exponential")) for a in args)):
            cond = Conditional(name=f"{param_name}_cond")
            select_param_name = f"{param_name}_select_type"
            cond_options = {"linear": "Linear Model", "exponential": "Exponential Model", "custom": "Custom Callable"}
            if optional: cond_options["none"] = "None (use default)"

            select_default_val = None 
            if default in ("linear", "exponential"): select_default_val = default
            elif callable(default) or (isinstance(default, str) and default not in ("linear", "exponential")): select_default_val = "custom"
            elif optional and default is None: select_default_val = "none"
            if select_default_val not in cond_options and cond_options: select_default_val = list(cond_options.keys())[0]

            cond.append(SelectParam(name=select_param_name, label=f"{label} Model Type", options=cond_options, value=select_default_val, optional=False))

            when_linear = When(value="linear"); when_linear.append(HiddenParam(name=param_name, value="linear")); cond.append(when_linear)
            when_exp = When(value="exponential"); when_exp.append(HiddenParam(name=param_name, value="exponential")); cond.append(when_exp)
            
            when_custom = When(value="custom")
            kwargs_custom_call = {**param_constructor_args, "optional": False, "label": f"{label} (Custom Callable Name)"}
            custom_default_val_str = str(default) if isinstance(default, str) and default not in ("linear", "exponential") else ""
            if custom_default_val_str: kwargs_custom_call['value'] = custom_default_val_str
            elif 'value' not in kwargs_custom_call: kwargs_custom_call['value'] = ""
            when_custom.append(TextParam(argument=param_name, **kwargs_custom_call))
            cond.append(when_custom)

            if "none" in cond_options:
                when_none = When(value="none"); when_none.append(HiddenParam(name=param_name, value="__none__")); cond.append(when_none)
            xml_params.append(cond)

        elif origin in (pd.Series, pd.DataFrame, DictOfSeries, list, np.ndarray) or \
             (origin is Union and any(o_arg in (pd.Series, pd.DataFrame, DictOfSeries, list, np.ndarray) for o_arg in args)):
            param_constructor_args["help"] += "\n(Name of another data field/column or comma-separated list of columns)"
            xml_params.append(TextParam(argument=param_name, **param_constructor_args))

        elif origin is Sequence and not (isinstance(annotation, type) and annotation == Sequence[ForwardRef("SaQC")]): # type: ignore
             param_constructor_args["help"] += "\n(Enter items separated by commas, e.g., val1,val2,val3)"
             current_seq_attrs = {**param_constructor_args}
             if isinstance(default, Sequence) and not isinstance(default, str) :
                 current_seq_attrs['value'] = ",".join(map(str, default))
             # Ensure value is set if not optional and no other default was applicable
             elif 'value' not in current_seq_attrs and not param_constructor_args.get('optional', False): 
                 current_seq_attrs['value'] = ""
             elif 'value' in current_seq_attrs and param_constructor_args.get('optional', False) and current_seq_attrs.get('value') is None:
                 del current_seq_attrs['value']
             xml_params.append(TextParam(argument=param_name, **current_seq_attrs))
        
        elif isinstance(annotation, type) and (annotation == Sequence[ForwardRef("SaQC")] or annotation == dict[ForwardRef("SaQC"), Union[str, Sequence[str]]]): # type: ignore
            sys.stderr.write(f"Ignoring specific complex SaQC sequence/dict parameter {param_name} ({method.__name__})\n")

        else:
             # sys.stderr.write(f"Warning: Parameter '{param_name}' of type {annotation} (origin: {origin}, args: {args}) in method '{method.__name__}' is falling back to TextParam.\n") # Auskommentiert, da viele Warnings
             xml_params.append(TextParam(argument=param_name, **param_constructor_args))
    return xml_params


def get_methods_conditional(methods, module): # Wie im Basis-Skript des Nutzers
    method_conditional = Conditional(name="method_cond", label="Method")
    method_select_options = []
    if not methods:
        return None

    for method in methods: # method_obj zu method geändert
        method_name = method.__name__
        method_doc = _get_doc(method.__doc__)
        if not method_doc:
            method_doc = method_name
        method_select_options.append((method_name, f"{method_name}: {method_doc}"))

    if method_select_options:
        method_select = SelectParam(
            name="method_select", label="Method", options=dict(method_select_options), optional=False
        )
        method_conditional.append(method_select)
    else:
         return None

    for method in methods: # method_obj zu method geändert
        method_name = method.__name__
        method_when = When(value=method_name)
        try:
            params = get_method_params(method, module) # method statt method_obj
            if not params :
                 no_params_notice = TextParam(name=f"{method_name}_no_params_notice", type="text", value="This method has no configurable parameters.", label="Info")
                 method_when.append(no_params_notice)
            else:
                for p in params:
                    method_when.append(p)
        except ValueError as e:
            sys.stderr.write(
                f"Skipping params for {method_name} in {module.__name__} due to {e}\n"
            )
            param_error_notice = TextParam(name=f"{method_name}_param_error", type="text", value=f"Error generating parameters for this method: {e}", label="Parameter Error")
            method_when.append(param_error_notice)
        method_conditional.append(method_when)

    return method_conditional


# --- Original-Struktur des Nutzerskripts für Tool-Definition, Inputs, Outputs, Command ---
# KEINE Modus-Umschaltung hier, da vom Nutzer explizit für diesen Schritt zurückgestellt.

command_override = ["""
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
 """]

tool = Tool(
    "SaQC",
    "saqc",
    version="@TOOL_VERSION@+galaxy@VERSION_SUFFIX@",
    description="quality control pipelines for environmental sensor data",
    executable="saqc",
    macros=["macros.xml"],
    command_override=command_override,
    profile="22.01",
    version_command="python -c 'import saqc; print(saqc.__version__)'",
)
tool.help = "TODO"

tool.configfiles = Configfiles()
tool.configfiles.append(ConfigfileDefaultInputs(name="param_conf"))
inputs = tool.inputs = Inputs() # Beibehaltung von 'inputs' als Variablenname
inputs.append(DataParam(argument="--data", format="csv", multiple=True, label="Input table"))

# Originale methods_repeat Struktur direkt hier, wie im Nutzer-Basis-Skript
modules = get_modules()
module_repeat = Repeat(name="methods_repeat", title="Methods")
inputs.append(module_repeat) # methods_repeat zu inputs hinzufügen
module_conditional = Conditional(name="module_cond", label="Module")
module_select_options = []
for module_name, module in modules:
    module_doc = _get_doc(module.__doc__)
    if not module_doc:
        module_doc = module_name
    module_select_options.append((module_name, f"{module_name}: {module_doc}"))

if module_select_options:
    module_select = SelectParam(
        name="module_select", label="saqc module", options=dict(module_select_options), optional=False
    )
    module_conditional.append(module_select)
else:
     # Original-Skript fügte hier nichts zu inputs hinzu, wenn keine Module da waren
     # Um einen Fehler zu vermeiden, wenn keine Module da sind (unwahrscheinlich):
     pass

for module_name, module in modules:
    module_when = When(value=module_name)
    methods = get_methods(module)
    if methods:
        methods_conditional_obj = get_methods_conditional(methods, module) # Renamed
        if methods_conditional_obj:
             module_when.append(methods_conditional_obj)
        else:
             # readonly entfernt
             module_when.append(TextParam(name=f"{module_name}_no_methods_notice", type="text", value=f"No configurable methods found or processed for module '{module_name}'.", label="Notice"))
    else:
        # readonly entfernt
        module_when.append(TextParam(name=f"{module_name}_no_methods_found", type="text", value=f"No SaQC methods detected for module '{module_name}'.", label="Notice"))
    module_conditional.append(module_when)

if module_select_options: # Nur hinzufügen, wenn es Optionen gab
    module_repeat.append(module_conditional)


outputs = tool.outputs = Outputs()
outputs.append(OutputData(name="output", format="csv", from_work_dir="output.csv", label="${tool.name} on ${on_string}: Processed Data"))
plot_outputs = OutputCollection(
    name="plots", type="list", label="${tool.name} on ${on_string}: Plots"
)
plot_outputs.append(DiscoverDatasets(pattern=r"(?P<name>.*)\.png", ext="png"))
outputs.append(OutputData(name="config", format="txt", from_work_dir="config.csv", label="${tool.name} on ${on_string}: Configuration File"))
outputs.append(plot_outputs)

print(tool.export())