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
    measurement

DROP CONSTRAINT
    -- enter the wanted constraint here
    measurement_peak_picking_algorithm_check
;

-- add adapted or new constraint
ALTER TABLE
    -- enter the wanted relation here
    measurement

ADD CONSTRAINT
    -- enter the wanted constraint name here
    measurement_peak_picking_algorithm_check

CHECK
    (peak_picking_algorithm::text = ANY (ARRAY['MRMS'::character varying::text, 'sMRMS'::character varying::text, 'nsMRMS'::character varying::text, 'FTMS'::character varying::text, 'SNAP'::character varying::text, 'CENTROID'::character varying::text, 'APEX'::character varying::text]))

;

ROLLBACK;
--COMMIT;
