-- SPDX-FileCopyrightText: 2024 Helmholtz Centre for Environmental Research GmbH - UFZ
--
-- SPDX-License-Identifier: LicenseRef-UFZ-GPL-3.0-or-later

/*
*   This script builds the Lambda-Miner Database
*/

\i /home/cflib/ddl/cflib_schema.sql
\i /home/cflib/ddl/cflib_privileges.sql

/*
*   Data
*/

\i /home/cflib/data/chemical_formula.sql

/*
*   Journal (recent changes)
*/

--\i /home/lmdb/journal/
