-- SPDX-FileCopyrightText: 2024 Helmholtz Centre for Environmental Research GmbH - UFZ
--
-- SPDX-License-Identifier: LicenseRef-UFZ-GPL-3.0-or-later

--
-- Data for Name: evaluation_rule; Type: TABLE DATA; Schema: public; Owner: lmdb_adm
--

INSERT INTO public.evaluation_rule (evaluation_rule_id, label, description) VALUES (23, 'Nitrogen Isotope Filter', '14N/15N isotope presence test');
INSERT INTO public.evaluation_rule (evaluation_rule_id, label, description) VALUES (24, 'Hydrogen Isotope Filter', '1H/2C isotope presence test');
INSERT INTO public.evaluation_rule (evaluation_rule_id, label, description) VALUES (26, 'CHN Series Rule', '-CH/+N homologous series rule');
INSERT INTO public.evaluation_rule (evaluation_rule_id, label, description) VALUES (27, 'CH2 Series Rule', '+CH2 homologous series rule');
INSERT INTO public.evaluation_rule (evaluation_rule_id, label, description) VALUES (28, 'OCH4 Series Rule', '-O/+CH4 homologous series rule');
INSERT INTO public.evaluation_rule (evaluation_rule_id, label, description) VALUES (51, 'Carbon Isotope Validation', '12C validation based on 12C/13C isotope ratio');
INSERT INTO public.evaluation_rule (evaluation_rule_id, label, description) VALUES (21, 'Identity', 'This rule acts as an identity function, no chemical formula will be sorted out');
INSERT INTO public.evaluation_rule (evaluation_rule_id, label, description) VALUES (52, 'My Extra Rule', 'This extra rule will be implemented using the Converter Nodes');
INSERT INTO public.evaluation_rule (evaluation_rule_id, label, description) VALUES (22, 'Carbon Isotope Filter', '12C/13C isotope presence test');
INSERT INTO public.evaluation_rule (evaluation_rule_id, label, description) VALUES (25, 'Sulphur Isotope Filter', '32S/34S isotope presence test');

--
-- Name: evaluation_rule_evaluation_rule_id_seq; Type: SEQUENCE SET; Schema: public; Owner: lmdb_adm
--

SELECT pg_catalog.setval('public.evaluation_rule_evaluation_rule_id_seq', 52, true);
