import argparse
import logging
import re
import shlex
import sys
import tempfile
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Any, Dict, List, Tuple

from galaxyxml.tool import Tool
from galaxyxml.tool.parameters import (
    BooleanParam,
    DataParam,
    DiscoverDatasets,
    Expand,
    FloatParam,
    Inputs,
    IntegerParam,
    OutputCollection,
    OutputData,
    Outputs,
    SelectParam,
    Tests,
    TextParam,
)

# --- CONFIGURATION ---
# The generator works from a *local* clone of the OGS source tree (no network
# required). The OGS root is supplied on the command line (see main()); the
# directories below are resolved relative to it.
UTILS_PATH = "Applications/Utils"
TEST_DATA_PATH = "Tests/Data"

# Test fixtures are referenced from the *official* OGS repository, pinned to a
# specific commit. The generator never points at a personal fork. When the local
# OGS clone is generated from, its HEAD commit is stamped here so the pinned URL
# and the source of the wrappers always agree.
OGS_GITLAB_RAW = "https://gitlab.opengeosys.org/ogs/ogs/-/raw"
OGS_PINNED_COMMIT = "8ffec079b9ce8764ab565c6470839b34033bc718"
OGS_TEST_DATA_URL = f"{OGS_GITLAB_RAW}/{OGS_PINNED_COMMIT}/{TEST_DATA_PATH}"

# Tools with broken executable commands (the conda ``ogs`` package does not ship a
# working binary for these, so a wrapper would fail at runtime).
# Utilities that are *not* wrapped. Every entry is justified by something a
# wrapper cannot work around -- see scripts/ogs_autowrap/README.md for the
# long form. Do not add a tool here because writing its test is inconvenient.
EXCLUDED_TOOLS = [
    # --- Not part of the released OGS build -------------------------------
    # OGS compiles these only with a build option the release does not enable,
    # so there is simply no command to wrap. Required option in brackets.
    "netcdfconverter",  # [OGS_USE_NETCDF]
    "binarytopvtu",  # [OGS_USE_MPI]
    "swmmconverter",  # [OGS_BUILD_SWMM]
    "raster2pointcloud",  # [OGS_BUILD_GUI]
    "verticalslicefromlayers",  # [OGS_BUILD_GUI]
    "convertshptogli",  # [OGS_BUILD_GUI]
    "mesh2shape",  # [OGS_BUILD_GUI]
    # Qt desktop application (file dialogs, no usable command line at all).
    "ogsfileconverter",
    # --- Only work with legacy ``.vtk`` meshes ----------------------------
    # The released build has no working legacy-VTK reader: a 4-point/1-cell
    # file that VTK itself reads fine is reported as "contains zero points".
    "vtk2ogs",
    "vtk2tin",
    "tin2vtk",
    "convertvtkdataarraytovtkdataarray",
    "mergemeshtobulkmesh",
    # --- Need input a single Galaxy dataset cannot provide ----------------
    # An ASCII file listing rasters whose paths are resolved relative to the
    # working directory; the rasters themselves cannot be staged from that one
    # dataset (the wrapper would have to build the list from a collection).
    "layers2grid",
    "createlayeredmeshfromrasters",
    "createtetgensmeshfromrasters",
    # ``.sg`` / ``.pvd`` / ``.pvtu`` files reference companion files by name
    # (property files without any directory prefix, time series, partition
    # members). Missing members make the utilities abort.
    "gocadsgridreader",
    "pvd2xdmf",
    "pvtu2vtu",
    # Needs the METIS partition files ``<base>.mesh.npart.N`` / ``.epart.N``
    # next to the input; without them -- or an external ``mpmetis``, which the
    # release does not ship -- it aborts.
    "partitionmesh",
    # Reads binary TecPlot ``.plt`` files; OGS ships no such file to test with.
    "tecplottools",
    # --- Command line a wrapper cannot express (yet) ----------------------
    # Requires exactly one of ``-c/-r/-s``: TCLAP's required *XOR* group is not
    # modelled by the generator. (The utility itself works, e.g. with ``-r``.)
    "editmaterialid",
    # Needs a surface mesh carrying both ``bulk_node_ids`` and a *double*
    # element property; no mesh under ``Tests/Data`` has a double element
    # property and OGS has no test for the utility to copy a setup from.
    "createneumannbc",
    # Positional mesh argument and stdout-only output (it writes no file), so
    # a Galaxy wrapper could not produce a dataset.
    "querymesh",
    # Aborts on meshes without ``bulk_node_ids`` and segfaults on the ones
    # that have it (exit 139).
    "reordermesh",
    # Always writes its node geometry as legacy ``.gli``, which the released
    # build cannot write ("not possible to determine the required format from
    # file extension"); the ``.bc`` it does write would always be accompanied
    # by a missing geometry output.
    "createboundaryconditionsalongpolylines",
]

# NOTE: there is deliberately no list of hand-maintained wrappers here. Every
# wrapper in ``tools/ogs`` except ``ogs_simulation`` (which runs the ``ogs``
# binary itself, not an ``Applications/Utils`` helper) is generated, so a
# wrapper can never drift from the OGS command line it wraps. Tools that used
# to be hand-written keep their tool id (``ogs_<lowercase tool name>``), so
# saved workflows continue to resolve.

# Directory (relative to the job working directory) that utilities taking an
# *output directory* write their files into.
DIRECTORY_OUTPUT_DIR = "outputs"

# Outputs whose help text does not name a file extension (OGS derives the
# format from the file name the caller passes), keyed by
# ``(tool_name.lower(), long_flag)``.
OUTPUT_EXT_OVERRIDES = {
    # "Output. The name of the new geometry file whose file format is
    # determined by its file extension" -- the released OGS only has the GML
    # writer compiled in, so the wrapper must ask for ``.gml``.
    ("convertgeo", "output-file"): "gml",
}

# Utilities that write their results *next to the input geometry* without
# taking an output argument at all: the output name is built from the polygon
# names inside the GML. The inputs are symlinked into the job working
# directory, so the files land there and can be discovered; each entry is one
# list collection of discovered datasets.
IMPLICIT_OUTPUTS = {
    "computesurfacenodeidsinpolygonalregion": [
        {
            "name": "node_ids_txt",
            "pattern": r"(?P<designation>.*)\.txt",
            "format": "txt",
            "label": "Node ids and areas (plain text)",
        },
        {
            "name": "node_ids_csv",
            "pattern": r"(?P<designation>.*)\.csv",
            "format": "csv",
            "label": "Node ids and areas (CSV)",
        },
    ],
}

# Tools whose ``--output-file`` argument is really a *base name* that the
# utility extends with its own suffixes (the TCLAP help does not say so).
# ``pattern``/``format`` describe the files to discover; ``extra_outputs``
# lists additional fixed files written alongside them.
BASE_FILENAME_OVERRIDES = {
    "extractmaterials": {
        "flag": "output",
        "base_value": "output.vtu",
        "pattern": r"(?P<designation>output_.*)\.vtu",
        "format": "vtkxml",
        "extra_outputs": [
            {
                "name": "layer_info",
                "from_work_dir": "output_Layers.txt",
                "format": "txt",
                "label": "Layer/material table",
            }
        ],
    },
    "createintermediaterasters": {
        "flag": "output-file",
        "base_value": "output_.asc",
        "pattern": r"(?P<designation>output_.*)\.asc",
        "format": "raster.asc",
    },
    # ComputeNodeAreasFromSurfaceMesh always writes ``<base>.csv`` and
    # ``<base>.txt`` (the base name is the only thing its output flag controls),
    # so both files are declared explicitly. Discovering them instead would put
    # the wrapper's own base-name prefix into the element designations -- and
    # force one format on both files.
    "computenodeareasfromsurfacemesh": {
        "flag": "output-base-name",
        "base_value": "node_areas",
        "outputs": [
            {
                "name": "node_areas_csv",
                "from_work_dir": "node_areas.csv",
                "format": "csv",
                "label": "Node areas (CSV)",
            },
            {
                "name": "node_areas_txt",
                "from_work_dir": "node_areas.txt",
                "format": "txt",
                "label": "Node areas (plain text)",
            },
        ],
    },
}

# Inputs where OGS chooses the reader from the file extension but the help text
# lists several extensions. The default is the first one from the help text;
# these entries select the format the OGS test data actually uses.
PARAM_EXT_OVERRIDES = {
    # "(.gli | .gml)" -- the GML reader is the one that parses XML geometries.
    ("resetpropertiesinpolygonalregion", "geometry"): "gml",
    # The help says "(.msh)", but the released OGS build can only read VTK-XML
    # meshes here: a ``.msh`` input sends it down the legacy reader, which
    # fails without any diagnostic.
    ("ogs2vtk", "mesh_input_file"): "vtu",
}

# ``-i/--input-file`` arguments that accept either a ``.pvd`` or a single mesh.
# They are exposed as the single-mesh variant: a PVD would additionally need
# the member files it references, which the wrapper cannot stage.
NON_PVD_INPUTS = {
    ("postlie", "input_file"),
}

# Curated test inputs, keyed by tool (lower case) and parameter variable name.
# The auto-derived fixtures only match a tool's input *extension*, not its
# semantics; these entries pin the value a tool actually needs.
#
#   "Some/Path/in/Tests/Data.msh" -> downloaded from the pinned OGS commit
#   ("local", "file.ext")         -> vendored in tools/ogs/test-data/
#
# Non-data parameters (text/integer/select) take the literal value.
TEST_OVERRIDES = {
    "raster2asc": {"input": "FileIO/GrdTest.grd"},
    "swapnodecoordinateaxes": {"new_order": "xzy"},
    "appendlinesalongpolyline": {
        "geo_file": "MeshGeoToolsLib/ResetPropertiesInPolygonalRegion/Polylines.gml",
        "gmsh_path": None,
    },
    "converttolinearmesh": {
        "input_mesh_file": (
            "MeshGeoToolsLib/ConstructMeshesFromGeometry/square_1x1_quad8_1e2.vtu"
        ),
    },
    "convertgeo": {
        "input_file": "MeshGeoToolsLib/ConstructMeshesFromGeometry/square_1x1.gml",
        "gmsh_path": None,
    },
    "createanchors": {
        "input": "HydroMechanics/EmbeddedAnchorSourceTerm/cube_1x1x1_hex_1e3.vtu",
        "json_file": "HydroMechanics/EmbeddedAnchorSourceTerm/data_3D.json",
    },
    "gocadtsurfacereader": {"input": "MeshLib/Top-Lower-Shaly.ts"},
    "ogs2vtk": {"mesh_input_file": "MeshGeoToolsLib/Naegelstedt/SmallTest.vtu"},
    "generatematpropsfrommatid": {"mesh": "MeshGeoToolsLib/Bode/BodeComplex.msh"},
    "computenodeareasfromsurfacemesh": {
        "mesh_input_file": (
            "EllipticPETSc/cube_1x1x1_SteadyStateDiffusion/gml_output/3/"
            "hex_27_cube_1x1x1_geometry_top_ts_0_t_0_000000_2.vtu"
        ),
    },
    "computesurfacenodeidsinpolygonalregion": {
        "mesh_input_file": (
            "MeshGeoToolsLib/ResetPropertiesInPolygonalRegion/Cube.vtu"
        ),
        "geo_file": "MeshGeoToolsLib/ResetPropertiesInPolygonalRegion/Polylines.gml",
        "gmsh_path": None,
    },
    # generateStructuredMesh needs a geometry: with nothing but ``-e`` it has
    # nothing to mesh. The values mirror the upstream AddTest call.
    "generatestructuredmesh": {
        "element_type": "quad",
        "lx": "3",
        "ly": "4",
        "nx": "3",
        "ny": "4",
    },
    "addlayer": {"layer_tickness": "1"},
    "postlie": {
        "input_file": "LIE/PostProcessing/single_joint_3D_ts_1_t_1.000000.vtu",
        "output_file": "post_processed.vtu",
        "no_overwrite": False,
    },
}

TCLAP_PATTERN_STD = re.compile(
    r"TCLAP::(?P<arg_type>(?:Value|Switch|Multi)Arg)\s*"
    r"(?:<(?P<cpp_type>.*?)>)?\s*(?P<tclap_var_name>\w+)\s*"
    r"[\({]\s*(?P<all_args>.*?)\s*[\)}];",
    re.DOTALL,
)

TCLAP_PATTERN_UNLABELED = re.compile(
    r"TCLAP::(?P<arg_type>Unlabeled(?:Value|Multi)Arg)\s*"
    r"(?:<(?P<cpp_type>.*?)>)?\s*(?P<tclap_var_name>\w+)\s*"
    r"[\({]\s*(?P<all_args>.*?)\s*[\)}];",
    re.DOTALL,
)
# Only match a parenthesised list of dot-prefixed extensions, e.g.
# "(.fem)", "(.msh | .vtk)", "(.vtu | .gml | .asc)". The previous pattern
# ``\\((.*?)\\)`` matched *anything* in parentheses, which let prose such as
# "(if extension is msh, old OGS file format is written)" leak into file
# names and datatypes.
FILE_EXTENSION_PATTERN = re.compile(
    r"\(\s*(\.[A-Za-z0-9]+(?:\s*\|\s*\.[A-Za-z0-9]+)*)\s*\)"
)
MIN_MAX_PATTERN = re.compile(r"\((min|max)\s*=\s*([^)]+)\)")


def list_cpp_files(root_dir: str) -> List[str]:
    """Return a sorted list of all *.cpp file paths under ``root_dir`` (recursive)."""
    return sorted(str(p) for p in Path(root_dir).rglob("*.cpp"))


# Curated OGS extension -> Galaxy datatype mapping.
#
# This table is authoritative: the generator must never derive a datatype from
# free help text (that produced formats like "geometry (gli" in the original PR).
# Every extension OGS utilities use is listed here; anything not present falls
# back to the generic ``data`` type so a wrapper still loads instead of failing.
DATATYPE_MAP = {
    # VTK family (unstructured/structured grids, parallel, time series)
    "vtu": "vtkxml",
    # ``.vtk`` is the legacy format. Galaxy ships no ``vtk`` datatype in the
    # supported releases, and the OGS build cannot read legacy VTK at all (the
    # legacy-only utilities are excluded), so it maps to the VTK XML type.
    "vtk": "vtkxml",
    "pvtu": "vtkxml",
    "pvd": "vtkxml",
    # OGS / FEFLOW / Gocad project and geometry files
    "sg": "gocad.sg",
    "fem": "feflow.fem",
    "gml": "xml",
    "prj": "xml",
    "xml": "xml",
    "ts": "xml",
    # Rasters and NetCDF
    "asc": "raster.asc",
    "grd": "raster.asc",
    "nc": "netcdf",
    # Tabular / structured text
    "csv": "csv",
    "json": "json",
    "txt": "txt",
    # ASCII text-ish formats (no dedicated Galaxy datatype)
    "gli": "txt",
    "plt": "txt",
    "tin": "txt",
    "geo": "txt",
    "smesh": "txt",
    "bin": "txt",
    "mesh": "txt",
    # Binary without a dedicated Galaxy datatype -> generic
    "xdmf": "data",
    "h5": "data",
}

# ``.msh`` is ambiguous: it is both the *Gmsh* mesh format (an input to GMSH2OGS)
# and the legacy OGS-5 mesh format (an output of several utilities). Disambiguate
# by role rather than by a single static mapping.
MESH_INPUT_DATATYPE = "gmsh.msh"
MESH_OUTPUT_DATATYPE = "data"

# Extensions already warned about, so the unmapped-datatype warning is not
# repeated once per wrapped utility.
_UNMAPPED_EXT_WARNED: set = set()


def get_ogs_ftype(extensions: List[str], role: str = "output") -> str:
    """Map OGS file extensions to a Galaxy datatype.

    ``role`` is ``"input"`` or ``"output"`` and is only meaningful for the
    ambiguous ``.msh`` extension (Gmsh input vs. legacy OGS-5 mesh output).
    Extensions with no mapping fall back to the generic ``data`` type and a
    one-time warning is emitted so gaps in :data:`DATATYPE_MAP` are visible
    during generation instead of being silently mis-typed.
    """
    if not extensions:
        return "vtkxml"

    ext = extensions[0].lower().lstrip(".")
    if ext == "msh":
        return MESH_INPUT_DATATYPE if role == "input" else MESH_OUTPUT_DATATYPE
    fmt = DATATYPE_MAP.get(ext)
    if fmt is None:
        if ext not in _UNMAPPED_EXT_WARNED:
            _UNMAPPED_EXT_WARNED.add(ext)
            logging.warning(
                "No Galaxy datatype mapped for OGS extension %r; falling back "
                "to generic 'data'. Add it to DATATYPE_MAP if a real Galaxy "
                "datatype exists.",
                ext,
            )
        return "data"
    return fmt


def eprint(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)


def _node_attr_true(param, attr: str) -> bool:
    """Return True when a galaxyxml parameter's XML attribute is ``"true"``."""
    val = getattr(param, attr, None)
    return str(val).strip().lower() == "true"


def is_param_optional(param, default: bool = True) -> bool:
    """Return whether a galaxyxml parameter is optional.

    ``galaxyxml.XMLParam.__getattr__`` proxies attribute access to the lxml
    ``node.attrib`` dict, so ``param.optional`` is the *string* ``"true"`` /
    ``"false"`` (when set) and the string ``"false"`` is truthy. Read the
    attribute explicitly instead of relying on truthiness.
    """
    val = getattr(param, "optional", None)
    if val is None:
        return default
    return str(val).strip().lower() == "true"


def sanitize_name(name: str) -> str:
    return re.sub(r"[^a-zA-Z0-9_]+", "_", name)


def param_var_name(param) -> str:
    """Return the Galaxy command-line variable name for a parameter.

    Mirrors Galaxy's own behaviour: a ``<param>`` with an explicit ``name``
    uses it; otherwise the variable name is *derived* from ``argument`` (the
    leading dashes are stripped and non-alphanumerics become underscores, e.g.
    ``--input-geometry`` -> ``input_geometry``). The generated wrappers rely on
    this derivation (they set ``argument`` only), so the test macros must use
    the same name to reference the variable.
    """
    name = None
    try:
        name = param.name
    except AttributeError:
        name = None
    if name:
        return name
    argument = getattr(param, "argument", None) or ""
    if argument:
        return sanitize_name(argument.lstrip("-"))
    return sanitize_name(getattr(param, "original_long_flag", "") or "param")


# Test fixtures always live under the immutable pinned commit and are taken
# from OGS's own Tests.cmake at that same commit, i.e. they exist by
# construction. A live HEAD request would make generation network-dependent
# and non-deterministic (a flaky request silently swaps a real recipe for a
# dummy fallback). So we trust pinned URLs by default and only hit the network
# when --verify-urls is passed (for occasional maintenance).
VERIFY_URLS = False
_URL_EXISTS_CACHE: Dict[str, bool] = {}


def url_exists(url: str) -> bool:
    """Return True if ``url`` is a usable OGS test-data fixture.

    By default this trusts the URL (the pinned commit is immutable, so a
    fixture referenced by a passing AddTest exists). With ``VERIFY_URLS`` set
    (``--verify-urls``) a cached HEAD request is made instead.
    """
    if not VERIFY_URLS or not url.startswith(OGS_TEST_DATA_URL):
        return True
    if url in _URL_EXISTS_CACHE:
        return _URL_EXISTS_CACHE[url]
    try:
        req = urllib.request.Request(url, method="HEAD")
        with urllib.request.urlopen(req, timeout=10) as response:
            ok = response.status == 200
    except Exception:
        ok = False
    _URL_EXISTS_CACHE[url] = ok
    return ok


def _fixture_url(path: str, wd_sub: str) -> str:
    """Build the pinned test-data URL for a fixture referenced by a test.

    ``path`` is the fixture path with any ``${Data_SOURCE_DIR}/`` already
    stripped. If it already names a directory (e.g.
    ``FileIO/FEFLOW/prism.fem``) that directory is authoritative; a bare
    filename falls back to the test's working directory ``wd_sub``.
    """
    p = path.strip().lstrip("/")
    if "/" in p:
        rel = p
    elif wd_sub:
        rel = f"{wd_sub}/{p}"
    else:
        rel = p
    return f"{OGS_TEST_DATA_URL}/{rel}"


def resolve_values_constraint(constraint_ptr: str, search_space: str) -> List[str]:
    var_name = constraint_ptr.lstrip("&")
    vc_pattern = re.compile(
        r"TCLAP::ValuesConstraint<.*?>\s+"
        + re.escape(var_name)
        + r"\s*[\({]\s*(\w+)\s*[\)}]",
        re.DOTALL,
    )
    vc_match = vc_pattern.search(search_space)
    if not vc_match:
        return []

    vector_var_name = vc_match.group(1)
    options = []

    vec_init_pattern = re.compile(
        r"std::vector<.*?>\s+"
        + re.escape(vector_var_name)
        + r"\s*(?:=)?\s*[({]?\s*\{(.*?)\}\s*[)}]?;",
        re.DOTALL,
    )
    vec_match = vec_init_pattern.search(search_space)
    if vec_match:
        content = vec_match.group(1)
        string_options = re.findall(r'"(.*?)"', content)
        if string_options:
            options.extend(string_options)
        else:
            numeric_options = [
                item.strip() for item in content.split(",") if item.strip()
            ]
            options.extend(numeric_options)

    push_pattern = re.compile(
        re.escape(vector_var_name)
        + r"\.(?:emplace_back|push_back)\s*\(\s*([^)]+)\s*\)\s*;",
        re.MULTILINE,
    )
    push_matches = push_pattern.findall(search_space)
    if push_matches:
        for val in push_matches:
            clean_val = val.strip().strip('"')
            options.append(clean_val)

    seen = set()
    return [x for x in options if not (x in seen or seen.add(x))]


# ``(min = 0)`` / ``(max = 5)`` / ``(min = 0, max = 1)`` in an OGS help string
# is a real constraint of the utility, not prose.
_RANGE_VALUE_RE = re.compile(
    r"\b(min|max)\s*=\s*(-?\d+(?:\.\d+)?)", re.IGNORECASE
)
_RANGE_CLAUSE_RE = re.compile(
    r"[(,]?\s*(?:min|max)\s*=\s*-?\d+(?:\.\d+)?"
    r"(?:\s*,\s*(?:min|max)\s*=\s*-?\d+(?:\.\d+)?)*\s*\)?",
    re.IGNORECASE,
)


def split_range_clause(help_text: str) -> Tuple[str, Dict[str, str]]:
    """Move ``(min = X)``-style constraints out of an OGS help string.

    Returns the help text with the parenthetical range removed plus the bounds
    as ``{"min": ..., "max": ...}`` so they can be rendered as Galaxy
    parameter attributes instead of being buried in the prose.
    """
    bounds: Dict[str, str] = {}
    for key, value in _RANGE_VALUE_RE.findall(help_text):
        bounds.setdefault(key.lower(), value)
    if not bounds:
        return help_text, bounds

    cleaned = _RANGE_CLAUSE_RE.sub("", help_text)
    cleaned = re.sub(r"\s+([.,;:!?])", r"\1", cleaned)
    cleaned = re.sub(r"\s{2,}", " ", cleaned).strip()
    cleaned = cleaned.rstrip(",;/")
    return cleaned, bounds


def extract_cmdline_text(source: str) -> str:
    """Return the description OGS itself passes to ``TCLAP::CmdLine``.

    Every OGS utility constructs its command line object with a free-text
    description as first argument, e.g.::

        TCLAP::CmdLine cmd(
            "Checks mesh properties.\n\n"
            "OpenGeoSys-6 software, version " + ...,
            ' ', GitInfoLib::GitInfo::ogs_version);

    That text is the utility's own documentation and therefore exactly what a
    Galaxy wrapper should show as ``<description>``/``<help>``. The trailing
    version/copyright banner is dropped. The result is a blank-line separated
    paragraph string, or ``""`` when no description is found.
    """
    match = re.search(r"TCLAP::CmdLine\s+\w+\s*\(", source)
    if not match:
        return ""

    start = match.end()
    depth, pos, in_string = 1, start, False
    while pos < len(source) and depth:
        char = source[pos]
        if in_string:
            if char == "\\":
                pos += 2
                continue
            if char == '"':
                in_string = False
        elif char == '"':
            in_string = True
        elif char == "(":
            depth += 1
        elif char == ")":
            depth -= 1
        pos += 1

    literals = re.findall(r'"((?:[^"\\]|\\.)*)"', source[start:pos])
    text = "".join(literals)
    text = (
        text.replace("\\n", "\n")
        .replace("\\t", " ")
        .replace('\\"', '"')
        .replace("\\'", "'")
    )
    text = re.split(r"\s*(?:OpenGeoSys-6 software|Copyright \()", text)[0]
    # Adjacent C++ literals are concatenated without a separating space, so
    # "Adds a layer to an existing mesh." + "The documentation ..." ends up as
    # "mesh.The". Restore the sentence boundary.
    text = re.sub(r"([.!?])(?=[A-Z])", r"\1 ", text)

    paragraphs = []
    for block in re.split(r"\n\s*\n", text):
        paragraph = re.sub(
            r"\s+", " ", " ".join(line.strip() for line in block.splitlines())
        ).strip()
        # "... bounding box\n." -> "... bounding box."
        paragraph = re.sub(r"\s+([.,;:!?])", r"\1", paragraph)
        if paragraph:
            paragraphs.append(paragraph)
    return "\n\n".join(paragraphs)


def cmdline_description(cmdline_text: str) -> str:
    """First complete sentence of OGS's own description, or ``""``.

    Galaxy renders ``<description>`` right next to the tool name, so only a
    short sentence is useful there. Sentences are accumulated until any
    parenthesis opened earlier is closed again (OGS writes things like
    "elements in a voxel grid (i.e. ...)"), and the result is dropped entirely
    rather than truncated to nonsense when it does not fit.
    """
    first_paragraph = cmdline_text.split("\n\n")[0].strip()
    if not first_paragraph:
        return ""

    accumulated = ""
    for sentence in re.split(r"(?<=[.!?])\s+", first_paragraph):
        accumulated = f"{accumulated} {sentence}".strip()
        balanced = accumulated.count("(") == accumulated.count(")")
        if balanced and len(accumulated) <= 150:
            return accumulated
        if len(accumulated) > 150:
            break
    return ""


def discover_tools(ogs_root: Path) -> List[Dict[str, Any]]:
    source_files = list_cpp_files(ogs_root / "Applications" / "Utils")
    tools_dict: Dict[str, Dict[str, Any]] = {}
    logging.info(f"Searching {len(source_files)} .cpp files under {ogs_root / 'Applications' / 'Utils'}")

    for file_path in source_files:
        path_obj = Path(file_path)

        with open(file_path) as fh:
            content = fh.read()

        all_matches = list(TCLAP_PATTERN_STD.finditer(content)) + list(
            TCLAP_PATTERN_UNLABELED.finditer(content)
        )

        if not all_matches:
            logging.debug(f"Skiping (no tclap): {file_path}")
            continue

        if path_obj.name == "main.cpp":
            tool_name = path_obj.parent.name
        else:
            tool_name = path_obj.stem

        if tool_name.lower() in ["main", "utils"]:
            continue

        if tool_name not in tools_dict:
            tools_dict[tool_name] = {
                "name": tool_name,
                "parameters": [],
                # OGS's own tool description (TCLAP::CmdLine), used for the
                # Galaxy <description>/<help> instead of a redundant
                # "Galaxy wrapper for ..." sentence.
                "cmdline_text": extract_cmdline_text(content),
                "source": file_path,
            }

        for match in all_matches:
            param_data = match.groupdict()
            param_data["is_unlabeled"] = "Unlabeled" in param_data.get("arg_type", "")
            param_data["full_source_code"] = content
            param_data["match_start_pos"] = match.start()
            tools_dict[tool_name]["parameters"].append(param_data)

    all_tools_data = list(tools_dict.values())
    logging.info(f"-> Found {len(all_tools_data)}")
    return sorted(all_tools_data, key=lambda x: x["name"])


def process_parameters(
    tclap_params: List[Dict[str, Any]], tool_name: str = ""
) -> Tuple[List[object], Dict[str, str]]:
    """Turn a tool's raw TCLAP parameter descriptors into Galaxy parameter objects.

    Each element of ``tclap_params`` is one ``TCLAP::(Value|Switch|Multi)Arg``
    declaration captured by :func:`discover_tools`. This function classifies it
    (TCLAP arg type + C++ type) and emits the matching Galaxy parameter object
    (``DataParam``, ``SelectParam``, ``TextParam``, ``IntegerParam``,
    ``FloatParam``, ``BooleanParam``). It also:

      * models OGS ``*_INPUT_FILE_LIST`` args as a single ``format=txt`` input
        (OGS reads one ASCII list file, not a collection);
      * sets ``is_data_collection`` for ``MultiArg``/``UnlabeledMultiArg`` args;
      * resolves TCLAP ``ValuesConstraint`` option lists into ``SelectParam``
        choices (with the ``cmd``/default-value false-positive guard);
      * records the OGS file extension (``ogs_ext``) for runtime-correct
        symlink naming, and builds the ``output_command_map`` used to derive
        the tool's ``<outputs>`` (``BASE_FILENAME`` outputs for tools that only
        accept an output basename).

    Returns ``(galaxy_inputs, output_command_map)``.
    """
    galaxy_inputs = []
    output_command_map = {}
    output_idx = 1

    if tclap_params and "writeMeshToFile" in tclap_params[0].get(
        "full_source_code", ""
    ):
        has_tclap_output = any(
            "output" in p.get("all_args", "").lower()
            or "BASE_FILENAME_OUTPUT" in p.get("all_args", "")
            for p in tclap_params
        )
        if not has_tclap_output:
            output_command_map["VIRTUAL_no_flag"] = {
                "filename": "new_",
                "format": "vtkxml",
                "type": "BASE_FILENAME",
            }

    for param_info in tclap_params:
        if param_info.get("tclap_var_name") == "log_level_arg":
            continue
        all_args_str = param_info.get("all_args", "")
        if not all_args_str:
            continue

        args = re.split(r",(?=(?:[^\"]*\"[^\"]*\")*[^\"]*$)", all_args_str)
        args = [arg.strip() for arg in args]
        is_unlabeled = param_info.get("is_unlabeled", False)

        short_flag, long_flag, help_text_raw = "", "", ""
        if not is_unlabeled:
            if len(args) > 0:
                short_flag = args[0].strip('"')
            if len(args) > 1:
                long_flag = args[1].strip('"')
            if len(args) > 2:
                help_text_raw = args[2]
        else:
            if len(args) > 0:
                long_flag = args[0].strip('"')
            if len(args) > 1:
                help_text_raw = args[1]
            if not long_flag:
                long_flag = param_info.get("tclap_var_name", f"arg_{output_idx}")

        if not long_flag:
            continue
        help_parts = re.findall(r'"(.*?)"', help_text_raw, re.DOTALL)
        help_text = " ".join(part.strip() for part in help_parts).strip()
        var_name = sanitize_name(long_flag)
        argument = f"--{long_flag}" if long_flag else f"-{short_flag}"

        # TCLAP constructor arity:
        #   Value/MultiArg(flag, name, desc, required, ...) -> required at [3]
        #   Unlabeled(Value|Multi)Arg(name, desc, required, ...) -> required at [2]
        # Anything we cannot classify as explicitly required stays optional so a
        # parse quirk never turns a working wrapper into a mandatory-input tool.
        req_idx = 2 if is_unlabeled else 3
        is_required = (
            len(args) > req_idx and args[req_idx].strip().lower() == "true"
        )
        is_optional = not is_required

        # OUTPUT LOGIC
        is_output_help = (
            help_text.lower().startswith("output")
            or "directory name and output base" in help_text.lower()
        )

        if is_output_help or "BASE_FILENAME_OUTPUT" in all_args_str:
            format_match = FILE_EXTENSION_PATTERN.search(help_text)
            primary_ext = "vtu"
            if format_match:
                primary_ext = format_match.group(1).split("|")[0].strip().lstrip(".")
            primary_ext = OUTPUT_EXT_OVERRIDES.get(
                (tool_name.lower(), long_flag), primary_ext
            )

            file_format = get_ogs_ftype([primary_ext], role="output")
            disk_ext = "vtu" if file_format == "vtkxml" else primary_ext

            is_base_filename_output = (
                "BASE_FILENAME_OUTPUT" in all_args_str
                or "base name" in help_text.lower()
            )

            output_command_map[long_flag] = {
                "filename": f"output_{output_idx}.{disk_ext}",
                "format": file_format,
                "short_flag": short_flag,
                "type": "BASE_FILENAME" if is_base_filename_output else "FIXED_FILE",
                # ``--output-directory`` / ``--output-dir`` take a directory
                # the utility creates its files in; Galaxy cannot stage a bare
                # directory, so such outputs are declared as a discovered
                # collection instead of a single file.
                "is_directory": (
                    "directory" in long_flag.lower()
                    or long_flag.lower().endswith("-dir")
                ),
            }
            output_idx += 1
            continue

        # INPUT & PARAMETER LOGIC
        param = None
        constraint_ptr = ""
        if len(args) >= 5:
            for potential_ptr in args[4:]:
                ptr_stripped = potential_ptr.strip()
                if (
                    ptr_stripped
                    and not ptr_stripped.startswith('"')
                    and not ptr_stripped[0].isdigit()
                ):
                    constraint_ptr = ptr_stripped
                    break

        if constraint_ptr:
            options_list = resolve_values_constraint(
                constraint_ptr, param_info.get("full_source_code", "")
            )
        else:
            options_list = []

        # Only treat a value as a Select when a real ValuesConstraint was
        # found. A ``constraint_ptr`` false positive (e.g. the trailing
        # ``cmd`` argument of TCLAP's 7-arg form, or a default value such as
        # ``std::numeric_limits<double>::epsilon()``) must NOT swallow the
        # generic input/select/switch handling, or the tool loses all inputs.
        if options_list:
            opts_dict = {opt: opt for opt in options_list}
            is_multi = "MultiArg" in param_info.get("arg_type", "")
            param = SelectParam(
                argument=argument,
                label=var_name.replace("_", " "),
                help=help_text,
                options=opts_dict,
                optional=is_optional,
                multiple=is_multi,
            )
            param.options_dict = opts_dict
        elif (
            help_text.startswith("Input")
            or "filenames" in var_name
            or "INPUT_FILE_LIST" in all_args_str
        ):
            format_match = FILE_EXTENSION_PATTERN.search(help_text)
            all_exts = (
                [e.strip().lstrip(".") for e in format_match.group(1).split("|")]
                if format_match
                else []
            )
            # Arguments that accept a ``.pvd`` *or* a single ``.vtu`` are
            # exposed as the single-file variant: writing a sidecar XDMF/PVD
            # from a pvd would need the member files it references.
            is_pvd = (
                "pvd" in help_text.lower() or "pvd" in all_exts
            ) and (tool_name.lower(), var_name) not in NON_PVD_INPUTS
            primary_ext = "pvd" if is_pvd else (all_exts[0] if all_exts else "vtu")
            # A curated extension (see PARAM_EXT_OVERRIDES) must also drive the
            # Galaxy datatype, otherwise the test uploads the fixture under a
            # datatype that does not match the extension the command uses.
            primary_ext = PARAM_EXT_OVERRIDES.get(
                (tool_name.lower(), var_name), primary_ext
            )
            galaxy_type = get_ogs_ftype([primary_ext], role="input")
            is_file_list = "INPUT_FILE_LIST" in all_args_str
            # A *_INPUT_FILE_LIST argument is a single ASCII text file naming
            # the input files (OGS reads it with readStringListFromFile), NOT a
            # Galaxy collection. Model it as one txt input.
            is_collection = "MultiArg" in param_info.get("arg_type", "")
            if is_file_list:
                galaxy_type = "txt"

            param = DataParam(
                argument=argument,
                label=var_name.replace("_", " "),
                help=help_text,
                format=galaxy_type,
                optional=is_optional,
            )
            param.is_data_collection = is_collection
            param.is_collection = is_collection
            param.ogs_ext = primary_ext
            param.is_pvd = is_pvd
            param.is_file_list = is_file_list

            if is_pvd:
                pvd_data = DataParam(
                    name=f"{var_name}_pvd_data",
                    label=f"{var_name} PVD Data Elements",
                    help="VTU Member Collection",
                    format="vtkxml",
                    optional=True,
                )
                pvd_data.is_pvd_element = True
                pvd_data.is_data_collection = True
                pvd_data.is_collection = True
                galaxy_inputs.append(pvd_data)

        elif "Switch" in param_info.get("arg_type", ""):
            param = BooleanParam(
                argument=argument,
                label=var_name.replace("_", " "),
                help=help_text,
                truevalue=f"--{long_flag}",
                falsevalue="",
                checked=False,
            )

        else:
            cpp_type = param_info.get("cpp_type", "").lower()
            # TCLAP spells integers as ``int``, ``unsigned``, ``size_t``, ...;
            # anything else (``std::string``) is free text.
            if re.search(
                r"\b(?:u?int(?:8|16|32|64)?_t|u?int|u?long|u?short|unsigned|size_t)\b",
                cpp_type,
            ):
                p_class = IntegerParam
            elif re.search(r"\b(?:float|double)\b", cpp_type):
                p_class = FloatParam
            else:
                p_class = TextParam
            param = p_class(
                argument=argument,
                label=var_name.replace("_", " "),
                help=help_text,
                optional=is_optional,
            )

        if param:
            param.original_long_flag = long_flag
            param.original_short_flag = short_flag
            param.is_unlabeled = is_unlabeled
            galaxy_inputs.append(param)

    base_override = BASE_FILENAME_OVERRIDES.get(tool_name.lower())
    if base_override and base_override["flag"] in output_command_map:
        info = output_command_map[base_override["flag"]]
        info["type"] = "BASE_FILENAME"
        for key in (
            "base_value",
            "pattern",
            "format",
            "extra_outputs",
            "outputs",
        ):
            if key in base_override:
                info[key] = base_override[key]

    return galaxy_inputs, output_command_map


def _derive_param_constraints(inputs_node) -> None:
    """Turn OGS help-string details into real Galaxy parameter attributes.

    * numeric parameters: ``(min = 0)``/``(max = ...)`` in the OGS help text is
      a constraint of the utility, so it becomes the ``min``/``max`` attribute
      (and is removed from the prose).
    * text parameters: the value is passed to OGS verbatim (flag values, array
      names, ids), hence an explicit ``<sanitizer sanitize="false"/>`` -- and a
      required text field gets an ``<empty_field/>`` validator, because
      ``optional="false"`` alone does not stop an empty string from being
      passed on.
    """
    for param in inputs_node.findall("param"):
        ptype = param.get("type")
        help_text = param.get("help") or ""

        if ptype in ("integer", "float"):
            cleaned, bounds = split_range_clause(help_text)
            if bounds:
                param.set("help", cleaned)
                for key, value in bounds.items():
                    param.set(key, value)

        elif ptype == "text":
            if param.find("sanitizer") is None:
                ET.SubElement(param, "sanitizer", {"sanitize": "false"})
            required_text = param.get("optional") != "true"
            if required_text and param.find("validator") is None:
                ET.SubElement(param, "validator", {"type": "empty_field"})


def _discover_pattern(pattern: str, link_names: set) -> str:
    """Keep the wrapper's own input links out of a discovered output list.

    Every input dataset is symlinked into the job working directory (so that
    utilities which write next to their input do not write into the Galaxy
    file store). A discovery pattern such as ``(?P<designation>.*)\\.vtu``
    would match those links too, and Galaxy rejects a discovered file that
    resolves outside the job directory -- aborting the whole output
    collection. The negative lookahead skips exactly the names we created.
    """
    if not link_names or "(?P<designation>" not in pattern:
        return pattern
    names = "|".join(re.escape(n) for n in sorted(link_names))
    lookahead = f"(?!(?:{names})$)"
    return pattern.replace("(?P<designation>", lookahead + "(?P<designation>", 1)


def generate_tools(ogs_root: Path, output_dir: Path):
    output_dir.mkdir(parents=True, exist_ok=True)
    all_tools_data = discover_tools(ogs_root)
    if not all_tools_data:
        eprint("No tools with TCLAP definitions found. Aborting.")
        return

    generated_count = 0
    for tool_data in all_tools_data:
        tool_name = tool_data["name"]
        if tool_name.lower() in EXCLUDED_TOOLS:
            logging.info(f"--> Skipping excluded tool: {tool_name}")
            continue
        logging.info(f"Generating wrapper for: {tool_name}...")
        galaxy_inputs, output_command_map = process_parameters(
            tool_data["parameters"], tool_name
        )

        # 1. EXECUTABLE NAMING
        current_exe = tool_name
        if tool_name.upper() == "PVTU2VTU":
            current_exe = "pvtu2vtu"
        elif tool_name[0].isupper() and tool_name[1:].islower():
            current_exe = tool_name[0].lower() + tool_name[1:]

        m_fixes = {
            "PVTU2VTU": "pvtu2vtu",
            "FEFLOW2OGS": "feflow2ogs",
            "MergeMeshToBulkMesh": "mergeMeshToBulkMesh",
            "PartitionMesh": "partmesh",
        }

        executable_name = m_fixes.get(tool_name, current_exe)

        command_parts = []
        flag_parts = []
        unlabeled_parts = []
        # Names of the symlinks created in the job working directory; the
        # discovery patterns must not pick them up as outputs.
        input_link_names: set = set()

        # 2. SYMLINKS & ARGUMENT MAPPING
        for param in galaxy_inputs:
            is_unlabeled = getattr(param, "is_unlabeled", False)

            flag = getattr(param, "original_long_flag", None)
            if flag:
                name = sanitize_name(flag)
            else:
                name = ""

            if isinstance(param, DataParam):
                is_file_list = getattr(param, "is_file_list", False)
                is_coll = getattr(param, "is_data_collection", False)
                ext = PARAM_EXT_OVERRIDES.get(
                    (tool_name.lower(), param_var_name(param)),
                    getattr(param, "ogs_ext", "vtu"),
                ).lower()

                if getattr(param, "is_pvd_element", False):
                    command_parts.append(
                        f"  #for $item in ${param.name}\n    ln -sf '$item' '$item.element_identifier';\n  #end for"
                    )
                    continue
                if is_file_list:
                    # Single ASCII list file (OGS readStringListFromFile); pass
                    # it straight through, no collection loop is needed. The
                    # local symlink carries a real .txt extension so OGS can
                    # open it (OGS infers the format from the file extension).
                    # The link is created *in the job working directory*: a
                    # path derived from ``${name}`` would end up in the Galaxy
                    # file store, next to the input dataset.
                    local = f"{name}.txt"
                    input_link_names.add(local)
                    symlink = f"ln -sf '${name}' '{local}';"
                    arg = f"    --{flag} '{local}'"
                    if is_param_optional(param, default=False):
                        command_parts.append(f"#if ${name}\n{symlink}\n#end if")
                        flag_parts.append(f"#if ${name}\n{arg}\n#end if")
                    else:
                        command_parts.append(symlink)
                        flag_parts.append(arg)
                    continue
                if is_coll:
                    loop = (
                        f"#for $item in ${name}\n"
                        f"ln -sf '$item' '$item.element_identifier';\n"
                        f"#end for"
                    )
                    loop_str = f"#for $item in ${name}\n'$item.element_identifier'\n#end for"
                    if is_unlabeled:
                        arg = f"    --\n{loop_str}"
                        dest = unlabeled_parts
                    else:
                        arg = f"    --{flag}\n{loop_str}"
                        dest = flag_parts
                    if is_param_optional(param, default=False):
                        command_parts.append(f"#if ${name}\n{loop}\n#end if")
                        dest.append(f"#if ${name}\n{arg}\n#end if")
                    else:
                        command_parts.append(loop)
                        dest.append(arg)
                else:
                    # Link the dataset to a name carrying the OGS extension
                    # (OGS infers the input format from the file extension; the
                    # Galaxy ``element_identifier`` suffix has none). The link
                    # is created in the job working directory under a name
                    # derived from the parameter -- writing ``${name}.ext``
                    # would place it next to the input dataset in the Galaxy
                    # file store, which breaks read-only/object-store backends
                    # and litters the store.
                    local = f"{name}.{ext}"
                    input_link_names.add(local)
                    symlink = f"ln -sf '${name}' '{local}';"
                    arg_val = f"'{local}'"
                    arg = f"    {arg_val}" if is_unlabeled else f"    --{flag} {arg_val}"
                    target = unlabeled_parts if is_unlabeled else flag_parts
                    if is_param_optional(param, default=False):
                        # An omitted optional dataset must not be rendered as
                        # the literal string 'None.<ext>': guard both the
                        # symlink and the flag on the parameter being set.
                        command_parts.append(f"#if ${name}\n{symlink}\n#end if")
                        target.append(f"#if ${name}\n{arg}\n#end if")
                    else:
                        command_parts.append(symlink)
                        target.append(arg)
            elif isinstance(param, BooleanParam):
                flag_parts.append(f"    ${name}")
            elif isinstance(
                param, (TextParam, IntegerParam, FloatParam, SelectParam)
            ):
                if isinstance(param, SelectParam) and _node_attr_true(
                    param, "multiple"
                ):
                    # Multi-value selects render as a Python list; repeat the
                    # flag once per selected value (a plain ``'$x'`` would
                    # stringify the whole list, or ``'None'`` when empty).
                    flag_parts.append(
                        f"#for $v in ${name}\n    --{flag} '$v'\n#end for"
                    )
                    continue
                # Optional value arguments are wrapped in ``#if str(...)`` so an
                # empty value is omitted from the command line rather than passed
                # as ``--flag ''`` (which TCLAP silently accepts, giving silently
                # wrong results).
                if is_unlabeled:
                    if is_param_optional(param, default=False):
                        unlabeled_parts.append(
                            f"#if str(${name})\n    '${name}'\n#end if"
                        )
                    else:
                        unlabeled_parts.append(f"    '${name}'")
                else:
                    if is_param_optional(param, default=False):
                        flag_parts.append(
                            f"#if str(${name})\n    --{flag} '${name}'\n#end if"
                        )
                    else:
                        flag_parts.append(f"    --{flag} '${name}'")

        # 3. OUTPUT FLAGS
        for flag, info in output_command_map.items():
            if flag == "VIRTUAL_no_flag":
                continue
            if info.get("is_directory"):
                # The utility writes into a directory it is given.
                flag_parts.append(f"    --{flag} '{DIRECTORY_OUTPUT_DIR}'")
                continue
            if info.get("type") == "BASE_FILENAME":
                if "directory" in flag.lower():
                    flag_parts.append(f"    --{flag} 'new_output'")
                else:
                    flag_parts.append(
                        f"    --{flag} {info.get('base_value', 'new_')}"
                    )
            else:
                flag_parts.append(f"    --{flag} {info['filename']}")

        final_exec_line = [executable_name]
        final_exec_line.extend(flag_parts)
        final_exec_line.extend(unlabeled_parts)
        if any(info.get("is_directory") for info in output_command_map.values()):
            # OGS does not create the output directory itself.
            command_parts.append(f"mkdir -p '{DIRECTORY_OUTPUT_DIR}';")
        command_parts.extend(final_exec_line)
        if (
            not output_command_map
            and tool_name.lower() not in IMPLICIT_OUTPUTS
        ):
            command_parts[-1] += " > '$stdout_log'"
        command_str = "\n".join(command_parts)

        # 4. Tool object
        # Description/help come from the utility's own ``TCLAP::CmdLine`` text
        # (the CLI definition), not from a generic "Galaxy wrapper for ..."
        # sentence that repeats the tool name. If OGS has no description the
        # element is dropped entirely below.
        cmdline_text = tool_data.get("cmdline_text") or ""
        tool_description = cmdline_description(cmdline_text)
        tool = Tool(
            name=f"OGS: {tool_name}",
            id=f"ogs_{tool_name.lower()}",
            version="@TOOL_VERSION@+galaxy@VERSION_SUFFIX@",
            description=tool_description,
            executable=executable_name,
            macros=["macros.xml", "test_macros.xml"],
            profile="@PROFILE@",
            version_command=f"{executable_name} --version",
            command_override=[command_str],
        )

        inputs_tag = tool.inputs = Inputs()
        for param in galaxy_inputs:
            inputs_tag.append(param)

        if output_command_map:
            outputs_tag = tool.outputs = Outputs()
            uses_base_filename = any(
                info.get("type") == "BASE_FILENAME"
                for info in output_command_map.values()
            )

            if any(
                info.get("is_directory") for info in output_command_map.values()
            ):
                collection = OutputCollection(
                    name="tool_outputs",
                    type="list",
                    label=f"Outputs from {tool_name}",
                )
                collection.append(
                    DiscoverDatasets(
                        pattern="__name_and_ext__",
                        directory=DIRECTORY_OUTPUT_DIR,
                        visible=True,
                    )
                )
                outputs_tag.append(collection)
            elif uses_base_filename:
                first_out_info = next(
                    info
                    for info in output_command_map.values()
                    if info.get("type") == "BASE_FILENAME"
                )
                fixed_outputs = first_out_info.get("outputs")
                if fixed_outputs:
                    # The utility writes exactly these files (their names follow
                    # from the base name the wrapper passes), so declare them
                    # explicitly instead of guessing designations from a file
                    # name pattern that carries the wrapper's artificial prefix.
                    for out in fixed_outputs:
                        outputs_tag.append(
                            OutputData(
                                name=out["name"],
                                format=out["format"],
                                label=out.get("label", out["name"]),
                                from_work_dir=out["from_work_dir"],
                            )
                        )
                else:
                    # No explicit output list: discover whatever the utility wrote
                    # under the base name the wrapper passes.
                    if first_out_info.get("pattern"):
                        pattern = first_out_info["pattern"]
                    elif "VIRTUAL_no_flag" in output_command_map:
                        # The utility names its output files itself.
                        pattern = r"(?P<designation>.*)\.vtu"
                    else:
                        # Base-name output: the wrapper chooses the prefix, so
                        # strip it (and the extension) again -- the element
                        # designation must not depend on the wrapper's prefix.
                        base = first_out_info.get("base_value", "new_")
                        ext = (first_out_info.get("filename") or "x.vtu").rsplit(
                            ".", 1
                        )[-1]
                        pattern = (
                            rf"{re.escape(base)}(?P<designation>.*)\."
                            rf"{re.escape(ext)}"
                        )
                    collection = OutputCollection(
                        name="tool_outputs",
                        type="list",
                        label=f"Outputs from {tool_name}",
                    )
                    collection.append(
                        DiscoverDatasets(
                            pattern=_discover_pattern(pattern, input_link_names),
                            format=first_out_info.get("format", "vtkxml"),
                            visible=True,
                        )
                    )
                    outputs_tag.append(collection)
                    for extra in first_out_info.get("extra_outputs", []):
                        outputs_tag.append(
                            OutputData(
                                name=extra["name"],
                                format=extra["format"],
                                label=extra.get("label", extra["name"]),
                                from_work_dir=extra["from_work_dir"],
                            )
                        )
            else:
                single_file_outputs = [
                    v
                    for v in output_command_map.values()
                    if v.get("type") == "FIXED_FILE"
                ]
                if len(single_file_outputs) == 1 and len(output_command_map) == 1:
                    flag, info = list(output_command_map.items())[0]
                    outputs_tag.append(
                        OutputData(
                            name=f"output_{tool_name.lower()}",
                            format=info["format"],
                            from_work_dir=info["filename"],
                            label=f"Output from {tool_name}",
                        )
                    )
                else:
                    exts = sorted(
                        {
                            str(info["filename"]).rsplit(".", 1)[-1]
                            for info in single_file_outputs
                        }
                    )
                    collection = OutputCollection(
                        name="tool_outputs",
                        type="list",
                        label=f"Outputs from {tool_name}",
                    )
                    collection.append(
                        DiscoverDatasets(
                            pattern=_discover_pattern(
                                r"(?P<designation>output_[^.]*)\.(?:"
                                + "|".join(exts)
                                + r")",
                                input_link_names,
                            ),
                            format="data",
                            visible=True,
                        )
                    )
                    outputs_tag.append(collection)
        elif tool_name.lower() in IMPLICIT_OUTPUTS:
            outputs_tag = tool.outputs = Outputs()
            for spec in IMPLICIT_OUTPUTS[tool_name.lower()]:
                collection = OutputCollection(
                    name=spec["name"],
                    type="list",
                    label=spec["label"],
                )
                collection.append(
                    DiscoverDatasets(
                        pattern=_discover_pattern(
                            spec["pattern"], input_link_names
                        ),
                        format=spec["format"],
                        visible=True,
                    )
                )
                outputs_tag.append(collection)
        else:
            outputs_tag = tool.outputs = Outputs()
            outputs_tag.append(
                OutputData(
                    name="stdout_log",
                    format="txt",
                    label=f"Output Log from {tool_name}",
                )
            )

        tests_section = Tests()
        tests_section.append(Expand(macro=f"{tool_name.lower()}_test"))
        tool.tests = tests_section
        # The OGS help strings use ``*`` (``*.vtu``) and backticks that RST would
        # interpret as markup, so escape the characters that matter.
        tool_help = (
            cmdline_text
            or f"This tool runs the **{tool_name}** utility from the "
            "OpenGeoSys suite."
        )
        tool.help = re.sub(r"([*`|])", r"\\\1", tool_help)

        # --- 5. XML
        raw_xml_string = tool.export()
        tool_xml_root = ET.fromstring(raw_xml_string)

        # A tool without an OGS-supplied description gets no <description> at
        # all: repeating the tool name there is pure noise.
        if not tool_description:
            description_node = tool_xml_root.find("description")
            if description_node is not None:
                tool_xml_root.remove(description_node)

        # Insert the house <expand macro="creator"/> right after the
        # <expand macro="requirements"/> that galaxyxml emits automatically.
        for i, child in enumerate(tool_xml_root):
            if child.tag == "expand" and child.get("macro") == "requirements":
                tool_xml_root.insert(i + 1, ET.Element("expand", {"macro": "creator"}))
                break

        inputs_node = tool_xml_root.find("inputs")

        if inputs_node is not None:
            for param in galaxy_inputs:
                if getattr(param, "is_data_collection", False):
                    arg = getattr(param, "argument", None)
                    p_node = (
                        inputs_node.find(f"param[@argument='{arg}']") if arg else None
                    )
                    if p_node is None and getattr(param, "name", None):
                        # PVD element collections are declared by ``name`` and
                        # have no ``argument`` attribute in the emitted XML.
                        p_node = inputs_node.find(f"param[@name='{param.name}']")
                    if p_node is None and arg:
                        # Fall back to the (possibly stale) outer ``flag`` var.
                        p_node = inputs_node.find(f"param[@argument='--{flag}']")
                    if p_node is not None:
                        p_node.set("type", "data_collection")
                        p_node.set("collection_type", "list")
                        if "multiple" in p_node.attrib:
                            del p_node.attrib["multiple"]

        if inputs_node is not None:
            _derive_param_constraints(inputs_node)

        output_file_path = output_dir / f"{tool_name}.xml"
        ET.indent(tool_xml_root, space="  ")
        xml_str = ET.tostring(tool_xml_root, encoding="unicode")

        def version_cdata_rewrite(match):
            return f"<version_command><![CDATA[{match.group(1).strip()}]]></version_command>"

        xml_str = re.sub(
            r"<version_command>(.*?)</version_command>",
            version_cdata_rewrite,
            xml_str,
        )

        def command_cdata_rewrite(match):
            content = (
                match.group(1)
                .strip()
                .replace("&lt;", "<")
                .replace("&gt;", ">")
                .replace("&amp;", "&")
            )
            return f"<command><![CDATA[\n{content}\n]]></command>"

        xml_str = re.sub(
            r"<command.*?>(.*?)</command>",
            command_cdata_rewrite,
            xml_str,
            flags=re.DOTALL,
        )

        with open(output_file_path, "w", encoding="utf-8") as f:
            # No ``<?xml ... ?>`` declaration: Galaxy does not need it and the
            # house style omits it.
            f.write(xml_str + "\n")
        generated_count += 1

    eprint(f"\nFinished. {generated_count} tool wrappers created.")


def parse_diff_data(
    diff_str: str, base_url: str, workdir: str, input_files: List[str]
) -> List[Dict[str, str]]:
    diff_files = []
    seen_generated = set()
    valid_exts = (
        ".vtu",
        ".gml",
        ".bin",
        ".asc",
        ".pvtu",
        ".msh",
        ".smesh",
        ".xdmf",
        ".prj",
        ".xml",
        ".png",
        ".geo",
    )

    clean_lines = [line.split("#")[0].strip() for line in diff_str.strip().split("\n")]
    tokens = (" ".join(clean_lines)).split()

    i = 0
    while i < len(tokens):
        t1 = tokens[i]
        if any(t1.lower().endswith(ext) for ext in valid_exts):
            if i + 1 < len(tokens) and any(
                tokens[i + 1].lower().endswith(ext) for ext in valid_exts
            ):
                t2 = tokens[i + 1]

                if t2 not in input_files and t2 not in seen_generated:
                    ref_url = (
                        f"{base_url}/{workdir}/{t1}".replace("<PATH>", workdir)
                        if workdir
                        else f"{base_url}/{t1}"
                    )
                    diff_files.append(
                        {
                            "reference": ref_url,
                            "generated": t2,
                            "ftype": t2.split(".")[-1],
                        }
                    )
                    seen_generated.add(t2)
                i += 2
                continue
        i += 1
    return diff_files


def get_dummy_value(param, tool_name, all_params=None):
    def _tdata(relpath: str) -> str:
        # Official OGS test data, pinned commit.
        return f"{OGS_TEST_DATA_URL}/{relpath}"

    URL_AREHS_TEST = _tdata("Utils/VoxelGridFromLayers/AREHS_test.vtu")
    URL_AREHS_FAULT = _tdata("Utils/VoxelGridFromLayers/AREHS_fault.vtu")
    URL_PVD_MAIN = _tdata(
        "HydroMechanics/IdealGas/flow_pressure_boundary/flow_pressure_boundary.pvd"
    )
    URL_VTK_TEST = _tdata("Utils/VoxelGridFromLayers/AREHS_Layer17.vtu")

    special_tool_files = {
        "ComputeNodeAreasFromSurfaceMesh": "computeNodeAreasFromSurfaceMesh_test_data",
    }
    # For *_INPUT_FILE_LIST arguments the wrapper takes a single ASCII list
    # file (not a collection). Fall back to the correct, known list file for
    # tools that have no entry in Tests.cmake.
    file_list_fixtures = {
        "layers2grid": "Utils/VoxelGridFromLayers/AREHS_test_layers.txt",
    }
    if isinstance(param, DataParam):
        ext = getattr(param, "ogs_ext", "vtu").lower()
        if tool_name in special_tool_files:
            return f"{special_tool_files[tool_name]}.{ext}"
        if getattr(param, "is_file_list", False):
            return _tdata(
                file_list_fixtures.get(
                    tool_name.lower(), "Utils/VoxelGridFromLayers/AREHS_test_layers.txt"
                )
            )
        if getattr(param, "is_pvd", False):
            return URL_PVD_MAIN
        if (
            param_var_name(param) == "fault"
            or "fault" in (getattr(param, "label", "") or "").lower()
        ) and ext in [
            "vtu",
            "vtk",
            "msh",
        ]:
            return URL_AREHS_FAULT
        if ext in ["vtu", "msh"]:
            return URL_AREHS_TEST
        if ext in ["vtk"]:
            return URL_VTK_TEST
        return f"test.{ext}"

    if isinstance(param, SelectParam):
        opts = getattr(param, "options_dict", {})
        return list(opts.keys())[0] if opts else "value"
    if isinstance(param, (IntegerParam, FloatParam)):
        return "1" if isinstance(param, IntegerParam) else "1.0"
    if isinstance(param, BooleanParam):
        return "true"
    return "dummy_text"


def extra_outputs_of(tool_name: str) -> List[Dict[str, Any]]:
    """Fixed files written next to a base-filename collection output."""
    return BASE_FILENAME_OVERRIDES.get(tool_name.lower(), {}).get(
        "extra_outputs", []
    )


def fixed_outputs_of(tool_name: str) -> List[Dict[str, Any]]:
    """Files declared individually instead of a discovered collection."""
    return BASE_FILENAME_OVERRIDES.get(tool_name.lower(), {}).get(
        "outputs", []
    )


def apply_test_overrides(tool_name: str, test_case, galaxy_inputs) -> None:
    """Replace auto-derived test inputs with the curated ones for a tool.

    The generator can only match a parameter's *file extension* when it picks a
    fixture, which is not enough for utilities that need a particular kind of
    mesh, a real property name or a valid switch value. ``TEST_OVERRIDES``
    pins those values per tool; this applies them to an already-built
    ``<test>`` element.
    """
    overrides = TEST_OVERRIDES.get(tool_name.lower())
    if not overrides:
        return
    by_var = {param_var_name(p): p for p in galaxy_inputs}
    existing = {e.get("name"): e for e in test_case.findall("param")}
    for var, spec in overrides.items():
        param = by_var.get(var)
        if param is None:
            continue
        elem = existing.get(var)
        if spec is None:
            # Optional input the tool does not need for this test case.
            if elem is not None:
                test_case.remove(elem)
            continue
        if elem is None:
            elem = ET.SubElement(test_case, "param", {"name": var})
        if isinstance(param, DataParam):
            if isinstance(spec, tuple):
                # Vendored fixture in tools/ogs/test-data/.
                filename = spec[1]
                elem.set("value", filename)
                elem.attrib.pop("location", None)
            else:
                filename = spec.rsplit("/", 1)[-1]
                elem.set("value", filename)
                elem.set("location", f"{OGS_TEST_DATA_URL}/{spec}")
        else:
            elem.set("value", str(spec))


def generate_tests(ogs_root: Path, output_dir: Path):
    eprint("--- Generating Final Unified Test Macros ---")
    # Read the CMake test definitions from the local OGS clone (no network).
    cmake_path = Path(ogs_root) / UTILS_PATH / "Tests.cmake"
    if not cmake_path.exists():
        eprint(f"ERROR: {cmake_path} not found.")
        return
    cmake_content = cmake_path.read_text(encoding="utf-8", errors="ignore")

    all_tools_data = discover_tools(ogs_root)
    tools_map_lower = {
        tool["name"].lower(): tool
        for tool in all_tools_data
        if tool["name"].lower() not in EXCLUDED_TOOLS
    }
    tool_tests_accumulator = {tool_name: [] for tool_name in tools_map_lower.keys()}

    addtest_pattern = re.compile(r"AddTest\s*\((.*?)\s*\)(?!\s*PROPERTIES)", re.DOTALL)

    STOP_KEYWORDS = [
        "TESTER",
        "RUNTIME",
        "PROPERTIES",
        "DEPENDS",
        "REQUIREMENTS",
        "DIFF_DATA",
        "WRAPPER",
        "WRAPPER_ARGS",
    ]

    for match in addtest_pattern.finditer(cmake_content):
        test_block = match.group(1)

        exec_match = re.search(r"EXECUTABLE\s+([^\s\)]+)", test_block)
        matched_tool = None
        if exec_match and exec_match.group(1).lower() in tools_map_lower:
            matched_tool = exec_match.group(1).lower()
        else:
            # No direct EXECUTABLE match: the binary name can differ from the
            # .cpp-derived tool name (e.g. ``partmesh`` -> PartitionMesh). Scan
            # only the metadata fields -- NOT EXECUTABLE_ARGS, whose file paths
            # can name another tool (ExtractSurface reads
            # ``Utils/GMSH2OGS/quadratic_mesh.vtu``) and would otherwise
            # mis-attribute that test to the wrong tool.
            search_space = " ".join(
                m.group(1).lower()
                for m in re.finditer(
                    r"(?:NAME|PATH|WORKING_DIRECTORY)\s+([^\n\)]+)", test_block
                )
            )
            for t in tools_map_lower.keys():
                if re.search(
                    r"(?:[\s/_-]|^)" + re.escape(t) + r"(?:[\s/_-]|$)",
                    search_space,
                ):
                    matched_tool = t
                    break

        if not matched_tool or matched_tool.lower() in EXCLUDED_TOOLS:
            continue

        tool_data = tools_map_lower[matched_tool]
        g_inputs_temp, _ = process_parameters(tool_data["parameters"], matched_tool)
        # Skip only true PVD inputs (a list of .vtu members that must be
        # rendered as a collection). File-list inputs are single txt files
        # nowadays and render fine from the real EXECUTABLE_ARGS recipe.
        has_complex_input = any(
            getattr(p, "is_pvd", False) for p in g_inputs_temp
        )

        if has_complex_input:
            eprint(
                f"   -> Marking {matched_tool} for Dummy-Test (Complex PVD input)."
            )
            continue

        if tool_tests_accumulator[matched_tool]:
            continue
        galaxy_inputs, output_map = process_parameters(
            tool_data["parameters"], matched_tool
        )
        # A tool whose wrapper has no output *file* falls back to capturing
        # command stdout as a ``stdout_log`` text output (see generate_tools).
        output_has_stdout = (
            not output_map and matched_tool.lower() not in IMPLICIT_OUTPUTS
        )
        all_inputs_map = {param_var_name(p): p for p in galaxy_inputs}

        flag_map = {}
        unlabeled_p = next(
            (p for p in galaxy_inputs if getattr(p, "is_unlabeled", False)), None
        )
        for p in galaxy_inputs:
            if hasattr(p, "original_long_flag") and p.original_long_flag:
                flag_map[f"--{p.original_long_flag}"] = p
            if hasattr(p, "original_short_flag") and p.original_short_flag:
                flag_map[f"-{p.original_short_flag}"] = p

        path_match = re.search(r"PATH\s+([^\s\)]+)", test_block)
        p_rep = path_match.group(1).strip() if path_match else ""
        wd_match = re.search(
            r"WORKING_DIRECTORY\s+\$\{Data_SOURCE_DIR\}/([^\s\)]+)", test_block
        )
        wd_sub = wd_match.group(1).replace("<PATH>", p_rep).strip() if wd_match else ""

        # ARGUMENT PARSING
        params_in_test = {}
        input_files_in_this_test = []
        args_match = re.search(r"EXECUTABLE_ARGS\s+(.*)", test_block, re.DOTALL)
        if args_match:
            raw_args = args_match.group(1).split(")")[0].strip().replace("\n", " ")
            norm_args = raw_args.replace(" -- ", " --SEP-- ")
            try:
                args_list = shlex.split(norm_args)
            except ValueError:
                args_list = norm_args.split()

            i = 0
            while i < len(args_list):
                arg = args_list[i]
                if arg.upper() in STOP_KEYWORDS:
                    break

                if arg in flag_map:
                    p = flag_map[arg]
                    i += 1
                    if isinstance(p, BooleanParam):
                        params_in_test[param_var_name(p)] = "true"
                    else:
                        collected_vals = []
                        while (
                            i < len(args_list)
                            and not args_list[i].startswith("-")
                            and args_list[i].upper() not in STOP_KEYWORDS
                        ):
                            val = (
                                args_list[i]
                                .replace("<PATH>", p_rep)
                                .replace("<SOURCE_PATH>", p_rep)
                                .replace("${Data_SOURCE_DIR}/", "")
                                .replace("${Data_BINARY_DIR}/", "")
                                .lstrip("/")
                            )
                            if val:
                                collected_vals.append(val)
                            i += 1
                        if collected_vals:
                            params_in_test[param_var_name(p)] = ",".join(collected_vals)
                        continue

                elif unlabeled_p and not arg.startswith("-"):
                    current_unlabeled = []
                    if param_var_name(unlabeled_p) in params_in_test:
                        current_unlabeled = (
                            params_in_test[param_var_name(unlabeled_p)].split(",")
                        )

                    while (
                        i < len(args_list)
                        and not args_list[i].startswith("-")
                        and args_list[i].upper() not in STOP_KEYWORDS
                    ):
                        val = (
                            args_list[i]
                            .replace("<PATH>", p_rep)
                            .replace("<SOURCE_PATH>", p_rep)
                            .replace("${Data_SOURCE_DIR}/", "")
                            .replace("${Data_BINARY_DIR}/", "")
                            .lstrip("/")
                        )
                        if any(
                            val.lower().endswith(ext)
                            for ext in [
                                ".pvd",
                                ".vtu",
                                ".msh",
                                ".gml",
                                ".asc",
                                ".nc",
                                ".xyz",
                            ]
                        ):
                            current_unlabeled.append(val)
                        i += 1
                    if current_unlabeled:
                        params_in_test[param_var_name(unlabeled_p)] = ",".join(
                            current_unlabeled
                        )
                    continue

                i += 1

        # XML generation
        test_case = ET.Element("test")
        test_is_valid = True
        test_params_xml = []

        for p_name, p_val in params_in_test.items():
            p_obj = all_inputs_map.get(p_name)
            if not p_obj:
                continue

            val_clean = (
                str(p_val)
                .replace("<PATH>", p_rep)
                .replace("<SOURCE_PATH>", p_rep)
                .replace("${Data_BINARY_DIR}/", "")
                .replace("${Data_SOURCE_DIR}/", "")
                .lstrip("/")
            )

            # PVD
            if getattr(p_obj, "is_pvd", False):
                pvd_members = [
                    v
                    for v in re.findall(r"([^\s/]+\.vt[ui])", test_block)
                    if not v.endswith(".pvd")
                ]
                if pvd_members:
                    p_pvd_name = f"{p_name}_pvd_data"
                    coll_param = ET.Element("param", {"name": p_pvd_name})
                    coll_wrapper = ET.SubElement(
                        coll_param, "collection", {"type": "list"}
                    )

                    for v in sorted(set(pvd_members)):
                        url = (
                            f"{OGS_TEST_DATA_URL}/{wd_sub}/{v}"
                            if wd_sub
                            else f"{OGS_TEST_DATA_URL}/{v}"
                        )
                        ET.SubElement(
                            coll_wrapper,
                            "element",
                            {"name": v, "value": v, "location": url, "ftype": "vtkxml"},
                        )
                    test_params_xml.append(coll_param)

            # Collections / INPUT_FILE_LIST
            if getattr(p_obj, "is_data_collection", False):
                files_to_process = val_clean.split(",")
                coll_param = ET.Element("param", {"name": p_name})
                coll_wrapper = ET.SubElement(coll_param, "collection", {"type": "list"})

                for f_path in files_to_process:
                    f_name = f_path.split("/")[-1]
                    url = _fixture_url(f_path, wd_sub)

                    if not url_exists(url):
                        test_is_valid = False
                        break

                    ET.SubElement(
                        coll_wrapper,
                        "element",
                        {
                            "name": f_name,
                            "value": f_name,
                            "location": url,
                            "ftype": p_obj.format.split(",")[0],
                        },
                    )

                if test_is_valid:
                    test_params_xml.append(coll_param)

            # 3. single parameter
            else:
                attrs = {"name": p_name}
                if isinstance(p_obj, DataParam):
                    f_name = val_clean.split("/")[-1]
                    url = _fixture_url(val_clean, wd_sub)
                    if not url_exists(url):
                        test_is_valid = False
                        break
                    attrs.update(
                        {
                            "value": f_name,
                            "location": url,
                            "ftype": p_obj.format.split(",")[0],
                        }
                    )
                else:
                    is_base_filename_param = any(
                        sanitize_name(flag) == p_name
                        and info.get("type") == "BASE_FILENAME"
                        for flag, info in output_map.items()
                    )
                    attrs["value"] = (
                        BASE_FILENAME_OVERRIDES.get(matched_tool.lower(), {}).get(
                            "base_value", "new_"
                        )
                        if is_base_filename_param
                        else val_clean.split("/")[-1]
                    )

                test_params_xml.append(ET.Element("param", attrs))

            if not test_is_valid:
                break

        if not test_is_valid:
            continue

        for elem in test_params_xml:
            val = elem.get("value")
            if val and val.startswith("${") and val.endswith("}"):
                p_name = elem.get("name")
                p_obj = all_inputs_map.get(p_name)
                if p_obj:
                    new_val = get_dummy_value(
                        p_obj, matched_tool, all_params=galaxy_inputs
                    )
                    elem.set("value", str(new_val))

        for xml_elem in test_params_xml:
            test_case.append(xml_elem)

        # --- OUTPUT LOGIK ---
        dm = re.search(r"DIFF_DATA\s+(.*?)(?=\s*\)|$)", test_block, re.DOTALL)
        output_added = False
        # Set below when the test asserts exactly one plain data output, so we
        # can emit ``expect_num_outputs="1"`` (guards against silently
        # dropped or extra outputs). Collection outputs have a data-dependent
        # element count and are left without an explicit count.
        expect_single_output = False

        if dm:
            diff_files = parse_diff_data(
                dm.group(1).strip(),
                OGS_TEST_DATA_URL,
                wd_sub,
                input_files_in_this_test,
            )
            if diff_files:
                diff_files.sort(key=lambda x: x["generated"])
                if fixed_outputs_of(matched_tool):
                    # Individual outputs are asserted from the override below.
                    pass
                elif len(output_map) > 1 or any(
                    info.get("type") == "BASE_FILENAME"
                    or info.get("is_directory")
                    for info in output_map.values()
                ):
                    # Discovered collections have data-dependent element names
                    # (base-filename tools append their own suffixes), so assert
                    # on the element count instead.
                    ET.SubElement(
                        test_case,
                        "output_collection",
                        {"name": "tool_outputs", "type": "list", "min": "1"},
                    )
                    output_added = True
                elif len(diff_files) == 1:
                    out_name = sanitize_name(f"output_{matched_tool}")
                    out_elem = ET.SubElement(test_case, "output", {"name": out_name})
                    ET.SubElement(
                        ET.SubElement(out_elem, "assert_contents"),
                        "has_size",
                        {"min": "100"},
                    )
                    output_added = True
                    expect_single_output = True

        # Fallback
        # Utilities in ``IMPLICIT_OUTPUTS`` write their files without an output
        # flag; each declared collection is asserted to be non-empty.
        if not output_added and matched_tool.lower() in IMPLICIT_OUTPUTS:
            for spec in IMPLICIT_OUTPUTS[matched_tool.lower()]:
                ET.SubElement(
                    test_case,
                    "output_collection",
                    {"name": spec["name"], "type": "list", "min": "1"},
                )
                output_added = True

        if not output_added and not output_map and output_has_stdout:
            # Tool captures command stdout as a ``stdout_log`` text output
            # (the wrapper has no real output file). Assert it exists.
            out_elem = ET.SubElement(test_case, "output", {"name": "stdout_log"})
            ET.SubElement(
                ET.SubElement(out_elem, "assert_contents"), "has_size", {"min": "1"}
            )
            output_added = True
            expect_single_output = True

        if not output_added and output_map:
            if fixed_outputs_of(matched_tool):
                # Individual outputs are asserted below.
                pass
            elif len(output_map) > 1 or any(
                info.get("type") == "BASE_FILENAME"
                or info.get("is_directory")
                for info in output_map.values()
            ):
                # Element names of a discovered collection are data dependent
                # (base-filename tools append their own suffixes), so assert on
                # the element count instead.
                ET.SubElement(
                    test_case,
                    "output_collection",
                    {"name": "tool_outputs", "type": "list", "min": "1"},
                )
                pass
            else:
                out_name = sanitize_name(f"output_{matched_tool}")
                out_elem = ET.SubElement(test_case, "output", {"name": out_name})
                ET.SubElement(
                    ET.SubElement(out_elem, "assert_contents"), "has_size", {"min": "1"}
                )
                expect_single_output = True

        extras = extra_outputs_of(matched_tool) + fixed_outputs_of(matched_tool)
        for extra in extras:
            out_elem = ET.SubElement(
                test_case, "output", {"name": extra["name"]}
            )
            ET.SubElement(
                ET.SubElement(out_elem, "assert_contents"),
                "has_size",
                {"min": "1"},
            )
        if matched_tool.lower() in IMPLICIT_OUTPUTS:
            # Only the implicit collections above; no ``stdout_log``.
            test_case.set(
                "expect_num_outputs", str(len(IMPLICIT_OUTPUTS[matched_tool.lower()]))
            )
        elif fixed_outputs_of(matched_tool):
            # Every output is declared explicitly; there is no collection.
            test_case.set("expect_num_outputs", str(len(extras)))
        elif extras:
            test_case.set("expect_num_outputs", str(len(extras) + 1))
        elif expect_single_output:
            test_case.set("expect_num_outputs", "1")

        apply_test_overrides(matched_tool, test_case, galaxy_inputs)
        tool_tests_accumulator[matched_tool].append(test_case)

    # Build Macros
    macros_root = ET.Element("macros")
    for t_name, cases in tool_tests_accumulator.items():
        macro_xml = ET.SubElement(macros_root, "xml", {"name": f"{t_name}_test"})

        if not cases:
            fallback_test = ET.SubElement(macro_xml, "test")
            tool_data = tools_map_lower[t_name]
            g_inputs, g_outputs = process_parameters(tool_data["parameters"], t_name)

            for p in g_inputs:
                is_data_coll = getattr(p, "is_data_collection", False)

                if is_data_coll:
                    if getattr(p, "is_pvd_element", False):
                        urls = [
                            f"{OGS_TEST_DATA_URL}/HydroMechanics/IdealGas/flow_pressure_boundary/flow_pressure_boundary_ts_0_t_0.000000.vtu",
                            f"{OGS_TEST_DATA_URL}/HydroMechanics/IdealGas/flow_pressure_boundary/flow_pressure_boundary_ts_100_t_4000.000000.vtu",
                        ]
                    elif getattr(p, "is_file_list", False) or param_var_name(p) == "raster_list":
                        urls = [
                            f"{OGS_TEST_DATA_URL}/Utils/VoxelGridFromLayers/AREHS_Layer0.vtu",
                            f"{OGS_TEST_DATA_URL}/Utils/VoxelGridFromLayers/AREHS_Layer15.vtu",
                        ]
                    else:
                        urls = [get_dummy_value(p, t_name, all_params=g_inputs)]

                    coll_node = ET.SubElement(
                        fallback_test, "param", {"name": param_var_name(p)}
                    )
                    coll_wrapper = ET.SubElement(
                        coll_node, "collection", {"type": "list"}
                    )
                    for url in urls:
                        filename = url.split("/")[-1]
                        ET.SubElement(
                            coll_wrapper,
                            "element",
                            {
                                "name": filename,
                                "value": filename,
                                "location": url,
                                "ftype": "vtkxml",
                            },
                        )
                    continue

                # Standard parameter
                is_mandatory = not is_param_optional(p, default=True)
                if (
                    is_mandatory
                    or isinstance(p, DataParam)
                    or isinstance(p, SelectParam)
                ):
                    val_str = get_dummy_value(p, t_name, all_params=g_inputs)
                    is_ext = str(val_str).startswith("http")
                    clean_val = val_str.split("/")[-1] if is_ext else val_str
                    attrs = {"name": param_var_name(p), "value": clean_val}
                    if isinstance(p, DataParam):
                        attrs["ftype"] = p.format.split(",")[0]
                        if is_ext:
                            attrs["location"] = val_str
                    ET.SubElement(fallback_test, "param", attrs)

            apply_test_overrides(t_name, fallback_test, g_inputs)

            # Outputs
            if g_outputs:
                if fixed_outputs_of(t_name):
                    # Individual outputs are asserted below.
                    pass
                elif len(g_outputs) > 1 or any(
                    info.get("type") == "BASE_FILENAME"
                    or info.get("is_directory")
                    for info in g_outputs.values()
                ):
                    # Element names of a discovered collection are data
                    # dependent (base-filename tools append their own suffixes),
                    # so assert on the element count instead.
                    ET.SubElement(
                        fallback_test,
                        "output_collection",
                        {"name": "tool_outputs", "type": "list", "min": "1"},
                    )
                else:
                    out_n = sanitize_name(f"output_{t_name}")
                    out_tag = ET.SubElement(fallback_test, "output", {"name": out_n})
                    ET.SubElement(
                        ET.SubElement(out_tag, "assert_contents"),
                        "has_size",
                        {"min": "1"},
                    )
                    fallback_test.set("expect_num_outputs", "1")

            elif t_name.lower() in IMPLICIT_OUTPUTS:
                # Files written next to the input geometry, no output flag.
                for spec in IMPLICIT_OUTPUTS[t_name.lower()]:
                    ET.SubElement(
                        fallback_test,
                        "output_collection",
                        {"name": spec["name"], "type": "list", "min": "1"},
                    )
                fallback_test.set(
                    "expect_num_outputs", str(len(IMPLICIT_OUTPUTS[t_name.lower()]))
                )

            else:
                out_tag = ET.SubElement(fallback_test, "output", {"name": "stdout_log"})
                ac = ET.SubElement(out_tag, "assert_contents")
                ET.SubElement(ac, "has_size", {"min": "1"})
                fallback_test.set("expect_num_outputs", "1")

            extras = extra_outputs_of(t_name) + fixed_outputs_of(t_name)
            for extra in extras:
                out_elem = ET.SubElement(
                    fallback_test, "output", {"name": extra["name"]}
                )
                ET.SubElement(
                    ET.SubElement(out_elem, "assert_contents"),
                    "has_size",
                    {"min": "1"},
                )
            if fixed_outputs_of(t_name):
                fallback_test.set("expect_num_outputs", str(len(extras)))
            elif extras:
                fallback_test.set("expect_num_outputs", str(len(extras) + 1))
        else:
            for case in cases:
                macro_xml.append(case)

    tree = ET.ElementTree(macros_root)
    ET.indent(tree, space="    ")
    out_path = Path(output_dir) / "test_macros.xml"
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with open(out_path, "wb") as f:
        f.write(b'<?xml version="1.0" encoding="UTF-8"?>\n')
        tree.write(f, encoding="utf-8", xml_declaration=False)
    eprint(f"Wrote {out_path}")


def _check_outputs(ogs_root: Path, target: Path) -> int:
    """Regenerate every tool wrapper and the test macros and verify they match.

    Wrappers must be produced by the generator (no hand-edits), so CI can
    assert that the committed ``tools/ogs/`` outputs are reproducible. Each
    file the generator produces (61 tool XMLs + ``test_macros.xml``) is
    regenerated into a throw-away directory and compared byte-for-byte with
    its counterpart under ``target`` (normally ``tools/ogs/``).

    Returns 0 if everything matches (plain string-files also byte matches),
    else returns the number of mismatches (and prints each one).
    """
    with tempfile.TemporaryDirectory(prefix="ogs_autowrap_ck_") as tmp:
        out = Path(tmp)
        # --check always regenerates the full, canonical output set.
        generate_tools(ogs_root, out)
        generate_tests(ogs_root, out)
        generated = sorted(out.glob("*.xml"))
        mismatches = 0
        for f in generated:
            counterpart = target / f.name
            if not counterpart.exists():
                eprint(f"CHECK MISMATCH: generated {f.name} has no counterpart in {target}")
                mismatches += 1
                continue
            with open(f, "rb") as a, open(counterpart, "rb") as b:
                if a.read() != b.read():
                    eprint(f"CHECK MISMATCH: {target / f.name} differs from regenerated output")
                    mismatches += 1
        if mismatches:
            eprint(f"CHECK FAILED: {mismatches} file(s) out of sync with generator (run --generate-tools --generate-tests).")
        else:
            logging.info(f"--check: all {len(generated)} generated files match {target}")
        return mismatches


def main():
    parser = argparse.ArgumentParser(
        description="Galaxy XML Wrapper Generator for OGS Utilities"
    )
    parser.add_argument(
        "--ogs-root",
        required=True,
        type=Path,
        help="Path to a local clone of the OGS source tree.",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path("."),
        help="Directory to write the generated tool XML files into.",
    )
    parser.add_argument(
        "--generate-tools",
        action="store_true",
        help="Generate individual tool XML wrappers (default action).",
    )
    parser.add_argument(
        "--generate-tests",
        action="store_true",
        help="Generate a single test_macros.xml file for all tools.",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="Regenerate everything and verify it matches the committed tools/ogs/ outputs "
        "(exit non-zero on drift). Implies --generate-tools --generate-tests.",
    )
    parser.add_argument(
        "--check-target",
        type=Path,
        default=Path("tools/ogs"),
        help="Directory the generated outputs are expected to match (default: tools/ogs).",
    )

    parser.add_argument(
        "--verify-urls",
        action="store_true",
        help="HEAD-check test-data fixture URLs instead of trusting the pinned "
        "commit (network-dependent; off by default so --check is deterministic).",
    )

    args = parser.parse_args()

    global VERIFY_URLS
    VERIFY_URLS = args.verify_urls

    if args.check:
        sys.exit(1 if _check_outputs(args.ogs_root, args.check_target) else 0)

    if args.generate_tests:
        generate_tests(args.ogs_root, args.output_dir)
    if args.generate_tools:
        generate_tools(args.ogs_root, args.output_dir)
    if not args.generate_tests and not args.generate_tools:
        # Default: generate the tool wrappers.
        generate_tools(args.ogs_root, args.output_dir)


if __name__ == "__main__":
    main()
