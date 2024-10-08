"""Post processing routines for mHM.

Bankfull discharge
==================

.. autosummary::
   :toctree:

    bankfull_discharge
"""

from . import bankfull
from .bankfull import bankfull_discharge

__all__ = ["bankfull"]
__all__ += ["bankfull_discharge"]
