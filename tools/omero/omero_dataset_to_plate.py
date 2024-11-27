import argparse
import csv
import json
import re
import sys
from collections import defaultdict


import omero
from omero.gateway import BlitzGateway
from omero.rtypes import rint, rstring


def convert_dataset_to_plate(host, user, pws, port, dataset_id, log_file, mapping_file, delete_dataset):
    """
    Connect to OMERO server, convert a dataset to a plate using the specified well mapping file
    """
    conn = BlitzGateway(user, pws, host=host, port=port, secure=True)
    if not conn.connect():
        sys.exit("ERROR: Failed to connect to OMERO server")

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
        else:
            conn.close()
            sys.exit("ERROR: No mapping file provided")

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
    conn.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Convert an OMERO dataset to a plate.")
    parser.add_argument("--credential-file", dest="credential_file", type=str, required=True,
                        help="Credential file (JSON file with username and password for OMERO)")
    parser.add_argument('--host', required=True, help='OMERO host')
    parser.add_argument('--port', required=True, type=int, help='OMERO port')
    parser.add_argument('--dataset_id', type=int, required=True, help="Dataset ID to convert plate")
    parser.add_argument('--log_file', default='metadata_import_log.txt',
                        help='Path to the log file')
    parser.add_argument('--mapping_file',
                        help='Tabular file mapping filenames to well positions (2 columns: filename, Well)')
    parser.add_argument('--delete_dataset', required=True, type=bool,
                        help='Delete the original dataset or not')
    args = parser.parse_args()

    with open(args.credential_file, 'r') as f:
        crds = json.load(f)

    convert_dataset_to_plate(
        user=crds['username'],
        pws=crds['password'],
        host=args.host,
        port=args.port,
        dataset_id=args.dataset_id,
        log_file=args.log_file,
        mapping_file=args.mapping_file,
        delete_dataset=args.delete_dataset
    )
