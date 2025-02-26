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
        default="projects.csv",
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


def get_user_id(connection, metadata, login: str) -> int:
    """
    Retrieve the user_id for a given login.

    :param connection: The database connection.
    :param metadata: The database metadata containing table definitions.
    :param login: The login username to search for.
    :return: The user_id if found, otherwise None.
    """

    # Access the 'ufz_user' table from metadata.
    User = metadata.tables["ufz_user"]

    # Construct a query to select the user_id where the login matches.
    query = db.select(User.c.user_id).where(User.c.login == login)

    # Execute the query and fetch the scalar result.
    result = connection.execute(query).scalar()

    # Return the user_id as an integer if found, otherwise return None.
    return int(result) if result else None


def get_projects_with_sample_count(connection, metadata, user_id):
    """
    Retrieve projects and their sample counts for a given user_id.

    The query will return a pandas DataFrame with the columns:
        project_id : The id of the project.
        name : The name of the project.
        sample_count : The number of samples associated with the project.

    :param connection: The database connection.
    :param metadata: The database metadata containing table definitions.
    :param user_id: The user_id to search for.
    :return: A pandas DataFrame with the projects and their sample counts.
    """

    User = metadata.tables["ufz_user"]
    User_Project = metadata.tables["ufz_user_project"]
    Project = metadata.tables["project"]
    Sample = metadata.tables["sample"]

    # Construct the query:
    # 1. Select project_id, name and the count of sample_id as sample_count.
    # 2. Join the tables ufz_user_project, ufz_user, project and sample.
    #    - Join ufz_user_project with project on project_id.
    #    - Join ufz_user with ufz_user_project on user_id.
    #    - Join sample with project on project_id.
    #      - Use an outer join to include projects without samples.
    # 3. Filter the results to only include the given user_id.
    # 4. Group the results by project_id and name.

    query = (
        db.select(
            Project.c.project_id.label("Project ID"),
            Project.c.name.label("Project Name"),
            db.func.count(Sample.c.sample_id).label("Sample Count")
        )
        .join(User_Project, User_Project.c.project_id == Project.c.project_id)
        .join(User, User.c.user_id == User_Project.c.user_id)
        .join(Sample, Sample.c.project == Project.c.project_id, isouter=True)
        .where(User.c.user_id == user_id)
        .group_by(Project.c.project_id, Project.c.name)
    )

    # Execute the query, fetch the results, and return the DataFrame.
    return pd.DataFrame(connection.execute(query).fetchall())


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
        metadata.reflect(bind=engine, only=["ufz_user", "ufz_user_project", "project", "sample"])

        with engine.connect() as conn:
            # Get user ID
            user_id = get_user_id(conn, metadata, args.login)

            if not user_id:
                print(
                    "No Lambda-Miner user found with the login name \"{}\". "
                    "Please find the description on how to register for the Lambda-Miner at "
                    "https://lambda-miner-project.pages.ufz.de/lambda-miner-workflows/getting-started/."
                    .format(args.login)
                )

                return

            # Get projects with sample counts
            projects = get_projects_with_sample_count(conn, metadata, user_id)

            # Write projects as a CSV file to the specified output
            with open(args.output, "w") as f:
                f.write(projects.to_csv(index=False))

        # Display the result
        if not projects.empty:
            print(projects)
        else:
            print(
                "No projects found for the user \"{}\". "
                "Please create a project before going on."
                .format(args.login)
            )

    except FileNotFoundError:

        print(f"Credentials file not found at \"{args.credentials_file}\".")

    except db.exc.SQLAlchemyError as e:

        print(f"Database error occurred: {e}")

    except Exception as e:

        print(f"An unexpected error occurred: {e}")


if __name__ == "__main__":
    main()
