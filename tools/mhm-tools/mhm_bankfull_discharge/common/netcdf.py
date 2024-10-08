"""Common NetCDF routines."""
from .constants import NC_ENCODE_DEFAULTS


def set_netcdf_encoding(ds, var_encoding=None):
    """
    Set default netcdf encoding settings to a xarray data-set.

    Parameters
    ----------
    ds : :class:`xarray.Dataset`
        xarray dataset to set the encoding.
    var_encoding : :class:`dict`, optional
        Encoding for variables within the given dataset,
        by default :any:`NC_ENCODE_DEFAULTS`
    """
    var_encoding = var_encoding or NC_ENCODE_DEFAULTS
    # no FillValue for dim-coords and bounds
    dims = set(ds.dims)
    all_coords = set(ds.coords)
    dim_coords = all_coords & dims  # intersection
    aux_coords = all_coords - dims  # difference
    bnds = {ds[c].attrs["bounds"] for c in all_coords if "bounds" in ds[c].attrs}
    vars = set(ds.data_vars) - bnds

    for v in aux_coords | vars:  # union
        ds[v].encoding = var_encoding

    for v in dim_coords | bnds:  # union
        ds[v].encoding = {"_FillValue": None}
