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
        description="Read the projects of the current user from the Lambda-Miner Database"
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

    # Add argument for the output file
    parser.add_argument(
        "-o",
        "--output-file",
        dest="output",
        type=str,
        default="chemical_formula_configurations.csv",
        help="Specifiy the output file path including the file name (default: 'chemical_formula_configurations.csv')"
    )

    # Add argument for the type
    parser.add_argument(
        "-t",
        "--type",
        choices=["generic", "import", "calibration", "assignment", "validation", "export"],
        default="generic",
        help="Specify the workflow type (default: 'generic')"
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


# Function to format range columns
def format_range(min_val, max_val):
    """
    Format a range from two values.

    If both values are given, a string in the form "min - max" is returned.
    If any of the values are NaN, None is returned.

    :param min_val: The minimum of the range.
    :param max_val: The maximum of the range.
    :return: A string with the range or None.
    :rtype: str or None
    """

    return f"{min_val} - {max_val}" if pd.notna(min_val) and pd.notna(max_val) else None


def transform_cfcs(cfcs: pd.DataFrame) -> pd.DataFrame:
    """
    Transforms a DataFrame containing chemical formula configurations (CFCs) by
    formatting and aggregating relevant columns for CFC view.

    :param cfcs: A DataFrame containing chemical formula configurations.
    :type cfcs: pd.DataFrame
    :return: A transformed DataFrame suitable for CFC view.
    :rtype: pd.DataFrame
    """

    # Select and deduplicate relevant columns for non-element data
    cfcs_no_elements = cfcs[[
        "CFC ID",
        "CFC Name",
        "Mass Range Min",
        "Mass Range Max",
        "Fault Tolerance Min",
        "Fault Tolerance Max",
        "OC Ratio Min",
        "OC Ratio Max",
        "HC Ratio Min",
        "HC Ratio Max",
        "NC Ratio Min",
        "NC Ratio Max",
        "SC Ratio Min",
        "SC Ratio Max",
        "PC Ratio Min",
        "PC Ratio Max",
        "DBE Min",
        "DBE Max",
        "DBE-O Min",
        "DBE-O Max",
        "Electron Configuration",
        "Active",
        "Library"
    ]].drop_duplicates().reset_index(drop=True)

    # Convert mass range values to integer
    cfcs_no_elements["Mass Range Min"] = cfcs_no_elements["Mass Range Min"].astype(int)
    cfcs_no_elements["Mass Range Max"] = cfcs_no_elements["Mass Range Max"].astype(int)

    # Format range columns
    cfcs_no_elements["Mass range"] = cfcs_no_elements.apply(
        lambda row: format_range(row["Mass Range Min"], row["Mass Range Max"]), axis=1
    )
    cfcs_no_elements["Fault tolerance"] = cfcs_no_elements.apply(
        lambda row: format_range(row["Fault Tolerance Min"], row["Fault Tolerance Max"]), axis=1
    )
    cfcs_no_elements["OC Ratio"] = cfcs_no_elements.apply(
        lambda row: format_range(row["OC Ratio Min"], row["OC Ratio Max"]), axis=1
    )
    cfcs_no_elements["HC Ratio"] = cfcs_no_elements.apply(
        lambda row: format_range(row["HC Ratio Min"], row["HC Ratio Max"]), axis=1
    )
    cfcs_no_elements["NC Ratio"] = cfcs_no_elements.apply(
        lambda row: format_range(row["NC Ratio Min"], row["NC Ratio Max"]), axis=1
    )
    cfcs_no_elements["SC Ratio"] = cfcs_no_elements.apply(
        lambda row: format_range(row["SC Ratio Min"], row["SC Ratio Max"]), axis=1
    )
    cfcs_no_elements["PC Ratio"] = cfcs_no_elements.apply(
        lambda row: format_range(row["PC Ratio Min"], row["PC Ratio Max"]), axis=1
    )
    cfcs_no_elements["DBE"] = cfcs_no_elements.apply(
        lambda row: format_range(row["DBE Min"], row["DBE Max"]), axis=1
    )
    cfcs_no_elements["DBE-O"] = cfcs_no_elements.apply(
        lambda row: format_range(row["DBE-O Min"], row["DBE-O Max"]), axis=1
    )

    # Drop the min-max columns as they are now represented in combined format
    cfcs_no_elements = cfcs_no_elements.drop(
        [
            "Mass Range Min",
            "Mass Range Max",
            "Fault Tolerance Min",
            "Fault Tolerance Max",
            "OC Ratio Min",
            "OC Ratio Max",
            "HC Ratio Min",
            "HC Ratio Max",
            "NC Ratio Min",
            "NC Ratio Max",
            "SC Ratio Min",
            "SC Ratio Max",
            "PC Ratio Min",
            "PC Ratio Max",
            "DBE Min",
            "DBE Max",
            "DBE-O Min",
            "DBE-O Max"
        ],
        axis=1
    )

    # TODO: Implement element range column for CFC view

    return cfcs_no_elements  # Later: Return transformed dataframe including element ranges


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

            # Get CFCs
            cfcs = get_cfcs(conn, metadata)

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
