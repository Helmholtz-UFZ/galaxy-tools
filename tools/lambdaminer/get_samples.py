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


def get_projects(input_file: str, allow_multiple: bool) -> int:
    """
    Extract the project ID from the input CSV file.

    The input file is expected to contain a single row with a column named 'Project ID'.

    :param input_file: The path to the input CSV file.
    :type input_file: str
    :return: The project ID extracted from the file.
    :rtype: int
    :raises FileNotFoundError: If the input file does not exist.
    :raises ValueError: If the file is empty, contains more than one row, lacks a 'Project ID'
        column, or contains an invalid Project ID.
    """

    try:
        # Read the CSV file
        df_projects = pd.read_csv(input_file)
    except pd.errors.EmptyDataError:
        raise ValueError("The input file is empty.")
    except Exception as e:
        raise ValueError(f"An error occurred while reading the file: {e}")

    # Ensure the DataFrame contains exactly one row
    if not allow_multiple:
        assert len(df_projects) == 1, "The input file must contain exactly one row."

    # Check for the existence of the 'Project ID' column
    if "Project ID" not in df_projects.columns:
        raise ValueError("The input file does not contain a column named 'Project ID'.")

    return df_projects


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

def get_samples(connection, metadata, projects: pd.DataFrame) -> pd.DataFrame:
    """
    Retrieves a Pandas DataFrame containing information about all samples
    associated with the specified project IDs.

    :param connection: The database connection object
    :type connection: sqlalchemy.engine.Connection
    :param metadata: The database metadata object
    :type metadata: sqlalchemy.MetaData
    :param projects: A DataFrame containing project IDs
    :type projects: pandas.DataFrame
    :return: A Pandas DataFrame containing the sample information for all projects
    :rtype: pandas.DataFrame
    """

    if "Project ID" not in projects.columns:
        raise ValueError("The provided DataFrame must contain a 'Project ID' column.")

    project_ids = projects["Project ID"].dropna().astype(int).tolist()
    if not project_ids:
        raise ValueError("No valid project IDs found in the DataFrame.")

    Project = metadata.tables["project"]
    Sample = metadata.tables["sample"]
    Measurement = metadata.tables["measurement"]

    # Define alias for self-join on replicate samples
    ReplicateSample = Sample.alias("replicate")

    # Query
    query = (
        db.select(
            Sample.c.project.label("Project ID"),
            Project.c.name.label("Project Name"),
            Sample.c.sample_id.label("Sample ID"),
            Sample.c.name.label("Sample Name"),
            Sample.c.sample_date.label("Sample Date"),
            Sample.c.sample_type.label("Sample Type"),
            Sample.c.replicate_of_sample.label("Replicate of Sample ID"),
            db.func.coalesce(ReplicateSample.c.name, db.null()).label("Replicate of Sample Name"),
            db.func.count(Measurement.c.sample).label("Measurement Count")
        )
        .join(Project, Project.c.project_id == Sample.c.project)  # Join project to get project name
        # Self-join for replicate sample names
        .outerjoin(ReplicateSample, ReplicateSample.c.sample_id == Sample.c.replicate_of_sample)
        .outerjoin(Measurement, Measurement.c.sample == Sample.c.sample_id)  # Count measurements
        .where(Sample.c.project.in_(project_ids))  # Filter by multiple projects
        # Ensure correct aggregation
        .group_by(Sample.c.sample_id, Project.c.name, ReplicateSample.c.name)
        .order_by(Sample.c.sample_id)
    )

    # Execute the query and return the results as a Pandas DataFrame
    result = connection.execute(query)

    return pd.DataFrame(result.fetchall(), columns=result.keys())


def main():

    # Parse command-line arguments
    args = get_arguments()

    # Parse and check the specified command line arguments
    parse_check_args(args)

    try:
 
        # Read the project data from the input file
        projects = get_projects(args.input, args.multiple) # Multiple allowed
 
        print("\n")
        if args.multiple: print("Selected projects:")
        else: print("Selected project:")
        print(projects, "\n")

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
        metadata.reflect(bind=engine, only=["project", "sample", "measurement"])

        with engine.connect() as conn:
            # Get user ID
            samples = get_samples(conn, metadata, projects)

            # Write projects as a CSV file to the specified output
            with open(args.output, "w") as f:
                f.write(samples.to_csv(index=False))

        # Display the result
        if samples.empty:
            raise ValueError(
                "No samples found for the specified project(s)."
                "Please upload samples and measurements before going on."
            )
        else:
            print("Found sample(s):")
            print(samples, "\n")
            print(f"Samples saved to '{args.output}'.", "\n")

    except FileNotFoundError:
        raise FileNotFoundError(f"Credentials file not found at \"{args.credentials_file}\".")

    except db.exc.SQLAlchemyError as e:
        raise RuntimeError(f"Database error occurred: {e}")

    except Exception as e:
        raise RuntimeError(f"An unexpected error occurred: {e}")

if __name__ == "__main__":
    main()
