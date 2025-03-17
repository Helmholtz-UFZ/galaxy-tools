-- SPDX-FileCopyrightText: 2024 Helmholtz Centre for Environmental Research GmbH - UFZ
--
-- SPDX-License-Identifier: LicenseRef-UFZ-GPL-3.0-or-later

-- Dumped from database version 13.10
-- Dumped by pg_dump version 14.11 (Ubuntu 14.11-0ubuntu0.22.04.1)

--
-- Name: cflib; Type: SCHEMA; Schema: -; Owner: cflib_adm
--

CREATE SCHEMA cflib;

ALTER SCHEMA cflib OWNER TO cflib_adm;

--
-- Name: chemical_formula; Type: TABLE; Schema: cflib; Owner: cflib_adm
--

CREATE TABLE cflib.chemical_formula (
    chemical_formula_id bigint NOT NULL,
    exact_mass numeric(13,8) NOT NULL,
    hc_ratio numeric(6,3),
    nc_ratio numeric(6,3),
    oc_ratio numeric(6,3),
    pc_ratio numeric(6,3),
    sc_ratio numeric(6,3),
    dbe numeric(6,3),
    dbe_o numeric(6,3),
    formula_json json NOT NULL,
    monoisotopic_parent bigint NOT NULL,
    CONSTRAINT chemical_formula_exact_mass_check CHECK ((exact_mass > (0)::numeric)),
    CONSTRAINT chemical_formula_hc_ratio_check CHECK ((hc_ratio >= (0)::numeric)),
    CONSTRAINT chemical_formula_nc_ratio_check CHECK ((nc_ratio >= (0)::numeric)),
    CONSTRAINT chemical_formula_oc_ratio_check CHECK ((oc_ratio >= (0)::numeric)),
    CONSTRAINT chemical_formula_pc_ratio_check CHECK ((pc_ratio >= (0)::numeric)),
    CONSTRAINT chemical_formula_sc_ratio_check CHECK ((sc_ratio >= (0)::numeric))
);

ALTER TABLE cflib.chemical_formula OWNER TO cflib_adm;

--
-- Name: do_assignments_for_peak(numeric[], numeric[], numeric[], numeric[], numeric[], numeric[], numeric[], numeric[], json); Type: FUNCTION; Schema: cflib; Owner: cflib_adm
--

CREATE FUNCTION cflib.do_assignments_for_peak(mass_range numeric[], rrange_hc numeric[], rrange_nc numeric[], rrange_oc numeric[], rrange_pc numeric[], rrange_sc numeric[], rrange_dbe numeric[], rrange_dbe_o numeric[], element_ranges json) RETURNS SETOF cflib.chemical_formula
    LANGUAGE plpgsql PARALLEL SAFE
    AS $$

DECLARE
cf_row cflib.chemical_formula%ROWTYPE;
range json;
range_c integer[];
range_13c integer[];
range_h integer[];
range_2h integer[];
range_n integer[];
range_15n integer[];
range_o integer[];
range_18o integer[];
range_p integer[];
range_s integer[];
range_34s integer[];
range_cl integer[];
range_37cl integer[];
range_na integer[];

BEGIN

/* read the element ranges */
SELECT COALESCE(element_ranges->'C', '[0,0]') INTO range;
SELECT ARRAY[((range->0)::text)::integer, ((range->1)::text)::integer] INTO range_c;
SELECT COALESCE(element_ranges->'13C', '[0,0]') INTO range;
SELECT ARRAY[((range->0)::text)::integer, ((range->1)::text)::integer] INTO range_13c;
SELECT COALESCE(element_ranges->'H', '[0,0]') INTO range;
SELECT ARRAY[((range->0)::text)::integer, ((range->1)::text)::integer] INTO range_h;
SELECT COALESCE(element_ranges->'2H', '[0,0]') INTO range;
SELECT ARRAY[((range->0)::text)::integer, ((range->1)::text)::integer] INTO range_2h;
SELECT COALESCE(element_ranges->'N', '[0,0]') INTO range;
SELECT ARRAY[((range->0)::text)::integer, ((range->1)::text)::integer] INTO range_n;
SELECT COALESCE(element_ranges->'15N', '[0,0]') INTO range;
SELECT ARRAY[((range->0)::text)::integer, ((range->1)::text)::integer] INTO range_15n;
SELECT COALESCE(element_ranges->'O', '[0,0]') INTO range;
SELECT ARRAY[((range->0)::text)::integer, ((range->1)::text)::integer] INTO range_o;
SELECT COALESCE(element_ranges->'18O', '[0,0]') INTO range;
SELECT ARRAY[((range->0)::text)::integer, ((range->1)::text)::integer] INTO range_18o;
SELECT COALESCE(element_ranges->'P', '[0,0]') INTO range;
SELECT ARRAY[((range->0)::text)::integer, ((range->1)::text)::integer] INTO range_p;
SELECT COALESCE(element_ranges->'S', '[0,0]') INTO range;
SELECT ARRAY[((range->0)::text)::integer, ((range->1)::text)::integer] INTO range_s;
SELECT COALESCE(element_ranges->'34S', '[0,0]') INTO range;
SELECT ARRAY[((range->0)::text)::integer, ((range->1)::text)::integer] INTO range_34s;
SELECT COALESCE(element_ranges->'Cl', '[0,0]') INTO range;
SELECT ARRAY[((range->0)::text)::integer, ((range->1)::text)::integer] INTO range_cl;
SELECT COALESCE(element_ranges->'37Cl', '[0,0]') INTO range;
SELECT ARRAY[((range->0)::text)::integer, ((range->1)::text)::integer] INTO range_37cl;
SELECT COALESCE(element_ranges->'Na', '[0,0]') INTO range;
SELECT ARRAY[((range->0)::text)::integer, ((range->1)::text)::integer] INTO range_na;

/* do the assignment */
FOR cf_row IN
SELECT *
FROM cflib.chemical_formula cf

/*
following statements are less time consuming than the blow
approx. 15 % of the total execution time
*/
WHERE cf.exact_mass BETWEEN mass_range[1] AND mass_range[2]
AND cf.hc_ratio BETWEEN rrange_hc[1] AND rrange_hc[2]
AND cf.nc_ratio BETWEEN rrange_nc[1] AND rrange_nc[2]
AND cf.oc_ratio BETWEEN rrange_oc[1] AND rrange_oc[2]
AND cf.pc_ratio BETWEEN rrange_pc[1] AND rrange_pc[2]
AND cf.sc_ratio BETWEEN rrange_sc[1] AND rrange_sc[2]
AND cf.dbe BETWEEN rrange_dbe[1] AND rrange_dbe[2]
AND cf.dbe_o BETWEEN rrange_dbe_o[1] AND rrange_dbe_o[2]

/*
following statements are more time consuming than the above
approx. 9/10 of the total execution time
filter from infrequent to frequent elements/isotopes to reduce execution times
*/
AND COALESCE(((cf.formula_json->0->'Na')::text)::integer, 0) BETWEEN range_na[1] AND range_na[2]
AND COALESCE(((cf.formula_json->0->'2H')::text)::integer, 0) BETWEEN range_2h[1] AND range_2h[2]
AND COALESCE(((cf.formula_json->0->'37Cl')::text)::integer, 0) BETWEEN range_37cl[1] AND range_37cl[2]
AND COALESCE(((cf.formula_json->0->'34S')::text)::integer, 0) BETWEEN range_34s[1] AND range_34s[2]
AND COALESCE(((cf.formula_json->0->'18O')::text)::integer, 0) BETWEEN range_18o[1] AND range_18o[2]
AND COALESCE(((cf.formula_json->0->'15N')::text)::integer, 0) BETWEEN range_15n[1] AND range_15n[2]
AND COALESCE(((cf.formula_json->0->'13C')::text)::integer, 0) BETWEEN range_13c[1] AND range_13c[2]
AND COALESCE(((cf.formula_json->0->'Cl')::text)::integer, 0) BETWEEN range_cl[1] AND range_cl[2]
AND COALESCE(((cf.formula_json->0->'P')::text)::integer, 0) BETWEEN range_p[1] AND range_p[2]
AND COALESCE(((cf.formula_json->0->'S')::text)::integer, 0) BETWEEN range_s[1] AND range_s[2]
AND COALESCE(((cf.formula_json->0->'N')::text)::integer, 0) BETWEEN range_n[1] AND range_n[2]
AND COALESCE(((cf.formula_json->0->'O')::text)::integer, 0) BETWEEN range_o[1] AND range_o[2]
AND COALESCE(((cf.formula_json->0->'H')::text)::integer, 0) BETWEEN range_h[1] AND range_h[2]
AND COALESCE(((cf.formula_json->0->'C')::text)::integer, 0) BETWEEN range_c[1] AND range_c[2]

LOOP
RETURN NEXT cf_row;
END LOOP;
END;
$$;

ALTER FUNCTION cflib.do_assignments_for_peak(mass_range numeric[], rrange_hc numeric[], rrange_nc numeric[], rrange_oc numeric[], rrange_pc numeric[], rrange_sc numeric[], rrange_dbe numeric[], rrange_dbe_o numeric[], element_ranges json) OWNER TO cflib_adm;

--
-- Name: chemical_formula chemical_formula_pkey; Type: CONSTRAINT; Schema: cflib; Owner: lmdb_adm
--

ALTER TABLE cflib.chemical_formula ADD CONSTRAINT chemical_formula_pkey PRIMARY KEY (chemical_formula_id);

--
-- Name: chemical_formula_exact_mass_idx; Type: INDEX; Schema: cflib; Owner: lmdb_adm
--

CREATE INDEX chemical_formula_exact_mass_idx ON cflib.chemical_formula USING btree (exact_mass);

--
-- Name: chemical_formula_monoisotopic_parent_idx; Type: INDEX; Schema: cflib; Owner: lmdb_adm
--

CREATE INDEX chemical_formula_monoisotopic_parent_idx ON cflib.chemical_formula USING btree (monoisotopic_parent);

--
-- Name: chemical_formula chemical_formula_monoisotopic_parent_fkey; Type: FK CONSTRAINT; Schema: cflib; Owner: lmdb_adm
--

ALTER TABLE cflib.chemical_formula ADD CONSTRAINT chemical_formula_monoisotopic_parent_fkey FOREIGN KEY (monoisotopic_parent) REFERENCES cflib.chemical_formula(chemical_formula_id) ON DELETE CASCADE;
