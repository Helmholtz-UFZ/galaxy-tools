#!/usr/bin/env python

import json
import sys
import math


def format_saqc_value_repr(value: any) -> str:
    """
    Konvertiert einen Python-Wert in seine korrekte String-Darstellung für die SaQC-Konfiguration.
    Behandelt None, Bools, Floats (inkl. inf/nan) und Strings zentral.
    """
    if value is None:
        return "None"
    if isinstance(value, bool):
        return str(value)
    if isinstance(value, float):
        if math.isinf(value):
            return "float('inf')" if value > 0 else "float('-inf')"
        if math.isnan(value):
            return "float('nan')"
        return repr(value)
    if isinstance(value, int):
        return str(value)
    if isinstance(value, str):
        val_lower = value.lower()
        if val_lower == "inf":
            return "float('inf')"
        if val_lower == "-inf":
            return "float('-inf')"
        if val_lower == "nan":
            return "float('nan')"
        escaped_v = value.replace("\\", "\\\\").replace('"', '\\"')
        return f'"{escaped_v}"'
    sys.stderr.write(
        f"Warning: Unhandled type {type(value)}. Converting to string representation: '{str(value)}'.\n"
    )
    return repr(value)


print("varname; function")

try:
    infile = sys.argv[1]
    with open(infile) as fh:
        params_from_galaxy = json.load(fh)
except Exception as e:
    sys.stderr.write(
        f"Error opening or reading JSON file {infile}: {type(e).__name__} - {e}\n"
    )
    sys.exit(1)

EMPTY_STRING_IS_NONE_PARAMS = {
    "xscope",
    "yscope",
    "max_gap",
    "min_periods",
    "min_residuals",
    "min_offset",
}

for r_method_set in params_from_galaxy.get("methods_repeat", []):
    method_str_for_error = "unknown_method_in_repeat"
    field_str_for_error = "unknown_field_in_repeat"
    try:
        method_cond_params = r_method_set.get("module_cond", {}).get("method_cond", {})
        if not method_cond_params:
            sys.stderr.write(
                f"Warning: Skipping a methods_repeat entry due to missing/empty method_cond: {r_method_set}\n"
            )
            continue

        params_to_process = method_cond_params.copy()

        method = params_to_process.pop("method_select", "unknown_method")
        method_str_for_error = method

        raw_field_val = None
        if "field" in params_to_process:
            raw_field_val = params_to_process.pop("field")
        elif "field_repeat" in params_to_process:
            field_repeat_data = params_to_process.pop("field_repeat", [])
            if isinstance(field_repeat_data, list) and len(field_repeat_data) > 0:
                first_field_item = field_repeat_data[0]
                if isinstance(first_field_item, dict):
                    raw_field_val = first_field_item.get("field")

        if raw_field_val is None or str(raw_field_val).strip() == "":
            field_str = "undefined_field"
            field_str_for_error = "undefined_field (extraction failed or empty)"
            sys.stderr.write(
                f"Warning: Field name could not be determined for method '{method}'. Using '{field_str}'.\n"
            )
        else:
            field_str = str(raw_field_val) if not isinstance(raw_field_val, list) else ",".join(map(str, raw_field_val))
            field_str_for_error = field_str

        saqc_args_dict = {}
        for param_key, param_value_json in params_to_process.items():
            if param_key.endswith("_select_type"):
                continue

            actual_param_name_for_saqc = param_key
            current_value_for_saqc = param_value_json

            if isinstance(param_value_json, dict) and param_key.endswith("_cond"):
                actual_param_name_for_saqc = param_key[:-5]
                value_found = False
                for inner_k, inner_v in param_value_json.items():
                    if not inner_k.endswith("_select_type"):
                        current_value_for_saqc = inner_v
                        value_found = True
                        break
                if not value_found:
                    current_value_for_saqc = None

            if current_value_for_saqc == "__none__":
                saqc_args_dict[actual_param_name_for_saqc] = None
            elif isinstance(current_value_for_saqc, str) and not current_value_for_saqc and actual_param_name_for_saqc in EMPTY_STRING_IS_NONE_PARAMS:
                saqc_args_dict[actual_param_name_for_saqc] = None
            else:
                saqc_args_dict[actual_param_name_for_saqc] = current_value_for_saqc
        param_strings_for_saqc_call = [
            f"{k_saqc}={format_saqc_value_repr(v_saqc)}"
            for k_saqc, v_saqc in sorted(saqc_args_dict.items())
        ]

        print(
            f"{field_str}; {method}({', '.join(param_strings_for_saqc_call)})",
            flush=True,
        )

    except Exception as e:
        sys.stderr.write(
            f"FATAL Error processing a method entry in json_to_saqc_config.py: {r_method_set}\n"
        )
        sys.stderr.write(
            f"Method context: {method_str_for_error}, Field context: {field_str_for_error}\n"
        )
        import traceback
        traceback.print_exc(file=sys.stderr)
        print(
            f"{field_str_for_error}; ERROR_PROCESSING_METHOD({method_str_for_error})",
            flush=True,
        )
        continue