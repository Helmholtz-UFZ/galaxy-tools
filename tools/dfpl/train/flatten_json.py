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

d["py/object"] = "dfpl.options.Options"
d["outputDir"] = "./output/"
d["ecModelDir"] = "autoencoder"  # The directory where the full encoder will be saved
del d["use_autoencoder"]
d["trainAC"] = bool(d["trainAC"] == "true")  # because this is actually a <select> tag that provides string values

print(json.dumps(d))
