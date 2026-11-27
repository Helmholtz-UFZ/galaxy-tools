# OpenGeoSys utilities for Galaxy

Galaxy wrappers for the helper utilities in OpenGeoSys's `Applications/Utils`
(`MeshEdit`, `MeshGeoToolsLib`, `FileIO`, `VoxelGrid`, …): mesh conversion,
editing and inspection.

The wrappers are **generated**, not written by hand: `gen.py` reads the
`TCLAP::CmdLine` definition of every utility and derives the tool id, the
arguments, the parameter types, the formats and the tests from it. Do not edit
the `.xml` files in this directory — change the generator
([`scripts/ogs_autowrap`](../../scripts/ogs_autowrap)) and regenerate:

```bash
python scripts/ogs_autowrap/gen.py --ogs-root ogs-src --output-dir tools/ogs \
    --generate-tools --generate-tests
```

The only exception is `ogs_simulation.xml`, which runs the `ogs` solver itself
rather than a `Applications/Utils` helper, so there is no command line to derive
it from.

## Requirements

Every wrapper needs the `ogs` utilities on `PATH` (conda-forge package `ogs`,
see the suite's `macros.xml`). The tools in this suite only *inspect* and
convert meshes; running a simulation needs the separate `ogs_simulation` tool
plus the project bundle it is given.

## Testing

```bash
planemo lint --fail_level warn tools/ogs
planemo test tools/ogs
```

`tools/ogs/test-data` holds the few fixtures that are not part of OGS's own
test data (see its README). The remaining fixtures are fetched from the pinned
OGS commit named in `gen.py`.
