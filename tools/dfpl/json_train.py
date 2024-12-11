import json
from sys import stdin

d = json.load(stdin)

d["py/object"] = "dfpl.options.Options"
d["outputDir"] = "./model/"
d["ecModelDir"] = "./autoencoder/"

# <select> tags provide string values -> parse to boolean
d["trainAC"] = bool(d["trainAC"] == "true")
d["compressFeatures"] = bool(d["compressFeatures"] == "true")

print(json.dumps(d))
