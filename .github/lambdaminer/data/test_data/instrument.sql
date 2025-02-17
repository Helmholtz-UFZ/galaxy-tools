-- SPDX-FileCopyrightText: 2024 Helmholtz Centre for Environmental Research GmbH - UFZ
--
-- SPDX-License-Identifier: LicenseRef-UFZ-GPL-3.0-or-later

--
-- Data for Name: instrument; Type: TABLE DATA; Schema: public; Owner: lmdb_adm
--

INSERT INTO public.instrument (instrument_id, name, serial_number, location, institute, contact_mail, type, model, manufacturer, parameters) VALUES (1, 'solariX-12T-2XR', '1234567-12345', 'Halle', 'Department of Chemistry', 'max.muesterman@gmail.de', 'ICR', 'solariX', 'Bruker', '{ "field_strength": "12T", "icr_cell": "2XR"}');
INSERT INTO public.instrument (instrument_id, name, serial_number, location, institute, contact_mail, type, model, manufacturer, parameters) VALUES (2, 'scimaX-7T-2XR', '1234567-12345', 'Halle', 'Department of Chemistry', 'max.muesterman@gmail.de', 'ICR', 'scimaX', 'Bruker', '{ "field_strength": "7T", "icr_cell": "2XR"}');

--
-- Name: instrument_instrument_id_seq; Type: SEQUENCE SET; Schema: public; Owner: lmdb_adm
--

SELECT pg_catalog.setval('public.instrument_instrument_id_seq', 2, true);
