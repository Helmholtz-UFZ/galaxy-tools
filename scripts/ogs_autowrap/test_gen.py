"""Tests for the generator helpers that do not need an OGS source tree.

Run with::

    python -m unittest discover -s scripts/ogs_autowrap -p 'test_*.py'
"""

import re
import string
import sys
import tempfile
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parent))

import gen  # noqa: E402


DISCOVERED = {"sometool", "othertool", "queried"}
PARAMS = {
    "sometool": {"input_file", "raster_list", "threshold"},
    "othertool": {"input"},
}
FLAGS = {
    "sometool": {"input-file", "raster-list", "threshold", "output-file"},
    "othertool": {"input"},
}
# Only the tests that are about collection inputs declare a ``<var>__members``
# fixture key, so the other cases are not polluted by the "missing members"
# check.
VIRTUAL = {"sometool": set(), "othertool": set()}
VIRTUAL_WITH_MEMBERS = {"sometool": {"raster_list__members"}, "othertool": set()}


class CuratedTableAuditTest(unittest.TestCase):
    """The audit is the only thing that catches a curated key that names nothing."""

    def audit(self, virtual=None, **tables):
        """Run the audit with the given tables patched in."""
        defaults = {
            "TEST_OVERRIDES": {},
            "PARAM_EXT_OVERRIDES": {},
            "OUTPUT_EXT_OVERRIDES": {},
            "MANIFEST_INPUTS": {},
            "NON_PVD_INPUTS": set(),
            "IMPLICIT_OUTPUTS": {},
            "BASE_FILENAME_OVERRIDES": {},
            "EXCLUDED_TOOLS": [],
            "EXCLUSIVE_MODES": {},
            "TEXT_VALIDATORS": {},
            "EXTRA_TESTS": {},
        }
        defaults.update(tables)
        with patch.multiple(gen, **defaults):
            return gen._audit_curated_tables(
                set(DISCOVERED), PARAMS, FLAGS, VIRTUAL if virtual is None else virtual
            )

    def test_consistent_tables_report_nothing(self):
        problems = self.audit(
            TEST_OVERRIDES={"sometool": {"input_file": "x.vtu"}},
            MANIFEST_INPUTS={
                ("sometool", "raster_list"): {"kind": "file_list", "format": "raster.asc"}
            },
            PARAM_EXT_OVERRIDES={("sometool", "threshold"): "vtu"},
            OUTPUT_EXT_OVERRIDES={("sometool", "output-file"): "gml"},
            NON_PVD_INPUTS={("othertool", "input")},
            EXCLUDED_TOOLS=["queried"],
        )
        self.assertEqual(problems, [])

    def test_typo_in_parameter_name_is_reported_with_suggestion(self):
        problems = self.audit(TEST_OVERRIDES={"sometool": {"rasterlist": "a.asc"}})
        self.assertEqual(len(problems), 1)
        self.assertIn("TEST_OVERRIDES['sometool']['rasterlist']", problems[0])
        self.assertIn("did you mean 'raster_list'?", problems[0])

    def test_unknown_tool_is_reported(self):
        problems = self.audit(TEST_OVERRIDES={"sometol": {"input_file": "x.vtu"}})
        self.assertIn("no such generated tool", problems[0])

    def test_curated_tool_that_is_also_excluded_is_reported(self):
        problems = self.audit(
            TEST_OVERRIDES={"queried": {"input": "x.vtu"}}, EXCLUDED_TOOLS=["queried"]
        )
        self.assertIn("EXCLUDED_TOOLS", problems[0])

    def test_collection_input_without_members_fixture_is_reported(self):
        problems = self.audit(
            virtual=VIRTUAL_WITH_MEMBERS,
            TEST_OVERRIDES={"sometool": {"input_file": "x.vtu"}},
        )
        self.assertEqual(len(problems), 1)
        self.assertIn("raster_list__members", problems[0])
        self.assertIn("dummy test", problems[0])

    def test_param_ext_override_is_keyed_by_variable_name(self):
        # The lookup uses the variable name, not the long flag.
        problems = self.audit(PARAM_EXT_OVERRIDES={("sometool", "input-file"): "vtu"})
        self.assertIn("PARAM_EXT_OVERRIDES", problems[0])

    def test_output_ext_override_is_keyed_by_long_flag(self):
        # Output flags never become parameters, so the flag universe differs.
        problems = self.audit(OUTPUT_EXT_OVERRIDES={("sometool", "output_file"): "gml"})
        self.assertIn("OUTPUT_EXT_OVERRIDES", problems[0])
        self.assertIn("no such output argument", problems[0])

    def test_unknown_manifest_kind_is_reported(self):
        problems = self.audit(
            virtual=VIRTUAL_WITH_MEMBERS,
            MANIFEST_INPUTS={("sometool", "raster_list"): {"kind": "file-list"}},
            TEST_OVERRIDES={"sometool": {"raster_list__members": "a.asc"}},
        )
        self.assertIn("unknown kind", problems[0])

    def test_base_filename_flag_must_exist(self):
        problems = self.audit(
            BASE_FILENAME_OVERRIDES={
                "sometool": {"flag": "output", "pattern": r"(?P<designation>.*)\.vtu"}
            }
        )
        self.assertIn("BASE_FILENAME_OVERRIDES", problems[0])
        self.assertIn("did you mean 'output-file'?", problems[0])

    def test_excluded_tool_must_exist_in_the_tree(self):
        problems = self.audit(EXCLUDED_TOOLS=["querymesh"])
        self.assertIn("is not a utility in this OGS tree", problems[0])


class ExclusiveModeAuditTest(unittest.TestCase):
    """``EXCLUSIVE_MODES`` is the newest table, so it gets its own checks."""

    def audit(self, modes, **tables):
        defaults = {
            "TEST_OVERRIDES": {},
            "PARAM_EXT_OVERRIDES": {},
            "OUTPUT_EXT_OVERRIDES": {},
            "MANIFEST_INPUTS": {},
            "NON_PVD_INPUTS": set(),
            "IMPLICIT_OUTPUTS": {},
            "BASE_FILENAME_OVERRIDES": {},
            "EXCLUDED_TOOLS": [],
            "EXCLUSIVE_MODES": modes,
            "TEXT_VALIDATORS": {},
            "EXTRA_TESTS": {},
        }
        defaults.update(tables)
        with patch.multiple(gen, **defaults):
            return gen._audit_curated_tables(set(DISCOVERED), PARAMS, FLAGS, VIRTUAL)

    @staticmethod
    def mode(flag, params=()):
        return {"flag": flag, "label": flag, "params": list(params)}

    def test_consistent_group_reports_nothing(self):
        problems = self.audit(
            {
                "sometool": {
                    "name": "mode",
                    "label": "mode",
                    "help": "",
                    "modes": {
                        "one": self.mode("threshold", ["input_file"]),
                        "two": self.mode("input-file"),
                    },
                }
            }
        )
        self.assertEqual(problems, [])

    def test_unknown_mode_flag_is_reported_with_suggestion(self):
        problems = self.audit(
            {"sometool": {"name": "mode", "modes": {"one": self.mode("treshold")}}}
        )
        self.assertEqual(len(problems), 1)
        self.assertIn("EXCLUSIVE_MODES['sometool']['modes']['one']", problems[0])
        self.assertIn("did you mean 'threshold'?", problems[0])

    def test_unknown_mode_parameter_is_reported_with_suggestion(self):
        problems = self.audit(
            {
                "sometool": {
                    "name": "mode",
                    "modes": {"one": self.mode("threshold", ["input_fil"])},
                }
            }
        )
        self.assertEqual(len(problems), 1)
        self.assertIn("no such parameter 'input_fil'", problems[0])
        self.assertIn("did you mean 'input_file'?", problems[0])

    def test_group_for_an_excluded_tool_is_reported(self):
        problems = self.audit(
            {"queried": {"name": "mode", "modes": {"one": self.mode("input")}}},
            EXCLUDED_TOOLS=["queried"],
        )
        self.assertIn("EXCLUDED_TOOLS", problems[0])

    def test_group_for_an_unknown_tool_is_reported(self):
        problems = self.audit(
            {"sometol": {"name": "mode", "modes": {"one": self.mode("threshold")}}}
        )
        self.assertIn("no such generated tool", problems[0])


class DatatypeMapTest(unittest.TestCase):
    def test_mapped_datatype_returns_none_for_unknown_extension(self):
        self.assertIsNone(gen.mapped_datatype("xyz"))
        self.assertEqual(gen.get_ogs_ftype(["xyz"]), "data")

    def test_msh_depends_on_role(self):
        self.assertEqual(gen.mapped_datatype("msh", role="input"), "gmsh.msh")
        # A legacy OGS-5 ``.msh`` written by the utilities is ASCII.
        self.assertEqual(gen.mapped_datatype("msh", role="output"), "txt")

    def test_binary_formats_are_not_text(self):
        # ``.plt`` is binary TecPlot and ``.bin`` a raw dump: as ``txt`` Galaxy
        # would run them through text sanitising.
        self.assertEqual(gen.mapped_datatype("plt"), "binary")
        self.assertEqual(gen.mapped_datatype("bin"), "binary")

    def test_ascii_gocad_surfaces_are_not_xml(self):
        for ext in ("ts", "pl", "mx"):
            self.assertEqual(gen.mapped_datatype(ext), "txt", ext)

    def test_every_mapped_datatype_is_a_galaxy_type(self):
        # No OGS-specific custom datatypes are shipped, so the wrappers may only
        # use formats Galaxy defines itself.
        galaxy_types = {
            "vtkxml",
            "gmsh.msh",
            "gocad.sg",
            "feflow.fem",
            "xml",
            "raster.asc",
            "csv",
            "json",
            "txt",
            "binary",
            "data",
            "netcdf",
            "h5",
        }
        self.assertLessEqual(set(gen.DATATYPE_MAP.values()), galaxy_types)


class IdentifierSanitizationTest(unittest.TestCase):
    """The element identifier becomes a file name in the generated command."""

    def sanitize(self, name):
        import re

        return re.sub(gen.IDENTIFIER_UNSAFE, "_", name)

    def test_shell_metacharacters_are_replaced(self):
        self.assertEqual(self.sanitize("a b.vtu"), "a_b.vtu")
        self.assertEqual(self.sanitize("a'b;rm -rf x.vtu"), "a_b_rm_-rf_x.vtu")
        self.assertEqual(self.sanitize("$(whoami).vtu"), "__whoami_.vtu")

    def test_name_the_manifest_refers_to_is_kept(self):
        # OGS Gocad SGrid data files really are called ``..._points@@``.
        self.assertEqual(
            self.sanitize("SGrid_Testflow_x__points@@"), "SGrid_Testflow_x__points@@"
        )

    def test_staging_block_checks_for_collisions(self):
        block = gen.identifier_staging("layers")
        self.assertIn("#set $safe_names = [re.sub(", block)
        self.assertIn("for $item in $layers]", block)
        self.assertIn("if len($safe_names) != len(set($safe_names))", block)
        self.assertIn("exit 1", block)

    def test_single_element_block_and_staging_use_the_same_pattern(self):
        self.assertIn(gen.IDENTIFIER_UNSAFE, gen.SANITIZE_IDENTIFIER)
        self.assertIn(gen.IDENTIFIER_UNSAFE, gen.identifier_staging("x"))


class TextParameterValidationTest(unittest.TestCase):
    """Text parameters reach the shell, so they are validated instead of unfiltered.

    A value interpolated into ``'$param'`` that contains a single quote ends the
    quoting and can run arbitrary commands, which is why the wrappers used to
    set ``<sanitizer sanitize="false"/>``. They must not: Galaxy's default
    sanitiser is what keeps the quote out.
    """

    # galaxy.util.valid_chars -- what Galaxy passes through unchanged. Every
    # other printable character is either escaped (mapped) or replaced by "X".
    GALAXY_VERBATIM = set(string.ascii_letters + string.digits + " -=_.()/+*^,:?!")

    def allowed(self, pattern):
        return {
            chr(code)
            for code in range(32, 127)
            if re.match(pattern, "v" + chr(code) + "v")
        }

    def test_generic_pattern_allows_exactly_the_verbatim_characters(self):
        self.assertEqual(self.allowed(gen.TEXT_VALUE_PATTERN), self.GALAXY_VERBATIM)

    def test_generic_pattern_rejects_the_shell_metacharacters(self):
        for bad in ("'", '"', "`", "$", "\\", ";", "&", "|", "<", ">", "\n", "\t"):
            self.assertIsNone(
                re.match(gen.TEXT_VALUE_PATTERN, "a" + bad + "b"),
                f"{bad!r} must not be accepted",
            )

    def test_generic_pattern_rejects_injection_attempts(self):
        for bad in ("'; rm -rf /", "$(whoami)", "`id`", "x' | nc host 1", "';'", "a\nb"):
            self.assertIsNone(re.match(gen.TEXT_VALUE_PATTERN, bad), bad)

    def test_generic_pattern_accepts_property_and_geometry_names(self):
        for good in ("bulk_node_ids", "Material IDs", "2nd layer", "T/x", "a,b", "x-y.z"):
            self.assertIsNotNone(re.match(gen.TEXT_VALUE_PATTERN, good), good)

    def test_generic_pattern_requires_a_value(self):
        # ``optional`` fields skip validators when empty, so the pattern itself
        # does not have to allow the empty string.
        self.assertIsNone(re.match(gen.TEXT_VALUE_PATTERN, ""))

    def test_text_validator_prefers_the_ogs_derived_pattern(self):
        pattern, message = gen.text_validator("swapnodecoordinateaxes", "new_order")
        self.assertEqual(pattern, r"^[xyz]{3}$")
        self.assertIn("x, y and z", message)
        self.assertIsNotNone(re.match(pattern, "xzy"))

    def test_new_order_pattern_matches_the_ogs_check(self):
        # parseNewOrder() in swapNodeCoordinateAxes.cpp: three characters, each
        # x, y or z. It additionally rejects repetitions, which a regex cannot
        # express -- OGS reports that case itself.
        pattern = gen.text_validator("swapnodecoordinateaxes", "new_order")[0]
        for good in ("xyz", "xzy", "zyx"):
            self.assertIsNotNone(re.match(pattern, good), good)
        for bad in ("xy", "xyzz", "XY Z", "xyZ", "x y", ""):
            self.assertIsNone(re.match(pattern, bad), bad)

    def test_char_property_value_is_a_single_character(self):
        # --char-property-value is a TCLAP ValueArg<char>.
        pattern = gen.text_validator(
            "resetpropertiesinpolygonalregion", "char_property_value"
        )[0]
        for good in ("A", "7", ".", " "):
            self.assertIsNotNone(re.match(pattern, good), good)
        for bad in ("", "AB", "a'b", "\\'"):
            self.assertIsNone(re.match(pattern, bad), bad)

    def test_unknown_parameter_falls_back_to_the_generic_pattern(self):
        self.assertEqual(
            gen.text_validator("sometool", "some_param"),
            (gen.TEXT_VALUE_PATTERN, gen.TEXT_VALUE_MESSAGE),
        )

    def test_every_curated_pattern_compiles_and_is_stricter(self):
        generic = self.allowed(gen.TEXT_VALUE_PATTERN)
        for key, spec in gen.TEXT_VALIDATORS.items():
            with self.subTest(key=key):
                re.compile(spec["pattern"])
                self.assertTrue(spec["message"])
                # A curated pattern must not be a superset of the generic one:
                # it either restricts further or stays within it.
                stricter = {
                    chr(code)
                    for code in range(32, 127)
                    if re.match(spec["pattern"], "v" + chr(code) + "v")
                }
                self.assertTrue(
                    stricter <= generic,
                    f"{sorted(stricter - generic)} escapes the generic pattern",
                )

    def test_generated_text_parameters_are_not_left_unsanitised(self):
        """The emitted wrappers must not switch the sanitiser off."""
        for path in Path(__file__).parent.parent.parent.glob("tools/ogs/*.xml"):
            with self.subTest(tool=path.name):
                self.assertNotIn('sanitize="false"', path.read_text())

    def test_generated_text_parameters_carry_a_regex_validator(self):
        text_param = re.compile(
            r'<param [^>]*type="text"[^>]*>(.*?)</param>', re.DOTALL
        )
        regex_validator = re.compile(
            r'<validator type="regex" message="[^"]+">([^<]+)</validator>'
        )
        checked = 0
        for path in Path(__file__).parent.parent.parent.glob("tools/ogs/*.xml"):
            for body in text_param.findall(path.read_text()):
                checked += 1
                match = regex_validator.search(body)
                self.assertIsNotNone(
                    match, f"{path.name}: text parameter without a regex validator"
                )
                re.compile(match.group(1))
        self.assertGreater(checked, 0, "no text parameters found to check")

    def test_parameter_attribute_reads_objects_and_xml_nodes(self):
        """_derive_param_constraints_ works on exported ElementTree nodes."""
        node = ET.fromstring('<param argument="--new-order" type="text" />')
        self.assertEqual(gen.param_var_name(node), "new_order")
        self.assertEqual(gen.parameter_attribute(node, "argument"), "--new-order")
        self.assertIsNone(gen.parameter_attribute(node, "missing"))
        # A galaxyxml parameter exposes the same values as Python attributes.
        galaxyxml_param = SimpleNamespace(argument="--input-file", name=None)
        self.assertEqual(gen.param_var_name(galaxyxml_param), "input_file")


class ClosestMatchTest(unittest.TestCase):
    def test_no_hint_for_unrelated_key(self):
        self.assertEqual(gen._closest_match("zzz", {"input_file"}), "")

    def test_hint_for_near_miss(self):
        self.assertIn("input_file", gen._closest_match("input_fil", {"input_file"}))


class RepeatedArgumentTest(unittest.TestCase):
    """How a repeated (``MultiArg``) argument is modelled.

    Galaxy has no list type for numbers (``multiple`` exists for ``select`` and
    ``data`` only), so a repeated *numeric* argument is passed once and its help
    says so; a repeated *file* argument is a collection, because there the list
    really is the input.
    """

    @staticmethod
    def param(args, arg_type, cpp_type="int", var_name="element_ids_arg"):
        return {
            "arg_type": arg_type,
            "all_args": args,
            "cpp_type": cpp_type,
            "tclap_var_name": var_name,
        }

    def test_numeric_multi_arg_is_one_value_with_honest_help(self):
        inputs, _ = gen.process_parameters(
            [
                self.param(
                    '"e","element-ids","element ID",false,"0"',
                    "TCLAP::MultiArg<int>",
                )
            ],
            "sometool",
        )
        self.assertEqual(len(inputs), 1)
        param = inputs[0]
        self.assertIsInstance(param, gen.IntegerParam)
        self.assertIn("may be repeated", param.node.attrib["help"])
        # No collection: a list of numbers cannot be expressed.
        self.assertFalse(getattr(param, "is_data_collection", False))

    def test_a_plain_value_arg_says_nothing_about_repetition(self):
        inputs, _ = gen.process_parameters(
            [self.param('"n","node-id","node ID",false,"0"', "TCLAP::ValueArg<int>")],
            "sometool",
        )
        self.assertNotIn("may be repeated", inputs[0].node.attrib["help"])

    def test_repeated_file_arg_becomes_a_collection(self):
        inputs, _ = gen.process_parameters(
            [
                self.param(
                    '"g","geometries","Input (.gml) filenames",true,""',
                    "TCLAP::MultiArg<std::string>",
                )
            ],
            "sometool",
        )
        self.assertTrue(inputs[0].is_data_collection)
        # Data collections carry the list themselves, so no hint is added.
        self.assertNotIn("may be repeated", inputs[0].node.attrib.get("help", ""))

    def test_text_multi_arg_is_one_text_field(self):
        inputs, _ = gen.process_parameters(
            [
                {
                    "arg_type": "TCLAP::MultiArg<std::string>",
                    "all_args": '"p","property-name","property name",false,""',
                    "cpp_type": "std::string",
                    "tclap_var_name": "property_name_arg",
                }
            ],
            "sometool",
        )
        self.assertIsInstance(inputs[0], gen.TextParam)
        self.assertIn("may be repeated", inputs[0].node.attrib["help"])


class MembersParamTest(unittest.TestCase):
    """The collection elements of a manifest input, OGS fixture or vendored one."""

    def param(self, fmt="vtkxml"):
        return gen.DataParam(name="input_members", format=fmt)

    def test_published_fixture_gets_a_location(self):
        elem = gen.members_param(
            self.param(), "Utils/PVTU2VTU/mesh_0.vtu", "", Path(".")
        )
        element = elem.find("collection").find("element")
        self.assertEqual(element.get("name"), "mesh_0.vtu")
        self.assertEqual(element.get("ftype"), "vtkxml")
        self.assertEqual(
            element.get("location"),
            f"{gen.OGS_TEST_DATA_URL}/Utils/PVTU2VTU/mesh_0.vtu",
        )

    def test_vendored_fixture_has_no_location(self):
        with tempfile.TemporaryDirectory() as tmp:
            (Path(tmp) / "test-data").mkdir()
            (Path(tmp) / "test-data" / "part_0.vtu").write_text("x")
            elem = gen.members_param(
                self.param(), "local:part_0.vtu", "", Path(tmp)
            )
        element = elem.find("collection").find("element")
        self.assertEqual(element.get("value"), "part_0.vtu")
        # Galaxy takes the content from ``--test_data``.
        self.assertIsNone(element.get("location"))

    def test_missing_vendored_fixture_is_reported(self):
        with tempfile.TemporaryDirectory() as tmp:
            (Path(tmp) / "test-data").mkdir()
            self.assertIsNone(
                gen.members_param(self.param(), "local:gone.vtu", "", Path(tmp))
            )


class ExtraTestAuditTest(unittest.TestCase):
    """``EXTRA_TESTS`` and the vendored fixtures are audited like the rest."""

    def audit(self, test_data_dir=None, **tables):
        defaults = {
            "TEST_OVERRIDES": {},
            "PARAM_EXT_OVERRIDES": {},
            "OUTPUT_EXT_OVERRIDES": {},
            "MANIFEST_INPUTS": {},
            "NON_PVD_INPUTS": set(),
            "IMPLICIT_OUTPUTS": {},
            "BASE_FILENAME_OVERRIDES": {},
            "EXCLUDED_TOOLS": [],
            "EXCLUSIVE_MODES": {},
            "TEXT_VALIDATORS": {},
            "EXTRA_TESTS": {},
        }
        defaults.update(tables)
        with patch.multiple(gen, **defaults):
            return gen._audit_curated_tables(
                set(DISCOVERED), PARAMS, FLAGS, VIRTUAL, test_data_dir
            )

    def case(self, **kwargs):
        return {"overrides": {}, "assertions": {}, **kwargs}

    def test_consistent_extra_test_reports_nothing(self):
        problems = self.audit(
            EXTRA_TESTS={
                "sometool": [
                    self.case(
                        overrides={"input_file": ("local", "a.vtu"), "threshold": "1"},
                        assertions={"output_sometool": [("has_text", {"text": "x"})]},
                    )
                ]
            }
        )
        self.assertEqual(problems, [])

    def test_unknown_tool_is_reported(self):
        problems = self.audit(EXTRA_TESTS={"sometol": [self.case()]})
        self.assertIn("no such generated tool", problems[0])

    def test_unknown_override_is_reported_with_suggestion(self):
        problems = self.audit(
            EXTRA_TESTS={"sometool": [self.case(overrides={"treshold": "1"})]}
        )
        self.assertEqual(len(problems), 1)
        self.assertIn("EXTRA_TESTS['sometool'][0]['overrides']['treshold']", problems[0])
        self.assertIn("did you mean 'threshold'?", problems[0])

    def test_unknown_output_name_is_reported(self):
        problems = self.audit(
            EXTRA_TESTS={
                "sometool": [self.case(assertions={"tool_outputs": [("has_size", {})]})]
            }
        )
        self.assertEqual(len(problems), 1)
        self.assertIn("['assertions']['tool_outputs']", problems[0])

    def test_missing_vendored_fixture_is_reported(self):
        with tempfile.TemporaryDirectory() as tmp:
            (Path(tmp) / "test-data").mkdir()
            problems = self.audit(
                test_data_dir=Path(tmp) / "test-data",
                TEST_OVERRIDES={"sometool": {"input_file": ("local", "gone.vtu")}},
            )
        self.assertEqual(len(problems), 1)
        self.assertIn("does not exist", problems[0])
        self.assertIn("gone.vtu", problems[0])

    def test_vendored_fixture_that_exists_is_not_reported(self):
        with tempfile.TemporaryDirectory() as tmp:
            (Path(tmp) / "test-data").mkdir()
            (Path(tmp) / "test-data" / "here.vtu").write_text("x")
            problems = self.audit(
                test_data_dir=Path(tmp) / "test-data",
                TEST_OVERRIDES={"sometool": {"input_file": ("local", "here.vtu")}},
            )
        self.assertEqual(problems, [])


if __name__ == "__main__":
    unittest.main()
