-- SPDX-FileCopyrightText: 2024 Helmholtz Centre for Environmental Research GmbH - UFZ
--
-- SPDX-License-Identifier: LicenseRef-UFZ-GPL-3.0-or-later

--
-- Data for Name: location; Type: TABLE DATA; Schema: public; Owner: lmdb_adm
--

INSERT INTO public.location (location_id, height, latitude, longitude, country, state, zipcode, site_description) VALUES (1, 12.000000, 51.340199, 12.360103, 'Germany', 'Sachsen', '04318', 'Leipzig');
INSERT INTO public.location (location_id, height, latitude, longitude, country, state, zipcode, site_description) VALUES (2, NULL, 51.867139, 10.870583, 'Germany', 'Sachsen-Anhalt', '38855', 'Holtemme, downstream of WWTP Silstedt');
INSERT INTO public.location (location_id, height, latitude, longitude, country, state, zipcode, site_description) VALUES (3, NULL, 29.288333, -83.165833, 'USA', 'Florida', '4131', 'Dummy Site Description for SRFA');
INSERT INTO public.location (location_id, height, latitude, longitude, country, state, zipcode, site_description) VALUES (5, NULL, 29.288333, -83.165833, 'USA', 'Florida', '4131', 'Test Site Description');

--
-- Name: location_location_id_seq; Type: SEQUENCE SET; Schema: public; Owner: lmdb_adm
--

SELECT pg_catalog.setval('public.location_location_id_seq', 5, true);
