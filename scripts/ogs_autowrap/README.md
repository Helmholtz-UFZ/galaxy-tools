# OGS utility wrappers

`gen.py` generates the Galaxy wrappers in [`tools/ogs`](../../tools/ogs) from the
command line definitions of the [OpenGeoSys](https://www.opengeosys.org)
`Applications/Utils` helpers. Nothing in `tools/ogs` is hand-maintained except
the `ogs_simulation` wrapper (which runs the `ogs` solver itself), so a wrapper
cannot drift away from the command line it wraps.

## Running

```bash
python scripts/ogs_autowrap/gen.py \
    --ogs-root /path/to/ogs-src \
    --output-dir tools/ogs \
    --generate-tools --generate-tests
```

`ogs-src` is a checkout of the OGS sources; the pinned commit is
`OGS_PINNED_COMMIT` in `gen.py`. Generation is offline and deterministic: no
network access is needed and the output depends only on the OGS *sources*, so
the result can be diffed in CI. `--check` verifies that the committed files
match what the generator would write:

```bash
python scripts/ogs_autowrap/gen.py --ogs-root ogs-src --output-dir tools/ogs --check
```

`--check-target <tool>` does the same for a single wrapper while developing.

## What is derived from where

| Wrapper element | Source in OGS |
| --- | --- |
| tool id, command, argument flags | the `TCLAP::CmdLine` definition in the utility's `.cpp` |
| `<description>`, `<help>` | the same `TCLAP` description and argument help strings |
| parameter types, `min`/`max` | the `TCLAP` argument types and the ranges stated in the help |
| input formats | the extensions listed in the argument help (`(.vtu \| .msh)`) |
| `<version>` | `macros.xml` (`@TOOL_VERSION@`, kept in sync with the OGS release) |
| tests | the fixtures named by `TEST_OVERRIDES`, downloaded from `OGS_PINNED_COMMIT` |

Curated tables near the top of `gen.py` record the few things the command line
does not state, all keyed by tool and parameter so they are easy to audit:

* `PARAM_EXT_OVERRIDES` – which of several accepted extensions the wrapper asks for.
* `OUTPUT_EXT_OVERRIDES` – the extension for outputs whose format OGS derives
  from the file name only.
* `BASE_FILENAME_OVERRIDES` – outputs that are a *base name* writing several
  files.
* `IMPLICIT_OUTPUTS` – utilities that write next to their input and take no
  output argument at all.
* `NON_PVD_INPUTS` – inputs that accept a `.pvd` *or* a single mesh; the
  wrapper exposes the single-mesh variant.
* `TEST_OVERRIDES` – the fixture and parameter values each test needs. A
  `<param>__members` entry lists the companion files a `.pvd` input references:
  they are staged as a collection under exactly the names the `.pvd` contains,
  which is also what makes a test for such a tool possible at all.

## Tests

The generated tests are minimal by design: they check that the utility runs and
produces non-empty output (or a collection with at least one element). They are
not meant to validate the numerics of OGS.

```bash
planemo lint --fail_level warn tools/ogs
planemo test tools/ogs
```

## Why some utilities are not wrapped

`EXCLUDED_TOOLS` in `gen.py` lists 25 of the ~74 utilities, each for a concrete
reason. The rule is that an entry must be blocked by something a wrapper cannot
work around — "the test is inconvenient to write" is not a reason.

### Not part of the released OGS build (8)

OGS compiles these utilities only when a build option is enabled that the
released binaries (conda-forge `ogs`) do not set, so there is no command to
wrap. The required option is in brackets.

| Utility | Build option |
| --- | --- |
| `NetCdfConverter` | `OGS_USE_NETCDF` |
| `binaryToPVTU` | `OGS_USE_MPI` |
| `SWMMConverter` | `OGS_BUILD_SWMM` |
| `Raster2PointCloud` | `OGS_BUILD_GUI` |
| `VerticalSliceFromLayers` | `OGS_BUILD_GUI` |
| `ConvertSHPToGLI` | `OGS_BUILD_GUI` |
| `Mesh2Shape` | `OGS_BUILD_GUI` |
| `OGSFileConverter` | not a CLI tool: Qt desktop application (file dialogs) |

### Only work with legacy `.vtk` meshes (5)

`VTK2OGS`, `VTK2TIN`, `TIN2VTK`, `convertVtkDataArrayToVtkDataArray` and
`mergeMeshToBulkMesh` read (or write) legacy `DATASET UNSTRUCTURED_GRID` files.
The released build contains no working legacy-VTK reader: a 4-point, 1-cell file
that VTK itself reads is reported as

```
error: Mesh 'tiny.vtk' contains zero points.
```

A wrapper around them would fail for every input that can be provided from
Galaxy, so they are excluded instead of shipped broken.

### Need input that one Galaxy dataset cannot provide (6)

**`Layers2Grid`, `createLayeredMeshFromRasters`, `createTetgenSmeshFromRasters`**
— "an ascii-file containing a list of input raster files". All three read that
file with `BaseLib::IO::readStringListFromFile()` (one path per line, trimmed,
blank lines skipped) and then hand the paths verbatim to
`readMeshFromFile()`/`FileIO::readRasters()`, i.e. they are resolved against the
*working directory*, not against the list file. Galaxy can stage *a* text file
but it would have to already contain the names the wrapper gave the raster
datasets — and the raster datasets themselves are exactly what is missing from
the single input the generator models (the generated wrapper symlinks the list
as `raster_list.txt`, and the run dies on its first line with
`error: Input layer 'layer1.asc' not found. Aborting...`). What would work is an
ordered collection of rasters (order = layer order, top DEM first) plus a
generated list file — a "derived text file from a collection" step the
generator does not have.

**`GocadSGridReader`** — the `.sg` file is a manifest, not the data:

```
name: flow_simulation_grid_stair-stepped
POINTS_FILE SGrid_Testflow_simulation_grid_stair-stepped__points@@
FLAGS_FILE  SGrid_Testflow_simulation_grid_stair-stepped__flags@@
PROPERTY 1 CELL_VOLUME_CORRECTION_FACTOR
```

The companion names are the *file stem* plus the grid name from inside the file,
with no directory separator, and they are opened relative to the working
directory. Uploading the `.sg` alone always ends in
`error: Could not open points file '…__points@@'`, and a user cannot name a
second dataset `SGrid_Testflow_simulation_grid_stair-stepped__points@@` in a way
that also follows whatever stem the `.sg` ends up with. A wrapper would have to
parse the `.sg` inside the job and symlink the companions of a collection onto
the names it declares — runtime logic well outside the generator.

**`pvtu2vtu`** — same shape one level up: the `.pvtu` is a manifest
(`<Piece Source="x_0.vtu"/>`) and the parts are read relative to the working
directory, so a staged `.pvtu` alone gives `error: File 'x_0.vtu' does not
exist.` and no output. In addition OGS ships no `.pvtu` fixture at all (they are
produced at test time by `partmesh`/`binaryToPVTU`, the latter needing
`OGS_USE_MPI`). The `.pvd` member mechanism that now makes `PVD2XDMF` testable
could be extended to `.pvtu`, but it would also need a vendored
`.pvtu` + member fixture.

**`PartitionMesh` (`partmesh`)** — `-x/--metis-mesh-input-file` is not a file
but a *base name*: the tool opens `<base>.mesh.npart.<np>` and
`<base>.mesh.epart.<np>`, where `<np>` is the `-n` value. With those two files
present it works (verified: 2 partitions, binary output files in the `-o`
directory), so the blocker is purely staging: a wrapper has to rename two
companion datasets so that they match both the base name of the mesh symlink and
a partition count the user picks. The generator has no "rename this input using
another parameter" step. The alternative `-m/--exe_metis` shells out to
`mpmetis`, which the released OGS does not ship.

### Command line a wrapper cannot express yet (3)

**`editMaterialID`** — the mode is a *required XOR group*:

```
editMaterialID {-c|-r|-s} [-e <point|line|quad|hex|tri|tet|pris|pyra>]
               [-m <id> ...] [-n <id>] -i <in> -o <out>
```

TCLAP enforces "exactly one of `--condense/--replace/--specify`"; without it the
run dies with `PARSE ERROR: Required argument missing: {replace | condense |
specify}`. The generator maps one TCLAP argument to one Galaxy parameter and has
no notion of a mutually exclusive group, so it would emit three independent
booleans, all optional, and every run would fail at parse time. The utility
itself is fine — with `-r` it runs and writes the output mesh — so the fix is in
the generator: a `select` for XOR groups (option labels from the
group's help texts) that maps to one switch.

**`createNeumannBc`** — needs a *2D surface mesh* (`Given mesh is no surface
mesh (dimension != 2).`), a node property `bulk_node_ids` to map back onto the
bulk mesh, **and** a *double* element property: it calls
`existsPropertyVector<double>(prop_name)` and rejects anything else with
`Need element property, but the property '…' is not available.` No mesh under
`Tests/Data` carries a double element property, and OGS has no ctest for the
utility, so there is no reference setup to derive a fixture from — every attempt
ended in `A PropertyVector with name 'bulk_node_ids' does not exist in the
mesh.` and no output. Wrappable after vendoring a small surface mesh with
`bulk_node_ids` plus one double cell property and pinning the property names.

**`queryMesh`** — `queryMesh [--show-node-with-max-elements] [-e <id> ...]
[-n <id> ...] mesh-file`: the mesh is a positional argument and the utility
writes *no file at all*, everything goes to stdout (that is its purpose:
interactive inspection). A wrapper would therefore consist of a `stdout_log`
dataset containing a human-readable dump, and the user would have to type node
and element ids as free text. The auto-derived test cannot even call it: passing
`-i mesh.vtu` gives `PARSE ERROR: Argument: mesh.vtu / Couldn't find match for
argument`, because the mesh is the unlabeled argument.

### Broken upstream (3)

| Utility | Symptom |
| --- | --- |
| `ReorderMesh` | Aborts on meshes without `bulk_node_ids` and segfaults (exit 139) on the ones that have it, e.g. `hex_27_cube_1x1x1_geometry_top_ts_0_t_0_000000_2.vtu`. |
| `CreateBoundaryConditionsAlongPolylines` | Always writes the node geometry as legacy `.gli`, which the released build cannot write: `error: Writing of geometry failed, since it was not possible to determine the required format from file extension.` The `.bc` is written, the geometry output would be permanently missing. |
| `TecPlotTools` | Reads binary TecPlot `.plt` files; OGS ships no such file, so there is no fixture to test a wrapper with. |

## Adding a wrapper

1. Run the generator; if the utility shows up in the output, check that the
   derived arguments, formats and ranges are right.
2. Give the test a fixture and parameter values through `TEST_OVERRIDES` (the
   auto-derived ones only match the *extension*, not the meaning of an input).
3. Run `planemo lint --fail_level warn` and `planemo test` on the new tool.
4. If the utility cannot be wrapped at all, add it to `EXCLUDED_TOOLS` **with
   the concrete failure** as a comment, and to the tables above.
