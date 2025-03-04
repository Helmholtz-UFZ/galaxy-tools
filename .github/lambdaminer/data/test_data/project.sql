-- SPDX-FileCopyrightText: 2024 Helmholtz Centre for Environmental Research GmbH - UFZ
--
-- SPDX-License-Identifier: LicenseRef-UFZ-GPL-3.0-or-later

--
-- Data for Name: project; Type: TABLE DATA; Schema: public; Owner: lmdb_adm
--

INSERT INTO public.project (project_id, name, project_pi, added_at, added_by) VALUES (1, '2024_BGO_TestProject', 2, '2016-06-22 09:45:00+00', 2);
INSERT INTO public.project (project_id, name, project_pi, added_at, added_by) VALUES (2, '2025_BGO_TestProject', 2, '2025-02-25 09:45:00+00', 2);

--
-- Name: project_project_id_seq; Type: SEQUENCE SET; Schema: public; Owner: lmdb_adm
--

SELECT pg_catalog.setval('public.project_project_id_seq', 2, true);
