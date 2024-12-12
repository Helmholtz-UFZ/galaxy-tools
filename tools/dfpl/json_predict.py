import json
from sys import stdin

d = json.load(stdin)

# The directory where the full model of the fnn is loaded from.
d["fnnModelDir"] = ""  # 'dfpl predict' looks for "model_weights.h5" in this directory
del d["fnn_weights"]

d["compressFeatures"] = bool(d["compressFeatures"] == "true")

# The encoder file where it is loaded from, to compress the fingerprints.
d["ecModelDir"] = ""
d["ecWeightsFile"] = "encoder_weights.h5"

# Output csv file name which will contain one prediction per input line.
# Default: prefix of input file name.
d["outputFile"] = "predictions.csv"

d["py/object"] = "dfpl.options.Options"

print(json.dumps(d))
