"""Generator for the Galaxy wrappers of `SaQC <https://rdm-software.pages.ufz.de/saqc/>`_.

SaQC documents every quality control method with a typed signature and a
reStructuredText docstring.  This package turns that documentation into

* ``saqc.xml`` -- the tool wrapper with one input form per method, and
* ``test_macros.xml`` -- a planemo test per method.

Run it with ``python -m saqcgen --help`` from the tool directory,
see ``README.md`` next to it for the version pinning and the verification steps.
"""

__all__ = [
    "cli",
    "docs",
    "introspect",
    "params",
    "samples",
    "testmacros",
    "tool",
    "typespec",
]
