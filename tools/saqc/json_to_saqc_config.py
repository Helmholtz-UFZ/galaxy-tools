#!/usr/bin/env python

import json
import sys
import math


print("varname; function")

try:
    infile = sys.argv[1]
    with open(infile) as fh:
        params_from_galaxy = json.load(fh)
except Exception as e:
    sys.stderr.write(f"Error opening or reading JSON file {infile}: {type(e).__name__} - {e}\n")
    sys.exit(1)

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
        
        # *** ANFANG DER MODIFIKATION FÜR FIELD EXTRACTION ***
        raw_field_val = None
        field_str = "undefined_field" # Fallback

        if "field" in params_to_process:
            raw_field_val = params_to_process.pop("field")
        elif "field_repeat" in params_to_process:
            field_repeat_data = params_to_process.pop("field_repeat") 
            if isinstance(field_repeat_data, list) and len(field_repeat_data) > 0:
                first_field_item = field_repeat_data[0] 
                if isinstance(first_field_item, dict) and "field" in first_field_item:
                    raw_field_val = first_field_item.get("field")
                else:
                    sys.stderr.write(f"Warning: 'field_repeat' item is not a dict with a 'field' key for method '{method}'. Item: {first_field_item}\n")
            else:
                sys.stderr.write(f"Warning: 'field_repeat' is not a list or is empty for method '{method}'. Value: {field_repeat_data}\n")
        
        if raw_field_val is None or str(raw_field_val).strip() == "": # Wenn kein Feld gefunden oder Feld ist leer
            field_str = "undefined_field"
            field_str_for_error = "undefined_field (extraction failed or empty)"
            sys.stderr.write(f"Warning: Field name could not be determined for method '{method}'. Using '{field_str}'.\n")
        else:
            
            if isinstance(raw_field_val, list):
                field_str = ','.join(map(str, raw_field_val))
            else:
                field_str = str(raw_field_val)
            field_str_for_error = field_str
        

        saqc_args_dict = {}

        for param_key, param_value_json in params_to_process.items():
            if param_key.endswith("_select_type"): 
                continue

            actual_param_name_for_saqc = param_key
            current_value_for_saqc = param_value_json

            if isinstance(param_value_json, dict) and param_key.endswith("_cond"):
                actual_param_name_for_saqc = param_key[:-5] 
                found_val_in_cond = False
                for inner_k, inner_v in param_value_json.items():
                    if not inner_k.endswith("_select_type"):
                        current_value_for_saqc = inner_v
                        found_val_in_cond = True
                        break
                if not found_val_in_cond:
                    sys.stderr.write(f"Warning: Could not extract value from conditional block '{param_key}' for method '{method}'. Using None.\n")
                    current_value_for_saqc = None
            
            if current_value_for_saqc == "__none__":
                saqc_args_dict[actual_param_name_for_saqc] = None
            elif isinstance(current_value_for_saqc, str) and current_value_for_saqc == "" and \
                 actual_param_name_for_saqc in ["xscope", "yscope", "max_gap", "min_periods", "min_residuals", "min_offset"]: # Explizite Liste für "" -> None
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
            elif isinstance(v_saqc_raw, float):
                if v_saqc_raw == float('inf'): v_str_repr = "float('inf')"
                elif v_saqc_raw == float('-inf'): v_str_repr = "float('-inf')"
                elif math.isnan(v_saqc_raw): v_str_repr = "float('nan')"
                else: v_str_repr = repr(v_saqc_raw) # Stellt sicher, dass z.B. 10.0 als '10.0' dargestellt wird
            elif isinstance(v_saqc_raw, int):
                v_str_repr = str(v_saqc_raw)
            elif isinstance(v_saqc_raw, str):
                if not v_saqc_raw and k_saqc not in ["xscope", "yscope", "max_gap", "min_periods", "min_residuals", "min_offset"]: # Wenn "" und nicht Spezialfall, als "" String
                    
                    if val_lower == "inf": v_str_repr = "float('inf')"
                    elif val_lower == "-inf": v_str_repr = "float('-inf')"
                    elif val_lower == "nan": v_str_repr = "float('nan')"
                    else: # Auch für leere Strings, die nicht None werden sollen
                        escaped_v = v_saqc_raw.replace('\\', '\\\\').replace('"', '\\"')
                        v_str_repr = f'"{escaped_v}"'
                else: # Nicht-leerer String oder leerer String für Spezialparameter (der schon None ist)
                    val_lower = v_saqc_raw.lower()
                    if val_lower == "inf": v_str_repr = "float('inf')"
                    elif val_lower == "-inf": v_str_repr = "float('-inf')"
                    elif val_lower == "nan": v_str_repr = "float('nan')"
                    else:
                        escaped_v = v_saqc_raw.replace('\\', '\\\\').replace('"', '\\"')
                        v_str_repr = f'"{escaped_v}"'
            else:
                sys.stderr.write(f"Warning: Param '{k_saqc}' for method '{method}' has unhandled type {type(v_saqc_raw)}. Converting to string representation: '{str(v_saqc_raw)}'.\n")
                # Fallback: Versuche, es als String darzustellen, ggf. in Anführungszeichen, wenn es keine Zahl/Bool/None ist
                v_str_repr = repr(v_saqc_raw)


            param_strings_for_saqc_call.append(f"{k_saqc}={v_str_repr}")

        print(f"{field_str}; {method}({', '.join(param_strings_for_saqc_call)})", flush=True)

    except Exception as e:
        sys.stderr.write(f"FATAL Error processing a method entry in json_to_saqc_config.py: {r_method_set}\n")
        sys.stderr.write(f"Method context: {method_str_for_error}, Field context: {field_str_for_error}\n") # field_str_for_error verwenden
        import traceback
        traceback.print_exc(file=sys.stderr)
        print(f"{field_str_for_error}; ERROR_PROCESSING_METHOD({method_str_for_error})", flush=True) # field_str_for_error verwenden
        continue