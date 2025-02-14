-- SPDX-FileCopyrightText: 2024 Helmholtz Centre for Environmental Research GmbH - UFZ
--
-- SPDX-License-Identifier: LicenseRef-UFZ-GPL-3.0-or-later

/*
*   This script builds the Lambda-Miner Database
*/

\i ./.github/lambaminer/ddl/lmdb_schema.sql
\i ./.github/lambaminer/ddl/lmdb_privileges.sql

/*
*   Data
*/

-- Reference data

\i ./.github/lambdaminer/data/reference_data/chemical_formula_config.sql


-- Test data

\i ./.github/lambdaminer/data/test_data/instrument.sql


/*
*   Journal (recent changes)
*/

\i ./.github/lambdaminer/journal/240325-0_drop-table-ufz-user-role.sql
\i ./.github/lambdaminer/journal/240508-0_new-calibration-function.sql
\i ./.github/lambdaminer/journal/240521-0_geo-distance-function.sql
