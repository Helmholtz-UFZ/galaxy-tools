-- SPDX-FileCopyrightText: 2024 Helmholtz Centre for Environmental Research GmbH - UFZ
--
-- SPDX-License-Identifier: LicenseRef-UFZ-GPL-3.0-or-later

/*
* This script alters the sample origin check constraint on the relation sample by adding 'other' to
* the list of possible values.
*/

BEGIN;

-- Drop the existing sample origin check constraint
ALTER TABLE
    sample
DROP CONSTRAINT
    sample_origin_check
;

-- Add a the updated sample origin check constraint
ALTER TABLE
    sample
ADD CONSTRAINT
    sample_origin_check
CHECK
    (origin = ANY (ARRAY[
        'aerosols'::text,
        'freshwater'::text,
        'groundwater'::text,
        'marine'::text,
        'sediment porewater'::text,
        'soil extract'::text,
        'soil porewater'::text,
        'wastewater'::text,
        'other leachate'::text,
        'sediment extract'::text,
        'mineral'::text,
        'soil particle'::text,
        'nanoparticle'::text,
        'microplastics'::text,
        'other'::text
    ]))
;

ROLLBACK;
--COMMIT;

/*
-- RECOVERY CODE

BEGIN;

-- Set sample origin to NULL on "other"
UPDATE
    sample
SET
    origin = NULL
WHERE
    origin = 'other'
;

-- Drop the existing sample origin check constraint
ALTER TABLE
    sample
DROP CONSTRAINT
    sample_origin_check
;

-- Add a the previous sample origin check constraint
ALTER TABLE
    sample
ADD CONSTRAINT
    sample_origin_check
CHECK
    (origin = ANY (ARRAY[
        'aerosols'::text,
        'freshwater'::text,
        'groundwater'::text,
        'marine'::text,
        'sediment porewater'::text,
        'soil extract'::text,
        'soil porewater'::text,
        'wastewater'::text,
        'other leachate'::text,
        'sediment extract'::text,
        'mineral'::text,
        'soil particle'::text,
        'nanoparticle'::text,
        'microplastics'::text
    ]))
;

ROLLBACK;
--COMMIT;
*/
