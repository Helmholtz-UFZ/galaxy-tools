import argparse
import json
import re
from collections import defaultdict

import omero
from omero.gateway import BlitzGateway
from omero.rtypes import rint, rstring


def convert_dataset_to_plate(host, user, pws, port, dataset_id,
                             log_file):
    """
    Connect to OMERO server, convert a dataset to a plate using the specified regex for extracting well positions,
    optionally link the plate to a screen.
    """
    conn = BlitzGateway(user, pws, host=host, port=port, secure=True)
    if not conn.connect():
        raise ConnectionError("Failed to connect to OMERO server")

    def log_message(message, status="INFO"):
        with open(log_file, 'f') as f:
            f.write(f"{status}: {message}\n")

    try:
        regex = r"(?:^|[_-])([A-Z])(\d{1,2})(?:[_-]|$)"
        dataset = conn.getObject("Dataset", dataset_id)
        if dataset is None:
            raise ValueError("Dataset not found")

        update_service = conn.getUpdateService()

        plate = omero.model.PlateI()
        plate.name = rstring(dataset.getName())
        plate = update_service.saveAndReturnObject(plate)

        log_message(f"Created plate with ID {plate.id.val} for dataset '{dataset.getName()}'.")

        # Extract well positions from filenames and group images
        images = list(dataset.listChildren())
        grouped_images = defaultdict(list)
        for image in images:
            match = re.search(regex, image.getName())
            if match:
                row_str, col = match.groups()
                row, col = ord(row_str) - ord('A'), int(col) - 1
                grouped_images[(row, col)].append(image)
            else:
                log_message(f"Image '{image.getName()}' does not match the regex.", "WARNING")

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
                log_message(f"Successfully added images to well {chr(row + ord('A'))}{col + 1}.")
            except Exception as e:
                log_message(f"Failed to add images to well {chr(row + ord('A'))}{col + 1}: {e}", "ERROR")
                return False

        log_message(f"Images from Dataset {dataset_id} successfully added to Plate {plate.id.val}.", "SUCCESS")
        conn.close()

    except Exception as e:
        log_message(f"An error occurred: {str(e)}", "ERROR")
        conn.close()


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
