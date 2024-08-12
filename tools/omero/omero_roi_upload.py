import argparse
import re

from ezomero import post_roi, connect
from ezomero.rois import Ellipse, Label, Line, Point, Polygon, Polyline, Rectangle
import pandas as pd


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
            label=row.get('label', None),
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
            fill_color=parse_color(row.get('fill_color')),
            stroke_color=parse_color(row.get('stroke_color')),
            stroke_width=row.get('stroke_width')
        )
    return shape


def main(input_file, conn, image_id, log_file):
    # Open log file
    with open(log_file, 'w') as log:
        df = pd.read_csv(input_file, sep='\t')
        for index, row in df.iterrows():
            msg = f"Processing row {index + 1}/{len(df)}: {row.to_dict()}"
            print(msg)
            log.write(msg + "\n")
            shape = create_shape(row)
            if shape:
                roi_name = row['roi_name'] if 'roi_name' in row else None
                roi_description = row['roi_description'] if 'roi_description' in row else None
                roi_id = post_roi(conn, image_id, [shape], name=roi_name, description=roi_description)
                msg = f"ROI ID: {roi_id} for row {index + 1}"
                print(msg)
                log.write(msg + "\n")
            else:
                msg = f"Skipping row {index + 1}: Unable to create shape"
                print(msg)
                log.write(msg + "\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Create shapes from a tabular file and optionally post them as an ROI to OMERO.")
    parser.add_argument("--input_file", help="Path to the input tabular file.")
    parser.add_argument("--image_id", type=int, required=True, help="ID of the image to which the ROI will be linked")
    parser.add_argument("--host", type=str, required=True, help="OMERO server host")
    parser.add_argument("--user", type=str, required=True, help="OMERO username")
    parser.add_argument("--psw", type=str, required=True, help="OMERO password")
    parser.add_argument("--port", type=int, default=4064, help="OMERO server port")
    parser.add_argument("--log_file", type=str, default="process.txt", help="Log file path")

    args = parser.parse_args()

    conn = connect(
        host=args.host,
        user=args.user,
        password=args.psw,
        port=args.port,
        group="",
        secure=True
    )

    try:
        main(args.input_file, conn, args.image_id, args.log_file)
    finally:
        conn.close()
