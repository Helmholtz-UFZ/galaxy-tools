"""Galaxy input widgets for the SaQC parameters.

The mapping from a :class:`~saqcgen.typespec.TypeSpec` to a Galaxy XML input is
a plain dispatch table, so adding support for a new SaQC type means adding one
function and one entry in :data:`_BUILDERS`.
"""

from __future__ import annotations

from typing import Callable, Dict, Optional

from galaxyxml.tool.parameters import (
    BooleanParam,
    Conditional,
    DataParam,
    FloatParam,
    IntegerParam,
    Repeat,
    SelectParam,
    TextParam,
    ValidatorParam,
    When,
)

from . import typespec
from .introspect import ParamPlan
from .typespec import TypeSpec

__all__ = ["build", "select_widget"]

#: description of the "choose the input format" selector
TYPE_SELECTOR_HELP = (
    "The parameter supports different input formats, you can choose which one "
    "suites your application."
)

#: appended to the help text of text parameters with a format restriction
_TEXT_HELP = {
    typespec.TIMEDELTA: (
        " Format: Fixed time duration (no calendar logic). "
        "Examples: '1d', '2.5h', '30min'. (No 'M' or 'Y')."
    ),
    typespec.OFFSET_OR_TIMEDELTA: (
        " Format: Time object. Accepts Pandas Frequencies (e.g. '1M', 'W-MON') "
        "OR Timedeltas (e.g. '3 days', '1.5h')."
    ),
    typespec.OFFSET: (
        " Format: Calendar frequency/offset. "
        "Examples: '1D', '1M' (Month), 'W-MON' (Weekly Mon)."
    ),
}

#: patterns accepted by the text parameters that describe a time span
_OFFSET_PATTERN = r"\s*(\d+(\.\d+)?)?\s*[A-Za-z]+(?:-[A-Za-z]{3})?\s*"
_TIMEDELTA_PATTERN = (
    r"-?(\d+(\.\d*)?|\.\d+)\s*"
    r"(W|D|days?|d|H|hours?|hr|h|T|minutes?|min|m|S|seconds?|sec|s"
    r"|L|milliseconds?|ms|U|microseconds?|us|N|nanoseconds?|ns)\s*"
)

#: SaQC writes plots to a path, which must be a plain file name
_PATH_PATTERN = r"[\w -\.]+"

_VALIDATORS = {
    typespec.TIMEDELTA: (
        f"(^$)|(^{_TIMEDELTA_PATTERN}$)",
        "Must be a valid Pandas Timedelta string (e.g., '1d', '2.5h', '30min'). "
        "Month (M) or Year (Y) are NOT allowed.",
    ),
    typespec.OFFSET_OR_TIMEDELTA: (
        f"(^$)|({_OFFSET_PATTERN})|(^{_TIMEDELTA_PATTERN}$)",
        "Accepts both Pandas Frequencies (e.g. '1M', 'W-SAT') AND Timedeltas "
        "(e.g. '3 days', '1.5h').",
    ),
    typespec.OFFSET: (
        f"(^$)|({_OFFSET_PATTERN})",
        "Must be a valid Pandas offset/frequency string "
        "(e.g., '1D', '1M', 'min', 'W-MON').",
    ),
}


def build(plan: ParamPlan) -> object:
    """Build the Galaxy input(s) for one SaQC method parameter."""
    if plan.from_default:
        return _from_default_value(plan)

    args: Dict[str, object] = {
        "name": plan.input_name,
        "argument": plan.name,
        "label": plan.label,
        "help": plan.help,
    }
    if plan.optional:
        args["optional"] = True
    if plan.default is not None:
        args["value"] = plan.default

    if plan.has_type_selection:
        # the default value belongs to one specific input format, so the
        # inputs of a type selection are always empty
        args.pop("value", None)
        return _type_selection(plan, args)
    return _widget(
        plan.specs[0], plan.input_name, args, plan.optional, plan.default_value
    )


def select_widget(name: str, label: str, options: Dict[str, str]) -> SelectParam:
    """A dropdown input (also used for the module and method selection)."""
    widget = SelectParam(name=name, label=label, options=options)
    if options:
        widget.value = next(iter(options))
    return widget


# --------------------------------------------------------------------------
# widget builders per type
# --------------------------------------------------------------------------
def _widget(
    spec: TypeSpec,
    name: str,
    args: Dict[str, object],
    optional: bool,
    default: object = None,
) -> object:
    builder = _BUILDERS.get(spec.kind)
    if builder is None:  # pragma: no cover - guarded by parse_annotation
        raise ValueError(f"no widget for type '{spec.text}'")
    if spec.kind == typespec.BOOLEAN:
        # the default of a flag decides whether the checkbox is ticked
        args = dict(args)
        args.pop("value", None)
        args["checked"] = bool(default)
    return builder(spec, name, args, optional)


def _type_selection(plan: ParamPlan, args: Dict[str, object]) -> Conditional:
    """A selector plus one ``when`` block per accepted input format."""
    conditional = Conditional(name=f"{plan.input_name}_cond")
    conditional.append(
        SelectParam(
            name=f"{plan.input_name}_selector",
            label=f"Choose type for '{plan.label}'",
            help=TYPE_SELECTOR_HELP,
            options={
                f"type_{index}": typespec.friendly_name(spec)
                for index, spec in enumerate(plan.specs)
            },
        )
    )
    for index, spec in enumerate(plan.specs):
        when = When(value=f"type_{index}")
        when.append(
            _widget(
                spec, plan.input_name, dict(args), plan.optional, plan.default_value
            )
        )
        conditional.append(when)
    return conditional


def _arguments(name: str, args: Dict[str, object]) -> Dict[str, object]:
    """The keyword arguments of a single input.

    ``name`` is the name of the Galaxy input, the SaQC argument is stored in
    ``args``.  A parameter whose names agree is written as ``argument`` only,
    Galaxy derives the name of such an input from its argument.
    """
    args = dict(args)
    argument = args.pop("argument", None) or name
    args.pop("name", None)
    if argument != name:
        args["name"] = name
    args["argument"] = argument
    return args


def _text(spec: TypeSpec, name: str, args: Dict[str, object], optional: bool):
    args = dict(args)
    # a text input cannot be marked optional, an empty value is validated instead
    args.pop("optional", None)
    if spec.validator in _TEXT_HELP:
        args["help"] = (str(args.get("help", "")) + _TEXT_HELP[spec.validator]).strip()

    if spec.multiple:
        return TextParam(multiple=True, **_arguments(name, args))

    param = TextParam(**_arguments(name, args))
    if spec.validator in _VALIDATORS:
        pattern, message = _VALIDATORS[spec.validator]
        param.append(_regex_validator(pattern, message))
    if not optional:
        param.append(_empty_field_validator())
    return param


def _integer(spec: TypeSpec, name: str, args: Dict[str, object], optional: bool):
    return _number(IntegerParam, spec, name, args)


def _float(spec: TypeSpec, name: str, args: Dict[str, object], optional: bool):
    return _number(FloatParam, spec, name, args)


def _number(constructor, spec: TypeSpec, name: str, args: Dict[str, object]):
    args = dict(args)
    if spec.minimum is not None:
        args["min"] = spec.minimum
    if spec.maximum is not None:
        args["max"] = spec.maximum
    return constructor(**_arguments(name, args))


def _boolean(spec: TypeSpec, name: str, args: Dict[str, object], optional: bool):
    args = dict(args)
    args.pop("value", None)
    args.pop("multiple", None)
    args.pop("optional", None)
    checked = bool(args.pop("checked", False))
    param = BooleanParam(checked=checked, **_arguments(name, args))
    _drop_attribute(param, "truevalue")
    _drop_attribute(param, "falsevalue")
    return param


def _select(spec: TypeSpec, name: str, args: Dict[str, object], optional: bool):
    args = dict(args)
    default = args.pop("value", None)
    if default is not None:
        args["default"] = default
    options = dict(spec.option_labels) or {option: option for option in spec.options}
    return SelectParam(options=options, **_arguments(name, args))


def _fields(spec: TypeSpec, name: str, args: Dict[str, object], optional: bool):
    args = dict(args)
    args.pop("value", None)
    args.update(type="data_column", data_ref="data", multiple=spec.multiple)
    return SelectParam(**_arguments(name, args))


def _files(spec: TypeSpec, name: str, args: Dict[str, object], optional: bool):
    args = dict(args)
    args.pop("value", None)
    # a dataset input has no command line argument of its own
    args.pop("argument", None)
    args.pop("name", None)
    return DataParam(name=name, format="csv", multiple=True, **args)


def _ranges(spec: TypeSpec, name: str, args: Dict[str, object], optional: bool):
    """A repeated pair of lower and upper bound."""
    repeat = Repeat(
        name=name, title=str(args.get("label", name)), help=str(args.get("help", ""))
    )
    repeat.append(FloatParam(name=f"{name}_min", label=f"{name}_min"))
    repeat.append(FloatParam(name=f"{name}_max", label=f"{name}_max"))
    return repeat


def _mapping(spec: TypeSpec, name: str, args: Dict[str, object], optional: bool):
    """A repeated key/value pair."""
    repeat = Repeat(
        name=name, title=str(args.get("label", name)), help=str(args.get("help", ""))
    )
    key = TextParam(name="key", label="Key", help="Name of the dictionary key.")
    key.append(_empty_field_validator())
    value = TextParam(
        name="value", label="Value", help="Value for the key (e.g., 'min,max')."
    )
    value.append(_empty_field_validator())
    repeat.append(key)
    repeat.append(value)
    return repeat


def _tuple(spec: TypeSpec, name: str, args: Dict[str, object], optional: bool):
    """A repeated tuple, with one input per element."""
    repeat = Repeat(
        name=name, title=str(args.get("label", name)), help=str(args.get("help", ""))
    )
    elements = spec.inner[:2] or (TypeSpec(typespec.TEXT, "str"),) * 2
    for index, inner in enumerate(elements):
        element_name = f"{name}_pos{index}"
        element_args: Dict[str, object] = {
            "name": element_name,
            "label": element_name,
            "help": f"{_ORDINALS[index]} element (index {index}) of the {name} tuple.",
        }
        if optional:
            element_args["optional"] = True
        repeat.append(_widget(inner, element_name, element_args, optional))
    return repeat


def _output_path(spec: TypeSpec, name: str, args: Dict[str, object], optional: bool):
    args = dict(args)
    args.pop("optional", None)
    param = TextParam(**_arguments(name, args))
    param.append(ValidatorParam(type="regex", text=_PATH_PATTERN))
    param.append(_empty_field_validator())
    return param


def _from_default_value(plan: ParamPlan):
    """Input for an unannotated parameter, derived from its default value."""
    value = plan.default_value
    args: Dict[str, object] = {
        "name": plan.input_name,
        "argument": plan.name,
        "label": plan.label,
        "help": plan.help,
    }

    if isinstance(value, bool):
        param = BooleanParam(checked=value, **_arguments(plan.input_name, args))
        _drop_attribute(param, "truevalue")
        _drop_attribute(param, "falsevalue")
        return param

    args["value"] = str(value)
    if isinstance(value, int):
        return IntegerParam(**_arguments(plan.input_name, args))
    if isinstance(value, float):
        return FloatParam(**_arguments(plan.input_name, args))
    if isinstance(value, str):
        return TextParam(**_arguments(plan.input_name, args))
    raise ValueError(
        f"cannot derive an input for parameter '{plan.name}' from {value!r}"
    )


_ORDINALS = ("First", "Second")

_BUILDERS: Dict[str, Callable] = {
    typespec.TEXT: _text,
    typespec.INTEGER: _integer,
    typespec.FLOAT: _float,
    typespec.BOOLEAN: _boolean,
    typespec.SELECT: _select,
    typespec.FIELDS: _fields,
    typespec.FILES: _files,
    typespec.RANGES: _ranges,
    typespec.MAPPING: _mapping,
    typespec.TUPLE: _tuple,
    typespec.OUTPUT_PATH: _output_path,
}


# --------------------------------------------------------------------------
# helpers
# --------------------------------------------------------------------------
def _empty_field_validator() -> ValidatorParam:
    validator = ValidatorParam(type="empty_field")
    # galaxyxml always sets the (empty) text, which would be serialised as
    # ``<validator type="empty_field"><![CDATA[]]></validator>``
    validator.node.text = None
    return validator


def _regex_validator(pattern: str, message: Optional[str] = None) -> ValidatorParam:
    validator = ValidatorParam(type="regex", message=message, text=pattern)
    return validator


def _drop_attribute(param, name: str) -> None:
    """Remove an attribute that galaxyxml adds by default."""
    param.node.attrib.pop(name, None)
