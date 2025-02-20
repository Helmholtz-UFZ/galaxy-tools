import json
from sys import stdin

d = json.load(stdin)

d["no_cache"] = bool(d["no_cache"] == True)
#wird dann data_path noch benötigt????
d["test_path"] = "test-data/smiles.csv" 

#Path to CSV file where predictions will be saved.
d["preds_path"] = "test-data/DMPNN_preds.csv" 

#Directory from which to load model checkpoints "(walks directory and ensembles all models that are found)" -> führt das zu problem? besser einfach weg lassen?

d["checkpoint_path"] = "test-data/dmpnn-random/fold_0/model_0/model.pt"


d["py/object"] = "dfpl.options.GnnOptions"

print(json.dumps(d))




