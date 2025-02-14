-- SPDX-FileCopyrightText: 2024 Helmholtz Centre for Environmental Research GmbH - UFZ
--
-- SPDX-License-Identifier: LicenseRef-UFZ-GPL-3.0-or-later

/*
* This script drops the table ufz_user_role.
*/

BEGIN;

DROP TABLE ufz_user_role;

--ROLLBACK;
COMMIT;

/*
-- RECOVERY CODE

BEGIN;

--
-- Name: ufz_user_role; Type: TABLE; Schema: public; Owner: lmdb_adm
--

CREATE TABLE public.ufz_user_role (
    login character varying(50) NOT NULL,
    user_role text NOT NULL
);

ALTER TABLE public.ufz_user_role OWNER TO lmdb_adm;

--
-- Data for Name: ufz_user_role; Type: TABLE DATA; Schema: public; Owner: lmdb_adm
--

INSERT INTO public.ufz_user_role (login, user_role) VALUES ('lechtenf', 'admin');
INSERT INTO public.ufz_user_role (login, user_role) VALUES ('lechtenf', 'knime');
INSERT INTO public.ufz_user_role (login, user_role) VALUES ('wurz', 'admin');

--
-- Name: ufz_user_role ufz_user_role_pkey; Type: CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.ufz_user_role
    ADD CONSTRAINT ufz_user_role_pkey PRIMARY KEY (login, user_role);

--
-- Name: ufz_user_role ufz_user_role_login_fkey; Type: FK CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.ufz_user_role
    ADD CONSTRAINT ufz_user_role_login_fkey FOREIGN KEY (login) REFERENCES public.ufz_user(login) ON DELETE CASCADE;

--
-- Name: TABLE ufz_user_role; Type: ACL; Schema: public; Owner: lmdb_adm
--

GRANT ALL ON TABLE public.ufz_user_role TO lmdb_rw;
GRANT SELECT ON TABLE public.ufz_user_role TO lmdb_ro;

ROLLBACK;
--COMMIT;
*/
