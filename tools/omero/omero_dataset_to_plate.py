import argparse
import csv
import os
import re
import sys
from collections import defaultdict
from pathlib import Path
from typing import Optional

import omero
from omero.rtypes import rint, rstring

from connect_omero import establish_connection

# Import environmental variables
usr = os.getenv("OMERO_USER")
psw = os.getenv("OMERO_PASSWORD")
uuid_key = os.getenv("UUID_SESSION_KEY")


def convert_dataset_to_plate(
    host: str,
    port: str,
    dataset_id: str,
    log_file: Path,
    mapping_file: str,
    delete_dataset: bool,
    uuid_key: Optional[str] = None,
    ses_close: Optional[bool] = True
) -> str:
    """
    Connect to OMERO server, convert a dataset to a plate using the specified well mapping file

    Parameters
    ----------
     host : str
        OMERO server host (i.e. OMERO address or domain name)"
    port : int
        OMERO server port (default:4064)
    dataset_id : str
        Dataset ID to convert plate
    log_file : str
        Output path for the log file
    mapping_file: str
        Tabular file mapping filenames to well positions (2 columns: filename, Well)
    delete_dataset: bool
        Input to delete the original dataset convert to plate or not
    uuid_key : str, optional
        OMERO UUID session key to connect without password
    ses_close : bool
        Decide if close or not the section after executing the script. Defaulf value is true, useful when connecting with the UUID session key.

    Returns
    -------
    str
        Return log file with info on the conversion
    """
    conn = establish_connection(uuid_key, usr, psw, host, port)

    def log_message(message, status="INFO"):
        with open(log_file, 'w') as f:
            f.write(f"{message}")

    dataset = conn.getObject("Dataset", dataset_id)
    if dataset is None:
        conn.close()
        sys.exit("ERROR: Dataset not found")

    update_service = conn.getUpdateService()

    # Create a Plate
    plate = omero.model.PlateI()
    plate.name = rstring(dataset.getName())
    plate = update_service.saveAndReturnObject(plate)

    # Parse the mapping file
    image_to_well_mapping = {}
    if mapping_file:
        with open(mapping_file, 'r') as f:
            reader = csv.DictReader(f, delimiter='\t')
            for row in reader:
                filename = row['Filename']
                well = row['Well']
                match = re.match(r"([A-Z])(\d+)", well)
                if match:
                    row_char, col = match.groups()
                    row = ord(row_char.upper()) - ord('A')
                    col = int(col) - 1
                    image_to_well_mapping[filename] = (row, col)
                else:
                    conn.close()
                    sys.exit(f"Invalid well format '{well}' for file '{filename}'")

    # List the dataset children
    images = list(dataset.listChildren())
    if not images:
        conn.close()
        sys.exit("ERROR: No images found in dataset")

    # Compare images in the mapping file and in the dataset
    grouped_images = defaultdict(list)
    for image in images:
        image_name = image.getName()
        if image_to_well_mapping:
            if image_name in image_to_well_mapping:
                row, col = image_to_well_mapping[image_name]
                grouped_images[(row, col)].append(image)
            else:
                conn.close()
                sys.exit(f"Image '{image_name}' not found in mapping file.")

    # Assign images to the well based on the mapping file
    for (row, col), imgs_in_group in grouped_images.items():
        well = omero.model.WellI()
        well.plate = omero.model.PlateI(plate.id.val, False)
        well.column = rint(col)
        well.row = rint(row)

        for image in imgs_in_group:
            ws = omero.model.WellSampleI()
            ws.image = omero.model.ImageI(image.id, False)
            ws.well = well
            well.addWellSample(ws)

        try:
            update_service.saveObject(well)
        except ValueError as e:
            conn.close()
            sys.exit("ERROR: Failed to update plate for dataset '{}' due to: {}".format(dataset.getName(), str(e)))

    # Close the connection and, in case, delete the dataset
    if delete_dataset is True:
        conn.deleteObjects("Dataset", [dataset_id], wait=True)
    log_message(f"Images from Dataset {dataset_id} successfully added to Plate {plate.id.val}")
    if ses_close:
        conn.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Convert an OMERO dataset to a plate.")
    parser.add_argument('--host', required=True, help="OMERO server host (i.e. OMERO address or domain name)")
    parser.add_argument('--port', required=True, type=int, help="OMERO server port (default:4064)")
    parser.add_argument('--dataset_id', type=int, required=True, help="Dataset ID to convert plate")
    parser.add_argument('--log_file', default='metadata_import_log.txt', help="Output path for the log file")
    parser.add_argument('--mapping_file', help='Tabular file mapping filenames to well positions (2 columns: filename, Well)')
    parser.add_argument('--session_close', required=False, help='Namespace or title for the annotation')
    parser.add_argument('--delete_dataset', action='store_true', help='Flag to delete the original dataset')

    args = parser.parse_args()

    convert_dataset_to_plate(
        host=args.host,
        port=args.port,
        dataset_id=args.dataset_id,
        log_file=args.log_file,
        mapping_file=args.mapping_file,
        ses_close=args.session_close,
        delete_dataset=args.delete_dataset
    )
