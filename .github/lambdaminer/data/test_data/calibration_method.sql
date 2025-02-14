-- SPDX-FileCopyrightText: 2024 Helmholtz Centre for Environmental Research GmbH - UFZ
--
-- SPDX-License-Identifier: LicenseRef-UFZ-GPL-3.0-or-later

--
-- Data for Name: calibration_method; Type: TABLE DATA; Schema: public; Owner: lmdb_adm
--

INSERT INTO public.calibration_method (calibration_method_id, calibration_list, calibration_type, calibration_parameters, ppm_window, sn_threshold, outlier_k_factor, electron_config, added_at, added_by) VALUES (1, 150, 'linear', '{"1": 0.0, "0": 0}', NULL, NULL, NULL, 'even', '2023-12-11 07:51:01.671456+00', 2);
INSERT INTO public.calibration_method (calibration_method_id, calibration_list, calibration_type, calibration_parameters, ppm_window, sn_threshold, outlier_k_factor, electron_config, added_at, added_by) VALUES (2, 83, 'linear', '{"1":-0.0002479111998195181,"0":0.0858639776816672}', 0.50, 8.00, 1.50, 'even', '2024-03-19 09:14:35.91371+00', 2);

--
-- Name: calibration_method_calibration_method_id_seq; Type: SEQUENCE SET; Schema: public; Owner: lmdb_adm
--

SELECT pg_catalog.setval('public.calibration_method_calibration_method_id_seq', 2, true);
