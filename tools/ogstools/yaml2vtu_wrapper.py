#!/usr/bin/env python3
"""Run ogstools' yaml2vtu command line interface.

The console script shipped with ogstools 0.8.x still imports the command from
``ogstools.meshlib``, the package that was renamed to ``ogstools.meshes`` in
0.8.0, so the installed ``yaml2vtu`` entry point fails with
``ModuleNotFoundError``. Import the command from whichever module the installed
release provides and let click handle the command line arguments, so the wrapper
works with every release that ships this command.
"""

try:  # ogstools <= 0.7.1
    from ogstools.meshlib.meshes_from_yaml_cli import cli
except ImportError:  # ogstools >= 0.8.0
    from ogstools.meshes.meshes_from_yaml_cli import cli

if __name__ == "__main__":
    cli()
