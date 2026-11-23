"""Introspection of the SaQC package: which modules, methods and parameters exist.

The SaQC public API is a collection of mixin classes (one per module, e.g.
``saqc.funcs.breaks.BreaksMixin``) whose methods take a ``self`` annotated with
``SaQC``.  Those methods are the ones a user can call from a configuration file
and therefore the ones that are exposed in the Galaxy tool.

This module answers three questions:

* which modules/methods should be shown at all (:meth:`Introspection.modules`,
  :meth:`Introspection.methods`),
* which parameters of a method can be represented in the Galaxy UI, and how
  (:meth:`Introspection.parameters`),
* how a parameter should be labelled and documented
  (:class:`ParamPlan`).
"""

from __future__ import annotations

import inspect
import logging
import sys
from dataclasses import dataclass, field, replace
from types import ModuleType
from typing import (
    Any,
    Callable,
    Dict,
    List,
    Literal,
    Mapping,
    Optional,
    Tuple,
    get_origin,
)

from . import docs
from .typespec import (
    BOOLEAN,
    FIELDS,
    FILES,
    FLOAT,
    INTEGER,
    SELECT,
    TEXT,
    TypeSpec,
    annotation_to_string,
    friendly_name,
    parse_annotation,
    split_union,
)

__all__ = [
    "HIDDEN_PARAMETERS",
    "Introspection",
    "ParamPlan",
    "TYPE_OVERRIDES",
    "annotation_to_string",
    "discover_aliases",
]

logger = logging.getLogger(__name__)

#: parameters that are never user configurable
HIDDEN_PARAMETERS = frozenset({"self", "kwargs", "reduce_func", "metric"})

#: parameters that SaQC cannot render because their type is not a simple value
FUNCTION_TYPES = ("Callable", "GenericFunction", "CurveFitter")

#: methods that are suppressed on purpose, keyed by ``module|method``
SKIP_METHODS = frozenset(
    {
        # https://git.ufz.de/rdm-software/saqc/-/issues/512
        "saqc.funcs.tools|flagByClick",
    }
)

#: types that are replaced before looking at the type hint,
#: keyed by ``(module, method, parameter)``
TYPE_OVERRIDES: Dict[Tuple[str, str, str], str] = {
    # https://git.ufz.de/rdm-software/saqc/-/issues/511
    ("saqc.funcs.tools", "plot", "path"): "OutputPath",
}

#: type hint members that cannot be displayed and are silently dropped
_UNSUPPORTED_MEMBERS = {"dict", "slice", "none", "mpl.axes.axes"}

#: parameters that select a column of the input table
_FIELD_PARAMETERS = ("target", "reference")


def discover_aliases(*modules: Optional[ModuleType]) -> Dict[str, Any]:
    """Collect the module level type aliases of SaQC.

    SaQC annotates many parameters with the name of a module level alias
    instead of spelling out the type, e.g. ``FILL_METHODS`` (a ``Literal``) or
    ``EXTERNAL_FLAG`` (a ``Union``).  The returned mapping lets the type parser
    resolve those names.
    """
    aliases: Dict[str, Any] = {}
    for module in modules:
        if module is None:
            continue
        for name in dir(module):
            if not name.isupper() or name.startswith("_"):
                continue
            try:
                value = getattr(module, name)
            except Exception:  # pragma: no cover - defensive
                continue
            if get_origin(value) is None:
                continue
            logger.debug("discovered alias '%s' in '%s'", name, module.__name__)
            aliases[name] = value
    return aliases


@dataclass(frozen=True)
class ParamPlan:
    """How one method parameter is represented in the Galaxy tool."""

    name: str
    #: one spec per accepted input format (more than one -> type selection)
    specs: Tuple[TypeSpec, ...]
    optional: bool
    label: str
    help: str = ""
    #: default value as written into an input field (None: no default)
    default: Optional[str] = None
    #: the default value as it appears in the SaQC source
    default_value: Any = None
    #: True for unannotated parameters, whose input is derived from the default
    from_default: bool = False

    @property
    def has_type_selection(self) -> bool:
        return len(self.specs) > 1


class Introspection:
    """Cached queries against the SaQC package."""

    def __init__(
        self, package: ModuleType, aliases: Optional[Mapping[str, Any]] = None
    ):
        self.package = package
        #: name -> typing object of the module level type aliases of SaQC
        self.aliases = dict(aliases or {})
        #: the aliases that stand for a fixed set of values
        self.selection_aliases = frozenset(
            name for name, value in self.aliases.items() if get_origin(value) is Literal
        )
        self._modules: Optional[List[Tuple[str, ModuleType]]] = None
        self._methods: Dict[int, List[Callable]] = {}
        self._plans: Dict[int, List[ParamPlan]] = {}

    # -- structure ---------------------------------------------------------
    def modules(self) -> List[Tuple[str, ModuleType]]:
        """All SaQC function modules, in the order of ``saqc.funcs``."""
        if self._modules is None:
            self._modules = inspect.getmembers(self.package.funcs, inspect.ismodule)
        return self._modules

    def methods(self, module: ModuleType) -> List[Callable]:
        """All methods of a module that operate on a ``SaQC`` object."""
        cached = self._methods.get(id(module))
        if cached is not None:
            return cached

        methods: List[Callable] = []
        for _, cls in inspect.getmembers(module, inspect.isclass):
            if inspect.ismodule(cls):
                continue
            for _, method in inspect.getmembers(cls, inspect.isfunction):
                parameters = inspect.signature(method).parameters
                if "self" not in parameters:
                    continue
                if annotation_to_string(parameters["self"].annotation) == "SaQC":
                    methods.append(method)
        self._methods[id(module)] = methods
        return methods

    def is_deprecated(self, obj: Any) -> bool:
        """True for docstrings that contain a ``.. deprecated::`` directive."""
        return docs.header_is_deprecated(getattr(obj, "__doc__", None))

    def skip_reason(self, method: Callable, module: ModuleType) -> Optional[str]:
        """Why a method cannot be exposed in the Galaxy tool (``None``: it can)."""
        if self.is_deprecated(method):
            return "deprecated method"
        if f"{module.__name__}|{method.__name__}" in SKIP_METHODS:
            return "hardcoded to be skipped"

        for name, parameter in inspect.signature(method).parameters.items():
            annotation = annotation_to_string(parameter.annotation)
            looks_like_function = "func" in name.lower() or any(
                function_type in annotation for function_type in FUNCTION_TYPES
            )
            if not looks_like_function:
                continue
            if "Literal[" in annotation or annotation in self.selection_aliases:
                continue
            if parameter.default is not inspect.Parameter.empty:
                continue
            if "None" in split_union(annotation):
                continue
            return (
                f"contains mandatory function-parameter '{name}' "
                f"(Type: {annotation}) which cannot be mapped to Galaxy UI"
            )
        return None

    # -- parameters --------------------------------------------------------
    def parameters(self, method: Callable, module: ModuleType) -> List[ParamPlan]:
        """The Galaxy input plans for one SaQC method."""
        module_name = module.__name__
        cached = self._plans.get(id(method))
        if cached is not None:
            return cached

        sections = docs.split_sections(method.__doc__)
        parameter_docs = docs.parameter_docs(sections)

        plans: List[ParamPlan] = []
        for name, parameter in inspect.signature(method).parameters.items():
            if name in HIDDEN_PARAMETERS or "kwarg" in name.lower():
                continue
            if _is_documented_as_deprecated(parameter_docs, name):
                logger.info(
                    "(%s): skipping deprecated parameter '%s' of '%s'",
                    module.__name__,
                    name,
                    method.__name__,
                )
                continue
            plan = self._plan(method, module, name, parameter, parameter_docs)
            if plan is not None:
                plans.append(plan)

        self._plans[id(method)] = plans
        return plans

    def _plan(
        self,
        method: Callable,
        module: ModuleType,
        name: str,
        parameter: inspect.Parameter,
        parameter_docs: Mapping[str, str],
    ) -> Optional[ParamPlan]:
        module_name = module.__name__
        annotation = annotation_to_string(parameter.annotation)
        override = TYPE_OVERRIDES.get((module_name, method.__name__, name))
        if override:
            annotation = override
            optional = False
        else:
            optional = parameter.default is None or "None" in split_union(annotation)

        label, help_text = docs.label_and_help(name, parameter_docs)
        has_default = (
            parameter.default is not inspect.Parameter.empty
            and parameter.default is not None
            and not callable(parameter.default)
        )
        default_value = parameter.default if has_default else None

        if _is_function_parameter(name, annotation) and not self._has_literal_option(
            annotation
        ):
            logger.info(
                "(%s): skipping parameter '%s' of '%s' "
                "(accepts a function, which cannot be configured)",
                module_name,
                name,
                method.__name__,
            )
            return None

        if annotation and "Sequence[SaQC]" in annotation:
            specs: List[TypeSpec] = [TypeSpec(FILES, annotation)]
        elif annotation and _is_field_parameter(name):
            specs = [
                TypeSpec(
                    FIELDS,
                    annotation,
                    multiple=any(
                        keyword in annotation.lower() for keyword in ("list", "sequence")
                    ),
                )
            ]
        else:
            specs = self._specs(annotation, method, module, name)
        if not specs:
            if not annotation and has_default:
                # a parameter without type information, but with a default value:
                # the input is a plain input field for that value
                logger.info(
                    "(%s): parameter '%s' of '%s' misses a type annotation, "
                    "using its default value",
                    module_name,
                    name,
                    method.__name__,
                )
                return ParamPlan(
                    name=name,
                    specs=(),
                    optional=optional,
                    label=label,
                    help=help_text,
                    default_value=default_value,
                    from_default=True,
                )
            logger.info(
                "(%s): skipping parameter '%s' of '%s' (no supported type)",
                module.__name__,
                name,
                method.__name__,
            )
            return None

        specs = [
            _with_option_labels(spec, name, parameter_docs) for spec in specs
        ]

        return ParamPlan(
            name=name,
            specs=tuple(specs),
            optional=optional,
            label=label,
            help=help_text,
            default=None if default_value is None or isinstance(default_value, bool)
            else str(default_value),
            default_value=default_value,
        )

    def _has_literal_option(self, annotation: str) -> bool:
        """True if a parameter also accepts one of a fixed set of values."""
        return any(
            "Literal[" in member or member in self.selection_aliases
            for member in split_union(annotation)
        )

    def _specs(
        self,
        annotation: str,
        method: Callable,
        module: ModuleType,
        name: str,
    ) -> List[TypeSpec]:
        """Parse and clean the union members of a parameter annotation."""
        members = split_union(annotation) if annotation else []
        members = _expand_aliases(members, self.aliases)
        members = _drop_unsupported_members(
            members, f"{module.__name__}|{method.__name__}|{name}"
        )
        if not members:
            return []

        if len(members) > 1 and all(
            member in ("SaQCFields", "NewSaQCFields") for member in members
        ):
            members = ["SaQCFields"]

        if len(members) > 1 and any(
            "Literal[" in member or member in self.selection_aliases
            for member in members
        ):
            without_functions = [
                member
                for member in members
                if not any(function_type in member for function_type in FUNCTION_TYPES)
            ]
            if len(without_functions) < len(members):
                logger.info(
                    "(%s): hiding function option of parameter '%s' in '%s' "
                    "because a selection option exists",
                    module.__name__,
                    name,
                    method.__name__,
                )
            members = without_functions

        specs = [parse_annotation(member) for member in members]
        known = [spec for spec in specs if spec is not None]
        unknown = [m for m, spec in zip(members, specs) if spec is None]
        for member in unknown:
            logger.info(
                "(%s): cannot map type '%s' of parameter '%s' in '%s' to a Galaxy input",
                module.__name__,
                member,
                name,
                method.__name__,
            )
        known = _dedupe_by_name(known, f"{module.__name__}|{method.__name__}|{name}")
        if _is_any_scalar(known):
            # e.g. ``EXTERNAL_FLAG``: a text field accepts both the name of a
            # flag (``BAD``) and its numeric value, so a type selection would
            # only be in the way
            return [TypeSpec(TEXT, annotation, plain_value=True)]
        return known


#: the kinds of input that SaQC reads from a plain field
_SCALAR_KINDS = frozenset({TEXT, INTEGER, FLOAT, BOOLEAN})

#: the builtin types that make a union a plain value union
_BASIC_SCALARS = frozenset({"str", "string", "any", "int", "float", "bool"})


def _expand_aliases(
    members: List[str],
    aliases: Mapping[str, Any],
    seen: Tuple[str, ...] = (),
) -> List[str]:
    """Replace module level type aliases by the types they stand for."""
    expanded: List[str] = []
    for member in members:
        alias = aliases.get(member)
        if alias is None or member in seen:
            expanded.append(member)
            continue
        expanded.extend(
            _expand_aliases(
                split_union(annotation_to_string(alias)), aliases, seen + (member,)
            )
        )
    return expanded


def _dedupe_by_name(specs: List[TypeSpec], where: str) -> List[TypeSpec]:
    """Drop the inputs that a user cannot tell apart.

    ``list`` and ``ArrayLike`` for example are both presented as a free text
    field for several values, and Galaxy rejects a selection with two options
    of the same label.
    """
    seen: Dict[str, None] = {}
    kept: List[TypeSpec] = []
    for spec in specs:
        name = friendly_name(spec)
        if name in seen:
            logger.info(
                "(%s): ignoring type '%s', it is entered like '%s'",
                where,
                spec.text,
                name,
            )
            continue
        seen[name] = None
        kept.append(spec)
    return kept


def _is_any_scalar(specs: List[TypeSpec]) -> bool:
    """True for a union of plain values that includes a free text option.

    ``EXTERNAL_FLAG`` (``Union[str, float, int]``) is such a union: a text
    field accepts both the name of a flag (``BAD``) and its numeric value.
    Unions that combine a plain type with a formatted one (e.g. an offset
    string next to an integer) keep their type selection.
    """
    kinds = {spec.kind for spec in specs}
    if len(specs) < 2 or not kinds <= _SCALAR_KINDS or TEXT not in kinds:
        return False
    return all(spec.text.strip().lower() in _BASIC_SCALARS for spec in specs)


def _is_function_parameter(name: str, annotation: str) -> bool:
    """True for parameters that expect a callable (or are named like one)."""
    return "func" in name.lower() or any(
        function_type in annotation for function_type in FUNCTION_TYPES
    )


def _is_field_parameter(name: str) -> bool:
    return "field" in name.lower() or name in _FIELD_PARAMETERS


def _with_option_labels(
    spec: TypeSpec, parameter: str, parameter_docs: Mapping[str, str]
) -> TypeSpec:
    """Attach the option descriptions of a ``Literal`` to its spec."""
    if spec.kind != SELECT:
        return spec
    descriptions = docs.option_help(parameter, spec.options, parameter_docs)
    labels = tuple((option, descriptions.get(option, option)) for option in spec.options)
    return replace(spec, option_labels=labels)


def _drop_unsupported_members(members: List[str], where: str) -> List[str]:
    """Drop union members that cannot be displayed in the Galaxy UI."""
    kept: List[str] = []
    for member in members:
        if member.lower() in _UNSUPPORTED_MEMBERS:
            if member.lower() != "none":
                logger.info("ignoring unsupported type '%s' in %s", member, where)
            continue
        if any(f"list[{member}]" == other for other in members):
            logger.info(
                "ignoring type '%s' in %s because 'list[%s]' is also accepted",
                member,
                where,
                member,
            )
            continue
        kept.append(member)
    return kept


def _is_documented_as_deprecated(parameter_docs: Mapping[str, str], name: str) -> bool:
    text = parameter_docs.get(name, "")
    if not text:
        return False
    first_line = text.splitlines()[0].lower().strip()
    return "deprecated" in first_line or ".. deprecated::" in text.lower()


def configure_logging() -> None:
    """Send the generator's progress messages to stderr."""
    if not logging.getLogger().handlers:
        logging.basicConfig(
            level=logging.INFO,
            stream=sys.stderr,
            format="%(message)s",
        )
