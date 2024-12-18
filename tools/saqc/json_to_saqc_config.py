#!/usr/bin/env python

import json
import sys

infile = sys.argv[1]

with open(infile) as fh:
    params = json.load(fh)

# print header (important: SaQC ignores the 1st line)
print("varname; function")

for r in params["methods_repeat"]:
    r = r["module_cond"]["method_cond"]
    method = r["method_select"]
    del r["method_select"]
    field = r["field"]
    del r["field"]

    items = []
    # flatten included dictionaries
    # which correspond to conditionals added by the tool
    for k, v in list(r.items()):
        if isinstance(v, dict) and k.endswith("_cond"):
            k_prefix = k[:-5]
            for s in v:
                if s == f"{k_prefix}_select":
                    continue
                if v[s] == "__none__":
                    v[s] = None
                items.append((s, v[s]))
                r[s] = v[s]
            del r[k]
        else:
            items.append((k, v))

    # quote string parameters
    for i, item in enumerate(items):
        if isinstance(item[1], str):
            items[i] = (item[0], f'"{item[1]}"')

    if isinstance(field, list):
        print(f"{','.join(field)}; ", end="")
    else:
        print(f"{field}; ", end="")
    print(f"{method}(", end="")
    print(', '.join([f"{p[0]}={p[1]}" for p in items]), end="")
    print(")", )
