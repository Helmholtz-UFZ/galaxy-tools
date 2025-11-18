#!/usr/bin/env python

import json
import math
import sys
import traceback
from typing import Any, Dict, List, Tuple, Optional

import numpy as np


def translateColumn(inputData: str, index: int) -> str:
    """
    Reads a CSV header and returns the column name for a given index.
    """
    try:
        with open(inputData, "r") as f:
            columns = f.readline()
            array = np.array(columns.strip().split(','))
            return array[index]
    except Exception as e:
        print(f"Could not open dataset '{inputData}' to read header. Error: {e}", file=sys.stderr)
        raise


def load_inputs() -> Tuple[Dict[str, Any], str]:
    """
    Loads JSON params and data file path from sys.argv. Exits on error.
    
    Returns:
        Tuple[Dict[str, Any], str]: (params_from_galaxy, primary_input_file)
    """
    try:
        infile = sys.argv[1]
        with open(infile) as fh:
            params_from_galaxy = json.load(fh)
    except Exception as e:
        sys.stderr.write(f"Error opening or reading JSON file {infile}: {type(e).__name__} - {e}\n")
        sys.exit(1)

    primary_input_file = None
    try:
        primary_input_file = sys.argv[2]
    except IndexError:
        sys.stderr.write("FATAL: No second argument handed to the script (data path).\n")
        sys.exit(2)

    if not primary_input_file:
        sys.stderr.write("FATAL: could not read input data path sys.argv[2] .\n")
        sys.exit(2)
    
    return params_from_galaxy, primary_input_file


def process_main_column(params_to_process: Dict[str, Any], primary_input_file: str, method_name: str) -> Tuple[str, Dict[str, Any]]:
    """
    Finds, translates, and removes the main column ('field' or 'target').

    Args:
        params_to_process: The parameter dictionary for this method.
        primary_input_file: Path to the data file for column translation.
        method_name: The current method name (for error logging).

    Returns:
        Tuple[str, Dict[str, Any]]: (field_str, remaining_params)
    """
    raw_field_val = None
    field_str = "undefined_field"

    if "field" in params_to_process:
        raw_field_val = params_to_process.pop("field")
    elif "target" in params_to_process:
        raw_field_val = params_to_process.pop("target")

    if raw_field_val is None:
        field_str = "no_field_applicable"
    else:
        try:
            indices_from_galaxy = []
            if isinstance(raw_field_val, list):
                indices_from_galaxy = raw_field_val
            else:
                indices_from_galaxy = [raw_field_val]

            column_names = []
            for index_str in indices_from_galaxy:
                index_int = int(index_str)
                name = translateColumn(primary_input_file, index_int)
                column_names.append(name)
            field_str = ','.join(column_names)

        except Exception as e:
            sys.stderr.write(f"FATAL: translateColumn failed for MAIN column of method '{method_name}' with index '{raw_field_val}'. Error: {e}\n")
            traceback.print_exc(file=sys.stderr)
            field_str = f"ERROR_CONVERSION_FAILED_{raw_field_val}"

    return field_str, params_to_process


def process_parameters(params_to_process: Dict[str, Any], primary_input_file: str) -> Dict[str, Any]:
    """
    Processes remaining params: resolves conditionals, translates secondary
    columns (like 'target' or '*field*'), and handles 'None' values.
    """
    saqc_args_dict = {}
    
    for param_key, param_value_json in params_to_process.items():
        if param_key.endswith("_selector"):
            continue

        actual_param_name_for_saqc = param_key
        current_value_for_saqc = param_value_json

        # Resolve conditionals (e.g., `param_cond`)
        if isinstance(param_value_json, dict) and param_key.endswith("_cond"):
            actual_param_name_for_saqc = param_key[:-5]
            inner_params = param_value_json.copy()
            inner_params.pop(f"{actual_param_name_for_saqc}_selector", None)

            if len(inner_params) == 1:
                current_value_for_saqc = list(inner_params.values())[0]
            else:
                # Handle special tuples/slices
                if f"{actual_param_name_for_saqc}_start" in inner_params:
                    start = inner_params.get(f"{actual_param_name_for_saqc}_start")
                    end = inner_params.get(f"{actual_param_name_for_saqc}_end")
                    current_value_for_saqc = f"slice({start}, {end})" if start is not None or end is not None else None
                elif f"{actual_param_name_for_saqc}_min" in inner_params:
                    min_val = inner_params.get(f"{actual_param_name_for_saqc}_min")
                    max_val = inner_params.get(f"{actual_param_name_for_saqc}_max")
                    current_value_for_saqc = f"({min_val}, {max_val})" if min_val is not None or max_val is not None else None
                else:
                    current_value_for_saqc = None

        # Skip empty lists
        if isinstance(current_value_for_saqc, list) and not current_value_for_saqc:
            continue
        
        # Handle 'None' values
        if current_value_for_saqc == "__none__":
            saqc_args_dict[actual_param_name_for_saqc] = None
        elif isinstance(current_value_for_saqc, str) and current_value_for_saqc == "" and actual_param_name_for_saqc in ["xscope", "yscope", "max_gap", "min_periods", "min_residuals", "min_offset"]:
            saqc_args_dict[actual_param_name_for_saqc] = None
        
        # Translate secondary column params
        elif "field" in actual_param_name_for_saqc.lower() or actual_param_name_for_saqc == "target":
            try:
                indices_from_galaxy = []
                if isinstance(current_value_for_saqc, list):
                    indices_from_galaxy = current_value_for_saqc
                else:
                    indices_from_galaxy = [current_value_for_saqc]
                
                column_names = []
                for index_str in indices_from_galaxy:
                    index_int = int(index_str)
                    name = translateColumn(primary_input_file, index_int)
                    column_names.append(name)

                if isinstance(current_value_for_saqc, list):
                    saqc_args_dict[actual_param_name_for_saqc] = column_names
                else:
                    saqc_args_dict[actual_param_name_for_saqc] = column_names[0]
            
            except Exception as e:
                sys.stderr.write(f"FATAL: translateColumn failed for PARAMETER '{actual_param_name_for_saqc}' with index '{current_value_for_saqc}'. Error: {e}\n")
                traceback.print_exc(file=sys.stderr)
                saqc_args_dict[actual_param_name_for_saqc] = f"ERROR_CONVERSION_FAILED_{current_value_for_saqc}"
        
        # Add normal parameter
        else:
            saqc_args_dict[actual_param_name_for_saqc] = current_value_for_saqc
            
    return saqc_args_dict


def format_saqc_value(v_saqc_raw: Any, k_saqc: str) -> Optional[str]:
    """
    Formats a Python value into a SaQC-compatible string.
    
    Handles 'inf', 'nan', bools, lists, and Galaxy-specific dicts
    (tuples, key-value repeats). Returns None if the param should be skipped.

    Args:
        v_saqc_raw: The raw Python value (e.g., True, 1.0, "inf").
        k_saqc: The parameter name (needed for 'func' logic).
        
    Returns:
        Optional[str]: The formatted string (e.g., "True", '["a", "b"]').
    """
    v_str_repr = ""
    
    if v_saqc_raw is None:
        return None

    elif isinstance(v_saqc_raw, bool):
        v_str_repr = "True" if v_saqc_raw else "False"
    
    elif isinstance(v_saqc_raw, (float, int)):
        if v_saqc_raw == float('inf'):
            v_str_repr = "float('inf')"
        elif v_saqc_raw == float('-inf'):
            v_str_repr = "float('-inf')"
        elif isinstance(v_saqc_raw, float) and math.isnan(v_saqc_raw):
            v_str_repr = "float('nan')"
        else:
            v_str_repr = repr(v_saqc_raw)
    
    elif isinstance(v_saqc_raw, str):
        val_lower = v_saqc_raw.lower()
        if val_lower == "inf":
            v_str_repr = "float('inf')"
        elif val_lower == "-inf":
            v_str_repr = "float('-inf')"
        elif val_lower == "nan":
            v_str_repr = "float('nan')"
        elif "func" in k_saqc.lower():
            v_str_repr = v_saqc_raw
        elif v_saqc_raw.startswith(('slice(', '(', '[', "'", '"')):
            v_str_repr = v_saqc_raw
        else:
            escaped_v = v_saqc_raw.replace('\\', '\\\\').replace('"', '\\"')
            v_str_repr = f'"{escaped_v}"'
            
    elif isinstance(v_saqc_raw, list):
        if v_saqc_raw and isinstance(v_saqc_raw[0], dict):
            inner_dict = v_saqc_raw[0]
            # Galaxy tuple repeat
            if f"{k_saqc}_pos0" in inner_dict:
                pos0_val_raw = inner_dict.get(f"{k_saqc}_pos0")
                pos1_val_raw = inner_dict.get(f"{k_saqc}_pos1")

                def format_tuple_val(val):
                    if val is None: return "None"
                    if isinstance(val, str):
                        if val.startswith("'") and val.endswith("'"): return val
                        if val.lower() in ['np.mean', 'np.min', 'np.max', 'np.std']: return val
                        return f'"{val}"'
                    if isinstance(val, (int, float)): return str(val)
                    return repr(val)
                
                v_str_repr = f"({format_tuple_val(pos0_val_raw)}, {format_tuple_val(pos1_val_raw)})"
            # Galaxy dict repeat
            elif 'key' in inner_dict:
                dict_items = [f'"{i["key"]}": "{i["value"]}"' for i in v_saqc_raw]
                v_str_repr = f"{{{', '.join(dict_items)}}}"
                
            else: # Fallback for unknown dict list
                v_str_repr = f"[{', '.join(map(str, v_saqc_raw))}]"
        
        else:  # Normal list (e.g., from "multiple: True" text/select)
            formatted_list_items = []
            for item in v_saqc_raw:
                if isinstance(item, str):
                    formatted_list_items.append(f'"{item}"')
                else:
                    formatted_list_items.append(str(item))
            v_str_repr = f"[{', '.join(formatted_list_items)}]"
            
    else:
        sys.stderr.write(f"Warning: Param '{k_saqc}' has unhandled type {type(v_saqc_raw)}. Converting to string representation: '{str(v_saqc_raw)}'.\n")
        v_str_repr = repr(v_saqc_raw)
        
    return v_str_repr


def main():
    """
    Main script execution logic.
    """
    print("varname; function")
    
    try:
        params_from_galaxy, primary_input_file = load_inputs()
    except SystemExit:
        return

    sys.stderr.write(f"INFO: Use data path as column name: {primary_input_file}\n")

    for r_method_set in params_from_galaxy.get("methods_repeat", []):
        method_str_for_error = "unknown_method_in_repeat"
        field_str_for_error = "unknown_field_in_repeat"

        try:
            # Extract method and parameters
            method_cond_params = r_method_set.get("module_cond", {}).get("method_cond", {})
            if not method_cond_params:
                sys.stderr.write(f"Warning: Skipping a methods_repeat entry due to missing/empty method_cond: {r_method_set}\n")
                continue

            params_to_process = method_cond_params.copy()
            method = params_to_process.pop("method_select", "unknown_method")
            method_str_for_error = method

            # Process the main column
            field_str, params_to_process = process_main_column(params_to_process, primary_input_file, method)
            field_str_for_error = field_str

            # Process remaining parameters (incl. secondary columns)
            saqc_args_dict = process_parameters(params_to_process, primary_input_file)

            # Format parameter strings for SaQC
            param_strings_for_saqc_call = []
            for k_saqc, v_saqc_raw in sorted(saqc_args_dict.items()):
                v_str_repr = format_saqc_value(v_saqc_raw, k_saqc)
                if v_str_repr is not None:
                    param_strings_for_saqc_call.append(f"{k_saqc}={v_str_repr}")

            # Print final config line
            print(f"{field_str}; {method}({', '.join(param_strings_for_saqc_call)})", flush=True)

        except Exception as e:
            sys.stderr.write(f"FATAL Error processing a method entry in json_to_saqc_config.py: {type(e).__name__}\n")
            sys.stderr.write(f"Method context: {method_str_for_error}, Field context: {field_str_for_error}\n")
            traceback.print_exc(file=sys.stderr)
            print(f"{field_str_for_error}; ERROR_PROCESSING_METHOD({method_str_for_error})", flush=True)
            continue

if __name__ == "__main__":
    main()