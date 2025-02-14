-- SPDX-FileCopyrightText: 2024 Helmholtz Centre for Environmental Research GmbH - UFZ
--
-- SPDX-License-Identifier: LicenseRef-UFZ-GPL-3.0-or-later

/*
* This SQL script is the template for deleting evaluations from the LMDB for a whole project.
* Therefore, the script deletes from measurement_evaluation_config and from eval_config_cfa using
* the data queried in the temporary table.
*/


BEGIN;

-- initialize a temporary table with wanted data
-- adapt the where clause
-- ATTENTION: the temporary table has to be copy-pasted below!
WITH t AS (
    SELECT
        m.measurement_id,
        p.peak_id,
        cfa.chemical_formula_assignment_id,
        cfa.chemical_formula_config_id,
        ecc.evaluation_config_id
    FROM
        sample s,
        measurement m,
        peak p,
        chemical_formula_assignment cfa,
        eval_config_cfa ecc
    WHERE
        s.sample_id = m.sample AND
        m.measurement_id = p.measurement AND
        p.peak_id = cfa.peak_id AND
        cfa.chemical_formula_assignment_id = ecc.chemical_formula_assignment_id AND
        s.project = 500 AND -- Adapt the project id here
        cfa.chemical_formula_config_id IN (143) AND -- Adapt the cfc id here
        ecc.evaluation_config_id IN (91) -- Adapt the ec id here
)

DELETE FROM
    measurement_evaluation_config
WHERE
    measurement_id IN (SELECT measurement_id FROM t) AND
    chemical_formula_config_id IN (SELECT chemical_formula_config_id FROM t) AND
    evaluation_config_id IN (SELECT evaluation_config_id FROM t)
;


-- copy-paste the temporary table from above here
WITH t AS (
    SELECT
        m.measurement_id,
        p.peak_id,
        cfa.chemical_formula_assignment_id,
        cfa.chemical_formula_config_id,
        ecc.evaluation_config_id
    FROM
        sample s,
        measurement m,
        peak p,
        chemical_formula_assignment cfa,
        eval_config_cfa ecc
    WHERE
        s.sample_id = m.sample AND
        m.measurement_id = p.measurement AND
        p.peak_id = cfa.peak_id AND
        cfa.chemical_formula_assignment_id = ecc.chemical_formula_assignment_id AND
        s.project = 500 AND -- Adapt the project id here
        cfa.chemical_formula_config_id IN (143) AND -- Adapt the cfc id here
        ecc.evaluation_config_id IN (91) -- Adapt the ec id here
)

DELETE FROM
    eval_config_cfa
WHERE
    chemical_formula_assignment_id IN (SELECT chemical_formula_assignment_id FROM t) AND
    evaluation_config_id IN (SELECT evaluation_config_id FROM t)
;

ROLLBACK; -- Un-does your queries
--COMMIT; -- Commits your queries
