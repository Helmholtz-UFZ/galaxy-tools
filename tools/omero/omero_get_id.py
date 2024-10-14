import argparse
import csv
import json

import ezomero as ez


def get_ids_ezo(user, pws, host, port, final_obj_type, parent_obj_type, parent_id=None, tsv_file="id_list.tsv"):
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
    try:
        with ez.connect(user, pws, "", host, port, secure=True) as conn:
            if final_obj_type == "Project":
                proj_ids = ez.get_project_ids(conn)
                write_ids_to_tsv(proj_ids, "Project IDs")
                return proj_ids
            elif final_obj_type == "Dataset":
                args = {'project': None}
                if parent_obj_type == "Project":
                    args['project'] = parent_id
                ds_ids = ez.get_dataset_ids(conn, **args)
                write_ids_to_tsv(ds_ids, "Dataset IDs")
                return ds_ids
            elif final_obj_type == "Image":
                args = {
                    'project': None,
                    'dataset': None,
                    'plate': None,
                    'well': None
                }
                if parent_obj_type == "Project":
                    args['project'] = parent_id
                elif parent_obj_type == "Dataset":
                    args['dataset'] = parent_id
                elif parent_obj_type == "Plate":
                    args['plate'] = parent_id
                elif parent_obj_type == "Well":
                    args['well'] = parent_id
                elif parent_obj_type != "All":
                    raise ValueError("Object set as parent_obj_type is not compatible")
                ds_ims = ez.get_image_ids(conn, **args)
                write_ids_to_tsv(ds_ims, "Image IDs")
                return ds_ims
            elif final_obj_type == "Annotation":
                map_annot_ids = ez.get_map_annotation_ids(conn, parent_obj_type, parent_id)
                write_ids_to_tsv(map_annot_ids, "Annotation IDs")
                return map_annot_ids
            elif final_obj_type == "Tag":
                tag_ids = ez.get_tag_ids(conn, parent_obj_type, parent_id)
                write_ids_to_tsv(tag_ids, "Tag IDs")
                return tag_ids
            elif final_obj_type == "Roi":
                roi_ids = ez.get_roi_ids(conn, parent_id)
                write_ids_to_tsv(roi_ids, "ROI IDs")
                return roi_ids
            elif final_obj_type == "Table":
                file_ann_ids = ez.get_file_annotation_ids(conn, parent_obj_type, parent_id)
                write_ids_to_tsv(file_ann_ids, "Table IDs")
                return file_ann_ids
            else:
                raise ValueError(f"Unsupported object type: {final_obj_type}")

    except Exception as e:
        print(f"Connection error: {str(e)}")
        return None


# Argument parsing
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Fetch OMERO object IDs as TSV from parent object.")
    parser.add_argument("--credential-file", dest="credential_file", type=str,
                        required=True, help="Credential file (JSON file with username and password for OMERO)")
    parser.add_argument('--host', required=True,
                        help="Host server address.")
    parser.add_argument('--port', required=True, type=int,
                        help='OMERO port')
    parser.add_argument('--final_obj_type', required=True,
                        help="Type of object to fetch ID: Project, Dataset, Image, Annotation, Tag, Roi, or Table.")
    parser.add_argument('--parent_obj_type', required=True,
                        help="Type of object from which you fetch IDs: Project, Dataset, Plate, Well, Image (or 'All' if you want to get all objects).")
    parser.add_argument('--parent_id', required=False, type=int,
                        help="ID of the OMERO object in `--parent_obj_type`, not required if you used `--parent_obj_type All`.")
    parser.add_argument('--tsv_file', default='id_list.tsv', required=True,
                        help="Output TSV file path.")
    args = parser.parse_args()

    if args.parent_id is None and args.parent_obj_type != "All":
        raise ValueError("ID is only optional is you use `--parent_obj_type All`")

    if args.final_obj_type == "Roi" and args.parent_obj_type != "Image":
        raise ValueError("Roi IDs can only be retrived from images, use `--parent_obj_type Image`")

    if args.parent_obj_type == "All" and args.final_obj_type not in ["Image", "Dataset", "Project"]:
        raise ValueError("Only Images, Datasets and Projects is compatible with `--parent_obj_type All`")

    with open(args.credential_file, 'r') as f:
        crds = json.load(f)

    # Call the main function to get the object and save it as a TSV
    get_ids_ezo(user=crds['username'], pws=crds['password'], host=args.host,
                port=args.port,
                final_obj_type=args.final_obj_type,
                parent_obj_type=args.parent_obj_type,
                parent_id=args.parent_id,
                tsv_file=args.tsv_file)
