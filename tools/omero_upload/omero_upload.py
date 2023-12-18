import argparse
import omero
from omero.rtypes import rdouble, rint, rstring
import ezomero
import os
import pandas as pd
from omero.gateway import BlitzGateway
from datetime import datetime

now = datetime.now() # current date and time
date_time = now.strftime("%m/%d/%Y, %H:%M:%S")

parser = argparse.ArgumentParser(
                    prog='ProgramName',
                    description='What the program does',
                    epilog='Text at the bottom of help')

parser.add_argument("--url", required=True, type=str, help="")
parser.add_argument("--port", required=True, type=int, help="")
parser.add_argument("--username", required=True, type=str, help="")
parser.add_argument("--password", required=True, type=str, help="")
parser.add_argument("--folder", required=True, type=str, help="")

args = parser.parse_args()

print(args.url)

conn = BlitzGateway(arg.username , arg.password , host= arg.url, port= arg.port, secure= True)
constatus = str(conn.connect())

tb_input = knio.input_tables[0].to_pandas()
list = tb_input.values.tolist()
dict = dict(list)

# create a dataset to import into the dataset
dataset_obj = omero.model.DatasetI()
dataset_obj.setName(rstring(date_time))
dataset_obj = conn.getUpdateService().saveAndReturnObject(dataset_obj, conn.SERVICE_OPTS)
dataset_id = dataset_obj.getId().getValue()
dataset_id_str = str(dataset_id)

list_img = os.listdir(path)

for image_name in list:
    image_path = os.path.join(path, image_name)
    ezomero.ezimport(conn, image_path, dataset=dataset_id, ann=dict, ns="VAST Metadata")
    image_transferred += 1

image_transferred = str(image_transferred)
df = pd.DataFrame({
    'Output': ['Connecton Status', 'Image Import', 'Dataset Name'. 'Numbe of Images Transferred"],
    'constatus': [constatus, "Import Completed", dataset_id_str, image_transferred],
})

conn.close()