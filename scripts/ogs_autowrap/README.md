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
`PARAM_EXT_OVERRIDES`, `MANIFEST_INPUTS`, `EXCLUSIVE_MODES`, `TEXT_VALIDATORS`,
`EXCLUDED_TOOLS`, …) against the OGS sources: they are consulted with `dict.get` all over the generator, so a key
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
| tests | the fixtures named by `TEST_OVERRIDES`, downloaded from `OGS_TEST_DATA_COMMIT` |

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
* `DATATYPE_MAP` – the Galaxy datatype of every OGS file extension (see
  "Datatypes").
* `TEST_OVERRIDES` – the fixture and parameter values each test needs. A
  `<param>__members` entry lists the files of a collection input: they are
  staged under exactly the names the manifest (or `.pvd`) contains, which is
  also what makes a test for such a tool possible at all.
* `EXTRA_TESTS` – further test cases for code paths the upstream ctest entry
  does not reach (see "Tests").

## Tests

The generated tests are minimal by design: they check that the utility runs and
produces non-empty output (or a collection with at least one element). They are
not meant to validate the numerics of OGS.

Each wrapped tool gets the test the upstream `AddTest` entry describes. Where
the wrapper exposes something OGS itself does not test, `EXTRA_TESTS` adds a
second `<test>` on top of it: it starts from the generated case, applies its own
overrides and *adds* assertions. The one entry currently needed is
`pvtu2vtu --original_mesh`, the option that transfers the subdomain data onto
the unpartitioned mesh through `global_node_ids` — upstream's `.pvtu` fixtures
have no such array, so the failure it guards against ("The data array
'global_node_ids' is required … but it doesn't exist") only shows up with a
vendored mesh.

Fixtures come from two places, both spelled out in the curated tables:

* a path inside OGS's `Tests/Data`, downloaded from `OGS_TEST_DATA_COMMIT`
  (a *published* commit — the test-data pin is separate from
  `OGS_PINNED_COMMIT` so a wrapper may depend on a fix that is not on `master`
  yet while its test data stays fetchable),
* `("local", "file.vtu")` or `local:file.vtu` for a file vendored in
  `tools/ogs/test-data`; Galaxy copies it from `--test_data`, so the `<param>`
  or `<element>` carries no `location`.

The curated-table audit fails when a vendored fixture it names is not in
`test-data`, which is how the unused files were pruned.

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
  ln -sf '$item' '$safe_name';
  echo '$safe_name' >> 'raster_list.txt';
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
  ln -sf '$item' '$safe_name';
  #end for
  ```

  Used by `GocadSGridReader` and `pvtu2vtu`.

In both cases the collection elements are staged under the names they were
uploaded with, so the names inside the manifest keep matching.
`TEST_OVERRIDES` supplies the collection contents through `<param>__members`.

The element identifier is user-controlled, so it is sanitized before it is used
as a file name (the `logs` of a tool that does not do this end up with a
half-linked directory):

```
#import re
#set $safe_names = [re.sub(r'[^\w\-.@]', '_', str($item.element_identifier)) for $item in $input]
#if len($safe_names) != len(set($safe_names))
    echo 'error: the element identifiers map to the same file name ...' >&2;
    exit 1;
#end if
```

`@` is kept on purpose: OGS Gocad SGrid data files are called
`…_points@@`, and the `.sg` header references them by that name. The collision
check exists because replacing characters can map two identifiers onto one file
name, which would silently feed the same file twice; the job fails instead.

## Text parameters

Names, ids and array names are passed as flag values, i.e. the command renders
them as `--property-name '$property_name'`. An unvalidated text field that
reaches that command can therefore end the quoting and run arbitrary commands,
so the wrappers do **not** set `<sanitizer sanitize="false"/>`:

```
'; rm -rf ~         ->  --property-name ''; rm -rf ~'
```

Galaxy's default sanitiser is what stops that: it lets no `'`, `"`, `` ` ``,
`\`, `$`, `;` or any other shell metacharacter through. It does not reject
them silently either — it *rewrites* them (`'` becomes `__sq__`, `;` becomes
`X`), which would hand OGS a different name than the user asked for. So every
text parameter additionally gets an explicit validator covering exactly the
characters Galaxy passes through unchanged (`galaxy.util.valid_chars`):

```xml
<param argument="--property-name" type="text" optional="false" label="property name" help="name of property in the mesh">
  <validator type="empty_field" />
  <validator type="regex" message="only letters, digits, spaces and the characters = - _ . ( ) / + * ^ , : ? ! are allowed">^[A-Za-z0-9 =\-_.()/+*^,:?!]+$</validator>
</param>
```

A value outside that set is now rejected with a readable message instead of
being passed on mangled, and nothing that could terminate the single-quoted
shell word is ever accepted. The pattern does not have to allow the empty
string: Galaxy skips validators for an empty *optional* value, and a required
field hits `<validator type="empty_field"/>` first.

Where the OGS source constrains the value itself, `TEXT_VALIDATORS` replaces the
generic pattern and states the constraint in OGS's words:

| tool | parameter | pattern | source |
| --- | --- | --- | --- |
| `swapNodeCoordinateAxes` | `--new-order` | `^[xyz]{3}$` | `parseNewOrder()` requires three characters, each `x`, `y` or `z` (it also rejects repetitions; a regex cannot express that, OGS reports it) |
| `ResetPropertiesInPolygonalRegion` | `--char-property-value` | a single character | the argument is a TCLAP `ValueArg<char>` |

To add one, key `TEXT_VALIDATORS` by `(tool name in lower case, parameter
variable name)`; the curated-table audit checks that the key names a real
parameter, that the pattern compiles and that a message is given.

## Datatypes

`DATATYPE_MAP` maps every OGS extension to a Galaxy datatype, and the wrapper
takes its `format` from there -- never from the free help text. Only formats
Galaxy actually ships are used, so an uploaded file is validated, displayed and
accepted by the next wrapper without conversion:

| OGS extension | Galaxy datatype | note |
| --- | --- | --- |
| `.vtu`, `.vtk`, `.pvtu`, `.pvd` | `vtkxml` | the OGS build reads VTK XML only |
| `.msh` | `gmsh.msh` as input, `txt` as output | Gmsh mesh in, legacy OGS-5 mesh out (ASCII) |
| `.gml`, `.xml`, `.prj`, `.xdmf` | `xml` | Galaxy's `prj` is an *Athena* project file, not an OGS one |
| `.sg` | `gocad.sg` | |
| `.fem` | `feflow.fem` | |
| `.asc`, `.grd` | `raster.asc` | |
| `.ts`, `.pl`, `.mx` | `txt` | Gocad surfaces/lines/meshes are ASCII, not XML |
| `.gli`, `.smesh`, `.geo`, `.tin`, `.mesh` | `txt` | ASCII, no dedicated Galaxy type |
| `.plt`, `.bin` | `binary` | *not* text: binary TecPlot, raw dumps |
| `.csv`, `.json`, `.nc`, `.h5` | `csv`, `json`, `netcdf`, `h5` | |
| anything else | `data` | generation warns, so the gap is visible |

Galaxy cannot split one input into several types, and OGS picks its reader from
the *file extension*. Where an argument documents several extensions
(`Input (.gli | .gml)`), the wrapper accepts the first one and the help says so:

```
<param argument="--geometry" help="Input (.gli | .gml). … (the wrapper accepts .gml only)" format="xml"/>
```

`GMSH2OGS` deserves a note: its `--out` is a file name whose extension selects
the *writer*, and `.msh` would produce the legacy OGS-5 format. The wrapper asks
for `.vtu` (what the OGS test suite checks) so the mesh can be used by every
other utility.

There is no generic "OGS" datatype and no `datatypes_conf.xml` in this
repository: every format above is one Galaxy ships itself, so a user does not
have to install our definitions to open a result. Galaxy's own definitions live
in `lib/galaxy/config/sample/datatypes_conf.xml.sample` and
`lib/galaxy/datatypes/`; `binary` is `data` with the text conversion disabled,
which is why it is the right choice for `.plt`/`.bin` (a `txt` input is run
through the text sanitiser, a `binary` one is passed through byte for byte).

One wrapper still declares the generic `data`: `ogs_simulation` takes the whole
project *bundle* (`.prj`, `.xml`, `.gbc`, `.gli`, `.vtu`, …) as a collection, so
no single existing type describes its members. The generated wrappers only use
`data` for an extension `DATATYPE_MAP` does not know, and warn when that
happens.

## Mutually exclusive switches

TCLAP `xorAdd()` groups accept *exactly one* of several switches, and each
switch brings its own arguments — `editMaterialID` is the case in point:

```
editMaterialID {-c|-r|-s} [-e <point|line|quad|hex|tri|tet|pris|pyra>]
               [-m <id> ...] [-n <id>] -i <in> -o <out>
```

Three independent booleans would let a user tick none of them (the utility then
prints its usage and writes no output) or several (`PARSE ERROR: Required
argument missing`). `EXCLUSIVE_MODES` instead declares a `<conditional>`:

* the switches are removed from the flat input list and become the options of a
  `select` (`optional="false"`, so one is always set),
* the parameters a mode needs move into that mode's `<when>` and are *required*
  there (a parameter used by several modes, like `--new-material-id`, is
  repeated in each branch),
* the command renders the branches with Mako:

  ```
  #if str($mode.mode) == "replace"
      --replace
      --current-material-id '$mode.current_material_id'
      --new-material-id '$mode.new_material_id'
  #elif str($mode.mode) == "condense"
      --condense
  #elif str($mode.mode) == "specify"
      --specify
      --element-type '$mode.element_type'
      --new-material-id '$mode.new_material_id'
  #end if
  ```

A tool whose utility writes no file at all gets a `stdout_log` dataset instead
(`checkMesh`, `queryMesh`): the command captures stdout, which for these
two is the actual result rather than logging.

One limitation: a `MultiArg` *numeric* argument (`-e <id> ...`) is passed once.
Galaxy has no list type for numeric parameters (`multiple` exists for
`select`/`data` only), so the generated help text says so instead of silently
accepting one value.

## Why some utilities are not wrapped

`EXCLUDED_TOOLS` in `gen.py` lists 18 of the ~74 utilities, each for a concrete
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

### Command line a wrapper cannot express yet (1)

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
