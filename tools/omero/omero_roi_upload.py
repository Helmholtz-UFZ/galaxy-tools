import argparse
import re
import os
import sys

import ezomero as ez
import numpy as np
import pandas as pd

from ezomero.rois import Ellipse, Label, Line, Point, Polygon, Polyline, Rectangle
from omero.gateway import BlitzGateway
from pathlib import Path
from typing import Optional

# Import environmental variables
usr = os.getenv("OMERO_USER")
psw = os.getenv("OMERO_PASSWORD")
uuid_key = os.getenv("UUID_SESSION_KEY")


def parse_color(color_str):
    if not color_str:
        return None
    return tuple(map(int, re.findall(r'\d+', color_str)))


def parse_points(points_str):
    if not points_str:
        return None
    # Remove leading and trailing brackets and split into individual points
    points_str = points_str.strip("[]")
    points = points_str.split("),(")
    points = [point.strip("()") for point in points]  # Remove any remaining parentheses
    return [tuple(map(float, point.split(','))) for point in points]


# function to create different shapes
def create_shape(row):
    shape_type = row['shape']
    shape = None

    if shape_type == 'Ellipse':
        shape = Ellipse(
            x=row['x'],
            y=row['y'],
            x_rad=row['x_rad'],
            y_rad=row['y_rad'],
            z=row.get('z'),
            c=row.get('c'),
            t=row.get('t'),
            label=row.get('label'),
            fill_color=parse_color(row.get('fill_color')),
            stroke_color=parse_color(row.get('stroke_color')),
            stroke_width=row.get('stroke_width')
        )
    elif shape_type == 'Label':
        shape = Label(
            x=row['x'],
            y=row['y'],
            label=row['label'],
            fontSize=row['fontSize'],
            z=row.get('z'),
            c=row.get('c'),
            t=row.get('t'),
            fill_color=parse_color(row.get('fill_color')),
            stroke_color=parse_color(row.get('stroke_color')),
            stroke_width=row.get('stroke_width')
        )
    elif shape_type == 'Line':
        shape = Line(
            x1=row['x1'],
            y1=row['y1'],
            x2=row['x2'],
            y2=row['y2'],
            markerStart=row.get('markerStart', None),
            markerEnd=row.get('markerEnd', None),
            label=row.get('label'),
            z=row.get('z'),
            c=row.get('c'),
            t=row.get('t'),
            fill_color=parse_color(row.get('fill_color')),
            stroke_color=parse_color(row.get('stroke_color')),
            stroke_width=row.get('stroke_width')
        )
    elif shape_type == 'Point':
        shape = Point(
            x=row['x'],
            y=row['y'],
            z=row.get('z'),
            c=row.get('c'),
            t=row.get('t'),
            label=row.get('label'),
            fill_color=parse_color(row.get('fill_color')),
            stroke_color=parse_color(row.get('stroke_color')),
            stroke_width=row.get('stroke_width')
        )
    elif shape_type == 'Polygon':
        shape = Polygon(
            points=parse_points(row['points']),
            z=row.get('z'),
            c=row.get('c'),
            t=row.get('t'),
            label=row.get('label'),
            fill_color=parse_color(row.get('fill_color')),
            stroke_color=parse_color(row.get('stroke_color')),
            stroke_width=row.get('stroke_width')
        )
    elif shape_type == 'Polyline':
        shape = Polyline(
            points=parse_points(row['points']),
            z=row.get('z'),
            c=row.get('c'),
            t=row.get('t'),
            label=row.get('label'),
            fill_color=parse_color(row.get('fill_color')),
            stroke_color=parse_color(row.get('stroke_color')),
            stroke_width=row.get('stroke_width')
        )
    elif shape_type == 'Rectangle':
        shape = Rectangle(
            x=row['x'],
            y=row['y'],
            width=row['width'],
            height=row['height'],
            z=row.get('z'),
            c=row.get('c'),
            t=row.get('t'),
            label=row.get('label'),
            fill_color=parse_color(row.get('fill_color')),
            stroke_color=parse_color(row.get('stroke_color')),
            stroke_width=row.get('stroke_width')
        )
    return shape


def import_rois(
    host: str,
    port: int,
    input_file: Path,
    image_id: int,
    log_file: Path,
    uuid_key: Optional[str] = None,
    ses_close: Optional[bool] = True,
) -> str | int:

    """
    Create shapes from a tabular file and upload them as an ROI to OMERO.

    Parameters
    ----------
    host : str
        OMERO server host (i.e. OMERO address or domain name)"
    port : int
        OMERO server port (default:4064)
    image_id : str
        ID of the image to which the ROI will be linked
    input_file: Path
        Path to the input tabular file
    log_file : str
        Output path for the log file
    uuid_key : str, optional
        OMERO UUID session key to connect without password
    ses_close : bool
        Decide if close or not the section after executing the script. Defaulf value is true, useful when connecting with the UUID session key.
    Returns
    -------
    str | int
        A CSV writer object configured to write TSV data and ID of newly created ROI
    """

    # Try to connect with UUID or with username and password
    if uuid_key is not None:
        conn = BlitzGateway(username="", passwd="", host=host, port=port, secure=True)
        conn.connect(sUuid=uuid_key)
    else:
        conn = ez.connect(usr, psw, "", host, port, secure=True)
    if not conn.connect():
        sys.exit("ERROR: Failed to connect to OMERO server")

    # Open log file
    try:
        with open(log_file, 'w') as log:
            df = pd.read_csv(input_file, sep='\t')
            # Replace nan to none
            df = df.replace({np.nan: None})
            for index, row in df.iterrows():
                msg = f"Processing row {index + 1}/{len(df)}: {row.to_dict()}"
                print(msg)
                log.write(msg + "\n")
                shape = create_shape(row)
                if shape:
                    roi_name = row['roi_name'] if 'roi_name' in row else None
                    roi_description = row['roi_description'] if 'roi_description' in row else None
                    roi_id = ez.post_roi(conn, image_id, [shape], name=roi_name, description=roi_description)
                    msg = f"ROI ID: {roi_id} for row {index + 1}"
                    print(msg)
                    log.write(msg + "\n")
                else:
                    msg = f"Skipping row {index + 1}: Unable to create shape"
                    print(msg)
                    log.write(msg + "\n")
    finally:
        if ses_close:
            conn.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Create shapes from a tabular file and post them as an ROI to OMERO.")
    parser.add_argument("--host", type=str, required=True, help="OMERO server host (i.e. OMERO address or domain name)")
    parser.add_argument("--port", type=int, default=4064, help="OMERO server port (default:4064)")
    parser.add_argument("--input_file", help="Path to the input tabular file.")
    parser.add_argument("--image_id", type=int, required=True, help="ID of the image to which the ROI will be linked")
    parser.add_argument('--session_close', required=False, help='Namespace or title for the annotation')
    parser.add_argument("--log_file", type=str, default="process.txt", help="Output path for the log file")

    args = parser.parse_args()

    import_rois(host=args.host,
                port=args.port,
                input_file=args.input_file,
                image_id=args.image_id,
                ses_close=args.session_close,
                log_file=args.log_file)
