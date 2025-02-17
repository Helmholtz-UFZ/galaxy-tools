-- SPDX-FileCopyrightText: 2024 Helmholtz Centre for Environmental Research GmbH - UFZ
--
-- SPDX-License-Identifier: LicenseRef-UFZ-GPL-3.0-or-later

/*
* This script adds the function pretty_formula to return formula json columns as text in a human
* readable and pretty format.
*/

BEGIN;

CREATE OR REPLACE FUNCTION pretty_formula(input_json JSON, separator TEXT DEFAULT '')
RETURNS TEXT AS $$
DECLARE
    result TEXT := '';
    item JSON;
    key TEXT;
    value TEXT;
BEGIN
    -- Loop through the array elements in the JSON array
    FOR item IN SELECT * FROM json_array_elements(input_json)
    LOOP
        -- Loop through the key-value pairs of each JSON object
        FOR key, value IN SELECT * FROM json_each_text(item)
        LOOP
            -- Concatenate key-value pairs with the provided separator
            result := result || key || value || separator;
        END LOOP;
    END LOOP;

    -- Remove the trailing separator if present
    IF separator <> '' THEN
        result := left(result, length(result) - length(separator));
    END IF;

    RETURN result;
END;
$$ LANGUAGE plpgsql;


ROLLBACK;
--COMMIT;

/*
-- RECOVERY CODE

BEGIN;

DROP FUNCTION pretty_formula(JSON, TEXT);

ROLLBACK;
--COMMIT;
*/
