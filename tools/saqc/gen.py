#!/usr/bin/env python
"""Generate the Galaxy tool XML and the tests for SaQC.

This is the entry point of the :mod:`saqcgen` package::

    python gen.py --generate-tool  > saqc.xml
    python gen.py --generate-tests > test_macros.xml
    python gen.py --write
"""

import sys

from saqcgen.cli import main

if __name__ == "__main__":
    sys.exit(main())
