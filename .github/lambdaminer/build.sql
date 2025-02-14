-- SPDX-FileCopyrightText: 2024 Helmholtz Centre for Environmental Research GmbH - UFZ
--
-- SPDX-License-Identifier: LicenseRef-UFZ-GPL-3.0-or-later

/*
*   This script builds the Lambda-Miner Database
*/

\i ./.github/lambdaminer/ddl/lmdb_schema.sql
\i ./.github/lambdaminer/ddl/lmdb_privileges.sql

/*
*   Data
*/

-- Reference data

\i ./.github/lambdaminer/data/reference_data/chemical_formula_config.sql
\i ./.github/lambdaminer/data/reference_data/element.sql
\i ./.github/lambdaminer/data/reference_data/feature.sql
\i ./.github/lambdaminer/data/reference_data/feature_chemical_formula.sql
\i ./.github/lambdaminer/data/reference_data/evaluation_rule.sql
\i ./.github/lambdaminer/data/reference_data/evaluation_config.sql
\i ./.github/lambdaminer/data/reference_data/eval_config_eval_rule.sql
\i ./.github/lambdaminer/data/reference_data/chemical_formula_config.sql
\i ./.github/lambdaminer/data/reference_data/element_cformula_config.sql
\i ./.github/lambdaminer/data/reference_data/sample_preparation.sql
\i ./.github/lambdaminer/data/reference_data/user_role.sql


-- Test data

\i ./.github/lambdaminer/data/test_data/instrument.sql
\i ./.github/lambdaminer/data/test_data/location.sql
\i ./.github/lambdaminer/data/test_data/ufz_user.sql
\i ./.github/lambdaminer/data/test_data/ufz_user_role.sql
\i ./.github/lambdaminer/data/test_data/project.sql
\i ./.github/lambdaminer/data/test_data/ufz_user_project.sql
\i ./.github/lambdaminer/data/test_data/calibration_method.sql
\i ./.github/lambdaminer/data/test_data/sample.sql
\i ./.github/lambdaminer/data/test_data/measurement.sql
\i ./.github/lambdaminer/data/test_data/peak.sql
\i ./.github/lambdaminer/data/test_data/chemical_formula_assignment.sql
\i ./.github/lambdaminer/data/test_data/measurement_cformula_config.sql
\i ./.github/lambdaminer/data/test_data/eval_config_cfa.sql
\i ./.github/lambdaminer/data/test_data/measurement_evaluation_config.sql

/*
*   Journal (recent changes)
*/

\i ./.github/lambdaminer/journal/240325-0_drop-table-ufz-user-role.sql
\i ./.github/lambdaminer/journal/240508-0_new-calibration-function.sql
\i ./.github/lambdaminer/journal/240521-0_geo-distance-function.sql
