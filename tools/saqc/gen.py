import argparse
import csv
import inspect
import re
import sys
import xml.etree.ElementTree as ET
from typing import (
    Any,
    Callable,
    Dict,
    ForwardRef,
    get_args,
    get_origin,
    Literal,
    Optional,
    Tuple,
    TYPE_CHECKING,
)

import saqc
from galaxyxml.tool import Tool
from galaxyxml.tool.parameters import (
    BooleanParam,
    Conditional,
    ConfigfileDefaultInputs,
    Configfiles,
    DataParam,
    DiscoverDatasets,
    FloatParam,
    HiddenParam,
    Inputs,
    IntegerParam,
    OutputCollection,
    OutputData,
    Outputs,
    Repeat,
    SelectParam,
    TextParam,
    ValidatorParam,
    When,
)
from saqc.lib import types as saqc_types

if TYPE_CHECKING:
    from types import ModuleType

TRACING_DATA = []


def discover_literals(*modules_to_scan) -> Dict[str, Any]:
    """
    Searches the modules for literal definitions.
    """
    discovered_literals = {}
    for module in modules_to_scan:
        if module is None:
            continue
        for attr_name in dir(module):
            if attr_name.isupper() and not attr_name.startswith('_'):
                try:
                    literal_obj = getattr(module, attr_name)
                    if get_origin(literal_obj) is Literal:
                        print(f"Discovered Literal '{attr_name}' in module '{module.__name__}'", file=sys.stderr)
                        discovered_literals[attr_name] = literal_obj
                except Exception:
                    continue
    return discovered_literals


SAQC_CUSTOM_SELECT_TYPES = {}
try:
    SAQC_CUSTOM_SELECT_TYPES.update(discover_literals(saqc_types))
    for _, func_module in inspect.getmembers(saqc.funcs, inspect.ismodule):
        SAQC_CUSTOM_SELECT_TYPES.update(discover_literals(func_module))
except (ImportError, TypeError) as e:
    sys.stderr.write(f"Warning: Could not automatically discover saqc Literals: {e}\n")


def clean_annotation_string(s: str) -> str:
    """
    Translates non standard data types in standard types.
    """
    if not isinstance(s, str):
        return s

    all_literals = "|".join(SAQC_CUSTOM_SELECT_TYPES.keys())
    if all_literals:
        s = re.sub(fr'\b({all_literals})\b', "str", s)

    s = re.sub(r'\b(FreqStr|OffsetStr|SaQCFields|NewSaQCFields)\b', "str", s)
    s = s.replace("GenericFunction", "Callable")
    s = s.replace("ArrayLike", "list")
    s = re.sub(r'\bInt\s*(?:\[.*?\]|[><=]\s*\d+)?', 'int', s)
    s = re.sub(r'\bFloat\s*(?:\[.*?\]|[><=]\s*\d*\.?\d+)?', 'float', s)
    s = s.replace('(', '').replace(')', '')
    s = re.sub(r'\s*\|\s*', ' | ', s).strip()

    return s


def _get_doc(doc_str: Optional[str]) -> str:
    if not doc_str:
        return ""
    doc_str = str(doc_str)
    doc_str_lines = [x for x in doc_str.split("\n") if x.strip() != ""]
    if not doc_str_lines:
        return ""
    doc_str = doc_str_lines[0]
    doc_str = (
        doc_str.strip(" .,")
        .replace(":py:attr:", "")
        .replace("&#10;", " ")
        .replace("<", " ")
        .replace(">", " ")
        .replace('"', " ")
    )

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

    for i, match in enumerate(section_matches):
        if i == 0:
            if match.start() > 0:
                sections[""] = docstring[: match.start()].strip()
                first_section_processed_by_title = True

        if title_key or (
            i == 0 and not first_section_processed_by_title and match.start() == 0
        ):
            if title_key or "" not in sections or (i == 0 and match.start() == 0):
                sections[title_key] = docstring[end: match.start()].strip()

        title_key = match.group("title").strip()
        end = match.end()
        if i == 0:
            first_section_processed_by_title = True

    if title_key or (not sections and docstring):
        sections[title_key] = docstring[end:].strip()
    elif not sections and not docstring:
        return {}

    return {k: v for k, v in sections.items() if v or k == ""}


def parse_parameter_docs(sections: Dict[str, str]) -> Dict[str, str]:
    parameter_doc = {}
    parameters_text = sections.get("Parameters", "")
    if not parameters_text:
        return parameter_doc

    current_param = None
    current_lines = []
    param_start_pattern = re.compile(
        r"^(?P<param_name>[a-zA-Z_][a-zA-Z0-9_]*)\s*(:.*)?"
    )

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
            if (
                line.startswith("    ")
                or line.startswith("\t\t")
                or not param_start_pattern.match(original_line_stripped)
            ):
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
        lines = pdoc.split("\n")
        if lines:
            first_line = lines[0]
            cleaned_first_line = re.sub(
                r"^\s*{}\s*:\s*[^-\n]+?\s*--\s*".format(re.escape(pname)),
                "",
                first_line,
                count=1,
            ).strip()
            if first_line.strip() == cleaned_first_line and ":" in first_line:
                cleaned_first_line = re.sub(
                    r"^\s*{}\s*:\s*".format(re.escape(pname)), "", first_line, count=1
                ).strip()

            if cleaned_first_line.startswith(pname):
                cleaned_first_line = re.sub(
                    r"^\s*{}".format(re.escape(pname)), "", cleaned_first_line, count=1
                ).strip()

            lines[0] = cleaned_first_line
            parameter_doc[pname] = "\n".join(
                line.strip() for line in lines if line.strip() or line == ""
            ).strip()

    return parameter_doc


def get_label_help(param_name, parameter_docs):
    """
    Extracts label and help text.
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
    if (
        not label_candidate
        or "|" in label_candidate
        or "[" in label_candidate
        or not label_candidate[0].isupper()
        or " " not in label_candidate
        or len(label_candidate) > 80
    ):
        is_bad_label = True

    if not is_bad_label and label_candidate:
        label = label_candidate

        if full_help.startswith(label_candidate):
            remaining_help = full_help[len(label_candidate):].strip()
            remaining_help = remaining_help.lstrip(".\n\r").strip()

        if not remaining_help:
            remaining_help = full_help

    label = (
        label.replace("\n", " ")
        .replace("&#10;", " ")
        .replace(":py:attr:", "")
        .removesuffix(".")
        .strip()
    )
    remaining_help = (
        remaining_help.replace("\n", " ")
        .replace("&#10;", " ")
        .replace(":py:attr:", "")
        .removesuffix(".")
        .strip()
    )

    label = label.replace("<", " ").replace(">", " ").replace('"', " ")
    remaining_help = (
        remaining_help.replace("<", " ").replace(">", " ").replace('"', " ")
    )

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
                        annotation_str = self_param.annotation.__forward_arg__.strip(
                            "'"
                        )
                    elif hasattr(self_param.annotation, "__name__"):
                        annotation_str = self_param.annotation.__name__

                    if annotation_str == "SaQC":
                        methods_with_saqc.append(method)
            except (ValueError, TypeError) as e:
                sys.stderr.write(
                    f"Warning: Could not inspect signature for {cls.__name__}.{method_name}: {e}\n"
                )
                continue
    return methods_with_saqc


def _split_type_string_safely(type_string: str) -> list[str]:
    parts = []
    current_part = ""
    bracket_level = 0
    for char in type_string:
        if char in ('[', '('):
            bracket_level += 1
        elif char in (']', ')'):
            bracket_level -= 1

        if char in ('|', ',') and bracket_level == 0:
            if current_part.strip():
                parts.append(current_part.strip())
            current_part = ""
        else:
            current_part += char

    if current_part.strip():
        parts.append(current_part.strip())

    return [p for p in parts if p]


def _create_param_from_type_str(type_str: str, param_name: str, param_constructor_args: dict, is_optional: bool) -> Optional[object]:
    param_object = None
    base_type_str = type_str.strip()
    is_tuple = False

    tuple_match = re.fullmatch(r"tuple\[\s*([^,]+).*", base_type_str, re.IGNORECASE)
    if tuple_match:
        is_tuple = True
        inner_type_str = tuple_match.group(1).strip()
        base_type_str = inner_type_str
        param_constructor_args["label"] = param_constructor_args.get("label", inner_type_str) + " (one or more)"

    creation_args = param_constructor_args.copy()

    if is_tuple:
        creation_args['multiple'] = True

    if base_type_str in ('SaQCFields', 'NewSaQCFields'):
        param_object = TextParam(argument=param_name, multiple=True, **creation_args)
    elif re.fullmatch(r"(list|Sequence)\[\s*str\s*\]", base_type_str, re.IGNORECASE):
        param_object = TextParam(argument=param_name, multiple=True, **creation_args)
    elif re.fullmatch(r"list\[\s*tuple\[\s*float\s*,\s*float\s*\]\s*\]", base_type_str, re.IGNORECASE):
        repeat = Repeat(name=param_name, title=creation_args.get("label", param_name),
                        help=creation_args.get("help", ""))
        repeat.append(FloatParam(name=f"{param_name}_min", label="Y-Axis Minimum"))
        repeat.append(FloatParam(name=f"{param_name}_max", label="Y-Axis Maximum"))
        param_object = repeat
    elif base_type_str.lower() in ('list', 'sequence', 'arraylike', 'pd.series', 'pd.dataframe', 'pd.datetimeindex'):
        param_object = TextParam(argument=param_name, **creation_args)
    elif base_type_str.lower() in ('pd.timedelta', 'offsetlike'):
        param_object = TextParam(argument=param_name, **creation_args)
        regex = r"^\s*-?\d+(\.\d+)?\s*(D|H|T|S|L|U|N|days?|hours?|minutes?|seconds?|weeks?|milliseconds?|microseconds?|nanoseconds?)\s*$"
        message = "Please enter a valid Timedelta string (e.g., '30min', '2H', '1D')."
        param_object.append(ValidatorParam(type="regex", message=message, text=regex))
    elif base_type_str.lower() in ('dict', 'dictionary'):
        repeat = Repeat(name=param_name, title=creation_args.get("label", param_name),
                        help=creation_args.get("help", ""))
        key_param = TextParam(name="key", label="Key", help="Name of the dictionary key.")
        key_param.append(ValidatorParam(type="empty_field"))
        value_param = TextParam(name="value", label="Value", help="Value for the key (e.g., 'min,max').")
        value_param.append(ValidatorParam(type="empty_field"))
        repeat.append(key_param)
        repeat.append(value_param)
        param_object = repeat
    elif re.match(r"Literal\[(.*)\]", base_type_str):
        literal_match = re.match(r"Literal\[(.*)\]", base_type_str)
        options_str = literal_match.group(1)
        options_list = [opt.strip().strip("'\"") for opt in _split_type_string_safely(options_str)]
        if options_list:
            options = {o: o for o in options_list}
            param_object = SelectParam(argument=param_name, options=options, **creation_args)
    elif base_type_str in SAQC_CUSTOM_SELECT_TYPES:
        type_obj = SAQC_CUSTOM_SELECT_TYPES[base_type_str]
        args = get_args(type_obj)
        if get_origin(type_obj) is Literal and args:
            options = {str(o): str(o) for o in args}
            param_object = SelectParam(argument=param_name, options=options, **creation_args)
    elif (range_match := re.fullmatch(r"(Float|Int)\[\s*([0-9.-]+)\s*,\s*([0-9.-]+)\s*\]", base_type_str, re.IGNORECASE)):
        type_name, min_val, max_val = range_match.groups()
        creation_args['min'] = min_val
        creation_args['max'] = max_val
        if type_name.lower() == 'float':
            param_object = FloatParam(argument=param_name, **creation_args)
        else:
            param_object = IntegerParam(argument=param_name, **creation_args)
    elif "Int >" in base_type_str or "Float >" in base_type_str:
        pattern = re.compile(r"\(?\s*(Int|Float)\s*(>=?)\s*(\d+(?:\.\d+)?)\s*\)?")
        match = pattern.search(base_type_str)
        if match:
            type_name, _, value_str = match.groups()
            creation_args['min'] = value_str
            if type_name == 'Int':
                param_object = IntegerParam(argument=param_name, **creation_args)
            else:
                param_object = FloatParam(argument=param_name, **creation_args)
    elif base_type_str in ['OffsetStr', 'str', 'string', 'FreqStr', 'Any']:
        param_object = TextParam(argument=param_name, **creation_args)
    elif base_type_str == 'int':
        param_object = IntegerParam(argument=param_name, **creation_args)
    elif base_type_str == 'float':
        param_object = FloatParam(argument=param_name, **creation_args)
    elif base_type_str == 'bool':
        creation_args.pop("value", None)
        creation_args.pop("multiple", None)
        creation_args.pop("optional", None)
        param_object = BooleanParam(argument=param_name, checked=False, **creation_args)

    if param_object and not is_optional:
        if isinstance(param_object, TextParam) and not getattr(param_object, 'multiple', False):
            param_object.append(ValidatorParam(type="empty_field"))

    return param_object


def _get_user_friendly_type_name(type_str: str) -> str:
    if "list[tuple[float, float]]" in type_str:
        return "List of Y-Ranges"
    if "tuple[float, float]" in type_str:
        return "Single Y-Range"
    if type_str.startswith("Callable") or type_str.startswith("CurveFitter"):
        return "Custom Function"
    if "Int >" in type_str or "Float >" in type_str:
        return type_str.replace("Int", "Integer").replace("Float", "Float")
    if type_str.startswith("tuple"):
        return "Multiple values (Tuple)"
    if type_str.startswith("Literal"):
        return "Selection"
    name_map = {"OffsetStr": "Offset String", "FreqStr": "Frequency String", "str": "Text", "int": "Integer", "float": "Float", "bool": "Boolean"}
    clean_name = type_str.replace("_", " ").title()
    return name_map.get(type_str, clean_name)


def get_method_params(method, module, tracing=False):
    sections = parse_docstring(method)
    param_docs = parse_parameter_docs(sections)
    xml_params = []
    try:
        parameters = inspect.signature(method).parameters
    except (ValueError, TypeError) as e:
        sys.stderr.write(f"Warning: Could not get signature for {method.__name__}: {e}. Skipping params for this method.\n")
        return xml_params

    for param_name, param in parameters.items():
        if param_name in ["self", "kwargs"] or "kwarg" in param_name.lower():
            continue

        annotation = param.annotation
        param_object = None
        label, help_text = get_label_help(param_name, param_docs)

        raw_annotation_str = ""
        if isinstance(annotation, (str, ForwardRef)):
            raw_annotation_str = annotation.__forward_arg__ if isinstance(annotation, ForwardRef) else str(annotation)
        elif annotation is not inspect.Parameter.empty:
            raw_annotation_str = str(annotation).replace("typing.", "")

        if 'mpl.axes.Axes' in raw_annotation_str:
            continue

        is_python_optional_by_default = (param.default is not inspect.Parameter.empty)

        if raw_annotation_str.startswith('Union[') and raw_annotation_str.endswith(']'):
            inner_content = raw_annotation_str[6:-1]
            type_parts = _split_type_string_safely(inner_content)
        else:
            type_parts = _split_type_string_safely(raw_annotation_str)

        is_optional_by_none = 'None' in type_parts
        is_truly_optional = is_python_optional_by_default or is_optional_by_none

        optional_arg = {'optional': True} if is_truly_optional else {}
        param_constructor_args = {"label": label, "help": help_text, **optional_arg}

        if 'Sequence[SaQC]' in raw_annotation_str:
            data_param = DataParam(name=param_name, format="csv", multiple=True, **param_constructor_args)
            xml_params.append(data_param)
            continue

        type_parts_without_none = [p for p in type_parts if p != 'None']

        if param.default is not inspect.Parameter.empty and param.default is not None and not isinstance(param.default, bool):
            if not isinstance(param.default, Callable):
                param_constructor_args['value'] = str(param.default)

        if len(type_parts_without_none) == 1:
            single_type_str = type_parts_without_none[0]
            if single_type_str == 'slice':
                start_param_args = {"name": f"{param_name}_start", "label": f"{label} (start index)", "min": 0, "help": "Start index of the slice (e.g., 0).", **optional_arg}
                end_param_args = {"name": f"{param_name}_end", "label": f"{label} (end index)", "min": 0, "help": "End index of the slice (exclusive).", **optional_arg}
                start_param = IntegerParam(**start_param_args)
                end_param = IntegerParam(**end_param_args)
                xml_params.extend([start_param, end_param])
                continue
            elif any(func_type in single_type_str for func_type in ['Callable', 'CurveFitter', 'GenericFunction']):
                param_object = TextParam(argument=param_name, **param_constructor_args)
                if not is_truly_optional:
                    param_object.append(ValidatorParam(type="empty_field"))
            else:
                param_object = _create_param_from_type_str(single_type_str, param_name, param_constructor_args, is_truly_optional)

        elif len(type_parts_without_none) > 1:
            conditional = Conditional(name=f"{param_name}_cond", label=label)
            type_options = [(f"type_{i}", _get_user_friendly_type_name(part)) for i, part in enumerate(type_parts_without_none)]
            selector = SelectParam(name=f"{param_name}_selector", label=f"Choose type for '{label}'",
                                   help=help_text, options=dict(type_options))
            conditional.append(selector)

            for i, part_str in enumerate(type_parts_without_none):
                when = When(value=f"type_{i}")

                inner_param_args = {"label": _get_user_friendly_type_name(part_str), **optional_arg}

                if part_str == 'slice':
                    start_param = IntegerParam(name=f"{param_name}_start", label=f"{label} (start index)", min=0, help="Start index of the slice (e.g., 0).", **optional_arg)
                    end_param = IntegerParam(name=f"{param_name}_end", label=f"{label} (end index)", min=0, help="End index of the slice (exclusive).", **optional_arg)
                    when.extend([start_param, end_param])
                elif re.fullmatch(r"tuple\[\s*float\s*,\s*float\s*\]", part_str, re.IGNORECASE):
                    min_param = FloatParam(name=f"{param_name}_min", label=f"{label} (Y-Axis Minimum)", **optional_arg)
                    max_param = FloatParam(name=f"{param_name}_max", label=f"{label} (Y-Axis Maximum)", **optional_arg)
                    when.extend([min_param, max_param])
                elif any(func_type in part_str for func_type in ['Callable', 'CurveFitter', 'GenericFunction']):
                    inner_param = TextParam(argument=param_name, **inner_param_args)
                    if not is_truly_optional:
                        inner_param.append(ValidatorParam(type="empty_field"))
                    when.append(inner_param)
                else:
                    inner_param = _create_param_from_type_str(part_str, param_name, inner_param_args, is_truly_optional)
                    if inner_param:
                        when.append(inner_param)
                    else:
                        sys.stderr.write(f"Info ({module.__name__}): Could not create UI element for type '{part_str}' in Conditional '{param_name}'. Falling back to info text.\n")
                        info_text = TextParam(name=f"{param_name}_info", type="text",
                                              value="This type is not usable in Galaxy.",
                                              label="Info",
                                              help="This option is for programmatic use and cannot be set from the UI.")
                        when.append(info_text)

                conditional.append(when)
            param_object = conditional

        if not param_object and not raw_annotation_str.strip() and param.default is not inspect.Parameter.empty:
            default_value = param.default

            if not isinstance(default_value, bool):
                param_constructor_args['value'] = str(default_value)

            if isinstance(default_value, bool):
                param_constructor_args.pop("value", None)
                param_constructor_args.pop("optional", None)
                param_object = BooleanParam(argument=param_name, checked=default_value, **param_constructor_args)
            elif isinstance(default_value, int):
                param_object = IntegerParam(argument=param_name, **param_constructor_args)
            elif isinstance(default_value, float):
                param_object = FloatParam(argument=param_name, **param_constructor_args)
            elif isinstance(default_value, str):
                param_object = TextParam(argument=param_name, **param_constructor_args)

        if param_object:
            xml_params.append(param_object)
        elif raw_annotation_str.strip() and raw_annotation_str.strip() not in ['slice']:
            sys.stderr.write(f"Info ({module.__name__}): Unhandled annotation for param '{param_name}': '{raw_annotation_str}'. Creating default TextParam.\n")

            fallback_param = TextParam(argument=param_name, **param_constructor_args)

            if not is_truly_optional:
                fallback_param.append(ValidatorParam(type="empty_field"))

            xml_params.append(fallback_param)

    return xml_params


def get_methods_conditional(methods, module, tracing=False):
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
            name="method_select", label="Method", options=dict(method_select_options)
        )
        if method_select_options:
            method_select.value = method_select_options[0][0]
        method_conditional.append(method_select)
    else:
        no_options_notice = TextParam(
            name="no_method_options_notice",
            type="text",
            value="No methods available for selection.",
            label="Info",
        )
        method_conditional.append(no_options_notice)

    for method_obj in methods:
        method_name = method_obj.__name__
        method_when = When(value=method_name)
        try:
            params = get_method_params(method_obj, module, tracing=tracing)
            if not params:
                no_params_notice = TextParam(
                    name=f"{method_name}_no_params_notice",
                    type="text",
                    value="This method has no configurable parameters.",
                    label="Info",
                )
                method_when.append(no_params_notice)
            else:
                for p in params:
                    method_when.append(p)
        except ValueError as e:
            sys.stderr.write(
                f"Skipping params for method {method_name} in module {module.__name__} due to: {e}\n"
            )
            param_error_notice = TextParam(
                name=f"{method_name}_param_error_notice",
                type="text",
                value=f"Error generating parameters for this method: {e}",
                label="Parameter Generation Error",
            )
            method_when.append(param_error_notice)
        method_conditional.append(method_when)

    return method_conditional


def generate_tool_xml(tracing=False):
    """Generates XML-Definition of Galaxy-Tools."""
    command_override = [
        """
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
"""
    ]

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
    inputs_section.append(
        DataParam(
            argument="--data", format="csv", multiple=True, label="Input table(s)"
        )
    )
    inputs_section.append(HiddenParam(name="run_test_mode", value="false"))

    modules = get_modules()
    module_repeat = Repeat(
        name="methods_repeat", title="Methods (add multiple QC steps)"
    )
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
            name="module_select",
            label="Select SaQC module",
            options=dict(module_select_options),
        )
        if module_select_options:
            module_select.value = module_select_options[0][0]
        module_conditional.append(module_select)
    else:
        module_conditional.append(
            TextParam(
                name="no_modules_found",
                type="text",
                value="No SaQC modules found.",
                label="Error",
            )
        )

    for module_name, module_obj in modules:
        module_when = When(value=module_name)
        methods = get_methods(module_obj)
        if methods:
            methods_conditional_obj = get_methods_conditional(
                methods, module_obj, tracing=tracing
            )
            if methods_conditional_obj:
                module_when.append(methods_conditional_obj)
            else:
                module_when.append(
                    TextParam(
                        name=f"{module_name}_no_methods_conditional",
                        type="text",
                        value=f"Could not generate method selection for module '{module_name}'.",
                        label="Notice",
                    )
                )
        else:
            module_when.append(
                TextParam(
                    name=f"{module_name}_no_methods_found",
                    type="text",
                    value=f"No SaQC methods detected for module '{module_name}'.",
                    label="Notice",
                )
            )
        module_conditional.append(module_when)

    if module_select_options:
        module_repeat.append(module_conditional)

    outputs_section = tool.outputs = Outputs()
    outputs_section.append(
        OutputData(
            name="output",
            format="csv",
            from_work_dir="output.csv",
            label="${tool.name} on ${on_string}: Processed Data",
        )
    )
    plot_outputs = OutputCollection(
        name="plots",
        type="list",
        label="${tool.name} on ${on_string}: Plots (if any generated)",
    )
    plot_outputs.append(
        DiscoverDatasets(pattern=r"(?P<name>.*)\.png", ext="png", visible=True)
    )
    outputs_section.append(plot_outputs)
    outputs_section.append(
        OutputData(
            name="config_out",
            format="txt",
            from_work_dir="config.csv",
            label="${tool.name} on ${on_string}: Generated SaQC Configuration",
        )
    )

    tool_xml = tool.export()
    print(tool_xml)


def get_test_value_for_type(type_str: str, param_name: str) -> Any:
    """
    Gives valid test values and handles special types like dicts, slices und tuples.
    """
    clean_type = type_str.strip()

    if clean_type.lower() in ('dict', 'dictionary'):
        return [{'key': 'test_key', 'value': 'test_value'}]
    if clean_type == 'slice':
        return {f"{param_name}_start": 0, f"{param_name}_end": 10}
    if re.fullmatch(r"tuple\[\s*float\s*,\s*float\s*\]", clean_type, re.IGNORECASE):
        return {f"{param_name}_min": 0.0, f"{param_name}_max": 1.0}
    if re.fullmatch(r"list\[\s*tuple\[\s*float\s*,\s*float\s*\]\s*\]", clean_type, re.IGNORECASE):
        return [{f"{param_name}_min": 0.0, f"{param_name}_max": 1.0}]

    literal_match = re.search(r"Literal\[(.*)\]", clean_type)
    if literal_match:
        options_str = literal_match.group(1)
        options_list = [opt.strip().strip("'\"") for opt in _split_type_string_safely(options_str)]
        if options_list:
            return options_list[0]
    if clean_type in SAQC_CUSTOM_SELECT_TYPES:
        literal_obj = SAQC_CUSTOM_SELECT_TYPES[clean_type]
        args = get_args(literal_obj)
        if args:
            return args[0]

    if 'callable' in clean_type.lower() or 'genericfunction' in clean_type.lower():
        return "'mean'"

    if 'int' in clean_type.lower() or 'float' in clean_type.lower():
        return 1

    if 'bool' in clean_type.lower():
        return True
    if any(s in clean_type.lower() for s in ['offset', 'timedelta', 'freq']):
        return "1D"

    return "a_string"


def generate_test_variants(method: Callable) -> list:
    variants = []
    base_params = {}
    complex_params = {}

    try:
        parameters = inspect.signature(method).parameters
    except (ValueError, TypeError):
        return []

    for param_name, param in parameters.items():
        if param_name in ["self", "kwargs"] or "kwarg" in param_name.lower():
            continue

        annotation = param.annotation
        raw_annotation_str = ""
        if isinstance(annotation, (str, ForwardRef)):
            raw_annotation_str = annotation.__forward_arg__ if isinstance(annotation, ForwardRef) else str(annotation)
        elif annotation is not inspect.Parameter.empty:
            raw_annotation_str = str(annotation).replace("typing.", "")

        if 'Sequence[SaQC]' in raw_annotation_str:
            base_params[param_name] = "test1/data.csv"
            continue

        if 'mpl.axes.Axes' in raw_annotation_str:
            continue

        if raw_annotation_str.startswith('Union[') and raw_annotation_str.endswith(']'):
            inner_content = raw_annotation_str[6:-1]
            type_parts = _split_type_string_safely(inner_content)
        else:
            type_parts = _split_type_string_safely(raw_annotation_str)

        type_parts_without_none = [p for p in type_parts if p.strip() != 'None']

        if len(type_parts_without_none) > 1:
            complex_params[param_name] = type_parts_without_none
        elif type_parts_without_none:
            single_type_str = type_parts_without_none[0]
            if param_name in ["field", "target"]:
                base_params[param_name] = "test_variable"
            else:
                test_value = get_test_value_for_type(single_type_str, param_name)
                if isinstance(test_value, dict):
                    base_params.update(test_value)
                else:
                    base_params[param_name] = test_value
        else:
            if param.default is not inspect.Parameter.empty:
                base_params[param_name] = param.default
            else:
                base_params[param_name] = get_test_value_for_type("str", param_name)

    default_galaxy_params = base_params.copy()
    for name, type_parts in complex_params.items():
        first_type = type_parts[0]
        test_value = get_test_value_for_type(first_type, name)

        when_params = {f"{name}_selector": "type_0"}
        if isinstance(test_value, dict):
            when_params.update(test_value)
        else:
            when_params[name] = test_value
        default_galaxy_params[f"{name}_cond"] = when_params

    variants.append({
        "description": f"Test mit Defaults für {method.__name__}",
        "galaxy_params": default_galaxy_params,
    })

    for name, type_parts in complex_params.items():
        for i, type_str in enumerate(type_parts):
            if i == 0:
                continue

            variant_galaxy_params = default_galaxy_params.copy()
            test_value = get_test_value_for_type(type_str, name)

            when_params = {f"{name}_selector": f"type_{i}"}
            if isinstance(test_value, dict):
                when_params.update(test_value)
            else:
                when_params[name] = test_value

            variant_galaxy_params[f"{name}_cond"] = when_params

            variants.append({
                "description": f"Test-Variante für '{name}' mit Typ '{type_str}'",
                "galaxy_params": variant_galaxy_params,
            })

    return variants


def build_test_xml_recursively(parent_element: ET.Element, params_dict: dict):
    for name, value in params_dict.items():
        if name.endswith("_cond") and isinstance(value, dict):
            cond_elem = ET.SubElement(parent_element, "conditional", {"name": name})
            build_test_xml_recursively(cond_elem, value)
        elif isinstance(value, list):
            repeat_elem = ET.SubElement(parent_element, "repeat", {"name": name})
            for item_dict in value:
                build_test_xml_recursively(repeat_elem, item_dict)
        else:
            val_str = str(value).lower() if isinstance(value, bool) else str(value) if value is not None else ""
            ET.SubElement(parent_element, "param", {"name": name, "value": val_str})


def format_value_for_regex(value: Any) -> str:
    if value is None:
        return "None"
    if isinstance(value, bool):
        return str(value)
    if isinstance(value, int):
        return f"{re.escape(str(value))}(?:\\.0)?"

    if isinstance(value, float):
        if value.is_integer():
            return f"{re.escape(str(int(value)))}(?:\\.0)?"
        return re.escape(str(value))

    if isinstance(value, str) and value.startswith("'") and value.endswith("'"):
        inner_val = value.strip("'")
        transformed_val = f"__sq__{inner_val}__sq__"
        return f"[\"']?{re.escape(transformed_val)}[\"']?"

    if isinstance(value, str):
        return f"[\"']{re.escape(str(value))}[\"']"

    return re.escape(str(value))


def generate_test_macros():
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

            for variant in test_variants:
                test_elem = ET.SubElement(all_tests_macro, "test")
                ET.SubElement(test_elem, "param", {"name": "data", "value": "test1/data.csv", "ftype": "csv"})
                ET.SubElement(test_elem, "param", {"name": "run_test_mode", "value": "true"})

                repeat_elem = ET.SubElement(test_elem, "repeat", {"name": "methods_repeat"})
                module_cond_elem = ET.SubElement(repeat_elem, "conditional", {"name": "module_cond"})
                ET.SubElement(module_cond_elem, "param", {"name": "module_select", "value": module_name})

                method_cond_elem = ET.SubElement(module_cond_elem, "conditional", {"name": "method_cond"})
                ET.SubElement(method_cond_elem, "param", {"name": "method_select", "value": method_name})

                build_test_xml_recursively(method_cond_elem, variant["galaxy_params"])

                output_elem = ET.SubElement(test_elem, "output", {"name": "config_out", "ftype": "txt"})
                assert_contents = ET.SubElement(output_elem, "assert_contents")

                final_params_to_check = {}
                for p_name, p_value in variant["galaxy_params"].items():
                    if p_name.endswith('_cond') and isinstance(p_value, dict):
                        key = p_name[:-5]
                        if key in p_value:
                            final_params_to_check[key] = p_value[key]
                    else:
                        final_params_to_check[p_name] = p_value

                subject = final_params_to_check.pop("field", None)
                if not subject:
                    subject = final_params_to_check.pop("target", None)

                ET.SubElement(assert_contents, "has_text", {"text": method_name})

                if subject:
                    ET.SubElement(assert_contents, "has_text", {"text": str(subject)})

    try:
        ET.indent(macros_root, space="  ")
        sys.stdout.buffer.write(b'<?xml version="1.0" encoding="utf-8"?>\n')
        sys.stdout.buffer.write(ET.tostring(macros_root, encoding="utf-8", xml_declaration=False))
        print("\nSuccessfully generated test macro XML.", file=sys.stderr)
    except Exception as e:
        print(f"\nXML Serialization failed. Error: {e}", file=sys.stderr)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Generate Galaxy XML for SaQC tool or its test macros."
    )
    parser.add_argument(
        "--generate-tool",
        action="store_true",
        help="Generate the main tool XML file (saqc.xml).",
    )
    parser.add_argument(
        "--generate-tests",
        action="store_true",
        help="Generate the test macros file (test_macros.xml).",
    )
    parser.add_argument(
        "--tracing",
        action="store_true",
        help="Writes detailed parameter generation info to tracing.tsv.",
    )

    args = parser.parse_args()

    if args.generate_tool:
        print("--- Generating Galaxy Tool XML ---", file=sys.stderr)
        generate_tool_xml(tracing=args.tracing)
    elif args.generate_tests:
        print("--- Generating Galaxy Test Macros XML ---", file=sys.stderr)
        generate_test_macros()
    else:
        print(
            "--- No argument specified, generating Galaxy Tool XML by default. ---",
            file=sys.stderr,
        )
        generate_tool_xml(tracing=args.tracing)

    if args.tracing and TRACING_DATA:
        try:
            with open("tracing.tsv", "w", newline="", encoding="utf-8") as f:
                writer = csv.writer(f, delimiter="\t")
                headers = [
                    "ModuleName",
                    "ParameterName",
                    "TypeAnnotation",
                    "FinalXML",
                    "TracePath",
                ]
                writer.writerow(headers)
                for row in TRACING_DATA:
                    xml_string = row["xml"].replace("\n", " ").replace("\r", "")
                    writer.writerow(
                        [
                            row["module"],
                            row["param_name"],
                            row["annotation"],
                            xml_string,
                            row["path"],
                        ]
                    )
            print("--- Tracing information written to tracing.tsv ---", file=sys.stderr)
        except Exception as e:
            print(f"Error writing tracing file: {e}", file=sys.stderr)
