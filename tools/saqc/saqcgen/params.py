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
from .introspect import COLUMN_SUFFIX, ParamPlan
from .typespec import TypeSpec

__all__ = ["build", "input_name_for", "select_widget"]

#: description of the "choose the input format" selector
TYPE_SELECTOR_HELP = (
    "The parameter supports different input formats, you can choose which one "
    "suites your application."
)

#: appended to the help text of text parameters with a format restriction
_TEXT_HELP = {
    typespec.TIMEDELTA: (
        " Format: a fixed time duration (no calendar logic), as understood by "
        "pandas.Timedelta. Examples: '1d', '2.5h', '30min', '1h30min', "
        "'1 day 2 hours', '00:00:30', 'P1D'. (No 'M' or 'Y')."
    ),
    typespec.OFFSET_OR_TIMEDELTA: (
        " Format: a time offset, either a calendar based pandas offset alias "
        "(e.g. '1D', 'ME' (month end), 'W-MON') or a fixed duration "
        "(e.g. '3 days', '1h30min')."
    ),
    typespec.OFFSET: (
        " Format: a pandas offset alias, e.g. '1D', '15min', 'W-MON' or 'ME' "
        "(month end). Note that pandas 3 removed the legacy aliases 'M', 'Y', "
        "'H', 'T', 'S', 'L', 'U' and 'N': use 'ME', 'YE', 'h', 'min', 's', "
        "'ms', 'us' and 'ns' instead."
    ),
    typespec.FLAG: (
        " Format: a flag name of the active flagging scheme (e.g. 'BAD', "
        "'DOUBTFUL') or a numeric flag value (e.g. '255')."
    ),
}

#: a number with an optional decimal part, e.g. ``1`` or ``2.5``
_NUMBER = r"[0-9]+(?:\.[0-9]+)?"

#: an offset alias with an optional weekday suffix, e.g. ``D`` or ``W-MON``
_UNIT = r"[A-Za-z]+(?:-[A-Za-z]{3})?"

#: The patterns below are *shape* checks, not a re-implementation of the pandas
#: grammar: pandas owns its aliases and changes them between releases (pandas 3
#: dropped ``1M``, ``1H``, ``1T`` and friends and added multi unit offsets such
#: as ``1h30min``), so a fixed vocabulary would block valid input sooner or
#: later.  They are anchored and case insensitive, and reject anything that is
#: not even shaped like a duration -- the actual validation is done by SaQC,
#: which reports the precise pandas error.  ``(^$)`` lets an optional parameter
#: stay empty.
#:
#: Galaxy validates with ``re.match``, i.e. the pattern has to anchor its end
#: itself; ``$`` (not ``\Z``) is used on purpose, it also matches in front of a
#: trailing newline, which pandas tolerates.
_OFFSET_BODY = (
    rf"^\s*[+-]?\s*(?:{_NUMBER}\s*)?{_UNIT}\s*(?:{_NUMBER}\s*{_UNIT}\s*)*$"
)
_TIMEDELTA_BODY = (
    r"^\s*[+-]?\s*(?:"
    rf"{_NUMBER}\s*[A-Za-z]+\s*,?\s*"  # 1d, 2.5 hours
    rf"|{_NUMBER}\s*,?\s*"  # a bare number means nanoseconds
    r"|[0-9]+:[0-9]+(?::[0-9]+(?:\.[0-9]+)?)?"  # 00:00:30
    r"|P[0-9A-Za-z.]*"  # ISO 8601, e.g. P1DT2H
    r")+$"
)
_OFFSET_PATTERN = rf"(?i:(^$)|({_OFFSET_BODY}))"
_TIMEDELTA_PATTERN = rf"(?i:(^$)|({_TIMEDELTA_BODY}))"
_OFFSET_OR_TIMEDELTA_PATTERN = (
    rf"(?i:(^$)|({_OFFSET_BODY})|({_TIMEDELTA_BODY}))"
)

#: SaQC writes plots into the working directory, where Galaxy discovers them by
#: ``*.png``, so the name has to be a single file name and not a path.  An
#: anchored pattern is essential here, otherwise a prefix match would let
#: ``../plot`` or ``plot.png; rm -rf /`` through.
_PATH_PATTERN = r"^[\w][\w .\-]*$"

#: a flag is either the name of a flag of the active flagging scheme or its
#: numeric value (``EXTERNAL_FLAG`` is ``Union[str, float, int]``)
_FLAG_PATTERN = r"(?i:(^$)|(^(?:[A-Za-z_][A-Za-z0-9_.+\-]*|[+-]?[0-9]+(?:\.[0-9]+)?)$))"

#: free text parameters have no format to check, but the value ends up on a
#: single line of the generated configuration, so line breaks have to go.  The
#: pattern also rejects a value that only consists of white space; ``.*`` does
#: not match a line break, so an embedded one never reaches the ``$``.
_FREE_TEXT_PATTERN = r"^\s*\S.*$"
_FREE_TEXT_MESSAGE = "Must not be empty and must not contain a line break."

_VALIDATORS = {
    typespec.TIMEDELTA: (
        _TIMEDELTA_PATTERN,
        "Must be a fixed time duration as understood by pandas.Timedelta "
        "(e.g. '1d', '2.5h', '30min', '1h30min', '00:00:30'). Month (M) or "
        "Year (Y) are NOT allowed.",
    ),
    typespec.OFFSET_OR_TIMEDELTA: (
        _OFFSET_OR_TIMEDELTA_PATTERN,
        "Accepts a pandas calendar offset (e.g. '1D', 'W-SAT', 'ME') as well "
        "as a fixed duration (e.g. '3 days', '1h30min').",
    ),
    typespec.OFFSET: (
        _OFFSET_PATTERN,
        "Must be a pandas offset alias, e.g. '1D', '15min', 'W-MON' or 'ME'. "
        "The legacy aliases 'M', 'Y', 'H', 'T', 'S', 'L', 'U' and 'N' are no "
        "longer supported, use 'ME', 'YE', 'h', 'min', 's', 'ms', 'us' or "
        "'ns'.",
    ),
    typespec.FLAG: (
        _FLAG_PATTERN,
        "Must be the name of a flag of the flagging scheme in use (e.g. "
        "'BAD') or a numeric flag value (e.g. '255').",
    ),
}


def build(plan: ParamPlan) -> object:
    """Build the Galaxy input(s) for one SaQC method parameter."""
    if plan.from_default:
        return _from_default_value(plan)

    args: Dict[str, object] = {
        "name": input_name_for(plan),
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
        plan.specs[0],
        input_name_for(plan, plan.specs[0]),
        args,
        plan.optional,
        plan.default_value,
    )


def input_name_for(plan: ParamPlan, spec: Optional[TypeSpec] = None) -> str:
    """The name of the Galaxy input of ``plan``, resp. of one of its formats.

    The input of a column selection is named separately, so the script that
    writes the configuration can tell an index of the input table (which has to
    be translated to a column name) from a plain value: SaQC accepts a
    timestamp such as ``"1"`` for some of the sibling formats.  SaQC has no
    type selection with more than one column format and the formats are
    otherwise deduplicated by their widget, so the name is unambiguous.

    Everything else is named like the SaQC argument.
    """
    if spec is not None and plan.has_type_selection and spec.kind == typespec.FIELDS:
        return f"{plan.name}{COLUMN_SUFFIX}"
    return plan.name


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
    base_name = input_name_for(plan)
    conditional = Conditional(name=f"{base_name}_cond")
    conditional.append(
        SelectParam(
            name=f"{base_name}_selector",
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
                spec,
                input_name_for(plan, spec),
                dict(args),
                plan.optional,
                plan.default_value,
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

    # a ``multiple`` text parameter holds a list of values and Galaxy applies
    # the validators to every element separately, so they work either way
    text_args = dict(_arguments(name, args))
    if spec.multiple:
        text_args["multiple"] = True
    param = TextParam(**text_args)
    if spec.validator in _VALIDATORS:
        param.append(_regex_validator(*_VALIDATORS[spec.validator]))
    if spec.multiple:
        # every entry has to be a value of its own
        param.append(_regex_validator(_FREE_TEXT_PATTERN, _FREE_TEXT_MESSAGE))
    elif spec.validator not in _VALIDATORS:
        param.append(
            _regex_validator(
                rf"(^$)|({_FREE_TEXT_PATTERN})" if optional else _FREE_TEXT_PATTERN,
                _FREE_TEXT_MESSAGE,
            )
        )
    if not optional and not spec.multiple:
        # ``empty_field`` compares the value to '' and therefore never fails
        # for a list, a ``multiple`` parameter is validated per element instead
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
    # a SaQC column is an index, but a user reads the header of their table
    args.update(
        type="data_column",
        data_ref="data",
        multiple=spec.multiple,
        use_header_names=True,
    )
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
    param.append(
        _regex_validator(
            _PATH_PATTERN,
            "Must be a plain file name within the working directory: letters, "
            "digits, spaces, '.', '-' and '_' (no directories).",
        )
    )
    param.append(_empty_field_validator())
    return param


def _from_default_value(plan: ParamPlan):
    """Input for an unannotated parameter, derived from its default value."""
    value = plan.default_value
    name = input_name_for(plan)
    args: Dict[str, object] = {
        "name": name,
        "argument": plan.name,
        "label": plan.label,
        "help": plan.help,
    }

    if isinstance(value, bool):
        param = BooleanParam(checked=value, **_arguments(name, args))
        _drop_attribute(param, "truevalue")
        _drop_attribute(param, "falsevalue")
        return param

    args["value"] = str(value)
    if isinstance(value, int):
        return IntegerParam(**_arguments(name, args))
    if isinstance(value, float):
        return FloatParam(**_arguments(name, args))
    if isinstance(value, str):
        return TextParam(**_arguments(name, args))
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
