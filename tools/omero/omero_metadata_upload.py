import argparse
from datetime import datetime

import ezomero as ez
import pandas as pd


def metadata_import_ezo(user, pws, host, port, obj_type, did=None, ann_type="table", ann_file=None, an_name=None,
                        log_file='metadata_import_log.txt'):
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
        with ez.connect(user, pws, "", host, port, secure=True) as conn:
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
            elif obj_type == "image":
                result = upload_metadata(conn, "Image", did, data_dict, df, ann_type, an_name)
            else:
                raise ValueError("Unsupported object type provided: {}".format(obj_type))

            if result is not None:
                log_success(f"Successfully uploaded metadata for {obj_type} with ID {did}. Result: {result}")
            else:
                log_error(f"Failed to upload metadata for {obj_type} with ID {did}.")

        conn.close()

    except Exception as e:
        log_error(f"Connection error: {str(e)}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Import metadata into OMERO.')
    parser.add_argument('--user', required=True, help='OMERO username')
    parser.add_argument('--pws', required=True, help='OMERO password')
    parser.add_argument('--host', required=True, help='OMERO host')
    parser.add_argument('--port', required=True, type=int, help='OMERO port')
    parser.add_argument('--obj_type', required=True, choices=['project', 'screen', 'dataset', 'image'],
                        help='Type of OMERO object')
    parser.add_argument('--did', type=int, help='ID of the object (if it exists)')
    parser.add_argument('--ann_type', required=True, choices=['table', 'KV'], help='Annotation type')
    parser.add_argument('--ann_file', required=True, help='Path to the annotation file')
    parser.add_argument('--an_name', required=True, help='Namespace or title for the annotation')
    parser.add_argument('--log_file', default='metadata_import_log.txt', help='Path to the log file')

    args = parser.parse_args()

    metadata_import_ezo(user=args.user, pws=args.pws, host=args.host, port=args.port,
                        obj_type=args.obj_type, did=args.did, ann_type=args.ann_type,
                        ann_file=args.ann_file, an_name=args.an_name, log_file=args.log_file)
