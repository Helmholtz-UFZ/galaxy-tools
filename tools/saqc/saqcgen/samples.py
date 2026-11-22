"""Example values for the generated tests.

A test for a SaQC method sets every parameter of that method to a value that
SaQC accepts, so the generated configuration can be executed.  The values are
derived from the :class:`~saqcgen.typespec.TypeSpec` of a parameter, i.e. from
the same information the input widgets are built from.
"""

from __future__ import annotations

from typing import Any, Dict, List, Union

from . import typespec
from .typespec import TypeSpec

__all__ = ["sample_values"]

#: value used for a string parameter of a nested structure (tuple, mapping)
NESTED_TEXT = "test_string"

#: value used for a string parameter
TEXT = "a_string"

#: value used for inputs of a time span
OFFSET = "1D"
TIMEDELTA = "1d"


def sample_values(spec: TypeSpec, name: str) -> Union[Dict[str, Any], List[Any], Any]:
    """Galaxy test parameters for the input of ``spec``.

    A returned ``dict`` is merged into the surrounding parameters (the input is
    a set of sibling fields), a returned ``list`` describes a ``repeat`` block
    and anything else is the value of the input named ``name``.
    """
    if spec.kind == typespec.FIELDS:
        return 1
    if spec.kind == typespec.FILES:
        return "test1/data.csv"
    if spec.kind == typespec.TUPLE:
        elements = spec.inner[:2] or (TypeSpec(typespec.TEXT, "str"),) * 2
        return [
            {
                _positioned(name, index): _element_value(inner)
                for index, inner in enumerate(elements)
            }
        ]
    if spec.kind == typespec.RANGES:
        return [{f"{name}_min": 0.0, f"{name}_max": 0.0}]
    if spec.kind == typespec.MAPPING:
        return [{"key": "test_key", "value": "test_value"}]
    if spec.kind == typespec.SELECT:
        return spec.options[0] if spec.options else TEXT
    if spec.kind == typespec.BOOLEAN:
        return True
    if spec.kind in (typespec.INTEGER, typespec.FLOAT):
        return 1
    if spec.kind == typespec.OUTPUT_PATH:
        return TEXT
    return _text_value(spec)


def _text_value(spec: TypeSpec) -> str:
    if spec.validator == typespec.TIMEDELTA:
        return TIMEDELTA
    if spec.validator in (typespec.OFFSET, typespec.OFFSET_OR_TIMEDELTA):
        return OFFSET
    return TEXT


def _element_value(spec: TypeSpec) -> Any:
    """Value for one element of a tuple."""
    if spec.kind == typespec.FLOAT:
        return 1.0
    if spec.kind == typespec.INTEGER:
        return 1
    if spec.kind == typespec.BOOLEAN:
        return True
    if spec.kind == typespec.SELECT:
        return spec.options[0] if spec.options else NESTED_TEXT
    if spec.validator == typespec.TIMEDELTA:
        return TIMEDELTA
    if spec.validator in (typespec.OFFSET, typespec.OFFSET_OR_TIMEDELTA):
        return OFFSET
    if spec.kind == typespec.FIELDS:
        return 1
    return NESTED_TEXT


def _positioned(name: str, index: int) -> str:
    return f"{name}_pos{index}"
