"""
Calculate the river discharge at bankfull conditions and the bankfull width.

Bankfull discharge is determined as the yearly peak flow
with a recurrence interval given by "return_period", which is 1.5 years by default.
The wetted perimeter is estimated from bankfull discharge with Lacey's formula.

This routine will simply use the closest flood event in terms of its recurrence interval.
Also, any input time-stepping is accepted but daily or sub-daily data is preferred.
Ouput variables in the created NetCDF file are called "Q_bkfl" and "P_bkfl".
"""
from ..post.bankfull import bankfull_discharge


def add_args(parser):
    """Add cli arguments for the bankfull subcommand.

    Parameters
    ----------
    parser : argparse.ArgumentParser
        the main argument parser
    """
    parser.add_argument(
        "-r",
        "--return_period",
        type=float,
        default=1.5,
        help="The return period of the flood in years.",
    )
    parser.add_argument(
        "-w",
        "--wetted_perimeter",
        action="store_true",
        default=False,
        help="Additionally estimate the wetted perimeter.",
    )
    parser.add_argument(
        "-v",
        "--var",
        default="Qrouted",
        help="Variable name for routed streamflow in the NetCDF file",
    )
    required_args = parser.add_argument_group("required arguments")
    required_args.add_argument(
        "-i",
        "--input",
        dest="in_file",
        required=True,
        help="The path of the mRM NetCDF file with the discharge data.",
    )
    required_args.add_argument(
        "-o",
        "--output",
        dest="out_file",
        required=True,
        help="The path of the output NetCDF file.",
    )


def run(args):
    """Calculate the bankfull discharge.

    Parameters
    ----------
    args : argparse.Namespace
        parsed command line arguments
    """
    bankfull_discharge(
        in_file=args.in_file,
        out_file=args.out_file,
        return_period=args.return_period,
        wetted_perimeter=args.wetted_perimeter,
        var=args.var,
    )
