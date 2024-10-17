import json
import sys

input_json_path = sys.argv[1]
d = json.load(open(input_json_path, "r"))


def flatten(d: dict):
    d_flat = {}
    for key, value in d.items():
        if type(value) == dict:
            value = flatten(value)
            for k, v in value.items():
                d_flat[k] = v
        else:
            d_flat[key] = value
    return d_flat

d = flatten(d)

d["outputDir"] = "./output/"
d["py/object"] = "dfpl.options.Options"

d["ecModelDir"] = "autoencoder"  # The directory where the full encoder will be saved

print(json.dumps(d))
