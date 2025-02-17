-- SPDX-FileCopyrightText: 2024 Helmholtz Centre for Environmental Research GmbH - UFZ
--
-- SPDX-License-Identifier: LicenseRef-UFZ-GPL-3.0-or-later

/*
* This SQL script adds the new check constraint called "dilution_factor_check" to the measurement
* relation.
*/

BEGIN;

ALTER TABLE
    measurement

ADD CONSTRAINT
    dilution_factor_check
CHECK
    (dilution_factor >= 1.0)
;

ROLLBACK;
--COMMIT;
