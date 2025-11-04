#!/usr/bin/env python

import json
import math
import sys
import traceback
import numpy as np


def translateColumn(inputData: str, index: int):
    try:
        collumns = open(inputData, "r").readline()
        array = np.array(collumns.strip().split(','))
        return array[index]
    except:
        sys.stderr.write("Could not find dataset")

print("varname; function")

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
    sys.stderr.write("FATAL: Dem Skript wurde kein zweites Argument (der Dateipfad) übergeben.\n")
    sys.exit(2)

if not primary_input_file:
    sys.stderr.write("FATAL: Konnte Eingabedatei-Pfad nicht aus sys.argv[2] lesen.\n")
    sys.exit(2)
    
sys.stderr.write(f"INFO: Verwende Dateipfad für Spaltennamen: {primary_input_file}\n")

for r_method_set in params_from_galaxy.get("methods_repeat", []):
    method_str_for_error = "unknown_method_in_repeat"
    field_str_for_error = "unknown_field_in_repeat"
    try:
        method_cond_params = r_method_set.get("module_cond", {}).get("method_cond", {})
        if not method_cond_params:
            sys.stderr.write(f"Warning: Skipping a methods_repeat entry due to missing/empty method_cond: {r_method_set}\n")
            continue

        params_to_process = method_cond_params.copy()
        method = params_to_process.pop("method_select", "unknown_method")
        method_str_for_error = method
        raw_field_val = None
        field_str = "undefined_field"

        if "field" in params_to_process:
            raw_field_val = params_to_process.pop("field")
        elif "target" in params_to_process:
            raw_field_val = params_to_process.pop("target")

        if raw_field_val is None:
            field_str = "no_field_applicable"
            field_str_for_error = field_str
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
                sys.stderr.write(f"FATAL: translateColumn failed for method '{method}' with index '{raw_field_val}'. Error: {e}\n")
                traceback.print_exc(file=sys.stderr)
                field_str = f"ERROR_CONVERSION_FAILED_{raw_field_val}"
                
            field_str_for_error = field_str

        saqc_args_dict = {}

        for param_key, param_value_json in params_to_process.items():
            if param_key.endswith("_selector"):
                continue

            actual_param_name_for_saqc = param_key
            current_value_for_saqc = param_value_json

            if isinstance(param_value_json, dict) and param_key.endswith("_cond"):
                actual_param_name_for_saqc = param_key[:-5]
                inner_params = param_value_json.copy()
                inner_params.pop(f"{actual_param_name_for_saqc}_selector", None)

                if len(inner_params) == 1:
                    current_value_for_saqc = list(inner_params.values())[0]
                else:
                    if f"{actual_param_name_for_saqc}_start" in inner_params:
                        start = inner_params.get(f"{actual_param_name_for_saqc}_start")
                        end = inner_params.get(f"{actual_param_name_for_saqc}_end")
                        current_value_for_saqc = f"slice({start}, {end})"
                    elif f"{actual_param_name_for_saqc}_min" in inner_params:
                        min_val = inner_params.get(f"{actual_param_name_for_saqc}_min")
                        max_val = inner_params.get(f"{actual_param_name_for_saqc}_max")
                        current_value_for_saqc = f"({min_val}, {max_val})"
                    else:
                        current_value_for_saqc = None

            if isinstance(current_value_for_saqc, list) and not current_value_for_saqc:
                continue

            if current_value_for_saqc == "__none__":
                saqc_args_dict[actual_param_name_for_saqc] = None
            elif isinstance(current_value_for_saqc, str) and current_value_for_saqc == "" and actual_param_name_for_saqc in ["xscope", "yscope", "max_gap", "min_periods", "min_residuals", "min_offset"]:
                saqc_args_dict[actual_param_name_for_saqc] = None
            else:
                saqc_args_dict[actual_param_name_for_saqc] = current_value_for_saqc

        param_strings_for_saqc_call = []
        for k_saqc, v_saqc_raw in sorted(saqc_args_dict.items()):
            v_str_repr = ""
            if v_saqc_raw is None:
                v_str_repr = "None"
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

                    if f"{k_saqc}_pos0" in inner_dict:
                        pos0_val_raw = inner_dict.get(f"{k_saqc}_pos0")
                        pos1_val_raw = inner_dict.get(f"{k_saqc}_pos1")

                        def format_val(val):
                            if val is None: return "None"
                            if isinstance(val, str):
                                if val.startswith("'") and val.endswith("'"): return val
                                if val.lower() in ['np.mean', 'np.min', 'np.max', 'np.std']: return val
                                return f'"{val}"'
                            if isinstance(val, (int, float)): return str(val)
                            return repr(val)
                        v_str_repr = f"({format_val(pos0_val_raw)}, {format_val(pos1_val_raw)})"

                    elif 'key' in inner_dict:
                        dict_items = [f'"{i["key"]}": "{i["value"]}"' for i in v_saqc_raw]
                        v_str_repr = f"{{{', '.join(dict_items)}}}"
                    
                    else:
                        v_str_repr = f"[{', '.join(map(str, v_saqc_raw))}]"

                else:
                    formatted_list_items = []
                    for item in v_saqc_raw:
                        if isinstance(item, str):
                            formatted_list_items.append(f'"{item}"')
                        else:
                            formatted_list_items.append(str(item))
                    v_str_repr = f"[{', '.join(formatted_list_items)}]"

            else:
                sys.stderr.write(f"Warning: Param '{k_saqc}' for method '{method}' has unhandled type {type(v_saqc_raw)}. Converting to string representation: '{str(v_saqc_raw)}'.\n")
                v_str_repr = repr(v_saqc_raw)

            param_strings_for_saqc_call.append(f"{k_saqc}={v_str_repr}")

        module_name = r_method_set.get("module_cond", {}).get("module_select", "unknown_module")

        print(f"{field_str}; {method}({', '.join(param_strings_for_saqc_call)})", flush=True)

    except Exception as e:
        sys.stderr.write(f"FATAL Error processing a method entry in json_to_saqc_config.py: {type(e).__name__}\n")
        sys.stderr.write(f"Method context: {method_str_for_error}, Field context: {field_str_for_error}\n")
        import traceback
        traceback.print_exc(file=sys.stderr)
        print(f"{field_str_for_error}; ERROR_PROCESSING_METHOD({method_str_for_error})", flush=True)
        continue
