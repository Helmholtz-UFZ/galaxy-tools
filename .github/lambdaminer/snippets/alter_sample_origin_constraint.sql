-- SPDX-FileCopyrightText: 2024 Helmholtz Centre for Environmental Research GmbH - UFZ
--
-- SPDX-License-Identifier: LicenseRef-UFZ-GPL-3.0-or-later

/*
* This SQL script is the template for altering the sample origin check constraint. A constraint can
* not be adapted directly. It has to be deleted and applied again.
*/

BEGIN;

-- drop current constraint
ALTER TABLE
    sample

DROP CONSTRAINT
    sample_origin_check
;

-- add adapted or new constraint
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
