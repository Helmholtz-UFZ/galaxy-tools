#!/usr/bin/env python

import json
import sys
import math

print("DEBUG: Running json_to_saqc_config.py VERSION_JUNE_2_2025_V5", file=sys.stderr)
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
        # Hole das method_cond Dictionary, das alle Parameter für die Methode enthält
        method_cond_params = r_method_set.get("module_cond", {}).get("method_cond", {})
        if not method_cond_params:
            sys.stderr.write(f"Warning: Skipping a methods_repeat entry due to missing/empty method_cond: {r_method_set}\n")
            continue

        # Erstelle eine Kopie, um Pop-Operationen sicher durchzuführen
        params_to_process = method_cond_params.copy()

        method = params_to_process.pop("method_select", "unknown_method")
        method_str_for_error = method
        
        raw_field_val = params_to_process.pop("field", "undefined_field")
        field_str_for_error = str(raw_field_val)
        field_str = ','.join(map(str, raw_field_val)) if isinstance(raw_field_val, list) else str(raw_field_val)

        saqc_args_dict = {}

        for param_key, param_value_json in params_to_process.items():
            # Überspringe interne Galaxy-Selektoren, die nicht an saqc gehen sollen
            if param_key.endswith("_select_type"):
                continue

            actual_param_name_for_saqc = param_key
            current_value_for_saqc = param_value_json

            # Wenn der Parameter selbst ein Konditional-Block ist (z.B. window_cond)
            if isinstance(param_value_json, dict) and param_key.endswith("_cond"):
                actual_param_name_for_saqc = param_key[:-5] # z.B. "window" aus "window_cond"
                
                # Finde den eigentlichen Wert innerhalb des Konditional-Dicts
                # Der Schlüssel für den Wert ist normalerweise der `actual_param_name_for_saqc`
                # oder der einzige andere Schlüssel neben dem `_select_type`
                found_val_in_cond = False
                for inner_k, inner_v in param_value_json.items():
                    if not inner_k.endswith("_select_type"):
                        current_value_for_saqc = inner_v
                        found_val_in_cond = True
                        break
                if not found_val_in_cond:
                    sys.stderr.write(f"Warning: Could not extract value from conditional block '{param_key}' for method '{method}'. Using None.\n")
                    current_value_for_saqc = None
            
            # Konvertiere spezielle Galaxy-Werte oder leere Strings zu Python None
            if current_value_for_saqc == "__none__":
                saqc_args_dict[actual_param_name_for_saqc] = None
            elif isinstance(current_value_for_saqc, str) and current_value_for_saqc == "":
                # Speziell für Parameter, bei denen "" (aus JSON) -> None bedeuten soll
                # (z.B. xscope, yscope, max_gap für plot; min_periods, min_residuals für flagMAD)
                saqc_args_dict[actual_param_name_for_saqc] = None
            else:
                saqc_args_dict[actual_param_name_for_saqc] = current_value_for_saqc
        
        # Baue den Parameter-String für den saqc-Aufruf
        param_strings_for_saqc_call = []
        for k_saqc, v_saqc_raw in sorted(saqc_args_dict.items()):
            v_str_repr = ""
            if v_saqc_raw is None:
                v_str_repr = "None"
            elif isinstance(v_saqc_raw, bool): # Sollte boolesches False korrekt als "False" behandeln
                v_str_repr = "True" if v_saqc_raw else "False"
            elif isinstance(v_saqc_raw, float):
                if v_saqc_raw == float('inf'): v_str_repr = "float('inf')"
                elif v_saqc_raw == float('-inf'): v_str_repr = "float('-inf')"
                elif math.isnan(v_saqc_raw): v_str_repr = "float('nan')"
                else: v_str_repr = repr(v_saqc_raw)
            elif isinstance(v_saqc_raw, int):
                v_str_repr = str(v_saqc_raw)
            elif isinstance(v_saqc_raw, str):
                # Leere Strings sollten oben bereits zu None konvertiert worden sein,
                # aber zur Sicherheit hier nochmals prüfen, falls ein "" durchgerutscht ist
                if not v_saqc_raw: 
                    v_str_repr = "None"
                else:
                    val_lower = v_saqc_raw.lower()
                    if val_lower == "inf": v_str_repr = "float('inf')"
                    elif val_lower == "-inf": v_str_repr = "float('-inf')"
                    elif val_lower == "nan": v_str_repr = "float('nan')"
                    else:
                        escaped_v = v_saqc_raw.replace('\\', '\\\\').replace('"', '\\"')
                        v_str_repr = f'"{escaped_v}"'
            else:
                sys.stderr.write(f"Warning: Param '{k_saqc}' for method '{method}' has unhandled type {type(v_saqc_raw)}. Converting to string.\n")
                escaped_v = str(v_saqc_raw).replace('\\', '\\\\').replace('"', '\\"')
                v_str_repr = f'"{escaped_v}"'
            param_strings_for_saqc_call.append(f"{k_saqc}={v_str_repr}")

        print(f"{field_str}; {method}({', '.join(param_strings_for_saqc_call)})", flush=True)

    except Exception as e:
        sys.stderr.write(f"FATAL Error processing a method entry in json_to_saqc_config.py: {r_method_set}\n")
        sys.stderr.write(f"Method context: {method_str_for_error}, Field context: {field_str_for_error}\n")
        import traceback
        traceback.print_exc(file=sys.stderr)
        print(f"{field_str_for_error if 'field_str_for_error' in locals() else 'unknown_field'}; ERROR_PROCESSING_METHOD({method_str_for_error if 'method_str_for_error' in locals() else 'unknown_method'})", flush=True)
        continue