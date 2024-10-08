"""
Calculate the river discharge at bankfull conditions and the bankfull width.

Authors
-------
- Lennart Schüler
- Sebastian Müller
"""

import numpy as np
import xarray as xr

from ..common import NC_ENCODE_DEFAULTS, set_netcdf_encoding


def find_nearest_idx(array, value):
    """Find nearest index.

    Parameters
    ----------
    array : numpy.ndarray
        input array
    value : float
        desired value

    Returns
    -------
    int
        nearest index
    """
    return (np.abs(array - value)).argmin()


def calc_q_bkfl(q_yearly_peak, return_period):
    """Calculate the discharge at bankfull conditions.

    Parameters
    ----------
    q_yearly_peak : numpy.ndarray
        yearly peak discharge from monthly means (3d ndarray)
    return_period : float
        The return period of the flood in years

    Returns
    -------
    numpy.ma.MaskedArray
    """
    q_bkfl = np.ma.empty(q_yearly_peak.shape[1:], q_yearly_peak.dtype)
    q_bkfl[...] = np.nan
    # all finite values mask
    q_mask = np.all(np.isfinite(q_yearly_peak), axis=0)
    # reverse sorted q time-series at each location for all empirical CDF
    q_sort = np.flip(np.sort(q_yearly_peak[:, q_mask], axis=0), axis=0)
    # all time-series have the same timestep: calculate recurrence intervals (n+1)/m
    ex_prob = np.linspace(0, 1, q_yearly_peak.shape[0] + 1, endpoint=False)[1:] ** -1
    # X-year flood is defined as a flood which has a 1/X chance to occur during a year
    idx_bkfl = find_nearest_idx(ex_prob, return_period)
    # TODO: use log-Pearson Type 3 analysis instead of closest flood event
    q_bkfl[q_mask] = q_sort[idx_bkfl]
    return q_bkfl


def bankfull_discharge(
    in_file, out_file, return_period=1.5, wetted_perimeter=False, var="Qrouted"
):
    """Calculate bankfull discharge and perimeter.

    Bankfull discharge is determined as the yearly peak flow
    with a recurrence interval given by ``return_period``, which is 1.5 years by default.
    The wetted perimeter is estimated from bankfull discharge with Lacey's formula.
    Ouput variables in the created NetCDF file are called "Q_bkfl" and "P_bkfl".
    See [1]_, [2]_ and [3]_ for more information.

    .. note::
       This will simply use the closest flood event in terms of its recurrence interval.
       Also, any input time-stepping is accepted but daily or sub-daily data is preferred.

    Parameters
    ----------
    in_file : :class:`~os.PathLike`
        The path of the mRM NetCDF file with the discharge data
    out_file : :class:`~os.PathLike`
        The path of the output NetCDF file
    return_period : :class:`float`, optional
        The return period of the flood in years, by default 1.5
    wetted_perimeter : :class:`bool`, optional
        Whether to also estimate the wetted perimeter, by default False
    var : :class:`str`, optional
        Variable name for routed streamflow in the input NetCDF file,
        by default "Qrouted"

    References
    ----------
    .. [1] Sutanudjaja, E. H., van Beek, L. P. H., de Jong, S. M., van Geer, F. C., and Bierkens, M. F. P.:
       Large-scale groundwater modeling using global datasets: a test case for the Rhine-Meuse basin,
       Hydrol. Earth Syst. Sci., 15, 2913-2935, https://doi.org/10.5194/hess-15-2913-2011, 2011.
    .. [2] Savenije, H. H. G.: The width of a bankfull channel; Lacey's formula explained,
       J. Hydrol., 276, 176-183, https://doi.org/10.1016/S0022-1694(03)00069-6, 2003.
    .. [3] Edwards, P.J., Watson, E.A. and Wood, F.:
       Toward a Better Understanding of Recurrence Intervals, Bankfull, and Their Importance.
       J. Contemp. Water Res. Educ., 166, 35-45, https://doi.org/10.1111/j.1936-704X.2019.03300.x, 2019.
    """
    ds = xr.open_dataset(in_file)
    var_encode = {
        key: ds[var].encoding.get(key, val) for key, val in NC_ENCODE_DEFAULTS.items()
    }
    # bankfull discharge from yearly peak flow
    q_yearly_peak = ds[var].resample(time="AS").max()
    q_bkfl_data = calc_q_bkfl(q_yearly_peak.data, return_period=return_period)
    q_bkfl = q_yearly_peak.isel(time=0, drop=True).copy(data=q_bkfl_data)
    q_bkfl.attrs["long_name"] = "Discharge at bankfull conditions"
    # drop time (and all time dependent variables)
    ds = ds.drop_dims("time")
    ds.encoding.pop("unlimited_dims", None)
    # add new variable
    ds["Q_bkfl"] = q_bkfl
    # perimeter
    if wetted_perimeter:
        # "4.8" from Savenije, H. H. G.:
        # The width of a bankfull channel; Lacey's formula explained
        p_bkfl_data = np.copy(q_bkfl_data)
        p_bkfl_data[q_bkfl_data > 0] = 4.8 * np.sqrt(q_bkfl_data[q_bkfl_data > 0])
        p_bkfl = q_bkfl.copy(data=p_bkfl_data)
        p_bkfl.attrs["long_name"] = "Perimeter at bankfull conditions"
        p_bkfl.attrs["units"] = "m"
        ds["P_bkfl"] = p_bkfl

    # no FillValue for dim-coords and bounds
    set_netcdf_encoding(ds=ds, var_encoding=var_encode)

    # save
    ds.to_netcdf(out_file)
