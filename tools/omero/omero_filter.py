import argparse
import csv
import json
import sys

import ezomero as ez


def filter_ids_ezo(user, pws, host, port, filter, id, value1, value2=None, tsv_file="filter_list.tsv"):

    # Transform the id input in a list of integer
    id = id.split(',')
    id = list(map(int, id))

    # Function to write tabular file from the ezomero output
    def write_ids_to_tsv(data):
        with open(tsv_file, 'w', newline='') as f:
            writer = csv.writer(f, delimiter='\t')
            for item in data:
                writer.writerow([item])  # Write each ID

    try:
        with ez.connect(user, pws, "", host, port, secure=True) as conn:
            try:
                if filter == "filename":
                    fn_ids = ez.filter_by_filename(conn, id, value1)
                    write_ids_to_tsv(fn_ids)
                    return fn_ids

                elif filter == "KP":
                    kp_ims = ez.filter_by_kv(conn, id, value1, value2)
                    write_ids_to_tsv(kp_ims)
                    return kp_ims

                elif filter == "tag":
                    tg_dict = ez.filter_by_tag_value(conn, id, value1)
                    write_ids_to_tsv(tg_dict)
                    return tg_dict

                else:
                    raise ValueError(f"Unsupported object type: {filter}")

            except ValueError as ve:
                sys.exit(f"ValueError: {str(ve)}")

    except Exception as e:
        sys.exit(f"Connection error: {str(e)}")


# Argument parsing
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Fetch and save data as TSV based on object type.")
    parser.add_argument("--credential-file", dest="credential_file", type=str, required=True,
                        help="Credential file (JSON file with username and password for OMERO)")
    parser.add_argument('--host', required=True,
                        help="Host server address.")
    parser.add_argument('--port', required=True, type=int,
                        help='OMERO port')
    parser.add_argument('--filter', required=True,
                        help="Filter type - Filename, Key-Value Pairs, Tag")
    parser.add_argument('--id', required=True,
                        help="List of images IDs")
    parser.add_argument('--value1', required=True,
                        help="First searching values - Filename, Key, Tag")
    parser.add_argument('--value2', required=False,
                        help="Second searching values - Value (necessary just for Key-Value Pairs filter")
    parser.add_argument('--tsv_file', default='filter_list.tsv', 
                        help="Output TSV file path.")
    args = parser.parse_args()

    if args.filter == "KP" and args.value2 is None:
        raise ValueError("'--value 2' is necessary to retrieve KP")

    with open(args.credential_file, 'r') as f:
        crds = json.load(f)

    # Call the main function to get the object and save it as a TSV
    filter_ids_ezo(user=crds['username'], pws=crds['password'], host=args.host,
                   port=args.port,
                   filter=args.filter,
                   value1=args.value1,
                   value2=args.value2,
                   id=args.id,
                   tsv_file=args.tsv_file)
