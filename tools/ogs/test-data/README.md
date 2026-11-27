# Fixtures used by the OGS wrapper tests

Most test inputs are **not** stored here: the generated tests download them
from OGS's own `Tests/Data` at the commit pinned in
[`gen.py`](../../scripts/ogs_autowrap/gen.py) (`OGS_TEST_DATA_COMMIT`). Only
files OGS does not ship are vendored here, and every one of them is named in the
generator's curated tables or in `ogs_simulation.xml`, so nothing in this
directory is accidental.

## The `ogs_simulation` project bundle

A simulation needs a project file *plus* the mesh and the referenced XML/`.gml`
files, and it refers to them by their plain file names. The bundle is therefore
uploaded as a collection whose element names match the references:

| File | Role |
| --- | --- |
| `square_1e0_neumann.prj` | the project file the test starts from (`<param name="project_file">`) |
| `square_1e0.xml`, `square_neumann.xml` | the simulation settings the `.prj` references |
| `square_1x1.gml` | the geometry the settings describe |
| `square_1x1_quad_1e0.vtu` | the mesh of the 1x1 square |
| `square_1e0_neumann_neumann.pvd` | the expected result collection, listing … |
| `square_1e0_neumann_neumann_ts_0_t_0.000000.vtu`, `…_ts_1_t_1.000000.vtu` | … the two time steps it names |

## Placeholder inputs of the generated tests

A tool whose input has no override gets the extension-based placeholder from
`get_dummy_value()`, which for an extension OGS test data has no analogue for is
simply `test.<ext>`. Those names are what the wrappers' tests upload, so they
have to exist:

| File | Used by |
| --- | --- |
| `test.gml` | `MoveGeometry` (`--input`) |
| `test.asc` | `CreateMeshElemPropertiesFromASCRaster` (`--raster-file`) |

## `PVTU2VTU` partition data

| File | Role |
| --- | --- |
| `pvtu2vtu_input.pvtu` | the `.pvtu` header, referencing the two parts |
| `pvtu2vtu_part_0.vtu`, `pvtu2vtu_part_1.vtu` | the two partitions, each with `global_node_ids`, `global_element_ids` and `vtkGhostType` |
| `pvtu2vtu_original_mesh.vtu` | the unpartitioned mesh the data must be transferred onto |

OGS's own `.pvtu` fixtures (`Tests/Data/Utils/PVTU2VTU/`) have no
`global_node_ids`, so `pvtu2vtu --original_mesh` cannot be exercised with them —
the tool aborts with "The data array 'global_node_ids' is required for the
transfer of data from subdomain mesh to the global mesh". These four files were
generated, not hand-written:

```bash
python scripts/ogs_autowrap/make_test_fixtures.py
```

They are committed because the test needs them; re-running the script rewrites
them byte for byte.
