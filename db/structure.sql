--
-- PostgreSQL database dump
--

-- Dumped from database version 10.3
-- Dumped by pg_dump version 10.3

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


--
-- Name: btree_gin; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS btree_gin WITH SCHEMA public;


--
-- Name: EXTENSION btree_gin; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION btree_gin IS 'support for indexing common datatypes in GIN';


--
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: async_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.async_transactions (
    id integer NOT NULL,
    type character varying,
    user_uuid character varying,
    source_id character varying,
    source character varying,
    status character varying,
    transaction_id character varying,
    transaction_status character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: async_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.async_transactions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: async_transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.async_transactions_id_seq OWNED BY public.async_transactions.id;


--
-- Name: base_facilities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.base_facilities (
    unique_id character varying NOT NULL,
    name character varying NOT NULL,
    facility_type character varying NOT NULL,
    classification character varying,
    website character varying,
    lat double precision NOT NULL,
    long double precision NOT NULL,
    address jsonb,
    phone jsonb,
    hours jsonb,
    services jsonb,
    feedback jsonb,
    access jsonb,
    fingerprint character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: beta_registrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.beta_registrations (
    id integer NOT NULL,
    user_uuid character varying NOT NULL,
    feature character varying NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: beta_registrations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.beta_registrations_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: beta_registrations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.beta_registrations_id_seq OWNED BY public.beta_registrations.id;


--
-- Name: central_mail_submissions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.central_mail_submissions (
    id integer NOT NULL,
    state character varying DEFAULT 'pending'::character varying NOT NULL,
    saved_claim_id integer NOT NULL
);


--
-- Name: central_mail_submissions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.central_mail_submissions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: central_mail_submissions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.central_mail_submissions_id_seq OWNED BY public.central_mail_submissions.id;


--
-- Name: education_benefits_claims; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.education_benefits_claims (
    id integer NOT NULL,
    submitted_at timestamp without time zone,
    processed_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    encrypted_form character varying,
    encrypted_form_iv character varying,
    regional_processing_office character varying NOT NULL,
    form_type character varying DEFAULT '1990'::character varying,
    saved_claim_id integer NOT NULL
);


--
-- Name: education_benefits_claims_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.education_benefits_claims_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: education_benefits_claims_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.education_benefits_claims_id_seq OWNED BY public.education_benefits_claims.id;


--
-- Name: education_benefits_submissions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.education_benefits_submissions (
    id integer NOT NULL,
    region character varying NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    chapter33 boolean DEFAULT false NOT NULL,
    chapter30 boolean DEFAULT false NOT NULL,
    chapter1606 boolean DEFAULT false NOT NULL,
    chapter32 boolean DEFAULT false NOT NULL,
    status character varying DEFAULT 'submitted'::character varying NOT NULL,
    education_benefits_claim_id integer,
    form_type character varying DEFAULT '1990'::character varying NOT NULL,
    chapter35 boolean DEFAULT false NOT NULL,
    transfer_of_entitlement boolean DEFAULT false NOT NULL,
    chapter1607 boolean DEFAULT false NOT NULL
);


--
-- Name: education_benefits_submissions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.education_benefits_submissions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: education_benefits_submissions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.education_benefits_submissions_id_seq OWNED BY public.education_benefits_submissions.id;


--
-- Name: evss_claims; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.evss_claims (
    id integer NOT NULL,
    evss_id integer NOT NULL,
    data json NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    user_uuid character varying NOT NULL,
    list_data json DEFAULT '{}'::json NOT NULL,
    requested_decision boolean DEFAULT false NOT NULL
);


--
-- Name: evss_claims_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.evss_claims_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: evss_claims_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.evss_claims_id_seq OWNED BY public.evss_claims.id;


--
-- Name: form_attachments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.form_attachments (
    id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    guid uuid NOT NULL,
    encrypted_file_data character varying NOT NULL,
    encrypted_file_data_iv character varying NOT NULL,
    type character varying NOT NULL
);


--
-- Name: form_attachments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.form_attachments_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: form_attachments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.form_attachments_id_seq OWNED BY public.form_attachments.id;


--
-- Name: gibs_not_found_users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.gibs_not_found_users (
    id integer NOT NULL,
    edipi character varying NOT NULL,
    first_name character varying NOT NULL,
    last_name character varying NOT NULL,
    encrypted_ssn character varying NOT NULL,
    encrypted_ssn_iv character varying NOT NULL,
    dob timestamp without time zone NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: gibs_not_found_users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.gibs_not_found_users_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: gibs_not_found_users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.gibs_not_found_users_id_seq OWNED BY public.gibs_not_found_users.id;


--
-- Name: id_card_announcement_subscriptions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.id_card_announcement_subscriptions (
    id integer NOT NULL,
    email character varying NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: id_card_announcement_subscriptions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.id_card_announcement_subscriptions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: id_card_announcement_subscriptions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.id_card_announcement_subscriptions_id_seq OWNED BY public.id_card_announcement_subscriptions.id;


--
-- Name: in_progress_forms; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.in_progress_forms (
    id integer NOT NULL,
    user_uuid character varying NOT NULL,
    form_id character varying NOT NULL,
    encrypted_form_data character varying NOT NULL,
    encrypted_form_data_iv character varying NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    metadata json
);


--
-- Name: in_progress_forms_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.in_progress_forms_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: in_progress_forms_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.in_progress_forms_id_seq OWNED BY public.in_progress_forms.id;


--
-- Name: invalid_letter_address_edipis; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.invalid_letter_address_edipis (
    id integer NOT NULL,
    edipi character varying NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: invalid_letter_address_edipis_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.invalid_letter_address_edipis_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: invalid_letter_address_edipis_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.invalid_letter_address_edipis_id_seq OWNED BY public.invalid_letter_address_edipis.id;


--
-- Name: maintenance_windows; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.maintenance_windows (
    id integer NOT NULL,
    pagerduty_id character varying,
    external_service character varying,
    start_time timestamp without time zone,
    end_time timestamp without time zone,
    description character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: maintenance_windows_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.maintenance_windows_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: maintenance_windows_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.maintenance_windows_id_seq OWNED BY public.maintenance_windows.id;


--
-- Name: mhv_accounts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mhv_accounts (
    id integer NOT NULL,
    user_uuid character varying NOT NULL,
    account_state character varying NOT NULL,
    registered_at timestamp without time zone,
    upgraded_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    mhv_correlation_id character varying
);


--
-- Name: mhv_accounts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.mhv_accounts_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: mhv_accounts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.mhv_accounts_id_seq OWNED BY public.mhv_accounts.id;


--
-- Name: persistent_attachments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.persistent_attachments (
    id integer NOT NULL,
    guid uuid,
    type character varying,
    form_id character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    saved_claim_id integer,
    completed_at timestamp without time zone,
    encrypted_file_data character varying NOT NULL,
    encrypted_file_data_iv character varying NOT NULL
);


--
-- Name: persistent_attachments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.persistent_attachments_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: persistent_attachments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.persistent_attachments_id_seq OWNED BY public.persistent_attachments.id;


--
-- Name: preneed_submissions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.preneed_submissions (
    id integer NOT NULL,
    tracking_number character varying NOT NULL,
    application_uuid character varying,
    return_description character varying NOT NULL,
    return_code integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: preneed_submissions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.preneed_submissions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: preneed_submissions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.preneed_submissions_id_seq OWNED BY public.preneed_submissions.id;


--
-- Name: saved_claims; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.saved_claims (
    id integer NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    encrypted_form character varying NOT NULL,
    encrypted_form_iv character varying NOT NULL,
    form_id character varying,
    guid uuid NOT NULL,
    type character varying
);


--
-- Name: saved_claims_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.saved_claims_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: saved_claims_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.saved_claims_id_seq OWNED BY public.saved_claims.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: terms_and_conditions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.terms_and_conditions (
    id integer NOT NULL,
    name character varying,
    title character varying,
    terms_content text,
    header_content text,
    yes_content character varying,
    no_content character varying,
    footer_content character varying,
    version character varying,
    latest boolean DEFAULT false,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: terms_and_conditions_acceptances; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.terms_and_conditions_acceptances (
    user_uuid character varying,
    terms_and_conditions_id integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: terms_and_conditions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.terms_and_conditions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: terms_and_conditions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.terms_and_conditions_id_seq OWNED BY public.terms_and_conditions.id;


--
-- Name: vba_documents_upload_submissions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.vba_documents_upload_submissions (
    id integer NOT NULL,
    guid uuid NOT NULL,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    code character varying,
    detail character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: vba_documents_upload_submissions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.vba_documents_upload_submissions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: vba_documents_upload_submissions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.vba_documents_upload_submissions_id_seq OWNED BY public.vba_documents_upload_submissions.id;


--
-- Name: vic_submissions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.vic_submissions (
    id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    state character varying DEFAULT 'pending'::character varying NOT NULL,
    guid uuid NOT NULL,
    response json
);


--
-- Name: vic_submissions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.vic_submissions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: vic_submissions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.vic_submissions_id_seq OWNED BY public.vic_submissions.id;


--
-- Name: async_transactions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.async_transactions ALTER COLUMN id SET DEFAULT nextval('public.async_transactions_id_seq'::regclass);


--
-- Name: beta_registrations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.beta_registrations ALTER COLUMN id SET DEFAULT nextval('public.beta_registrations_id_seq'::regclass);


--
-- Name: central_mail_submissions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.central_mail_submissions ALTER COLUMN id SET DEFAULT nextval('public.central_mail_submissions_id_seq'::regclass);


--
-- Name: education_benefits_claims id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.education_benefits_claims ALTER COLUMN id SET DEFAULT nextval('public.education_benefits_claims_id_seq'::regclass);


--
-- Name: education_benefits_submissions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.education_benefits_submissions ALTER COLUMN id SET DEFAULT nextval('public.education_benefits_submissions_id_seq'::regclass);


--
-- Name: evss_claims id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evss_claims ALTER COLUMN id SET DEFAULT nextval('public.evss_claims_id_seq'::regclass);


--
-- Name: form_attachments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.form_attachments ALTER COLUMN id SET DEFAULT nextval('public.form_attachments_id_seq'::regclass);


--
-- Name: gibs_not_found_users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gibs_not_found_users ALTER COLUMN id SET DEFAULT nextval('public.gibs_not_found_users_id_seq'::regclass);


--
-- Name: id_card_announcement_subscriptions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.id_card_announcement_subscriptions ALTER COLUMN id SET DEFAULT nextval('public.id_card_announcement_subscriptions_id_seq'::regclass);


--
-- Name: in_progress_forms id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.in_progress_forms ALTER COLUMN id SET DEFAULT nextval('public.in_progress_forms_id_seq'::regclass);


--
-- Name: invalid_letter_address_edipis id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invalid_letter_address_edipis ALTER COLUMN id SET DEFAULT nextval('public.invalid_letter_address_edipis_id_seq'::regclass);


--
-- Name: maintenance_windows id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.maintenance_windows ALTER COLUMN id SET DEFAULT nextval('public.maintenance_windows_id_seq'::regclass);


--
-- Name: mhv_accounts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mhv_accounts ALTER COLUMN id SET DEFAULT nextval('public.mhv_accounts_id_seq'::regclass);


--
-- Name: persistent_attachments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.persistent_attachments ALTER COLUMN id SET DEFAULT nextval('public.persistent_attachments_id_seq'::regclass);


--
-- Name: preneed_submissions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.preneed_submissions ALTER COLUMN id SET DEFAULT nextval('public.preneed_submissions_id_seq'::regclass);


--
-- Name: saved_claims id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.saved_claims ALTER COLUMN id SET DEFAULT nextval('public.saved_claims_id_seq'::regclass);


--
-- Name: terms_and_conditions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.terms_and_conditions ALTER COLUMN id SET DEFAULT nextval('public.terms_and_conditions_id_seq'::regclass);


--
-- Name: vba_documents_upload_submissions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vba_documents_upload_submissions ALTER COLUMN id SET DEFAULT nextval('public.vba_documents_upload_submissions_id_seq'::regclass);


--
-- Name: vic_submissions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vic_submissions ALTER COLUMN id SET DEFAULT nextval('public.vic_submissions_id_seq'::regclass);


--
-- Name: async_transactions async_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.async_transactions
    ADD CONSTRAINT async_transactions_pkey PRIMARY KEY (id);


--
-- Name: beta_registrations beta_registrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.beta_registrations
    ADD CONSTRAINT beta_registrations_pkey PRIMARY KEY (id);


--
-- Name: central_mail_submissions central_mail_submissions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.central_mail_submissions
    ADD CONSTRAINT central_mail_submissions_pkey PRIMARY KEY (id);


--
-- Name: education_benefits_claims education_benefits_claims_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.education_benefits_claims
    ADD CONSTRAINT education_benefits_claims_pkey PRIMARY KEY (id);


--
-- Name: education_benefits_submissions education_benefits_submissions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.education_benefits_submissions
    ADD CONSTRAINT education_benefits_submissions_pkey PRIMARY KEY (id);


--
-- Name: evss_claims evss_claims_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evss_claims
    ADD CONSTRAINT evss_claims_pkey PRIMARY KEY (id);


--
-- Name: form_attachments form_attachments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.form_attachments
    ADD CONSTRAINT form_attachments_pkey PRIMARY KEY (id);


--
-- Name: gibs_not_found_users gibs_not_found_users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gibs_not_found_users
    ADD CONSTRAINT gibs_not_found_users_pkey PRIMARY KEY (id);


--
-- Name: id_card_announcement_subscriptions id_card_announcement_subscriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.id_card_announcement_subscriptions
    ADD CONSTRAINT id_card_announcement_subscriptions_pkey PRIMARY KEY (id);


--
-- Name: in_progress_forms in_progress_forms_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.in_progress_forms
    ADD CONSTRAINT in_progress_forms_pkey PRIMARY KEY (id);


--
-- Name: invalid_letter_address_edipis invalid_letter_address_edipis_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invalid_letter_address_edipis
    ADD CONSTRAINT invalid_letter_address_edipis_pkey PRIMARY KEY (id);


--
-- Name: maintenance_windows maintenance_windows_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.maintenance_windows
    ADD CONSTRAINT maintenance_windows_pkey PRIMARY KEY (id);


--
-- Name: mhv_accounts mhv_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mhv_accounts
    ADD CONSTRAINT mhv_accounts_pkey PRIMARY KEY (id);


--
-- Name: persistent_attachments persistent_attachments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.persistent_attachments
    ADD CONSTRAINT persistent_attachments_pkey PRIMARY KEY (id);


--
-- Name: preneed_submissions preneed_submissions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.preneed_submissions
    ADD CONSTRAINT preneed_submissions_pkey PRIMARY KEY (id);


--
-- Name: saved_claims saved_claims_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.saved_claims
    ADD CONSTRAINT saved_claims_pkey PRIMARY KEY (id);


--
-- Name: terms_and_conditions terms_and_conditions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.terms_and_conditions
    ADD CONSTRAINT terms_and_conditions_pkey PRIMARY KEY (id);


--
-- Name: vba_documents_upload_submissions vba_documents_upload_submissions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vba_documents_upload_submissions
    ADD CONSTRAINT vba_documents_upload_submissions_pkey PRIMARY KEY (id);


--
-- Name: vic_submissions vic_submissions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vic_submissions
    ADD CONSTRAINT vic_submissions_pkey PRIMARY KEY (id);


--
-- Name: index_async_transactions_on_source_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_async_transactions_on_source_id ON public.async_transactions USING btree (source_id);


--
-- Name: index_async_transactions_on_transaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_async_transactions_on_transaction_id ON public.async_transactions USING btree (transaction_id);


--
-- Name: index_async_transactions_on_transaction_id_and_source; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_async_transactions_on_transaction_id_and_source ON public.async_transactions USING btree (transaction_id, source);


--
-- Name: index_async_transactions_on_user_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_async_transactions_on_user_uuid ON public.async_transactions USING btree (user_uuid);


--
-- Name: index_base_facilities_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_base_facilities_on_name ON public.base_facilities USING gin (name public.gin_trgm_ops);


--
-- Name: index_base_facilities_on_unique_id_and_facility_type; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_base_facilities_on_unique_id_and_facility_type ON public.base_facilities USING btree (unique_id, facility_type);


--
-- Name: index_beta_registrations_on_user_uuid_and_feature; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_beta_registrations_on_user_uuid_and_feature ON public.beta_registrations USING btree (user_uuid, feature);


--
-- Name: index_central_mail_submissions_on_saved_claim_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_central_mail_submissions_on_saved_claim_id ON public.central_mail_submissions USING btree (saved_claim_id);


--
-- Name: index_central_mail_submissions_on_state; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_central_mail_submissions_on_state ON public.central_mail_submissions USING btree (state);


--
-- Name: index_edu_benefits_subs_ytd; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_edu_benefits_subs_ytd ON public.education_benefits_submissions USING btree (region, created_at, form_type);


--
-- Name: index_education_benefits_claim_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_education_benefits_claim_id ON public.education_benefits_submissions USING btree (education_benefits_claim_id);


--
-- Name: index_education_benefits_claims_on_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_education_benefits_claims_on_created_at ON public.education_benefits_claims USING btree (created_at);


--
-- Name: index_education_benefits_claims_on_saved_claim_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_education_benefits_claims_on_saved_claim_id ON public.education_benefits_claims USING btree (saved_claim_id);


--
-- Name: index_education_benefits_claims_on_submitted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_education_benefits_claims_on_submitted_at ON public.education_benefits_claims USING btree (submitted_at);


--
-- Name: index_evss_claims_on_user_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_evss_claims_on_user_uuid ON public.evss_claims USING btree (user_uuid);


--
-- Name: index_form_attachments_on_guid_and_type; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_form_attachments_on_guid_and_type ON public.form_attachments USING btree (guid, type);


--
-- Name: index_gibs_not_found_users_on_edipi; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_gibs_not_found_users_on_edipi ON public.gibs_not_found_users USING btree (edipi);


--
-- Name: index_id_card_announcement_subscriptions_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_id_card_announcement_subscriptions_on_email ON public.id_card_announcement_subscriptions USING btree (email);


--
-- Name: index_in_progress_forms_on_form_id_and_user_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_in_progress_forms_on_form_id_and_user_uuid ON public.in_progress_forms USING btree (form_id, user_uuid);


--
-- Name: index_invalid_letter_address_edipis_on_edipi; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invalid_letter_address_edipis_on_edipi ON public.invalid_letter_address_edipis USING btree (edipi);


--
-- Name: index_maintenance_windows_on_end_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_maintenance_windows_on_end_time ON public.maintenance_windows USING btree (end_time);


--
-- Name: index_maintenance_windows_on_pagerduty_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_maintenance_windows_on_pagerduty_id ON public.maintenance_windows USING btree (pagerduty_id);


--
-- Name: index_maintenance_windows_on_start_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_maintenance_windows_on_start_time ON public.maintenance_windows USING btree (start_time);


--
-- Name: index_mhv_accounts_on_user_uuid_and_mhv_correlation_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_mhv_accounts_on_user_uuid_and_mhv_correlation_id ON public.mhv_accounts USING btree (user_uuid, mhv_correlation_id);


--
-- Name: index_persistent_attachments_on_guid; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_persistent_attachments_on_guid ON public.persistent_attachments USING btree (guid);


--
-- Name: index_persistent_attachments_on_saved_claim_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_persistent_attachments_on_saved_claim_id ON public.persistent_attachments USING btree (saved_claim_id);


--
-- Name: index_preneed_submissions_on_application_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_preneed_submissions_on_application_uuid ON public.preneed_submissions USING btree (application_uuid);


--
-- Name: index_preneed_submissions_on_tracking_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_preneed_submissions_on_tracking_number ON public.preneed_submissions USING btree (tracking_number);


--
-- Name: index_saved_claims_on_created_at_and_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_saved_claims_on_created_at_and_type ON public.saved_claims USING btree (created_at, type);


--
-- Name: index_saved_claims_on_guid; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_saved_claims_on_guid ON public.saved_claims USING btree (guid);


--
-- Name: index_terms_and_conditions_acceptances_on_user_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_terms_and_conditions_acceptances_on_user_uuid ON public.terms_and_conditions_acceptances USING btree (user_uuid);


--
-- Name: index_terms_and_conditions_on_name_and_latest; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_terms_and_conditions_on_name_and_latest ON public.terms_and_conditions USING btree (name, latest);


--
-- Name: index_vba_documents_upload_submissions_on_guid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_vba_documents_upload_submissions_on_guid ON public.vba_documents_upload_submissions USING btree (guid);


--
-- Name: index_vba_documents_upload_submissions_on_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_vba_documents_upload_submissions_on_status ON public.vba_documents_upload_submissions USING btree (status);


--
-- Name: index_vic_submissions_on_guid; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_vic_submissions_on_guid ON public.vic_submissions USING btree (guid);


--
-- Name: unique_schema_migrations; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX unique_schema_migrations ON public.schema_migrations USING btree (version);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO schema_migrations (version) VALUES ('20160824165957');

INSERT INTO schema_migrations (version) VALUES ('20160830224945');

INSERT INTO schema_migrations (version) VALUES ('20160916202418');

INSERT INTO schema_migrations (version) VALUES ('20161003175413');

INSERT INTO schema_migrations (version) VALUES ('20161005170638');

INSERT INTO schema_migrations (version) VALUES ('20161012193544');

INSERT INTO schema_migrations (version) VALUES ('20161101142229');

INSERT INTO schema_migrations (version) VALUES ('20161102212911');

INSERT INTO schema_migrations (version) VALUES ('20161104193741');

INSERT INTO schema_migrations (version) VALUES ('20161114211400');

INSERT INTO schema_migrations (version) VALUES ('20170105181302');

INSERT INTO schema_migrations (version) VALUES ('20170105195635');

INSERT INTO schema_migrations (version) VALUES ('20170105214115');

INSERT INTO schema_migrations (version) VALUES ('20170126184940');

INSERT INTO schema_migrations (version) VALUES ('20170228013605');

INSERT INTO schema_migrations (version) VALUES ('20170329210115');

INSERT INTO schema_migrations (version) VALUES ('20170512162050');

INSERT INTO schema_migrations (version) VALUES ('20170518001612');

INSERT INTO schema_migrations (version) VALUES ('20170519153047');

INSERT INTO schema_migrations (version) VALUES ('20170601175300');

INSERT INTO schema_migrations (version) VALUES ('20170607043549');

INSERT INTO schema_migrations (version) VALUES ('20170621025522');

INSERT INTO schema_migrations (version) VALUES ('20170621122611');

INSERT INTO schema_migrations (version) VALUES ('20170626141315');

INSERT INTO schema_migrations (version) VALUES ('20170703133702');

INSERT INTO schema_migrations (version) VALUES ('20170703225400');

INSERT INTO schema_migrations (version) VALUES ('20170731142715');

INSERT INTO schema_migrations (version) VALUES ('20170802173236');

INSERT INTO schema_migrations (version) VALUES ('20170804151637');

INSERT INTO schema_migrations (version) VALUES ('20170807203358');

INSERT INTO schema_migrations (version) VALUES ('20170815231329');

INSERT INTO schema_migrations (version) VALUES ('20170815231353');

INSERT INTO schema_migrations (version) VALUES ('20170815232409');

INSERT INTO schema_migrations (version) VALUES ('20170815232444');

INSERT INTO schema_migrations (version) VALUES ('20170815233455');

INSERT INTO schema_migrations (version) VALUES ('20171026211303');

INSERT INTO schema_migrations (version) VALUES ('20171026211337');

INSERT INTO schema_migrations (version) VALUES ('20171103140150');

INSERT INTO schema_migrations (version) VALUES ('20171107181828');

INSERT INTO schema_migrations (version) VALUES ('20171107183613');

INSERT INTO schema_migrations (version) VALUES ('20171108220445');

INSERT INTO schema_migrations (version) VALUES ('20171108221458');

INSERT INTO schema_migrations (version) VALUES ('20171203010549');

INSERT INTO schema_migrations (version) VALUES ('20171203062701');

INSERT INTO schema_migrations (version) VALUES ('20171220225520');

INSERT INTO schema_migrations (version) VALUES ('20171227231018');

INSERT INTO schema_migrations (version) VALUES ('20171228003251');

INSERT INTO schema_migrations (version) VALUES ('20171229003530');

INSERT INTO schema_migrations (version) VALUES ('20180126201308');

INSERT INTO schema_migrations (version) VALUES ('20180130213405');

INSERT INTO schema_migrations (version) VALUES ('20180209160254');

INSERT INTO schema_migrations (version) VALUES ('20180216144705');

INSERT INTO schema_migrations (version) VALUES ('20180226230215');

INSERT INTO schema_migrations (version) VALUES ('20180226234916');

INSERT INTO schema_migrations (version) VALUES ('20180404214912');

INSERT INTO schema_migrations (version) VALUES ('20180404230656');

INSERT INTO schema_migrations (version) VALUES ('20180411001427');

INSERT INTO schema_migrations (version) VALUES ('20180414001259');

INSERT INTO schema_migrations (version) VALUES ('20180416231107');

INSERT INTO schema_migrations (version) VALUES ('20180423181323');

INSERT INTO schema_migrations (version) VALUES ('20180423182604');

INSERT INTO schema_migrations (version) VALUES ('20180427004001');

INSERT INTO schema_migrations (version) VALUES ('20180427004822');

INSERT INTO schema_migrations (version) VALUES ('20180503081144');

INSERT INTO schema_migrations (version) VALUES ('20180503172030');

