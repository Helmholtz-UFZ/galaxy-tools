-- SPDX-FileCopyrightText: 2024 Helmholtz Centre for Environmental Research GmbH - UFZ
--
-- SPDX-License-Identifier: LicenseRef-UFZ-GPL-3.0-or-later

/*
* This SQL script prepares the Lambda Miner database for the calibration functionality.
* It does the following:
*   Create the relation 'calibration_method'
*   Alters the relation 'feature'
*
*
* Author: Johann Wurz
* Vendor: Helmholtz Center for Environmental Research - UFZ
*
*/

BEGIN;

/*
* Create the relation 'calibration_method'
* to store calibration parameters for later calculation of calibrated data.
*/

CREATE TABLE IF NOT EXISTS calibration_method (
    calibration_method_id SERIAL PRIMARY KEY,
    calibration_list INTEGER NOT NULL REFERENCES feature (feature_id) ON DELETE RESTRICT,
    calibration_type VARCHAR(15) CHECK (calibration_type IN ('linear', 'quadratic')) NOT NULL,
    calibration_parameters json NOT NULL,
    ppm_window NUMERIC(5,2),
    sn_threshold NUMERIC(5,2),
    outlier_k_factor NUMERIC(5,2),
    electron_config VARCHAR(4) CHECK (electron_config IN ('even', 'odd')) DEFAULT 'even',
    added_at TIMESTAMP with TIME ZONE DEFAULT current_timestamp NOT NULL,
    added_by INTEGER REFERENCES ufz_user (user_id) ON DELETE SET NULL
);

/*
* Add the new column `active` to the feature relation similar to the one in the
* `chemical_formula_config` relation. This automatically sets the column `active`
* for all already existing entries to `true`.
*/
ALTER TABLE feature ADD COLUMN active BOOLEAN NOT NULL DEFAULT TRUE;

-- Set active status of old calibration lists to false
UPDATE feature SET active = false WHERE type = 'calibration list';

-- Add the column 'added_at' to the feature relation with a timestamp as default
ALTER TABLE feature ADD COLUMN added_at TIMESTAMP with TIME ZONE DEFAULT current_timestamp NOT NULL;

-- ADD the column 'added_by' to the feature relation and link it to the user ids in ufz_user
ALTER TABLE feature ADD COLUMN added_by INTEGER REFERENCES ufz_user (user_id) ON DELETE SET NULL;

-- Add the new column 'library' to the feature relation similar to the one in the
-- 'chemical_formula_config' relation.
ALTER TABLE feature
ADD COLUMN library VARCHAR(10)
CHECK (library IN ('small', 'big'))
;

-- Set library in feature for all entries to 'small'
UPDATE feature SET library = 'small';

/*
*   Insert new calibration lists to the feature relation including all calibration lists found in
*   the measurement relation from before the calibration implementation.
*   Query to get the calibration lists:
    \copy (
        SELECT
            feature_id,
            name,
            description,
            type,
            active,
            library
        FROM
            feature
        WHERE
            type = 'calibration list' AND
            feature_id > 73
        ORDER BY
            feature_id
    ) TO 'new_calibration_lists.csv'
    CSV DELIMITER ',' HEADER QUOTE '"'
    ;
*/
INSERT INTO
    feature (
        feature_id,
        name,
        description,
        type,
        active,
        library
    )
VALUES
    (
        '78',
        'SRFA-Roland_neg_248-644',
        'Roland SRFA calibration list for measurements in negative mode.',
        'calibration list',
        't',
        'small'
    )
;
INSERT INTO
    feature (
        feature_id,
        name,
        description,
        type,
        active,
        library
    )
VALUES
    (
        '79',
        'SRFA-Roland-Na_pos_149-720',
        'SRFA-Roland-Na positive',
        'calibration list',
        't',
        'small'
    )
;
INSERT INTO
    feature (
        feature_id,
        name,
        description,
        type,
        active,
        library
    )
VALUES
    (
        '81',
        'Sugars-NOM-Na_pos_158-666',
        'Sugars-NOM-Na positve',
        'calibration list',
        't',
        'small'
    )
;
INSERT INTO
    feature (
        feature_id,
        name,
        description,
        type,
        active,
        library
    )
VALUES
    (
        '82',
        'FattyAcids-Sulfonates_neg_88-466',
        'FattyAcids-Sulfonates_neg_102-466 negative.',
        'calibration list',
        't',
        'small'
    )
;
INSERT INTO
    feature (
        feature_id,
        name,
        description,
        type,
        active,
        library
    )
VALUES
    (
        '83',
        'SRFA-Roland_neg_150-998',
        'SRFA Roland neg (former extended 1000 mz)',
        'calibration list',
        't',
        'small'
    )
;
INSERT INTO
    feature (
        feature_id,
        name,
        description,
        type,
        active,
        library
    )
VALUES
    (
        '84',
        'SRFA-Roland_neg_150-720',
        'SRFA Roland negative (former extended)',
        'calibration list',
        't',
        'small'
    )
;
INSERT INTO
    feature (
        feature_id,
        name,
        description,
        type,
        active,
        library
    )
VALUES
    (
        '85',
        'SRFA-Roland-Hi-Lo-polar_neg_150-978',
        'SRFA Roland Hi-Lo-polar negative (former extend H-L-Polar)',
        'calibration list',
        't',
        'small'
    )
;
INSERT INTO
    feature (
        feature_id,
        name,
        description,
        type,
        active,
        library
    )
VALUES
    (
        '86',
        'SRFA-Roland-Hi-polar_neg_160-568',
        'Former SRFA_neg Roland_highlypolar',
        'calibration list',
        't',
        'small'
    )
;
INSERT INTO
    feature (
        feature_id,
        name,
        description,
        type,
        active,
        library
    )
VALUES
    (
        '87',
        'SRFA-Roland-Hi-polar_neg_150-978',
        'former SRFA_neg Roland_extend_HPolar',
        'calibration list',
        't',
        'small'
    )
;
INSERT INTO
    feature (
        feature_id,
        name,
        description,
        type,
        active,
        library
    )
VALUES
    (
        '88',
        'FattyAcids-Sulfonates-Sugars_pos_88-666',
        'Former Fatty Acid + Sulfonates + sugars (pos)',
        'calibration list',
        't',
        'small'
    )
;
INSERT INTO
    feature (
        feature_id,
        name,
        description,
        type,
        active,
        library
    )
VALUES
    (
        '89',
        'FattyAcids-Sulfonates_pos_88-466',
        'Former Fatty Acid + Sulfonates (pos)',
        'calibration list',
        't',
        'small'
    )
;
INSERT INTO
    feature (
        feature_id,
        name,
        description,
        type,
        active,
        library
    )
VALUES
    (
        '90',
        'ESI Fatty Acids (neg)_deprecated',
        'Deprecated calibration list from the time before the Lambda Miner calibration.',
        'calibration list',
        'f',
        NULL
    )
;
INSERT INTO
    feature (
        feature_id,
        name,
        description,
        type,
        active,
        library
    )
VALUES
    (
        '91',
        'ESI Surf+Fatty+Salt_CalibList_deprecated',
        'Deprecated calibration list from the time before the Lambda Miner calibration.',
        'calibration list',
        'f',
        NULL
    )
;
INSERT INTO
    feature (
        feature_id,
        name,
        description,
        type,
        active,
        library
    )
VALUES
    (
        '92',
        ' ESI Sugars-NOM-Na_pos_165-689_deprecated',
        'Deprecated calibration list from the time before the Lambda Miner calibration.',
        'calibration list',
        'f',
        NULL
    )
;
INSERT INTO
    feature (
        feature_id,
        name,
        description,
        type,
        active,
        library
    )
VALUES
    (
        '93',
        'ESI Fatty Acids_even_odd (neg)_deprecated',
        'Deprecated calibration list from the time before the Lambda Miner calibration.',
        'calibration list',
        'f',
        NULL
    )
;
INSERT INTO
    feature (
        feature_id,
        name,
        description,
        type,
        active,
        library
    )
VALUES
    (
        '94',
        '_deprecated',
        'Deprecated calibration list from the time before the Lambda Miner calibration.',
        'calibration list',
        'f',
        NULL
    )
;
INSERT INTO
    feature (
        feature_id,
        name,
        description,
        type,
        active,
        library
    )
VALUES
    (
        '95',
        'ESI PEG (neg)_deprecated',
        'Deprecated calibration list from the time before the Lambda Miner calibration.',
        'calibration list',
        'f',
        NULL
    )
;
INSERT INTO
    feature (
        feature_id,
        name,
        description,
        type,
        active,
        library
    )
VALUES
    (
        '96',
        ' ESI SRFA-Na_pos Roland_extended_deprecated',
        'Deprecated calibration list from the time before the Lambda Miner calibration.',
        'calibration list',
        'f',
        NULL
    )
;
INSERT INTO
    feature (
        feature_id,
        name,
        description,
        type,
        active,
        library
    )
VALUES
    (
        '97',
        'ESI PFC (neg)_deprecated',
        'Deprecated calibration list from the time before the Lambda Miner calibration.',
        'calibration list',
        'f',
        NULL
    )
;
INSERT INTO
    feature (
        feature_id,
        name,
        description,
        type,
        active,
        library
    )
VALUES
    (
        '98',
        'ESI Na TFA_deprecated',
        'Deprecated calibration list from the time before the Lambda Miner calibration.',
        'calibration list',
        'f',
        NULL
    )
;
INSERT INTO
    feature (
        feature_id,
        name,
        description,
        type,
        active,
        library
    )
VALUES
    (
        '99',
        'ESI Fatty Acid + Sulfonates (neg)_deprecated',
        'Deprecated calibration list from the time before the Lambda Miner calibration.',
        'calibration list',
        'f',
        NULL
    )
;
INSERT INTO
    feature (
        feature_id,
        name,
        description,
        type,
        active,
        library
    )
VALUES
    (
        '100',
        ' _deprecated',
        'Deprecated calibration list from the time before the Lambda Miner calibration.',
        'calibration list',
        'f',
        NULL
    )
;
INSERT INTO
    feature (
        feature_id,
        name,
        description,
        type,
        active,
        library
    )
VALUES
    (
        '101',
        'ESI Fatty Acid + Sulfonates (pos)_deprecated',
        'Deprecated calibration list from the time before the Lambda Miner calibration.',
        'calibration list',
        'f',
        NULL
    )
;
INSERT INTO
    feature (
        feature_id,
        name,
        description,
        type,
        active,
        library
    )
VALUES
    (
        '102',
        'ESI Coffeine_and_adducts_pos_deprecated',
        'Deprecated calibration list from the time before the Lambda Miner calibration.',
        'calibration list',
        'f',
        NULL
    )
;

INSERT INTO
    feature (
        feature_id,
        name,
        description,
        type,
        active,
        library
    )
VALUES
    (
        '104',
        'ESI SRFA_neg Roland_highlypolar_deprecated',
        'Deprecated calibration list from the time before the Lambda Miner calibration.',
        'calibration list',
        'f',
        NULL
    )
;
INSERT INTO
    feature (
        feature_id,
        name,
        description,
        type,
        active,
        library
    )
VALUES
    (
        '105',
        'ESI a-Pinen-OH-HOMS (neg)_deprecated',
        'Deprecated calibration list from the time before the Lambda Miner calibration.',
        'calibration list',
        'f',
        NULL
    )
;
INSERT INTO
    feature (
        feature_id,
        name,
        description,
        type,
        active,
        library
    )
VALUES
    (
        '106',
        'ESI Surfactants+FattyAcids+SaltCluster_neg_deprecated',
        'Deprecated calibration list from the time before the Lambda Miner calibration.',
        'calibration list',
        'f',
        NULL
    )
;
INSERT INTO
    feature (
        feature_id,
        name,
        description,
        type,
        active,
        library
    )
VALUES
    (
        '107',
        'ESI SRFA_pos Roland_deprecated',
        'Deprecated calibration list from the time before the Lambda Miner calibration.',
        'calibration list',
        'f',
        NULL
    )
;
INSERT INTO
    feature (
        feature_id,
        name,
        description,
        type,
        active,
        library
    )
VALUES
    (
        '108',
        'ESI_deprecated',
        'Deprecated calibration list from the time before the Lambda Miner calibration.',
        'calibration list',
        'f',
        NULL
    )
;
INSERT INTO
    feature (
        feature_id,
        name,
        description,
        type,
        active,
        library
    )
VALUES
    (
        '109',
        'ESI Fatty Acids_deprecated',
        'Deprecated calibration list from the time before the Lambda Miner calibration.',
        'calibration list',
        'f',
        NULL
    )
;
INSERT INTO
    feature (
        feature_id,
        name,
        description,
        type,
        active,
        library
    )
VALUES
    (
        '110',
        'ESI Sugars-NOM-Na_pos_165-689_deprecated',
        'Deprecated calibration list from the time before the Lambda Miner calibration.',
        'calibration list',
        'f',
        NULL
    )
;
INSERT INTO
    feature (
        feature_id,
        name,
        description,
        type,
        active,
        library
    )
VALUES
    (
        '111',
        'ESI SRFA_neg Roland_extended_deprecated',
        'Deprecated calibration list from the time before the Lambda Miner calibration.',
        'calibration list',
        'f',
        NULL
    )
;
INSERT INTO
    feature (
        feature_id,
        name,
        description,
        type,
        active,
        library
    )
VALUES
    (
        '112',
        'ESI <not set>_deprecated',
        'Deprecated calibration list from the time before the Lambda Miner calibration.',
        'calibration list',
        'f',
        NULL
    )
;
INSERT INTO
    feature (
        feature_id,
        name,
        description,
        type,
        active,
        library
    )
VALUES
    (
        '113',
        ' ESI SRFA_neg Roland_extended_deprecated',
        'Deprecated calibration list from the time before the Lambda Miner calibration.',
        'calibration list',
        'f',
        NULL
    )
;
INSERT INTO
    feature (
        feature_id,
        name,
        description,
        type,
        active,
        library
    )
VALUES
    (
        '115',
        ' ESI SRFA_neg Roland_extend_H-Lpolar-D_deprecated',
        'Deprecated calibration list from the time before the Lambda Miner calibration.',
        'calibration list',
        'f',
        NULL
    )
;
INSERT INTO
    feature (
        feature_id,
        name,
        description,
        type,
        active,
        library
    )
VALUES
    (
        '116',
        '<not set> <not set>_deprecated',
        'Deprecated calibration list from the time before the Lambda Miner calibration.',
        'calibration list',
        'f',
        NULL
    )
;
INSERT INTO
    feature (
        feature_id,
        name,
        description,
        type,
        active,
        library
    )
VALUES
    (
        '117',
        'ESI SRFA_neg Roland_extend_Hpolar_Fatty_Acid_deprecated',
        'Deprecated calibration list from the time before the Lambda Miner calibration.',
        'calibration list',
        'f',
        NULL
    )
;
INSERT INTO
    feature (
        feature_id,
        name,
        description,
        type,
        active,
        library
    )
VALUES
    (
        '118',
        'ESI few_DiPAPs_deprecated',
        'Deprecated calibration list from the time before the Lambda Miner calibration.',
        'calibration list',
        'f',
        NULL
    )
;
INSERT INTO
    feature (
        feature_id,
        name,
        description,
        type,
        active,
        library
    )
VALUES
    (
        '119',
        'ESI SRFA_neg Roland_extend_1000mz_deprecated',
        'Deprecated calibration list from the time before the Lambda Miner calibration.',
        'calibration list',
        'f',
        NULL
    )
;
INSERT INTO
    feature (
        feature_id,
        name,
        description,
        type,
        active,
        library
    )
VALUES
    (
        '120',
        'ESI SRFA-Na_pos Roland_extended_deprecated',
        'Deprecated calibration list from the time before the Lambda Miner calibration.', 'calibration list', 'f', NULL
    )
;
INSERT INTO
    feature (
        feature_id,
        name,
        description,
        type,
        active,
        library
    )
VALUES
    (
        '121',
        ' ESI Fatty Acid + Sulfonates (neg)_deprecated',
        'Deprecated calibration list from the time before the Lambda Miner calibration.',
        'calibration list',
        'f',
        NULL
    )
;
INSERT INTO
    feature (
        feature_id,
        name,
        description,
        type,
        active,
        library
    )
VALUES
    (
        '122',
        'ESI Glutamate_neg_deprecated',
        'Deprecated calibration list from the time before the Lambda Miner calibration.',
        'calibration list',
        'f',
        NULL
    )
;
INSERT INTO
    feature (
        feature_id,
        name,
        description,
        type,
        active,
        library
    )
VALUES
    (
        '123',
        'SRFA-Na_pos Roland_extended_deprecated',
        'Deprecated calibration list from the time before the Lambda Miner calibration.',
        'calibration list',
        'f',
        NULL
    )
;
INSERT INTO
    feature (
        feature_id,
        name,
        description,
        type,
        active,
        library
    )
VALUES
    (
        '124',
        ' ESI SRFA_neg Roland_extend_Hpolar_deprecated',
        'Deprecated calibration list from the time before the Lambda Miner calibration.',
        'calibration list',
        'f',
        NULL
    )
;
INSERT INTO
    feature (
        feature_id,
        name,
        description,
        type,
        active,
        library
    )
VALUES
    (
        '125',
        'MALDI DHB_neg_deprecated',
        'Deprecated calibration list from the time before the Lambda Miner calibration.',
        'calibration list',
        'f',
        NULL
    )
;
INSERT INTO
    feature (
        feature_id,
        name,
        description,
        type,
        active,
        library
    )
VALUES
    (
        '126',
        'ESI SFRA pos_deprecated',
        'Deprecated calibration list from the time before the Lambda Miner calibration.',
        'calibration list',
        'f',
        NULL
    )
;
INSERT INTO
    feature (
        feature_id,
        name,
        description,
        type,
        active,
        library
    )
VALUES
    (
        '127',
        'ESI FattyAcid_Sulfonates_sugars_(neg)_0420_deprecated',
        'Deprecated calibration list from the time before the Lambda Miner calibration.',
        'calibration list',
        'f',
        NULL
    )
;
INSERT INTO
    feature (
        feature_id,
        name,
        description,
        type,
        active,
        library
    )
VALUES
    (
        '128',
        'ESI Zher_FaandPosSeries_deprecated',
        'Deprecated calibration list from the time before the Lambda Miner calibration.',
        'calibration list',
        'f',
        NULL
    )
;
INSERT INTO
    feature (
        feature_id,
        name,
        description,
        type,
        active,
        library
    )
VALUES
    (
        '129',
        ' ESI SRFA_neg Roland_extend_H-Lpolar_deprecated',
        'Deprecated calibration list from the time before the Lambda Miner calibration.',
        'calibration list',
        'f',
        NULL
    )
;
INSERT INTO
    feature (
        feature_id,
        name,
        description,
        type,
        active,
        library
    )
VALUES
    (
        '130',
        ' ESI SRFA_neg Roland_deprecated',
        'Deprecated calibration list from the time before the Lambda Miner calibration.',
        'calibration list',
        'f',
        NULL
    )
;
INSERT INTO
    feature (
        feature_id,
        name,
        description,
        type,
        active,
        library
    )
VALUES
    (
        '131',
        'ESI SRFA_neg Roland_extend_Hpolar_deprecated',
        'Deprecated calibration list from the time before the Lambda Miner calibration.',
        'calibration list',
        'f',
        NULL
    )
;
INSERT INTO
    feature (
        feature_id,
        name,
        description,
        type,
        active,
        library
    )
VALUES
    (
        '132',
        'ESI FattyAcid_Sulfonates_sugars-Cl_(neg)_0520_deprecated',
        'Deprecated calibration list from the time before the Lambda Miner calibration.',
        'calibration list',
        'f',
        NULL
    )
;
INSERT INTO
    feature (
        feature_id,
        name,
        description,
        type,
        active,
        library
    )
VALUES
    (
        '133',
        'ESI _deprecated',
        'Deprecated calibration list from the time before the Lambda Miner calibration.',
        'calibration list',
        'f',
        NULL
    )
;
INSERT INTO
    feature (
        feature_id,
        name,
        description,
        type,
        active,
        library
    )
VALUES
    (
        '134',
        'ESI SRFA_neg Roland_deprecated',
        'Deprecated calibration list from the time before the Lambda Miner calibration.',
        'calibration list',
        'f',
        NULL
    )
;
INSERT INTO
    feature (
        feature_id,
        name,
        description,
        type,
        active,
        library
    )
VALUES
    (
        '135',
        'SRFA-SOM_neg_152-689',
        'Former SOM_megalist_CS_230802_LDIneg for LDI',
        'calibration list',
        't',
        'small'
    )
;
INSERT INTO
    feature (
        feature_id,
        name,
        description,
        type,
        active,
        library
    )
VALUES
    (
        '137',
        'SRFA-Roland-Hi-Lo-polar-2H_neg_150-978',
        'Former SRFA_neg Roland_extend_H-Lpolar-D',
        'calibration list',
        't',
        'big'
    )
;

-- Restart the sequence at 150 because of the manual feature id inserts
ALTER SEQUENCE feature_feature_id_seq RESTART WITH 150;

-- Update the relevant calibration list descriptions
UPDATE
    feature
SET
    description = 'Calibration list for ESI negative measurements of SFRA with neutral masses between 248 Da and 644 Da containing 188 calibrants.'
WHERE
    name = 'SRFA-Roland_neg_248-644'
;

UPDATE
    feature
SET
    description = 'Calibration list for ESI positive measurements of SFRA with neutral masses between 149 Da and 720 Da containing 249 calibrants.'
WHERE
    name = 'SRFA-Roland-Na_pos_149-720'
;

UPDATE
    feature
SET
    description = 'Calibration list for ESI positive measurements of Sugars and NOM with neutral masses between 158 Da and 666 Da containing 16 calibrants.'
WHERE
    name = 'Sugars-NOM-Na_pos_158-666'
;

UPDATE
    feature
SET
    description = 'Calibration list for ESI negative measurements of fatty acids and sulfonates with neutral masses between 88 Da and 466 Da containing 32 calibrants.'
WHERE
    name = 'FattyAcids-Sulfonates_neg_88-466'
;

UPDATE
    feature
SET
    description = 'Calibration list for ESI negative measurements of SFRA with neutral masses between 150 Da and 998 Da containing 443 calibrants.'
WHERE
    name = 'SRFA-Roland_neg_150-998'
;

UPDATE
    feature
SET
    description = 'Calibration list for ESI negative measurements of SFRA with neutral masses between 150 Da and 720 Da containing 253 calibrants.'
WHERE
    name = 'SRFA-Roland_neg_150-720'
;

UPDATE
    feature
SET
    description = 'Calibration list for ESI negative measurements of SFRA with neutral masses between 150 Da and 978 Da containing 552 calibrants with high and low polarity.'
WHERE
    name = 'SRFA-Roland-Hi-Lo-polar_neg_150-978'
;

UPDATE
    feature
SET
    description = 'Calibration list for ESI negative measurements of SFRA with neutral masses between 160 Da and 568 Da containing 31 calibrants with high polarity.'
WHERE
    name = 'SRFA-Roland-Hi-polar_neg_160-568'
;

UPDATE
    feature
SET
    description = 'Calibration list for ESI negative measurements of SFRA with neutral masses between 150 Da and 978 Da containing 425 calibrants with high polarity.'
WHERE
    name = 'SRFA-Roland-Hi-polar_neg_150-978'
;

UPDATE
    feature
SET
    description = 'Calibration list for ESI positive measurements of fatty acids, sulfonates, and sugars with neutral masses between 88 Da and 666 Da containing 42 calibrants.'
WHERE
    name = 'FattyAcids-Sulfonates-Sugars_pos_88-666'
;

UPDATE
    feature
SET
    description = 'Calibration list for ESI positive measurements of fatty acsids and sulfonates with neutral masses between 88 Da and 466 Da containing  27 calibrants.'
WHERE
    name = 'FattyAcids-Sulfonates_pos_88-466'
;

UPDATE
    feature
SET
    description = 'Calibration list for LDI negative measurements of SFRA and SOM with neutral masses between 152 Da and 689 Da containing 665 calibrants.'
WHERE
    name = 'SRFA-SOM_neg_152-689'
;

UPDATE
    feature
SET
    description = 'Calibration list for ESI negative measurements of SFRA with neutral masses between 150 Da and 978 Da containing 2756 calibrants including deuterium isotopologues.'
WHERE
    name = 'SRFA-Roland-Hi-Lo-polar-2H_neg_150-978'
;

/*
*   Populate the corresponding feature - chemical formula cross table to link formula ids with the
*   new calibration lists
*   Query to get the feature - formula matches:
        \copy (
            SELECT
                feature_id,
                chemical_formula_id
            FROM
                feature_chemical_formula
            WHERE
                feature_id > 73
            ORDER BY
                feature_id
        )
        TO 'feature_chemical_formula.csv'
        CSV DELIMITER ',' HEADER QUOTE '"'
        ;
*/
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '43364000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '45482000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '47674000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '50049000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '52465000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '54702000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '59458000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '62365000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '64832000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '67950000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '70981000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '73969000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '80311000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '84005000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '87473000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '91212000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '94926000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '98953000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '102896000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '106754000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '111526000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '116107000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '120845000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '125551000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '130389000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '135120000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '140920000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '146230000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '152035000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '157992000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '164144000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '170233000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '176489000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '182587000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '189628000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '197256000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '204642000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '211941000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '219811000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '227579000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '236114000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '244372000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '252257000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '261945000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '271334000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '280967000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '290563000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '300379000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '311176000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '321568000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '332710000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '344123000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '355453000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '367524000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '378464000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '392552000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '405677000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '418731000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '432067000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '446287000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '460361000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '475387000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '490516000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '506437000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '522695000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '538830000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '555292000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '572109000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '589682000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '608207000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '608954000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '627943000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '646783000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '666723000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '686473000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '706609000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '726518000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '749636000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '772249000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '795434000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '818382000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '842681000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '867489000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '891153000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '917649000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '944339000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '971697000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '998836000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '1027510000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '1055894000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '1084836000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '1115926000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '1147288000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '1179395000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '1211377000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '1243981000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '1278434000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '1310123000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '1346286000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '1381474000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '1422028000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '1460434000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '1498607000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '1538727000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '1578564000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '1619678000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '1662415000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '1706056000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '1749428000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '1795080000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '1840350000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '1886436000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '1929702000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '1983835000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '2034443000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '2084493000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '2135443000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '2189463000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '2244597000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '2297587000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '2358447000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '2415261000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '2474692000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '2535323000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '2595708000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '2657146000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '2715601000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '2784207000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '2846164000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '2919529000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '2987065000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '3058062000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '3123790000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '3202972000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '3270146000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '3354361000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '3430374000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '3507605000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '3588484000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '3670849000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '3753522000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '3833988000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '3923746000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '4007126000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '4100183000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '4189498000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '4283081000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '4379275000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '4473792000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '4569771000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '4670172000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '4772191000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '4873431000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '4976163000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '5078206000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '5183780000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '5299628000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '5416110000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '5528289000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '5645303000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '5750332000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '5876527000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '5995565000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '6116316000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '6244185000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '6374115000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '6513395000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '6763185000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '6901814000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '7055460000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '7190354000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '7325402000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '7766281000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '7921024000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '8077985000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '8231561000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '8393560000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '8571077000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '8885006000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '9050494000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '9225290000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '9402502000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '9582314000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '10311787000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '10694463000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '10893657000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '11496842000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('78', '11707819000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '3014000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '3447000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '3687000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '3934000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '4465000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '5065000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '5412000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '5776000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '6117000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '6501000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '6917000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '7368000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '7797000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '8245000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '8771000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '9294000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '9860000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '10402000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '11024000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '11622000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '12327000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '13101000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '13748000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '14509000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '15337000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '16205000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '17040000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '17909000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '18930000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '20015000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '21100000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '22071000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '23256000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '24378000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '25671000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '27128000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '28482000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '29733000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '31371000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '32857000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '34370000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '36090000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '37892000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '39758000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '41721000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '43364000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '45482000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '47674000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '50049000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '52465000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '54702000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '59458000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '62365000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '64832000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '67950000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '70981000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '73969000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '80311000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '84005000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '87473000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '91212000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '94926000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '98953000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '102896000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '106754000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '111526000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '116107000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '120845000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '125551000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '130389000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '135120000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '140920000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '146230000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '152035000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '157992000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '164144000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '170233000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '176489000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '182587000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '189628000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '197256000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '204642000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '211941000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '219811000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '227579000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '236114000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '244372000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '252257000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '261945000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '271334000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '280967000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '290563000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '300379000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '311176000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '321568000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '332710000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '344123000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '355453000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '367524000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '378464000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '392552000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '405677000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '418731000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '432067000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '446287000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '460361000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '475387000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '490516000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '506437000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '522695000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '538830000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '555292000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '572109000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '589682000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '608207000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '608954000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '627943000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '646783000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '666723000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '686473000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '706609000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '726518000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '749636000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '772249000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '795434000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '818382000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '842681000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '867489000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '891153000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '917649000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '944339000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '971697000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '998836000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '1027510000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '1055894000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '1084836000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '1115926000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '1147288000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '1179395000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '1211377000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '1243981000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '1278434000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '1310123000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '1346286000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '1381474000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '1422028000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '1460434000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '1498607000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '1538727000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '1578564000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '1619678000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '1662415000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '1706056000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '1749428000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '1795080000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '1840350000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '1886436000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '1929702000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '1983835000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '2034443000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '2084493000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '2135443000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '2189463000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '2244597000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '2297587000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '2358447000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '2415261000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '2474692000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '2535323000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '2595708000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '2657146000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '2715601000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '2784207000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '2846164000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '2919529000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '2987065000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '3058062000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '3123790000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '3202972000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '3270146000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '3354361000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '3430374000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '3507605000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '3588484000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '3670849000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '3753522000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '3833988000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '3923746000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '4007126000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '4100183000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '4189498000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '4283081000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '4379275000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '4473792000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '4569771000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '4670172000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '4772191000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '4873431000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '4976163000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '5078206000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '5183780000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '5299628000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '5416110000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '5528289000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '5645303000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '5750332000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '5876527000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '5995565000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '6116316000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '6244185000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '6374115000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '6513395000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '6763185000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '6901814000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '7055460000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '7190354000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '7325402000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '7766281000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '7921024000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '8077985000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '8231561000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '8393560000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '8571077000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '8885006000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '9050494000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '9225290000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '9402502000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '9582314000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '10311787000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '10694463000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '10893657000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '11496842000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '11707819000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '11921511000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '12137967000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '12357353000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '12579723000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '13023290000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '13255011000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '13489677000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '13720904000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '13962042000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '14206395000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '14694151000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '15724138000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '15991785000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '16526528000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '17653022000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('79', '22032522000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('81', '3687000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('81', '4481000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('81', '5776000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('81', '7347000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('81', '7368000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('81', '7823000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('81', '11024000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('81', '13101000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('81', '27128000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('81', '50049000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('81', '52465000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('81', '54702000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('81', '70981000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('81', '280823000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('81', '2786475000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('81', '14213111000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('82', '228000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('82', '437000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('82', '797000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('82', '1380000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('82', '2301000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('82', '3715000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('82', '5805000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('82', '8844000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('82', '13133000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('82', '19091000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('82', '27208000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('82', '38076000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('82', '52465000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('82', '71185000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('82', '91490000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('82', '125817000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('82', '125964000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('82', '164421000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('82', '164571000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('82', '212513000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('82', '212672000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('82', '271926000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('82', '272087000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('82', '344903000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('82', '433331000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('82', '540130000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('82', '668062000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('82', '820522000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('82', '1001045000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('82', '1213648000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('82', '1462766000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('82', '1753051000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '2796000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '3014000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '3206000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '3447000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '3687000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '3919000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '3934000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '4152000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '4171000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '4465000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '4730000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '5065000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '5412000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '5776000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '6117000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '6501000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '6917000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '7347000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '7368000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '7797000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '8245000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '8771000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '9265000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '9294000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '9860000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '10402000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '11024000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '11622000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '12327000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '13101000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '13748000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '14509000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '15337000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '16205000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '17040000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '17909000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '18930000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '20015000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '20914000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '21100000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '22071000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '23256000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '24378000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '25539000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '25671000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '27128000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '28482000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '29733000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '31371000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '32721000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '32857000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '34370000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '36090000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '37892000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '39758000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '41721000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '43364000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '45482000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '47674000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '50049000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '52465000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '54358000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '54702000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '59458000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '62365000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '64832000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '67950000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '70981000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '73969000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '80311000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '84005000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '87473000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '91212000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '94926000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '98953000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '102602000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '102896000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '106754000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '111526000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '116107000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '120845000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '124956000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '125551000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '130389000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '135120000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '140920000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '146230000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '152035000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '157992000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '163495000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '164144000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '169893000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '170233000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '176489000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '182587000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '189628000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '197256000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '204642000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '211941000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '219811000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '227579000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '236114000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '244372000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '252257000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '261945000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '270330000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '271175000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '271334000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '280967000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '289471000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '290563000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '300379000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '311176000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '321568000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '332710000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '344123000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '355453000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '366374000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '367524000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '378464000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '392552000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '405677000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '418731000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '432067000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '444924000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '446287000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '460361000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '475387000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '490516000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '506437000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '522695000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '538830000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '555292000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '572109000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '589682000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '608207000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '608954000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '627943000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '646783000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '666723000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '684458000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '686473000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '706609000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '725994000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '726518000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '749636000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '772249000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '795434000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '818382000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '839093000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '842681000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '867489000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '891153000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '917649000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '944339000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '971697000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '998836000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '1027510000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '1053293000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '1055894000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '1084836000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '1115926000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '1147288000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '1179395000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '1211377000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '1243981000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '1278434000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '1309328000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '1310123000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '1346286000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '1381474000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '1422028000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '1460434000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '1498607000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '1538727000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '1578564000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '1617408000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '1619678000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '1662415000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '1706056000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '1749428000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '1795080000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '1840350000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '1882147000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '1886436000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '1929702000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '1983835000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '2034443000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '2084493000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '2135443000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '2189463000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '2244597000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '2297587000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '2358447000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '2415261000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '2474692000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '2535323000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '2595708000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '2649489000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '2657146000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '2715601000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '2784207000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '2846164000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '2919529000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '2978249000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '2987065000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '3058062000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '3122428000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '3123790000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '3202972000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '3270146000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '3354361000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '3430374000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '3507605000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '3588484000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '3670849000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '3753522000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '3833988000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '3923746000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '4007126000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '4100183000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '4189498000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '4283081000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '4379275000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '4461658000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '4473792000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '4569771000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '4670172000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '4772191000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '4873431000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '4976163000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '5078206000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '5183780000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '5299628000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '5416110000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '5528289000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '5633510000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '5645303000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '5750332000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '5876527000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '5995565000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '6116316000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '6244185000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '6374115000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '6513395000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '6763185000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '6901814000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '7055460000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '7190354000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '7325402000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '7766281000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '7921024000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '8077985000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '8231561000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '8393560000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '8571077000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '8885006000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '9050494000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '9225290000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '9402502000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '9582314000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '10311787000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '10694463000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '10893657000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '11496842000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '11707819000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '11921511000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '12137967000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '12357353000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '12579723000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '13023290000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '13255011000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '13489677000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '13720904000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '13962042000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '14206395000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '14694151000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '15724138000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '15991785000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '16526528000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '17653022000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '19102910000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '19114120000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '19415267000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '19435560000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '19731265000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '19741569000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '20069218000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '20695132000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '21015517000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '21339185000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '21350734000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '21678664000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '22032522000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '22368939000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '23768244000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '23780107000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '24136119000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '24147539000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '24495728000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '24508051000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '24518909000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '24894173000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '25263671000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '26018697000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '26399547000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '26784183000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '27186534000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '27199184000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '27210295000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '27593130000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '27605192000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '28831083000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '29657903000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '29671324000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '30091624000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '30104567000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '30529667000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '30541991000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '30972029000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '32306356000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '32753812000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '33205280000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '33233273000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '34166256000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '37071198000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '37085751000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '39624693000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '39647613000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '39656073000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '39661848000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '39674458000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '39685372000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '40167305000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '40182666000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '40196381000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '40227227000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '40691470000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '40722743000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '40735803000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '40756729000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '41220027000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '41237561000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '41253469000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '41279985000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '41753112000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '41771679000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '41803919000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '41829163000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '41839353000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '42328259000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '42344605000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '42364790000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '42853254000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '42872287000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '42889724000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '42946498000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '43456098000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '43477119000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '43500971000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '44033922000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '44070365000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '44578468000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '44623566000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '45161148000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '45215108000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '45731604000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '45778130000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '46306678000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '46325122000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '46341774000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '46374656000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '46923621000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '46945780000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '47510074000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '47533878000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '47582140000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '48126581000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '48723966000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '48781348000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '49398989000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '49969896000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '49999545000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '50621510000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '51182445000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '51220479000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '53153029000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '53776212000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '53850182000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '54421541000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '55092672000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '56431577000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '56504040000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '57176623000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '57820869000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '58500770000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '59185654000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '59240125000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '59875548000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '61294022000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '61324440000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '62052626000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '62087505000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '62766690000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '62819980000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '63485811000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '64232101000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '64252437000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '64962637000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '65698286000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '68836972000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '69544777000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '69567206000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '70339259000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '70361136000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '71139676000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '71217901000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '72802132000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '74407380000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '74440245000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '76011527000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '76071948000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '76831305000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '77630150000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '77656477000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '77750426000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '79462781000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '80275129000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '80312425000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '81985089000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '82848210000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '83689973000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '88240760000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '89172539000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '89196548000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '90058144000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '96739624000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '100697175000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '103709673000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '107880886000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '107959240000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '111000091000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('83', '118649196000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '2796000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '3014000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '3206000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '3447000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '3687000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '3934000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '4171000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '4465000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '4730000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '5065000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '5412000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '5776000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '6117000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '6501000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '6917000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '7368000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '7797000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '8245000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '8771000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '9294000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '9860000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '10402000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '11024000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '11622000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '12327000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '13101000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '13748000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '14509000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '15337000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '16205000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '17040000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '17909000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '18930000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '20015000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '21100000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '22071000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '23256000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '24378000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '25671000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '27128000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '28482000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '29733000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '31371000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '32857000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '34370000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '36090000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '37892000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '39758000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '41721000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '43364000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '45482000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '47674000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '50049000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '52465000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '54702000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '59458000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '62365000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '64832000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '67950000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '70981000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '73969000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '80311000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '84005000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '87473000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '91212000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '94926000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '98953000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '102896000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '106754000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '111526000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '116107000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '120845000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '125551000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '130389000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '135120000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '140920000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '146230000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '152035000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '157992000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '164144000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '170233000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '176489000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '182587000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '189628000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '197256000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '204642000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '211941000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '219811000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '227579000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '236114000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '244372000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '252257000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '261945000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '271334000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '280967000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '290563000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '300379000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '311176000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '321568000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '332710000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '344123000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '355453000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '367524000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '378464000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '392552000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '405677000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '418731000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '432067000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '446287000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '460361000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '475387000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '490516000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '506437000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '522695000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '538830000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '555292000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '572109000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '589682000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '608207000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '608954000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '627943000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '646783000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '666723000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '686473000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '706609000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '726518000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '749636000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '772249000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '795434000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '818382000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '842681000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '867489000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '891153000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '917649000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '944339000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '971697000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '998836000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '1027510000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '1055894000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '1084836000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '1115926000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '1147288000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '1179395000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '1211377000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '1243981000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '1278434000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '1310123000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '1346286000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '1381474000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '1422028000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '1460434000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '1498607000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '1538727000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '1578564000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '1619678000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '1662415000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '1706056000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '1749428000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '1795080000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '1840350000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '1886436000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '1929702000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '1983835000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '2034443000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '2084493000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '2135443000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '2189463000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '2244597000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '2297587000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '2358447000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '2415261000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '2474692000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '2535323000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '2595708000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '2657146000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '2715601000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '2784207000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '2846164000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '2919529000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '2987065000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '3058062000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '3123790000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '3202972000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '3270146000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '3354361000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '3430374000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '3507605000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '3588484000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '3670849000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '3753522000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '3833988000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '3923746000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '4007126000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '4100183000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '4189498000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '4283081000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '4379275000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '4473792000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '4569771000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '4670172000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '4772191000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '4873431000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '4976163000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '5078206000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '5183780000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '5299628000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '5416110000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '5528289000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '5645303000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '5750332000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '5876527000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '5995565000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '6116316000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '6244185000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '6374115000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '6513395000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '6763185000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '6901814000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '7055460000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '7190354000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '7325402000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '7766281000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '7921024000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '8077985000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '8231561000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '8393560000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '8571077000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '8885006000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '9050494000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '9225290000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '9402502000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '9582314000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '10311787000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '10694463000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '10893657000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '11496842000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '11707819000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '11921511000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '12137967000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '12357353000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '12579723000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '13023290000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '13255011000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '13489677000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '13720904000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '13962042000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '14206395000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '14694151000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '15724138000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '15991785000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '16526528000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '17653022000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('84', '22032522000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '2796000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '3014000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '3206000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '3447000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '3687000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '3919000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '3934000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '4152000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '4171000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '4465000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '4730000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '5065000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '5412000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '5776000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '6117000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '6501000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '6917000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '7347000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '7368000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '7797000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '8245000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '8771000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '9265000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '9294000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '9860000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '10402000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '11024000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '11622000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '12327000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '13101000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '13748000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '14509000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '15337000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '16205000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '17040000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '17909000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '18930000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '20015000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '20914000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '21100000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '22071000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '23256000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '24378000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '25539000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '25671000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '27128000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '28482000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '29733000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '31371000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '32721000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '32857000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '34370000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '36090000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '37892000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '39758000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '41721000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '43364000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '45482000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '47674000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '50049000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '52465000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '54358000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '54702000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '59458000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '62365000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '64832000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '67950000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '70981000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '73969000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '80311000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '84005000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '87473000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '91212000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '94926000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '98953000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '102602000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '102896000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '106754000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '111526000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '116107000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '120845000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '124956000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '125551000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '130389000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '135120000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '140920000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '146230000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '152035000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '157992000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '163495000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '164144000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '169893000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '170233000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '176489000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '182587000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '189628000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '197256000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '204642000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '211941000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '219811000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '227579000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '236114000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '244372000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '252257000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '261945000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '270330000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '271175000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '271334000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '280967000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '289471000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '290563000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '300379000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '311176000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '321568000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '332710000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '344123000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '355453000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '366374000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '367524000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '378464000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '392552000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '405677000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '418731000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '432067000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '444924000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '446287000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '460361000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '475387000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '490516000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '506437000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '522695000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '538830000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '555292000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '572109000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '589682000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '608207000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '608954000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '627943000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '646783000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '666723000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '684458000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '686473000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '706609000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '725994000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '726518000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '749636000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '772249000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '795434000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '818382000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '839093000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '842681000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '867489000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '891153000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '917649000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '944339000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '971697000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '998836000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '1027510000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '1053293000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '1055894000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '1084836000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '1115926000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '1147288000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '1179395000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '1211377000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '1243981000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '1278434000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '1309328000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '1310123000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '1346286000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '1381474000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '1422028000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '1460434000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '1498607000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '1538727000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '1578564000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '1617408000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '1619678000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '1662415000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '1706056000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '1749428000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '1795080000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '1840350000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '1882147000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '1886436000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '1929702000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '1983835000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '2034443000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '2084493000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '2135443000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '2189463000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '2244597000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '2297587000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '2358447000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '2415261000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '2474692000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '2535323000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '2595708000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '2649489000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '2657146000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '2715601000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '2784207000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '2846164000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '2919529000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '2978249000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '2987065000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '3058062000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '3122428000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '3123790000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '3202972000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '3270146000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '3354361000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '3430374000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '3507605000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '3588484000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '3670849000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '3753522000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '3833988000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '3923746000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '4007126000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '4100183000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '4189498000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '4283081000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '4379275000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '4461658000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '4473792000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '4569771000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '4670172000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '4772191000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '4873431000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '4976163000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '5078206000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '5183780000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '5299628000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '5416110000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '5528289000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '5633510000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '5645303000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '5750332000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '5876527000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '5995565000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '6116316000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '6238857000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '6244185000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '6374115000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '6513395000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '6763185000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '6901814000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '7055460000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '7190354000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '7319327000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '7325402000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '7330773000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '7766281000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '7914747000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '7921024000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '8065213000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '8071985000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '8077985000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '8231561000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '8380163000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '8387218000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '8393560000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '8545016000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '8551913000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '8571077000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '8870491000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '8885006000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '9043085000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '9050494000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '9218193000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '9225290000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '9395690000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '9402502000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '9568342000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '9575724000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '9582314000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '9751203000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '9758403000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '10112739000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '10120770000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '10304030000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '10311787000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '10497927000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '10502356000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '10505337000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '10694463000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '10893657000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '11079871000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '11088176000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '11496842000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '11690750000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '11699733000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '11707819000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '11905117000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '11913820000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '11921511000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '12137967000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '12333395000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '12342341000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '12350338000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '12357353000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '12556576000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '12579723000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '12997296000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '13006860000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '13015576000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '13023290000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '13229985000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '13239371000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '13255011000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '13489677000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '13720904000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '13962042000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '14182504000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '14206395000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '14667204000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '14677181000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '14694151000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '14932297000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '15170795000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '15698540000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '15708225000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '15724138000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '15967219000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '15991785000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '16487436000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '16498705000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '16526528000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '16766962000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '16778023000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '17050031000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '17060860000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '17615499000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '17626691000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '17653022000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '17920134000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '18489365000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '18501123000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '18794274000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '18805760000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '19102910000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '19109541000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '19114120000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '19415267000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '19435560000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '19719665000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '19731265000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '19741569000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '20039684000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '20069218000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '20684111000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '20695132000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '20990725000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '21003652000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '21015517000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '21339185000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '21346023000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '21350734000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '21678664000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '22009957000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '22021937000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '22032522000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '22357476000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '22368939000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '23030858000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '23044628000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '23390972000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '23768244000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '23780107000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '24136119000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '24147539000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '24482093000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '24495728000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '24508051000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '24518909000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '24858887000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '24894173000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '25263671000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '25602608000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '25616896000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '25992299000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '26006162000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '26018697000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '26394055000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '26399547000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '26784183000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '27172488000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '27186534000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '27199184000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '27210295000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '27579545000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '27593130000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '27605192000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '28367598000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '28383554000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '28788417000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '28803990000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '28831083000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '29236959000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '29657903000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '29671324000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '30061549000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '30077203000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '30091624000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '30104567000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '30515734000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '30529667000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '30541991000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '30972029000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '31366137000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '31382665000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '32285853000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '32306356000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '32753812000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '33189176000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '33205280000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '33233273000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '33660947000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '33676687000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '34166256000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '34592149000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '34609197000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '35060739000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '36531478000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '36549338000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '37055088000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '37071198000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '37085751000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '38035503000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '38054247000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '38071770000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '38556894000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '38575305000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '39624693000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '39647613000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '39656073000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '39661848000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '39674458000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '39685372000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '40132032000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '40150410000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '40167305000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '40182666000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '40196381000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '40227227000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '40673530000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '40691470000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '40722743000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '40735803000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '40756729000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '41220027000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '41237561000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '41253469000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '41279985000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '41721410000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '41741747000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '41753112000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '41761048000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '41771679000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '41803919000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '41829163000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '41839353000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '42328259000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '42344605000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '42364790000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '42853254000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '42872287000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '42889724000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '42946498000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '43456098000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '43477119000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '43500971000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '43982236000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '44033922000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '44070365000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '44560123000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '44578468000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '44623566000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '45161148000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '45215108000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '45700934000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '45731604000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '45778130000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '46306678000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '46325122000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '46341774000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '46374656000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '46923621000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '46945780000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '47510074000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '47533878000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '47582140000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '48089766000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '48126581000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '48684962000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '48723966000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '48781348000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '49398989000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '49969896000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '49999545000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '50544483000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '50564946000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '50621510000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '51182445000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '51220479000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '53095936000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '53153029000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '53776212000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '53850182000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '54421541000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '55092672000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '56431577000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '56504040000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '57085926000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '57176623000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '57780347000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '57820869000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '58500770000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '59163941000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '59185654000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '59240125000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '59875548000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '61294022000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '61324440000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '62052626000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '62087505000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '62721859000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '62766690000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '62819980000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '63485811000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '64186248000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '64232101000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '64252437000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '64962637000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '65698286000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '67973144000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '68836972000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '69544777000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '69567206000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '70339259000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '70361136000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '71139676000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '71217901000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '72802132000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '76011527000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '76831305000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '81985089000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '88240760000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '89172539000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '100697175000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('85', '107880886000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('86', '3919000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('86', '4152000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('86', '7347000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('86', '9265000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('86', '20914000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('86', '22071000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('86', '25539000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('86', '32721000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('86', '54358000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('86', '61981000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('86', '102602000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('86', '124956000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('86', '163495000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('86', '169893000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('86', '270330000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('86', '271175000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('86', '289471000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('86', '366374000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('86', '444924000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('86', '684458000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('86', '725994000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('86', '839093000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('86', '1053293000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('86', '1309328000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('86', '1617408000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('86', '1882147000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('86', '2649489000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('86', '2978249000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('86', '3122428000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('86', '4461658000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('86', '5633510000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '2796000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '3014000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '3206000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '3447000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '3687000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '3919000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '3934000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '4152000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '4171000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '4465000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '4730000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '5065000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '5412000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '5776000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '6117000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '6501000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '6917000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '7347000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '7368000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '7797000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '8245000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '8771000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '9265000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '9294000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '9860000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '10402000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '11024000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '11622000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '12327000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '13101000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '13748000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '14509000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '15337000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '16205000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '17040000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '17909000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '18930000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '20015000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '20914000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '21100000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '22071000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '23256000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '24378000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '25539000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '25671000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '27128000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '28482000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '29733000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '31371000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '32721000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '32857000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '34370000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '36090000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '37892000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '39758000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '41721000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '43364000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '45482000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '47674000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '50049000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '52465000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '54358000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '54702000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '59458000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '62365000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '64832000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '67950000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '70981000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '73969000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '80311000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '84005000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '87473000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '91212000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '94926000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '98953000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '102602000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '102896000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '106754000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '111526000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '116107000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '120845000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '124956000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '125551000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '130389000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '135120000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '140920000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '146230000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '152035000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '157992000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '163495000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '164144000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '169893000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '170233000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '176489000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '182587000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '189628000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '197256000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '204642000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '211941000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '219811000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '227579000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '236114000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '244372000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '252257000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '261945000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '270330000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '271175000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '271334000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '280967000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '289471000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '290563000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '300379000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '311176000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '321568000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '332710000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '344123000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '355453000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '366374000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '367524000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '378464000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '392552000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '405677000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '418731000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '432067000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '444924000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '446287000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '460361000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '475387000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '490516000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '506437000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '522695000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '538830000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '555292000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '572109000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '589682000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '608207000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '608954000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '627943000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '646783000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '666723000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '684458000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '686473000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '706609000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '725994000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '726518000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '749636000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '772249000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '795434000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '818382000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '839093000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '842681000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '867489000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '891153000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '917649000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '944339000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '971697000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '998836000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '1027510000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '1053293000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '1055894000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '1084836000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '1115926000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '1147288000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '1179395000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '1211377000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '1243981000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '1278434000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '1309328000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '1310123000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '1346286000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '1381474000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '1422028000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '1460434000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '1498607000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '1538727000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '1578564000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '1617408000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '1619678000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '1662415000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '1706056000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '1749428000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '1795080000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '1840350000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '1882147000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '1886436000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '1929702000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '1983835000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '2034443000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '2084493000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '2135443000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '2189463000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '2244597000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '2297587000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '2358447000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '2415261000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '2474692000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '2535323000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '2595708000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '2649489000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '2657146000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '2715601000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '2784207000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '2846164000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '2919529000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '2978249000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '2987065000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '3058062000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '3122428000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '3123790000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '3202972000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '3270146000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '3354361000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '3430374000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '3507605000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '3588484000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '3670849000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '3753522000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '3833988000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '3923746000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '4007126000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '4100183000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '4189498000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '4283081000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '4379275000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '4461658000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '4473792000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '4569771000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '4670172000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '4772191000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '4873431000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '4976163000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '5078206000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '5183780000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '5299628000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '5416110000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '5528289000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '5633510000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '5645303000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '5750332000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '5876527000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '5995565000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '6116316000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '6244185000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '6374115000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '6513395000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '6763185000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '6901814000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '7055460000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '7190354000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '7325402000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '7766281000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '7921024000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '8077985000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '8231561000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '8393560000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '8571077000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '8885006000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '9050494000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '9225290000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '9402502000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '9582314000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '10311787000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '10694463000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '10893657000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '11496842000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '11707819000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '11921511000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '12137967000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '12357353000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '12579723000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '13023290000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '13255011000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '13489677000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '13720904000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '13962042000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '14206395000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '14694151000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '15724138000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '15991785000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '16526528000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '17653022000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '19102910000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '19114120000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '19415267000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '19435560000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '19731265000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '19741569000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '20069218000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '20695132000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '21015517000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '21339185000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '21350734000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '21678664000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '22032522000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '22368939000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '23768244000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '23780107000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '24136119000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '24147539000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '24495728000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '24508051000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '24518909000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '24894173000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '25263671000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '26018697000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '26399547000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '26784183000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '27186534000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '27199184000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '27210295000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '27593130000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '27605192000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '28831083000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '29657903000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '29671324000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '30091624000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '30104567000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '30529667000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '30541991000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '30972029000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '32306356000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '32753812000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '33205280000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '33233273000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '34166256000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '37071198000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '37085751000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '39624693000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '39647613000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '39656073000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '39661848000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '39674458000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '39685372000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '40167305000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '40182666000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '40196381000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '40227227000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '40691470000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '40722743000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '40735803000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '40756729000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '41220027000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '41237561000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '41253469000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '41279985000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '41753112000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '41771679000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '41803919000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '41829163000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '41839353000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '42328259000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '42344605000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '42364790000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '42853254000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '42872287000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '42889724000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '42946498000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '43456098000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '43477119000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '43500971000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '44033922000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '44070365000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '44578468000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '44623566000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '45161148000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '45215108000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '45731604000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '45778130000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '46306678000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '46325122000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '46341774000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '46374656000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '46923621000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '46945780000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '47510074000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '47533878000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '47582140000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '48126581000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '48723966000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '48781348000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '49398989000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '49969896000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '49999545000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '50621510000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '51182445000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '51220479000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '53153029000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '53776212000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '53850182000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '54421541000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '55092672000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '56431577000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '56504040000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '57176623000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '57820869000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '58500770000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '59185654000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '59240125000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '59875548000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '61294022000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '61324440000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '62052626000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '62087505000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '62766690000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '62819980000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '63485811000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '64232101000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '64252437000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '64962637000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '65698286000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '68836972000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '69544777000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '69567206000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '70339259000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '70361136000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '71139676000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '71217901000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '72802132000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '76011527000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '76831305000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '81985089000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '88240760000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '89172539000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '100697175000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('87', '107880886000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('88', '228000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('88', '437000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('88', '797000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('88', '1380000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('88', '2301000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('88', '3687000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('88', '3715000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('88', '4481000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('88', '5776000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('88', '5805000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('88', '7347000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('88', '7368000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('88', '7823000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('88', '8844000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('88', '11024000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('88', '13101000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('88', '13133000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('88', '19091000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('88', '27128000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('88', '27208000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('88', '38076000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('88', '50049000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('88', '52465000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('88', '54702000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('88', '68214000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('88', '70981000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('88', '91490000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('88', '125817000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('88', '125964000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('88', '164421000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('88', '212513000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('88', '212672000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('88', '271926000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('88', '280823000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('88', '344903000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('88', '540130000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('88', '820522000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('88', '1001045000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('88', '1213648000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('88', '1753051000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('88', '2786475000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('88', '14213111000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('89', '228000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('89', '437000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('89', '797000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('89', '1380000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('89', '2301000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('89', '3715000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('89', '5805000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('89', '8844000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('89', '13133000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('89', '19091000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('89', '27208000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('89', '38076000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('89', '52465000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('89', '68214000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('89', '91490000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('89', '125817000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('89', '125964000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('89', '164421000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('89', '212513000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('89', '212672000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('89', '271926000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('89', '344903000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('89', '540130000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('89', '820522000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('89', '1001045000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('89', '1213648000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('89', '1753051000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '2978000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '3014000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '3102000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '3206000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '3223000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '3447000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '3458000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '3656000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '3672000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '3782000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '3898000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '3934000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '4045000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '4171000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '4201000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '4297000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '4324000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '4421000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '4465000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '4593000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '4605000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '4730000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '4775000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '4878000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '4895000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '5065000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '5085000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '5225000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '5370000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '5394000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '5547000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '5574000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '5714000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '5761000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '5910000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '6092000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '6136000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '6261000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '6296000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '6443000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '6501000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '6670000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '6867000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '6917000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '7057000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '7100000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '7260000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '7320000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '7513000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '7534000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '7734000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '7797000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '7959000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '8022000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '8207000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '8274000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '8488000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '8739000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '8793000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '8980000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '9026000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '9225000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '9294000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '9471000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '9534000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '9796000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '9860000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '10058000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '10115000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '10328000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '10402000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '10667000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '10689000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '10954000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '11024000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '11278000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '11327000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '11622000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '11655000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '11920000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '11952000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '12278000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '12357000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '12604000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '12667000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '12926000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '13021000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '13343000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '13393000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '13701000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '13780000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '14055000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '14123000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '14416000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '14509000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '14780000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '14861000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '15250000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '15337000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '15629000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '15704000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '16131000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '16205000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '16515000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '16548000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '16984000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '17075000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '17401000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '17478000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '17841000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '17954000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '18283000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '18382000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '18862000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '18971000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '19325000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '19417000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '19802000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '19928000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '20015000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '20392000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '20427000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '20914000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '21023000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '21062000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '21424000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '21515000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '22071000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '22119000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '22588000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '22631000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '23133000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '23294000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '23792000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '23826000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '24427000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '24490000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '24991000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '25080000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '25595000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '25720000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '25818000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '26199000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '26307000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '26809000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '26960000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '27578000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '27682000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '28243000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '28388000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '28482000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '28904000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '29025000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '29564000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '29733000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '29854000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '30397000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '30447000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '31112000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '31264000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '31889000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '32006000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '32721000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '32784000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '33500000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '33598000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '34281000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '34370000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '34423000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '35043000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '35165000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '36004000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '36143000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '36787000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '36909000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '37640000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '37807000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '37941000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '38473000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '38621000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '39533000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '39692000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '40384000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '40450000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '41309000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '41505000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '41571000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '42388000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '42447000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '43364000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '43446000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '44350000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '44481000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '45370000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '45554000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '46501000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '46611000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '47574000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '47733000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '48566000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '48701000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '49637000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '49828000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '49980000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '50696000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '50857000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '51993000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '52180000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '53082000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '53245000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '54220000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '54452000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '54630000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '55580000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '55653000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '56788000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '57009000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '58055000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '58222000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '59458000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '59544000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '60669000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '60748000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '62083000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '62282000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '63325000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '63502000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '64683000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '64923000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '65087000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '66007000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '66213000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '67364000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '67642000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '67853000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '68990000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '69173000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '70421000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '70682000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '70885000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '72073000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '72156000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '73295000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '73585000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '73845000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '75048000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '75274000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '76589000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '76886000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '78395000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '78492000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '80155000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '80409000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '81713000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '81932000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '83407000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '83699000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '85056000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '85313000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '87094000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '87359000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '88763000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '88997000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '90566000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '90887000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '91111000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '92339000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '92612000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '94151000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '94501000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '94790000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '96306000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '96559000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '98540000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '98667000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '98820000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '100402000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '100514000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '102546000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '102731000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '104479000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '104751000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '106754000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '106899000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '108893000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '109137000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '111055000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '111385000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '113132000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '113415000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '115321000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '115704000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '117847000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '118103000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '120150000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '120499000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '120741000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '122363000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '122678000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '124709000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '125105000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '125409000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '127389000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '127519000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '129843000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '130208000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '130502000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '132361000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '132667000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '135280000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '135476000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '137701000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '138005000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '140345000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '140741000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '142864000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '143218000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '145538000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '146009000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '148604000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '148923000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '151411000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '151843000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '152148000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '154113000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '154488000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '157444000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '157827000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '160230000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '160381000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '163219000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '163662000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '166501000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '166640000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '169132000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '169645000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '169825000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '170039000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '172777000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '173105000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '176251000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '176423000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '179050000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '179445000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '182800000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '183226000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '185951000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '186341000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '189321000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '189835000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '192596000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '193055000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '196593000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '197054000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '199954000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '200372000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '203533000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '204067000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '204469000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '207498000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '207665000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '211248000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '211724000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '215035000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '215274000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '219189000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '219613000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '222575000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '223035000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '227049000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '227328000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '227510000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '230846000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '231275000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '234890000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '235452000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '238817000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '239332000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '243565000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '244115000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '247592000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '248099000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '251880000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '252509000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '256621000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '256825000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '261110000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '261681000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '265389000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '265911000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '270594000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '271104000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '274964000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '275174000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '280311000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '280760000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '284505000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '284999000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '289999000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '290305000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '294049000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '294630000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '299688000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '300291000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '304500000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '305054000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '309606000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '310310000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '315232000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '315771000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '320552000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '321238000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '325665000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '326287000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '331021000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '331812000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '337032000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '337282000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '342614000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '343338000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '348321000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '348915000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '354502000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '355158000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '359611000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '360304000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '366245000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '366931000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '371959000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '372595000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '377985000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '378776000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '384622000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '385215000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '390894000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '391646000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '396950000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '397643000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '403273000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '404149000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '410333000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '410630000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '416917000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '417775000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '424098000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '424368000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '430930000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '431711000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '437776000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '444772000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '445273000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '451499000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '452244000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '459525000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '460600000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '466392000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '467067000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '473771000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '474621000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '480882000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '481662000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '489326000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '490120000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '496595000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '497337000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '504354000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '505298000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '512250000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '512741000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '520770000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '521691000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '528815000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '529289000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '537022000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '537618000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '544926000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '545807000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '554300000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '554838000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '562369000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '570967000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '571962000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '579302000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '580215000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '589126000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '590029000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '597647000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '606649000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '607700000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '615449000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '616422000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '616767000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '625746000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '634746000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '635155000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '644209000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '646328000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '653949000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '654952000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '664820000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '665452000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '674247000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '675196000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '684250000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '685428000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '693977000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '695048000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '705391000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '706454000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '715310000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '725775000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '726999000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '736415000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '737120000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '747968000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '749094000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '758410000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '769395000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '770667000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '781696000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '781770000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '792706000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '793929000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '804196000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '816622000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '817141000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '828335000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '840334000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '841585000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '851842000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '863975000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '865405000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '876322000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '877141000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '889662000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '890967000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '901764000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '915897000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '917087000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '927390000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '928655000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '941333000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '942693000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '954530000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '954623000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '968831000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '970123000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '982363000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '996144000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '996985000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '1009484000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '1023445000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '1025035000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '1037707000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '1053029000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '1054546000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '1066993000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '1067517000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '1083270000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '1084642000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '1097492000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '1097972000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '1112528000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '1114095000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '1127698000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '1144133000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '1145576000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '1159538000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '1159638000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '1176411000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '1177766000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '1208553000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '1209438000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '1223148000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '1224159000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '1240707000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '1242392000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '1275412000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '1277015000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '1291769000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '1292329000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '1309019000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '1310832000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '1345275000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '1346929000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '1362955000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '1382216000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '1383730000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '1418174000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '1419914000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '1436820000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '1456772000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '1457500000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '1495175000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '1496945000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '1513919000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '1533552000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '1535561000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '1574915000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '1576833000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '1617104000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '1618847000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '1637640000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '1660074000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '1661654000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '1702029000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '1703860000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '1745696000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '1746848000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '1789331000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '1791510000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '1813845000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '1836230000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '1838342000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '1884138000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '1886150000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '1933050000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '1934881000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '1980733000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '1982827000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '2030285000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '2031594000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '2055215000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '2083410000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '2135113000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '2186936000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '2189138000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '2239675000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '2296140000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '2298539000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '2410923000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '2468081000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '2471911000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '2529069000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '2652002000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '2716787000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '2781237000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '2782811000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '3125071000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '3127822000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '3197332000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '3201703000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '3269589000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '3271534000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '3343002000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '3346610000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '3348451000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '3381215000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '3417648000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '3421577000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '3471275000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '3550824000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '3582671000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '3661946000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '3668145000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '3744147000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '3830078000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '3832120000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '3917619000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '4003038000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '4058283000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '4272102000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '6115463000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '11328209000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('135', '17223262000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2796000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3014000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3206000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3447000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3687000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3919000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3934000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4152000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4171000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4465000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4730000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5065000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5412000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5776000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6117000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6501000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6917000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7347000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7368000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7797000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '8245000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '8771000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '9265000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '9294000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '9860000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '10402000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '11024000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '11622000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '12327000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '13101000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '13748000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '14509000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '15337000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '16205000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '17040000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '17909000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '18930000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '20015000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '20914000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '21100000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '22071000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '23256000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '24378000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '25539000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '25671000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '27128000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '28482000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '29733000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '31371000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '32721000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '32857000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '34370000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '36090000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '37892000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '39758000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '41721000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '43364000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '45482000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '47674000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '50049000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '52465000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '54358000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '54702000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '59458000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '62365000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '64832000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '67950000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '70981000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '73969000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '80311000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '80409031');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '84005000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '87473000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '91212000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '94926000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '98953000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '102602000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '102896000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '106754000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '107174032');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '111526000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '116107000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '120845000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '124956000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '125551000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '125825043');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '130341033');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '130389000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '135120000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '140920000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '141032033');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '146230000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '146362032');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '146362050');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '152035000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '152148032');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '157992000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '158264033');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '163495000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '163816034');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '164144000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '169893000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '170181034');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '170233000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '176423033');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '176489000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '176693059');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '182587000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '183226051');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '183540034');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '189628000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '190215051');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '197054032');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '197256000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '204469032');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '204642000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '204924034');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '211883035');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '211941000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '219758035');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '219811000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '227510034');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '227579000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '235452033');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '235907034');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '235907052');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '236114000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '244115033');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '244372000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '244523034');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '252257000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '253002033');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '261945000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '262586035');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '270330000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '271175000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '271334000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '280514035');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '280967000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '289471000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '290492035');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '290563000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '290793061');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '300291034');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '300291052');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '300379000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '300772035');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '310901034');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '310901046');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '311176000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '321568000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '321769034');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '321769052');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '332710000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '344123000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '354796035');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '355373036');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '355373054');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '355453000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '366374000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '366931035');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '366931053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '367332061');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '367524000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '378464000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '379409053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '391646034');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '392264035');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '392552000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '404883034');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '404883052');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '405439053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '405677000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '418075037');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '418437034');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '418731000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '431276036');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '432067000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '444924000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '445586036');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '446204037');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '446287000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '460361000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '460684062');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '474621035');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '475289036');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '475289054');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '475387000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '490516000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '506070053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '506437000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '521176037');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '522005038');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '522389035');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '522695000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '537995037');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '538830000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '555168037');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '555292000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '572109000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '572741037');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '573181063');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '589682000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '590029036');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '590731055');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '607700035');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '608207000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '608535036');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '608954000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '609217037');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '626747035');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '627556036');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '627943000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '646328035');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '646783000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '647059036');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '666723000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '684458000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '685428037');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '686344038');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '686344056');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '686473000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '705874076');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '706454037');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '706609000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '707271056');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '725994000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '726518000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '727962037');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '727962055');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '728695038');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '749094036');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '749636000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '749976037');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '749976055');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '771723036');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '772249000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '772576037');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '772576055');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '794383039');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '794794043');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '794950036');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '795434000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '817141056');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '818227039');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '818382000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '839093000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '841585038');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '841585056');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '842547039');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '842547057');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '842681000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '842868043');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '865405037');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '865914077');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '866526038');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '867374039');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '867489000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '890967037');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '891153000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '891973038');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '917087037');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '917087055');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '917649000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '918002038');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '918002056');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '943797037');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '943797055');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '944339000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '968592060');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '970123036');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '971034044');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '971192037');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '971697000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '997532039');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '998836000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '999065044');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1025035038');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1027510000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1027704044');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1053293000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1054546038');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1054546056');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1054546074');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1055561046');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1055727039');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1055894000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1083270037');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1084642038');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1084836000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1085542046');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1085693039');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1115341038');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1115926000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1144783040');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1145576037');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1145576055');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1146092041');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1146726038');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1146726056');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1147288000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1177766037');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1178708045');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1178872038');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1179395000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1208553039');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1210017040');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1210549044');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1211377000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1211614045');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1242392039');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1242392057');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1243780040');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1243981000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1244263044');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1274339059');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1275412038');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1275692031');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1277015039');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1277015057');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1278085047');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1278260040');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1278434000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1308168033');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1309328000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1310123000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1310832038');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1312072046');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1313221047');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1346286000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1346929056');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1381474000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1381931080');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1382216037');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1383507045');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1384750046');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1384926039');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1384926057');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1422028000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1422308046');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1456469061');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1457500058');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1457500076');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1460434000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1495945079');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1496945040');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1496945076');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1498607000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1498900063');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1500272061');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1532621034');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1533885031');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1535561039');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1537243058');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1538727000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1576833039');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1576833057');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1578355040');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1578564000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1617104038');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1617408000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1618847039');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1619678000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1620009047');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1620206040');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1620206058');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1657141069');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1657735080');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1658440066');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1659292070');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1659774081');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1660074038');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1661422046');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1661654075');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1662415000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1662719047');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1701692080');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1702348066');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1702849077');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1704113067');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1706056000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1744394061');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1744394079');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1746223069');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1746223087');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1746533062');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1746533080');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1747146048');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1747146066');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1747611059');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1747611077');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1748571056');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1748571074');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1748812049');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1749428000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1749775064');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1752873055');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1787216031');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1787890060');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1789694032');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1789694050');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1789694068');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1789922068');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1790275061');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1790275079');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1791510058');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1791822051');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1792012069');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1792313080');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1793351041');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1793351059');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1793618052');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1794020045');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1795080000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1795388046');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1813591052');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1834188049');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1834839060');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1834839078');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1835237035');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1836584068');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1836803050');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1836803068');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1836803086');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1837149079');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1838342040');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1838342058');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1838342076');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1838829069');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1840097041');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1840097059');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1840097077');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1840350000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1861794049');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1863154050');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1880659052');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1881335063');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1882147000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1882147049');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1882394067');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1882785078');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1883174053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1884486050');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1884486068');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1884694068');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1884694086');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1885860047');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1886150058');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1886150076');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1886436000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1886436051');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1887511048');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1887511066');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1887738041');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1887738059');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1929702000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1930363063');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1930363081');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1931157031');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1931157049');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1931392067');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1931392085');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1932712082');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1933050039');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1933050057');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1933050075');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1933373050');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1933560068');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1933560086');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1934617047');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1934881076');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1935134051');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1936086048');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1936290041');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1977032033');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1977758062');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1979723034');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1979723052');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1979723070');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1979966052');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1979966070');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1980352063');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1980352081');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1980733038');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1981098049');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1981098067');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1981316067');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1981316085');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1981667042');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1982003053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1982003071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1982827057');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1982827075');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1983119050');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1983119068');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1983835000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1984240047');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1984240065');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1984482040');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1984482058');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1984482076');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '1985583066');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2027692040');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2028131033');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2028131051');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2028131069');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2028822062');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2028822080');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2029656048');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2030285041');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2030663034');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2030663070');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2030886070');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2030886088');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2031239081');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2031594038');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2031926049');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2032129085');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2032449042');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2032449060');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2032449078');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2032758053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2033228046');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2033514057');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2033514075');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2033783068');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2034443000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2034821047');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2034821065');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2035048040');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2057813051');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2077390032');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2078147061');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2080174033');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2080174051');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2080174069');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2080429051');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2080429069');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2080822062');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2080822080');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2082194041');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2082194059');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2082543070');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2082750070');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2082750088');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2083078063');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2083078081');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2084207042');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2084207060');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2084207078');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2084493000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2084937046');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2084937064');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2085210057');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2086457047');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2086457065');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2089000068');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2131297061');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2132828040');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2133213033');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2133213069');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2133453051');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2133453069');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2133453087');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2133823080');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2134773048');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2135113041');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2135113059');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2135113077');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2135443000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2135443052');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2135443070');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2135639070');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2136272056');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2136754049');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2137040042');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2137040060');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2137040078');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2137744046');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2161686050');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2162383054');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2163251051');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2183152053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2184784032');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2184784050');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2185052068');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2185471061');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2185471079');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2186936058');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2187307069');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2187536069');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2187536087');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2187896080');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2188812048');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2189138059');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2189138077');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2189463000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2189463070');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2189648070');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2190712049');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2190974042');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2190974060');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2191621046');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2213136052');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2238051078');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2238515053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2239236064');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2240097032');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2240097050');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2240357068');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2240357086');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2240769079');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2241174036');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2242187058');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2242187076');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2242769069');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2243990048');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2244291059');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2244291077');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2244597000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2245044045');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2245719049');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2245719067');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2270751053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2292071052');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2292856063');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2293806049');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2294552078');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2295008035');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2295008053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2295279053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2295279071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2295714082');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2296140039');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2296552050');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2296801050');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2296801068');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2296801086');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2297200079');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2297587000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2297587054');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2298539058');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2298539076');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2298877051');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2299072087');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2300005048');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2300005066');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2300178048');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2300178066');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2300453041');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2300453059');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2301709049');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2349299059');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2349796070');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2350570063');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2350570081');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2351506067');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2352224042');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2352224060');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2352658071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2352917053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2352917071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2352917089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2353080064');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2353324082');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2353727039');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2353727057');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2354112050');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2354340068');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2354340086');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2355057054');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2355057072');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2355599047');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2355920058');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2355920076');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2356224051');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2356224069');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2357234066');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2357386048');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2357386066');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2357634041');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2357634059');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2358447000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2383459052');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2385009053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2405506033');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2406351062');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2408919052');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2409372063');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2409372081');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2410254049');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2410923042');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2410923060');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2411559071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2411929082');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2412298057');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2412649050');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2412649068');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2412860086');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2413193043');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2413193061');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2414004047');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2414300058');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2414300076');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2415261000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2415652048');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2415885041');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2465559033');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2465559069');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2466371062');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2466371080');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2468081041');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2468522034');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2468522070');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2468784052');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2468784070');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2469203081');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2470020049');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2470638042');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2470638078');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2471007053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2471228071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2471569046');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2471911057');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2472239050');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2472239068');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2472743043');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2472743061');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2473501047');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2473501065');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2473782058');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2473782076');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2474692000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2475065048');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2524335061');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2526690051');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2526986051');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2526986069');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2527457062');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2527457080');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2529069041');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2529069059');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2529479052');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2529726070');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2529726088');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2530117081');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2531468060');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2531468078');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2531813053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2532674057');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2533469043');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2533469061');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2534198047');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2534198065');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2535323000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2558594053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2585893032');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2585893050');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2586725061');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2586725079');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2587234054');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2588968033');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2588968051');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2588968069');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2589248051');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2589248069');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2589248087');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2589692080');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2591222041');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2591222059');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2591222077');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2591615052');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2591850070');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2591850088');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2592966049');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2593183049');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2593528042');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2593528060');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2593528078');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2593867053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2593867071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2594380046');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2595708000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2596106047');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2597926063');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2624383051');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2647595053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2648453064');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2649489000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2649797050');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2649797068');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2650290079');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2650782072');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2651545083');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2652002040');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2652449051');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2652449069');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2652719069');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2652719087');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2653153080');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2654629059');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2654629077');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2655014052');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2655014070');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2655237070');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2655237088');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2656309049');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2656513049');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2656830042');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2656830060');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2657146000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2657614046');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2682781052');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2713332064');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2713332082');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2714341050');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2714341068');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2714638068');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2714638086');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2715123079');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2715601000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2715601036');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2715601054');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2715601072');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2715887071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2715887089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2716787058');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2717223051');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2717481069');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2718930048');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2719298059');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2719298077');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2719658052');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2719658070');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2720832049');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2720832067');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2721010049');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2721010067');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2721298042');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2721298060');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2775257034');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2775257052');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2778675035');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2778675053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2778989053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2778989071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2779496064');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2779496082');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2780484068');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2780770068');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2780770086');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2781237043');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2781237061');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2781693054');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2781693072');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2781966071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2782811058');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2782811076');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2783218051');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2783218069');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2783453069');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2783453087');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2783840044');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2784207000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2784770048');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2784770066');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2785107059');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2785107077');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2785428052');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2785428070');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2786633049');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2786633067');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2804586027');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2842251059');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2843731063');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2843731081');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2845661042');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2846164000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2846164035');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2846164053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2846164071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2846463053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2846463071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2846463089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2847408039');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2847868050');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2847868068');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2848567043');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2848567061');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2848984054');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2849234089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2849625047');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2850006058');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2850376051');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2850376069');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2851783048');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2852089059');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2852089077');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2853489049');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2853489067');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2872655027');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2882316052');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2884193053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2909017062');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2911661034');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2911661052');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2911991052');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2911991070');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2912525063');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2913853049');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2914343042');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2914343060');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2914812053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2914812071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2915090071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2915090089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2916386050');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2916386068');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2917030061');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2917030079');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2917415036');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2917415054');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2917415072');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2918005047');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2918358040');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2918358058');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2918358076');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2918702051');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2919221062');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2919529000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2920008048');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2920008066');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2942052027');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2978249000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2978249033');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2979183062');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2979183080');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2980312066');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2981691034');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2981691052');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2981691070');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2981998052');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2981998070');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2981998088');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2982496063');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2984196042');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2984196060');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2984630053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2984891071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2984891089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2986104050');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2986104068');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2986333050');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2986706043');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2986706061');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2986706079');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2987065000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2987065054');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2987065072');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2987622047');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2987622065');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2987958058');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '2989530048');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3019331051');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3020231055');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3021072059');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3021377052');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3048539065');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3049690051');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3049690069');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3050030069');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3050577062');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3050577080');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3051118055');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3052953052');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3052953070');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3053245052');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3053245070');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3053245088');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3055320060');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3055730035');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3055730053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3055730071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3055977071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3055977089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3057131050');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3057353050');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3057353068');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3057710061');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3057710079');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3058062000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3058062036');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3058062054');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3058596047');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3084707027');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3119818079');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3120407036');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3120407054');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3121329065');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3121329083');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3122428000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3122428033');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3122428051');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3122428069');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3122752051');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3122752069');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3122752087');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3123790000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3123790055');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3124095053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3124591084');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3125071041');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3125071059');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3125543052');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3125543070');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3125822070');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3125822088');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3127408049');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3127822060');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3127822078');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3128224035');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3128224053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3128458089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3129568050');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3129776050');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3130107043');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3130922047');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3157959027');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3162759054');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3164021051');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3164827055');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3165555059');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3190861035');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3190861053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3191853064');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3193051032');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3193051050');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3193988079');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3194560036');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3194560054');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3194560072');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3196510069');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3196823069');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3196823087');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3197836037');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3197836055');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3197836073');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3198135089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3199076059');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3199076077');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3199536034');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3199536052');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3199536070');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3199802070');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3201077031');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3201317049');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3201317067');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3201703060');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3202077053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3202077071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3202972000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3203297050');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3203481050');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3203481068');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3266528071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3267502064');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3267502082');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3268676068');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3269589043');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3270146000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3270146036');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3270146054');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3270146072');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3270478053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3270478071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3270478089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3270688047');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3272049051');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3272049069');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3272350069');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3272350087');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3272842044');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3273322037');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3273322055');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3273610089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3274494059');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3274494077');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3274925052');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3274925070');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3276541049');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3276541067');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3276893060');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3276893078');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3278306050');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3278465050');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3300142027');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3308753027');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3310847053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3312988054');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3339673034');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3340721063');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3343616035');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3343616053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3343977053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3343977071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3344573064');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3345725050');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3345725068');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3346610043');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3347141054');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3347458071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3347458089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3347962083');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3348932051');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3348932069');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3349666044');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3349666062');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3350107055');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3350107073');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3350367071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3350773048');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3351172059');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3351560052');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3351560070');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3353017049');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3353017067');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3354361000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3377834027');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3418313034');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3418313052');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3418313070');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3418734085');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3419348063');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3419348081');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3421577042');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3422164035');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3422164053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3422164071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3422511053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3422511071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3422511089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3423074064');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3424155050');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3424979043');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3424979061');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3425469036');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3425469054');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3425764071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3425764089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3426679058');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3427117051');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3427117069');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3427785062');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3428186037');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3428186073');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3428798048');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3428798066');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3429164041');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3429164059');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3429164077');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3430374000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3430866049');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3430866067');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3453187027');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3464425052');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3465433056');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3466344060');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3466679053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3498349052');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3498726070');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3499346063');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3499346081');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3501458042');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3501458060');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3502007053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3502007071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3502330071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3502330089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3502852082');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3504623061');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3505074036');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3505074054');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3505074072');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3505350071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3506198058');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3506610051');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3506610069');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3506844051');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3507230062');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3507230080');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3507605000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3507830053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3508181048');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3508181066');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3508528059');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3537576027');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3540237054');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3575781051');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3576851080');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3577507055');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3578530066');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3578530084');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3579752034');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3579752052');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3579752070');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3580103052');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3580103070');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3580103088');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3580684063');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3580684081');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3581257056');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3582671060');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3583182035');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3583182053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3583488071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3583488089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3585194050');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3585643061');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3585643079');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3586069054');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3586069072');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3586737047');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3587751051');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3587751069');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3588119062');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3588484000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3588695053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3589034048');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3619499027');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3623649051');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3626098052');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3627006056');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3656310036');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3657413065');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3658737033');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3658737051');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3659124069');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3659760080');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3660384055');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3661360084');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3662521052');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3662521070');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3662858070');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3662858088');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3663405081');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3663955056');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3663955074');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3665787035');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3665787053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3665787071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3666078071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3667714050');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3667714068');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3668145061');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3668145079');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3668561036');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3668561054');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3668561072');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3669205047');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3670166051');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3670849000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3699484027');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3702262053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3702904027');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3740830036');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3741892065');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3741892083');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3743165033');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3743165051');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3743165069');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3744751055');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3745105053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3745105071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3745689084');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3746248041');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3746248059');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3746804052');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3746804070');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3747126070');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3747126088');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3748191056');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3749001049');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3749488060');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3749488078');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3749964053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3749964071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3751561032');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3751804050');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3751804068');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3752208043');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3752208061');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3753522000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3784476027');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3787667046');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3787787027');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3790113054');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3792579055');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3823722064');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3826847036');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3826847054');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3827881065');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3827881083');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3829120069');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3830078044');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3830664055');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3831011053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3831011071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3831011089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3832120059');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3832663052');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3832663070');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3833486045');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3833486063');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3833988000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3834756049');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3835215060');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3835215078');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3835659053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3835659071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3837332050');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3837332068');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3861025027');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3865170027');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3871105027');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3911410064');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3911410082');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3914475054');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3914475072');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3914854053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3914854071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3914854089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3915482083');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3916692051');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3916692069');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3917619044');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3917619062');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3918176055');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3918510071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3918510089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3919549059');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3919549077');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3920057052');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3920057070');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3920817045');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3920817063');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3921971049');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3921971067');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3922389042');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3922389060');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3922389078');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3923746000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3924289050');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3949351027');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3959295027');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3961753053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3962899057');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3964294054');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3999581035');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3999581053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3999581071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '3999998071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4000680064');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4000680082');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4003038043');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4003657054');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4003657072');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4004022071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4004022089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4004615083');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4005749051');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4005749069');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4006610044');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4006610062');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4006610080');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4007126000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4007126055');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4007126073');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4007432089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4007918048');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4008390059');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4008390077');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4008849052');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4008849070');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4010206053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4010596049');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4010596067');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4010980060');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4016625071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4034981027');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4039309027');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4043424027');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4086081034');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4087266081');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4089133085');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4090499035');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4090499053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4090899071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4090899089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4091548064');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4091548082');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4093769043');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4093769061');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4094344054');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4094685071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4095236083');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4096287069');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4097080062');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4097080080');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4097553073');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4097838071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4098287048');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4098725059');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4100183000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4100413053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4100778049');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4100778067');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4126580027');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4134931027');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4139553052');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4142231053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4144085061');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4178664070');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4179096070');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4179808081');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4180510056');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4181597085');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4182255042');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4182890071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4183264053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4183264071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4183264089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4183870082');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4185955061');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4185955079');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4186490054');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4186490072');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4186811071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4188589051');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4189052062');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4189498000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4189498055');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4190194048');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4190194066');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4192213053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4219871027');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4224158027');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4270218037');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4271396066');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4271396084');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4272806034');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4272806052');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4273214070');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4273214088');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4273888081');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4274553038');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4274553056');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4274940053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4274940071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4275580085');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4276800053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4276800071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4277157071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4277726082');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4279695061');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4279695079');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4280205054');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4280205072');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4280509089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4282206051');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4282206069');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4282648062');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4282648080');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4283081000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4283081055');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4283748048');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4288343065');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4318899027');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4322373047');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4325010055');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4325487048');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4326643052');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4327725056');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4328722060');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4362599065');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4366016037');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4366016055');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4367146066');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4367146084');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4368492070');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4368886070');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4368886088');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4369526081');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4370168056');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4370168074');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4370534071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4371739078');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4372312053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4372649071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4372649089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4374588050');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4375093043');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4375093061');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4375093079');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4375588054');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4375588072');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4377497051');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4377497069');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4379275000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4411344027');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4415308027');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4454532086');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4458965036');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4458965054');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4458965072');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4459460087');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4460184065');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4460184083');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4461658000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4461658051');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4463491037');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4463491073');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4463897053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4463897071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4463897089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4464581066');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4464581084');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4465231041');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4465881052');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4465881070');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4466255088');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4466879045');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4466879063');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4467497056');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4467497074');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4467857071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4467857089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4468450085');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4469021060');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4469021078');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4469580053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4469580071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4471749050');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4471749068');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4472227043');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4472227061');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4472227079');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4473792000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4509514027');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4513371027');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4516099054');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4518574062');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4519005055');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4554664064');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4558246036');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4558246054');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4558246072');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4559437065');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4559437083');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4560878051');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4562665055');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4562665073');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4563064071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4563064089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4563726066');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4563726084');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4564358059');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4564993052');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4565957063');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4566541056');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4566887089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4567981042');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4567981060');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4567981078');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4568502053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4568502071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4569771000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4570490050');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4570490068');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4570921061');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4597953027');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4602662027');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4609495027');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4654523035');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4655798064');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4655798082');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4657817050');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4659322036');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4659322054');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4659322072');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4659759053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4659759071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4659759089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4660485065');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4660485083');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4661892069');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4662962044');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4663610055');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4663996071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4663996089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4664247066');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4664618084');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4665214077');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4665807052');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4665807070');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4666142052');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4666701045');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4666701063');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4666701081');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4667242056');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4667242074');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4667559089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4668066049');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4668066067');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4668558060');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4668558078');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4669030053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4670172000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4670423053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4670823050');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4670823068');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4678425069');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4699756027');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4711174027');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4714042053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4715388057');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4716602061');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4719100062');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4755797067');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4757419035');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4757419053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4757419071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4757896071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4758681064');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4758681082');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4759449039');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4761394043');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4762106072');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4762528071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4762528089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4763217083');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4765542062');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4766144055');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4766499071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4766499089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4767629059');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4768170070');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4768481052');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4768990063');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4768990081');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4769482056');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4770242049');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4770242067');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4770697042');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4770697060');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4772191000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4772425053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4772798050');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4777624071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4798503027');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4803384027');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4808090027');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4811525055');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4812322027');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4858426081');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4859260056');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4860563085');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4862126053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4862126071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4862582071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4862582089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4863331082');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4864062057');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4865207050');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4865207086');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4865903043');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4865903061');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4866335076');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4866566054');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4866566072');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4866959053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4866959071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4866959089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4867601083');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4869763062');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4869763080');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4870319055');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4870319073');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4871183048');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4872497052');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4872972063');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4872972081');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4873431000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4873705053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4874146049');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4874146067');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4903915027');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4913422027');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4920206056');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4924194061');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4961928066');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4964912081');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4965714056');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4965714074');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4966962085');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4968453071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4968884071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4968884089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4969588082');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4970279039');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4970279057');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4970684071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4972008079');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4972629054');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4973002071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4975091051');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4975634062');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4975634080');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4976163000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4976163055');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4976163073');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4978234052');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '4979389053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5011199027');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5016067027');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5020449027');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5066368091');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5068915055');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5070254066');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5070254084');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5071871052');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5073108063');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5073874056');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5074314053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5074314071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5075057085');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5075771060');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5076469053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5076469071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5076880089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5077547082');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5078206000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5078206057');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5078206075');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5078588053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5078588071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5079847061');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5080442054');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5080442072');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5080794089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5082485051');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5082803051');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5082803069');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5083323062');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5083323080');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5083833055');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5085803052');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5124984027');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5129022047');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5129172027');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5132109055');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5132661048');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5175106065');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5179000055');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5180292066');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5180292084');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5181848070');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5183037045');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5183037063');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5183037081');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5183780000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5183780074');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5184201071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5184201089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5184922085');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5186279053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5187316064');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5187316082');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5187948057');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5188321071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5189533061');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5189533079');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5190113054');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5190113072');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5192064051');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5192064069');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5192359051');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5192359069');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5192852044');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5192852062');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5192852080');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5201463050');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5231206027');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5235761027');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5236014064');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5285782036');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5285782072');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5287172065');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5287172083');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5290966037');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5290966055');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5290966073');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5291431053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5291431071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5291431089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5292218066');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5292218084');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5293731052');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5293731070');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5294885045');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5294885063');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5295600056');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5295600074');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5296013071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5296013089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5296705085');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5297368060');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5297368078');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5298028053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5298028071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5299028046');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5299028064');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5299628000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5299628075');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5300563050');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5300563068');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5301123043');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5301123061');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5301123079');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5303264053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5303451051');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5303715051');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5303715069');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5343928027');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5348374027');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5351553054');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5354454062');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5357307063');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5399741054');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5401106065');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5401106083');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5403237051');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5404041044');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5404825073');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5405284053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5405284071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5405284089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5406044084');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5407515052');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5407515070');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5408631045');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5408631063');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5408631081');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5409308056');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5409707071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5409707089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5410984060');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5410984078');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5411598053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5411598071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5412526064');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5413936050');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5413936068');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5414445061');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5416110000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5416373053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5416782051');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5422136089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5423075071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5458650027');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5511665082');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5513447068');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5513968086');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5515685036');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5515685054');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5515685072');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5516193071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5516193089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5517022065');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5517022083');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5519101087');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5519872044');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5519872062');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5520619055');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5521062071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5521062089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5521782084');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5523170070');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5524206063');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5524835056');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5524835074');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5525803049');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5526379060');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5527262053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5527787064');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5528289000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5528589053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5529071050');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5529071068');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5531321053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5536629071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5572574027');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5575264027');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5578586053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5579339027');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5580144057');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5584540062');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5626317067');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5628159053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5629592082');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5631856086');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5633510000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5633510072');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5633997071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5633997089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5634786083');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5637479062');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5638178055');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5638178073');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5638586089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5640909052');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5641508063');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5642088056');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5642088074');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5642984049');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5644345053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5645303000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5645584053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5646037050');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5681003027');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5686334027');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5690273055');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5691189027');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5744852038');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5744852056');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5746329067');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5746329085');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5748112053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5748637071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5748637089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5749486082');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5750332000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5750332039');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5750332057');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5750332075');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5750822053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5751644086');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5752440061');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5753212054');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5753212072');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5753669071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5753669089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5755554053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5756933062');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5756933080');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5757586055');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5757586073');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5759207059');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5760148052');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5760148070');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5760707063');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5760707081');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5761254038');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5761254056');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5761254074');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5764567053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5806999027');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5811614027');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5814832056');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5815422049');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5816901053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5817745064');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5819530061');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5862437066');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5866743038');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5866743056');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5866743074');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5868164067');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5868164085');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5869875071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5870374089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5871183064');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5871183082');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5871988057');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5872452071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5872452089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5873231086');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5873982061');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5873982079');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5874711054');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5875146089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5876527000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5877592051');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5878226062');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5878226080');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5878641095');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5878851055');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5878851073');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5881294052');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5881294070');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5881829045');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5881829063');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5881829081');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5882659053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5919051027');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5924555027');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5929551027');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5929826065');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5984895037');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5984895055');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5986419066');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5986419084');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5989678063');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5990560038');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5990560056');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5991064053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5991064071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5991064089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5991405067');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5991919067');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5991919085');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5993549053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5993549071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5994794046');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5994794064');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5995565000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5995565057');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5995565075');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5996005071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5996005089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5996755086');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5997468061');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5997468079');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5998172054');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5998172072');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5998581089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5999257047');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5999257065');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5999909058');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '5999909076');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6000296071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6000933051');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6000933069');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6001544062');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6001544080');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6002148055');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6002148073');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6004466052');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6004972045');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6049202027');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6057426055');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6061168056');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6106412065');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6110831055');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6112310084');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6115463045');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6115463063');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6116316000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6116800071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6116800089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6117129067');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6117627085');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6119202053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6120406046');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6120406064');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6120406082');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6121144057');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6121573071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6121573089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6123667054');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6123667072');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6124710047');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6125702053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6126295051');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6126295069');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6126873044');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6126873062');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6126873080');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6129089053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6129281052');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6129554052');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6130016045');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6180821065');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6190238057');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6234533065');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6234533083');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6238857000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6238857037');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6238857055');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6239392071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6239392089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6240291084');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6243361063');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6244185000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6244185056');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6244662071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6244662089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6245456085');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6246223060');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6246988053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6246988071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6248149064');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6248149082');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6248852057');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6248852075');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6249267071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6249267089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6249940050');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6250590061');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6250590079');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6251227054');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6251227072');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6253103053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6253645051');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6253645069');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6254171062');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6256158053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6262045089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6263603071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6264468071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6308340054');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6311707062');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6315063063');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6363158036');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6363158054');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6363158072');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6364707065');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6364707083');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6366587069');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6367136069');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6367136087');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6368054044');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6368952073');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6369484071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6369484089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6370355066');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6370355084');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6373332063');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6374115000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6374115056');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6374574089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6374879067');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6376770053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6376770071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6377178053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6377178071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6377848064');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6378499057');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6378499075');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6379500050');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6379500068');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6380095061');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6381552047');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6382377053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6382870051');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6382870069');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6389390071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6390590071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6445664056');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6490982082');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6493591068');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6493591086');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6495542036');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6495542054');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6496123071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6496123089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6497062083');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6499440087');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6500319044');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6501180055');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6501180073');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6501689071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6501689089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6502518084');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6505322063');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6506051056');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6506051074');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6506476071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6506476089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6508880053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6509495064');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6509495082');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6510440053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6511009050');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6513395000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6513684053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6565603049');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6570018050');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6572585065');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6626528039');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6628099086');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6629987054');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6629987072');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6630542089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6631442083');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6632323040');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6632838053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6632838071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6634529062');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6634529080');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6635341055');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6635814089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6638501052');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6639201063');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6639201081');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6639877056');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6639877074');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6640274071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6640274089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6642520053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6642520071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6643093064');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6643093082');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6643983053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6696252066');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6709490055');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6756963038');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6758632067');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6758632085');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6763185000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6763185039');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6763185075');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6763740071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6763740089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6764679068');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6764679086');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6766473054');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6766473072');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6766996089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6767850065');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6767850083');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6768682076');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6769165071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6769165089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6770754062');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6770754080');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6771515055');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6771515073');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6771964089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6774493052');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6774493070');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6775145063');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6775145081');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6775787056');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6775787074');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6776160089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6777959053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6778299053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6778299071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6779696053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6835077052');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6836963056');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6837652049');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6895838038');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6895838074');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6897455085');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6899394053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6899394071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6900894064');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6901814000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6901814075');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6902343053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6902343071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6902343089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6902703068');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6903237086');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6904095061');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6904939054');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6907036058');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6907491071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6907491089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6909002062');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6909002080');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6909735055');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6909735073');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6912189052');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6912583052');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6912583070');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6913212063');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6913212081');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6913830056');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6915901053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6916217053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6967870065');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '6972867066');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7030430037');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7032142066');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7036826038');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7036826056');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7037404071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7038376085');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7040237071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7041675064');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7042556057');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7043062071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7043062089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7043409068');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7043923086');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7044744061');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7045565054');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7045565072');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7046823047');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7046823065');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7046823083');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7047582058');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7048024071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7048024089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7048763051');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7049474062');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7049474080');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7050185055');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7050185073');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7052281053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7052529052');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7052529070');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7052892052');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7052892070');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7053486063');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7055460000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7113215055');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7116899063');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7120670064');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7175396066');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7175396084');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7176411077');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7180521071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7180521089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7181461067');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7181461085');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7183264053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7183264071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7184661064');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7184661082');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7185511057');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7186006053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7186006071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7186006089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7187625079');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7188421054');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7188421072');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7189631065');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7189631083');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7190354000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7190354058');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7190782089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7191475051');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7191475069');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7192147062');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7192147080');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7194743053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7195300052');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7203881089');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7205459071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7264534057');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7319327000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7319327037');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7319327055');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7319941071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7323503070');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7324458045');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7324458063');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7325402000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7325402056');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7325958071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7328619053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7329961064');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7330773000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7330773057');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7331248071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7333523054');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7333945053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7334646065');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7336344069');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7336958062');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7339306053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7347689071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7398531054');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7400553058');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7401290051');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7406343063');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7467211037');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7467821071');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7472211045');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7473112056');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7476636053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7479325050');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7481092053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7482701053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7483285051');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7554805056');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7556524053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7606988039');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7613776040');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7620391053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7626268053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7630412053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7631920053');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7690708049');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7695787050');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7697668054');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7698762065');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7701038062');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7702541066');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7766281000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7914747000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '7921024000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '8065213000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '8071985000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '8077985000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '8231561000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '8380163000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '8387218000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '8393560000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '8545016000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '8551913000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '8571077000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '8870491000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '8885006000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '9043085000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '9050494000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '9218193000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '9225290000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '9395690000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '9402502000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '9568342000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '9575724000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '9582314000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '9751203000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '9758403000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '10112739000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '10120770000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '10304030000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '10311787000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '10497927000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '10502356000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '10505337000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '10694463000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '10893657000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '11079871000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '11088176000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '11496842000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '11690750000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '11699733000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '11707819000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '11905117000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '11913820000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '11921511000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '12137967000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '12333395000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '12342341000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '12350338000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '12357353000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '12556576000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '12579723000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '12997296000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '13006860000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '13015576000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '13023290000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '13229985000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '13239371000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '13255011000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '13489677000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '13720904000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '13962042000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '14182504000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '14206395000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '14667204000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '14677181000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '14694151000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '14932297000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '15170795000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '15698540000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '15708225000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '15724138000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '15967219000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '15991785000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '16487436000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '16498705000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '16526528000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '16766962000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '16778023000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '17050031000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '17060860000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '17615499000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '17626691000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '17653022000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '17920134000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '18489365000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '18501123000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '18794274000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '18805760000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '19102910000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '19109541000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '19114120000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '19415267000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '19435560000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '19719665000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '19731265000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '19741569000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '20039684000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '20069218000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '20684111000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '20695132000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '20990725000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '21003652000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '21015517000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '21339185000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '21346023000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '21350734000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '21678664000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '22009957000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '22021937000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '22032522000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '22357476000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '22368939000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '23030858000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '23044628000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '23390972000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '23768244000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '23780107000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '24136119000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '24147539000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '24482093000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '24495728000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '24508051000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '24518909000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '24858887000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '24894173000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '25054260127');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '25263671000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '25602608000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '25616896000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '25992299000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '26006162000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '26018697000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '26394055000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '26399547000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '26784183000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '27172488000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '27186534000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '27199184000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '27210295000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '27579545000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '27593130000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '27605192000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '27789909128');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '28367598000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '28383554000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '28788417000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '28803990000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '28831083000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '29236959000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '29657903000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '29671324000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '30061549000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '30077203000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '30091624000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '30104567000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '30515734000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '30529667000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '30541991000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '30728324134');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '30972029000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '31366137000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '31382665000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '31600367130');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '32285853000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '32306356000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '32753812000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '33189176000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '33205280000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '33233273000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '33407036131');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '33660947000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '33676687000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '34166256000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '34592149000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '34609197000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '35060739000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '35330905131');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '36279994132');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '36531478000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '36549338000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '37055088000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '37071198000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '37085751000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '37813556141');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '37841781131');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '38035503000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '38054247000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '38071770000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '38305389137');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '38322071132');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '38556894000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '38575305000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '38844719132');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '39356493137');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '39624693000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '39647613000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '39656073000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '39661848000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '39674458000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '39685372000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '39843994138');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '39889266137');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '40132032000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '40150410000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '40167305000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '40182666000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '40196381000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '40227227000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '40673530000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '40691470000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '40722743000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '40735803000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '40756729000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '40954152142');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '40969913137');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '41220027000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '41237561000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '41253469000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '41279985000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '41721410000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '41741747000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '41753112000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '41761048000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '41771679000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '41803919000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '41829163000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '41839353000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '42328259000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '42344605000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '42364790000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '42588488138');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '42853254000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '42872287000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '42889724000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '42946498000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '43168565133');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '43456098000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '43477119000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '43500971000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '43693983134');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '43982236000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '44033922000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '44070365000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '44279078143');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '44295604138');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '44310650133');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '44560123000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '44578468000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '44623566000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '45161148000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '45215108000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '45443795143');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '45700934000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '45731604000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '45778130000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '46006899139');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '46306678000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '46325122000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '46341774000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '46374656000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '46619994134');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '46923621000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '46945780000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '47510074000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '47533878000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '47582140000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '47826267134');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '48089766000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '48126581000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '48386676149');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '48684962000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '48723966000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '48781348000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '49004472149');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '49038843139');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '49398989000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '49969896000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '49999545000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '50544483000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '50564946000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '50621510000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '50860897145');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '51182445000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '51220479000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '51519381140');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '52796965145');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '53095936000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '53153029000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '53776212000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '53850182000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '54096640150');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '54421541000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '54733517146');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '55092672000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '55407329146');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '55444385136');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '56431577000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '56504040000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '56751622151');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '56771489146');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '57085926000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '57176623000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '57780347000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '57820869000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '58500770000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '59163941000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '59185654000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '59240125000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '59555514137');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '59875548000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '60209280152');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '60950259147');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '61294022000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '61324440000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '61633322157');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '61693895142');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '62052626000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '62087505000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '62386618152');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '62721859000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '62766690000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '62819980000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '63485811000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '64186248000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '64232101000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '64252437000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '64962637000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '65316048153');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '65698286000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '66844469153');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '66865106148');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '67637262148');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '67973144000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '68395862153');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '68836972000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '69544777000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '69567206000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '70339259000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '70361136000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '71139676000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '71217901000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '72802132000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '73140556154');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '76011527000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '76831305000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '78962518155');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '81985089000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '85065589161');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '85974465161');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '88240760000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '89172539000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '100697175000');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '104253515169');
INSERT INTO feature_chemical_formula (feature_id, chemical_formula_id) VALUES ('137', '107880886000');

-- Add an identity calibration method for all deprecated calibration lists
INSERT INTO
    calibration_method (
        calibration_method_id,
        calibration_list,
        calibration_type,
        calibration_parameters,
        added_by
    )
VALUES
    (
        '90',
        '90',
        'linear',
        '{"1": 0.0, "0": 0.0}',
        '224'
    )
;

INSERT INTO
    calibration_method (
        calibration_method_id,
        calibration_list,
        calibration_type,
        calibration_parameters,
        added_by
    )
VALUES
    (
        '91',
        '91',
        'linear',
        '{"1": 0.0, "0": 0.0}',
        '224'
    )
;

INSERT INTO
    calibration_method (
        calibration_method_id,
        calibration_list,
        calibration_type,
        calibration_parameters,
        added_by
    )
VALUES
    (
        '92',
        '92',
        'linear',
        '{"1": 0.0, "0": 0.0}',
        '224'
    )
;

INSERT INTO
    calibration_method (
        calibration_method_id,
        calibration_list,
        calibration_type,
        calibration_parameters,
        added_by
    )
VALUES
    (
        '93',
        '93',
        'linear',
        '{"1": 0.0, "0": 0.0}',
        '224'
    )
;

INSERT INTO
    calibration_method (
        calibration_method_id,
        calibration_list,
        calibration_type,
        calibration_parameters,
        added_by
    )
VALUES
    (
        '94',
        '94',
        'linear',
        '{"1": 0.0, "0": 0.0}',
        '224'
    )
;

INSERT INTO
    calibration_method (
        calibration_method_id,
        calibration_list,
        calibration_type,
        calibration_parameters,
        added_by
    )
VALUES
    (
        '95',
        '95',
        'linear',
        '{"1": 0.0, "0": 0.0}',
        '224'
    )
;

INSERT INTO
    calibration_method (
        calibration_method_id,
        calibration_list,
        calibration_type,
        calibration_parameters,
        added_by
    )
VALUES
    (
        '96',
        '96',
        'linear',
        '{"1": 0.0, "0": 0.0}',
        '224'
    )
;

INSERT INTO
    calibration_method (
        calibration_method_id,
        calibration_list,
        calibration_type,
        calibration_parameters,
        added_by
    )
VALUES
    (
        '97',
        '97',
        'linear',
        '{"1": 0.0, "0": 0.0}',
        '224'
    )
;

INSERT INTO
    calibration_method (
        calibration_method_id,
        calibration_list,
        calibration_type,
        calibration_parameters,
        added_by
    )
VALUES
    (
        '98',
        '98',
        'linear',
        '{"1": 0.0, "0": 0.0}',
        '224'
    )
;

INSERT INTO
    calibration_method (
        calibration_method_id,
        calibration_list,
        calibration_type,
        calibration_parameters,
        added_by
    )
VALUES
    (
        '99',
        '99',
        'linear',
        '{"1": 0.0, "0": 0.0}',
        '224'
    )
;

INSERT INTO
    calibration_method (
        calibration_method_id,
        calibration_list,
        calibration_type,
        calibration_parameters,
        added_by
    )
VALUES
    (
        '100',
        '100',
        'linear',
        '{"1": 0.0, "0": 0.0}',
        '224'
    )
;

INSERT INTO
    calibration_method (
        calibration_method_id,
        calibration_list,
        calibration_type,
        calibration_parameters,
        added_by
    )
VALUES
    (
        '101',
        '101',
        'linear',
        '{"1": 0.0, "0": 0.0}',
        '224'
    )
;

INSERT INTO
    calibration_method (
        calibration_method_id,
        calibration_list,
        calibration_type,
        calibration_parameters,
        added_by
    )
VALUES
    (
        '102',
        '102',
        'linear',
        '{"1": 0.0, "0": 0.0}',
        '224'
    )
;

INSERT INTO
    calibration_method (
        calibration_method_id,
        calibration_list,
        calibration_type,
        calibration_parameters,
        added_by
    )
VALUES
    (
        '104',
        '104',
        'linear',
        '{"1": 0.0, "0": 0.0}',
        '224'
    )
;

INSERT INTO
    calibration_method (
        calibration_method_id,
        calibration_list,
        calibration_type,
        calibration_parameters,
        added_by
    )
VALUES
    (
        '105',
        '105',
        'linear',
        '{"1": 0.0, "0": 0.0}',
        '224'
    )
;

INSERT INTO
    calibration_method (
        calibration_method_id,
        calibration_list,
        calibration_type,
        calibration_parameters,
        added_by
    )
VALUES
    (
        '106',
        '106',
        'linear',
        '{"1": 0.0, "0": 0.0}',
        '224'
    )
;

INSERT INTO
    calibration_method (
        calibration_method_id,
        calibration_list,
        calibration_type,
        calibration_parameters,
        added_by
    )
VALUES
    (
        '107',
        '107',
        'linear',
        '{"1": 0.0, "0": 0.0}',
        '224'
    )
;

INSERT INTO
    calibration_method (
        calibration_method_id,
        calibration_list,
        calibration_type,
        calibration_parameters,
        added_by
    )
VALUES
    (
        '108',
        '108',
        'linear',
        '{"1": 0.0, "0": 0.0}',
        '224'
    )
;

INSERT INTO
    calibration_method (
        calibration_method_id,
        calibration_list,
        calibration_type,
        calibration_parameters,
        added_by
    )
VALUES
    (
        '109',
        '109',
        'linear',
        '{"1": 0.0, "0": 0.0}',
        '224'
    )
;

INSERT INTO
    calibration_method (
        calibration_method_id,
        calibration_list,
        calibration_type,
        calibration_parameters,
        added_by
    )
VALUES
    (
        '110',
        '110',
        'linear',
        '{"1": 0.0, "0": 0.0}',
        '224'
    )
;

INSERT INTO
    calibration_method (
        calibration_method_id,
        calibration_list,
        calibration_type,
        calibration_parameters,
        added_by
    )
VALUES
    (
        '111',
        '111',
        'linear',
        '{"1": 0.0, "0": 0.0}',
        '224'
    )
;

INSERT INTO
    calibration_method (
        calibration_method_id,
        calibration_list,
        calibration_type,
        calibration_parameters,
        added_by
    )
VALUES
    (
        '112',
        '112',
        'linear',
        '{"1": 0.0, "0": 0.0}',
        '224'
    )
;

INSERT INTO
    calibration_method (
        calibration_method_id,
        calibration_list,
        calibration_type,
        calibration_parameters,
        added_by
    )
VALUES
    (
        '113',
        '113',
        'linear',
        '{"1": 0.0, "0": 0.0}',
        '224'
    )
;

INSERT INTO
    calibration_method (
        calibration_method_id,
        calibration_list,
        calibration_type,
        calibration_parameters,
        added_by
    )
VALUES
    (
        '115',
        '115',
        'linear',
        '{"1": 0.0, "0": 0.0}',
        '224'
    )
;

INSERT INTO
    calibration_method (
        calibration_method_id,
        calibration_list,
        calibration_type,
        calibration_parameters,
        added_by
    )
VALUES
    (
        '116',
        '116',
        'linear',
        '{"1": 0.0, "0": 0.0}',
        '224'
    )
;

INSERT INTO
    calibration_method (
        calibration_method_id,
        calibration_list,
        calibration_type,
        calibration_parameters,
        added_by
    )
VALUES
    (
        '117',
        '117',
        'linear',
        '{"1": 0.0, "0": 0.0}',
        '224'
    )
;

INSERT INTO
    calibration_method (
        calibration_method_id,
        calibration_list,
        calibration_type,
        calibration_parameters,
        added_by
    )
VALUES
    (
        '118',
        '118',
        'linear',
        '{"1": 0.0, "0": 0.0}',
        '224'
    )
;

INSERT INTO
    calibration_method (
        calibration_method_id,
        calibration_list,
        calibration_type,
        calibration_parameters,
        added_by
    )
VALUES
    (
        '119',
        '119',
        'linear',
        '{"1": 0.0, "0": 0.0}',
        '224'
    )
;

INSERT INTO
    calibration_method (
        calibration_method_id,
        calibration_list,
        calibration_type,
        calibration_parameters,
        added_by
    )
VALUES
    (
        '120',
        '120',
        'linear',
        '{"1": 0.0, "0": 0.0}',
        '224'
    )
;

INSERT INTO
    calibration_method (
        calibration_method_id,
        calibration_list,
        calibration_type,
        calibration_parameters,
        added_by
    )
VALUES
    (
        '121',
        '121',
        'linear',
        '{"1": 0.0, "0": 0.0}',
        '224'
    )
;

INSERT INTO
    calibration_method (
        calibration_method_id,
        calibration_list,
        calibration_type,
        calibration_parameters,
        added_by
    )
VALUES
    (
        '122',
        '122',
        'linear',
        '{"1": 0.0, "0": 0.0}',
        '224'
    )
;

INSERT INTO
    calibration_method (
        calibration_method_id,
        calibration_list,
        calibration_type,
        calibration_parameters,
        added_by
    )
VALUES
    (
        '123',
        '123',
        'linear',
        '{"1": 0.0, "0": 0.0}',
        '224'
    )
;

INSERT INTO
    calibration_method (
        calibration_method_id,
        calibration_list,
        calibration_type,
        calibration_parameters,
        added_by
    )
VALUES
    (
        '124',
        '124',
        'linear',
        '{"1": 0.0, "0": 0.0}',
        '224'
    )
;

INSERT INTO
    calibration_method (
        calibration_method_id,
        calibration_list,
        calibration_type,
        calibration_parameters,
        added_by
    )
VALUES
    (
        '125',
        '125',
        'linear',
        '{"1": 0.0, "0": 0.0}',
        '224'
    )
;

INSERT INTO
    calibration_method (
        calibration_method_id,
        calibration_list,
        calibration_type,
        calibration_parameters,
        added_by
    )
VALUES
    (
        '126',
        '126',
        'linear',
        '{"1": 0.0, "0": 0.0}',
        '224'
    )
;

INSERT INTO
    calibration_method (
        calibration_method_id,
        calibration_list,
        calibration_type,
        calibration_parameters,
        added_by
    )
VALUES
    (
        '127',
        '127',
        'linear',
        '{"1": 0.0, "0": 0.0}',
        '224'
    )
;

INSERT INTO
    calibration_method (
        calibration_method_id,
        calibration_list,
        calibration_type,
        calibration_parameters,
        added_by
    )
VALUES
    (
        '128',
        '128',
        'linear',
        '{"1": 0.0, "0": 0.0}',
        '224'
    )
;

INSERT INTO
    calibration_method (
        calibration_method_id,
        calibration_list,
        calibration_type,
        calibration_parameters,
        added_by
    )
VALUES
    (
        '129',
        '129',
        'linear',
        '{"1": 0.0, "0": 0.0}',
        '224'
    )
;

INSERT INTO
    calibration_method (
        calibration_method_id,
        calibration_list,
        calibration_type,
        calibration_parameters,
        added_by
    )
VALUES
    (
        '130',
        '130',
        'linear',
        '{"1": 0.0, "0": 0.0}',
        '224'
    )
;

INSERT INTO
    calibration_method (
        calibration_method_id,
        calibration_list,
        calibration_type,
        calibration_parameters,
        added_by
    )
VALUES
    (
        '131',
        '131',
        'linear',
        '{"1": 0.0, "0": 0.0}',
        '224'
    )
;

INSERT INTO
    calibration_method (
        calibration_method_id,
        calibration_list,
        calibration_type,
        calibration_parameters,
        added_by
    )
VALUES
    (
        '132',
        '132',
        'linear',
        '{"1": 0.0, "0": 0.0}',
        '224'
    )
;

INSERT INTO
    calibration_method (
        calibration_method_id,
        calibration_list,
        calibration_type,
        calibration_parameters,
        added_by
    )
VALUES
    (
        '133',
        '133',
        'linear',
        '{"1": 0.0, "0": 0.0}',
        '224'
    )
;

INSERT INTO
    calibration_method (
        calibration_method_id,
        calibration_list,
        calibration_type,
        calibration_parameters,
        added_by
    )
VALUES
    (
        '134',
        '134',
        'linear',
        '{"1": 0.0, "0": 0.0}',
        '224'
    )
;


-- Restart the sequence at 150 because of the manual calibration method id inserts
ALTER SEQUENCE
    calibration_method_calibration_method_id_seq
RESTART WITH
    150
;

-- Add a mock identity calibration list to the feature relation
INSERT INTO
    feature (
        name,
        description,
        type,
        active
    )
VALUES
    (
        'Identity',
        'This is a mock calibration list to map already calibrated data.',
        'calibration list',
        'false'
    )
;

-- Add an identity calibration method to the calibration method relation with the identity
-- calibration list
INSERT INTO
    calibration_method (
        calibration_method_id,
        calibration_list,
        calibration_type,
        calibration_parameters,
        added_by
    )
VALUES
    (
        1,
        (SELECT feature_id FROM feature WHERE name = 'Identity'),
        'linear',
        '{"1": 0.0, "0": 0}',
        224
    )
;

-- Add the column 'calibration_method' to the measurement relation
ALTER TABLE measurement
ADD COLUMN
calibration_method BIGINT
REFERENCES calibration_method (calibration_method_id) ON DELETE RESTRICT
;

-- Set the calibration method id by the old calibration lists name
UPDATE
    measurement
SET
    calibration_method = 90
WHERE
    calibration_list = 'ESI Fatty Acids (neg)'
;

UPDATE
    measurement
SET
    calibration_method = 91
WHERE
    calibration_list = 'ESI Surf+Fatty+Salt_CalibList'
;

UPDATE
    measurement
SET
    calibration_method = 92
WHERE
    calibration_list = ' ESI Sugars-NOM-Na_pos_165-689'
;

UPDATE
    measurement
SET
    calibration_method = 93
WHERE
    calibration_list = 'ESI Fatty Acids_even_odd (neg)'
;

UPDATE
    measurement
SET
    calibration_method = 94
WHERE
    calibration_list = ''
;

UPDATE
    measurement
SET
    calibration_method = 95
WHERE
    calibration_list = 'ESI PEG (neg)'
;

UPDATE
    measurement
SET
    calibration_method = 96
WHERE
    calibration_list = ' ESI SRFA-Na_pos Roland_extended'
;

UPDATE
    measurement
SET
    calibration_method = 97
WHERE
    calibration_list = 'ESI PFC (neg)'
;

UPDATE
    measurement
SET
    calibration_method = 98
WHERE
    calibration_list = 'ESI Na TFA'
;

UPDATE
    measurement
SET
    calibration_method = 99
WHERE
    calibration_list = 'ESI Fatty Acid + Sulfonates (neg)'
;

UPDATE
    measurement
SET
    calibration_method = 100
WHERE
    calibration_list = ' '
;

UPDATE
    measurement
SET
    calibration_method = 101
WHERE
    calibration_list = 'ESI Fatty Acid + Sulfonates (pos)'
;

UPDATE
    measurement
SET
    calibration_method = 102
WHERE
    calibration_list = 'ESI Coffeine_and_adducts_pos'
;

UPDATE
    measurement
SET
    calibration_method = 104
WHERE
    calibration_list = 'ESI SRFA_neg Roland_highlypolar'
;

UPDATE
    measurement
SET
    calibration_method = 105
WHERE
    calibration_list = 'ESI a-Pinen-OH-HOMS (neg)'
;

UPDATE
    measurement
SET
    calibration_method = 106
WHERE
    calibration_list = 'ESI Surfactants+FattyAcids+SaltCluster_neg'
;

UPDATE
    measurement
SET
    calibration_method = 107
WHERE
    calibration_list = 'ESI SRFA_pos Roland_deprecated'
;

UPDATE
    measurement
SET
    calibration_method = 108
WHERE
    calibration_list = 'ESI'
;

UPDATE
    measurement
SET
    calibration_method = 109
WHERE
    calibration_list = 'ESI Fatty Acids'
;

UPDATE
    measurement
SET
    calibration_method = 110
WHERE
    calibration_list = 'ESI Sugars-NOM-Na_pos_165-689'
;

UPDATE
    measurement
SET
    calibration_method = 111
WHERE
    calibration_list = 'ESI SRFA_neg Roland_extended'
;

UPDATE
    measurement
SET
    calibration_method = 112
WHERE
    calibration_list = 'ESI <not set>'
;

UPDATE
    measurement
SET
    calibration_method = 113
WHERE
    calibration_list = ' ESI SRFA_neg Roland_extended'
;

UPDATE
    measurement
SET
    calibration_method = 115
WHERE
    calibration_list = ' ESI SRFA_neg Roland_extend_H-Lpolar-D'
;

UPDATE
    measurement
SET
    calibration_method = 116
WHERE
    calibration_list = '<not set> <not set>'
;

UPDATE
    measurement
SET
    calibration_method = 117
WHERE
    calibration_list = 'ESI SRFA_neg Roland_extend_Hpolar_Fatty_Acid'
;

UPDATE
    measurement
SET
    calibration_method = 118
WHERE
    calibration_list = 'ESI few_DiPAPs'
;

UPDATE
    measurement
SET
    calibration_method = 119
WHERE
    calibration_list = 'ESI SRFA_neg Roland_extend_1000mz'
;

UPDATE
    measurement
SET
    calibration_method = 120
WHERE
    calibration_list = 'ESI SRFA-Na_pos Roland_extended'
;

UPDATE
    measurement
SET
    calibration_method = 121
WHERE
    calibration_list = ' ESI Fatty Acid + Sulfonates (neg)'
;

UPDATE
    measurement
SET
    calibration_method = 122
WHERE
    calibration_list = 'ESI Glutamate_neg'
;

UPDATE
    measurement
SET
    calibration_method = 123
WHERE
    calibration_list = 'SRFA-Na_pos Roland_extended'
;

UPDATE
    measurement
SET
    calibration_method = 124
WHERE
    calibration_list = ' ESI SRFA_neg Roland_extend_Hpolar'
;

UPDATE
    measurement
SET
    calibration_method = 125
WHERE
    calibration_list = 'MALDI DHB_neg'
;

UPDATE
    measurement
SET
    calibration_method = 126
WHERE
    calibration_list = 'ESI SFRA pos'
;

UPDATE
    measurement
SET
    calibration_method = 127
WHERE
    calibration_list = 'ESI FattyAcid_Sulfonates_sugars_(neg)_0420'
;

UPDATE
    measurement
SET
    calibration_method = 128
WHERE
    calibration_list = 'ESI Zher_FaandPosSeries'
;

UPDATE
    measurement
SET
    calibration_method = 129
WHERE
    calibration_list = ' ESI SRFA_neg Roland_extend_H-Lpolar'
;

UPDATE
    measurement
SET
    calibration_method = 130
WHERE
    calibration_list = ' ESI SRFA_neg Roland'
;

UPDATE
    measurement
SET
    calibration_method = 131
WHERE
    calibration_list = 'ESI SRFA_neg Roland_extend_Hpolar'
;

UPDATE
    measurement
SET
    calibration_method = 132
WHERE
    calibration_list = 'ESI FattyAcid_Sulfonates_sugars-Cl_(neg)_0520'
;

UPDATE
    measurement
SET
    calibration_method = 133
WHERE
    calibration_list = 'ESI '
;

UPDATE
    measurement
SET
    calibration_method = 134
WHERE
    calibration_list = 'ESI SRFA_neg Roland'
;

-- Set all calibration methods to the mock identity method for all measurements without any
-- calibration method
UPDATE
    measurement
SET
    calibration_method = 1
WHERE
    calibration_method IS NULL;

-- Drop the column calibration list and calibration type from the measurement relation
ALTER TABLE measurement
DROP COLUMN IF EXISTS calibration_list,
DROP COLUMN IF EXISTS calibration_type
;

/*
* Create the function 'get_calibrated_mz'
* to get the calibrated mass from the measured mass and calibration parameters.
*/

CREATE OR REPLACE FUNCTION get_calibrated_mz(mz numeric, cal_type varchar, cal_params json)

RETURNS numeric(13,8) AS $$

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
$$ LANGUAGE plpgsql;

/*
* Create the view 'calibrated_peak'
* to apply the calibration function to the peak data and get the calibrated peak mz.
*/

CREATE OR REPLACE VIEW calibrated_peak AS

SELECT
    p.peak_id,
    p.measured_mass,
    get_calibrated_mz(
        p.measured_mass,
        cm.calibration_type,
        cm.calibration_parameters
    ) AS calibrated_mass,
    p.intensity,
    p.resolution,
    p.adduct,
    p.charge,
    p.sn,
    p.measurement,
    p.added_at,
    p.added_by

FROM
    measurement m,
    calibration_method cm,
    peak p

WHERE
    m.calibration_method = cm.calibration_method_id AND
    p.measurement = m.measurement_id
;

/*
* Create the trigger 'delete_results_on_recalibration_trigger' and the triggered function
* 'delete_results_trigger_function' to delete results if the calibration method id in the relation
* 'measurement' is updated (set to another calibration_method_id or to NULL).
*/

-- Function
CREATE OR REPLACE FUNCTION delete_results_trigger_function()
    RETURNS TRIGGER
    LANGUAGE plpgsql
    AS
$$
BEGIN
    IF OLD.calibration_method IS DISTINCT FROM NEW.calibration_method
    THEN
        DELETE FROM
            chemical_formula_assignment
        WHERE peak_id IN (
            SELECT
                peak_id
            FROM
                peak
            WHERE
                measurement = OLD.measurement_id
        );
        DELETE FROM
            measurement_cformula_config
        WHERE
            measurement_id = OLD.measurement_id
        ;
        DELETE FROM
            measurement_evaluation_config
        WHERE
            measurement_id = OLD.measurement_id
        ;
    END IF;
    IF NEW.calibration_method IS NULL
    THEN
        NEW.calibration_points = NULL;
        NEW.calibration_error = NULL;
        NEW.calibration_min_mass = NULL;
        NEW.calibration_max_mass = NULL;
    END IF;
    RETURN NEW;
END;
$$;

-- Trigger
CREATE TRIGGER delete_results_on_recalibration_trigger
BEFORE UPDATE OF calibration_method
ON measurement
FOR EACH ROW --WHEN (OLD.calibration_method IS DISTINCT FROM NEW.calibration_method)
    EXECUTE FUNCTION delete_results_trigger_function();

ROLLBACK;
--COMMIT;
