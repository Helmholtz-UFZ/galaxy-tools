import argparse
import csv
import json

import ezomero as ez


def get_object_ezo(user, pws, host, port, obj_type, id=None, tsv_file="id_list.tsv"):
    # Function to write tabular file from the ezomero output
    def write_ids_to_tsv(data, header):
        with open(tsv_file, 'a+', newline='') as f:
            f.seek(0)
            is_empty = f.tell() == 0  # Check if file is empty
            writer = csv.writer(f, delimiter='\t')
            if is_empty:
                writer.writerow([header])  # Write the header
            for item in data:
                writer.writerow([item])  # Write each ID

    # Function to write tabular file from a dictionary ezomero output
    def write_dict_to_tsv(data, headers):
        with open(tsv_file, 'a+', newline='') as f:
            f.seek(0)
            is_empty = f.tell() == 0  # Check if file is empty
            writer = csv.writer(f, delimiter='\t')
            if is_empty:
                writer.writerow(headers)  # Write the headers
            for key, value in data.items():
                writer.writerow([key, value])  # Write each key-value pair

    try:
        with ez.connect(user, pws, "", host, port, secure=True) as conn:
            if obj_type == "dataset":
                ds_ids = ez.get_dataset_ids(conn, project=int(id))
                write_ids_to_tsv(ds_ids, "Dataset IDs")
                return ds_ids
            elif obj_type == "image":
                ds_ims = ez.get_image_ids(conn, dataset=int(id))
                write_ids_to_tsv(ds_ims, "Image IDs")
                return ds_ims
            elif obj_type == "annotation":
                ma_dict = ez.get_map_annotation(conn, int(id))
                write_dict_to_tsv(ma_dict, ["Annotation ID", "Annotation Value"])
                return ma_dict
            elif obj_type == "project":
                proj_ids = ez.get_project_ids(conn)
                write_ids_to_tsv(proj_ids, "Project IDs")
                return proj_ids
            elif obj_type == "roi":
                roi_ids = ez.get_roi_ids(conn, int(id))
                write_ids_to_tsv(roi_ids, "ROI IDs")
                return roi_ids
            elif obj_type == "table":
                table = ez.get_table(conn, int(id))
                write_dict_to_tsv(table, ["Table ID", "Table Value"])
                return table
            else:
                raise ValueError(f"Unsupported object type: {obj_type}")

    except Exception as e:
        print(f"Connection error: {str(e)}")
        return None


# Argument parsing
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Fetch and save data as TSV based on object type.")
    parser.add_argument("--credential-file", dest="credential_file", type=str,
                        required=True, help="Credential file (JSON file with username and password for OMERO)")
    parser.add_argument('--host', required=True,
                        help="Host server address.")
    parser.add_argument('--port', required=True, type=int,
                        help='OMERO port')
    parser.add_argument('--obj_type', required=True,
                        help="Type of object to fetch: dataset, image, annotation, project, roi, or table.")
    parser.add_argument('--id', required=False,
                        help="ID of the specific OMERO object.")
    parser.add_argument('--tsv_file', default='id_list.tsv', required=True,
                        help="Output TSV file path.")
    args = parser.parse_args()

    with open(args.credential_file, 'r') as f:
        crds = json.load(f)

    # Call the main function to get the object and save it as a TSV
    get_object_ezo(user=crds['username'], pws=crds['password'], host=args.host,
                   port=args.port,
                   obj_type=args.obj_type,
                   id=args.id,
                   tsv_file=args.tsv_file)
