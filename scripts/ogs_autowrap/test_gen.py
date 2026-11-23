"""Tests for the generator helpers that do not need an OGS source tree.

Run with::

    python -m unittest discover -s scripts/ogs_autowrap -p 'test_*.py'
"""

import sys
import unittest
from pathlib import Path
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
        self.assertEqual(gen.mapped_datatype("msh", role="output"), "data")

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


class ClosestMatchTest(unittest.TestCase):
    def test_no_hint_for_unrelated_key(self):
        self.assertEqual(gen._closest_match("zzz", {"input_file"}), "")

    def test_hint_for_near_miss(self):
        self.assertIn("input_file", gen._closest_match("input_fil", {"input_file"}))


if __name__ == "__main__":
    unittest.main()
