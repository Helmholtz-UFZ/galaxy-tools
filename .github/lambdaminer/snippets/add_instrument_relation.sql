-- SPDX-FileCopyrightText: 2024 Helmholtz Centre for Environmental Research GmbH - UFZ
--
-- SPDX-License-Identifier: LicenseRef-UFZ-GPL-3.0-or-later

/*
* This SQL script creates the a relation called "instrument" to store instrument information.
*/

BEGIN;

CREATE TABLE IF NOT EXISTS instrument (
    instrument_id serial PRIMARY KEY,
    name text NOT NULL UNIQUE,
    serial_number text NOT NULL UNIQUE,
    location text NOT NULL,
    institute text NOT NULL,
    contact_mail text NOT NULL,
    type text NOT NULL,
    model text NOT NULL,
    manufacturer text NOT NULL,
    parameters json
);

INSERT INTO instrument VALUES (
    1, -- ID
    'solariX-12T-2XR', -- Name
    '1272500-00128', -- Serial number
    'Leipzig', -- Location
    'Department of Analytical Chemistry', -- Institute
    'oliver.lechtenfeld@ufz.de', -- Contact mail
    'ICR', -- Type
    'solariX', -- Model
    'Bruker', -- Manufacturer
    '{ "field_strength": "12T", "icr_cell": "2XR"}' -- Parameters
), (
    2, -- ID
    'scimaX-7T-2XR', -- Name
    '1859310-00244', -- Serial number
    'Leipzig', -- Location
    'Department of Analytical Chemistry', -- Institute
    'oliver.lechtenfeld@ufz.de', -- Contact mail
    'ICR', -- Type
    'scimaX', -- Model
    'Bruker', -- Manufacturer
    '{ "field_strength": "7T", "icr_cell": "2XR"}' -- Parameters
);

-- Link the instrument relation to the measurement relation
-- Set default as 1 (solariX) to assign this instrument to all measurements
ALTER TABLE measurement
ADD COLUMN instrument INTEGER NOT NULL DEFAULT 1 REFERENCES instrument(instrument_id);

-- Drop the default constraint for proper usage
ALTER TABLE measurement ALTER COLUMN instrument DROP DEFAULT;

-- Link the instrument relation to the qc method relation
-- Set default as 1 (solariX) to assign this instrument to all qc methods
ALTER TABLE qc_method
ADD COLUMN instrument INTEGER NOT NULL DEFAULT 1 REFERENCES instrument(instrument_id);

-- Drop the default constraint for proper usage
ALTER TABLE qc_method ALTER COLUMN instrument DROP DEFAULT;

ROLLBACK;
--COMMIT;
