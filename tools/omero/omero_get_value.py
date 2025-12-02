import argparse
import csv
import os
import sys

import ezomero as ez
import pandas as pd

from connect_omero import establish_connection
from omero.gateway import BlitzGateway
from typing import Optional

# Import environmental variables
usr = os.getenv("OMERO_USER")
psw = os.getenv("OMERO_PASSWORD")
uuid_key = os.getenv("UUID_SESSION_KEY")


def get_object_ezo(
        host: str,
        port: int,
        obj_type: str,
        ids: list,
        out_dir: str,
        uuid_key: Optional[str] = None,
        ses_close: Optional[bool] = True
) -> str | dict:

    """
Fetch OMERO objects (Annotation, Table and Key-Value Pairs list) and save them as TSV based on object type.

Parameters
----------
host : str
    OMERO server host (i.e. OMERO address or domain name)"
port : int
    OMERO server port (default:4064)
obj_type : str
    Type of object to fetch ID: Project, Dataset, Image, Annotation, Tag, ROI, or Table.
ids : list
    IDs of the OMERO objects.
out_dir : str
    Output path of the file
uuid_key : str, optional
    OMERO UUID session key to connect without password
ses_close : bool
    Decide if close or not the section after executing the script. Defaulf value is true, useful when connecting with the UUID session key.
Returns
-------
csv.writer
    A CSV writer object configured to write TSV data.
"""

    conn = establish_connection(uuid_key, usr, psw, host, port)

    # Function to write tabular file from the ezomero output
    def write_values_to_tsv(data, header):
        with open("output.tsv", 'w', newline='') as f:
            writer = csv.writer(f, delimiter='\t')
            writer.writerow([header])  # Write the header
            for item in data:
                writer.writerow([item])  # Write each value

    # Function to write tabular file from a dictionary ezomero output
    def write_dict_to_tsv(data, headers):
        with open("output.tsv", 'w', newline='') as f:
            writer = csv.writer(f, delimiter='\t')
            writer.writerow(headers)  # Write the headers
            for key, value in data.items():
                writer.writerow([key, value])  # Write each key-value pair

    # Function to write tabular file from list of list ezomero output
    def write_table_to_tsv(data, id):
        with open(f"./output/ID_{id}_table.tsv", 'w') as f:
            for row in data:
                f.write('\t'.join([str(val) for val in row]) + '\n')

    try:
        # Fetch different object according to the user input
        if obj_type == "Annotation":
            ma_dict = {}
            for maid in ids:
                current_ma_dict = ez.get_map_annotation(conn, maid)
                ma_dict = {**ma_dict, **current_ma_dict}
                print(ma_dict)
            write_dict_to_tsv(ma_dict, ["Annotation ID", "Annotation Value"])
        elif obj_type == "Tag":
            tags = []
            for tag_id in ids:
                tags.append(ez.get_tag(conn, tag_id))
            # Sort the tags for consistency:
            tags.sort
            write_values_to_tsv(tags, "Tags")
        elif obj_type == "Table":
            for id in ids:
                table = ez.get_table(conn, id)
                print(table)
                write_table_to_tsv(table, id)
        elif obj_type == ("Attachment"):
            for id in ids:
                attch_path = ez.get_file_annotation(conn, id, folder_path='./output/')
                base_name = os.path.basename(attch_path)
                df = pd.read_csv(attch_path, sep='\t')
                df.to_csv(f"./output/ID_{id}_{base_name}", sep='\t', index=False)
                os.remove(attch_path)
        else:
            sys.exit(f"Unsupported object type: {filter}")

    finally:
        if ses_close:
            conn.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Fetch and save data as TSV based on object type.")
    parser.add_argument('--host', required=True, help="OMERO server host (i.e. OMERO address or domain name)")
    parser.add_argument('--port', required=True, type=int, help="OMERO server port (default:4064)")
    parser.add_argument('--obj_type', required=True, help="Type of object to fetch: Annotation, Table or Tag.")
    group = parser.add_mutually_exclusive_group()
    group.add_argument('--ids', nargs='+', type=int, help="IDs of the OMERO objects.")
    group.add_argument('--ids_path', help="File with IDs of the OMERO objects (one per line).")
    parser.add_argument('--session_close', required=False, help='Namespace or title for the annotation')
    parser.add_argument('--out_dir', required=True, help="Output path.")

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

    # Call the main function to get the object and save it as a TSV
    get_object_ezo(host=args.host,
                   port=args.port,
                   obj_type=args.obj_type,
                   ids=args.ids,
                   ses_close=args.session_close,
                   out_dir=args.out_dir)
