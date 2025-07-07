-- SPDX-FileCopyrightText: 2024 Helmholtz Centre for Environmental Research GmbH - UFZ
--
-- SPDX-License-Identifier: LicenseRef-UFZ-GPL-3.0-or-later

/*
* This script creates two database triggers to set missing information in the sample and
* measurement replicate columns the corresponding sample or measurement id.
*/

BEGIN;

-- Trigger function for missing sample replicates
CREATE OR REPLACE FUNCTION set_replicate_of_sample()
RETURNS TRIGGER AS $$
BEGIN
    -- Check if replicate_of_sample is NULL
    IF NEW.replicate_of_sample IS NULL THEN
        -- Set replicate_of_sample to the value of the name column
        NEW.replicate_of_sample := NEW.sample_id;
    END IF;

    -- Return NEW to apply the changes
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for missing sample replicates
CREATE TRIGGER sample_replicate_trigger
BEFORE INSERT OR UPDATE
ON sample
FOR EACH ROW
EXECUTE FUNCTION set_replicate_of_sample();

-- Trigger function for missing measurement replicates
CREATE OR REPLACE FUNCTION set_replicate_of_measurement()
RETURNS TRIGGER AS $$
BEGIN
    -- Check if replicate_of_measurement is NULL
    IF NEW.replicate_of_measurement IS NULL THEN
        -- Set replicate_of_sample to the value of the name column
        NEW.replicate_of_measurement := NEW.measurement_id;
    END IF;

    -- Return NEW to apply the changes
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for missing measurements replicates
CREATE TRIGGER measurement_replicate_trigger
BEFORE INSERT OR UPDATE
ON measurement
FOR EACH ROW
EXECUTE FUNCTION set_replicate_of_measurement();

ROLLBACK;
--COMMIT;
