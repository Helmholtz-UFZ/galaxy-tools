-- SPDX-FileCopyrightText: 2024 Helmholtz Centre for Environmental Research GmbH - UFZ
--
-- SPDX-License-Identifier: LicenseRef-UFZ-GPL-3.0-or-later

--
-- Data for Name: user_role; Type: TABLE DATA; Schema: public; Owner: lmdb_adm
--

INSERT INTO public.user_role (user_role_id, user_role, num_projects) VALUES (1, 'adm', 2147483647);
INSERT INTO public.user_role (user_role_id, user_role, num_projects) VALUES (2, 'bgo', 10);
INSERT INTO public.user_role (user_role_id, user_role, num_projects) VALUES (3, 'int', 3);
INSERT INTO public.user_role (user_role_id, user_role, num_projects) VALUES (4, 'ext', 1);
INSERT INTO public.user_role (user_role_id, user_role, num_projects) VALUES (5, 'ina', -2147483648);

--
-- Name: user_role_user_role_id_seq; Type: SEQUENCE SET; Schema: public; Owner: lmdb_adm
--

SELECT pg_catalog.setval('public.user_role_user_role_id_seq', 5, true);
