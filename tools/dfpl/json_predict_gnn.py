import json
from sys import stdin

d = json.load(stdin)

#d["no_cache"] = bool(d["no_cache"] == True)
#d["no_cuda"] = bool(d["no_cuda"] == True)

#d["num_workers"] = 1 #sys.env.get("GALAXY_SLOTS", "1")  

#hier hardgecoded oder input dateien frei wählbar
#d["test_path"] = "smiles.csv" 

#Path to CSV file where predictions will be saved.
d["preds_path"] = "DMPNN_preds.csv" 

#Directory from which to load model checkpoints "(walks directory and ensembles all models that are found)" -> führt das zu problem? besser einfach weg lassen?



d["py/object"] = "dfpl.options.GnnOptions"

print(json.dumps(d))




