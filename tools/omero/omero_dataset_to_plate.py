import argparse
import json
import re
from collections import defaultdict

import omero
from omero.gateway import BlitzGateway
from omero.rtypes import rint, rstring


def convert_dataset_to_plate(host, user, pws, port, dataset_id,
                             log_file='metadata_import_log.txt'):
    """
    Connect to OMERO server, convert a dataset to a plate using the specified regex for extracting well positions,
    optionally link the plate to a screen.
    """
    conn = BlitzGateway(user, pws, host=host, port=port, secure=True)
    if not conn.connect():
        raise ConnectionError("Failed to connect to OMERO server")

    def log_error(message):
        with open(log_file, 'w') as f:
            f.write(f"ERROR: {message}\n")

    def log_success(message):
        with open(log_file, 'w') as f:
            f.write(f"SUCCESS: {message}\n")

    try:
        regex = r"(?:^|[_-])([A-Z])(\d{1,2})(?:[_-]|$)"
        dataset = conn.getObject("Dataset", dataset_id)
        if dataset is None:
            raise ValueError("Dataset not found")

        update_service = conn.getUpdateService()

        plate = omero.model.PlateI()
        plate.name = rstring(dataset.getName())
        plate = update_service.saveAndReturnObject(plate)

        # Extract well positions from filenames and group images
        images = list(dataset.listChildren())
        grouped_images = defaultdict(list)
        for image in images:
            match = re.search(regex, image.getName())
            if match:
                row_str, col = match.groups()
                row, col = ord(row_str) - ord('A'), int(col) - 1
                grouped_images[(row, col)].append(image)

        # Add images to wells
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
            except Exception as e:
                log_error(f"Failed to add images to well {chr(row + ord('A'))}{col + 1}: {e}")
                return False

        log_success(f"Images from Dataset {dataset_id} successfully added to Plate {plate.id.val}.")
        conn.close()

    except Exception as e:
        log_error(f"Connection error: {str(e)}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Convert an OMERO dataset to a plate.")
    parser.add_argument("--credential-file", dest="credential_file", type=str, required=True,
                        help="Credential file (JSON file with username and password for OMERO)")
    parser.add_argument('--host', required=True, help='OMERO host')
    parser.add_argument('--port', required=True, type=int, help='OMERO port')
    parser.add_argument('--dataset_id', type=int, required=True, help="Dataset ID to convert plate")
    parser.add_argument('--log_file', default='metadata_import_log.txt', help='Path to the log file')
    args = parser.parse_args()

    with open(args.credential_file, 'r') as f:
        crds = json.load(f)

    convert_dataset_to_plate(user=crds['username'], pws=crds['password'], host=args.host, port=args.port,
                             dataset_id=args.dataset_id, log_file=args.log_file)
