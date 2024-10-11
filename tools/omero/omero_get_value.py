import argparse
import csv
import json

import ezomero as ez


def get_object_ezo(user, pws, host, port, obj_type, ids, tsv_file):
    # Function to write tabular file from the ezomero output
    def write_values_to_tsv(data, header):
        with open(tsv_file, 'a+', newline='') as f:
            f.seek(0)
            is_empty = f.tell() == 0  # Check if file is empty
            writer = csv.writer(f, delimiter='\t')
            if is_empty:
                writer.writerow([header])  # Write the header
            for item in data:
                writer.writerow([item])  # Write each value

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

    # Function to write tabular file from list of list ezomero output
    def write_table_to_tsv(data):
        with open(tsv_file, 'w') as f:
            for row in data:
                f.write('\t'.join([str(val) for val in row]) + '\n')

    try:
        with ez.connect(user, pws, "", host, port, secure=True) as conn:
            if obj_type == "Annotation":
                ma_dict = {}
                for maid in ids:
                    current_ma_dict = ez.get_map_annotation(conn, maid)
                    ma_dict = {**ma_dict, **current_ma_dict}
                write_dict_to_tsv(ma_dict, ["Annotation ID", "Annotation Value"])
                return ma_dict
            elif obj_type == "Tag":
                tags = []
                for tag_id in ids:
                    tags.append(ez.get_tag(conn, tag_id))
                # Sort the tags for consistency:
                tags.sort
                write_values_to_tsv(tags, "Tags")
                return tags
            elif obj_type == "Table":
                if len(ids) > 1:
                    raise ValueError("Only one table can be exported at a time")
                table = ez.get_table(conn, ids[0])
                write_table_to_tsv(table)
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
                        help="Type of object to fetch: Annotation, Table or Tag.")
    group = parser.add_mutually_exclusive_group()
    group.add_argument('--ids', nargs='+', type=int,
                       help="IDs of the OMERO objects.")
    group.add_argument('--ids_path',
                       help="File with IDs of the OMERO objects (one per line).")
    parser.add_argument('--tsv_file', default='id_list.tsv', required=True,
                        help="Output TSV file path.")
    args = parser.parse_args()

    if args.ids_path:
        args.ids = []
        with open(args.ids_path, 'r') as f:
            for line in f:
                try:
                    args.ids.append(int(line))
                except ValueError:
                    print(f"{line.strip()} is not a valid ID.")
        if len(args.ids) == 0:
            raise ValueError("Cound not find a single ID in the file.")

    with open(args.credential_file, 'r') as f:
        crds = json.load(f)

    # Call the main function to get the object and save it as a TSV
    get_object_ezo(user=crds['username'], pws=crds['password'], host=args.host,
                   port=args.port,
                   obj_type=args.obj_type,
                   ids=args.ids,
                   tsv_file=args.tsv_file)
