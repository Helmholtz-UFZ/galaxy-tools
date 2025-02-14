-- SPDX-FileCopyrightText: 2024 Helmholtz Centre for Environmental Research GmbH - UFZ
--
-- SPDX-License-Identifier: LicenseRef-UFZ-GPL-3.0-or-later

--
-- Data for Name: evaluation_config; Type: TABLE DATA; Schema: public; Owner: lmdb_adm
--

INSERT INTO public.evaluation_config (evaluation_config_id, default_config, satisfying_config, label, description) VALUES (61, false, true, 'Standard_EC_Workshop_Test', 'Apply isotope filter for 12C/13C and 32S/34S, apply 12C validation');
INSERT INTO public.evaluation_config (evaluation_config_id, default_config, satisfying_config, label, description) VALUES (22, false, true, 'EC_Isotope_Filter_CHNS', 'Apply isotope filter for C, H, N and S.');
INSERT INTO public.evaluation_config (evaluation_config_id, default_config, satisfying_config, label, description) VALUES (23, false, true, 'EC_Homologous_Series_Rules', 'Apply homologous series rules for +CH2, -CH/+N, -O/+CH4 homologous series rules');
INSERT INTO public.evaluation_config (evaluation_config_id, default_config, satisfying_config, label, description) VALUES (95, true, true, 'EC_Isotope_Filter_CS_plus', 'Apply isotope filter for Carbon and Sulphur only');
INSERT INTO public.evaluation_config (evaluation_config_id, default_config, satisfying_config, label, description) VALUES (97, false, true, 'EC_Isotope_Filter_S', 'Apply isotope filter for 32/34S');
INSERT INTO public.evaluation_config (evaluation_config_id, default_config, satisfying_config, label, description) VALUES (98, false, true, 'EC_Isotope_Filter_CSO', 'Apply isotope filter for 12/13C, 32/34S, and 16/18O');
INSERT INTO public.evaluation_config (evaluation_config_id, default_config, satisfying_config, label, description) VALUES (99, false, true, 'EC_Isotope_Filter_CSN', 'Apply isotope filter for 12/13C, 32/34S, and 14/15N');
INSERT INTO public.evaluation_config (evaluation_config_id, default_config, satisfying_config, label, description) VALUES (100, false, true, 'EC_Isotope_Filter_CSCl', 'Apply isotope filter for 12/13C, 32/34S, and 35/37Cl');
INSERT INTO public.evaluation_config (evaluation_config_id, default_config, satisfying_config, label, description) VALUES (21, false, true, 'EC_Identity', 'Apply no evaluation configuration and keep all assignments');
INSERT INTO public.evaluation_config (evaluation_config_id, default_config, satisfying_config, label, description) VALUES (91, true, true, 'EC_Isotope_Filter_CS', 'Apply isotope filter for 12/13C and 32/34S');

--
-- Name: evaluation_config_evaluation_config_id_seq; Type: SEQUENCE SET; Schema: public; Owner: lmdb_adm
--

SELECT pg_catalog.setval('public.evaluation_config_evaluation_config_id_seq', 101, true);
