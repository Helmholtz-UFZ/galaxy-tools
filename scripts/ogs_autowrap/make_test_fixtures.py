"""Build the vendor-neutral fixtures in ``tools/ogs/test-data``.

Most test inputs are downloaded from OGS's own ``Tests/Data`` (see
``_fixture_url`` in ``gen.py``); the files this script writes are the ones OGS
does not ship, so they have to be created here and committed.

The ``pvtu2vtu`` set is a hand-made two-partition mesh. OGS's own ``.pvtu``
fixtures have no ``global_node_ids``/``global_element_ids`` arrays, so
``pvtu2vtu --original_mesh`` -- the option that transfers the subdomain data
onto the unpartitioned mesh -- aborts with "The data array 'global_node_ids' is
required for the transfer of data from subdomain mesh to the global mesh".
Aborting is the only thing OGS's test data can prove, so the wrapper test uses
this mesh instead.

Run from the repository root::

    python scripts/ogs_autowrap/make_test_fixtures.py
"""

import argparse
from pathlib import Path

DEFAULT_OUTPUT_DIR = Path(__file__).resolve().parents[2] / "tools" / "ogs" / "test-data"

ORIGINAL = "pvtu2vtu_original_mesh.vtu"
PVTU = "pvtu2vtu_input.pvtu"
PARTS = ["pvtu2vtu_part_0.vtu", "pvtu2vtu_part_1.vtu"]

# The unpartitioned mesh: a unit square split into two triangles.
NODES = [(0.0, 0.0, 0.0), (1.0, 0.0, 0.0), (1.0, 1.0, 0.0), (0.0, 1.0, 0.0)]
TRIANGLES = [(0, 1, 2), (0, 2, 3)]

VTK_TRIANGLE = "5"


def vtu(points, triangles, point_data, cell_data):
    """Serialise one ASCII ``UnstructuredGrid`` as a VTU file."""
    lines = [
        '<?xml version="1.0"?>',
        '<VTKFile type="UnstructuredGrid" version="0.1" '
        'byte_order="LittleEndian" header_type="UInt64">',
        "  <UnstructuredGrid>",
        f'    <Piece NumberOfPoints="{len(points)}" '
        f'NumberOfCells="{len(triangles)}">',
        "      <PointData>",
    ]
    lines += _data_arrays(point_data, indent="        ")
    lines += ["      </PointData>", "      <CellData>"]
    lines += _data_arrays(cell_data, indent="        ")
    lines += [
        "      </CellData>",
        "      <Points>",
        '        <DataArray type="Float64" Name="Points" '
        'NumberOfComponents="3" format="ascii">',
        "          " + " ".join(f"{x} {y} {z}" for x, y, z in points),
        "        </DataArray>",
        "      </Points>",
        "      <Cells>",
        '        <DataArray type="Int64" Name="connectivity" format="ascii">',
        "          " + " ".join(str(i) for t in triangles for i in t),
        "        </DataArray>",
        '        <DataArray type="Int64" Name="offsets" format="ascii">',
        "          " + " ".join(str(offset) for offset in _offsets(triangles)),
        "        </DataArray>",
        '        <DataArray type="UInt8" Name="types" format="ascii">',
        "          " + " ".join(VTK_TRIANGLE for _ in triangles),
        "        </DataArray>",
        "      </Cells>",
        "    </Piece>",
        "  </UnstructuredGrid>",
        "</VTKFile>",
        "",
    ]
    return "\n".join(lines)


def _data_arrays(arrays, indent):
    lines = []
    for name, dtype, values in arrays:
        lines.append(
            f'{indent}<DataArray type="{dtype}" Name="{name}" '
            f'NumberOfComponents="1" format="ascii">'
        )
        lines.append(f"{indent}  " + " ".join(str(value) for value in values))
        lines.append(f"{indent}</DataArray>")
    return lines


def _offsets(triangles):
    offsets, total = [], 0
    for triangle in triangles:
        total += len(triangle)
        offsets.append(total)
    return offsets


def write_fixtures(output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)

    # The original, unpartitioned mesh, with properties that the transfer must
    # leave alone.
    (output_dir / ORIGINAL).write_text(
        vtu(
            NODES,
            TRIANGLES,
            [
                ("temperature", "Float64", [10.0, 20.0, 30.0, 40.0]),
                ("gravity", "Float64", [0.0, 0.0, -9.81, 0.0]),
            ],
            [("cell_marker", "Int32", [1, 2])],
        )
    )

    # Two partitions. The ``part_*`` properties exist only here, so a test can
    # tell whether the transfer happened at all; ``global_*_ids`` index back
    # into the original mesh, and ``vtkGhostType`` only has to be present (the
    # tool requires it before it looks at ``--original_mesh``).
    partitions = [
        # (global node ids, global element ids, node values, cell values)
        ([0, 1, 2], [0], [10.0, 20.0, 30.0], [1]),
        ([0, 2, 3], [1], [10.0, 30.0, 40.0], [2]),
    ]
    for index, (node_ids, element_ids, values, markers) in enumerate(partitions):
        points = [NODES[node] for node in node_ids]
        local_triangle = tuple(range(len(node_ids)))
        (output_dir / PARTS[index]).write_text(
            vtu(
                points,
                [local_triangle],
                [
                    ("part_temperature", "Float64", values),
                    ("global_node_ids", "UInt64", node_ids),
                    ("vtkGhostType", "UInt8", [0] * len(node_ids)),
                ],
                [
                    ("part_cell_marker", "Int32", markers),
                    ("global_element_ids", "UInt64", element_ids),
                ],
            )
        )

    pieces = "\n".join(f'      <Piece Source="{name}"/>' for name in PARTS)
    (output_dir / PVTU).write_text(
        '<?xml version="1.0"?>\n'
        '<VTKFile type="PUnstructuredGrid" version="0.1" '
        'byte_order="LittleEndian">\n'
        '  <PUnstructuredGrid GhostLevel="0">\n'
        "    <PPoints>\n"
        '      <PDataArray type="Float64" NumberOfComponents="3"/>\n'
        "    </PPoints>\n"
        f"{pieces}\n"
        "  </PUnstructuredGrid>\n"
        "</VTKFile>\n"
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=DEFAULT_OUTPUT_DIR,
        help="directory the fixtures are written to (default: tools/ogs/test-data)",
    )
    args = parser.parse_args()
    write_fixtures(args.output_dir)
    for name in [ORIGINAL, PVTU] + PARTS:
        size = (args.output_dir / name).stat().st_size
        print(f"{name}: {size} B")


if __name__ == "__main__":
    main()
