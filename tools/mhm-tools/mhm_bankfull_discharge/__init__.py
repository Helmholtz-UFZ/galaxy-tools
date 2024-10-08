"""
Tools to pre- and post-process data for and from mHM.

.. toctree::
   :hidden:

   self

Subpackages
===========

Built-in processing and tool functions.

.. autosummary::
   :toctree: api
   :caption: Subpackages

   common
   post
"""

try:
    from ._version import __version__
except ModuleNotFoundError:  # pragma: no cover
    # package is not installed
    __version__ = "0.0.0.dev0"

from . import common, post

__all__ = ["__version__"]
__all__ += ["common", "post"]
