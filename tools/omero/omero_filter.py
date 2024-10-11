import argparse
import csv
import json

import ezomero as ez


def filter_ids_ezo(user, pws, host, port, filter, id, value1, value2=None, tsv_file="filter_list.tsv"):

    # Transform the id input in a list of integer
    id = id.split(',')
    id = list(map(int, id))

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
            if filter == "filename":
                fn_ids = ez.filter_by_filename(conn, id, value1)
                write_ids_to_tsv(fn_ids, [f"Images with filename {value1}"])
                return fn_ids
            elif filter == "KP":
                kp_ims = ez.filter_by_kv(conn, id, value1, value2)
                write_ids_to_tsv(kp_ims, [f"Images with KV {value1} and {value2}"])
                return kp_ims
            elif filter == "tag":
                tg_dict = ez.filter_by_tag_value(conn, id, value1)
                write_ids_to_tsv(tg_dict, [f"Images with tag {value1}"])
                return tg_dict

            else:
                raise ValueError(f"Unsupported object type")

    except Exception as e:
        print(f"Connection error: {str(e)}")
        return None


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
    parser.add_argument('--tsv_file', default='filter_list.tsv', required=True,
                        help="Output TSV file path.")

    args = parser.parse_args()

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
