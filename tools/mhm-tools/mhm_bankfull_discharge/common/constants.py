"""
Common constants.

Constants
=========

.. autosummary::
    NO_DATA
    NC_ENCODE_DEFAULTS

----

.. autodata:: NO_DATA

.. autodata:: NC_ENCODE_DEFAULTS

"""
__all__ = ["NO_DATA", "NC_ENCODE_DEFAULTS"]

NO_DATA = -9999.0
"""float: Default no data value for mHM."""

NC_ENCODE_DEFAULTS = {"_FillValue": NO_DATA, "missing_value": NO_DATA}
"""dict: Default netcdf encoding settings."""
