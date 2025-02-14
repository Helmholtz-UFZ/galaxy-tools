-- SPDX-FileCopyrightText: 2024 Helmholtz Centre for Environmental Research GmbH - UFZ
--
-- SPDX-License-Identifier: LicenseRef-UFZ-GPL-3.0-or-later

/*
This script is only necessary to reverse the changes from the script
240508-0_new-calibration-function.sql.
*/

BEGIN;

-- Query from lmdb_schema.sql with adaption: "CREATE OR REPLACE FUNCTION"
CREATE OR REPLACE FUNCTION public.get_calibrated_mz(mz numeric, cal_type character varying, cal_params json) RETURNS numeric
    LANGUAGE plpgsql
    AS $$

DECLARE
    p0 numeric(13,8);
    p1 numeric(13,8);
    p2 numeric(13,8);
    exp_error numeric(13,8);
    cal_mz numeric(13,8);

BEGIN

    IF cal_type = 'linear' THEN
        p0 := cal_params::json -> '0';
        p1 := cal_params::json -> '1';
        exp_error := p1 * mz + p0;
        cal_mz := -( mz / ( exp_error * pow( 10, -6 ) - 1 ) );

        RETURN cal_mz;

    -- If the input calibration type is 'quadratic'
    ELSIF cal_type = 'quadratic' THEN

        p0 := cal_params::json -> '0';
        p1 := cal_params::json -> '1';
        p2 := cal_params::json -> '2';
        exp_error := p2 * pow( mz, 2 ) + p1 * mz + p0;
        cal_mz := -( mz / ( exp_error * pow( 10, -6 ) - 1 ) );

        RETURN cal_mz;

    END IF;

END;
$$;

-- Query from lmdb_schema.sql with adaption: "CREATE OR REPLACE VIEW"
CREATE OR REPLACE VIEW public.calibrated_peak AS
SELECT
    p.peak_id,
    p.measured_mass,
    public.get_calibrated_mz(p.measured_mass, cm.calibration_type, cm.calibration_parameters) AS calibrated_mass,
    p.intensity,
    p.resolution,
    p.adduct,
    p.charge,
    p.sn,
    p.measurement,
    p.added_at,
    p.added_by
FROM
    public.measurement m,
    public.calibration_method cm,
    public.peak p
WHERE
    ((m.calibration_method = cm.calibration_method_id) AND (p.measurement = m.measurement_id))
;

ROLLBACK;
--COMMIT;
