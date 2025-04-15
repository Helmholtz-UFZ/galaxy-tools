-- SPDX-FileCopyrightText: 2025 Helmholtz Centre for Environmental Research GmbH - UFZ
--
-- SPDX-License-Identifier: LicenseRef-UFZ-GPL-3.0-or-later

--
-- Data for Name: ufz_user; Type: TABLE DATA; Schema: public; Owner: lmdb_adm
--

INSERT INTO public.ufz_user (user_id, login, password, first_name, last_name, email, user_role) VALUES (1, 'dummy_adm', NULL, 'Dummy', 'Admin', NULL, 'adm');
INSERT INTO public.ufz_user (user_id, login, password, first_name, last_name, email, user_role) VALUES (2, 'dummy_bgo', NULL, 'Dummy', 'BGO', NULL, 'bgo');
INSERT INTO public.ufz_user (user_id, login, password, first_name, last_name, email, user_role) VALUES (3, 'dummy_int', NULL, 'Dummy', 'Internal', NULL, 'int');
INSERT INTO public.ufz_user (user_id, login, password, first_name, last_name, email, user_role) VALUES (4, 'dummy_ext', NULL, 'Dummy', 'External', NULL, 'ext');
INSERT INTO public.ufz_user (user_id, login, password, first_name, last_name, email, user_role) VALUES (5, 'dummy_ina', NULL, 'Dummy', 'Inactive', NULL, 'ina');
INSERT INTO public.ufz_user (user_id, login, password, first_name, last_name, email, user_role) VALUES (6, 'musterm', '35861e5875cf95bb595324a999c6f208964cdfe6fdf37fea20c0187c0b4213c75c0b88317c6798be9c92e5e3facbd8f57630f1a50d65e6d21ab3eb3e6fe32acd', 'Max', 'Mustermann', NULL, 'bgo');
INSERT INTO public.ufz_user (user_id, login, password, first_name, last_name, email, user_role) VALUES (7, 'planemo', NULL, 'Planemo', 'Test', NULL, 'bgo');

--
-- Name: ufz_user_user_id_seq; Type: SEQUENCE SET; Schema: public; Owner: lmdb_adm
--

SELECT pg_catalog.setval('public.ufz_user_user_id_seq', 7, true);
