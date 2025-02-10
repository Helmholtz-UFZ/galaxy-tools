import unittest
from unittest.mock import MagicMock, Mock, patch
import pandas as pd
import sqlalchemy as db
import argparse
from get_projects import get_arguments, get_engine, get_user_id, get_projects_with_sample_count, main

class TestScriptFunctions(unittest.TestCase):

    @patch("argparse.ArgumentParser.parse_args")
    def test_get_arguments(self, mock_parse_args):

        # Mock the command-line arguments
        mock_parse_args.return_value = argparse.Namespace(
            credentials_file="path/to/credentials.json",
            login="test_user"
        )
        args = get_arguments()

        self.assertEqual(args.credentials_file, "path/to/credentials.json")
        self.assertEqual(args.login, "test_user")

    @patch("get_projects.load")
    @patch("builtins.open")
    @patch("sqlalchemy.create_engine")
    def test_get_engine(self, mock_create_engine, mock_open, mock_load):
        # Mock credentials in JSON format
        mock_load.return_value = {
            "dialect": "postgresql",
            "user": "test_user",
            "password": "test_password",
            "host": "localhost",
            "port": 5432,
            "database": "test_db"
        }

        engine = get_engine("path/to/credentials.json")

        database_url = "postgresql://test_user:test_password@localhost:5432/test_db"
        mock_create_engine.assert_called_once_with(database_url, echo=False)
        self.assertEqual(engine, mock_create_engine.return_value)

if __name__ == "__main__":
    unittest.main()
