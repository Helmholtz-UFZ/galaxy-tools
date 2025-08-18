import inspect
import re
import sys
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
import csv


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
from saqc.core import DictOfSeries, SaQC
from saqc.funcs.generic import GenericFunction
from saqc.lib import types as saqc_types
from saqc.lib.types import CurveFitter
from typing_inspect import is_callable_type, is_union_type, is_union_type


if TYPE_CHECKING:
    
    from types import ModuleType

TRACING_DATA = []

def discover_literals(*modules_to_scan) -> Dict[str, Any]:
    """
    Durchsucht die übergebenen Python-Module nach Literal-Definitionen
    und gibt sie als Dictionary zurück.
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
    from saqc.lib import types as saqc_types
    SAQC_CUSTOM_SELECT_TYPES.update(discover_literals(saqc_types))
    for _, func_module in inspect.getmembers(saqc.funcs, inspect.ismodule):
        SAQC_CUSTOM_SELECT_TYPES.update(discover_literals(func_module))
except (ImportError, TypeError) as e:
    sys.stderr.write(f"Warning: Could not automatically discover saqc Literals: {e}\n")


def clean_annotation_string(s: str) -> str:
    """
    Wandelt Nicht-Standard-Typ-Annotationen aus saqc in gültigen Python-Code um.
    Diese Funktion dient als Fallback für komplexe Typen, die von eval() verarbeitet werden,
    insbesondere für die Test-Generierung.
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


def _param_to_element(p_obj: Any) -> ET.Element:
    """
    Wandelt ein galaxyxml-Parameterobjekt rekursiv in ein ET.Element um,
    indem es die Objektattribute direkt inspiziert und den Tag-Namen ableitet.
    """
    class_name = p_obj.__class__.__name__

    tag = "param"
    param_type = None

    container_tags = {
        "Conditional": "conditional",
        "Repeat": "repeat",
        "When": "when",
        "ValidatorParam": "validator",
        "DiscoverDatasets": "discover_datasets",
    }

    type_map = {
        "TextParam": "text",
        "IntegerParam": "integer",
        "FloatParam": "float",
        "DataParam": "data",
        "BooleanParam": "boolean",
        "SelectParam": "select",
        "HiddenParam": "hidden",
    }

    if class_name in container_tags:
        tag = container_tags[class_name]
    elif class_name in type_map:
        param_type = type_map[class_name]

    KNOWN_XML_ATTRIBUTES = [
        "argument",
        "name",
        "label",
        "help",
        "optional",
        "value",
        "format",
        "multiple",
        "checked",
        "min",
        "max",
        "title",
        "from_work_dir",
        "pattern",
        "ext",
        "visible",
        "truevalue",
        "falsevalue",
    ]

    attribs = {}
    if param_type:
        attribs["type"] = param_type

    for attr_name in KNOWN_XML_ATTRIBUTES:
        if hasattr(p_obj, attr_name):
            value = getattr(p_obj, attr_name)
            if value is not None:
                if isinstance(value, bool):
                    attribs[attr_name] = str(value).lower()
                else:
                    attribs[attr_name] = str(value)

    if class_name == "ValidatorParam" and hasattr(p_obj, "type"):
        attribs["type"] = p_obj.type

    elem = ET.Element(tag, attrib=attribs)

    if hasattr(p_obj, "text") and p_obj.text:
        elem.text = p_obj.text

    if hasattr(p_obj, "validators") and p_obj.validators:
        for v in p_obj.validators:
            elem.append(_param_to_element(v))

    if hasattr(p_obj, "options") and isinstance(p_obj.options, dict):
        for opt_value, opt_text in p_obj.options.items():
            opt_elem = ET.SubElement(elem, "option", {"value": str(opt_value)})
            opt_elem.text = opt_text
            if hasattr(p_obj, "value") and str(p_obj.value) == str(opt_value):
                opt_elem.set("selected", "true")

    if hasattr(p_obj, "params") and p_obj.params:
        for child_p in p_obj.params:
            elem.append(_param_to_element(child_p))

    return elem


def _get_xml_string_for_param(param_obj: Any) -> str:
    """Serialisiert ein einzelnes galaxyxml-Parameterobjekt zu einem XML-String."""
    try:
        element = _param_to_element(param_obj)
        ET.indent(element, space="  ")
        xml_string = ET.tostring(element, encoding="unicode").strip()
        return xml_string
    except Exception as e:
        return f"Error serializing XML for object {type(param_obj).__name__}: {e}"


def _param_to_element(p_obj: Any) -> ET.Element:
    """
    Wandelt ein galaxyxml-Parameterobjekt rekursiv in ein ET.Element um,
    indem es die Objektattribute direkt inspiziert und den Tag-Namen ableitet.
    """
    class_name = p_obj.__class__.__name__

    tag = "param"
    param_type = None

    container_tags = {
        "Conditional": "conditional",
        "Repeat": "repeat",
        "When": "when",
        "ValidatorParam": "validator",
        "DiscoverDatasets": "discover_datasets",
    }

    type_map = {
        "TextParam": "text",
        "IntegerParam": "integer",
        "FloatParam": "float",
        "DataParam": "data",
        "BooleanParam": "boolean",
        "SelectParam": "select",
        "HiddenParam": "hidden",
    }

    if class_name in container_tags:
        tag = container_tags[class_name]
    elif class_name in type_map:
        param_type = type_map[class_name]

    KNOWN_XML_ATTRIBUTES = [
        "argument",
        "name",
        "label",
        "help",
        "optional",
        "value",
        "format",
        "multiple",
        "checked",
        "min",
        "max",
        "title",
        "from_work_dir",
        "pattern",
        "ext",
        "visible",
        "truevalue",
        "falsevalue",
    ]

    attribs = {}
    if param_type:
        attribs["type"] = param_type

    for attr_name in KNOWN_XML_ATTRIBUTES:
        if hasattr(p_obj, attr_name):
            value = getattr(p_obj, attr_name)
            if value is not None:
                if isinstance(value, bool):
                    attribs[attr_name] = str(value).lower()
                else:
                    attribs[attr_name] = str(value)

    if class_name == "ValidatorParam" and hasattr(p_obj, "type"):
        attribs["type"] = p_obj.type

    elem = ET.Element(tag, attrib=attribs)

    if hasattr(p_obj, "text") and p_obj.text:
        elem.text = p_obj.text

    if hasattr(p_obj, "validators") and p_obj.validators:
        for v in p_obj.validators:
            elem.append(_param_to_element(v))

    if hasattr(p_obj, "options") and isinstance(p_obj.options, dict):
        for opt_value, opt_text in p_obj.options.items():
            opt_elem = ET.SubElement(elem, "option", {"value": str(opt_value)})
            opt_elem.text = opt_text
            if hasattr(p_obj, "value") and str(p_obj.value) == str(opt_value):
                opt_elem.set("selected", "true")

    if hasattr(p_obj, "params") and p_obj.params:
        for child_p in p_obj.params:
            elem.append(_param_to_element(child_p))

    return elem

def _split_type_string_safely(type_string: str) -> list[str]:
    """
    Zerlegt einen Typ-String bei '|' oder ',', ignoriert aber Trennzeichen
    innerhalb von Klammern (eckig, rund).
    """
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

    # --- ANPASSUNG FÜR OffsetStr/FreqStr VALIDIERUNG ---
    if base_type_str in ['OffsetStr', 'FreqStr']:
        param_object = TextParam(argument=param_name, **creation_args)
        # Diese Regex prüft auf das gängige Format "Zahl + Einheit", z.B. "5D", "-2H", "30min"
        regex = r"^\s*[+-]?\d+(\.\d+)?\s*(D|H|T|min|S|L|ms|U|us|N|ns)\s*$"
        message = "Please enter a valid Pandas Offset/Frequency string (e.g., '30min', '2H', '1D')."
        param_object.append(ValidatorParam(type="regex", message=message, text=regex))
    # --- ENDE DER ANPASSUNG ---
    
    elif base_type_str in ('SaQCFields', 'NewSaQCFields'):
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
    elif base_type_str in ['str', 'string', 'Any']: # 'OffsetStr' und 'FreqStr' entfernt
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
        
        # --- TRACING HINZUGEFÜGT ---
        # Initialisiere den path_trace für jeden Parameter
        path_trace = [f"Param: '{param_name}'"]
        # --- ENDE TRACING ---

        annotation = param.annotation
        param_object = None
        label, help_text = get_label_help(param_name, param_docs)
        
        raw_annotation_str = ""
        if isinstance(annotation, (str, ForwardRef)):
            raw_annotation_str = annotation.__forward_arg__ if isinstance(annotation, ForwardRef) else str(annotation)
        elif annotation is not inspect.Parameter.empty:
            raw_annotation_str = str(annotation).replace("typing.", "")

        path_trace.append(f"Annotation: '{raw_annotation_str}'") # --- TRACING HINZUGEFÜGT ---

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
            path_trace.append("is_simple_type") # --- TRACING HINZUGEFÜGT ---
            single_type_str = type_parts_without_none[0]
            if single_type_str == 'slice':
                start_param_args = {"name": f"{param_name}_start", "label": f"{label} (start index)", "min": 0, "help": "Start index of the slice (e.g., 0).", **optional_arg}
                end_param_args = {"name": f"{param_name}_end", "label": f"{label} (end index)", "min": 0, "help": "End index of the slice (exclusive).", **optional_arg}
                start_param = IntegerParam(**start_param_args)
                end_param = IntegerParam(**end_param_args)
                param_object = [start_param, end_param] # Als Liste speichern für Tracing
            elif any(func_type in single_type_str for func_type in ['Callable', 'CurveFitter', 'GenericFunction']):
                param_object = TextParam(argument=param_name, **param_constructor_args)
                if not is_truly_optional:
                    param_object.append(ValidatorParam(type="empty_field"))
            else:
                param_object = _create_param_from_type_str(single_type_str, param_name, param_constructor_args, is_truly_optional)

        elif len(type_parts_without_none) > 1:
            path_trace.append("is_union_type -> conditional") # --- TRACING HINZUGEFÜGT ---
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
                        info_text = TextParam(name=f"{param_name}_info", type="text", value="This type is not usable in Galaxy.", label="Info", help="This option is for programmatic use and cannot be set from the UI.")
                        when.append(info_text)
                
                conditional.append(when)
            param_object = conditional
        
        # --- TRACING HINZUGEFÜGT ---
        if tracing and param_object:
            # Stelle sicher, dass wir eine Liste haben, auch wenn nur ein Objekt erstellt wurde
            param_objects_to_trace = param_object if isinstance(param_object, list) else [param_object]
            for p_obj in param_objects_to_trace:
                trace_info = {
                    "module": module.__name__,
                    "param_name": param_name,
                    "annotation": raw_annotation_str,
                    "xml": _get_xml_string_for_param(p_obj),
                    "path": " -> ".join(path_trace),
                }
                TRACING_DATA.append(trace_info)
        # --- ENDE TRACING ---

        if param_object:
            # Stelle sicher, dass wir einzelne Objekte hinzufügen, falls 'slice' eine Liste zurückgab
            if isinstance(param_object, list):
                xml_params.extend(param_object)
            else:
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


REPEAT_FIELD_FUNCS = [
    "flagDriftFromNorm",
    "flagDriftFromReference",
    "flagLOF",
    "flagMVScores",
    "flagZScore",
    "assignKNNScore",
    "assignLOF",
    "assignUniLOF",
]


def get_param_info(method: Callable) -> Dict[str, Any]:
    """
    Inspiziert eine Funktion und gibt detaillierte Typinformationen für die Testgenerierung zurück.
    Angepasst an das neue Skript, ignoriert es nun auch Parameter mit 'kwarg' im Namen.
    """
    param_info = {}
    try:
        parameters = inspect.signature(method).parameters
    except (ValueError, TypeError):
        return {}

    for name, param in parameters.items():
        if name in ["self", "kwargs"] or "kwarg" in name.lower():
            continue
        
        annotation = param.annotation

        if isinstance(annotation, (str, ForwardRef)):
            try:
                eval_context = {**globals(), **saqc.__dict__, **saqc.lib.types.__dict__, **saqc.funcs.__dict__, **SAQC_CUSTOM_SELECT_TYPES, 
                                "pd": pd, "np": np, "mpl": mpl, "Union": Union, "Literal": Literal, 
                                "Sequence": Sequence, "Callable": Callable, "Any": Any, "Tuple": Tuple, "Dict": Dict}
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
            "annotation": annotation,
            "origin": origin,
            "args": args,
            "default": param.default if param.default is not param.empty else inspect.Parameter.empty,
        }
    return param_info


def _structure_galaxy_params(params_for_variant: dict, param_info: dict, method: Callable) -> dict:
    """
    Wandelt ein flaches Parameter-Dictionary in die korrekte logische, verschachtelte Struktur um,
    die die Conditional- und Repeat-Logik der Galaxy-UI widerspiegelt.
    """
    galaxy_params = {}
    for name, value in params_for_variant.items():
        info = param_info.get(name, {})
        origin = info.get("origin")
        args = info.get("args", [])
        annotation = info.get("annotation")

        is_union = origin is Union

        if is_union and len(args) > 1:
            # Replicate the logic from get_method_params to find the correct type choice
            raw_ann_str = str(info['annotation']).replace("typing.","")
            type_parts = [p for p in _split_type_string_safely(raw_ann_str[6:-1]) if p != 'None']
            
            value_type_str = _get_user_friendly_type_name(_get_type_str_for_value(value))
            selector_idx = -1
            
            # Find which "when" case this value corresponds to
            for i, part in enumerate(type_parts):
                friendly_part_name = _get_user_friendly_type_name(part)
                if value_type_str.lower() == friendly_part_name.lower():
                    selector_idx = i
                    break
            
            # Fallback for complex types
            if selector_idx == -1:
                simple_value_type = _get_type_str_for_value(value)
                for i, part in enumerate(type_parts):
                    if simple_value_type in part.lower():
                        selector_idx = i
                        break

            if selector_idx != -1:
                galaxy_params[f"{name}_cond"] = {
                    f"{name}_selector": f"type_{selector_idx}",
                    name: value
                }
            else:
                galaxy_params[name] = value # Fallback if no match is found
        elif name in ["field", "target"] and (origin in (list, Sequence) or annotation in (list[str], Sequence[str])):
            val_list = [value] if not isinstance(value, list) else value
            galaxy_params[f"{name}_repeat"] = [{name: v} for v in val_list]
        else:
            galaxy_params[name] = value
            
    return galaxy_params


def build_param_xml(parent: ET.Element, name: str, value: Any):
    """
    Recursively builds the XML <param> structure for Galaxy tests,
    now correctly handling nested conditionals.
    """
    name_str = str(name)

    # Handle repeats
    if name_str.endswith("_repeat") and isinstance(value, list):
        repeat = ET.SubElement(parent, "repeat", {"name": name_str})
        for item_dict in value:
            # For each item in the list, which is a dict of its own...
            if isinstance(item_dict, dict):
                for sub_name, sub_value in item_dict.items():
                    # The repeat item itself is not a param, but a container for them
                    # So we build the params inside the repeat directly
                    build_param_xml(repeat, sub_name, sub_value)
    # Handle conditionals
    elif name_str.endswith("_cond") and isinstance(value, dict):
        conditional = ET.SubElement(parent, "conditional", {"name": name_str})
        for sub_name, sub_value in value.items():
            # Recursively build params inside the conditional
            build_param_xml(conditional, sub_name, sub_value)
    # Handle simple params
    else:
        val_str = ""
        if isinstance(value, bool):
            val_str = str(value).lower()
        elif isinstance(value, list):
            # For params with multiple=true, Galaxy expects a comma-separated string
            val_str = ",".join(map(str, value))
        elif value is not None:
            val_str = str(value)
            
        ET.SubElement(parent, "param", {"name": name_str, "value": val_str})


def _get_type_str_for_value(value: Any) -> str:
    """Helper to get a representative type string for a given value."""
    if isinstance(value, bool):
        return 'bool'
    if isinstance(value, int):
        return 'int'
    if isinstance(value, float):
        return 'float'
    if isinstance(value, pd.Timedelta) or (isinstance(value, str) and re.match(r"^\s*-?\d+(\.\d+)?\s*(D|H|T|S|L|U|N|days?|hours?|minutes?|seconds?|weeks?|milliseconds?|microseconds?|nanoseconds?)\s*$", value)):
        return 'Offsetlike' # Match a broad category for timedelta-like things
    if isinstance(value, str):
        return 'str'
    return 'Any'


def generate_test_variants(method: Callable) -> list:
    """
    Erzeugt Testvarianten und strukturiert sie in eine verschachtelte Dictionary-Form,
    die von `build_test_xml_recursively` verarbeitet werden kann.
    """
    param_info = get_param_info(method)
    if not param_info:
        return []

    variants, base_params, complex_params_to_vary = [], {}, set()

    for name, info in param_info.items():
        default = info["default"]
        annotation = info["annotation"]
        origin = get_origin(annotation)
        args = get_args(annotation)
        
        is_union = origin is Union or (is_union_type(annotation) and origin is not Literal)

        if (is_union and len(args) > 1 and not any(is_callable_type(a) for a in args)) or \
           (origin is Literal and len(args) > 1):
            complex_params_to_vary.add(name)

        if default is not inspect.Parameter.empty and default is not None and default != "":
            if annotation is bool:
                base_params[name] = not default
            else:
                base_params[name] = default
        else:
            assigned = False
            possible_types = args if is_union else [annotation]
            
            if name in ["field", "target"]:
                base_params[name] = "test_variable"
                assigned = True
            elif origin is Literal and args:
                base_params[name] = args[0]
                assigned = True

            if not assigned:
                type_options = [t for t in possible_types if t is not type(None)]
                if type_options:
                    first_type = type_options[0]
                    if first_type in [int, 'int']: base_params[name] = 1
                    elif first_type in [float, 'float']: base_params[name] = 1.0
                    elif first_type in [bool, 'bool']: base_params[name] = True
                    elif pd and hasattr(pd, "Timedelta") and first_type == pd.Timedelta: base_params[name] = "1D"
                    elif get_origin(first_type) is Literal and get_args(first_type): base_params[name] = get_args(first_type)[0]
                    else: base_params[name] = "default_string"
                else:
                    base_params[name] = "default_string"

    variants.append({"description": f"Test mit Defaults für {method.__name__}", "params": base_params})

    for name in complex_params_to_vary:
        info = param_info[name]
        options_to_test = []
        if info["origin"] is Literal:
            options_to_test = list(info["args"])
        elif info["origin"] is Union:
            for arg_type in info["args"]:
                if arg_type is type(None): continue
                if arg_type is int: options_to_test.append(123)
                elif arg_type is float: options_to_test.append(45.6)
                elif arg_type is str: options_to_test.append("a_string_variant")
                elif pd and hasattr(pd, "Timedelta") and arg_type == pd.Timedelta: options_to_test.append("2H")

        for option in options_to_test:
            if option is None: continue
            variant_params = base_params.copy()
            variant_params[name] = option
            variants.append({"description": f"Test-Variante für '{name}' mit Wert '{str(option)}'", "params": variant_params})

    final_variants = []
    for variant in variants:
        galaxy_params = _structure_galaxy_params(variant["params"], param_info, method)
        final_variants.append({
            "description": variant["description"],
            "galaxy_params": galaxy_params,
            "saqc_call_params": variant["params"],
        })
    return final_variants


def build_test_xml_recursively(parent_element: ET.Element, params_dict: dict):
    """
    Baut rekursiv die korrekte, verschachtelte Test-XML-Struktur auf,
    basierend auf einem verschachtelten Parameter-Dictionary.
    """
    for name, value in params_dict.items():
        if name.endswith("_cond") and isinstance(value, dict):
            cond_elem = ET.SubElement(parent_element, "conditional", {"name": name})
            build_test_xml_recursively(cond_elem, value)
        elif name.endswith("_repeat") and isinstance(value, list):
            repeat_elem = ET.SubElement(parent_element, "repeat", {"name": name})
            for item_dict in value:
                build_test_xml_recursively(repeat_elem, item_dict)
        else:
            val_str = str(value).lower() if isinstance(value, bool) else str(value) if value is not None else ""
            ET.SubElement(parent_element, "param", {"name": name, "value": val_str})


def format_value_for_regex(value: Any, param_name: str) -> str:
    """Formats a Python value into a regex string for assertion."""
    empty_is_none_params = [
        "reduce_window",
        "tolerance",
        "maxna",
        "maxna_group",
        "sub_window",
        "sub_thresh",
        "min_periods",
        "min_residuals",
        "min_offset",
        "stray_range",
        "path",
        "ax",
        "marker_kwargs",
        "plot_kwargs",
        "freq",
        "group",
        "xscope",
        "yscope",
    ]
    if param_name in empty_is_none_params and (value is None or value == ""):
        return '(None|"")'

    if value is None:
        return "None"
    if isinstance(value, bool):
        return f"({str(value)}|None)"
    if isinstance(value, str) and value.startswith("<function"):
        sanitized_val = value.replace("<", "__lt__").replace(">", "__gt__")
        return re.escape(sanitized_val)

    if isinstance(value, int):
        escaped_val = re.escape(str(value))
        return f"(?:[\"']?{escaped_val}[\"']?)"

    if isinstance(value, float):
        if math.isinf(value):
            return r"float\(['\"]-?inf['\"]\)"
        if math.isnan(value):
            return r"float\(['\"]nan['\"]\)"
        return re.escape(str(value))

    if isinstance(value, str):
        return f"[\"']{re.escape(str(value))}[\"']"

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
                
                repeat_elem = ET.SubElement(test_elem, "repeat", {"name": "methods_repeat"})
                module_cond_elem = ET.SubElement(repeat_elem, "conditional", {"name": "module_cond"})
                ET.SubElement(module_cond_elem, "param", {"name": "module_select", "value": module_name})

                method_params = {"method_select": method_name}
                method_params.update(variant["galaxy_params"])
                galaxy_params_for_method = {"method_cond": method_params}
                
                build_test_xml_recursively(module_cond_elem, galaxy_params_for_method)

                output_elem = ET.SubElement(test_elem, "output", {"name": "config_out", "ftype": "txt"})
                assert_contents = ET.SubElement(output_elem, "assert_contents")
                params_to_check = variant["saqc_call_params"]

                field_val = params_to_check.get("field", params_to_check.get("target"))
                field_name = field_val if not isinstance(field_val, list) else (field_val[0] if field_val else "test_variable")
                field_regex_part = re.escape(str(field_name))
                lookaheads = []

                if variant["description"].startswith("Test mit Defaults"):
                    full_regex = f"{field_regex_part};\\s*{method_name}\\(.*\\)$"
                else:
                    match = re.search(r"Test-Variante für '([^']+)'.*", variant["description"])
                    if match:
                        varied_param_name = match.group(1)
                        if varied_param_name in params_to_check:
                            p_value = params_to_check[varied_param_name]
                            if varied_param_name not in ["field", "target"]:
                                formatted_value = format_value_for_regex(p_value, varied_param_name)
                                lookaheads.append(f"(?=.*{varied_param_name}\\s*=\\s*{formatted_value})")
                    
                    if not lookaheads:
                        full_regex = f"{field_regex_part};\\s*{method_name}\\(.*\\)$"
                    else:
                        full_regex = f"{field_regex_part};\\s*{method_name}\\({''.join(lookaheads)}.*\\)$"

                ET.SubElement(assert_contents, "has_text_matching", {"expression": full_regex})

    try:
        ET.indent(macros_root, space="  ")
        sys.stdout.buffer.write(b'<?xml version="1.0" encoding="utf-8"?>\n')
        sys.stdout.buffer.write(ET.tostring(macros_root, encoding="utf-8", xml_declaration=False))
        print("\nSuccessfully generated test macro XML.", file=sys.stderr)
    except Exception as e:
        print(f"\nXML Serialization failed. Error: {e}", file=sys.stderr)


def generate_tool_xml(tracing=False):
    """Generiert und druckt die XML-Definition des Galaxy-Tools."""

    # --- Tool Definition ---
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

    # --- TRACING HINZUGEFÜGT ---
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
