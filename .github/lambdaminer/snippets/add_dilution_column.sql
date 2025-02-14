-- SPDX-FileCopyrightText: 2024 Helmholtz Centre for Environmental Research GmbH - UFZ
--
-- SPDX-License-Identifier: LicenseRef-UFZ-GPL-3.0-or-later

/*
* This SQL script adds the new column called "dilution_factor" to the measurement relation.
*/

BEGIN;

ALTER TABLE
    measurement

ADD COLUMN
    dilution_factor numeric(5,1) DEFAULT 1.0
;

ROLLBACK;
--COMMIT;
