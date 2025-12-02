import argparse
import csv
import os
import sys

import ezomero as ez

from connect_omero import establish_connection
from omero.gateway import BlitzGateway
from typing import Optional

# Import environmental variables
usr = os.getenv("OMERO_USER")
psw = os.getenv("OMERO_PASSWORD")
uuid_key = os.getenv("UUID_SESSION_KEY")


def filter_ids_ezo(
        host: str,
        port: int,
        filter: str,
        id: list,
        value1: str,
        value2: Optional[str] = None,
        uuid_key: Optional[str] = None,
        tsv_file: str = "filter_list.tsv",
        ses_close: Optional[bool] = True
) -> int:
    """

    Apply filter_by_filename, filter_by_kv or filter_by_tag_value from the ezomero module to a list of images ID.

    Parameters
    ----------
    host : str
        OMERO server host (i.e. OMERO address or domain name)"
    port : int
        OMERO server port (default:4064)
    filter : str
        Filter to apply to the IDs list (Filename, Key-Value pairs or Tags)
    id : int
        A list of image IDs
    value1 : str
        Primary filter value.
    value2 : str, optional
        Optional secondary filter value.
    uuuid_key : str, optional
        OMERO UUID session key to connect without password
    tsv_file : str, optional
        Output TSV filename. Default is "filter_list.tsv".
    ses_close : bool
        Decide if close or not the section after executing the script. Defaulf value is true, useful when connecting with the UUID session key.

    Returns
    -------
    csv.writer
        A CSV writer object configured to write TSV data. Contain a list of IDs with the filtered IDs
    """

    # Function to write tabular file from the ezomero output
    def write_ids_to_tsv(data):
        with open(tsv_file, 'w', newline='') as f:
            writer = csv.writer(f, delimiter='\t')
            for item in data:
                writer.writerow([item])  # Write each ID

    # Try to connect with UUID or with username and password
    conn = establish_connection(uuid_key, usr, psw, host, port)

    # Transform the id input in a list of integer
    id = id.split(',')
    id = list(map(int, id))

    try:
        # Apply different filters to the image ID list
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
            sys.exit(f"Unsupported object type: {filter}")

    finally:
        if ses_close:
            conn.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Fetch and save data as TSV based on object type.")
    parser.add_argument('--host', required=True, help="OMERO server host (i.e. OMERO address or domain name)")
    parser.add_argument('--port', required=True, type=int, help="OMERO server port (default:4064)")
    parser.add_argument('--filter', required=True, help="Filter type - Filename, Key-Value Pairs, Tag")
    parser.add_argument('--id', required=True, help="List of images IDs")
    parser.add_argument('--value1', required=True, help="First searching values - Filename, Key, Tag")
    parser.add_argument('--value2', required=False,
                        help="Second searching values - Value (necessary just for Key-Value Pairs filter")
    parser.add_argument('--session_close', required=False, help='Namespace or title for the annotation')
    parser.add_argument('--tsv_file', default='filter_list.tsv', help="Output TSV file path.")

    args = parser.parse_args()

    if args.filter == "KP" and args.value2 is None:
        raise ValueError("'--value 2' is necessary to retrieve KP")

    # Call the main function to get the object and save it as a TSV
    filter_ids_ezo(host=args.host,
                   port=args.port,
                   filter=args.filter,
                   value1=args.value1,
                   value2=args.value2,
                   id=args.id,
                   ses_close=args.session_close,
                   tsv_file=args.tsv_file)
