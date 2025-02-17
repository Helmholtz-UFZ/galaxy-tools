-- SPDX-FileCopyrightText: 2024 Helmholtz Centre for Environmental Research GmbH - UFZ
--
-- SPDX-License-Identifier: LicenseRef-UFZ-GPL-3.0-or-later

/*
This script replaces the existing get_calibrated_mz function and replaces it with a new one. The
function is adapted to calculate the calibration on neutral masses, since this is what is done in
the workflow and resulted in a shift of results. This script also replaces the existing calibrated
peak view, because more function parameters are needed for the calculation of neutral masses in the
get_calibrated_mz function.
*/

BEGIN;

CREATE OR REPLACE FUNCTION public.get_calibrated_mz(mz numeric, cal_type character varying, cal_params json, ionization numeric, charge int, electron_config character varying)
RETURNS numeric AS
$$
DECLARE
    p0 numeric(25,20);
    p1 numeric(25,20);
    p2 numeric(25,20);
    proton_mass numeric(25,20) := 1.0072764521;
    electron_mass numeric(25,20) := 0.0005485799;
    measured_neutral_mass numeric(25,20);
    predicted_error numeric(25,20);
    calibrated_neutral_mass numeric(25,20);
    calibrated_mz numeric(13,8);

BEGIN

    -- Calculate the measured neutral mass depending on the electron configuration.
    IF electron_config = 'even' THEN
        measured_neutral_mass := mz * charge - (ionization * charge * proton_mass);

    ELSIF electron_config = 'odd' THEN
        measured_neutral_mass = mz * charge + (ionization * charge * electron_mass);

    END IF;

    -- Calculate the predicted error depending on the type of the calibration function.
    IF cal_type = 'linear' THEN
        p0 := cal_params::json -> '0';
        p1 := cal_params::json -> '1';

        predicted_error := p1 * measured_neutral_mass + p0;

    ELSIF cal_type = 'quadratic' THEN
        p0 := cal_params::json -> '0';
        p1 := cal_params::json -> '1';
        p2 := cal_params::json -> '2';

        predicted_error := p2 * pow( measured_neutral_mass, 2 ) + p1 * measured_neutral_mass + p0;

    END IF;

    -- Calculate the calibrated neutral mass from the measured neutral mass and the predicted
    -- error.
    calibrated_neutral_mass := (pow(10,6) * measured_neutral_mass)/(pow(10,6) + predicted_error);

    -- Calculate the calibrated measured mass depending on the electron configuration.
    IF electron_config = 'even' THEN

        calibrated_mz := (calibrated_neutral_mass + (ionization * charge * proton_mass))/charge;

    ELSIF electron_config = 'odd' THEN

        calibrated_mz := (calibrated_neutral_mass - (ionization * charge * electron_mass))/charge;

    END IF;

    RETURN calibrated_mz;

END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE VIEW public.calibrated_peak AS
 SELECT
    p.peak_id,
    p.measured_mass,
    -- Input additional parameters in the get_calibrated_mz function
    public.get_calibrated_mz(p.measured_mass, cm.calibration_type, cm.calibration_parameters, m.ionisation, p.charge, cm.electron_config) AS calibrated_mass,
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
    ((m.calibration_method = cm.calibration_method_id) AND (p.measurement = m.measurement_id));


--ROLLBACK;
COMMIT;
