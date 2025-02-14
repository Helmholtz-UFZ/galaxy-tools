-- SPDX-FileCopyrightText: 2024 Helmholtz Centre for Environmental Research GmbH - UFZ
--
-- SPDX-License-Identifier: LicenseRef-UFZ-GPL-3.0-or-later

--
-- Data for Name: sample; Type: TABLE DATA; Schema: public; Owner: lmdb_adm
--

INSERT INTO public.sample (sample_id, sample_date, name, description, origin, carbon_concentration, sample_type, replicate_of_sample, sample_location, separation, sample_preparation_date, sample_preparation_lot_number, carbon_concentration_extract, extract_volume, additional_parameters, project, sample_preparation, added_at, added_by, external_id) VALUES (1, '2022-11-13 23:00:00+00', 'SRFA_Test_1', NULL, NULL, 5.00, 'STD', 1, NULL, 'LC', '2022-11-14 23:00:00+00', NULL, 50.00, 1.00, NULL, 1, 9, '2024-03-19 09:06:09.325353+00', 2, '11111111111111');
INSERT INTO public.sample (sample_id, sample_date, name, description, origin, carbon_concentration, sample_type, replicate_of_sample, sample_location, separation, sample_preparation_date, sample_preparation_lot_number, carbon_concentration_extract, extract_volume, additional_parameters, project, sample_preparation, added_at, added_by, external_id) VALUES (2, '2022-11-13 23:00:00+00', 'SRFA_Test_2', NULL, 'groundwater', 5.00, 'STD', 1, 5, 'LC', '2022-11-14 23:00:00+00', NULL, 150.00, 1.00, NULL, 1, 9, '2024-03-19 09:06:10.743404+00', 2, NULL);

--
-- Name: sample_sample_id_seq; Type: SEQUENCE SET; Schema: public; Owner: lmdb_adm
--

SELECT pg_catalog.setval('public.sample_sample_id_seq', 2, true);
