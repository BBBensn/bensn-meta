--
-- PostgreSQL database dump
--

\restrict IMBe0IqPJYcfBxi8FOl4rTyExHZubdpqeCYg5EQWWHcJOI9TLwfCVXngpX6j29f

-- Dumped from database version 16.13
-- Dumped by pg_dump version 16.13

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- Name: save_correction(text, uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.save_correction(table_name text, record_id uuid, reason text) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Wird von der API verwendet, die vorher den Snapshot macht
    -- Placeholder für spätere Implementierung
    RAISE NOTICE 'Correction logged for % / %', table_name, record_id;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: breaks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.breaks (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    shift_id uuid NOT NULL,
    break_start timestamp with time zone NOT NULL,
    break_end timestamp with time zone,
    duration_minutes integer GENERATED ALWAYS AS (
CASE
    WHEN (break_end IS NOT NULL) THEN ((EXTRACT(epoch FROM (break_end - break_start)))::integer / 60)
    ELSE NULL::integer
END) STORED,
    break_type character varying(50),
    zig_spicy integer DEFAULT 0,
    zig_blend integer DEFAULT 0,
    notes text,
    corrected boolean DEFAULT false,
    corrected_at timestamp with time zone,
    corrected_reason text,
    original_data jsonb,
    created_at timestamp with time zone DEFAULT now(),
    source character varying(20) DEFAULT 'shortcut'::character varying,
    deleted boolean DEFAULT false
);


--
-- Name: shifts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.shifts (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    work_start timestamp with time zone NOT NULL,
    work_end timestamp with time zone,
    duration_minutes integer GENERATED ALWAYS AS (
CASE
    WHEN (work_end IS NOT NULL) THEN ((EXTRACT(epoch FROM (work_end - work_start)))::integer / 60)
    ELSE NULL::integer
END) STORED,
    shift_type character varying(20) NOT NULL,
    station character varying(50) NOT NULL,
    service_label character varying(100),
    is_duo_service boolean DEFAULT false,
    duo_partner_station character varying(50),
    has_training boolean DEFAULT false,
    training_note text,
    training_start timestamp with time zone,
    training_end timestamp with time zone,
    notes text,
    corrected boolean DEFAULT false,
    corrected_at timestamp with time zone,
    corrected_reason text,
    original_data jsonb,
    created_at timestamp with time zone DEFAULT now(),
    source character varying(20) DEFAULT 'shortcut'::character varying,
    cafe_puls boolean DEFAULT false,
    deleted boolean DEFAULT false,
    CONSTRAINT shifts_shift_type_check CHECK (((shift_type)::text = ANY ((ARRAY['früh'::character varying, 'nachmittag'::character varying, 'nacht'::character varying])::text[])))
);


--
-- Name: current_shift; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.current_shift AS
 SELECT id,
    work_start,
    work_end,
    duration_minutes,
    shift_type,
    station,
    service_label,
    is_duo_service,
    duo_partner_station,
    has_training,
    training_note,
    training_start,
    training_end,
    notes,
    corrected,
    corrected_at,
    corrected_reason,
    original_data,
    created_at,
    source,
    COALESCE(( SELECT sum(b.duration_minutes) AS sum
           FROM public.breaks b
          WHERE ((b.shift_id = s.id) AND (b.break_end IS NOT NULL))), (0)::bigint) AS total_break_minutes,
    ( SELECT count(*) AS count
           FROM public.breaks b
          WHERE (b.shift_id = s.id)) AS break_count,
    ( SELECT sum(b.zig_spicy) AS sum
           FROM public.breaks b
          WHERE (b.shift_id = s.id)) AS total_zig_spicy,
    ( SELECT sum(b.zig_blend) AS sum
           FROM public.breaks b
          WHERE (b.shift_id = s.id)) AS total_zig_blend
   FROM public.shifts s
  WHERE ((work_end IS NULL) AND (work_start > (now() - '16:00:00'::interval)))
  ORDER BY work_start DESC
 LIMIT 1;


--
-- Name: daily_summary; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.daily_summary AS
 SELECT date(s.work_start) AS date,
    count(s.id) AS shift_count,
    sum(s.duration_minutes) AS total_work_minutes,
    sum(sub.total_break_minutes) AS total_break_minutes,
    sum(sub.total_zig_spicy) AS total_zig_spicy,
    sum(sub.total_zig_blend) AS total_zig_blend,
    array_agg(s.shift_type) AS shift_types,
    array_agg(s.station) AS stations
   FROM (public.shifts s
     LEFT JOIN ( SELECT breaks.shift_id,
            COALESCE(sum(breaks.duration_minutes), (0)::bigint) AS total_break_minutes,
            COALESCE(sum(breaks.zig_spicy), (0)::bigint) AS total_zig_spicy,
            COALESCE(sum(breaks.zig_blend), (0)::bigint) AS total_zig_blend
           FROM public.breaks
          GROUP BY breaks.shift_id) sub ON ((sub.shift_id = s.id)))
  WHERE (s.work_end IS NOT NULL)
  GROUP BY (date(s.work_start))
  ORDER BY (date(s.work_start)) DESC;


--
-- Name: feed_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.feed_items (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    "timestamp" timestamp with time zone NOT NULL,
    item_type character varying(30) NOT NULL,
    reference_id uuid,
    reference_table character varying(50),
    title text,
    preview_text text,
    icon text,
    color character varying(7),
    metadata jsonb DEFAULT '{}'::jsonb,
    pinned boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: health_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.health_logs (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    "timestamp" timestamp with time zone DEFAULT now() NOT NULL,
    date date DEFAULT CURRENT_DATE NOT NULL,
    steps integer,
    weight_kg numeric(5,2),
    heart_rate_avg integer,
    medications jsonb DEFAULT '[]'::jsonb,
    notes text,
    source character varying(20) DEFAULT 'shortcut'::character varying
);


--
-- Name: library_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.library_items (
    id integer NOT NULL,
    jellyfin_id text NOT NULL,
    item_type text NOT NULL,
    title text NOT NULL,
    series_title text,
    series_jellyfin_id text,
    season_number integer,
    episode_number integer,
    year integer,
    container text,
    video_codec text,
    audio_codec text,
    audio_languages text,
    resolution text,
    file_size_bytes bigint,
    synced_at timestamp without time zone DEFAULT now()
);


--
-- Name: library_items_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.library_items_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: library_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.library_items_id_seq OWNED BY public.library_items.id;


--
-- Name: location_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.location_logs (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    "timestamp" timestamp with time zone DEFAULT now() NOT NULL,
    latitude numeric(10,7),
    longitude numeric(10,7),
    accuracy numeric(8,2),
    altitude numeric(8,2),
    city character varying(100),
    district character varying(100),
    country character varying(50),
    context character varying(50),
    shift_id uuid,
    source character varying(20) DEFAULT 'shortcut'::character varying,
    velocity numeric(6,2),
    battery smallint,
    device_id character varying(100),
    temperature numeric(5,2),
    apparent_temp numeric(5,2),
    precipitation numeric(6,2),
    weather_code smallint,
    weather_desc character varying(50),
    cloudcover smallint,
    windspeed numeric(5,1),
    is_day boolean
);


--
-- Name: location_stays; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.location_stays (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    start_time timestamp with time zone NOT NULL,
    end_time timestamp with time zone NOT NULL,
    duration_minutes numeric(8,1),
    latitude numeric(10,7),
    longitude numeric(10,7),
    city character varying(100),
    district character varying(100),
    country character varying(50),
    name character varying(200),
    point_count integer,
    avg_accuracy numeric(8,2),
    avg_temperature numeric(5,2),
    weather_desc character varying(50),
    source character varying(20) DEFAULT 'auto'::character varying,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: mood_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mood_logs (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    "timestamp" timestamp with time zone DEFAULT now() NOT NULL,
    mood_score smallint,
    energy_score smallint,
    anxiety_score smallint,
    tags text[],
    notes text,
    shift_id uuid,
    source character varying(20) DEFAULT 'shortcut'::character varying,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT mood_logs_anxiety_score_check CHECK (((anxiety_score >= 1) AND (anxiety_score <= 10))),
    CONSTRAINT mood_logs_energy_score_check CHECK (((energy_score >= 1) AND (energy_score <= 10))),
    CONSTRAINT mood_logs_mood_score_check CHECK (((mood_score >= 1) AND (mood_score <= 10)))
);


--
-- Name: obsidian_entries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.obsidian_entries (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    file_path text NOT NULL,
    title text NOT NULL,
    entry_date timestamp with time zone,
    created_at_obs timestamp with time zone,
    modified_at_obs timestamp with time zone,
    entry_type character varying(50),
    folder character varying(100),
    frontmatter jsonb DEFAULT '{}'::jsonb,
    content_preview text,
    content_full text,
    word_count integer,
    tags text[],
    css_class text,
    show_in_feed boolean DEFAULT true,
    pinned boolean DEFAULT false,
    last_synced timestamp with time zone DEFAULT now(),
    file_hash text,
    synced_at timestamp with time zone DEFAULT now()
);


--
-- Name: shares; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.shares (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    token text DEFAULT translate(encode(public.gen_random_bytes(24), 'base64'::text), '+/='::text, '-_'::text) NOT NULL,
    label text NOT NULL,
    allowed_types text[],
    blocked_types text[],
    blocked_wikilinks text[],
    date_from date,
    date_to date,
    include_work boolean DEFAULT true NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: sleep_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sleep_logs (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    date date NOT NULL,
    sleep_start timestamp with time zone,
    sleep_end timestamp with time zone,
    duration_minutes integer,
    quality smallint,
    notes text,
    corrected boolean DEFAULT false,
    corrected_at timestamp with time zone,
    original_data jsonb,
    created_at timestamp with time zone DEFAULT now(),
    source character varying(20) DEFAULT 'shortcut'::character varying,
    CONSTRAINT sleep_logs_quality_check CHECK (((quality >= 1) AND (quality <= 5)))
);


--
-- Name: tracking_categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tracking_categories (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    name character varying(50) NOT NULL,
    emoji character varying(10) DEFAULT '📦'::character varying,
    color character varying(20) DEFAULT 'muted'::character varying,
    sort_order integer DEFAULT 0,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: tracking_entries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tracking_entries (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    item_id character varying(50) NOT NULL,
    category character varying(50) NOT NULL,
    name character varying(100) NOT NULL,
    amount numeric(10,3) NOT NULL,
    unit character varying(20) NOT NULL,
    entry_type character varying(20) NOT NULL,
    date date NOT NULL,
    note text,
    created_at timestamp with time zone DEFAULT now(),
    "timestamp" timestamp with time zone DEFAULT now(),
    source character varying(20) DEFAULT 'pwa'::character varying,
    deleted boolean DEFAULT false,
    CONSTRAINT tracking_entries_entry_type_check CHECK (((entry_type)::text = ANY (ARRAY[('bestand'::character varying)::text, ('zaehler'::character varying)::text, ('auffuellung'::character varying)::text, ('entnahme'::character varying)::text, ('delta'::character varying)::text])))
);


--
-- Name: tracking_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tracking_items (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    category_id uuid NOT NULL,
    slug character varying(50),
    name character varying(100) NOT NULL,
    tracking_mode character varying(10) DEFAULT 'zaehler'::character varying NOT NULL,
    base_unit character varying(20) DEFAULT 'Stk.'::character varying NOT NULL,
    unit_size numeric(10,3) DEFAULT 1,
    presets text DEFAULT ''::text,
    sort_order integer DEFAULT 0,
    active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    counter_direction character varying(1) DEFAULT '+'::character varying,
    pack_unit character varying(20) DEFAULT NULL::character varying,
    pack_size numeric(10,3) DEFAULT NULL::numeric,
    buttons jsonb DEFAULT '[]'::jsonb,
    linked_items jsonb DEFAULT '[]'::jsonb,
    CONSTRAINT tracking_items_tracking_mode_check CHECK (((tracking_mode)::text = ANY ((ARRAY['bestand'::character varying, 'zaehler'::character varying, 'vorrat'::character varying])::text[])))
);


--
-- Name: wishlist_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.wishlist_items (
    id integer NOT NULL,
    title text NOT NULL,
    type text,
    requested_by text,
    note text,
    priority text DEFAULT 'low'::text,
    status text DEFAULT 'open'::text,
    created_at timestamp without time zone DEFAULT now()
);


--
-- Name: wishlist_items_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.wishlist_items_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: wishlist_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.wishlist_items_id_seq OWNED BY public.wishlist_items.id;


--
-- Name: library_items id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.library_items ALTER COLUMN id SET DEFAULT nextval('public.library_items_id_seq'::regclass);


--
-- Name: wishlist_items id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wishlist_items ALTER COLUMN id SET DEFAULT nextval('public.wishlist_items_id_seq'::regclass);


--
-- Name: breaks breaks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.breaks
    ADD CONSTRAINT breaks_pkey PRIMARY KEY (id);


--
-- Name: feed_items feed_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.feed_items
    ADD CONSTRAINT feed_items_pkey PRIMARY KEY (id);


--
-- Name: health_logs health_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.health_logs
    ADD CONSTRAINT health_logs_pkey PRIMARY KEY (id);


--
-- Name: library_items library_items_jellyfin_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.library_items
    ADD CONSTRAINT library_items_jellyfin_id_key UNIQUE (jellyfin_id);


--
-- Name: library_items library_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.library_items
    ADD CONSTRAINT library_items_pkey PRIMARY KEY (id);


--
-- Name: location_logs location_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.location_logs
    ADD CONSTRAINT location_logs_pkey PRIMARY KEY (id);


--
-- Name: location_stays location_stays_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.location_stays
    ADD CONSTRAINT location_stays_pkey PRIMARY KEY (id);


--
-- Name: mood_logs mood_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mood_logs
    ADD CONSTRAINT mood_logs_pkey PRIMARY KEY (id);


--
-- Name: obsidian_entries obsidian_entries_file_path_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.obsidian_entries
    ADD CONSTRAINT obsidian_entries_file_path_key UNIQUE (file_path);


--
-- Name: obsidian_entries obsidian_entries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.obsidian_entries
    ADD CONSTRAINT obsidian_entries_pkey PRIMARY KEY (id);


--
-- Name: shares shares_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shares
    ADD CONSTRAINT shares_pkey PRIMARY KEY (id);


--
-- Name: shares shares_token_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shares
    ADD CONSTRAINT shares_token_key UNIQUE (token);


--
-- Name: shifts shifts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shifts
    ADD CONSTRAINT shifts_pkey PRIMARY KEY (id);


--
-- Name: sleep_logs sleep_logs_date_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sleep_logs
    ADD CONSTRAINT sleep_logs_date_key UNIQUE (date);


--
-- Name: sleep_logs sleep_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sleep_logs
    ADD CONSTRAINT sleep_logs_pkey PRIMARY KEY (id);


--
-- Name: tracking_categories tracking_categories_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tracking_categories
    ADD CONSTRAINT tracking_categories_name_key UNIQUE (name);


--
-- Name: tracking_categories tracking_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tracking_categories
    ADD CONSTRAINT tracking_categories_pkey PRIMARY KEY (id);


--
-- Name: tracking_entries tracking_entries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tracking_entries
    ADD CONSTRAINT tracking_entries_pkey PRIMARY KEY (id);


--
-- Name: tracking_items tracking_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tracking_items
    ADD CONSTRAINT tracking_items_pkey PRIMARY KEY (id);


--
-- Name: tracking_items tracking_items_slug_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tracking_items
    ADD CONSTRAINT tracking_items_slug_key UNIQUE (slug);


--
-- Name: wishlist_items wishlist_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wishlist_items
    ADD CONSTRAINT wishlist_items_pkey PRIMARY KEY (id);


--
-- Name: idx_breaks_shift_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_breaks_shift_id ON public.breaks USING btree (shift_id);


--
-- Name: idx_feed_items_timestamp; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_feed_items_timestamp ON public.feed_items USING btree ("timestamp" DESC);


--
-- Name: idx_feed_items_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_feed_items_type ON public.feed_items USING btree (item_type);


--
-- Name: idx_library_items_series; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_library_items_series ON public.library_items USING btree (series_jellyfin_id);


--
-- Name: idx_location_stays_start; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_location_stays_start ON public.location_stays USING btree (start_time DESC);


--
-- Name: idx_mood_logs_timestamp; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_mood_logs_timestamp ON public.mood_logs USING btree ("timestamp" DESC);


--
-- Name: idx_obsidian_content; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_obsidian_content ON public.obsidian_entries USING gin (to_tsvector('german'::regconfig, COALESCE(content_preview, ''::text)));


--
-- Name: idx_obsidian_entry_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_obsidian_entry_date ON public.obsidian_entries USING btree (entry_date DESC);


--
-- Name: idx_obsidian_entry_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_obsidian_entry_type ON public.obsidian_entries USING btree (entry_type);


--
-- Name: idx_obsidian_tags; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_obsidian_tags ON public.obsidian_entries USING gin (tags);


--
-- Name: idx_shifts_shift_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_shifts_shift_type ON public.shifts USING btree (shift_type);


--
-- Name: idx_shifts_work_start; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_shifts_work_start ON public.shifts USING btree (work_start DESC);


--
-- Name: idx_sleep_logs_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sleep_logs_date ON public.sleep_logs USING btree (date DESC);


--
-- Name: idx_tracking_category; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tracking_category ON public.tracking_entries USING btree (category);


--
-- Name: idx_tracking_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tracking_date ON public.tracking_entries USING btree (date DESC);


--
-- Name: idx_tracking_item_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tracking_item_id ON public.tracking_entries USING btree (item_id);


--
-- Name: idx_tracking_items_category; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tracking_items_category ON public.tracking_items USING btree (category_id);


--
-- Name: idx_tracking_items_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tracking_items_slug ON public.tracking_items USING btree (slug);


--
-- Name: idx_tracking_ts; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tracking_ts ON public.tracking_entries USING btree ("timestamp" DESC);


--
-- Name: idx_tracking_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tracking_type ON public.tracking_entries USING btree (entry_type);


--
-- Name: breaks breaks_shift_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.breaks
    ADD CONSTRAINT breaks_shift_id_fkey FOREIGN KEY (shift_id) REFERENCES public.shifts(id) ON DELETE CASCADE;


--
-- Name: location_logs location_logs_shift_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.location_logs
    ADD CONSTRAINT location_logs_shift_id_fkey FOREIGN KEY (shift_id) REFERENCES public.shifts(id) ON DELETE SET NULL;


--
-- Name: mood_logs mood_logs_shift_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mood_logs
    ADD CONSTRAINT mood_logs_shift_id_fkey FOREIGN KEY (shift_id) REFERENCES public.shifts(id) ON DELETE SET NULL;


--
-- Name: tracking_items tracking_items_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tracking_items
    ADD CONSTRAINT tracking_items_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.tracking_categories(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

\unrestrict IMBe0IqPJYcfBxi8FOl4rTyExHZubdpqeCYg5EQWWHcJOI9TLwfCVXngpX6j29f

