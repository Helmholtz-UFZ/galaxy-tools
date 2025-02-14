-- SPDX-FileCopyrightText: 2024 Helmholtz Centre for Environmental Research GmbH - UFZ
--
-- SPDX-License-Identifier: LicenseRef-UFZ-GPL-3.0-or-later

/*
* This SQL script is the template for adding a check constraint to an existing column.
*/

BEGIN;

-- Add the new check constraint to the wanted relation
ALTER TABLE
    -- Enter the wanted relation here
    relation

ADD CONSTRAINT
    -- Enter the wanted constraint here
    relation_constr_name check (column > 0)
;

ROLLBACK;
--COMMIT;
