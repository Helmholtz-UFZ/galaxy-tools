"""Command line interface for mhm-tools."""
import argparse

from .. import __version__
from . import _bankfull


class Formatter(
    argparse.ArgumentDefaultsHelpFormatter, argparse.RawDescriptionHelpFormatter
):
    """Custom formatter for argparse with help and raw text."""


def add_command_from_module(subparsers, name, module):
    """
    Add a subcommand from a given module.

    Parameters
    ----------
    subparsers : subparsers
        Subparser to add the command to.
    name : str
        Name of the command to add.
    module : module
        Module containing the `add_args` and `run` functions defining the command.
    """
    desc = module.__doc__
    kwargs = {"description": desc}
    if desc:
        kwargs["help"] = desc.splitlines()[0]
    parser = subparsers.add_parser(name, formatter_class=Formatter, **kwargs)
    module.add_args(parser)
    parser.set_defaults(func=module.run)


def _get_parser():
    parent_parser = argparse.ArgumentParser(
        prog="mhm-tools",
        description=__doc__,
        formatter_class=Formatter,
    )

    parent_parser.add_argument(
        "-V",
        "--version",
        action="version",
        version=__version__,
        help="Display version information.",
    )

    sub_help = (
        "All tools are provided as sub-commands. "
        "Please refer to the respective help texts."
    )
    subparsers = parent_parser.add_subparsers(
        title="Available Tools", dest="command", required=True, description=sub_help
    )

    # all sub-parsers should be added here
    # documentation taken from docstring of respective cli module (first line summary)
    # module needs two functions: add_args and run

    add_command_from_module(subparsers, "bankfull", _bankfull)

    # return the parser
    return parent_parser


def main(argv=None):
    """
    Execute main CLI routine.

    Parameters
    ----------
    argv : list of str
        command line arguments, default is None

    Returns
    -------
        result of the called sub-argument routine
    """
    args = _get_parser().parse_args(argv)
    return args.func(args)
