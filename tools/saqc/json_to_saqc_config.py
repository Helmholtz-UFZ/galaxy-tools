#!/usr/bin/env python

import json
import sys

print("DEBUG: Running json_to_saqc_config.py FINAL_FIX_V4", file=sys.stderr)
print("varname; function")

try:
    with open(sys.argv[1]) as fh:
        params_from_galaxy = json.load(fh)
except Exception as e:
    sys.stderr.write(f"Error reading JSON file: {e}\n")
    sys.exit(1)

for method_set in params_from_galaxy.get("methods_repeat", []):
    method = "unknown_method"
    field_str = "unknown_field"
    try:
        method_cond_params = method_set.get("module_cond", {}).get("method_cond", {})
        if not method_cond_params:
            continue

        params_to_process = method_cond_params.copy()
        method = params_to_process.pop("method_select", "unknown_method")
        
        # Feld extrahieren und sicherstellen, dass es einen Fallback gibt
        raw_field_val = params_to_process.pop("field", None)
        if raw_field_val is not None and raw_field_val != "":
            field_str = str(raw_field_val)
        else:
            field_repeat_data = params_to_process.pop("field_repeat", [])
            if field_repeat_data and isinstance(field_repeat_data, list) and field_repeat_data[0].get("field"):
                field_str = str(field_repeat_data[0]["field"])
            else: # Fallback, falls 'field' oder 'field_repeat' leer/nicht vorhanden ist
                field_str = params_to_process.pop("target", "unknown_field")


        saqc_args_dict = {}
        for key, value in params_to_process.items():
            
            actual_key = key
            actual_value = value
            if key.endswith("_cond") and isinstance(value, dict):
                actual_key = key[:-5]
                actual_value = next((v for k, v in value.items() if not k.endswith("_select_type")), None)
            
            # Lambda-Funktionen zuverlässig überspringen
            if isinstance(actual_value, str) and (actual_value.strip().startswith('<function') or actual_value.strip().startswith('__lt__function')):
                sys.stderr.write(f"Info for '{method}': Ignoring function parameter '{actual_key}'.\n")
                continue

            saqc_args_dict[actual_key] = actual_value
        
        # Parameter-Strings sauber mit repr() erstellen, um korrekte Anführungszeichen zu gewährleisten
        # Leere Strings werden jetzt korrekt als `''` dargestellt und nicht mehr entfernt.
        param_strings = [f"{k}={repr(v)}" for k, v in sorted(saqc_args_dict.items())]
        
        print(f"{field_str}; {method}({', '.join(param_strings)})", flush=True)

    except Exception as e:
        sys.stderr.write(f"FATAL Error processing method '{method}' for field '{field_str}': {type(e).__name__} {e}\n")
        import traceback
        traceback.print_exc(file=sys.stderr)
        continue