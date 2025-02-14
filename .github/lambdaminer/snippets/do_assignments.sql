-- SPDX-FileCopyrightText: 2024 Helmholtz Centre for Environmental Research GmbH - UFZ
--
-- SPDX-License-Identifier: LicenseRef-UFZ-GPL-3.0-or-later

SELECT cflib.do_assignments_for_peak(
        array[160.5, 161.0]::numeric[], --mass_range numeric[]
        array[0.3, 3.0]::numeric[], --rrange_hc numeric[]
        array[0, 2.0]::numeric[], --rrange_nc numeric[]
        array[0, 1.2]::numeric[], --rrange_oc numeric[]
        array[0, 10]::numeric[], --rrange_pc numeric[]
        array[0, 10]::numeric[], --rrange_sc numeric[]
        array[0, 25]::numeric[], --rrange_dbe numeric[]
        array[-10, 10]::numeric[], --rrange_dbe_o numeric[]
        '{   "C" : [ 1, 80 ],   "13C" : [ 0, 1 ],   "H" : [ 0, 198 ],   "N" : [ 0, 5 ],   "Na" : [ 1, 2 ],   "O" : [ 0, 40 ],   "S" : [ 1, 3 ],   "34S" : [ 1, 2 ] }'::json
)
