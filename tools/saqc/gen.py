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
#from saqc.funcs.interpolation import INTERPOLATION_METHODS # Auskommentiert wie im Original
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
        if not line.startswith("    ") and not line.startswith("\t\t"): # Adjusted indentation check
            match = param_start_pattern.match(original_line_stripped)

        if match:
            if current_param:
                parameter_doc[current_param] = "\n".join(current_lines).strip()

            current_param = match.group("param_name")
            current_lines = [original_line_stripped] # Start with the matched line
        elif current_param:
            # Only append if it's an indented line, otherwise it might be a new param missed by regex
            if line.startswith("    ") or line.startswith("\t\t") or not param_start_pattern.match(original_line_stripped):
                 current_lines.append(original_line_stripped)
            else: # It looks like a new parameter, process the old one
                if current_param:
                    parameter_doc[current_param] = "\n".join(current_lines).strip()
                # This new line is a parameter itself
                new_match = param_start_pattern.match(original_line_stripped)
                if new_match:
                    current_param = new_match.group("param_name")
                    current_lines = [original_line_stripped]
                else: # Should not happen if logic is correct
                    current_param = None
                    current_lines = []


    if current_param: # Process the last parameter
        parameter_doc[current_param] = "\n".join(current_lines).strip()

    for pname, pdoc in parameter_doc.items():
        lines = pdoc.split('\n')
        if lines:
            # More robust cleaning of the first line
            first_line = lines[0]
            # Remove "param_name : type"
            cleaned_first_line = re.sub(r"^\s*{}\s*:\s*[^-\n]+?\s*--\s*".format(re.escape(pname)), "", first_line, count=1).strip()
            if first_line.strip() == cleaned_first_line and ":" in first_line: # if no type was found by '---'
                 cleaned_first_line = re.sub(r"^\s*{}\s*:\s*".format(re.escape(pname)), "", first_line, count=1).strip()

            # If still starts with param_name (e.g., no type info or ':' was present)
            if cleaned_first_line.startswith(pname):
                cleaned_first_line = re.sub(r"^\s*{}".format(re.escape(pname)),"", cleaned_first_line, count=1).strip()

            lines[0] = cleaned_first_line
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
        # Try to get the first sentence for the label
        sentence_match = re.match(r"([^.!?]+(?:[.!?](?=\s|$)|[.!?]$|$))", first_line_of_help)
        if sentence_match:
            label_candidate = sentence_match.group(1).strip()
            # Make label concise, max 80 chars, otherwise truncate
            if len(label_candidate) < 80 :
                label = label_candidate
            else: # Truncate and add ellipsis
                label = (first_line_of_help[:77] + "...") if len(first_line_of_help) > 80 else first_line_of_help
        elif first_line_of_help: # Fallback if no sentence structure found
            label = (first_line_of_help[:77] + "...") if len(first_line_of_help) > 80 else first_line_of_help
        
        if not label.strip(): # Ensure label is not empty
            label = param_name # Fallback to param_name if everything else fails
            
    return label, full_help


def get_modules() -> Tuple[str, "ModuleType"]:
    return inspect.getmembers(saqc.funcs, inspect.ismodule)


def get_methods(module):
    methods_with_saqc = []
    classes = inspect.getmembers(module, inspect.isclass)
    for name, cls in classes:
        if inspect.ismodule(cls): # Skip imported modules re-exported as classes
            continue
        methods = inspect.getmembers(cls, inspect.isfunction)
        for method_name, method in methods:
            try:
                parameters = inspect.signature(method).parameters
                if "self" in parameters:
                    self_param = parameters["self"]
                    # Check annotation of self for SaQC
                    annotation_str = None
                    if isinstance(self_param.annotation, str):
                         annotation_str = self_param.annotation.strip("'")
                    elif isinstance(self_param.annotation, ForwardRef):
                         annotation_str = self_param.annotation.__forward_arg__.strip("'")
                    elif hasattr(self_param.annotation, '__name__'): # For direct type annotation
                         annotation_str = self_param.annotation.__name__

                    if annotation_str == 'SaQC':
                         methods_with_saqc.append(method)
            except (ValueError, TypeError) as e: # Handle cases where signature can't be inspected
                 sys.stderr.write(f"Warning: Could not inspect signature for {cls.__name__}.{method_name}: {e}\n")
                 continue # Skip this method
    return methods_with_saqc


def get_method_params(method, module):
    sections = parse_docstring(method)
    param_docs = parse_parameter_docs(sections)

    xml_params = []
    try:
        parameters = inspect.signature(method).parameters
    except (ValueError, TypeError) as e: # Handle cases where signature can't be obtained
         sys.stderr.write(f"Warning: Could not get signature for {method.__name__}: {e}. Skipping params for this method.\n")
         return xml_params # Return empty list if signature fails

    for param_name, param in parameters.items():
        if param_name in ["self", "kwargs", "store_kwargs", "ax_kwargs"]:
            continue
        annotation = param.annotation

        # Attempt to resolve string annotations or ForwardRefs
        if isinstance(annotation, str):
             try:
                 # Broader context for eval, including more SaQC internals
                 eval_context = {**globals(), **module.__dict__, **saqc.__dict__, **saqc.lib.types.__dict__, **saqc.funcs.__dict__}
                 # Add common types directly to context
                 eval_context.update({'pd': pd, 'np': np, 'mpl': mpl, 'Union': Union, 'Literal': Literal, 'Sequence': Sequence, 'Callable': Callable, 'Any': Any, 'Tuple': Tuple, 'Dict': Dict})
                 # Include all submodules of saqc.funcs for robustness
                 for m_name, m_obj in inspect.getmembers(saqc.funcs, inspect.ismodule):
                     eval_context[m_name] = m_obj
                 annotation = eval(annotation, eval_context)
             except Exception: # Broad exception catch for eval issues
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

        if annotation is inspect.Parameter.empty: # Parameter.empty means no annotation
             sys.stderr.write(f"Warning: Missing type annotation for parameter '{param_name}' in method '{method.__name__}'. Treating as Any.\n")
             annotation = Any # Fallback to Any if no annotation
        
        if isinstance(annotation, str): # If eval still results in a string (e.g., unresolvable type)
             sys.stderr.write(f"Warning: Annotation '{annotation}' for parameter '{param_name}' in method '{method.__name__}' resolved to a string. Treating as Any.\n")
             annotation = Any # Fallback to Any

        origin = get_origin(annotation)
        args = get_args(annotation)

        # Determine Python default
        default = param.default if param.default is not inspect.Parameter.empty else None

        label, help_text = get_label_help(param_name, param_docs)
        param_constructor_args = {"label": label, "help": help_text}

        # Determine optionality for XML
        is_python_optional = (param.default is not inspect.Parameter.empty)
        is_union_with_none = is_union_type(annotation) and type(None) in args
        optional = is_python_optional or is_union_with_none # XML optional if Python has default OR it's Union[T, None]
        param_constructor_args['optional'] = optional


        # Base 'value' assignment logic for XML parameter
        # This 'value' might be overridden later by specific conditional logic if param.default isn't the right type for a branch
        has_explicit_value_for_xml = False
        if param.default is not inspect.Parameter.empty and param.default is not None:
            if not isinstance(param.default, bool): # Booleans use 'checked'
                 param_constructor_args['value'] = str(param.default)
                 has_explicit_value_for_xml = True
            # else: for bools, 'checked' handles it.
        # else: Python default is None or not provided.

        # If not optional in XML AND no explicit non-None default was set, XML needs value=""
        if not optional and not has_explicit_value_for_xml:
            param_constructor_args['value'] = ""
        # If optional AND the Python default was None (and thus 'value' not set yet),
        # we DON'T want to add value="" as it's truly optional with no default.
        # galaxyxml typically omits 'value' for optional params without explicit default.

        # Simplify annotation if it's Union[T, None]
        if is_union_with_none:
            args_wo_none = [a for a in args if a is not type(None)]
            if len(args_wo_none) == 1:
                annotation = args_wo_none[0]
                origin = get_origin(annotation) # Re-evaluate origin and args
                args = get_args(annotation)
                is_union = False # It's no longer a Union for type checking purposes
            elif len(args_wo_none) > 1: # Union[A, B, None] -> Union[A, B]
                 annotation = Union[tuple(args_wo_none)]
                 origin = get_origin(annotation)
                 args = get_args(annotation)
                 # is_union remains True
            else: # Union[NoneType] or unhandled case
                 annotation = Any
                 origin = None
                 args = ()
                 is_union = False


        # --- Parameter generation logic starts here ---
        if param_name in ["field", "target"]:
            is_multi = False
            if origin in (list, Sequence) and args and args[0] == str: is_multi = True
            elif annotation == list[str] or annotation == Sequence[str]: is_multi = True # More direct check

            if is_multi: # If annotation is list[str] or Sequence[str]
                 parent = Repeat(name=f"{param_name}_repeat", title=f"{param_name.capitalize()}(s)", min=1)
                 # Inner param should not be optional, and needs a value for planemo
                 inner_param_attrs = {k:v for k,v in param_constructor_args.items() if k not in ['value', 'optional']}
                 inner_param_attrs.update({"label": f"Name for {param_name}", "optional": False, "value": ""})
                 parent.append(TextParam(argument=param_name, **inner_param_attrs))
                 xml_params.append(parent)
            elif annotation == str: # Single string
                 xml_params.append(TextParam(argument=param_name, **param_constructor_args))
            else: # Fallback for unexpected types for field/target (should ideally be str or list[str])
                 sys.stderr.write(f"Warning: Parameter '{param_name}' expected str or List[str], got {annotation}. Treating as TextParam.\n")
                 xml_params.append(TextParam(argument=param_name, **param_constructor_args))

        elif origin is None and not is_union_type(annotation) : # Simple, non-Union types
            if annotation == bool:
                cli_argument_format = f"--{param_name}"
                # For BooleanParam, 'value' is not used; 'checked' is.
                bool_attrs = {k:v for k,v in param_constructor_args.items() if k != 'value'}
                bool_attrs['checked'] = True if param.default is True else False # Default for checked
                xml_params.append(BooleanParam(argument=cli_argument_format, truevalue=cli_argument_format, falsevalue="", **bool_attrs))
            elif annotation == str:
                xml_params.append(TextParam(argument=param_name, **param_constructor_args))
            elif annotation == int:
                 xml_params.append(IntegerParam(argument=param_name, **param_constructor_args))
            elif annotation == float:
                 xml_params.append(FloatParam(argument=param_name, **param_constructor_args))
            elif is_callable_type(annotation) or annotation in (GenericFunction, CurveFitter, Any, slice, mpl.axes.Axes):
                 if is_callable_type(annotation):
                    callable_args_repr = str(get_args(annotation)) if hasattr(annotation, '__args__') else '(...)'
                    help_suffix = f"\n(Expects a function reference: {callable_args_repr}."
                    if param.default is not inspect.Parameter.empty and param.default is not None:
                        help_suffix += f" Default: {param.default})"
                    else:
                        help_suffix += ")"
                    param_constructor_args["help"] += help_suffix

                    current_callable_attrs = {**param_constructor_args}
                    # If python default for callable is not a string, or no default, XML value should be "" if not optional
                    if not isinstance(param.default, str) or param.default is inspect.Parameter.empty:
                        if not current_callable_attrs.get('optional', False):
                             current_callable_attrs['value'] = ""
                        elif 'value' in current_callable_attrs : # Optional and no string default
                             del current_callable_attrs['value']
                    # else: python default is a string, param_constructor_args['value'] is already set.
                    xml_params.append(TextParam(argument=param_name, **current_callable_attrs))
                 # else: Other specific types like Any, slice, Axes are ignored as in original or fall through
            elif hasattr(annotation, '__mro__') and pd.Timedelta in annotation.__mro__:
                 param_constructor_args["help"] += "\n(Pandas timedelta string, e.g., '1D', '2H30M')"
                 xml_params.append(TextParam(argument=param_name, **param_constructor_args))
            else:
                 # sys.stderr.write(f"Warning: Unknown simple parameter type {annotation} for param '{param_name}' in method '{method.__name__}'. Treating as TextParam.\n")
                 xml_params.append(TextParam(argument=param_name, **param_constructor_args)) # Fallback

        elif origin is Union and str in args and pd.Timedelta in args: # Union[str, pd.Timedelta]
             param_constructor_args["help"] += "\n(Pandas timedelta string or offset, e.g., '1D', '2H30M')"
             xml_params.append(TextParam(argument=param_name, **param_constructor_args))

        elif origin is Union and all(el_type in args for el_type in (str, Tuple[str,str])) and len(args)==2 : # Union[str, Tuple[str,str]]
            param_constructor_args["help"] += "\n(String or two comma-separated strings, e.g., val1,val2)"
            xml_params.append(TextParam(argument=param_name, **param_constructor_args))

        elif origin is Union and all(el_type in args for el_type in (int, Tuple[int,int])) and len(args)==2 : # Union[int, Tuple[int,int]]
            param_constructor_args["help"] += "\n(Integer or two comma-separated integers, e.g., 1,2)"
            xml_params.append(TextParam(argument=param_name, **param_constructor_args))

        elif origin is Union and int in args and str in args and param_name in ["limit", "window"]: # E.g. Union[int, str] for window/limit
            cond = Conditional(name=f"{param_name}_cond")
            select_param_name = f"{param_name}_select_type"
            cond_options = {"number": "Number", "timedelta": "Timedelta"}
            if optional: cond_options["none"] = "None (use default)"

            select_default_choice = None # Default for the select (which branch to show)
            if isinstance(param.default, int): select_default_choice = 'number'
            elif isinstance(param.default, str): select_default_choice = 'timedelta'
            elif optional and param.default is None: select_default_choice = 'none'
            if select_default_choice not in cond_options and cond_options: select_default_choice = list(cond_options.keys())[0]

            cond.append(SelectParam(name=select_param_name, label=f"{label} Input Mode", options=cond_options, value=select_default_choice, optional=False))

            # Number branch
            when_number = When(value="number")
            num_attrs = {k:v for k,v in param_constructor_args.items() if k != 'value'} # Base, but manage value specifically
            num_attrs.update({"optional": False, "label": f"{label} (as number)"})
            if isinstance(param.default, int):
                num_attrs['value'] = str(param.default)
            else: # Python default not int (e.g. str or None)
                num_attrs['value'] = "" # Non-optional IntegerParam needs a value
            when_number.append(IntegerParam(argument=param_name, **num_attrs))
            cond.append(when_number)

            # Timedelta (string) branch
            when_timedelta = When(value="timedelta")
            td_attrs = {k:v for k,v in param_constructor_args.items() if k != 'value'}
            td_attrs.update({"optional": False, "label": f"{label} (as timedelta string)"})
            if isinstance(param.default, str): # Python default is a string
                td_attrs['value'] = param.default
            else: # Python default not str (e.g. int or None)
                td_attrs['value'] = "" # Non-optional TextParam needs a value
            when_timedelta.append(TextParam(argument=param_name, **td_attrs))
            cond.append(when_timedelta)

            if "none" in cond_options:
                when_none = When(value="none")
                # Hidden param with special value to signify None or "use Python default"
                # The script using this XML needs to interpret "__none__"
                when_none.append(HiddenParam(name=param_name, value="__none__"))
                cond.append(when_none)
            xml_params.append(cond)

        elif origin is Union and float in args and str in args and param_name in ["cutoff", "freq"]: # E.g. Union[float, str] for cutoff/freq
            cond = Conditional(name=f"{param_name}_cond")
            select_param_name = f"{param_name}_select_type"
            cond_options = {}
            num_label, str_label = "Value (float)", "Offset string"
            # Customize labels based on param_name
            if param_name == "cutoff": cond_options = {"number": f"Cutoff as {num_label}", "offset": f"Cutoff as {str_label}"}
            elif param_name == "freq": cond_options = {"number": f"Frequency as {num_label}", "offset": f"Frequency as {str_label}"}
            else: cond_options = {"number": num_label, "offset": str_label} # Generic fallback

            if optional: cond_options["none"] = "None (use default)"

            select_default_choice = None
            if isinstance(param.default, float): select_default_choice = 'number'
            elif isinstance(param.default, str): select_default_choice = 'offset'
            elif optional and param.default is None: select_default_choice = 'none'
            if select_default_choice not in cond_options and cond_options: select_default_choice = list(cond_options.keys())[0]
            cond.append(SelectParam(name=select_param_name, label=f"{label} Input Mode", options=cond_options, value=select_default_choice, optional=False))

            # Float branch
            when_number = When(value="number")
            float_attrs = {k:v for k,v in param_constructor_args.items() if k != 'value'}
            float_attrs.update({"optional": False, "label": f"{label} ({cond_options.get('number', num_label)})"})
            if isinstance(param.default, float):
                float_attrs['value'] = str(param.default)
            else:
                float_attrs['value'] = ""
            when_number.append(FloatParam(argument=param_name, **float_attrs))
            cond.append(when_number)

            # String offset branch
            when_str_offset = When(value="offset")
            str_attrs = {k:v for k,v in param_constructor_args.items() if k != 'value'}
            str_attrs.update({"optional": False, "label": f"{label} ({cond_options.get('offset', str_label)})"})
            if isinstance(param.default, str):
                str_attrs['value'] = param.default
            else:
                str_attrs['value'] = ""
            when_str_offset.append(TextParam(argument=param_name, **str_attrs))
            cond.append(when_str_offset)

            if "none" in cond_options:
                when_none = When(value="none")
                when_none.append(HiddenParam(name=param_name, value="__none__"))
                cond.append(when_none)
            xml_params.append(cond)

        elif origin is Union and all(a in args for a in (Literal['valid', 'complete'], list[str])): # For 'history' param
            cond = Conditional(name=f"{param_name}_cond")
            select_param_name = f"{param_name}_select_type"
            options_dict_local = {
                "valid": "Valid", "complete": "Complete", "list": "Custom List"
            }
            if optional: options_dict_local["none"] = "None (use default)"

            select_default_key = None
            if isinstance(param.default, str) and param.default in options_dict_local: select_default_key = param.default
            elif isinstance(param.default, list): select_default_key = 'list'
            elif optional and param.default is None: select_default_key = 'none'
            if select_default_key not in options_dict_local and options_dict_local: select_default_key = list(options_dict_local.keys())[0]

            cond.append(SelectParam(name=select_param_name, label=f"{label} Mode", options=options_dict_local, value=select_default_key, optional=False))

            for opt_key in options_dict_local.keys():
                current_when = When(value=opt_key)
                if opt_key == "list":
                    list_attrs = {k:v for k,v in param_constructor_args.items() if k != 'value'}
                    list_attrs.update({"optional":False, "label": f"{label} (comma-separated)"})
                    if isinstance(param.default, list):
                        list_attrs['value'] = ",".join(map(str,param.default))
                    else:
                        list_attrs['value'] = "" # Default to empty if Python default was not a list
                    current_when.append(TextParam(argument=param_name, **list_attrs))
                elif opt_key == "none":
                    current_when.append(HiddenParam(name=param_name, value="__none__"))
                else: # 'valid', 'complete'
                    current_when.append(HiddenParam(name=param_name, value=opt_key))
                cond.append(current_when)
            xml_params.append(cond)

        elif origin is Union and any(get_origin(a) is Literal and "auto" in get_args(a) for a in args) and float in args: # E.g. density, thresh in UniLOF
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

             cond.append(SelectParam(name=select_param_name, label=f"{label} Mode", options=cond_options, value=select_default_choice, optional=False))

             # Auto branch
             when_auto = When(value="auto"); when_auto.append(HiddenParam(name=param_name, value="auto")); cond.append(when_auto)

             # Float branch
             when_float = When(value="float")
             float_attrs = {k:v for k,v in param_constructor_args.items() if k != 'value'}
             float_attrs.update({"optional": False, "label": f"{label} (float value)"})
             if isinstance(param.default, float):
                 float_attrs['value'] = str(param.default)
             else: # Python default not float (e.g., "auto")
                 float_attrs['value'] = ""
             when_float.append(FloatParam(argument=param_name, **float_attrs))
             cond.append(when_float)

             # Custom callable branch (TextParam)
             if has_callable_opt:
                 when_custom = When(value="custom")
                 custom_attrs = {k:v for k,v in param_constructor_args.items() if k != 'value'}
                 custom_attrs.update({"optional": False, "label": f"{label} (custom callable name)"})
                 if isinstance(param.default, str) and param.default!="auto" and not isinstance(param.default, (float, int)): # If default is a custom string name
                      custom_attrs['value'] = param.default
                 elif is_callable_type(param.default) and hasattr(param.default, '__name__'): # if default is actual callable
                      custom_attrs['value'] = param.default.__name__ # Try to get its name
                 else: # Default not a custom string or nameable callable
                      custom_attrs['value'] = ""
                 when_custom.append(TextParam(argument=param_name, **custom_attrs))
                 cond.append(when_custom)

             if "none" in cond_options:
                 when_none = When(value="none"); when_none.append(HiddenParam(name=param_name, value="__none__")); cond.append(when_none)
             xml_params.append(cond)

        elif origin is Literal: # Simple Literal (becomes SelectParam)
             literal_options = dict([(str(o), str(o)) for o in args])
             # Value for SelectParam. If python default is one of the literal options, use it.
             # Otherwise, if not optional, galaxy expects a value. If options exist, first one. Else empty.
             # If optional and no matching default, omit value.
             current_literal_attrs = {**param_constructor_args} # start with base
             if param.default is not inspect.Parameter.empty and str(param.default) in literal_options:
                 current_literal_attrs['value'] = str(param.default)
             elif not optional: # Not optional, needs a value
                 if 'value' not in current_literal_attrs or current_literal_attrs['value'] is None : # if value wasn't set by default or was None
                     if literal_options:
                         current_literal_attrs['value'] = str(list(literal_options.keys())[0]) # Default to first option
                     else:
                         current_literal_attrs['value'] = "" # Should not happen if args exist for Literal
             elif 'value' in current_literal_attrs and current_literal_attrs['value'] is None: # Optional and current value is None from default=None
                del current_literal_attrs['value'] # Omit value for optional if default was None
             xml_params.append(SelectParam(argument=param_name, options=literal_options, **current_literal_attrs))

        elif (origin is Union and any(is_callable_type(a) for a in args) and
              any(get_origin(a) is Literal and all(lit_val in get_args(a) for lit_val in ("linear", "exponential")) for a in args)): # For 'model' param in correctDrift
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

            cond.append(SelectParam(name=select_param_name, label=f"{label} Model Type", options=cond_options, value=select_default_choice, optional=False))

            when_linear = When(value="linear"); when_linear.append(HiddenParam(name=param_name, value="linear")); cond.append(when_linear)
            when_exp = When(value="exponential"); when_exp.append(HiddenParam(name=param_name, value="exponential")); cond.append(when_exp)

            when_custom = When(value="custom")
            custom_attrs = {k:v for k,v in param_constructor_args.items() if k != 'value'}
            custom_attrs.update({"optional": False, "label": f"{label} (Custom Callable Name)"})
            if isinstance(param.default, str) and param.default not in ("linear", "exponential"):
                custom_attrs['value'] = param.default
            elif is_callable_type(param.default) and hasattr(param.default, '__name__'):
                custom_attrs['value'] = param.default.__name__
            else: # Python default was not a custom string callable name
                custom_attrs['value'] = ""
            when_custom.append(TextParam(argument=param_name, **custom_attrs))
            cond.append(when_custom)

            if "none" in cond_options:
                when_none = When(value="none"); when_none.append(HiddenParam(name=param_name, value="__none__")); cond.append(when_none)
            xml_params.append(cond)

        elif origin in (pd.Series, pd.DataFrame, DictOfSeries, list, np.ndarray) or \
             (origin is Union and any(o_arg in (pd.Series, pd.DataFrame, DictOfSeries, list, np.ndarray) for o_arg in args)): # Data-like inputs
            param_constructor_args["help"] += "\n(Name of another data field/column or comma-separated list of columns)"
            xml_params.append(TextParam(argument=param_name, **param_constructor_args))

        elif origin is Sequence and not (annotation == Sequence[ForwardRef("SaQC")] if isinstance(annotation, type) else False): # Generic Sequence, not SaQC sequence
             param_constructor_args["help"] += "\n(Enter items separated by commas, e.g., val1,val2,val3)"
             current_seq_attrs = {**param_constructor_args}
             if isinstance(param.default, Sequence) and not isinstance(param.default, str) : # If default is a Python sequence (and not a string)
                 current_seq_attrs['value'] = ",".join(map(str, param.default))
             # Ensure 'value' is set if not optional and no other default was applicable
             elif not optional and ('value' not in current_seq_attrs or current_seq_attrs['value'] is None):
                 current_seq_attrs['value'] = ""
             # If optional and default was None, 'value' should not be present
             elif optional and 'value' in current_seq_attrs and current_seq_attrs['value'] is None:
                 del current_seq_attrs['value']
             xml_params.append(TextParam(argument=param_name, **current_seq_attrs))

        elif isinstance(annotation, type) and (annotation == Sequence[ForwardRef("SaQC")] or annotation == dict[ForwardRef("SaQC"), Union[str, Sequence[str]]]):
            sys.stderr.write(f"Ignoring specific complex SaQC sequence/dict parameter {param_name} ({method.__name__})\n")

        else: # Fallback for any other unhandled types
             # sys.stderr.write(f"Warning: Parameter '{param_name}' of type {annotation} (origin: {origin}, args: {args}) in method '{method.__name__}' is falling back to TextParam.\n")
             xml_params.append(TextParam(argument=param_name, **param_constructor_args))
    return xml_params


def get_methods_conditional(methods, module):
    method_conditional = Conditional(name="method_cond", label="Method")
    method_select_options = []
    if not methods:
        return None # Should not happen if module has SaQC methods

    for method_obj in methods: # Renamed to method_obj to avoid conflict with outer 'method'
        method_name = method_obj.__name__
        method_doc = _get_doc(method_obj.__doc__)
        if not method_doc:
            method_doc = method_name # Fallback to name if no doc
        method_select_options.append((method_name, f"{method_name}: {method_doc}"))

    if method_select_options:
        method_select = SelectParam(
            name="method_select", label="Method", options=dict(method_select_options), optional=False
        )
        # Set a default for the select if possible (first method)
        if method_select_options:
            method_select.value = method_select_options[0][0]
        method_conditional.append(method_select)
    else:
         # This case should ideally not be reached if methods list is not empty.
         # If it were, returning None or an empty Conditional might be options.
         # For safety, if no options, don't add the SelectParam.
         # However, the outer logic expects a Conditional.
         # Add a placeholder if no methods were processed for select options.
         no_options_notice = TextParam(name="no_method_options_notice", type="text", value="No methods available for selection.", label="Info")
         method_conditional.append(no_options_notice) # Should be rare
         # return method_conditional # Or handle as error

    for method_obj in methods:
        method_name = method_obj.__name__
        method_when = When(value=method_name)
        try:
            params = get_method_params(method_obj, module)
            if not params : # If a method has no configurable parameters
                 no_params_notice = TextParam(name=f"{method_name}_no_params_notice", type="text", value="This method has no configurable parameters.", label="Info")
                 # no_params_notice.readonly = True # Galaxy might not support readonly on text directly. It's for UI hint.
                 method_when.append(no_params_notice)
            else:
                for p in params:
                    method_when.append(p)
        except ValueError as e: # Catch errors during param generation for a specific method
            sys.stderr.write(
                f"Skipping params for method {method_name} in module {module.__name__} due to: {e}\n"
            )
            param_error_notice = TextParam(name=f"{method_name}_param_error_notice", type="text", value=f"Error generating parameters for this method: {e}", label="Parameter Generation Error")
            method_when.append(param_error_notice)
        method_conditional.append(method_when)

    return method_conditional


# --- Tool Definition ---
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
    executable="saqc", # This is a placeholder, command_override is used
    macros=["macros.xml"], # Assuming macros.xml exists and defines requirements, tests, citations
    command_override=command_override,
    profile="22.01", # Or your target Galaxy profile
    version_command="python -c 'import saqc; print(saqc.__version__)'",
)
tool.help = "This tool provides access to SaQC functions for quality control of time series data. Select a module and method, then configure its parameters." # Basic help

tool.configfiles = Configfiles()
tool.configfiles.append(ConfigfileDefaultInputs(name="param_conf")) # For JSON config

inputs_section = tool.inputs = Inputs() # Use a different variable name if 'inputs' is a keyword/module
inputs_section.append(DataParam(argument="--data", format="csv", multiple=True, label="Input table(s)"))

# --- Module and Method Selection ---
modules = get_modules()
module_repeat = Repeat(name="methods_repeat", title="Methods (add multiple QC steps)")
inputs_section.append(module_repeat) # Add repeat to main inputs

module_conditional = Conditional(name="module_cond", label="SaQC Module")
module_select_options = []
for module_name, module_obj in modules: # Renamed module to module_obj
    module_doc = _get_doc(module_obj.__doc__)
    if not module_doc:
        module_doc = module_name
    module_select_options.append((module_name, f"{module_name}: {module_doc}"))

if module_select_options:
    module_select = SelectParam(
        name="module_select", label="Select SaQC module", options=dict(module_select_options), optional=False
    )
    if module_select_options: # Set default for the select
        module_select.value = module_select_options[0][0]
    module_conditional.append(module_select)
else:
     # Fallback if no modules found (should not happen with SaQC)
     module_conditional.append(TextParam(name="no_modules_found", type="text", value="No SaQC modules found.", label="Error"))

for module_name, module_obj in modules: # Renamed module to module_obj
    module_when = When(value=module_name)
    methods = get_methods(module_obj)
    if methods:
        methods_conditional_obj = get_methods_conditional(methods, module_obj) # Pass module_obj
        if methods_conditional_obj:
             module_when.append(methods_conditional_obj)
        else: # Should not happen if get_methods_conditional is robust
             module_when.append(TextParam(name=f"{module_name}_no_methods_conditional", type="text", value=f"Could not generate method selection for module '{module_name}'.", label="Notice"))
    else: # No SaQC-compatible methods in this module
        module_when.append(TextParam(name=f"{module_name}_no_methods_found", type="text", value=f"No SaQC methods detected for module '{module_name}'.", label="Notice"))
    module_conditional.append(module_when)

if module_select_options: # Only add the conditional to repeat if there were modules
    module_repeat.append(module_conditional)


# --- Outputs ---
outputs_section = tool.outputs = Outputs() # Use a different variable name
outputs_section.append(OutputData(name="output", format="csv", from_work_dir="output.csv", label="${tool.name} on ${on_string}: Processed Data"))
plot_outputs = OutputCollection(
    name="plots", type="list", label="${tool.name} on ${on_string}: Plots (if any generated)"
)
# Discover .png files, useful if some SaQC methods generate plots directly or via a wrapper script
plot_outputs.append(DiscoverDatasets(pattern=r"(?P<name>.*)\.png", ext="png", visible=True)) # ensure visible
outputs_section.append(plot_outputs)
outputs_section.append(OutputData(name="config_out", format="txt", from_work_dir="config.csv", label="${tool.name} on ${on_string}: Generated SaQC Configuration")) # Renamed from 'config'

# --- Export Tool XML ---
print(tool.export())