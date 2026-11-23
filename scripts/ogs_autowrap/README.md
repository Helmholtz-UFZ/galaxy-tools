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
* `TEST_OVERRIDES` – the fixture and parameter values each test needs.

## Tests

The generated tests are minimal by design: they check that the utility runs and
produces non-empty output (or a collection with at least one element). They are
not meant to validate the numerics of OGS.

```bash
planemo lint --fail_level warn tools/ogs
planemo test tools/ogs
```

## Why some utilities are not wrapped

`EXCLUDED_TOOLS` in `gen.py` lists 26 of the ~74 utilities, each for a concrete
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

### Need input that one Galaxy dataset cannot provide (7)

| Utility | Blocked by |
| --- | --- |
| `Layers2Grid`, `createLayeredMeshFromRasters`, `createTetgenSmeshFromRasters` | `-r/--raster-list` is an ASCII file listing raster *paths* that OGS resolves relative to the working directory. A single dataset cannot stage the rasters; the wrapper would have to generate the list file from a collection input. |
| `GocadSGridReader` | The `.sg` file references its property files by name, and those names carry no directory prefix (`SGrid_Testflow_simulation_grid_stair-stepped__points@@`), so they cannot be uploaded as separate datasets either. Without them: `error: Could not open points file`. |
| `PVD2XDMF` | The `.pvd` names a time series (`single_joint_ts_0_t_0.000000.vtu`, …) that must sit next to it; with a single staged `.pvd` the converter aborts on the first missing member. |
| `pvtu2vtu` | Same for the partition members of a `.pvtu` (`error: File 'x_0.vtu' does not exist.`). Note the *opposite* direction works: `postLIE` is wrapped through its single-mesh input. |
| `PartitionMesh` | Needs the METIS partition files `<base>.mesh.npart.N`/`.epart.N` next to the mesh, or an external `mpmetis` binary that the release does not ship. Otherwise: `Error: cannot open file …npart.2`. |

### Command line a wrapper cannot express yet (3)

| Utility | Blocked by |
| --- | --- |
| `editMaterialID` | Requires exactly one of `-c/-r/-s` (TCLAP required *XOR* group), which the generator does not model. The utility itself works (e.g. with `-r`), so this is a gap in the generator, not in the tool. |
| `createNeumannBc` | Needs a surface mesh carrying both `bulk_node_ids` and a *double* element property (it integrates a double cell property). No mesh under `Tests/Data` has a double element property, and OGS has no test for the utility to copy a setup from. |
| `queryMesh` | Takes a positional mesh argument and writes to stdout only — it creates no output file, so a wrapper could not produce a dataset. |

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
