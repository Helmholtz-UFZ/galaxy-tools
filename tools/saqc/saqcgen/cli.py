"""Command line interface of the SaQC tool generator.

Usage::

    python gen.py --generate-tool > saqc.xml
    python gen.py --generate-tests > test_macros.xml
    python gen.py --write     # update both files in place
    python gen.py --check     # fail if the committed files are out of date
"""

from __future__ import annotations

import argparse
import inspect
import re
import sys
from pathlib import Path
from typing import Dict, List, Optional

from . import testmacros, tool
from .introspect import Introspection, configure_logging, discover_aliases

__all__ = ["main"]

#: the directory that holds the generated files
TOOL_DIRECTORY = Path(__file__).resolve().parent.parent

TOOL_FILE = "saqc.xml"
TEST_FILE = "test_macros.xml"
MACROS_FILE = "macros.xml"

_VERSION = re.compile(r'<token name="@TOOL_VERSION@">\s*([^\s<]+)\s*</token>')


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(
        description="Generate the Galaxy tool XML and its test macros for SaQC."
    )
    parser.add_argument(
        "--generate-tool",
        action="store_true",
        help=f"print the tool XML ({TOOL_FILE})",
    )
    parser.add_argument(
        "--generate-tests",
        action="store_true",
        help=f"print the test macros ({TEST_FILE})",
    )
    parser.add_argument(
        "--write",
        action="store_true",
        help="write both generated files into the tool directory",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="check that the committed files match the generated ones",
    )
    parser.add_argument(
        "--output-dir",
        default=None,
        help=f"the directory to write to (default: {TOOL_DIRECTORY})",
    )
    args = parser.parse_args(argv)

    configure_logging()
    introspection = load_introspection()
    warn_about_version(introspection.package)
    documents = _documents(introspection, args)

    if args.check:
        return _check(documents, _directory(args))
    if args.write:
        _write(documents, _directory(args))
    else:
        for document in documents.values():
            sys.stdout.write(document)
    return 0


def _documents(introspection: Introspection, args: argparse.Namespace) -> Dict[str, str]:
    """The requested documents, keyed by file name, ready to be written."""
    if args.generate_tool:
        documents = {TOOL_FILE: tool.generate_tool(introspection)}
    elif args.generate_tests:
        documents = {TEST_FILE: testmacros.generate_test_macros(introspection)}
    else:
        documents = {
            TOOL_FILE: tool.generate_tool(introspection),
            TEST_FILE: testmacros.generate_test_macros(introspection),
        }
    return {name: _as_file_text(text) for name, text in documents.items()}


def _release(version: str) -> str:
    """The release part of a version, e.g. ``2.7.0`` for ``2.7.0.post3``."""
    match = re.match(r"\d+(?:\.\d+)*", version)
    return match.group(0) if match else version


def _as_file_text(text: str) -> str:
    return text.rstrip("\n") + "\n"


def _directory(args: argparse.Namespace) -> Path:
    return Path(args.output_dir).resolve() if args.output_dir else TOOL_DIRECTORY


def _write(documents: Dict[str, str], directory: Path) -> None:
    for name, document in documents.items():
        path = directory / name
        path.write_text(document, "utf-8")
        print(f"wrote {path}", file=sys.stderr)


def _check(documents: Dict[str, str], directory: Path) -> int:
    """Report files that do not match the generator, e.g. because of a manual edit."""
    outdated = [
        name
        for name, document in documents.items()
        if not (directory / name).exists()
        or (directory / name).read_text("utf-8") != document
    ]
    if not outdated:
        return 0
    for name in outdated:
        print(
            f"ERROR: {directory / name} does not match the generator, "
            "run `python gen.py --write`.",
            file=sys.stderr,
        )
    return 1


def load_introspection() -> Introspection:
    """Import SaQC and collect everything the generator needs from it."""
    import saqc
    from saqc.lib import types as saqc_types

    aliases = discover_aliases(saqc_types)
    for _, module in inspect.getmembers(saqc.funcs, inspect.ismodule):
        aliases.update(discover_aliases(module))
    return Introspection(saqc, aliases)


def warn_about_version(package) -> None:
    """Point out a stale ``@TOOL_VERSION@`` when the installed SaQC differs."""
    macros = TOOL_DIRECTORY / MACROS_FILE
    if not macros.exists():
        return
    match = _VERSION.search(macros.read_text("utf-8"))
    if not match:
        return
    expected = match.group(1)
    installed = getattr(package, "__version__", "")
    if installed and _release(installed) != _release(expected):
        print(
            f"WARNING: the tool is pinned to SaQC {expected}, but SaQC "
            f"{installed} is installed, see {macros.name}.",
            file=sys.stderr,
        )
