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

Every run first audits the curated tables (`TEST_OVERRIDES`,
`PARAM_EXT_OVERRIDES`, `MANIFEST_INPUTS`, `EXCLUDED_TOOLS`, …) against the OGS
sources: they are consulted with `dict.get` all over the generator, so a key
that names a tool or parameter that does not exist -- a typo, or a rename
upstream -- would otherwise be ignored without a word, silently dropping the
override or degrading a test to the dummy recipe. A key that resolves to
nothing is reported with a suggestion and the run stops with exit code 2
(`--check` exits 1 on a wrapper that is out of sync, so scripts can tell the
two apart):

```
curated tables do not match the OGS tree (2 problem(s)):
  TEST_OVERRIDES['gocadtsurfacereader']['input']: not a parameter of that wrapper (did you mean 'input_file'?)
  OUTPUT_EXT_OVERRIDES[('convertgeo', 'output_file')]: no such output argument (did you mean 'output-file'?)
```

The audit itself is unit-tested against synthetic tables (no OGS tree needed):

```bash
python -m unittest discover -s scripts/ogs_autowrap -p 'test_*.py'
```

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
* `MANIFEST_INPUTS` – arguments that name further files instead of carrying
  data; the files are exposed as a collection (see "Manifest inputs").
* `TEST_OVERRIDES` – the fixture and parameter values each test needs. A
  `<param>__members` entry lists the files of a collection input: they are
  staged under exactly the names the manifest (or `.pvd`) contains, which is
  also what makes a test for such a tool possible at all.

## Tests

The generated tests are minimal by design: they check that the utility runs and
produces non-empty output (or a collection with at least one element). They are
not meant to validate the numerics of OGS.

```bash
planemo lint --fail_level warn tools/ogs
planemo test tools/ogs
```

## Manifest inputs

Several utilities do not read the data they are given: they read a file that
*names* further files, and resolve those names against their working directory.
A Galaxy dataset for the manifest alone is therefore useless. For those
arguments `MANIFEST_INPUTS` declares what the manifest refers to, and the
wrapper exposes the referenced files themselves as a collection:

* `file_list` – the argument is an ASCII file listing the inputs
  (`readStringListFromFile`). The collection *is* the input; the command links
  every element under its own name and writes the list file on the fly, so its
  order is the collection's order:

  ```
  : > 'raster_list.txt';
  #for $item in $raster_list
  ln -sf '$item' '$item.element_identifier';
  echo '$item.element_identifier' >> 'raster_list.txt';
  #end for
  ```

  Used by `Layers2Grid`, `createLayeredMeshFromRasters`,
  `createTetgenSmeshFromRasters` (order = top layer first).

* `companion_names` – the argument is a header that references its data by its
  exact file name (`.sg` → `POINTS_FILE …__points@@`, `.pvtu` →
  `<Piece Source="…_0.vtu"/>`). The dataset stays a normal input and the
  collection members are staged under their own names:

  ```
  #for $item in $input_members
  ln -sf '$item' '$item.element_identifier';
  #end for
  ```

  Used by `GocadSGridReader` and `pvtu2vtu`.

In both cases the collection elements keep the names they were uploaded with,
so the names inside the manifest keep matching. `TEST_OVERRIDES` supplies the
collection contents through `<param>__members`.

## Why some utilities are not wrapped

`EXCLUDED_TOOLS` in `gen.py` lists 20 of the ~74 utilities, each for a concrete
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

### Takes a partition *base name* rather than files (1)

**`PartitionMesh` (`partmesh`)** — `-x/--metis-mesh-input-file` is not a file but
a base name: the tool opens `<base>.mesh.npart.<np>` and `<base>.mesh.epart.<np>`,
where `<np>` is the `-n` value. With those two files present it works (verified:
2 partitions, binary output files in the `-o` directory), but they have to be
named after the mesh *and* contain the partition count the user picks, which no
staging scheme can guarantee. Creating them is the point of `mpmetis`, which the
released OGS does not ship (`-m/--exe_metis` shells out to it), so the only
usable input is a pre-partitioned mesh that the caller has to prepare elsewhere.

The manifest-style inputs (raster lists, `.sg`, `.pvtu`) are *not* in this list
any more — see "Manifest inputs" for how they are wrapped.

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
