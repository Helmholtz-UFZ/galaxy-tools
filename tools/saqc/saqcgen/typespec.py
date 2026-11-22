"""Translation of SaQC type annotations into UI independent type specifications.

SaQC annotates its method parameters with type hints (which are plain strings,
because the SaQC modules use ``from __future__ import annotations``).  A type
hint can be a union of several types and each member is rendered as its own
input widget in Galaxy.

``parse_annotation`` turns one member of a type hint into a :class:`TypeSpec`.
A spec is a small, immutable description of "what the user has to provide", for
example "a float", "a selection of these three strings" or "a tuple of two
floats".  Everything that needs to know how a value looks (the Galaxy widget,
the example value in the generated tests, the human readable name) is derived
from the spec, so the knowledge about a SaQC type lives in exactly one place.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Any, Mapping, Optional, Sequence, Tuple

__all__ = [
    "BOOLEAN",
    "FIELDS",
    "FILES",
    "FILENAME",
    "FLOAT",
    "INTEGER",
    "MAPPING",
    "OFFSET",
    "OFFSET_OR_TIMEDELTA",
    "OUTPUT_PATH",
    "RANGES",
    "SELECT",
    "TEXT",
    "TIMEDELTA",
    "TUPLE",
    "TypeSpec",
    "friendly_name",
    "parse_annotation",
    "split_union",
]

# --------------------------------------------------------------------------
# kinds of input widgets a SaQC type is mapped to
# --------------------------------------------------------------------------
FIELDS = "fields"
FILES = "files"
TEXT = "text"
INTEGER = "integer"
FLOAT = "float"
BOOLEAN = "boolean"
SELECT = "select"
TUPLE = "tuple"
RANGES = "ranges"
MAPPING = "mapping"
OUTPUT_PATH = "output_path"

# --------------------------------------------------------------------------
# additional validators for text parameters
# --------------------------------------------------------------------------
OFFSET = "offset"
TIMEDELTA = "timedelta"
OFFSET_OR_TIMEDELTA = "offset_or_timedelta"
FILENAME = "filename"

#: type strings that are rendered as plain text inputs
_TEXT_TYPES = {
    "list",
    "sequence",
    "arraylike",
    "pd.series",
    "pd.dataframe",
    "pd.datetimeindex",
    "str",
    "string",
    "any",
}

#: text types that are presented as a plain string
_PLAIN_TEXT_TYPES = {"str", "string", "any"}

#: text types that need a validator restricting the accepted input
_TEXT_VALIDATORS = {
    "pd.timedelta": TIMEDELTA,
    "offsetstr": OFFSET,
    "freqstr": OFFSET,
}

#: values of a tuple type are described by their index, not by their name
_TUPLE_ELEMENT_LABELS = ("pos0", "pos1")

_FLOAT_TUPLE = re.compile(r"tuple\[\s*float\s*,\s*float\s*\]", re.IGNORECASE)
_FLOAT_TUPLE_LIST = re.compile(
    r"list\[\s*tuple\[\s*float\s*,\s*float\s*\]\s*\]", re.IGNORECASE
)
_TUPLE = re.compile(r"tuple(?:\[\s*(?P<inner>.*)\s*\])?", re.IGNORECASE)
_STRING_LIST = re.compile(r"(?:list|Sequence)\[\s*str\s*\]", re.IGNORECASE)
_LITERAL = re.compile(r"Literal\[(?P<options>.*)\]", re.IGNORECASE)
_NUMERIC_RANGE = re.compile(
    r"(?P<type>Float|Int)\[\s*(?P<min>[0-9.-]+)\s*,\s*(?P<max>[0-9.-]+)\s*\]",
    re.IGNORECASE,
)
_NUMERIC_LOWER_BOUND = re.compile(
    r"\(?\s*(?P<type>Int|Float)\s*>=?\s*(?P<min>\d+(?:\.\d+)?)\s*\)?"
)
_GENERIC_LIST = re.compile(r"^(?:list|sequence|array(?:like)?)(?:\[(?P<inner>.*)\])?$", re.I)

#: pluralisation exceptions for the "list of ..." type names
_NO_PLURAL = {"Integer", "Float", "String", "Boolean", "pd.Timedelta"}


@dataclass(frozen=True)
class TypeSpec:
    """Everything the generators need to know about one accepted input type."""

    kind: str
    #: the type hint as written in the SaQC source, e.g. ``list[tuple[float, float]]``
    text: str
    #: element specs of a ``tuple``
    inner: Tuple["TypeSpec", ...] = ()
    #: allowed values of a ``select``
    options: Tuple[str, ...] = ()
    #: (value, label) pairs of a ``select``, taken from the parameter docs
    option_labels: Tuple[Tuple[str, str], ...] = ()
    minimum: Optional[str] = None
    maximum: Optional[str] = None
    #: True if several values of this type are accepted (a list)
    multiple: bool = False
    validator: Optional[str] = None


def split_union(type_string: str) -> list[str]:
    """Split a type hint into its union members.

    Handles both ``Union[a, b]`` and ``a | b`` notation.  Bracketed parts are
    kept together, so ``list[int | str]`` stays a single member.
    """
    text = type_string.strip()
    if text.startswith("Union[") and text.endswith("]"):
        text = text[len("Union[") : -1]

    members: list[str] = []
    current = ""
    depth = 0
    for char in text:
        if char in "[(":
            depth += 1
        elif char in "])":
            depth -= 1
        if char in "|," and depth == 0:
            if current.strip():
                members.append(current.strip())
            current = ""
        else:
            current += char
    if current.strip():
        members.append(current.strip())
    return members


def parse_annotation(
    type_string: str, literals: Optional[Mapping[str, Any]] = None
) -> Optional[TypeSpec]:
    """Translate one (union free) SaQC type hint into a :class:`TypeSpec`.

    Returns ``None`` for types that cannot be represented by a Galaxy input
    field (those parameters are skipped by the generator).
    """
    text = type_string.strip()
    literals = literals or {}

    # a module level alias of a Literal, e.g. ``FILL_METHODS``
    if text in literals:
        return parse_annotation(str(literals[text]).replace("typing.", ""), literals)

    if text in ("SaQCFields", "NewSaQCFields"):
        return TypeSpec(FIELDS, text, multiple=True)

    if _STRING_LIST.fullmatch(text):
        return TypeSpec(TEXT, text, multiple=True)

    if _FLOAT_TUPLE_LIST.fullmatch(text):
        inner = (
            TypeSpec(FLOAT, "float"),
            TypeSpec(FLOAT, "float"),
        )
        return TypeSpec(RANGES, text, inner=inner)

    tuple_match = _TUPLE.fullmatch(text)
    if tuple_match:
        inner_string = (tuple_match.group("inner") or "").replace("...", "").strip()
        if not inner_string:
            # a bare ``tuple`` is filled with two free text elements
            return TypeSpec(TUPLE, text)
        members = [m for m in split_union(inner_string) if m]
        specs = [parse_annotation(m, literals) for m in members]
        specs = [spec for spec in specs if spec is not None]
        if not specs:
            specs = [TypeSpec(TEXT, "str")]
        while len(specs) < 2:
            specs.append(specs[0])
        return TypeSpec(TUPLE, text, inner=tuple(specs[:2]))

    lowered = text.lower()
    if lowered in _TEXT_TYPES:
        return TypeSpec(TEXT, text)

    if lowered in _TEXT_VALIDATORS:
        return TypeSpec(TEXT, text, validator=_TEXT_VALIDATORS[lowered])

    if "offsetlike" in lowered:
        return TypeSpec(TEXT, text, validator=OFFSET_OR_TIMEDELTA)

    if lowered.startswith("dict"):
        return TypeSpec(MAPPING, text)

    literal_match = _LITERAL.fullmatch(text)
    if literal_match:
        options = tuple(
            option.strip().strip("'\"")
            for option in split_union(literal_match.group("options"))
        )
        if not options:
            return None
        return TypeSpec(SELECT, text, options=options)

    range_match = _NUMERIC_RANGE.fullmatch(text)
    if range_match:
        kind = FLOAT if range_match.group("type").lower() == "float" else INTEGER
        return TypeSpec(
            kind, text, minimum=range_match.group("min"), maximum=range_match.group("max")
        )

    lower_bound_match = _NUMERIC_LOWER_BOUND.search(text)
    if lower_bound_match:
        kind = FLOAT if lower_bound_match.group("type").lower() == "float" else INTEGER
        return TypeSpec(kind, text, minimum=lower_bound_match.group("min"))

    if lowered == "int":
        return TypeSpec(INTEGER, text)
    if lowered == "float":
        return TypeSpec(FLOAT, text)
    if lowered == "bool":
        return TypeSpec(BOOLEAN, text)
    if text == "OutputPath":
        # hardcoded path parameter of ``saqc.funcs.tools.plot``
        # https://git.ufz.de/rdm-software/saqc/-/issues/511
        return TypeSpec(OUTPUT_PATH, text, validator=FILENAME)

    return None


def friendly_name(spec: TypeSpec) -> str:
    """Human readable name of a type, used in the "choose the type" dropdown."""
    if spec.kind == FIELDS:
        return "Column Selection"
    if spec.kind == SELECT:
        return "Selection"
    if spec.kind == INTEGER:
        return "Integer"
    if spec.kind == FLOAT:
        return "Float"
    if spec.kind == BOOLEAN:
        return "Boolean"
    if spec.kind == MAPPING:
        return "Dictionary"
    if spec.kind == FILES:
        return "Input Table(s)"
    if spec.kind == RANGES:
        return "List of Tuples (Float, Float)"
    if spec.kind == TUPLE:
        return _tuple_name(spec)
    if spec.validator == TIMEDELTA:
        return "pd.Timedelta"
    if spec.validator == OFFSET_OR_TIMEDELTA:
        return "Time Object (Offset/Timedelta)"
    if spec.validator == OFFSET:
        return "OffsetStr (Pandas Frequency)"
    if spec.kind == OUTPUT_PATH:
        return "OutputPath"
    return _text_name(spec)


def _tuple_name(spec: TypeSpec) -> str:
    if spec.inner and all(inner.kind == FLOAT for inner in spec.inner[:2]):
        return "Tuple (Float, Float)"
    if spec.inner:
        names = ", ".join(friendly_name(inner) for inner in spec.inner)
        return f"Tuple ({names})"
    return "Tuple"


def _text_name(spec: TypeSpec) -> str:
    list_match = _GENERIC_LIST.match(spec.text.strip())
    if list_match is None:
        # a plain string is called "String", anything else keeps the name of
        # the type hint (e.g. "pd.DatetimeIndex", which is parsed as text)
        return (
            "String" if spec.text.strip().lower() in _PLAIN_TEXT_TYPES
            else spec.text.strip()
        )
    inner = list_match.group("inner")
    if not inner:
        return "List"
    inner_name = friendly_name(parse_annotation(inner) or TypeSpec(TEXT, inner))
    if not inner_name.endswith("s") and inner_name not in _NO_PLURAL:
        return f"List of {inner_name}s"
    return f"List of {inner_name}"
