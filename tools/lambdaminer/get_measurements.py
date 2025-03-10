import argparse
from json import load
import os

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
        required=False, # Optional
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
        help="Specifiy the output file path including the file name (default: 'projects.csv')"
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

    # Select the required columns
    samples = samples[
        [
            "Project ID",
            "Project Name",
            "Sample ID",
            "Sample Name"
        ]
    ]

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

def get_measurements(connection, metadata, project_id: int) -> pd.DataFrame:
    """
    """
    
    Sample = metadata.tables["sample"]
    Measurement = metadata.tables["measurement"]
    Peak = metadata.tables["peak"]

    query = ()

    # Execute the query and return the results as a Pandas DataFrame
    return pd.DataFrame(connection.execute(query).fetchall())

"""
SELECT
	"measurement_id" AS "Measurement ID",
	"spectrum_name" AS "Measurement",
	"replicate_of_measurement"

FROM
	#table# AS "table"

WHERE
	"sample" = $Sample ID$

SELECT
	"spectrum_name" AS "Replicate of Measurement"

FROM
	#table# AS "table"

WHERE
	"measurement_id" = $replicate_of_measurement$

SELECT 
	COUNT(*) AS "# Peaks"

FROM
	#table# AS "table"

WHERE
	"measurement" = $Measurement ID$

GROUP BY
	"measurement"

SELECT
	COUNT(*) AS "# CFCs",
	json_agg("chemical_formula_config_id") as "CFCs"

FROM
	#table# AS "table"

WHERE
	"measurement_id" = $Measurement ID$

GROUP BY
	"measurement_id"

SELECT
	COUNT(*) AS "# ECs",
	json_agg("evaluation_config_id") as "ECs"

FROM
	#table# AS "table"

WHERE
	"measurement_id" = $Measurement ID$

GROUP BY
	"measurement_id"

SELECT
	"calibration_method" AS "Calibration Method ID",
	"calibration_error" AS "Calibration Error"

FROM
	#table# AS "table"

WHERE
	"measurement_id" = $Measurement ID$

SELECT
	"calibration_list" AS "Calibration List ID",
	"calibration_type" AS "Calibration Type",
	"electron_config" AS "Calibration Electron Configuration"

FROM
	#table# AS "table"

WHERE
	"calibration_method_id" = $Calibration Method ID$

SELECT
	"name" AS "Calibration List"

FROM
	#table# AS "table"

WHERE
	"feature_id" = $Calibration List ID$

"""


def depr_get_samples(connection, metadata, project_id: int) -> pd.DataFrame:
    """
    Retrieves a Pandas DataFrame containing information about all samples
    associated with the specified project ID.

    The DataFrame contains the following columns:
        Project ID: The ID of the project
        Project Name: The name of the project
        Sample ID: The ID of the sample
        Sample: The name of the sample
        Sample Date: The date the sample was taken
        Sample Type: The type of the sample
        Replicate of Sample ID: The ID of the sample that this sample is a
            replicate of, if applicable
        Replicate of Sample Name: The name of the sample that this sample is a
            replicate of, if applicable
        Measurement Count: The number of measurements associated with the sample

    :param connection: The database connection object
    :type connection: sqlalchemy.engine.Connection
    :param metadata: The database metadata object
    :type metadata: sqlalchemy.MetaData
    :param project_id: The ID of the project to retrieve samples for
    :type project_id: int
    :return: A Pandas DataFrame containing the sample information
    :rtype: pandas.DataFrame
    """

    Project = metadata.tables["project"]
    Sample = metadata.tables["sample"]
    Measurement = metadata.tables["measurement"]

    # Construct the query:
    # 1. Get sample data
    # 2. Get replicate sample name
    # 3. Get measurement count

    # Get the project name
    project_subquery = (
        db.select(Project.c.name.label("Project Name"))
        .where(Project.c.project_id == project_id)
        .correlate(Sample)
        .limit(1)
        .scalar_subquery()
    )

    # Get the replicate sample name, if applicable
    replicate_subquery = (
        db.select(Sample.c.name.label("Replicate of Sample Name"))
        .where(Sample.c.sample_id == Sample.c.replicate_of_sample)
        .correlate(Sample)  # Correlate with the main query
        .limit(1)  # Ensure only one result
        .scalar_subquery()
    )

    # Get the measurement count
    count_subquery = (
        db.select(db.func.count().label("Measurement Count"))
        .where(Measurement.c.sample == Sample.c.sample_id)
        .correlate(Sample)  # Correlate with the main query
        .scalar_subquery()
    )

    # Main query
    query = (
        db.select(
            Sample.c.project.label("Project ID"),
            project_subquery.label("Project Name"),
            Sample.c.sample_id.label("Sample ID"),
            Sample.c.name.label("Sample"),
            Sample.c.sample_date.label("Sample Date"),
            Sample.c.sample_type.label("Sample Type"),
            Sample.c.replicate_of_sample.label("Replicate of Sample ID"),
            replicate_subquery.label("Replicate of Sample Name"),
            count_subquery.label("Measurement Count")
        )
        .where(Sample.c.project == project_id)  # Filter by project ID
        .order_by(Sample.c.sample_id)
    )

    # Execute the query and return the results as a Pandas DataFrame
    return pd.DataFrame(connection.execute(query).fetchall())

def main():


    # Parse command-line arguments
    args = get_arguments()

    parse_check_args(args)

    try:
 
        #project_id, project_name = get_project(args.input)
 
        # Return selected samples as DataFrame
        samples = get_samples(args.input)

        # Print sample ID and name
        print(samples[["Sample ID", "Sample Name"]])

    except FileNotFoundError as fnf_error:
 
        print(f"Error: {fnf_error}")
 
    except ValueError as val_error:
 
        print(f"Data Error: {val_error}")
 
    except Exception as ex:
 
        print(f"An unexpected error occurred: {ex}")


    try:

        # Load credentials and create the database engine
        engine = get_engine(args.credentials_file)

        # Reflect metadata and connect to the database
        metadata = db.MetaData()
        metadata.reflect(bind=engine, only=["sample", "measurement", "peak", "measurement_cformula_config", "measurement_evaluation_config", "calibration_method", "feature"])

        with engine.connect() as conn:

            measurements = get_measurements(conn, metadata, samples)

            # Write measurements as a CSV file to the specified output
            with open(args.output, "w") as f:
                f.write(measurements.to_csv(index=False))

        # Display the result
        if not measurements.empty:
            print(measurements, "\n")
            print(f"Measurements saved to '{args.output}'.")
        else:
            print(
                "No measurements found for the selected samples."
                "Please upload samples and measurements before going on."
            )

    except FileNotFoundError:

        print(f"Credentials file not found at \"{args.credentials_file}\".")

    except db.exc.SQLAlchemyError as e:

        print(f"Database error occurred: {e}")

    except Exception as e:

        print(f"An unexpected error occurred: {e}")

if __name__ == "__main__":
    main()
