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
import math
import xml.etree.ElementTree as ET
from xml.dom import minidom
import os

try:
    import saqc
    from saqc.core import SaQC, DictOfSeries
    from saqc.funcs.curvefit import FILL_METHODS
    from saqc.funcs.drift import LinkageString
    from saqc.funcs.generic import GenericFunction
    from saqc.lib.types import CurveFitter
    from typing_inspect import is_callable_type, is_union_type
    import matplotlib as mpl
    import numpy as np
    import pandas as pd
except ImportError as e:
    print(f"FATAL: A critical dependency is missing: {e}", file=sys.stderr)
    sys.exit(1)

if TYPE_CHECKING:
    from types import ModuleType

# FINALE KORREKTE LISTE basierend auf saqc.xml
REPEAT_FIELD_FUNCS = [
    'flagDriftFromNorm', 'flagDriftFromReference', 'flagLOF', 'flagMVScores',
    'flagZScore', 'assignKNNScore', 'assignLOF', 'assignUniLOF'
]

def get_modules() -> list[Tuple[str, "ModuleType"]]:
    """Retrieves all modules from the saqc.funcs package."""
    return inspect.getmembers(saqc.funcs, inspect.ismodule)

def get_methods(module: "ModuleType") -> list[Callable]:
    """
    Extracts methods from a given module that have 'SaQC' as the type hint
    for their 'self' parameter, indicating they are part of the SaQC public API.
    """
    methods_with_saqc = []
    for _, cls in inspect.getmembers(module, inspect.isclass):
        if inspect.ismodule(cls): continue
        for method_name, method in inspect.getmembers(cls, inspect.isfunction):
            try:
                parameters = inspect.signature(method).parameters
                if "self" in parameters:
                    self_param = parameters["self"]
                    annotation = self_param.annotation
                    annotation_name = ''
                    if isinstance(annotation, str): annotation_name = annotation.strip("'")
                    elif isinstance(annotation, ForwardRef): annotation_name = annotation.__forward_arg__.strip("'")
                    elif hasattr(annotation, '__name__'): annotation_name = annotation.__name__
                    if annotation_name == 'SaQC': methods_with_saqc.append(method)
            except (ValueError, TypeError): continue
    return methods_with_saqc

def get_param_info(method: Callable) -> Dict[str, Any]:
    """
    Inspects a callable and returns a dictionary with detailed information
    about its parameters, resolving type annotations and default values.
    """
    param_info = {}
    try:
        parameters = inspect.signature(method).parameters
    except (ValueError, TypeError):
        return {}

    for name, param in parameters.items():
        if name in ["self", "kwargs", "store_kwargs", "ax_kwargs"]: continue
        annotation = param.annotation
        # Resolve forward references and string annotations
        if isinstance(annotation, (str, ForwardRef)):
            try:
                eval_context = {
                    **globals(), **saqc.__dict__, **saqc.lib.types.__dict__,
                    **saqc.funcs.__dict__, 'pd': pd, 'np': np, 'mpl': mpl,
                    'Union': Union, 'Literal': Literal, 'Sequence': Sequence,
                    'Callable': Callable, 'Any': Any, 'Tuple': Tuple, 'Dict': Dict
                }
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

        # Simplify Union[T, None] to just T
        origin = get_origin(annotation)
        args = get_args(annotation)
        is_union_with_none = is_union_type(annotation) and type(None) in args
        if is_union_with_none:
            non_none_args = [a for a in args if a is not type(None)]
            annotation = Union[tuple(non_none_args)] if len(non_none_args) > 1 else (non_none_args[0] if non_none_args else Any)
            origin, args = get_origin(annotation), get_args(annotation)

        param_info[name] = {
            'annotation': annotation, 'origin': origin, 'args': args,
            'default': param.default if param.default is not param.empty else inspect.Parameter.empty
        }
    return param_info

def generate_test_variants(method: Callable) -> list:
    """
    Generates a list of test case variants for a given method based on its
    parameter types and default values.
    """
    param_info = get_param_info(method)
    if not param_info: return []
    
    variants, base_params, complex_params_to_vary = [], {}, set()

    # Establish base parameters and identify complex ones to vary
    for name, info in param_info.items():
        default = info['default']
        annotation = info['annotation']
        origin = get_origin(info['annotation'])
        args = get_args(info['annotation'])

        if (origin is Literal and len(args) > 1) or (origin is Union and len(args) > 1):
            complex_params_to_vary.add(name)

        # General logic for assigning defaults
        # Condition 1: A meaningful, non-empty default exists in the function signature.
        if default is not inspect.Parameter.empty and default is not None and default != "":
            if annotation is bool:
                base_params[name] = not default
            else:
                base_params[name] = default
        # Condition 2 (else): No default exists OR the default is empty/None.
        else:
            # Assign a sensible, non-empty default for testing purposes based on type.
            if name in ['field', 'target']:
                base_params[name] = 'test_variable'
            elif origin is Literal and args:
                base_params[name] = args[0]
            elif annotation is bool:
                base_params[name] = True
            elif annotation is int:
                base_params[name] = 1
            elif annotation is float:
                base_params[name] = 1.0
            else:
                base_params[name] = "default_string"
            
    variants.append({"description": f"Test mit Defaults für {method.__name__}", "params": base_params})

    # Create variants for complex parameters
    for name in complex_params_to_vary:
        info, options_to_test = param_info[name], []
        if info['origin'] is Literal:
            options_to_test = info['args']
        elif info['origin'] is Union:
            for arg_type in info['args']:
                if arg_type is type(None): continue
                if arg_type is int: options_to_test.append(123)
                elif arg_type is float: options_to_test.append(45.6)
                elif arg_type is str: options_to_test.append("a_string")
                elif pd and hasattr(pd, 'Timedelta') and arg_type == pd.Timedelta: options_to_test.append("2H")

        for option in options_to_test:
            if option is None: continue
            variant_params = base_params.copy()
            
            if name == 'thresh' and isinstance(option, float):
                variant_params['thresh_cond'] = {'thresh_select_type': 'float', 'thresh': option}
                if 'thresh' in variant_params: del variant_params['thresh']
            elif name == 'density' and isinstance(option, float):
                 variant_params['density_cond'] = {'density_select_type': 'float', 'density': option}
                 if 'density' in variant_params: del variant_params['density']
            else:
                variant_params[name] = option

            variants.append({"description": f"Test-Variante für '{name}' mit Wert '{str(option)}'", "params": variant_params})

    # Prepare final structure for XML generation
    final_variants = []
    for variant in variants:
        galaxy_params = {}
        for name, value in variant['params'].items():
            info = param_info.get(name, {})
            is_union_cond = info.get('origin') is Union and any(t in info.get('args', []) for t in [int, float]) and str in info.get('args', [])

            if name in ["field", "target"]:
                if method.__name__ in REPEAT_FIELD_FUNCS:
                    val_list = [value] if not isinstance(value, list) else value
                    galaxy_params[f"{name}_repeat"] = [{name: v} for v in val_list]
                    # === WORKAROUND FÜR GALAXY-PARSER-BUG ===
                    # Fügt den field/target-Parameter redundant hinzu, damit der Test-Runner ihn erkennt.
                    galaxy_params[name] = value
                else:
                    galaxy_params[name] = value
            elif name.endswith('_cond') and isinstance(value, dict):
                 galaxy_params[name] = value
            elif is_union_cond:
                type_map = {int: 'number', float: 'number', str: 'timedelta'}
                val_type = type_map.get(type(value), 'offset')
                galaxy_params[f"{name}_cond"] = {f"{name}_select_type": val_type, name: value}
            else:
                galaxy_params[name] = value
                
        final_variants.append({
            "description": variant["description"],
            "galaxy_params": galaxy_params,
            "saqc_call_params": variant["params"] 
        })
    return final_variants

def build_param_xml(parent: ET.Element, name: str, value: Any):
    """Recursively builds the XML <param> structure for Galaxy tests."""
    name_str = str(name)
    if name_str.endswith("_repeat") and isinstance(value, list):
        repeat = ET.SubElement(parent, "repeat", {"name": name_str})
        for item_dict in value:
            if isinstance(item_dict, dict):
                for sub_name, sub_value in item_dict.items():
                    build_param_xml(repeat, sub_name, sub_value) 
    elif name_str.endswith("_cond") and isinstance(value, dict):
        conditional = ET.SubElement(parent, "conditional", {"name": name_str})
        param_name_base = name_str.replace("_cond", "")
        selector_name = f"{param_name_base}_select_type"
        selector_value = value.get(selector_name)
        if selector_value is not None:
            ET.SubElement(conditional, "param", {"name": selector_name, "value": str(selector_value)})
            build_param_xml(conditional, param_name_base, value.get(param_name_base))
    else:
        val_str = str(value).lower() if isinstance(value, bool) else str(value) if value is not None else ""
        ET.SubElement(parent, "param", {"name": name_str, "value": val_str})

def format_value_for_regex(value: Any, param_name: str) -> str:
    """Formats a Python value into a regex string for assertion."""
    empty_is_none_params = [
        "reduce_window", "tolerance", "maxna", "maxna_group", "sub_window", "sub_thresh", 
        "min_periods", "min_residuals", "min_offset", "stray_range", "path", "ax", 
        "marker_kwargs", "plot_kwargs", "freq", "group", "xscope", "yscope"
    ]
    if param_name in empty_is_none_params and (value is None or value == ""):
        return '(None|"")'

    if value is None: return "None"
    if isinstance(value, bool): return f"({str(value)}|None)"
    if isinstance(value, str) and value.startswith('<function'):
        sanitized_val = value.replace('<', '__lt__').replace('>', '__gt__')
        return re.escape(sanitized_val)

    if isinstance(value, int):
        escaped_val = re.escape(str(value))
        return f'(?:["\']?{escaped_val}["\']?)'

    if isinstance(value, float):
        if math.isinf(value): return r"float\(['\"]-?inf['\"]\)"
        if math.isnan(value): return r"float\(['\"]nan['\"]\)"
        return re.escape(str(value))

    if isinstance(value, str):
        return f'["\']{re.escape(str(value))}["\']'

    return re.escape(str(value))

def main():
    """Main function to generate the Galaxy test macros XML."""
    macros_root = ET.Element("macros")
    all_tests_macro = ET.SubElement(macros_root, "xml", {"name": "config_tests"})
    print("--- Starting Test Generation (Definitive Hybrid Strategy v5) ---", file=sys.stderr)
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
                repeat = ET.SubElement(test_elem, "repeat", {"name": "methods_repeat"})
                mod_cond = ET.SubElement(repeat, "conditional", {"name": "module_cond"})
                ET.SubElement(mod_cond, "param", {"name": "module_select", "value": module_name})
                meth_cond = ET.SubElement(mod_cond, "conditional", {"name": "method_cond"})
                ET.SubElement(meth_cond, "param", {"name": "method_select", "value": method_name})
                
                for p_name, p_value in variant['galaxy_params'].items():
                    build_param_xml(meth_cond, p_name, p_value)
                
                output_elem = ET.SubElement(test_elem, "output", {"name": "config_out", "ftype": "txt"})
                assert_contents = ET.SubElement(output_elem, "assert_contents")
                params_to_check = variant['saqc_call_params']
                
                field_val = params_to_check.get('field', params_to_check.get('target'))
                field_name = field_val if not isinstance(field_val, list) else (field_val[0] if field_val else "test_variable")

                field_regex_part = re.escape(str(field_name))
                
                lookaheads = []
                
                if variant['description'].startswith('Test mit Defaults'):
                    full_regex = f"{field_regex_part};\\s*{method_name}\\(.*\\)"
                else:
                    match = re.search(r"Test-Variante für '([^']+)'.*", variant['description'])
                    if match:
                        varied_param_name = match.group(1)
                        if varied_param_name in params_to_check:
                            p_value = params_to_check[varied_param_name]
                            
                            if varied_param_name not in ['field', 'target']:
                                formatted_value = format_value_for_regex(p_value, varied_param_name)
                                lookaheads.append(f'(?=.*{varied_param_name}\\s*=\\s*{formatted_value})')
                    
                    if not lookaheads:
                         full_regex = f"{field_regex_part};\\s*{method_name}\\(.*\\)"
                    else:
                         full_regex = f"{field_regex_part};\\s*{method_name}\\({ ''.join(lookaheads)}.*\\)"
                
                ET.SubElement(assert_contents, "has_text_matching", {"expression": full_regex})

    try:
        ET.indent(macros_root, space="  ")
        sys.stdout.buffer.write(ET.tostring(macros_root, encoding='utf-8', xml_declaration=False))
        print("\n", file=sys.stderr)
        print("Successfully generated XML with the definitive hybrid strategy.", file=sys.stderr)
    except Exception as e:
        print(f"\nSerialization failed. Error: {e}", file=sys.stderr)

if __name__ == "__main__":
    main()



