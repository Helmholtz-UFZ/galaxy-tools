-- SPDX-FileCopyrightText: 2024 Helmholtz Centre for Environmental Research GmbH - UFZ
--
-- SPDX-License-Identifier: LicenseRef-UFZ-GPL-3.0-or-later

/*
* This SQL script is the template for adding a new column to an existing relation.
*/

BEGIN;

-- Add the new column to the wanted relation
ALTER TABLE
    -- Enter the wanted relation here
    relation

ADD COLUMN
    -- Enter the wanted column here
    col_name data_type constraints defaults
;

ROLLBACK;
--COMMIT;
