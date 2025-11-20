import argparse
from datetime import datetime
import os
import sys

import ezomero as ez
import pandas as pd

from omero.gateway import BlitzGateway
from pathlib import Path
from typing import Optional


# Import environmental variables
usr = os.getenv("OMERO_USER")
psw = os.getenv("OMERO_PASSWORD")
uuid = os.getenv("UUID_SESSION_KEY")


def metadata_import_ezo(
        host: str,
        port: int,
        obj_type: str,
        ann_type: [str] = "table",
        ann_file: Path = None,
        an_name: [str] = None,
        did: Optional[int] = None,
        uuid_key: Optional[str] = None,
        log_file: [str] = 'metadata_import_log.txt',
        ses_close: Optional[bool] = True,
) -> str:

    '''
    Import metadata into OMERO as form of OMERO.table or Key-Value Pairs.

    Parameters
    ----------
    host : str
        OMERO server host (i.e. OMERO address or domain name)"
    port : int
        OMERO server port (default:4064)
    did: list
        ID of the object (if it exists)
    obj_type : str
        Annotation type meaning Table or Key-Value pairs
    ann_type: str
        Path to the annotation file
    ann_file: [Path]=None
        Path to the annotation file
    an_name : str
        Namespace or title for the annotation
    uuid_key : str, optional
        OMERO UUID session key to connect without password
    log_file : str
        Output path for the log file
    ses_close : bool
        Decide if close or not the section after executing the script. Defaulf value is true, useful when connecting with the UUID session key.

    Returns
    -------
    csv.writer
        A CSV writer object configured to write TSV data.
    '''

    # Try to connect with UUID or with username and password
    if uuid_key is not None:
        conn = BlitzGateway(username="", passwd="", host=host, port=port, secure=True)
        conn.connect(sUuid=uuid)
    else:
        conn = ez.connect(usr, psw, "", host, port, secure=True)
        if not conn.connect():
            sys.exit("ERROR: Failed to connect to OMERO server")

    def upload_metadata(conn, obj_type, did, data_dict, df, ann_type, an_name):
        try:
            if ann_type == "KV":
                id_map_ann = ez.post_map_annotation(conn, obj_type, object_id=int(did), kv_dict=data_dict, ns=an_name)
                ma_dict = ez.get_map_annotation(conn, id_map_ann)
                return ma_dict
            elif ann_type == "table":
                id_tb_ann = ez.post_table(conn, df, object_type=obj_type, object_id=int(did), title=an_name,
                                          headers=True)
                tb_dict = ez.get_table(conn, id_tb_ann)
                return tb_dict
        except Exception as e:
            log_error(f"Error uploading metadata for {obj_type} with ID {did}: {str(e)}")
            return None

    def log_error(message):
        with open(log_file, 'w') as f:
            f.write(f"ERROR: {message}\n")

    def log_success(message):
        with open(log_file, 'w') as f:
            f.write(f"SUCCESS: {message}\n")

    try:
        df = pd.read_csv(ann_file, delimiter='\t')
    except FileNotFoundError as e:
        log_error(f"Annotation file not found: {str(e)}")
        return

    if ann_type == "table":
        data_dict = df.to_dict(orient='records')
    elif ann_type == "KV":
        data_dict = {col: df[col].iloc[0] for col in df.columns}

    try:
        if obj_type == "project":
            if did is None:
                did = ez.post_project(conn, project_name=str(datetime.now()))
            result = upload_metadata(conn, "Project", did, data_dict, df, ann_type, an_name)
        elif obj_type == "screen":
            if did is None:
                did = ez.post_screen(conn, screen_name=str(datetime.now()))
            result = upload_metadata(conn, "Screen", did, data_dict, df, ann_type, an_name)
        elif obj_type == "dataset":
            if did is None:
                did = ez.post_dataset(conn, dataset_name=str(datetime.now()))
            result = upload_metadata(conn, "Dataset", did, data_dict, df, ann_type, an_name)
        elif obj_type == "plate":
            result = upload_metadata(conn, "Plate", did, data_dict, df, ann_type, an_name)
        elif obj_type == "well":
            result = upload_metadata(conn, "Well", did, data_dict, df, ann_type, an_name)
        elif obj_type == "image":
            result = upload_metadata(conn, "Image", did, data_dict, df, ann_type, an_name)
        else:
            raise ValueError("Unsupported object type provided: {}".format(obj_type))
    finally:
        if result is not None:
            log_success(f"Successfully uploaded metadata for {obj_type} with ID {did}. Result: {result}")
            if ses_close:
                conn.close()
        else:
            log_error(f"Failed to upload metadata for {obj_type} with ID {did}.")
            if ses_close:
                conn.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description='Import metadata into OMERO as form of OMERO.table or Key-Value Pairs.')
    parser.add_argument('--host', required=True, help="OMERO server host (i.e. OMERO address or domain name)")
    parser.add_argument('--port', required=True, type=int, help="OMERO server port (default:4064)")
    parser.add_argument('--obj_type', required=True,
                        choices=['project', 'screen', 'dataset', 'plate', 'well ', 'image'],
                        help='Type of OMERO object')
    parser.add_argument('--did', type=int, help='ID of the object (if it exists)')
    parser.add_argument('--ann_type', required=True, choices=['table', 'KV'], help='Annotation type')
    parser.add_argument('--ann_file', required=True, help='Path to the annotation file')
    parser.add_argument('--an_name', required=True, help='Namespace or title for the annotation')
    parser.add_argument('--session_close', required=False, help='Namespace or title for the annotation')
    parser.add_argument('--log_file', default='metadata_import_log.txt', help='Path to the log file')

    args = parser.parse_args()

    metadata_import_ezo(host=args.host,
                        port=args.port,
                        obj_type=args.obj_type,
                        did=args.did,
                        ann_type=args.ann_type,
                        ann_file=args.ann_file,
                        an_name=args.an_name,
                        ses_close=args.session_close,
                        log_file=args.log_file)
