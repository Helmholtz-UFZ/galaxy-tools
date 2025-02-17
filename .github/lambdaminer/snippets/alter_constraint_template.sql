-- SPDX-FileCopyrightText: 2024 Helmholtz Centre for Environmental Research GmbH - UFZ
--
-- SPDX-License-Identifier: LicenseRef-UFZ-GPL-3.0-or-later

/*
* This SQL script is the template for altering a relation constraint. A constraint can not be
* adapted directly. It has to be deleted and applied again.
*/

BEGIN;

-- drop current constraint
ALTER TABLE
    -- enter the wanted relation here
    wanted_relation

DROP CONSTRAINT
    -- enter the wanted constraint here
    wanted_constraint
;

-- add adapted or new constraint
ALTER TABLE
    -- enter the wanted relation here
    wanted_relation

ADD CONSTRAINT
    -- enter the wanted constraint name here
    wanted_constraint

-- enter the adapted or new constraint here, e.g. a check constraint
CHECK
    -- enter the wanted column name and the wanted conditions
    (column_to_check = ANY (ARRAY[
        'value_0'::text,
        'value_1'::text,
        'value_3'::text
    ]))
;

ROLLBACK;
--COMMIT;
