import argparse
import os
from json import load, dumps


import pandas as pd
import sqlalchemy as db


def get_arguments() -> argparse.Namespace:
    """
    Parse and return the command-line arguments required for the script.

    return: argparse.Namespace: Parsed arguments containing credentials_file (str) and login (str).
    """

    parser = argparse.ArgumentParser(
        description=(
            "Assign molecular formulas to the peaks of the specified measurements using the "
            "specified Chemical Formula Configuration."
        )
    )

    # Add argument for the credentials file
    parser.add_argument(
        "-c",
        "--credentials-file",
        dest="credentials_file",
        type=str,
        required=False,  # Optional
        help=(
            "Credential file in JSON format including dialect, user, password, host, port, and "
            "database. If not provided, the environment variable LAMBDAMINER_CREDENTIALS will be "
            "used."
        )
    )

    # Add argument for the login name
    parser.add_argument(
        "-l",
        "--login-name",
        dest="login",
        type=str,
        required=True,
        help="UFZ login name of the user"
    )

    # Add argument for the input measurements
    parser.add_argument(
        "-im",
        "--input-measurements",
        dest="measurements",
        type=str,
        required=True,
        help="Path to CSV file of the selected measurements"
    )

    # Add argument for the input CFC
    parser.add_argument(
        "-ic",
        "--input-cfc",
        dest="cfc",
        type=str,
        required=True,
        help="Path to CSV file of the selected CFC"
    )

    # Add argument for the output file
    parser.add_argument(
        "-o",
        "--output-file",
        dest="output",
        type=str,
        default="chemical_formula_assignments.csv",
        help="Specifiy the output file path including the file name (default: 'chemical_formula_assignments.csv')"
    )


    return parser.parse_args()


def parse_check_args(args):
    """
    Parse and validate command line arguments.

    Following actions are performed:
    - Check of the existence of the specified directory in the output path.
    - Assignment the correct credentials file to the arguments.

    :param args: command line arguments.
    :type args: argparse.Namespace
    :raises FileNotFoundError: If the specified directory in the output path does not exist.
    """

    # Extract the directory part of the specified output path
    dir_path = os.path.dirname(args.output) or "."

    # Check if the directory exists and raise error if not
    if not os.path.isdir(dir_path):
        raise FileNotFoundError(f"Error: The directory does not exist: {dir_path}")

    # Get environment variable LAMBDAMINER_CREDENTIALS
    envar_credentials = os.getenv("LAMBDAMINER_CREDENTIALS")

    # Use the provided argument or fallback to the environment variable
    args.credentials_file = args.credentials_file or envar_credentials

    assert args.credentials_file is not None, "Error: No credentials specified"


def get_engine(credentials_path: str, echo: bool = False) -> db.engine.Engine:
    """
    Create and return a SQLAlchemy engine based on the supplied credentials.

    The engine is created using the data from the supplied credentials file,
    which should be in JSON format and include the following keys:
        dialect, user, password, host, port, database

    :param credentials_path: The path to the credentials file.
    :type credentials_path: str
    :return: The SQLAlchemy engine object.
    :rtype: sqlalchemy.engine.Engine
    """

    with open(credentials_path) as file:
        credentials = load(file)

    dialect = credentials["dialect"]
    username = credentials["user"]
    password = credentials["password"]
    host = credentials["host"]
    port = credentials["port"]
    database_name = credentials["database"]

    database_url = f"{dialect}://{username}:{password}@{host}:{port}/{database_name}"

    return db.create_engine(database_url, echo=echo)


def do_assignments(connection, metadata) -> pd.DataFrame:
    """
    get calibrated peaks
    calculate query mass (even or odd)
    filter mass range
    calculate min mass from ppm error
    calculate max mass from ppm error
    get element ranges
    execute assignment function
    count assignments
    track time
    keep measurement ID, peak ID, CFC ID, CF ID, relative error
    """
    
    pass


def get_cfcs(connection, metadata) -> pd.DataFrame:
    """
    Retrieves all chemical formula configurations from the database and performs
    additional transformations to make them suitable for the CFC view.

    :param connection: The database connection object
    :type connection: sqlalchemy.engine.Connection
    :param metadata: The database metadata object
    :type metadata: sqlalchemy.MetaData
    :return: A Pandas DataFrame containing the transformed chemical formula configurations
    :rtype: pandas.DataFrame
    """

    # Retrieve the database tables
    ChemicalFormulaConfig = metadata.tables["chemical_formula_config"]
    ElementCFormulaConfig = metadata.tables["element_cformula_config"]
    Element = metadata.tables["element"]

    # Construct the query to retrieve all chemical formula configurations
    query = (
        db.select(
            ChemicalFormulaConfig.c.chemical_formula_config_id.label("CFC ID"),
            ChemicalFormulaConfig.c.label.label("CFC Name"),
            ChemicalFormulaConfig.c.mass_range_min.label("Mass Range Min"),
            ChemicalFormulaConfig.c.mass_range_max.label("Mass Range Max"),
            ChemicalFormulaConfig.c.fault_tolerance_min.label("Fault Tolerance Min"),
            ChemicalFormulaConfig.c.fault_tolerance_max.label("Fault Tolerance Max"),
            ChemicalFormulaConfig.c.oc_ratio_min.label("OC Ratio Min"),
            ChemicalFormulaConfig.c.oc_ratio_max.label("OC Ratio Max"),
            ChemicalFormulaConfig.c.hc_ratio_min.label("HC Ratio Min"),
            ChemicalFormulaConfig.c.hc_ratio_max.label("HC Ratio Max"),
            ChemicalFormulaConfig.c.nc_ratio_min.label("NC Ratio Min"),
            ChemicalFormulaConfig.c.nc_ratio_max.label("NC Ratio Max"),
            ChemicalFormulaConfig.c.sc_ratio_min.label("SC Ratio Min"),
            ChemicalFormulaConfig.c.sc_ratio_max.label("SC Ratio Max"),
            ChemicalFormulaConfig.c.pc_ratio_min.label("PC Ratio Min"),
            ChemicalFormulaConfig.c.pc_ratio_max.label("PC Ratio Max"),
            ChemicalFormulaConfig.c.dbe_min.label("DBE Min"),
            ChemicalFormulaConfig.c.dbe_max.label("DBE Max"),
            ChemicalFormulaConfig.c.dbe_o_min.label("DBE-O Min"),
            ChemicalFormulaConfig.c.dbe_o_max.label("DBE-O Max"),
            ChemicalFormulaConfig.c.electron_config.label("Electron Configuration"),
            ChemicalFormulaConfig.c.active.label("Active"),
            ChemicalFormulaConfig.c.library.label("Library"),
            Element.c.element_id.label("Element ID"),
            ElementCFormulaConfig.c.min.label("Element Min"),
            ElementCFormulaConfig.c.max.label("Element Max"),
            Element.c.symbol.label("Element Symbol"),
            Element.c.isotope.label("Isotope Number"),
            Element.c.hillorder.label("Hillorder")
        )
        # Join the tables
        .join(ElementCFormulaConfig, ElementCFormulaConfig.c.chemical_formula_config_id == ChemicalFormulaConfig.c.chemical_formula_config_id)
        .join(Element, Element.c.element_id == ElementCFormulaConfig.c.element_id)
        # Order the results
        .order_by(ChemicalFormulaConfig.c.chemical_formula_config_id)
    )

    # Execute the query
    result = connection.execute(query)

    # Transform the result
    transformed_cfcs = transform_cfcs(pd.DataFrame(result.fetchall(), columns=result.keys()))

    return transformed_cfcs


def main():

    # Parse command-line arguments
    args = get_arguments()

    # Parse and check the specified command line arguments
    parse_check_args(args)


    # read and check inputs - is the user allowed to access that data?


    try:

        measurements = get_measurements(args.measurements)
        cfc = get_cfc(args.cfc)

    except FileNotFoundError as fnf_error:
        raise FileNotFoundError(f"Error: {fnf_error}")

    except ValueError as val_error:
        raise ValueError(f"Data Error: {val_error}")

    except Exception as ex:
        raise Exception(f"An unexpected error occurred: {ex}")




    try:
        # Load credentials and create the database engine
        engine = get_engine(args.credentials_file)

        # Reflect metadata and connect to the database
        metadata = db.MetaData()
        metadata.reflect(
            bind=engine,
            only=[
                "chemical_formula_config",
                "element_cformula_config",
                "element"
            ]
        )

        with engine.connect() as conn:

            # Do assignments
            assignments = do_assignments(conn, metadata)

            # Display the result
            if cfcs.empty:
                raise ValueError("No Chemical Formula Configurations found.")

            else:
                print("Chemical Formula Configurations:")
                print(
                    cfcs[[
                        "CFC ID",
                        "CFC Name"
                    ]]
                )
                print("\n")
                print(f"CFCs saved to {args.output}.")

            # Write CFCs as a CSV file to the specified output
            with open(args.output, "w") as f:
                f.write(cfcs.to_csv(index=False))

    except FileNotFoundError:
        raise FileNotFoundError(f"Credentials file not found at \"{args.credentials_file}\".")

    except db.exc.SQLAlchemyError as e:
        raise RuntimeError(f"Database error occurred: {e}")

    except Exception as e:
        raise RuntimeError(f"An unexpected error occurred: {e}")


if __name__ == "__main__":
    main()
