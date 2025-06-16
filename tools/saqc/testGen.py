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


def get_modules() -> list[Tuple[str, "ModuleType"]]: return inspect.getmembers(saqc.funcs, inspect.ismodule)

def get_methods(module: "ModuleType") -> list[Callable]:
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
    param_info = {}
    try:
        parameters = inspect.signature(method).parameters
    except (ValueError, TypeError):
        return {}

    for name, param in parameters.items():
        if name in ["self", "kwargs", "store_kwargs", "ax_kwargs"]: continue
        annotation = param.annotation
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
    param_info = get_param_info(method)
    if not param_info: return []
    
    variants, base_params, complex_params_to_vary = [], {}, set()
    for name, info in param_info.items():
        default, origin, args = info['default'], info['origin'], info['args']
        if (origin is Literal and len(args) > 1) or (origin is Union and len(args) > 1):
            complex_params_to_vary.add(name)
        
        if default is not inspect.Parameter.empty:
            base_params[name] = default
        elif origin is Literal and args:
            base_params[name] = args[0]
        elif info['annotation'] == bool:
            base_params[name] = False
        elif info['annotation'] == int:
            base_params[name] = 0
        elif info['annotation'] == float:
            base_params[name] = 0.0
        elif name in ['field', 'target']:
            base_params[name] = "test_variable"
        else:
            base_params[name] = "default_string"
    
    variants.append({"description": "default values", "params": base_params})

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
            variant_params[name] = option
            variants.append({"description": f"param '{name}' as '{str(option)}'", "params": variant_params})

    final_variants = []
    for variant in variants:
        galaxy_params = {}
        saqc_call_params = {}
        
        for name, value in variant['params'].items():
            info = param_info.get(name, {})
            is_union_cond = info.get('origin') is Union and any(t in info.get('args', []) for t in [int, float]) and str in info.get('args', [])
            
            saqc_call_params[name] = value
            
            if name in ["field", "target"]:
                val_list = value if isinstance(value, list) else [value]
                galaxy_params[f"{name}_repeat"] = [{name: v} for v in val_list]
            elif is_union_cond:
                type_map = {int: 'number', float: 'number', str: 'timedelta'}
                val_type = type_map.get(type(value), 'offset')
                galaxy_params[f"{name}_cond"] = {f"{name}_select_type": val_type, name: value}
            else:
                galaxy_params[name] = value
                
        final_variants.append({
            "description": variant["description"],
            "galaxy_params": galaxy_params,
            "saqc_call_params": saqc_call_params
        })
    return final_variants

def build_param_xml(parent: ET.Element, name: str, value: Any, param_info: Dict[str, Any]):
    name_str = str(name)
    
    if name_str.endswith("_repeat") and isinstance(value, list):
        repeat = ET.SubElement(parent, "repeat", {"name": name_str})
        for item_dict in value:
            if isinstance(item_dict, dict):
                for sub_name, sub_value in item_dict.items():
                    build_param_xml(repeat, sub_name, sub_value, param_info) 
    elif name_str.endswith("_cond") and isinstance(value, dict):
        conditional = ET.SubElement(parent, "conditional", {"name": name_str})
        param_name_base = name_str.replace("_cond", "")
        selector_name = f"{param_name_base}_select_type"
        selector_value = value.get(selector_name)
        if selector_value is not None:
            ET.SubElement(conditional, "param", {"name": selector_name, "value": str(selector_value)})
            when = ET.SubElement(conditional, "when", {"value": str(selector_value)})
            build_param_xml(when, param_name_base, value.get(param_name_base), param_info)
    else:
        ET.SubElement(parent, "param", {"name": name_str, "value": str(value)})

def main():
    # Das <macros>-Tag als Wurzel bleibt erhalten.
    macros_root = ET.Element("macros")
    
    # KORREKTUR: Das Kind-Element wird zu <xml>, wie gewünscht.
    all_tests_macro = ET.SubElement(macros_root, "xml", {"name": "config_tests"})

    print("--- Starting Comprehensive Test Generation for SaQC ---", file=sys.stderr)
    modules = get_modules()

    for module_name, module_obj in modules:
        methods = get_methods(module_obj)
        for method_obj in methods:
            method_name = method_obj.__name__
            try:
                param_info = get_param_info(method_obj)
                test_variants = generate_test_variants(method_obj)
            except Exception as e:
                print(f"Error generating variants for {method_name}: {e}", file=sys.stderr)
                continue

            for i, variant in enumerate(test_variants):
                # Die Test-ID wird aus dem <test>-Tag entfernt, wie gewünscht.
                test_elem = ET.SubElement(all_tests_macro, "test")
                test_elem.append(ET.Comment(f" Test case for {module_name}.{method_name}, variant '{variant['description']}' "))

                ET.SubElement(test_elem, "param", {"name": "data", "value": "test1/data.csv", "ftype": "csv"})
                ET.SubElement(test_elem, "param", {"name": "run_test_mode", "value": "true"})

                repeat = ET.SubElement(test_elem, "repeat", {"name": "methods_repeat"})
                mod_cond = ET.SubElement(repeat, "conditional", {"name": "module_cond"})
                
                ET.SubElement(mod_cond, "param", {"name": "module_select", "value": module_name})
                mod_when = ET.SubElement(mod_cond, "when", {"value": module_name})
                meth_cond = ET.SubElement(mod_when, "conditional", {"name": "method_cond"})
                ET.SubElement(meth_cond, "param", {"name": "method_select", "value": method_name})
                meth_when = ET.SubElement(meth_cond, "when", {"value": method_name})
                
                for p_name, p_value in variant['galaxy_params'].items():
                    build_param_xml(meth_when, p_name, p_value, param_info)

                # Assertion-Block ohne "has_n_lines"
                output_elem = ET.SubElement(test_elem, "output", {"name": "config_out", "ftype": "txt"})
                assert_contents = ET.SubElement(output_elem, "assert_contents")
                
                params_to_check = variant['saqc_call_params']
                regex_parts = [method_name]
                for p_name, p_value in params_to_check.items():
                    escaped_value = re.escape(str(p_value))
                    regex_parts.append(f"{p_name}={escaped_value}")
                
                full_regex = ".*".join(regex_parts)
                ET.SubElement(assert_contents, "has_text_matching", {"expression": full_regex})

    try:
        ET.indent(macros_root, space="  ")
        # Ausgabe als UTF-8 Bytes, um eine saubere Datei zu gewährleisten
        sys.stdout.buffer.write(ET.tostring(macros_root, encoding='utf-8', xml_declaration=False))
        print("\n", file=sys.stderr) # Leerzeile für bessere Lesbarkeit im Terminal
        print("Successfully generated XML.", file=sys.stderr)
    except Exception as e:
        print(f"\nSerialization failed. Error: {e}", file=sys.stderr)


if __name__ == "__main__":
    main()