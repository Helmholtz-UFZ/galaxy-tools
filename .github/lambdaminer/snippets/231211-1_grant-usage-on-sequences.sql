-- SPDX-FileCopyrightText: 2024 Helmholtz Centre for Environmental Research GmbH - UFZ
--
-- SPDX-License-Identifier: LicenseRef-UFZ-GPL-3.0-or-later

/*
* The users of the production LMDB have not been able to write to 'calibration_method', because
* they did not have the permissions to write to the id sequence. The error was the following:
* "ERROR: permission denied for sequence calibration_method_calibration_method_id_seq".
* Therefore, the permission to use all sequences was given to all LMDB production users.
*/

BEGIN;

GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO lmdb_adm;

GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO lmdb_ro;

GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO lmdb_rw;

COMMIT;
