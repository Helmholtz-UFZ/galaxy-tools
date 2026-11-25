"""Generation of the test macros (``test_macros.xml``).

One test per SaQC method (plus one test per accepted input format of its
parameters) runs the tool in configuration-only mode and checks the generated
configuration.  The expected configuration keys are derived from the very same
parameter plans the tool inputs are built from, so a new SaQC parameter is
covered by a test as soon as it shows up in the tool.
"""

from __future__ import annotations

from types import ModuleType
from typing import Any, Dict, Iterator, List
from xml.etree import ElementTree as ET

from . import params, samples
from .introspect import Introspection, ParamPlan, saqc_parameter_name

__all__ = ["generate_test_macros"]

#: parameters that are not written into the configuration file
_UNASSERTED_PARAMETERS = frozenset({"field", "target", "group", "method_select"})

#: names of the elements of a nested input, they are not configuration keys
_NESTED_SUFFIXES = ("_pos0", "_pos1", "_min", "_max", "_start", "_end")

#: modules/methods that additionally produce a collection output, the set of
#: outputs is the one of a normal test plus the collection
_COLLECTION_METHODS = frozenset({("tools", "plot"), ("optisaqc", "calibratePipeline")})


def generate_test_macros(introspection: Introspection) -> str:
    """Render the test macros XML as a string."""
    root = ET.Element("macros")
    macro = ET.SubElement(root, "xml", {"name": "config_tests"})
    for test in _tests(introspection):
        macro.append(test)

    ET.indent(root, space="  ")
    body = ET.tostring(root, encoding="utf-8").decode("utf-8")
    return f'<?xml version="1.0" encoding="utf-8"?>\n{body}'


def _tests(introspection: Introspection) -> Iterator[ET.Element]:
    for module_name, module_obj in introspection.modules():
        if introspection.is_deprecated(module_obj):
            continue
        for method in introspection.methods(module_obj):
            if introspection.skip_reason(method, module_obj) is not None:
                continue
            for parameters in _variants(introspection, method, module_obj):
                yield _test(module_name, method.__name__, parameters)


def _test(module_name: str, method_name: str, parameters: Dict[str, Any]) -> ET.Element:
    """One ``<test>`` running a single method."""
    has_collection = (module_name, method_name) in _COLLECTION_METHODS
    expect_num_outputs = "3" if has_collection else "2"
    test = ET.Element("test", {"expect_num_outputs": expect_num_outputs})
    ET.SubElement(
        test, "param", {"name": "data", "value": "test1/data.csv", "ftype": "csv"}
    )
    ET.SubElement(test, "param", {"name": "run_test_mode", "value": "true"})

    repeat = ET.SubElement(test, "repeat", {"name": "methods_repeat"})
    module_conditional = ET.SubElement(repeat, "conditional", {"name": "module_cond"})
    ET.SubElement(
        module_conditional, "param", {"name": "module_select", "value": module_name}
    )
    method_conditional = ET.SubElement(
        module_conditional, "conditional", {"name": "method_cond"}
    )
    ET.SubElement(
        method_conditional, "param", {"name": "method_select", "value": method_name}
    )
    _append_parameters(method_conditional, parameters)

    output = ET.SubElement(test, "output", {"name": "config_out", "ftype": "txt"})
    assertions = ET.SubElement(output, "assert_contents")
    ET.SubElement(assertions, "has_text", {"text": method_name})
    for name in _asserted_parameters(parameters):
        ET.SubElement(assertions, "has_text", {"text": f"{name}="})
    return test


def _append_parameters(parent: ET.Element, parameters: Dict[str, Any]) -> None:
    """Write a ``{name: value}`` mapping as (nested) Galaxy test parameters."""
    for name, value in parameters.items():
        if name.endswith("_cond") and isinstance(value, dict):
            conditional = ET.SubElement(parent, "conditional", {"name": name})
            _append_parameters(conditional, value)
        elif isinstance(value, list):
            repeat = ET.SubElement(parent, "repeat", {"name": name})
            for item in value:
                _append_parameters(repeat, item)
        else:
            if isinstance(value, bool):
                text = str(value).lower()
            elif value is None:
                text = ""
            else:
                text = str(value)
            ET.SubElement(parent, "param", {"name": name, "value": text})


def _asserted_parameters(parameters: Dict[str, Any]) -> List[str]:
    """The configuration keys that a test can check for."""
    names: Dict[str, None] = {}

    def collect(values: Dict[str, Any]) -> None:
        for name, value in values.items():
            if name.endswith("_selector"):
                continue
            if isinstance(value, dict):
                if name.endswith("_cond"):
                    names[name[: -len("_cond")]] = None
                collect(value)
            elif isinstance(value, list):
                names[name] = None
                for item in value:
                    if isinstance(item, dict):
                        collect(item)
            else:
                names[name] = None

    collect(parameters)
    return [
        saqc_parameter_name(name)
        for name in names
        if name not in _UNASSERTED_PARAMETERS
        and not any(suffix in name for suffix in _NESTED_SUFFIXES)
    ]


# --------------------------------------------------------------------------
# test variants
# --------------------------------------------------------------------------
def _variants(
    introspection: Introspection, method: Any, module: ModuleType
) -> List[Dict[str, Any]]:
    """The parameters of the default test, plus one test per input format."""
    defaults: Dict[str, Any] = {}
    selections: List[ParamPlan] = []

    for plan in introspection.parameters(method, module):
        if plan.from_default:
            # the input is frozen to the default of the parameter
            continue
        if plan.has_type_selection:
            selections.append(plan)
            continue
        name = params.input_name_for(plan)
        _set_value(
            defaults,
            name,
            samples.sample_values(plan.specs[0], name, plan.default),
        )

    for plan in selections:
        defaults[_conditional_name(plan)] = _selected(plan, 0)

    variants = [defaults]
    for plan in selections:
        for index in range(1, len(plan.specs)):
            variant = dict(defaults)
            variant[_conditional_name(plan)] = _selected(plan, index)
            variants.append(variant)
    return variants


def _conditional_name(plan: ParamPlan) -> str:
    return f"{params.input_name_for(plan)}_cond"


def _selected(plan: ParamPlan, index: int) -> Dict[str, Any]:
    """The parameters of one ``when`` block of a type selection."""
    values: Dict[str, Any] = {
        f"{params.input_name_for(plan)}_selector": f"type_{index}"
    }
    input_name = params.input_name_for(plan, plan.specs[index])
    _set_value(
        values,
        input_name,
        samples.sample_values(plan.specs[index], input_name, plan.default),
    )
    return values


def _set_value(parameters: Dict[str, Any], name: str, value: Any) -> None:
    """Store a sample value, flattening the inputs that are sibling fields."""
    if isinstance(value, dict):
        parameters.update(value)
    else:
        parameters[name] = value
