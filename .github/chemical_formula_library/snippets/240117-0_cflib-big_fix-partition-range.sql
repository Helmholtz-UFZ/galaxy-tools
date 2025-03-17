-- SPDX-FileCopyrightText: 2024 Helmholtz Centre for Environmental Research GmbH - UFZ
--
-- SPDX-License-Identifier: LicenseRef-UFZ-GPL-3.0-or-later

/*
* This script fixes the partition range of the big cflib partition 314. Data could not be inserted
* into this partition, because the wanted id was out of range - the lower bound was set incorrectly
* (156905591000).
*
* Author: Johann Wurz
* Vendor: Helmholtz Centre for Environmental Research GmbH - UFZ
*/

BEGIN;

-- Detach the problematic partition
ALTER TABLE cflib.chemical_formula DETACH PARTITION cflib.chemical_formula_part_314;

-- Attach the partition with a new lower bound
ALTER TABLE cflib.chemical_formula ATTACH PARTITION cflib.chemical_formula_part_314 FOR VALUES FROM (156905590000) TO (157399766000);

ROLLBACK;
--COMMIT;
