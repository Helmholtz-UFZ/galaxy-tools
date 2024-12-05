import json
from sys import stdin

d = json.load(stdin)

d["py/object"] = "dfpl.options.Options"
d["outputDir"] = "./model/"
d["ecModelDir"] = "./autoencoder/"
d["trainAC"] = bool(d["trainAC"] == "true")  # because this is actually a <select> tag that provides string values

print(json.dumps(d))
