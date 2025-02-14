-- SPDX-FileCopyrightText: 2024 Helmholtz Centre for Environmental Research GmbH - UFZ
--
-- SPDX-License-Identifier: LicenseRef-UFZ-GPL-3.0-or-later

/*
*   This script builds the Lambda-Miner Database
*/

\i /home/lmdb/ddl/lmdb_schema.sql
\i /home/lmdb/ddl/lmdb_privileges.sql

/*
*   Data
*/

-- Reference data
\i /home/lmdb/data/reference_data/element.sql
\i /home/lmdb/data/reference_data/feature.sql
\i /home/lmdb/data/reference_data/feature_chemical_formula.sql
\i /home/lmdb/data/reference_data/evaluation_rule.sql
\i /home/lmdb/data/reference_data/evaluation_config.sql
\i /home/lmdb/data/reference_data/eval_config_eval_rule.sql
\i /home/lmdb/data/reference_data/chemical_formula_config.sql
\i /home/lmdb/data/reference_data/element_cformula_config.sql
\i /home/lmdb/data/reference_data/sample_preparation.sql
\i /home/lmdb/data/reference_data/user_role.sql

-- Test data

\i /home/lmdb/data/test_data/instrument.sql
\i /home/lmdb/data/test_data/location.sql
\i /home/lmdb/data/test_data/ufz_user.sql
\i /home/lmdb/data/test_data/ufz_user_role.sql
\i /home/lmdb/data/test_data/project.sql
\i /home/lmdb/data/test_data/ufz_user_project.sql
\i /home/lmdb/data/test_data/calibration_method.sql
\i /home/lmdb/data/test_data/sample.sql
\i /home/lmdb/data/test_data/measurement.sql
\i /home/lmdb/data/test_data/peak.sql
\i /home/lmdb/data/test_data/chemical_formula_assignment.sql
\i /home/lmdb/data/test_data/measurement_cformula_config.sql
\i /home/lmdb/data/test_data/eval_config_cfa.sql
\i /home/lmdb/data/test_data/measurement_evaluation_config.sql

/*
*   Journal (recent changes)
*/

\i /home/lmdb/journal/240325-0_drop-table-ufz-user-role.sql
\i /home/lmdb/journal/240508-0_new-calibration-function.sql
\i /home/lmdb/journal/240521-0_geo-distance-function.sql
