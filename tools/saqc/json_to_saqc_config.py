#!/usr/bin/env python

import json
import sys

infile = sys.argv[1]

with open(infile) as fh:
    params = json.load(fh)

for r in params["methods_repeat"]:
    r = r["module_cond"]["method_cond"]
    method = r["method_select"]
    del r["method_select"]
    field = r["field"]
    del r["field"]

    # flatten included dictionaries
    # which correspond to conditionals added by the tool
    for k, v in list(r.items()):
        if not (isinstance(v, dict) and k.endswith("_cond")):
            continue
        k_prefix = k[:-5]
        for s in v:
            if s == f"{k_prefix}_select":
                continue
            r[s] = v[s]
        del r[k]

    # quote string parameters
    for k, v in list(r.items()):
        if isinstance(v, str):
            r[k] = f'"{v}"'


    if isinstance(field, list):
        print(f"{','.join(field)}; ", end="")
    else:
        print(f"{field}; ", end="")
    print(f"{method}(", end="")
    print(', '.join([f"{p[0]}={p[1]}" for p in r.items()]), end="")
    print(")", )


