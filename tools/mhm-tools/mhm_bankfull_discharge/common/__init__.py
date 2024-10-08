"""Common routines and constants.

Subpackages
===========

.. autosummary::
   :toctree:

   constants

NetCDF
======

.. autosummary::
   :toctree:

    set_netcdf_encoding

Constants
=========

.. currentmodule:: mhm_tools.common.constants

.. autosummary::

    NO_DATA
    NC_ENCODE_DEFAULTS
"""

from . import constants, netcdf
from .constants import NC_ENCODE_DEFAULTS, NO_DATA
from .netcdf import set_netcdf_encoding

__all__ = ["constants", "netcdf"]
__all__ += ["NO_DATA", "NC_ENCODE_DEFAULTS"]
__all__ += ["set_netcdf_encoding"]
