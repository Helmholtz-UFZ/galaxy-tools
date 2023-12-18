import omero
from omero.rtypes import rstring
from omero.gateway import BlitzGateway

import time
from datetime import datetime

import getpass
import ezomero
import os


def import_omero_biotox(user, passw, pth):
    start_time = time.time()
    image_transferred = 0
    conn = BlitzGateway(user, passw, host='omero.intranet.ufz.de', port=4064, secure=True)
    if conn.connect() is False:
        print("Not connected to OMERO instance. Please retry")
    else:
        print("Connection established. Starting Importing.")
        conn.SERVICE_OPTS.setOmeroGroup('-1')
        dataset_obj = omero.model.DatasetI()
        dataset_obj.setName(rstring(datetime.now()))
        dataset_obj = conn.getUpdateService().saveAndReturnObject(dataset_obj, conn.SERVICE_OPTS)
        dataset_id = dataset_obj.getId().getValue()
        list_img = os.listdir(pth)
        for image_name in list_img:
            image_path = os.path.join(pth, image_name)
            ezomero.ezimport(conn, image_path, dataset=dataset_id, ann=dict, ns="REMBI - Image Metadata")
            image_transferred += 1
        print(f"Total {image_transferred} in dataset {dataset_id}")
        print("--- Execution time %s seconds ---" % (time.time() - start_time))
        conn.close()

