import json
from sys import stdin

d = json.load(stdin)


def flatten(o: dict):
    d_flat = {}
    for key, value in o.items():
        if type(value) == dict:
            value = flatten(value)
            for k, v in value.items():
                d_flat[k] = v
        else:
            d_flat[key] = value
    return d_flat


d = flatten(d)

print(json.dumps(d))
