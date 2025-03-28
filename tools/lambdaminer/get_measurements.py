import argparse
import os
from json import load

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
        default="samples.csv",
        help="Specifiy the output file path including the file name (default: 'samples.csv')"
    )

    # Add argument for the type
    parser.add_argument(
        "-t",
        "--type",
        choices=["generic", "import", "calibration", "assignment", "validation", "export"],
        default="generic",
        help="Specify the workflow type (default: 'generic')"
    )

    # Add argument for the input file - selected project
    parser.add_argument(
        "-i",
        "--input-file",
        dest="input",
        type=str,
        required=True,
        help="Path to CSV file of the selected project"
    )

    # Add argument for allowing multiple projects
    parser.add_argument(
        "-m",
        "--multiple-projects",
        dest="multiple",
        action="store_true",
        help="Allow multiple projects as input"
    )

    return parser.parse_args()


def parse_check_args(args):
    """
    Parse and validate command line arguments.

    Following actions are performed:
    - Check of the existence of the specified input file.
    - Check of the existence of the specified directory in the output path.
    - Assignment the correct credentials file to the arguments.

    :param args: command line arguments.
    :type args: argparse.Namespace
    :raises FileNotFoundError: If the specified directory in the output path does not exist.
    """

    # Check if the input file exists
    if not os.path.exists(args.input):
        raise FileNotFoundError(f"The file '{args.input}' does not exist.")

    # Extract the directory part of the specified output path
    dir_path = os.path.dirname(args.output) or "."

    # Check if the output directory exists
    if not os.path.isdir(dir_path):
        raise FileNotFoundError(f"Error: The directory does not exist: {dir_path}")

    # Get environment variable LAMBDAMINER_CREDENTIALS
    envar_credentials = os.getenv("LAMBDAMINER_CREDENTIALS")

    # Use the provided argument or fallback to the environment variable
    args.credentials_file = args.credentials_file or envar_credentials


def get_samples(input_file: str) -> pd.DataFrame:
    """
    Reads a CSV file containing information about the selected samples
    and returns a Pandas DataFrame.

    The DataFrame should contain the following columns:
        Project ID: The ID of the project
        Project Name: The name of the project
        Sample ID: The ID of the sample
        Sample Name: The name of the sample

    :param input_file: The path to the CSV file containing the sample information
    :return: A Pandas DataFrame containing the sample information
    """

    # Check if file exists
    if not os.path.exists(input_file):
        raise FileNotFoundError(f"The file '{input_file}' does not exist.")

    try:
        # Read the CSV file
        samples = pd.read_csv(input_file)

    except pd.errors.EmptyDataError:
        raise ValueError("The input file is empty.")

    except Exception as e:
        raise ValueError(f"An error occurred while reading the file: {e}")

    # Check for the existence of the 'Project ID' column
    if "Sample ID" not in samples.columns:
        raise ValueError("The input file does not contain a column named 'Sample ID'.")

    # Check for the existence of the 'Sample Name' column
    if "Sample Name" not in samples.columns:
        raise ValueError("The input file does not contain a column named 'Sample Name'.")

    return samples


def get_engine(credentials_path: str, echo: bool = False) -> db.engine.Engine:
    """
    Create and return a SQLAlchemy engine based on the supplied credentials.

    The engine is created using the data from the supplied credentials file,
    which should be in JSON format and include the following keys:
        dialect, user, password, host, port, database

    :param credentials_path: The path to the credentials file.
    :type credentials_path: str
    :param echo: If True, the engine will log all statements. Defaults to False.
    :type echo: bool
    :return: The SQLAlchemy engine object.
    :rtype: sqlalchemy.engine.Engine
    """

    # Open the credentials file and load the JSON data
    with open(credentials_path) as file:
        credentials = load(file)

    # Extract the necessary components from the credentials
    dialect = credentials["dialect"]
    username = credentials["user"]
    password = credentials["password"]
    host = credentials["host"]
    port = credentials["port"]
    database_name = credentials["database"]

    # Construct the database URL
    database_url = f"{dialect}://{username}:{password}@{host}:{port}/{database_name}"

    # Create and return the SQLAlchemy engine
    return db.create_engine(database_url, echo=echo)


def get_measurements(connection, metadata, samples: pd.DataFrame) -> pd.DataFrame:
    """
    Retrieves a Pandas DataFrame containing information about all measurements
    associated with the specified sample IDs.

    :param connection: The database connection object
    :type connection: sqlalchemy.engine.Connection
    :param metadata: The database metadata object
    :type metadata: sqlalchemy.MetaData
    :param samples: A DataFrame containing sample IDs
    :type samples: pandas.DataFrame
    :return: A Pandas DataFrame containing the measurement information for all samples
    :rtype: pandas.DataFrame
    """

    if "Sample ID" not in samples.columns:
        raise ValueError("The provided DataFrame must contain a 'Sample ID' column.")

    sample_ids = samples["Sample ID"].dropna().astype(int).tolist()

    if not sample_ids:
        raise ValueError("No valid sample IDs found in the DataFrame.")

    # Table references
    Measurement = metadata.tables["measurement"]
    Peak = metadata.tables["peak"]
    MeasurementCFC = metadata.tables["measurement_cformula_config"]
    MeasurementEC = metadata.tables["measurement_evaluation_config"]
    CalibrationMethod = metadata.tables["calibration_method"]
    Feature = metadata.tables["feature"]

    # Aliases for self-joins
    ReplicateMeasurement = Measurement.alias("replicate")

    # Query
    query = (
        db.select(
            Measurement.c.measurement_id.label("Measurement ID"),
            Measurement.c.spectrum_name.label("Measurement Name"),
            Measurement.c.replicate_of_measurement.label("Replicate of Measurement ID"),
            db.func.coalesce(ReplicateMeasurement.c.spectrum_name, db.null()).label("Replicate of Measurement"),
            db.func.count(Peak.c.peak_id).label("# Peaks"),  # Count of peaks remains the same
            db.func.count(db.func.distinct(MeasurementCFC.c.chemical_formula_config_id)).label("# CFCs"),
            db.func.json_agg(db.func.distinct(MeasurementCFC.c.chemical_formula_config_id)).label("CFCs"),
            db.func.count(db.func.distinct(MeasurementEC.c.evaluation_config_id)).label("# ECs"),
            db.func.json_agg(db.func.distinct(MeasurementEC.c.evaluation_config_id)).label("ECs"),
            Measurement.c.calibration_method.label("Calibration Method ID"),
            Measurement.c.calibration_error.label("Calibration Error"),
            CalibrationMethod.c.calibration_list.label("Calibration List ID"),
            CalibrationMethod.c.calibration_type.label("Calibration Type"),
            CalibrationMethod.c.electron_config.label("Calibration Electron Configuration"),
            Feature.c.name.label("Calibration List")
        )
        .outerjoin(ReplicateMeasurement, ReplicateMeasurement.c.measurement_id == Measurement.c.replicate_of_measurement)
        .outerjoin(MeasurementCFC, MeasurementCFC.c.measurement_id == Measurement.c.measurement_id)
        .outerjoin(MeasurementEC, MeasurementEC.c.measurement_id == Measurement.c.measurement_id)
        .outerjoin(CalibrationMethod, CalibrationMethod.c.calibration_method_id == Measurement.c.calibration_method)
        .outerjoin(Feature, Feature.c.feature_id == CalibrationMethod.c.calibration_list)
        .outerjoin(Peak, Peak.c.measurement == Measurement.c.measurement_id)
        .where(Measurement.c.sample.in_(sample_ids))
        .group_by(
            Measurement.c.measurement_id, Measurement.c.spectrum_name,
            ReplicateMeasurement.c.spectrum_name, Measurement.c.calibration_method,
            Measurement.c.calibration_error, CalibrationMethod.c.calibration_list,
            CalibrationMethod.c.calibration_type, CalibrationMethod.c.electron_config,
            Feature.c.name
        )
        .order_by(Measurement.c.measurement_id)
    )

    result = connection.execute(query)

    return pd.DataFrame(result.fetchall(), columns=result.keys())


def main():

    print("\n")

    # Parse command-line arguments
    args = get_arguments()

    # Parse and check the specified command line arguments
    parse_check_args(args)

    try:
 
        # Return selected samples as DataFrame
        samples = get_samples(args.input)

        if samples.empty:
            raise ValueError(
                "The specified input file is empty or did not contain valid sample data."
            )
        else:
            print("Selected sample(s):")
            print(samples[["Sample ID", "Sample Name"]])
            print("\n")

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
                "sample",
                "measurement",
                "peak",
                "measurement_cformula_config",
                "measurement_evaluation_config",
                "calibration_method",
                "feature"
            ]
        )

        with engine.connect() as conn:
            measurements = get_measurements(conn, metadata, samples)

        # Display the result
        if measurements.empty:
            raise ValueError(
                "No measurements found for the selected sample(s)."
                "Please upload samples and measurements before going on."
            )
        else:
            print("\n")
            print("Found measurement(s):")
            print(
                measurements[[
                    "Measurement ID",
                    "Measurement Name",
                    "Replicate of Measurement",
                    "# Peaks",
                    "Calibration Error",
                    "Calibration List",
                    "# CFCs",
                    "CFCs",
                    "# ECs",
                    "ECs"
                ]]
            )
            print("\n")
            print(f"Measurements saved to {args.output}.", "\n")

        # Write measurements as a CSV file to the specified output
        with open(args.output, "w") as f:
            f.write(measurements.to_csv(index=False))

    except FileNotFoundError:
        raise FileNotFoundError(f"Credentials file not found at \"{args.credentials_file}\".")

    except db.exc.SQLAlchemyError as e:
        raise RuntimeError(f"Database error occurred: {e}")

    except Exception as e:
        raise RuntimeError(f"An unexpected error occurred: {e}")


if __name__ == "__main__":
    main()
