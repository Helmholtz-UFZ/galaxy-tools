-- SPDX-FileCopyrightText: 2024 Helmholtz Centre for Environmental Research GmbH - UFZ
--
-- SPDX-License-Identifier: LicenseRef-UFZ-GPL-3.0-or-later

/*
* This SQL script is the template for deleting all assignments of a project of a CFC from the LMDB.
* Therefore, the script deletes from measurement_cformula_config and from
* chemical_formula_assignment using the data queried in the temporary table.
*/


BEGIN;

SELECT
    m.measurement_id,
    p.peak_id
INTO
    TEMP TABLE temp_table
FROM
    sample AS s,
    measurement AS m,
    peak AS p
WHERE
    s.sample_id = m.sample AND
    m.measurement_id = p.measurement AND
    s.project = 342 -- Adapt the project id here
;

-- Delete assignments from measurement_cformula_config
DELETE FROM
    measurement_cformula_config
WHERE
    measurement_id IN (SELECT measurement_id FROM temp_table) AND
    chemical_formula_config_id = 122 -- Adapt the CFC id here
;

-- Delete assignments from chemical_formula_assignment
DELETE FROM
    chemical_formula_assignment
WHERE
    peak_id IN (SELECT peak_id FROM temp_table) AND
    chemical_formula_config_id = 122 -- Adapt the CFC id here
;

ROLLBACK; -- Un-does your queries
--COMMIT; -- Commits your queries
