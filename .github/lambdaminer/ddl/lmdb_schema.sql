-- SPDX-FileCopyrightText: 2024 Helmholtz Centre for Environmental Research GmbH - UFZ
--
-- SPDX-License-Identifier: LicenseRef-UFZ-GPL-3.0-or-later

-- Dumped from database version 13.10
-- Dumped by pg_dump version 14.11 (Ubuntu 14.11-0ubuntu0.22.04.1)

--
-- Name: delete_results_trigger_function(); Type: FUNCTION; Schema: public; Owner: lmdb_adm
--

CREATE FUNCTION public.delete_results_trigger_function() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF OLD.calibration_method IS DISTINCT FROM NEW.calibration_method
    THEN
        DELETE FROM
            chemical_formula_assignment
        WHERE peak_id IN (
            SELECT
                peak_id
            FROM
                peak
            WHERE
                measurement = OLD.measurement_id
        );
        DELETE FROM
            measurement_cformula_config
        WHERE
            measurement_id = OLD.measurement_id
        ;
        DELETE FROM
            measurement_evaluation_config
        WHERE
            measurement_id = OLD.measurement_id
        ;
    END IF;
    IF NEW.calibration_method IS NULL
    THEN
        NEW.calibration_points = NULL;
        NEW.calibration_error = NULL;
        NEW.calibration_min_mass = NULL;
        NEW.calibration_max_mass = NULL;
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.delete_results_trigger_function() OWNER TO lmdb_adm;

--
-- Name: get_calibrated_mz(numeric, character varying, json); Type: FUNCTION; Schema: public; Owner: lmdb_adm
--

CREATE FUNCTION public.get_calibrated_mz(mz numeric, cal_type character varying, cal_params json) RETURNS numeric
    LANGUAGE plpgsql
    AS $$

DECLARE
    p0 numeric(13,8);
    p1 numeric(13,8);
    p2 numeric(13,8);
    exp_error numeric(13,8);
    cal_mz numeric(13,8);

BEGIN

    IF cal_type = 'linear' THEN
        p0 := cal_params::json -> '0';
        p1 := cal_params::json -> '1';
        exp_error := p1 * mz + p0;
        cal_mz := -( mz / ( exp_error * pow( 10, -6 ) - 1 ) );

        RETURN cal_mz;

    -- If the input calibration type is 'quadratic'
    ELSIF cal_type = 'quadratic' THEN

        p0 := cal_params::json -> '0';
        p1 := cal_params::json -> '1';
        p2 := cal_params::json -> '2';
        exp_error := p2 * pow( mz, 2 ) + p1 * mz + p0;
        cal_mz := -( mz / ( exp_error * pow( 10, -6 ) - 1 ) );

        RETURN cal_mz;

    END IF;

END;
$$;


ALTER FUNCTION public.get_calibrated_mz(mz numeric, cal_type character varying, cal_params json) OWNER TO lmdb_adm;

--
-- Name: set_replicate_of_measurement(); Type: FUNCTION; Schema: public; Owner: lmdb_adm
--

CREATE FUNCTION public.set_replicate_of_measurement() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Check if replicate_of_measurement is NULL
    IF NEW.replicate_of_measurement IS NULL THEN
        -- Set replicate_of_sample to the value of the name column
        NEW.replicate_of_measurement := NEW.measurement_id;
    END IF;

    -- Return NEW to apply the changes
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.set_replicate_of_measurement() OWNER TO lmdb_adm;

--
-- Name: set_replicate_of_sample(); Type: FUNCTION; Schema: public; Owner: lmdb_adm
--

CREATE FUNCTION public.set_replicate_of_sample() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Check if replicate_of_sample is NULL
    IF NEW.replicate_of_sample IS NULL THEN
        -- Set replicate_of_sample to the value of the name column
        NEW.replicate_of_sample := NEW.sample_id;
    END IF;

    -- Return NEW to apply the changes
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.set_replicate_of_sample() OWNER TO lmdb_adm;

--
-- Name: calibration_method; Type: TABLE; Schema: public; Owner: lmdb_adm
--

CREATE TABLE public.calibration_method (
    calibration_method_id integer NOT NULL,
    calibration_list integer NOT NULL,
    calibration_type character varying(15) NOT NULL,
    calibration_parameters json NOT NULL,
    ppm_window numeric(5,2),
    sn_threshold numeric(5,2),
    outlier_k_factor numeric(5,2),
    electron_config character varying(4) DEFAULT 'even'::character varying,
    added_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    added_by integer,
    CONSTRAINT calibration_method_calibration_type_check CHECK (((calibration_type)::text = ANY ((ARRAY['linear'::character varying, 'quadratic'::character varying])::text[]))),
    CONSTRAINT calibration_method_electron_config_check CHECK (((electron_config)::text = ANY ((ARRAY['even'::character varying, 'odd'::character varying])::text[])))
);


ALTER TABLE public.calibration_method OWNER TO lmdb_adm;

--
-- Name: measurement; Type: TABLE; Schema: public; Owner: lmdb_adm
--

CREATE TABLE public.measurement (
    measurement_id integer NOT NULL,
    spectrum_name text NOT NULL,
    spectrum_file_name text NOT NULL,
    measurement_date timestamp with time zone NOT NULL,
    measurement_method text,
    analysis_date timestamp with time zone,
    analysis_method text,
    measurement_comment text,
    scan_number integer NOT NULL,
    calibration_error numeric(5,3),
    calibration_points integer,
    calibration_min_mass numeric(13,8),
    calibration_max_mass numeric(13,8),
    peak_picking_algorithm character varying(20) NOT NULL,
    peak_picking_snthreshold numeric(7,2),
    peak_picking_intthreshold numeric(4,3),
    ionisation integer NOT NULL,
    max_intensity bigint DEFAULT 0,
    user_peak_intensity bigint DEFAULT 0,
    msms_stage integer DEFAULT 0,
    msms_mode text,
    scan_mode character varying(5) DEFAULT 'FS'::character varying,
    instrument_config character varying(10) DEFAULT 'ESI'::character varying,
    lc_rt numeric(6,2),
    lc_spectrum_number_start integer,
    lc_spectrum_number_end integer,
    fraction_number integer,
    data_size character varying(10) DEFAULT '8MW'::character varying,
    syringe_flow_rate numeric(5,0),
    capillary_voltage numeric(6,0),
    ion_accumulation_time numeric(7,4),
    q1_resolution numeric(5,1),
    q1_cid character varying(5) DEFAULT 'off'::character varying,
    q1_mass numeric(13,8),
    q1_cid_energy numeric(4,1),
    q1_isolate character varying(5) DEFAULT 'off'::character varying,
    in_source_collision_energy numeric(4,1),
    in_source_cid character varying(10) DEFAULT 'no'::character varying,
    number_of_laser_shots integer,
    laser_power numeric(6,2),
    laser_spot_size character varying(20),
    apci_temp numeric(4,1),
    nebulizer_gas_flow_rate numeric(3,1),
    drying_gas_temperature numeric(4,1),
    drying_gas_flow_rate numeric(3,1),
    maldi_isd character varying(5) DEFAULT 'off'::character varying,
    broadband_low_mass numeric(8,1),
    broadband_high_mass numeric(8,1),
    lock_masses text,
    processing_mode character varying(15),
    sample integer NOT NULL,
    replicate_of_measurement integer,
    added_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    added_by integer,
    dilution_factor numeric(5,1) DEFAULT 1.0,
    instrument integer NOT NULL,
    calibration_method bigint,
    CONSTRAINT dilution_factor_check CHECK ((dilution_factor >= 1.0)),
    CONSTRAINT measurement_data_size_check CHECK (((data_size)::text = ANY (ARRAY[('512KW'::character varying)::text, ('1MW'::character varying)::text, ('2MW'::character varying)::text, ('4MW'::character varying)::text, ('8MW'::character varying)::text]))),
    CONSTRAINT measurement_instrument_config_check CHECK (((instrument_config)::text = ANY (ARRAY[('ESI'::character varying)::text, ('Advion'::character varying)::text, ('CSpray'::character varying)::text, ('APPI'::character varying)::text, ('APCI'::character varying)::text, ('MALDI'::character varying)::text, ('AP-MALDI'::character varying)::text, ('LDI'::character varying)::text]))),
    CONSTRAINT measurement_ionisation_check CHECK ((ionisation = ANY (ARRAY['-1'::integer, 1]))),
    CONSTRAINT measurement_laser_spot_size_check CHECK (((laser_spot_size)::text = ANY (ARRAY[('minimum'::character varying)::text, ('small'::character varying)::text, ('medium'::character varying)::text, ('large'::character varying)::text, ('ultra'::character varying)::text]))),
    CONSTRAINT measurement_max_intensity_check CHECK ((max_intensity >= 0)),
    CONSTRAINT measurement_msms_stage_check CHECK (((msms_stage >= 0) AND (msms_stage <= 3))),
    CONSTRAINT measurement_peak_picking_algorithm_check CHECK (((peak_picking_algorithm)::text = ANY (ARRAY[('MRMS'::character varying)::text, ('sMRMS'::character varying)::text, ('nsMRMS'::character varying)::text, ('FTMS'::character varying)::text, ('SNAP'::character varying)::text, ('CENTROID'::character varying)::text, ('APEX'::character varying)::text]))),
    CONSTRAINT measurement_processing_mode_check CHECK (((processing_mode)::text = ANY (ARRAY[('Magnitude'::character varying)::text, ('Absorption'::character varying)::text]))),
    CONSTRAINT measurement_scan_mode_check CHECK (((scan_mode)::text = ANY (ARRAY[('FS'::character varying)::text, ('NB'::character varying)::text]))),
    CONSTRAINT measurement_scan_number_check CHECK ((scan_number > 0))
);


ALTER TABLE public.measurement OWNER TO lmdb_adm;

--
-- Name: peak; Type: TABLE; Schema: public; Owner: lmdb_adm
--

CREATE TABLE public.peak (
    peak_id bigint NOT NULL,
    measured_mass numeric(13,8) NOT NULL,
    intensity numeric(14,1),
    resolution numeric(9,1),
    adduct character varying(10),
    charge integer DEFAULT 1,
    sn numeric(8,2),
    measurement integer NOT NULL,
    added_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    added_by integer,
    CONSTRAINT peak_adduct_check CHECK (((adduct)::text = ANY (ARRAY[('isA'::character varying)::text, ('hasA'::character varying)::text]))),
    CONSTRAINT peak_charge_check CHECK ((charge >= 1)),
    CONSTRAINT peak_measured_mass_check CHECK ((measured_mass > (0)::numeric))
);


ALTER TABLE public.peak OWNER TO lmdb_adm;

--
-- Name: calibrated_peak; Type: VIEW; Schema: public; Owner: lmdb_adm
--

CREATE VIEW public.calibrated_peak AS
 SELECT p.peak_id,
    p.measured_mass,
    public.get_calibrated_mz(p.measured_mass, cm.calibration_type, cm.calibration_parameters) AS calibrated_mass,
    p.intensity,
    p.resolution,
    p.adduct,
    p.charge,
    p.sn,
    p.measurement,
    p.added_at,
    p.added_by
   FROM public.measurement m,
    public.calibration_method cm,
    public.peak p
  WHERE ((m.calibration_method = cm.calibration_method_id) AND (p.measurement = m.measurement_id));


ALTER TABLE public.calibrated_peak OWNER TO lmdb_adm;

--
-- Name: calibration_method_calibration_method_id_seq; Type: SEQUENCE; Schema: public; Owner: lmdb_adm
--

CREATE SEQUENCE public.calibration_method_calibration_method_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.calibration_method_calibration_method_id_seq OWNER TO lmdb_adm;

--
-- Name: calibration_method_calibration_method_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: lmdb_adm
--

ALTER SEQUENCE public.calibration_method_calibration_method_id_seq OWNED BY public.calibration_method.calibration_method_id;


--
-- Name: chemical_formula_assignment; Type: TABLE; Schema: public; Owner: lmdb_adm
--

CREATE TABLE public.chemical_formula_assignment (
    chemical_formula_assignment_id bigint NOT NULL,
    chemical_formula_id bigint NOT NULL,
    chemical_formula_config_id integer NOT NULL,
    peak_id bigint NOT NULL,
    relative_error numeric(13,8) NOT NULL
);


ALTER TABLE public.chemical_formula_assignment OWNER TO lmdb_adm;

--
-- Name: chemical_formula_assignment_chemical_formula_assignment_id_seq; Type: SEQUENCE; Schema: public; Owner: lmdb_adm
--

CREATE SEQUENCE public.chemical_formula_assignment_chemical_formula_assignment_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.chemical_formula_assignment_chemical_formula_assignment_id_seq OWNER TO lmdb_adm;

--
-- Name: chemical_formula_assignment_chemical_formula_assignment_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: lmdb_adm
--

ALTER SEQUENCE public.chemical_formula_assignment_chemical_formula_assignment_id_seq OWNED BY public.chemical_formula_assignment.chemical_formula_assignment_id;


--
-- Name: chemical_formula_config; Type: TABLE; Schema: public; Owner: lmdb_adm
--

CREATE TABLE public.chemical_formula_config (
    chemical_formula_config_id integer NOT NULL,
    default_config boolean DEFAULT true,
    label text NOT NULL,
    mass_range_min numeric(13,8) NOT NULL,
    mass_range_max numeric(13,8) NOT NULL,
    fault_tolerance_min numeric(13,8) NOT NULL,
    fault_tolerance_max numeric(13,8) NOT NULL,
    oc_ratio_min numeric(6,3),
    oc_ratio_max numeric(6,3),
    hc_ratio_min numeric(6,3),
    hc_ratio_max numeric(6,3),
    nc_ratio_min numeric(6,3),
    nc_ratio_max numeric(6,3),
    sc_ratio_min numeric(6,3),
    sc_ratio_max numeric(6,3),
    pc_ratio_min numeric(6,3),
    pc_ratio_max numeric(6,3),
    dbe_min numeric(6,3),
    dbe_max numeric(6,3),
    dbe_o_min numeric(6,3),
    dbe_o_max numeric(6,3),
    electron_config character varying(4) DEFAULT 'even'::character varying,
    active boolean DEFAULT true,
    library character varying(10) NOT NULL,
    CONSTRAINT chemical_formula_config_check CHECK ((mass_range_max >= mass_range_min)),
    CONSTRAINT chemical_formula_config_check1 CHECK ((fault_tolerance_max >= fault_tolerance_min)),
    CONSTRAINT chemical_formula_config_check2 CHECK ((oc_ratio_max >= oc_ratio_min)),
    CONSTRAINT chemical_formula_config_check3 CHECK ((hc_ratio_max >= hc_ratio_min)),
    CONSTRAINT chemical_formula_config_check4 CHECK ((nc_ratio_max >= nc_ratio_min)),
    CONSTRAINT chemical_formula_config_check5 CHECK ((sc_ratio_max >= sc_ratio_min)),
    CONSTRAINT chemical_formula_config_check6 CHECK ((pc_ratio_max >= pc_ratio_min)),
    CONSTRAINT chemical_formula_config_check7 CHECK ((dbe_max >= dbe_min)),
    CONSTRAINT chemical_formula_config_check8 CHECK ((dbe_o_max >= dbe_o_min)),
    CONSTRAINT chemical_formula_config_electron_config_check CHECK (((electron_config)::text = ANY (ARRAY[('even'::character varying)::text, ('odd'::character varying)::text]))),
    CONSTRAINT chemical_formula_config_hc_ratio_min_check CHECK ((hc_ratio_min >= (0)::numeric)),
    CONSTRAINT chemical_formula_config_mass_range_min_check CHECK ((mass_range_min >= (0)::numeric)),
    CONSTRAINT chemical_formula_config_nc_ratio_min_check CHECK ((nc_ratio_min >= (0)::numeric)),
    CONSTRAINT chemical_formula_config_oc_ratio_min_check CHECK ((oc_ratio_min >= (0)::numeric)),
    CONSTRAINT chemical_formula_config_pc_ratio_min_check CHECK ((pc_ratio_min >= (0)::numeric)),
    CONSTRAINT chemical_formula_config_sc_ratio_min_check CHECK ((sc_ratio_min >= (0)::numeric)),
    CONSTRAINT library_type_check CHECK (((library)::text = ANY ('{small,big}'::text[])))
);


ALTER TABLE public.chemical_formula_config OWNER TO lmdb_adm;

--
-- Name: chemical_formula_config_chemical_formula_config_id_seq; Type: SEQUENCE; Schema: public; Owner: lmdb_adm
--

CREATE SEQUENCE public.chemical_formula_config_chemical_formula_config_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.chemical_formula_config_chemical_formula_config_id_seq OWNER TO lmdb_adm;

--
-- Name: chemical_formula_config_chemical_formula_config_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: lmdb_adm
--

ALTER SEQUENCE public.chemical_formula_config_chemical_formula_config_id_seq OWNED BY public.chemical_formula_config.chemical_formula_config_id;


--
-- Name: element; Type: TABLE; Schema: public; Owner: lmdb_adm
--

CREATE TABLE public.element (
    element_id integer NOT NULL,
    symbol character varying(4) NOT NULL,
    isotope integer NOT NULL,
    exact_mass numeric(13,8) NOT NULL,
    mole_fraction numeric(7,6) NOT NULL,
    relative_abundance numeric(7,6) NOT NULL,
    valence integer NOT NULL,
    valence_2 integer NOT NULL,
    hillorder integer DEFAULT 3 NOT NULL,
    CONSTRAINT element_exact_mass_check CHECK ((exact_mass > (0)::numeric)),
    CONSTRAINT element_isotope_check CHECK ((isotope > 0)),
    CONSTRAINT element_mole_fraction_check CHECK (((mole_fraction >= (0)::numeric) AND (mole_fraction <= (1)::numeric))),
    CONSTRAINT element_relative_abundance_check CHECK (((relative_abundance >= (0)::numeric) AND (relative_abundance <= (1)::numeric))),
    CONSTRAINT element_valence_2_check CHECK ((valence_2 >= 0)),
    CONSTRAINT element_valence_check CHECK ((valence >= 0))
);


ALTER TABLE public.element OWNER TO lmdb_adm;

--
-- Name: element_cformula_config; Type: TABLE; Schema: public; Owner: lmdb_adm
--

CREATE TABLE public.element_cformula_config (
    element_id integer NOT NULL,
    chemical_formula_config_id integer NOT NULL,
    min integer NOT NULL,
    max integer NOT NULL,
    element_type character varying(20) DEFAULT 'regular'::character varying NOT NULL,
    CONSTRAINT element_cformula_config_check CHECK ((max >= min)),
    CONSTRAINT element_cformula_config_element_type_check CHECK (((element_type)::text = ANY (ARRAY[('regular'::character varying)::text, ('adduct'::character varying)::text]))),
    CONSTRAINT element_cformula_config_min_check CHECK ((min >= 0))
);


ALTER TABLE public.element_cformula_config OWNER TO lmdb_adm;

--
-- Name: element_element_id_seq; Type: SEQUENCE; Schema: public; Owner: lmdb_adm
--

CREATE SEQUENCE public.element_element_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.element_element_id_seq OWNER TO lmdb_adm;

--
-- Name: element_element_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: lmdb_adm
--

ALTER SEQUENCE public.element_element_id_seq OWNED BY public.element.element_id;


--
-- Name: eval_config_cfa; Type: TABLE; Schema: public; Owner: lmdb_adm
--

CREATE TABLE public.eval_config_cfa (
    evaluation_config_id integer NOT NULL,
    chemical_formula_assignment_id bigint NOT NULL,
    primary_score numeric(7,6) NOT NULL,
    secondary_score text,
    CONSTRAINT eval_config_cfa_primary_score_check CHECK (((primary_score >= (0)::numeric) AND (primary_score <= (1)::numeric)))
);


ALTER TABLE public.eval_config_cfa OWNER TO lmdb_adm;

--
-- Name: eval_config_eval_rule; Type: TABLE; Schema: public; Owner: lmdb_adm
--

CREATE TABLE public.eval_config_eval_rule (
    evaluation_config_id integer NOT NULL,
    evaluation_rule_id integer NOT NULL
);


ALTER TABLE public.eval_config_eval_rule OWNER TO lmdb_adm;

--
-- Name: evaluation_config; Type: TABLE; Schema: public; Owner: lmdb_adm
--

CREATE TABLE public.evaluation_config (
    evaluation_config_id integer NOT NULL,
    default_config boolean DEFAULT false,
    satisfying_config boolean DEFAULT true,
    label text NOT NULL,
    description text NOT NULL
);


ALTER TABLE public.evaluation_config OWNER TO lmdb_adm;

--
-- Name: evaluation_config_evaluation_config_id_seq; Type: SEQUENCE; Schema: public; Owner: lmdb_adm
--

CREATE SEQUENCE public.evaluation_config_evaluation_config_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.evaluation_config_evaluation_config_id_seq OWNER TO lmdb_adm;

--
-- Name: evaluation_config_evaluation_config_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: lmdb_adm
--

ALTER SEQUENCE public.evaluation_config_evaluation_config_id_seq OWNED BY public.evaluation_config.evaluation_config_id;


--
-- Name: evaluation_rule; Type: TABLE; Schema: public; Owner: lmdb_adm
--

CREATE TABLE public.evaluation_rule (
    evaluation_rule_id integer NOT NULL,
    label text NOT NULL,
    description text NOT NULL
);


ALTER TABLE public.evaluation_rule OWNER TO lmdb_adm;

--
-- Name: evaluation_rule_evaluation_rule_id_seq; Type: SEQUENCE; Schema: public; Owner: lmdb_adm
--

CREATE SEQUENCE public.evaluation_rule_evaluation_rule_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.evaluation_rule_evaluation_rule_id_seq OWNER TO lmdb_adm;

--
-- Name: evaluation_rule_evaluation_rule_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: lmdb_adm
--

ALTER SEQUENCE public.evaluation_rule_evaluation_rule_id_seq OWNED BY public.evaluation_rule.evaluation_rule_id;


--
-- Name: feature; Type: TABLE; Schema: public; Owner: lmdb_adm
--

CREATE TABLE public.feature (
    feature_id integer NOT NULL,
    name text NOT NULL,
    description text,
    type text,
    active boolean DEFAULT true NOT NULL,
    added_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    added_by integer,
    library character varying(10),
    CONSTRAINT feature_library_check CHECK (((library)::text = ANY ((ARRAY['small'::character varying, 'big'::character varying])::text[]))),
    CONSTRAINT type_check CHECK (((type IS NOT NULL) AND (type = ANY (ARRAY['calibration list'::text, 'blacklist'::text, 'molecular reactivity'::text, 'molecular indicator'::text]))))
);


ALTER TABLE public.feature OWNER TO lmdb_adm;

--
-- Name: feature_chemical_formula; Type: TABLE; Schema: public; Owner: lmdb_adm
--

CREATE TABLE public.feature_chemical_formula (
    feature_id integer NOT NULL,
    chemical_formula_id bigint NOT NULL
);


ALTER TABLE public.feature_chemical_formula OWNER TO lmdb_adm;

--
-- Name: feature_feature_id_seq; Type: SEQUENCE; Schema: public; Owner: lmdb_adm
--

CREATE SEQUENCE public.feature_feature_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.feature_feature_id_seq OWNER TO lmdb_adm;

--
-- Name: feature_feature_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: lmdb_adm
--

ALTER SEQUENCE public.feature_feature_id_seq OWNED BY public.feature.feature_id;


--
-- Name: instrument; Type: TABLE; Schema: public; Owner: lmdb_adm
--

CREATE TABLE public.instrument (
    instrument_id integer NOT NULL,
    name text NOT NULL,
    serial_number text NOT NULL,
    location text NOT NULL,
    institute text NOT NULL,
    contact_mail text NOT NULL,
    type text NOT NULL,
    model text NOT NULL,
    manufacturer text NOT NULL,
    parameters json
);


ALTER TABLE public.instrument OWNER TO lmdb_adm;

--
-- Name: instrument_instrument_id_seq; Type: SEQUENCE; Schema: public; Owner: lmdb_adm
--

CREATE SEQUENCE public.instrument_instrument_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.instrument_instrument_id_seq OWNER TO lmdb_adm;

--
-- Name: instrument_instrument_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: lmdb_adm
--

ALTER SEQUENCE public.instrument_instrument_id_seq OWNED BY public.instrument.instrument_id;


--
-- Name: location; Type: TABLE; Schema: public; Owner: lmdb_adm
--

CREATE TABLE public.location (
    location_id integer NOT NULL,
    height numeric(12,6),
    latitude numeric(8,6) NOT NULL,
    longitude numeric(9,6) NOT NULL,
    country text,
    state text,
    zipcode text,
    site_description text,
    CONSTRAINT location_latitude_check CHECK (((latitude >= ('-90'::integer)::numeric) AND (latitude <= (90)::numeric))),
    CONSTRAINT location_longitude_check CHECK (((longitude >= ('-180'::integer)::numeric) AND (longitude <= (180)::numeric)))
);


ALTER TABLE public.location OWNER TO lmdb_adm;

--
-- Name: location_location_id_seq; Type: SEQUENCE; Schema: public; Owner: lmdb_adm
--

CREATE SEQUENCE public.location_location_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.location_location_id_seq OWNER TO lmdb_adm;

--
-- Name: location_location_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: lmdb_adm
--

ALTER SEQUENCE public.location_location_id_seq OWNED BY public.location.location_id;


--
-- Name: measurement_cformula_config; Type: TABLE; Schema: public; Owner: lmdb_adm
--

CREATE TABLE public.measurement_cformula_config (
    measurement_id integer NOT NULL,
    chemical_formula_config_id integer NOT NULL,
    number_of_assignments integer NOT NULL,
    execution_time interval second,
    CONSTRAINT measurement_cformula_config_number_of_assignments_check CHECK ((number_of_assignments >= 0))
);


ALTER TABLE public.measurement_cformula_config OWNER TO lmdb_adm;

--
-- Name: measurement_evaluation_config; Type: TABLE; Schema: public; Owner: lmdb_adm
--

CREATE TABLE public.measurement_evaluation_config (
    measurement_id integer NOT NULL,
    chemical_formula_config_id integer NOT NULL,
    evaluation_config_id integer NOT NULL,
    execution_time interval second
);


ALTER TABLE public.measurement_evaluation_config OWNER TO lmdb_adm;

--
-- Name: measurement_measurement_id_seq; Type: SEQUENCE; Schema: public; Owner: lmdb_adm
--

CREATE SEQUENCE public.measurement_measurement_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.measurement_measurement_id_seq OWNER TO lmdb_adm;

--
-- Name: measurement_measurement_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: lmdb_adm
--

ALTER SEQUENCE public.measurement_measurement_id_seq OWNED BY public.measurement.measurement_id;


--
-- Name: peak_peak_id_seq; Type: SEQUENCE; Schema: public; Owner: lmdb_adm
--

CREATE SEQUENCE public.peak_peak_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.peak_peak_id_seq OWNER TO lmdb_adm;

--
-- Name: peak_peak_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: lmdb_adm
--

ALTER SEQUENCE public.peak_peak_id_seq OWNED BY public.peak.peak_id;


--
-- Name: project; Type: TABLE; Schema: public; Owner: lmdb_adm
--

CREATE TABLE public.project (
    project_id integer NOT NULL,
    name text NOT NULL,
    project_pi integer,
    added_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    added_by integer
);


ALTER TABLE public.project OWNER TO lmdb_adm;

--
-- Name: project_project_id_seq; Type: SEQUENCE; Schema: public; Owner: lmdb_adm
--

CREATE SEQUENCE public.project_project_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.project_project_id_seq OWNER TO lmdb_adm;

--
-- Name: project_project_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: lmdb_adm
--

ALTER SEQUENCE public.project_project_id_seq OWNED BY public.project.project_id;


--
-- Name: qc_method; Type: TABLE; Schema: public; Owner: lmdb_adm
--

CREATE TABLE public.qc_method (
    qc_method_id integer NOT NULL,
    added_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    added_by integer,
    instrument_config character varying(10) DEFAULT 'ESI'::character varying,
    ionisation integer NOT NULL,
    data_size character varying(10) DEFAULT '8MW'::character varying,
    processing_mode character varying(15),
    ion_accumulation_time numeric(7,4) NOT NULL,
    scan_number integer NOT NULL,
    sum_intensity bigint NOT NULL,
    feature integer NOT NULL,
    calibration_points integer,
    calibration_error numeric(5,3),
    calibration_fit_mean numeric(4,3),
    calibration_fit_sd numeric(4,3),
    calibration_plot bytea,
    instrument integer NOT NULL,
    CONSTRAINT qc_method_data_size_check CHECK (((data_size)::text = ANY (ARRAY[('512KW'::character varying)::text, ('1MW'::character varying)::text, ('2MW'::character varying)::text, ('4MW'::character varying)::text, ('8MW'::character varying)::text]))),
    CONSTRAINT qc_method_instrument_config_check CHECK (((instrument_config)::text = ANY (ARRAY[('ESI'::character varying)::text, ('Advion'::character varying)::text, ('CSpray'::character varying)::text, ('APPI'::character varying)::text, ('APCI'::character varying)::text, ('MALDI'::character varying)::text, ('AP-MALDI'::character varying)::text, ('LDI'::character varying)::text]))),
    CONSTRAINT qc_method_ionisation_check CHECK ((ionisation = ANY (ARRAY['-1'::integer, 1]))),
    CONSTRAINT qc_method_processing_mode_check CHECK (((processing_mode)::text = ANY (ARRAY[('Magnitude'::character varying)::text, ('Absorption'::character varying)::text]))),
    CONSTRAINT qc_method_scan_number_check CHECK ((scan_number > 0))
);


ALTER TABLE public.qc_method OWNER TO lmdb_adm;

--
-- Name: qc_method_qc_method_id_seq; Type: SEQUENCE; Schema: public; Owner: lmdb_adm
--

CREATE SEQUENCE public.qc_method_qc_method_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.qc_method_qc_method_id_seq OWNER TO lmdb_adm;

--
-- Name: qc_method_qc_method_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: lmdb_adm
--

ALTER SEQUENCE public.qc_method_qc_method_id_seq OWNED BY public.qc_method.qc_method_id;


--
-- Name: sample; Type: TABLE; Schema: public; Owner: lmdb_adm
--

CREATE TABLE public.sample (
    sample_id integer NOT NULL,
    sample_date timestamp with time zone,
    name text NOT NULL,
    description text,
    origin text,
    carbon_concentration numeric(10,2),
    sample_type character varying(5) NOT NULL,
    replicate_of_sample integer,
    sample_location integer,
    separation character varying(2),
    sample_preparation_date timestamp with time zone,
    sample_preparation_lot_number text,
    carbon_concentration_extract numeric(10,2),
    extract_volume numeric(10,2),
    additional_parameters json,
    project integer NOT NULL,
    sample_preparation integer,
    added_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    added_by integer,
    external_id character varying(14),
    CONSTRAINT sample_origin_check CHECK ((origin = ANY (ARRAY['aerosols'::text, 'freshwater'::text, 'groundwater'::text, 'marine'::text, 'sediment porewater'::text, 'soil extract'::text, 'soil porewater'::text, 'wastewater'::text, 'other leachate'::text, 'sediment extract'::text, 'mineral'::text, 'soil particle'::text, 'nanoparticle'::text, 'microplastics'::text]))),
    CONSTRAINT sample_sample_type_check CHECK (((sample_type)::text = ANY (ARRAY[('SMP'::character varying)::text, ('STD'::character varying)::text, ('BLK'::character varying)::text, ('QC'::character varying)::text, ('REF'::character varying)::text]))),
    CONSTRAINT sample_separation_check CHECK (((separation)::text = ANY (ARRAY[('F'::character varying)::text, ('LC'::character varying)::text])))
);


ALTER TABLE public.sample OWNER TO lmdb_adm;

--
-- Name: sample_preparation; Type: TABLE; Schema: public; Owner: lmdb_adm
--

CREATE TABLE public.sample_preparation (
    sample_preparation_id integer NOT NULL,
    sample_preparation_method text,
    sample_preparation_volume numeric(10,2),
    sorbens_size numeric(10,2),
    sorbens_type text,
    description text,
    additional_parameters json
);


ALTER TABLE public.sample_preparation OWNER TO lmdb_adm;

--
-- Name: sample_preparation_sample_preparation_id_seq; Type: SEQUENCE; Schema: public; Owner: lmdb_adm
--

CREATE SEQUENCE public.sample_preparation_sample_preparation_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sample_preparation_sample_preparation_id_seq OWNER TO lmdb_adm;

--
-- Name: sample_preparation_sample_preparation_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: lmdb_adm
--

ALTER SEQUENCE public.sample_preparation_sample_preparation_id_seq OWNED BY public.sample_preparation.sample_preparation_id;


--
-- Name: sample_sample_id_seq; Type: SEQUENCE; Schema: public; Owner: lmdb_adm
--

CREATE SEQUENCE public.sample_sample_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sample_sample_id_seq OWNER TO lmdb_adm;

--
-- Name: sample_sample_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: lmdb_adm
--

ALTER SEQUENCE public.sample_sample_id_seq OWNED BY public.sample.sample_id;


--
-- Name: ufz_user; Type: TABLE; Schema: public; Owner: lmdb_adm
--

CREATE TABLE public.ufz_user (
    user_id integer NOT NULL,
    login character varying(50) NOT NULL,
    password text,
    first_name text NOT NULL,
    last_name text NOT NULL,
    email character varying(100),
    user_role character varying(5)
);


ALTER TABLE public.ufz_user OWNER TO lmdb_adm;

--
-- Name: ufz_user_project; Type: TABLE; Schema: public; Owner: lmdb_adm
--

CREATE TABLE public.ufz_user_project (
    project_id integer NOT NULL,
    user_id integer NOT NULL
);


ALTER TABLE public.ufz_user_project OWNER TO lmdb_adm;

--
-- Name: ufz_user_role; Type: TABLE; Schema: public; Owner: lmdb_adm
--

CREATE TABLE public.ufz_user_role (
    login character varying(50) NOT NULL,
    user_role text NOT NULL
);


ALTER TABLE public.ufz_user_role OWNER TO lmdb_adm;

--
-- Name: ufz_user_user_id_seq; Type: SEQUENCE; Schema: public; Owner: lmdb_adm
--

CREATE SEQUENCE public.ufz_user_user_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ufz_user_user_id_seq OWNER TO lmdb_adm;

--
-- Name: ufz_user_user_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: lmdb_adm
--

ALTER SEQUENCE public.ufz_user_user_id_seq OWNED BY public.ufz_user.user_id;


--
-- Name: user_role; Type: TABLE; Schema: public; Owner: lmdb_adm
--

CREATE TABLE public.user_role (
    user_role_id integer NOT NULL,
    user_role character varying(5),
    num_projects integer
);


ALTER TABLE public.user_role OWNER TO lmdb_adm;

--
-- Name: user_role_user_role_id_seq; Type: SEQUENCE; Schema: public; Owner: lmdb_adm
--

CREATE SEQUENCE public.user_role_user_role_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.user_role_user_role_id_seq OWNER TO lmdb_adm;

--
-- Name: user_role_user_role_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: lmdb_adm
--

ALTER SEQUENCE public.user_role_user_role_id_seq OWNED BY public.user_role.user_role_id;


--
-- Name: calibration_method calibration_method_id; Type: DEFAULT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.calibration_method ALTER COLUMN calibration_method_id SET DEFAULT nextval('public.calibration_method_calibration_method_id_seq'::regclass);


--
-- Name: chemical_formula_assignment chemical_formula_assignment_id; Type: DEFAULT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.chemical_formula_assignment ALTER COLUMN chemical_formula_assignment_id SET DEFAULT nextval('public.chemical_formula_assignment_chemical_formula_assignment_id_seq'::regclass);


--
-- Name: chemical_formula_config chemical_formula_config_id; Type: DEFAULT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.chemical_formula_config ALTER COLUMN chemical_formula_config_id SET DEFAULT nextval('public.chemical_formula_config_chemical_formula_config_id_seq'::regclass);


--
-- Name: element element_id; Type: DEFAULT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.element ALTER COLUMN element_id SET DEFAULT nextval('public.element_element_id_seq'::regclass);


--
-- Name: evaluation_config evaluation_config_id; Type: DEFAULT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.evaluation_config ALTER COLUMN evaluation_config_id SET DEFAULT nextval('public.evaluation_config_evaluation_config_id_seq'::regclass);


--
-- Name: evaluation_rule evaluation_rule_id; Type: DEFAULT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.evaluation_rule ALTER COLUMN evaluation_rule_id SET DEFAULT nextval('public.evaluation_rule_evaluation_rule_id_seq'::regclass);


--
-- Name: feature feature_id; Type: DEFAULT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.feature ALTER COLUMN feature_id SET DEFAULT nextval('public.feature_feature_id_seq'::regclass);


--
-- Name: instrument instrument_id; Type: DEFAULT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.instrument ALTER COLUMN instrument_id SET DEFAULT nextval('public.instrument_instrument_id_seq'::regclass);


--
-- Name: location location_id; Type: DEFAULT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.location ALTER COLUMN location_id SET DEFAULT nextval('public.location_location_id_seq'::regclass);


--
-- Name: measurement measurement_id; Type: DEFAULT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.measurement ALTER COLUMN measurement_id SET DEFAULT nextval('public.measurement_measurement_id_seq'::regclass);


--
-- Name: peak peak_id; Type: DEFAULT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.peak ALTER COLUMN peak_id SET DEFAULT nextval('public.peak_peak_id_seq'::regclass);


--
-- Name: project project_id; Type: DEFAULT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.project ALTER COLUMN project_id SET DEFAULT nextval('public.project_project_id_seq'::regclass);


--
-- Name: qc_method qc_method_id; Type: DEFAULT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.qc_method ALTER COLUMN qc_method_id SET DEFAULT nextval('public.qc_method_qc_method_id_seq'::regclass);


--
-- Name: sample sample_id; Type: DEFAULT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.sample ALTER COLUMN sample_id SET DEFAULT nextval('public.sample_sample_id_seq'::regclass);


--
-- Name: sample_preparation sample_preparation_id; Type: DEFAULT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.sample_preparation ALTER COLUMN sample_preparation_id SET DEFAULT nextval('public.sample_preparation_sample_preparation_id_seq'::regclass);


--
-- Name: ufz_user user_id; Type: DEFAULT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.ufz_user ALTER COLUMN user_id SET DEFAULT nextval('public.ufz_user_user_id_seq'::regclass);


--
-- Name: user_role user_role_id; Type: DEFAULT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.user_role ALTER COLUMN user_role_id SET DEFAULT nextval('public.user_role_user_role_id_seq'::regclass);

--
-- Name: calibration_method calibration_method_pkey; Type: CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.calibration_method
    ADD CONSTRAINT calibration_method_pkey PRIMARY KEY (calibration_method_id);


--
-- Name: chemical_formula_assignment chemical_formula_assignment_chemical_formula_id_chemical_fo_key; Type: CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.chemical_formula_assignment
    ADD CONSTRAINT chemical_formula_assignment_chemical_formula_id_chemical_fo_key UNIQUE (chemical_formula_id, chemical_formula_config_id, peak_id);


--
-- Name: chemical_formula_assignment chemical_formula_assignment_pkey; Type: CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.chemical_formula_assignment
    ADD CONSTRAINT chemical_formula_assignment_pkey PRIMARY KEY (chemical_formula_assignment_id);


--
-- Name: chemical_formula_config chemical_formula_config_label_key; Type: CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.chemical_formula_config
    ADD CONSTRAINT chemical_formula_config_label_key UNIQUE (label);


--
-- Name: chemical_formula_config chemical_formula_config_pkey; Type: CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.chemical_formula_config
    ADD CONSTRAINT chemical_formula_config_pkey PRIMARY KEY (chemical_formula_config_id);


--
-- Name: element_cformula_config element_cformula_config_pkey; Type: CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.element_cformula_config
    ADD CONSTRAINT element_cformula_config_pkey PRIMARY KEY (element_id, chemical_formula_config_id);


--
-- Name: element element_pkey; Type: CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.element
    ADD CONSTRAINT element_pkey PRIMARY KEY (element_id);


--
-- Name: eval_config_cfa eval_config_cfa_pkey; Type: CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.eval_config_cfa
    ADD CONSTRAINT eval_config_cfa_pkey PRIMARY KEY (evaluation_config_id, chemical_formula_assignment_id);


--
-- Name: eval_config_eval_rule eval_config_eval_rule_pkey; Type: CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.eval_config_eval_rule
    ADD CONSTRAINT eval_config_eval_rule_pkey PRIMARY KEY (evaluation_config_id, evaluation_rule_id);


--
-- Name: evaluation_config evaluation_config_label_key; Type: CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.evaluation_config
    ADD CONSTRAINT evaluation_config_label_key UNIQUE (label);


--
-- Name: evaluation_config evaluation_config_pkey; Type: CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.evaluation_config
    ADD CONSTRAINT evaluation_config_pkey PRIMARY KEY (evaluation_config_id);


--
-- Name: evaluation_rule evaluation_rule_label_key; Type: CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.evaluation_rule
    ADD CONSTRAINT evaluation_rule_label_key UNIQUE (label);


--
-- Name: evaluation_rule evaluation_rule_pkey; Type: CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.evaluation_rule
    ADD CONSTRAINT evaluation_rule_pkey PRIMARY KEY (evaluation_rule_id);


--
-- Name: feature_chemical_formula feature_chemical_formula_pkey; Type: CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.feature_chemical_formula
    ADD CONSTRAINT feature_chemical_formula_pkey PRIMARY KEY (feature_id, chemical_formula_id);


--
-- Name: feature feature_name_key; Type: CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.feature
    ADD CONSTRAINT feature_name_key UNIQUE (name);


--
-- Name: feature feature_pkey; Type: CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.feature
    ADD CONSTRAINT feature_pkey PRIMARY KEY (feature_id);


--
-- Name: instrument instrument_name_key; Type: CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.instrument
    ADD CONSTRAINT instrument_name_key UNIQUE (name);


--
-- Name: instrument instrument_pkey; Type: CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.instrument
    ADD CONSTRAINT instrument_pkey PRIMARY KEY (instrument_id);


--
-- Name: instrument instrument_serial_number_key; Type: CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.instrument
    ADD CONSTRAINT instrument_serial_number_key UNIQUE (serial_number);


--
-- Name: location location_height_latitude_longitude_key; Type: CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.location
    ADD CONSTRAINT location_height_latitude_longitude_key UNIQUE (height, latitude, longitude);


--
-- Name: location location_pkey; Type: CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.location
    ADD CONSTRAINT location_pkey PRIMARY KEY (location_id);


--
-- Name: measurement_cformula_config measurement_cformula_config_pkey; Type: CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.measurement_cformula_config
    ADD CONSTRAINT measurement_cformula_config_pkey PRIMARY KEY (measurement_id, chemical_formula_config_id);


--
-- Name: measurement_evaluation_config measurement_evaluation_config_pkey; Type: CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.measurement_evaluation_config
    ADD CONSTRAINT measurement_evaluation_config_pkey PRIMARY KEY (measurement_id, chemical_formula_config_id, evaluation_config_id);


--
-- Name: measurement measurement_pkey; Type: CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.measurement
    ADD CONSTRAINT measurement_pkey PRIMARY KEY (measurement_id);


--
-- Name: measurement measurement_spectrum_name_key; Type: CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.measurement
    ADD CONSTRAINT measurement_spectrum_name_key UNIQUE (spectrum_name);


--
-- Name: peak peak_pkey; Type: CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.peak
    ADD CONSTRAINT peak_pkey PRIMARY KEY (peak_id);


--
-- Name: project project_name_key; Type: CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.project
    ADD CONSTRAINT project_name_key UNIQUE (name);


--
-- Name: project project_pkey; Type: CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.project
    ADD CONSTRAINT project_pkey PRIMARY KEY (project_id);


--
-- Name: qc_method qc_method_pkey; Type: CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.qc_method
    ADD CONSTRAINT qc_method_pkey PRIMARY KEY (qc_method_id);


--
-- Name: sample sample_pkey; Type: CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.sample
    ADD CONSTRAINT sample_pkey PRIMARY KEY (sample_id);


--
-- Name: sample_preparation sample_preparation_pkey; Type: CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.sample_preparation
    ADD CONSTRAINT sample_preparation_pkey PRIMARY KEY (sample_preparation_id);


--
-- Name: sample sample_project_name_key; Type: CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.sample
    ADD CONSTRAINT sample_project_name_key UNIQUE (project, name);


--
-- Name: ufz_user ufz_user_login_key; Type: CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.ufz_user
    ADD CONSTRAINT ufz_user_login_key UNIQUE (login);


--
-- Name: ufz_user ufz_user_pkey; Type: CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.ufz_user
    ADD CONSTRAINT ufz_user_pkey PRIMARY KEY (user_id);


--
-- Name: ufz_user_project ufz_user_project_pkey; Type: CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.ufz_user_project
    ADD CONSTRAINT ufz_user_project_pkey PRIMARY KEY (project_id, user_id);


--
-- Name: ufz_user_role ufz_user_role_pkey; Type: CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.ufz_user_role
    ADD CONSTRAINT ufz_user_role_pkey PRIMARY KEY (login, user_role);


--
-- Name: ufz_user unique_email_constraint; Type: CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.ufz_user
    ADD CONSTRAINT unique_email_constraint UNIQUE (email);


--
-- Name: user_role user_role_pkey; Type: CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.user_role
    ADD CONSTRAINT user_role_pkey PRIMARY KEY (user_role_id);


--
-- Name: user_role user_role_unique; Type: CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.user_role
    ADD CONSTRAINT user_role_unique UNIQUE (user_role);

--
-- Name: chemical_formula_assignment_peak_idx; Type: INDEX; Schema: public; Owner: lmdb_adm
--

CREATE INDEX chemical_formula_assignment_peak_idx ON public.chemical_formula_assignment USING btree (peak_id);


--
-- Name: eval_config_cfa_cfa_idx; Type: INDEX; Schema: public; Owner: lmdb_adm
--

CREATE INDEX eval_config_cfa_cfa_idx ON public.eval_config_cfa USING btree (chemical_formula_assignment_id);


--
-- Name: feature_chemical_formula_cf_id_idx; Type: INDEX; Schema: public; Owner: lmdb_adm
--

CREATE INDEX feature_chemical_formula_cf_id_idx ON public.feature_chemical_formula USING btree (chemical_formula_id);


--
-- Name: measurement_sample_idx; Type: INDEX; Schema: public; Owner: lmdb_adm
--

CREATE INDEX measurement_sample_idx ON public.measurement USING btree (sample);


--
-- Name: peak_measured_mass_idx; Type: INDEX; Schema: public; Owner: lmdb_adm
--

CREATE INDEX peak_measured_mass_idx ON public.peak USING btree (measured_mass);


--
-- Name: peak_measurement_idx; Type: INDEX; Schema: public; Owner: lmdb_adm
--

CREATE INDEX peak_measurement_idx ON public.peak USING btree (measurement);


--
-- Name: sample_project_idx; Type: INDEX; Schema: public; Owner: lmdb_adm
--

CREATE INDEX sample_project_idx ON public.sample USING btree (project);


--
-- Name: measurement delete_results_on_recalibration_trigger; Type: TRIGGER; Schema: public; Owner: lmdb_adm
--

CREATE TRIGGER delete_results_on_recalibration_trigger BEFORE UPDATE OF calibration_method ON public.measurement FOR EACH ROW EXECUTE FUNCTION public.delete_results_trigger_function();


--
-- Name: measurement measurement_replicate_trigger; Type: TRIGGER; Schema: public; Owner: lmdb_adm
--

CREATE TRIGGER measurement_replicate_trigger BEFORE INSERT OR UPDATE ON public.measurement FOR EACH ROW EXECUTE FUNCTION public.set_replicate_of_measurement();


--
-- Name: sample sample_replicate_trigger; Type: TRIGGER; Schema: public; Owner: lmdb_adm
--

CREATE TRIGGER sample_replicate_trigger BEFORE INSERT OR UPDATE ON public.sample FOR EACH ROW EXECUTE FUNCTION public.set_replicate_of_sample();

--
-- Name: calibration_method calibration_method_added_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.calibration_method
    ADD CONSTRAINT calibration_method_added_by_fkey FOREIGN KEY (added_by) REFERENCES public.ufz_user(user_id) ON DELETE SET NULL;


--
-- Name: calibration_method calibration_method_calibration_list_fkey; Type: FK CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.calibration_method
    ADD CONSTRAINT calibration_method_calibration_list_fkey FOREIGN KEY (calibration_list) REFERENCES public.feature(feature_id) ON DELETE RESTRICT;


--
-- Name: chemical_formula_assignment chemical_formula_assignment_chemical_formula_config_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.chemical_formula_assignment
    ADD CONSTRAINT chemical_formula_assignment_chemical_formula_config_id_fkey FOREIGN KEY (chemical_formula_config_id) REFERENCES public.chemical_formula_config(chemical_formula_config_id) ON DELETE RESTRICT;


--
-- Name: chemical_formula_assignment chemical_formula_assignment_peak_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.chemical_formula_assignment
    ADD CONSTRAINT chemical_formula_assignment_peak_id_fkey FOREIGN KEY (peak_id) REFERENCES public.peak(peak_id) ON DELETE CASCADE;


--
-- Name: element_cformula_config element_cformula_config_chemical_formula_config_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.element_cformula_config
    ADD CONSTRAINT element_cformula_config_chemical_formula_config_id_fkey FOREIGN KEY (chemical_formula_config_id) REFERENCES public.chemical_formula_config(chemical_formula_config_id) ON DELETE CASCADE;


--
-- Name: element_cformula_config element_cformula_config_element_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.element_cformula_config
    ADD CONSTRAINT element_cformula_config_element_id_fkey FOREIGN KEY (element_id) REFERENCES public.element(element_id) ON DELETE CASCADE;


--
-- Name: eval_config_cfa eval_config_cfa_chemical_formula_assignment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.eval_config_cfa
    ADD CONSTRAINT eval_config_cfa_chemical_formula_assignment_id_fkey FOREIGN KEY (chemical_formula_assignment_id) REFERENCES public.chemical_formula_assignment(chemical_formula_assignment_id) ON DELETE CASCADE;


--
-- Name: eval_config_cfa eval_config_cfa_evaluation_config_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.eval_config_cfa
    ADD CONSTRAINT eval_config_cfa_evaluation_config_id_fkey FOREIGN KEY (evaluation_config_id) REFERENCES public.evaluation_config(evaluation_config_id) ON DELETE CASCADE;


--
-- Name: eval_config_eval_rule eval_config_eval_rule_evaluation_config_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.eval_config_eval_rule
    ADD CONSTRAINT eval_config_eval_rule_evaluation_config_id_fkey FOREIGN KEY (evaluation_config_id) REFERENCES public.evaluation_config(evaluation_config_id) ON DELETE CASCADE;


--
-- Name: eval_config_eval_rule eval_config_eval_rule_evaluation_rule_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.eval_config_eval_rule
    ADD CONSTRAINT eval_config_eval_rule_evaluation_rule_id_fkey FOREIGN KEY (evaluation_rule_id) REFERENCES public.evaluation_rule(evaluation_rule_id) ON DELETE CASCADE;


--
-- Name: feature feature_added_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.feature
    ADD CONSTRAINT feature_added_by_fkey FOREIGN KEY (added_by) REFERENCES public.ufz_user(user_id) ON DELETE SET NULL;


--
-- Name: feature_chemical_formula feature_chemical_formula_feature_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.feature_chemical_formula
    ADD CONSTRAINT feature_chemical_formula_feature_id_fkey FOREIGN KEY (feature_id) REFERENCES public.feature(feature_id) ON DELETE CASCADE;


--
-- Name: measurement measurement_added_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.measurement
    ADD CONSTRAINT measurement_added_by_fkey FOREIGN KEY (added_by) REFERENCES public.ufz_user(user_id) ON DELETE SET NULL;


--
-- Name: measurement measurement_calibration_method_fkey; Type: FK CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.measurement
    ADD CONSTRAINT measurement_calibration_method_fkey FOREIGN KEY (calibration_method) REFERENCES public.calibration_method(calibration_method_id) ON DELETE RESTRICT;


--
-- Name: measurement_cformula_config measurement_cformula_config_chemical_formula_config_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.measurement_cformula_config
    ADD CONSTRAINT measurement_cformula_config_chemical_formula_config_id_fkey FOREIGN KEY (chemical_formula_config_id) REFERENCES public.chemical_formula_config(chemical_formula_config_id) ON DELETE CASCADE;


--
-- Name: measurement_cformula_config measurement_cformula_config_measurement_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.measurement_cformula_config
    ADD CONSTRAINT measurement_cformula_config_measurement_id_fkey FOREIGN KEY (measurement_id) REFERENCES public.measurement(measurement_id) ON DELETE CASCADE;


--
-- Name: measurement_evaluation_config measurement_evaluation_config_chemical_formula_config_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.measurement_evaluation_config
    ADD CONSTRAINT measurement_evaluation_config_chemical_formula_config_id_fkey FOREIGN KEY (chemical_formula_config_id) REFERENCES public.chemical_formula_config(chemical_formula_config_id) ON DELETE CASCADE;


--
-- Name: measurement_evaluation_config measurement_evaluation_config_evaluation_config_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.measurement_evaluation_config
    ADD CONSTRAINT measurement_evaluation_config_evaluation_config_id_fkey FOREIGN KEY (evaluation_config_id) REFERENCES public.evaluation_config(evaluation_config_id) ON DELETE CASCADE;


--
-- Name: measurement_evaluation_config measurement_evaluation_config_measurement_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.measurement_evaluation_config
    ADD CONSTRAINT measurement_evaluation_config_measurement_id_fkey FOREIGN KEY (measurement_id) REFERENCES public.measurement(measurement_id) ON DELETE CASCADE;


--
-- Name: measurement measurement_instrument_fkey; Type: FK CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.measurement
    ADD CONSTRAINT measurement_instrument_fkey FOREIGN KEY (instrument) REFERENCES public.instrument(instrument_id);


--
-- Name: measurement measurement_replicate_of_measurement_fkey; Type: FK CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.measurement
    ADD CONSTRAINT measurement_replicate_of_measurement_fkey FOREIGN KEY (replicate_of_measurement) REFERENCES public.measurement(measurement_id) ON DELETE SET NULL;


--
-- Name: measurement measurement_sample_fkey; Type: FK CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.measurement
    ADD CONSTRAINT measurement_sample_fkey FOREIGN KEY (sample) REFERENCES public.sample(sample_id) ON DELETE CASCADE;


--
-- Name: peak peak_added_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.peak
    ADD CONSTRAINT peak_added_by_fkey FOREIGN KEY (added_by) REFERENCES public.ufz_user(user_id) ON DELETE SET NULL;


--
-- Name: peak peak_measurement_fkey; Type: FK CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.peak
    ADD CONSTRAINT peak_measurement_fkey FOREIGN KEY (measurement) REFERENCES public.measurement(measurement_id) ON DELETE CASCADE;


--
-- Name: project project_added_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.project
    ADD CONSTRAINT project_added_by_fkey FOREIGN KEY (added_by) REFERENCES public.ufz_user(user_id) ON DELETE SET NULL;


--
-- Name: project project_project_pi_fkey; Type: FK CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.project
    ADD CONSTRAINT project_project_pi_fkey FOREIGN KEY (project_pi) REFERENCES public.ufz_user(user_id) ON DELETE SET NULL;


--
-- Name: qc_method qc_method_added_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.qc_method
    ADD CONSTRAINT qc_method_added_by_fkey FOREIGN KEY (added_by) REFERENCES public.ufz_user(user_id) ON DELETE SET NULL;


--
-- Name: qc_method qc_method_feature_fkey; Type: FK CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.qc_method
    ADD CONSTRAINT qc_method_feature_fkey FOREIGN KEY (feature) REFERENCES public.feature(feature_id) ON DELETE SET NULL;


--
-- Name: qc_method qc_method_instrument_fkey; Type: FK CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.qc_method
    ADD CONSTRAINT qc_method_instrument_fkey FOREIGN KEY (instrument) REFERENCES public.instrument(instrument_id);


--
-- Name: sample sample_added_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.sample
    ADD CONSTRAINT sample_added_by_fkey FOREIGN KEY (added_by) REFERENCES public.ufz_user(user_id) ON DELETE SET NULL;


--
-- Name: sample sample_project_fkey; Type: FK CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.sample
    ADD CONSTRAINT sample_project_fkey FOREIGN KEY (project) REFERENCES public.project(project_id) ON DELETE CASCADE;


--
-- Name: sample sample_replicate_of_sample_fkey; Type: FK CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.sample
    ADD CONSTRAINT sample_replicate_of_sample_fkey FOREIGN KEY (replicate_of_sample) REFERENCES public.sample(sample_id) ON DELETE SET NULL;


--
-- Name: sample sample_sample_location_fkey; Type: FK CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.sample
    ADD CONSTRAINT sample_sample_location_fkey FOREIGN KEY (sample_location) REFERENCES public.location(location_id) ON DELETE SET NULL;


--
-- Name: sample sample_sample_preparation_fkey; Type: FK CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.sample
    ADD CONSTRAINT sample_sample_preparation_fkey FOREIGN KEY (sample_preparation) REFERENCES public.sample_preparation(sample_preparation_id) ON DELETE SET NULL;


--
-- Name: ufz_user_project ufz_user_project_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.ufz_user_project
    ADD CONSTRAINT ufz_user_project_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.project(project_id) ON DELETE CASCADE;


--
-- Name: ufz_user_project ufz_user_project_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.ufz_user_project
    ADD CONSTRAINT ufz_user_project_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.ufz_user(user_id) ON DELETE CASCADE;


--
-- Name: ufz_user_role ufz_user_role_login_fkey; Type: FK CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.ufz_user_role
    ADD CONSTRAINT ufz_user_role_login_fkey FOREIGN KEY (login) REFERENCES public.ufz_user(login) ON DELETE CASCADE;


--
-- Name: ufz_user ufz_user_user_role_fkey; Type: FK CONSTRAINT; Schema: public; Owner: lmdb_adm
--

ALTER TABLE ONLY public.ufz_user
    ADD CONSTRAINT ufz_user_user_role_fkey FOREIGN KEY (user_role) REFERENCES public.user_role(user_role);
