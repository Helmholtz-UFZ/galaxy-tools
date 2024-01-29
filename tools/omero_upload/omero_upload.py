import argparse
import os
import time
from datetime import datetime
from sys import exit

import ezomero
import omero
from omero.rtypes import rstring
from omero.gateway import BlitzGateway


def import_omero_biotox(user, passw, pth, host='omero.intranet.ufz.de', port=4064):
    start_time = time.time()
    image_transferred = 0
    conn = BlitzGateway(user, passw, host=host, port=port, secure=True)
    connected = conn.connect()
    if not connected:
        exit("Not connected to OMERO instance. Please retry")
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
            ezomero.ezimport(conn, image_path, dataset=dataset_id)
            image_transferred += 1
        print(f"Total {image_transferred} in dataset {dataset_id}")
        print("--- Execution time %s seconds ---" % (time.time() - start_time))
        conn.close()


parser = argparse.ArgumentParser(prog='omero_upload', description='')
parser.add_argument('--url', type=str, default="omero.intranet.ufz.de", help='URL')
parser.add_argument('--port', type=int, default=4064, help='port')
parser.add_argument('--user', type=str, help='username')
parser.add_argument('--password', type=str, help='password')
parser.add_argument('--folder', type=str, help='folder')
args = parser.parse_args()

import_omero_biotox(args.user, args.password, args.folder, args.url, args.port)