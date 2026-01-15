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
    OutputFilter,
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

HARDCODED_PARAMETERS = {
    # https://git.ufz.de/rdm-software/saqc/-/issues/511
    'saqc.funcs.tools|plot|path': ("OutputPath", ["OutputPath"], False),
}


SKIP_METHODS = set(
    [
        # https://git.ufz.de/rdm-software/saqc/-/issues/512
        "saqc.funcs.tools|flagByClick",
    ]
)

SAQC_CUSTOM_SELECT_TYPES = {}


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


def clean_annotation_string(s: str) -> str:
    """
    Translates non standard data types in standard types.
    """
    if not isinstance(s, str):
        return s

    all_literals = "|".join(SAQC_CUSTOM_SELECT_TYPES.keys())
    if all_literals:
        s = re.sub(fr'\b({all_literals})\b', "str", s)

    s = re.sub(r'\b(FreqStr|OffsetStr)\b', "str", s)
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
        .replace(":py:class:`Any`,", "")
        .replace(":py:class:", "")
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


def get_label_help(param_name: str, parameter_docs: str) -> Tuple[str, str]:
    """
    Extracts label and help text.
    Aggressively cleans technical type hints from the docstring.
    """
    doc_string = parameter_docs.get(param_name, "").strip()

    if not doc_string:
        return param_name, ""

    clean_doc = (
        doc_string.replace(":py:attr:", "")
        .replace(":py:class:", "")
        .strip()
    )

    # remove type annotations from first line of parameter docs
    # TODO can be removed in 2.8 https://git.ufz.de/rdm-software/saqc/-/merge_requests/891
    clean_doc = clean_doc.splitlines()
    types = ["`Any`", "bool", "callable", "float", "int", "`SaQCFields`", "str", "{"]
    if len(clean_doc) > 0 and any([clean_doc[0].startswith(t) for t in types]):
        clean_doc = "\n".join(clean_doc[1:])
    else:
        clean_doc = "\n".join(clean_doc)

    # https://git.ufz.de/rdm-software/saqc/-/issues/518
    clean_doc = re.sub(r'pd\.([a-zA-Z0-9_.]+)', r'pandas.\1', clean_doc, flags=re.IGNORECASE)
    clean_doc = re.sub(r'np\.([a-zA-Z0-9_.]+)', r'numpy.\1', clean_doc, flags=re.IGNORECASE)

    # can be removed in >2.7.0
    clean_doc = re.sub(r'^[:]+\s*', '', clean_doc).strip()

    if not clean_doc:
        return param_name, ""

    paragraphs = re.split(r'\n\s*\n', clean_doc, maxsplit=1)
    first_paragraph = paragraphs[0].replace("\n", " ").strip()
    rest_of_paragraphs = paragraphs[1].strip() if len(paragraphs) > 1 else ""

    sentence_split = re.split(r'(\.\s+)', first_paragraph, maxsplit=1)

    is_single_sentence = len(sentence_split) == 1
    is_single_paragraph = not rest_of_paragraphs
    is_long = len(first_paragraph) > 80

    help_text = ""

    if is_single_sentence and is_single_paragraph and is_long:
        parts = first_paragraph.split(',')
        if len(parts) > 2:
            label = parts[0] + "," + parts[1]
            help_text = ",".join(parts[2:]).strip()
        else:
            label = first_paragraph
            help_text = ""
    else:
        label = sentence_split[0].strip()
        if not label:
            return param_name, ""

        rest_of_first_paragraph = ""
        if len(sentence_split) > 1:
            rest_of_first_paragraph = "".join(sentence_split[1:]).strip()

        if rest_of_first_paragraph and rest_of_paragraphs:
            help_text = rest_of_first_paragraph + "\n\n" + rest_of_paragraphs
        elif rest_of_first_paragraph:
            help_text = rest_of_first_paragraph
        else:
            help_text = rest_of_paragraphs

    help_text = help_text.replace("\n", " ").strip()
    help_text = re.sub(r'^[,\.:;-]+\s*', '', help_text).strip()
    help_text = help_text.rstrip(".")
    label = label.strip(" .")

    return label, help_text


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


def check_method_for_skip_condition(method: Callable, module: "ModuleType") -> bool:
    """
    Checks if method should be skipped.

    Criteria:
    - Is marked as deprecated
    - Contains a parameter expecting a Function/CurveFitter
      (detected by name 'func' OR type 'Callable'/'CurveFitter'/'GenericFunction')
    - AND is not a Literal (Selection)
    - AND is NOT optional (Mandatory)

    Returns True if the entire method should be skipped.
    """

    if is_method_deprecated(method):
        sys.stderr.write(
            f"Info skipping ({module.__name__}.{method.__name__}): deprecated method\n"
        )
        return True

    if f"{module.__name__}|{method.__name__}" in SKIP_METHODS:
        sys.stderr.write(
            f"Info skipping ({module.__name__}.{method.__name__}): hardcoded to be skipped\n"
        )
        return True

    parameters = inspect.signature(method).parameters

    for param_name, param in parameters.items():
        annotation = param.annotation
        raw_annotation_str = ""
        if isinstance(annotation, (str, ForwardRef)):
            raw_annotation_str = annotation.__forward_arg__ if isinstance(annotation, ForwardRef) else str(annotation)
        elif annotation is not inspect.Parameter.empty:
            raw_annotation_str = str(annotation).replace("typing.", "")

        is_func_name = "func" in param_name.lower()
        is_func_type = any(t in raw_annotation_str for t in ["Callable", "GenericFunction", "CurveFitter"])

        if not (is_func_name or is_func_type):
            continue

        is_literal_type = "Literal[" in raw_annotation_str or raw_annotation_str in SAQC_CUSTOM_SELECT_TYPES
        if is_literal_type:
            continue

        if raw_annotation_str.startswith('Union[') and raw_annotation_str.endswith(']'):
            inner_content = raw_annotation_str[6:-1]
            type_parts = _split_type_string_safely(inner_content)
        else:
            type_parts = _split_type_string_safely(raw_annotation_str)

        is_python_optional_by_default = (param.default is not inspect.Parameter.empty)
        is_optional_by_none = 'None' in type_parts

        is_truly_optional = is_python_optional_by_default or is_optional_by_none

        if is_truly_optional:
            continue

        sys.stderr.write(f"Info ({module.__name__}): Skipping method '{method.__name__}' from XML. Reason: Contains MANDATORY function-parameter '{param_name}' (Type: {raw_annotation_str}) which cannot be mapped to Galaxy UI.\n")
        return True

    return False


def is_module_deprecated(module: "ModuleType") -> bool:
    docstring = module.__doc__
    if not docstring:
        return False

    if ".. deprecated::" in docstring.lower():
        sys.stderr.write(
            f"Info: Skip deprecated module '{module.__name__}'. (Reason: '.. deprecated::' found).\n"
        )
        return True

    return False


def is_method_deprecated(method: Callable) -> bool:

    doc_sections = parse_docstring(method)
    header = doc_sections.get("", "")

    if ".. deprecated::" in header:
        return True

    return False


def is_parameter_deprecated(param_docs: Dict[str, str], param_name: str) -> bool:
    param_doc_entry = param_docs.get(param_name, "")
    param_doc_lines = param_doc_entry.split('\n')

    first_line = param_doc_lines[0].lower().strip() if param_doc_lines else ""
    is_deprecated = "deprecated" in first_line
    if not is_deprecated:
        is_deprecated = ".. deprecated::" in param_doc_entry.lower()
    return is_deprecated


def _create_param_from_type_str(type_str: str, param_name: str, param_constructor_args: dict, is_optional: bool) -> Optional[object]:

    pattern_offset = r"\s*(\d+(\.\d+)?)?\s*[A-Za-z]+(?:-[A-Za-z]{3})?\s*"

    regex_offset_full = f"(^$)|({pattern_offset})"
    msg_offset = "Must be a valid Pandas offset/frequency string (e.g., '1D', '1M', 'min', 'W-MON')."
    validator_offset = ValidatorParam(type="regex", message=msg_offset, text=regex_offset_full)

    pattern_timedelta = r"-?(\d+(\.\d*)?|\.\d+)\s*(W|D|days?|d|H|hours?|hr|h|T|minutes?|min|m|S|seconds?|sec|s|L|milliseconds?|ms|U|microseconds?|us|N|nanoseconds?|ns)\s*"

    regex_timedelta_full = f"(^$)|(^{pattern_timedelta}$)"
    msg_timedelta = "Must be a valid Pandas Timedelta string (e.g., '1d', '2.5h', '30min'). Month (M) or Year (Y) are NOT allowed."
    validator_timedelta = ValidatorParam(type="regex", message=msg_timedelta, text=regex_timedelta_full)

    regex_combined = f"(^$)|({pattern_offset})|(^{pattern_timedelta}$)"
    msg_combined = "Accepts both Pandas Frequencies (e.g. '1M', 'W-SAT') AND Timedeltas (e.g. '3 days', '1.5h')."
    validator_combined = ValidatorParam(type="regex", message=msg_combined, text=regex_combined)

    param_object = None
    base_type_str = type_str.strip()

    creation_args = param_constructor_args.copy()
    base_help = creation_args.get("help", "")

    text_types = ('list', 'sequence', 'arraylike', 'pd.series', 'pd.dataframe', 'pd.datetimeindex',
                  'str', 'string', 'any')

    is_text_type = base_type_str.lower() in text_types
    is_list_str = re.fullmatch(r"(list|Sequence)\[\s*str\s*\]", base_type_str, re.IGNORECASE)

    if is_text_type or is_list_str:
        creation_args.pop("optional", None)

    tuple_match = re.fullmatch(r"tuple(?:\[\s*(.*)\s*\])?", base_type_str, re.IGNORECASE)
    if tuple_match:
        inner_types_str = tuple_match.group(1) or ""
        inner_types_str = inner_types_str.replace("...", "").strip()
        inner_types_list = _split_type_string_safely(inner_types_str)

        type_0 = inner_types_list[0] if len(inner_types_list) >= 1 else "str"
        type_1 = inner_types_list[1] if len(inner_types_list) >= 2 else (inner_types_list[0] if len(inner_types_list) == 1 else "str")

        title = param_constructor_args.get("label", param_name)

        repeat = Repeat(name=param_name, title=title, help=base_help)

        inner_args_0 = {'label': f"{param_name}_pos0", 'help': f"First element (index 0) of the {param_name} tuple.", 'optional': is_optional}
        param_0 = _create_param_from_type_str(type_0, f"{param_name}_pos0", inner_args_0, is_optional)

        inner_args_1 = {'label': f"{param_name}_pos1", 'help': f"Second element (index 1) of the {param_name} tuple.", 'optional': is_optional}
        param_1 = _create_param_from_type_str(type_1, f"{param_name}_pos1", inner_args_1, is_optional)

        if param_0:
            repeat.append(param_0)
        else:
            fallback_args_0 = inner_args_0.copy()
            fallback_args_0.pop("optional", None)
            p0 = TextParam(name=f"{param_name}_pos0", **fallback_args_0)
            if not is_optional:
                p0.append(ValidatorParam(type="empty_field"))
            repeat.append(p0)

        if param_1:
            repeat.append(param_1)
        else:
            fallback_args_1 = inner_args_1.copy()
            fallback_args_1.pop("optional", None)
            p1 = TextParam(name=f"{param_name}_pos1", **fallback_args_1)
            if not is_optional:
                p1.append(ValidatorParam(type="empty_field"))
            repeat.append(p1)

        return repeat

    if base_type_str in ('SaQCFields', 'NewSaQCFields'):
        creation_args.pop("value", None)
        creation_args['type'] = "data_column"
        creation_args['data_ref'] = "data"
        creation_args['multiple'] = True
        param_object = SelectParam(argument=param_name, **creation_args)

    elif is_list_str:
        param_object = TextParam(argument=param_name, multiple=True, **creation_args)

    elif re.fullmatch(r"list\[\s*tuple\[\s*float\s*,\s*float\s*\]\s*\]", base_type_str, re.IGNORECASE):
        repeat = Repeat(name=param_name, title=creation_args.get("label", param_name), help=creation_args.get("help", ""))
        repeat.append(FloatParam(name=f"{param_name}_min", label=f"{param_name}_min"))
        repeat.append(FloatParam(name=f"{param_name}_max", label=f"{param_name}_max"))
        param_object = repeat

    elif base_type_str.lower() in ('list', 'sequence', 'arraylike', 'pd.series', 'pd.dataframe', 'pd.datetimeindex'):
        param_object = TextParam(argument=param_name, **creation_args)

    elif base_type_str.lower() == 'pd.timedelta':
        specific_help = " Format: Fixed time duration (no calendar logic). Examples: '1d', '2.5h', '30min'. (No 'M' or 'Y')."
        creation_args["help"] = (base_help + specific_help).strip()
        param_object = TextParam(argument=param_name, **creation_args)
        param_object.append(validator_timedelta)

    elif base_type_str.lower() == 'offsetlike' or 'offsetlike' in base_type_str:
        specific_help = " Format: Time object. Accepts Pandas Frequencies (e.g. '1M', 'W-MON') OR Timedeltas (e.g. '3 days', '1.5h')."
        creation_args["help"] = (base_help + specific_help).strip()
        param_object = TextParam(argument=param_name, **creation_args)
        param_object.append(validator_combined)

    elif base_type_str in ['OffsetStr', 'FreqStr']:
        specific_help = " Format: Calendar frequency/offset. Examples: '1D', '1M' (Month), 'W-MON' (Weekly Mon)."
        creation_args["help"] = (base_help + specific_help).strip()
        param_object = TextParam(argument=param_name, **creation_args)
        param_object.append(validator_offset)

    elif base_type_str.lower() in ('dict', 'dictionary'):
        repeat = Repeat(name=param_name, title=creation_args.get("label", param_name), help=base_help)
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
            creation_args["default"] = creation_args.pop("value", None)
            options = {o: o for o in options_list}
            param_object = SelectParam(argument=param_name, options=options, **creation_args)

    elif base_type_str in SAQC_CUSTOM_SELECT_TYPES:
        type_obj = SAQC_CUSTOM_SELECT_TYPES[base_type_str]
        args = get_args(type_obj)
        if get_origin(type_obj) is Literal and args:
            creation_args["default"] = creation_args.pop("value", None)
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

    elif base_type_str in ['str', 'string', 'Any']:
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

        if 'truevalue' in param_object.node.attrib:
            del param_object.node.attrib['truevalue']
        if 'falsevalue' in param_object.node.attrib:
            del param_object.node.attrib['falsevalue']
    # hardcoded path parameter of tools.plot
    # https://git.ufz.de/rdm-software/saqc/-/issues/511
    elif base_type_str == 'OutputPath':
        param_object = TextParam(argument=param_name, **creation_args)
        param_object.append(ValidatorParam(type="regex", text=r"[\w -\.]+"))

    if param_object:
        if isinstance(param_object, TextParam) and not getattr(param_object, 'multiple', False):
            if hasattr(param_object, 'optional'):
                if 'optional' in param_object.node.attrib:
                    del param_object.node.attrib['optional']

            if not is_optional:
                param_object.append(ValidatorParam(type="empty_field"))

    return param_object


def _get_user_friendly_type_name(type_str: str) -> str:
    """
    Maps types to user-readable names recursively.
    Examples:
    - 'list[tuple[float, float]]' -> 'List of Tuples (Float, Float)'
    - 'pd.Timedelta' -> 'pd.Timedelta'
    - 'OffsetLike' -> 'Time Object (Offset/Timedelta)'
    """
    s = type_str.strip()
    clean = s.replace("typing.", "").strip()
    lower = clean.lower()

    if 'pd.timedelta' in lower:
        return "pd.Timedelta"

    if 'offsetlike' in lower or 'OffsetLike' in clean:
        return "Time Object (Offset/Timedelta)"

    if any(x in clean for x in ['OffsetStr', 'FreqStr']):
        return "OffsetStr (Pandas Frequency)"

    if 'saqcfields' in lower:
        return "Column Selection"

    if re.search(r"list\[\s*tuple\[\s*float\s*,\s*float\s*\]\s*\]", lower):
        return "List of Tuples (Float, Float)"

    if re.fullmatch(r"tuple\[\s*float\s*,\s*float\s*\]", lower):
        return "Tuple (Float, Float)"

    list_match = re.match(r"^(?:list|sequence|array(?:like)?)(?:\[(.*)\])?$", clean, re.IGNORECASE)
    if list_match:
        inner_content = list_match.group(1)
        if inner_content:
            inner_name = _get_user_friendly_type_name(inner_content)

            if not inner_name.endswith('s') and inner_name not in ["Integer", "Float", "String", "Boolean", "pd.Timedelta"]:
                return f"List of {inner_name}s"
            return f"List of {inner_name}"
        return "List"

    tuple_match = re.match(r"^tuple(?:\[(.*)\])?$", clean, re.IGNORECASE)
    if tuple_match:
        inner_content = tuple_match.group(1)
        if inner_content:
            if "..." in inner_content:
                base_type = inner_content.split(',')[0]
                return f"Tuple of {_get_user_friendly_type_name(base_type)}s"

            parts = [p.strip() for p in inner_content.split(',')]
            if not any('[' in p for p in parts):
                friendly_parts = [_get_user_friendly_type_name(p) for p in parts]
                return f"Tuple ({', '.join(friendly_parts)})"
        return "Tuple"

    if lower.startswith("dict"):
        return "Dictionary"

    if re.search(r"(^|[^a-z])int(eger)?([^a-z]|$)", lower):
        return "Integer"

    if re.search(r"(^|[^a-z])float([^a-z]|$)", lower):
        return "Float"

    if 'bool' in lower:
        return "Boolean"

    if lower in ['str', 'string', 'any']:
        return "String"

    if 'literal' in lower:
        return "Selection"

    return clean


def _parse_parameter_annotation(
    param: inspect.Parameter, module_name: str, method_name: str
) -> Tuple[str, list[str], bool]:
    """
    Parses a parameter's type annotation to extract its raw string,
    a cleaned list of type parts (for Unions), and its optionality.
    """

    if f"{module_name}|{method_name}|{param.name}" in HARDCODED_PARAMETERS:
        return HARDCODED_PARAMETERS[f"{module_name}|{method_name}|{param.name}"]

    annotation = param.annotation
    raw_annotation_str = ""
    if isinstance(annotation, (str, ForwardRef)):
        raw_annotation_str = (
            annotation.__forward_arg__
            if isinstance(annotation, ForwardRef)
            else str(annotation)
        )
    elif annotation is not inspect.Parameter.empty:
        raw_annotation_str = str(annotation).replace("typing.", "")

    is_default_none = param.default is None

    if raw_annotation_str.startswith("Union[") and raw_annotation_str.endswith("]"):
        inner_content = raw_annotation_str[6:-1]
        type_parts = _split_type_string_safely(inner_content)
    else:
        type_parts = _split_type_string_safely(raw_annotation_str)

    is_optional_by_none = "None" in type_parts

    is_truly_optional = is_default_none or is_optional_by_none

    type_parts_without_none = [p for p in type_parts if p != "None"]

    type_parts_cleaned = [
        p
        for p in type_parts_without_none
        if p.lower() not in ("dict", "dictionary")
    ]

    if not type_parts_cleaned and type_parts_without_none:
        sys.stderr.write(
            f"Info ({module_name}): Skipping param '{param.name}' "
            "because its type is 'dict' (or Union of dicts), "
            "which is not UI-configurable.\n"
        )
        return raw_annotation_str, [], is_truly_optional

    is_all_saqc_fields = False
    if len(type_parts_cleaned) > 1:
        is_all_saqc_fields = all(
            p in ("SaQCFields", "NewSaQCFields") for p in type_parts_cleaned
        )

    if is_all_saqc_fields:
        type_parts_cleaned = ["SaQCFields"]

    return raw_annotation_str, type_parts_cleaned, is_truly_optional


def _handle_func_parameter(
    param_name: str,
    raw_annotation_str: str,
    is_literal_type: bool,
    method: Callable,
    module: "ModuleType",
    param_constructor_args: dict,
    is_truly_optional: bool,
) -> Tuple[Optional[object], bool]:
    """
    Handles logic for parameters identified as 'func' parameters.
    """

    if is_literal_type:
        return None, False

    if is_truly_optional:
        sys.stderr.write(
            f"Info ({module.__name__}): Skipping optional 'func'-parameter "
            f"'{param_name}' in method '{method.__name__}'.\n"
        )
        return None, False
    else:
        sys.stderr.write(
            f"Warning ({module.__name__}): Skipping non-optional 'func'-parameter "
            f"'{param_name}' in method '{method.__name__}' which is mandatory.\n"
        )
        return None, True


def _create_parameter_widget(
    param_name: str,
    type_parts_cleaned: list[str],
    param_constructor_args: dict,
    is_truly_optional: bool,
    label: str,
    help_text: str,
    module: "ModuleType",
    method: Callable,
    optional_arg: dict,
) -> Optional[object]:
    """
    Creates the main parameter widget (e.g., Text, Select, Conditional)
    based on the cleaned list of type annotations.
    """
    param_object = None

    if len(type_parts_cleaned) > 1:
        has_literal = any(
            "Literal[" in part or part in SAQC_CUSTOM_SELECT_TYPES
            for part in type_parts_cleaned
        )

        if has_literal:
            original_count = len(type_parts_cleaned)
            type_parts_cleaned = [
                part
                for part in type_parts_cleaned
                if not any(
                    func_type in part
                    for func_type in ["Callable", "CurveFitter", "GenericFunction"]
                )
            ]

            if len(type_parts_cleaned) < original_count:
                sys.stderr.write(
                    f"Info ({module.__name__}): Hiding 'Callable/Function' option "
                    f"for parameter '{param_name}' in method '{method.__name__}', "
                    "as a Literal option exists in the Union.\n"
                )

    if len(type_parts_cleaned) == 1:
        single_type_str = type_parts_cleaned[0]
        if single_type_str == "slice":
            return None
        elif any(
            func_type in single_type_str
            for func_type in ["Callable", "CurveFitter", "GenericFunction"]
        ):
            local_constructor_args = param_constructor_args.copy()
            local_constructor_args.pop("optional", None)
            param_object = TextParam(argument=param_name, **local_constructor_args)
            if not is_truly_optional:
                param_object.append(ValidatorParam(type="empty_field"))
        else:
            param_object = _create_param_from_type_str(
                single_type_str, param_name, param_constructor_args, is_truly_optional
            )

    elif len(type_parts_cleaned) > 1:
        conditional = Conditional(name=f"{param_name}_cond")

        type_options = [
            (f"type_{i}", _get_user_friendly_type_name(part))
            for i, part in enumerate(type_parts_cleaned)
        ]

        selector_help = "The parameter supports different input formats, you can choose which one suites your application."

        selector = SelectParam(
            name=f"{param_name}_selector",
            label=f"Choose type for '{label}'",
            help=selector_help,
            options=dict(type_options),
        )
        conditional.append(selector)

        for i, part_str in enumerate(type_parts_cleaned):
            when = When(value=f"type_{i}")

            inner_param_args = {"label": label, "help": help_text, **optional_arg}

            if part_str == "slice":
                start_param = IntegerParam(
                    name=f"{param_name}_start",
                    label=f"{label} (start index)",
                    min=0,
                    help="Start index of the slice (e.g., 0).",
                    **optional_arg,
                )
                end_param = IntegerParam(
                    name=f"{param_name}_end",
                    label=f"{label} (end index)",
                    min=0,
                    help="End index of the slice (exclusive).",
                    **optional_arg,
                )
                when.extend([start_param, end_param])
            elif re.fullmatch(
                r"tuple\[\s*float\s*,\s*float\s*\]", part_str, re.IGNORECASE
            ):

                min_param = FloatParam(
                    name=f"{param_name}_min", label=f"{param_name}_min", **optional_arg
                )
                max_param = FloatParam(
                    name=f"{param_name}_max", label=f"{param_name}_max", **optional_arg
                )
                when.extend([min_param, max_param])
            elif any(
                func_type in part_str
                for func_type in ["Callable", "CurveFitter", "GenericFunction"]
            ):

                inner_param_args.pop("optional", None)
                inner_param = TextParam(argument=param_name, **inner_param_args)
                if not is_truly_optional:
                    inner_param.append(ValidatorParam(type="empty_field"))
                when.append(inner_param)
            else:
                inner_param = _create_param_from_type_str(
                    part_str, param_name, inner_param_args, is_truly_optional
                )
                if inner_param:
                    when.append(inner_param)
                else:
                    sys.stderr.write(
                        f"Info ({module.__name__}): Could not create UI element "
                        f"for type '{part_str}' in Conditional '{param_name}'. "
                        "Falling back to info text.\n"
                    )
                    info_text = TextParam(
                        name=f"{param_name}_info",
                        type="text",
                        value="This type is not usable in Galaxy.",
                        label="Info",
                        help="This option is for programmatic use and cannot be set from the UI.",
                    )
                    when.append(info_text)

            conditional.append(when)
        param_object = conditional

    return param_object


def _create_param_from_default(
    param: inspect.Parameter, param_constructor_args: dict
) -> Optional[object]:
    """
    Creates a parameter widget based on the default value,
    used when no type annotation is present.
    """
    param_object = None
    default_value = param.default

    if not isinstance(default_value, bool):
        param_constructor_args["value"] = str(default_value)

    if isinstance(default_value, bool):
        param_constructor_args.pop("value", None)
        param_constructor_args.pop("optional", None)

        param_object = BooleanParam(
            argument=param.name, checked=default_value, **param_constructor_args
        )

        if 'truevalue' in param_object.node.attrib:
            del param_object.node.attrib['truevalue']
        if 'falsevalue' in param_object.node.attrib:
            del param_object.node.attrib['falsevalue']

    elif isinstance(default_value, int):
        param_object = IntegerParam(argument=param.name, **param_constructor_args)
    elif isinstance(default_value, float):
        param_object = FloatParam(argument=param.name, **param_constructor_args)
    elif isinstance(default_value, str):
        param_object = TextParam(argument=param.name, **param_constructor_args)

    return param_object


def get_method_params(method: Callable, module: "ModuleType", tracing=False):
    """
    Generates a list of Galaxy XML parameter objects for a given method.
    """
    sections = parse_docstring(method)
    param_docs = parse_parameter_docs(sections)
    xml_params = []

    parameters = inspect.signature(method).parameters

    for param_name, param in parameters.items():
        if (
            param_name in ["self", "kwargs", "reduce_func", "metric"]
            or "kwarg" in param_name.lower()
        ):
            continue

        if is_parameter_deprecated(param_docs, param_name):
            sys.stderr.write(
                f"Info ({module.__name__}): Skipping deprecated parameter '{param_name}' "
                f"in method '{method.__name__}'. (Reason: Found 'deprecated' marker in docstring).\n"
            )
            continue

        (
            raw_annotation_str,
            type_parts_cleaned,
            is_truly_optional,
        ) = _parse_parameter_annotation(param, module.__name__, method.__name__)

        if not type_parts_cleaned and raw_annotation_str:
            sys.stderr.write(
                f"Info ({module.__name__}): Skipping parameter '{param_name}' "
                f"in method '{method.__name__}'. (Reason: No type parts but raw annotation string).\n"
            )
            continue

        label, help_text = get_label_help(param_name, param_docs)
        optional_arg = {"optional": True} if is_truly_optional else {}
        param_constructor_args = {"label": label, "help": help_text, **optional_arg}
        param_object = None

        is_func_name = "func" in param_name.lower()
        is_func_type = any(t in raw_annotation_str for t in ["Callable", "GenericFunction", "CurveFitter"])
        is_func_param = is_func_name or is_func_type

        is_literal_type = (
            "Literal[" in raw_annotation_str
            or raw_annotation_str in SAQC_CUSTOM_SELECT_TYPES
        )

        if is_func_param:
            func_param_obj, should_skip = _handle_func_parameter(
                param_name,
                raw_annotation_str,
                is_literal_type,
                method,
                module,
                param_constructor_args,
                is_truly_optional,
            )
            if should_skip:
                continue
            if func_param_obj:
                xml_params.append(func_param_obj)
                continue

        if "mpl.axes.Axes" in raw_annotation_str:
            continue

        if "Sequence[SaQC]" in raw_annotation_str:
            data_param = DataParam(
                name=param_name, format="csv", multiple=True, **param_constructor_args
            )
            xml_params.append(data_param)
            continue

        # Can be dropped with 
        # https://git.ufz.de/rdm-software/saqc/-/merge_requests/887
        # https://git.ufz.de/rdm-software/saqc/-/merge_requests/894
        # https://git.ufz.de/rdm-software/saqc/-/merge_requests/895
        # or replaced by a correct implementation for https://git.ufz.de/rdm-software/saqc/-/issues/516
        if "field" in param_name.lower() or param_name in ["target", "reference"]:          
            creation_args = param_constructor_args.copy()
            creation_args.pop("value", None)
            creation_args["type"] = "data_column"
            creation_args["data_ref"] = "data"
            creation_args["multiple"] = False
            if "list" in raw_annotation_str.lower() or "sequence" in raw_annotation_str.lower():
                creation_args["multiple"] = True

            param_object = SelectParam(argument=param_name, **creation_args)
            xml_params.append(param_object)
            continue

        if (
            param.default is not inspect.Parameter.empty
            and param.default is not None
            and not isinstance(param.default, bool)
        ):
            if not isinstance(param.default, Callable):
                param_constructor_args["value"] = str(param.default)

        param_object = _create_parameter_widget(
            param_name,
            type_parts_cleaned,
            param_constructor_args,
            is_truly_optional,
            label,
            help_text,
            module,
            method,
            optional_arg,
        )

        if param_object is None and "slice" in type_parts_cleaned:
            start_param_args = {
                "name": f"{param_name}_start",
                "label": f"{param_name}_start",
                "min": 0,
                "help": "Start index of the slice (e.g., 0).",
                **optional_arg,
            }
            end_param_args = {
                "name": f"{param_name}_end",
                "label": f"{param_name}_end",
                "min": 0,
                "help": "End index of the slice (exclusive).",
                **optional_arg,
            }
            start_param = IntegerParam(**start_param_args)
            end_param = IntegerParam(**end_param_args)
            xml_params.extend([start_param, end_param])
            continue

        if (
            not param_object
            and not raw_annotation_str.strip()
            and param.default is not inspect.Parameter.empty
        ):
            param_object = _create_param_from_default(param, param_constructor_args)

        if param_object:
            xml_params.append(param_object)
        elif raw_annotation_str.strip() and raw_annotation_str.strip() not in ["slice"]:
            sys.stderr.write(
                f"Info ({module.__name__}): Unhandled annotation for param "
                f"'{param_name}': '{raw_annotation_str}'. "
                "Creating default TextParam.\n"
            )

            local_constructor_args = param_constructor_args.copy()
            local_constructor_args.pop("optional", None)
            fallback_param = TextParam(argument=param_name, **local_constructor_args)

            if not is_truly_optional:
                fallback_param.append(ValidatorParam(type="empty_field"))
            xml_params.append(fallback_param)

    return xml_params


def get_methods_conditional(methods, module, tracing=False):

    filtered_methods = []
    for method_obj in methods:
        if check_method_for_skip_condition(method_obj, module):
            continue
        filtered_methods.append(method_obj)
    method_conditional = Conditional(name="method_cond")
    method_select_options = []

    if not filtered_methods:
        return None

    for method_obj in filtered_methods:
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
        raise Exception(f"Could not determine select options for {methods} in {module}")

    for method_obj in filtered_methods:
        method_name = method_obj.__name__
        method_when = When(value=method_name)
        params = get_method_params(method_obj, module, tracing=tracing)
        for p in params:
            method_when.append(p)
        method_conditional.append(method_when)

    return method_conditional


def generate_tool_xml(tracing=False):
    """Generates XML-Definition of Galaxy-Tools."""
    command_override = [
        """
#set $first_data_file = $data[0]
  '$__tool_directory__'/json_to_saqc_config.py '$param_conf' '$first_data_file' > config.csv
#if str($run_test_mode) == "false":
  &&
  #for $i, $d in enumerate($data)
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

    module_conditional = Conditional(name="module_cond")

    module_select_options = []
    valid_modules_data = []

    for module_name, module_obj in modules:
        if is_module_deprecated(module_obj):
            continue

        methods = get_methods(module_obj)
        if not methods:
            continue

        has_valid_methods = False
        valid_methods_list = []

        for method_obj in methods:
            if not check_method_for_skip_condition(method_obj, module_obj):
                has_valid_methods = True
                valid_methods_list.append(method_obj)

        if has_valid_methods:
            valid_modules_data.append((module_name, module_obj, valid_methods_list))
            module_doc = _get_doc(module_obj.__doc__)
            if not module_doc:
                module_doc = module_name
            module_select_options.append((module_name, f"{module_name}: {module_doc}"))
        else:
            pass

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
            )
        )

    for module_name, module_obj, valid_methods in valid_modules_data:
        module_when = When(value=module_name)

        methods_conditional_obj = get_methods_conditional(
            valid_methods, module_obj, tracing=tracing
        )

        if methods_conditional_obj:
            module_when.append(methods_conditional_obj)
        else:
            module_when.append(
                TextParam(
                    name=f"{module_name}_no_methods_conditional",
                    type="text",
                    value=f"Could not generate method selection for module '{module_name}'.",
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
    plot_outputs.append(
        OutputFilter(text="any( r['module_cond']['module_select'] == 'tools' and r['module_cond']['method_cond']['method_select'] == 'plot' for r in methods_repeat)")
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
    tuple_match = re.fullmatch(r"tuple(?:\[\s*(.*)\s*\])?", clean_type, re.IGNORECASE)
    if tuple_match:
        inner_types_str = tuple_match.group(1)

        if inner_types_str is None:
            inner_types_str = ""

        inner_types_str = inner_types_str.replace("...", "").strip()
        inner_types_list = _split_type_string_safely(inner_types_str)

        type_0 = "str"
        if len(inner_types_list) >= 1:
            type_0 = inner_types_list[0]

        type_1 = "str"
        if len(inner_types_list) >= 2:
            type_1 = inner_types_list[1]
        elif len(inner_types_list) == 1:
            type_1 = inner_types_list[0]

        def get_simple_val(typ):
            clean_typ = typ.strip()
            if clean_typ == 'int' or 'Int' in clean_typ:
                return 1
            if clean_typ == 'float' or 'Float' in clean_typ:
                return 1.0
            if clean_typ == 'bool':
                return True

            if 'pd.timedelta' in clean_typ.lower():
                return "1d"
            if 'OffsetStr' in clean_typ or 'FreqStr' in clean_typ or 'OffsetLike' in clean_typ:
                return "1D"

            if 'SaQCFields' in clean_typ or 'NewSaQCFields' in clean_typ:
                return 1
            return "test_string"

        val_0 = get_simple_val(type_0)
        val_1 = get_simple_val(type_1)

        return [
            {f"{param_name}_pos0": val_0, f"{param_name}_pos1": val_1}
        ]

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

    if 'pd.timedelta' in clean_type.lower():
        return "1d"
    if any(s in clean_type.lower() for s in ['offset', 'freq']):
        return "1D"

    return "a_string"


def generate_test_variants(method: Callable, module: "ModuleType") -> list:
    variants = []
    base_params = {}
    complex_params = {}

    sections = parse_docstring(method)
    param_docs = parse_parameter_docs(sections)

    parameters = inspect.signature(method).parameters

    for param_name, param in parameters.items():
        if param_name in ["self", "kwargs", "reduce_func", "metric"] or "kwarg" in param_name.lower():
            continue

        if is_parameter_deprecated(param_docs, param_name):
            continue

        if "field" in param_name.lower() or param_name in ["target", "reference"]:
            base_params[param_name] = 1
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

        is_func_name = "func" in param_name.lower()
        is_func_type = any(t in raw_annotation_str for t in ["Callable", "GenericFunction", "CurveFitter"])
        is_func_param = is_func_name or is_func_type

        is_literal_type = "Literal[" in raw_annotation_str or raw_annotation_str in SAQC_CUSTOM_SELECT_TYPES

        if is_func_param:
            if is_literal_type:
                pass

            else:
                is_python_optional_by_default = (param.default is not inspect.Parameter.empty)
                if raw_annotation_str.startswith('Union[') and raw_annotation_str.endswith(']'):
                    inner_content = raw_annotation_str[6:-1]
                    type_parts = _split_type_string_safely(inner_content)
                else:
                    type_parts = _split_type_string_safely(raw_annotation_str)
                is_optional_by_none = 'None' in type_parts
                is_truly_optional = is_python_optional_by_default or is_optional_by_none

                if is_truly_optional:
                    continue
                else:
                    continue

        if raw_annotation_str.startswith('Union[') and raw_annotation_str.endswith(']'):
            inner_content = raw_annotation_str[6:-1]
            type_parts = _split_type_string_safely(inner_content)
        else:
            type_parts = _split_type_string_safely(raw_annotation_str)

        type_parts_without_none = [p for p in type_parts if p.strip() != 'None']

        type_parts_cleaned = [
            p for p in type_parts_without_none
            if p.lower() not in ('dict', 'dictionary')
        ]
        if not type_parts_cleaned and type_parts_without_none:
            continue

        is_all_saqc_fields = False
        if len(type_parts_cleaned) > 1:
            is_all_saqc_fields = all(
                p in ('SaQCFields', 'NewSaQCFields') for p in type_parts_cleaned
            )

        if is_all_saqc_fields:
            type_parts_cleaned = ['SaQCFields']

        if len(type_parts_cleaned) > 1:

            has_literal = any(
                "Literal[" in part or part in SAQC_CUSTOM_SELECT_TYPES for part in type_parts_cleaned
            )

            if has_literal:
                type_parts_cleaned = [
                    part for part in type_parts_cleaned
                    if not any(func_type in part for func_type in ['Callable', 'CurveFitter', 'GenericFunction'])
                ]

        if len(type_parts_cleaned) > 1:
            complex_params[param_name] = type_parts_cleaned
        elif type_parts_cleaned:
            single_type_str = type_parts_cleaned[0]
            if single_type_str in ('SaQCFields', 'NewSaQCFields'):
                base_params[param_name] = 1
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
        if not type_parts:
            continue
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
        if is_module_deprecated(module_obj):
            continue

        methods = get_methods(module_obj)
        for method in methods:

            if check_method_for_skip_condition(method, module_obj):
                continue

            method_name = method.__name__
            try:
                test_variants = generate_test_variants(method, module_obj)
            except Exception as e:
                print(f"Error generating variants for {method_name}: {e}", file=sys.stderr)
                continue

            for variant in test_variants:
                expect_num_outputs = "2"
                if module_name == "tools" and method.__name__ == "plot":
                    expect_num_outputs = "3"
                test_elem = ET.SubElement(all_tests_macro, "test", {"expect_num_outputs": expect_num_outputs})
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

    try:
        SAQC_CUSTOM_SELECT_TYPES.update(discover_literals(saqc_types))
        for _, func_module in inspect.getmembers(saqc.funcs, inspect.ismodule):
            SAQC_CUSTOM_SELECT_TYPES.update(discover_literals(func_module))
    except (ImportError, TypeError) as e:
        sys.stderr.write(f"Warning: Could not automatically discover saqc Literals: {e}\n")

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
