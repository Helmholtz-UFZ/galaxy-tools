-- SPDX-FileCopyrightText: 2024 Helmholtz Centre for Environmental Research GmbH - UFZ
--
-- SPDX-License-Identifier: LicenseRef-UFZ-GPL-3.0-or-later

/*
* This SQL script adds the new column called "barcode" to the sample relation.
*/

BEGIN;

ALTER TABLE
    sample

ADD COLUMN
    barcode varchar(14)
;

ROLLBACK;
--COMMIT;
