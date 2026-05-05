-- ============================================================
-- bensn Personal OS – Datenbankschema
-- ============================================================

-- Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm"; -- für Volltextsuche später

-- ============================================================
-- WORKTRACKER
-- ============================================================

CREATE TABLE shifts (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Zeitdaten
    work_start      TIMESTAMPTZ NOT NULL,
    work_end        TIMESTAMPTZ,
    duration_minutes INT GENERATED ALWAYS AS (
        CASE WHEN work_end IS NOT NULL
        THEN EXTRACT(EPOCH FROM (work_end - work_start))::INT / 60
        ELSE NULL END
    ) STORED,

    -- Schichttyp
    shift_type      VARCHAR(20) NOT NULL CHECK (shift_type IN ('früh', 'nachmittag', 'nacht')),
    
    -- Sender/Station
    station         VARCHAR(50) NOT NULL,   -- z.B. "Puls4" oder "Puls4+ATV2" bei Duo
    service_label   VARCHAR(100),           -- Freitext-Label für Widget
    
    -- Sonderfälle
    is_duo_service  BOOLEAN DEFAULT FALSE,
    duo_partner_station VARCHAR(50),        -- was der Partner macht
    
    -- Schulung
    has_training    BOOLEAN DEFAULT FALSE,
    training_note   TEXT,
    training_start  TIMESTAMPTZ,
    training_end    TIMESTAMPTZ,

    -- Anmerkungen
    notes           TEXT,
    
    -- Korrekturen
    corrected           BOOLEAN DEFAULT FALSE,
    corrected_at        TIMESTAMPTZ,
    corrected_reason    TEXT,
    original_data       JSONB,              -- Snapshot vor der Korrektur
    
    -- Metadaten
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    source          VARCHAR(20) DEFAULT 'shortcut' -- shortcut | web | api
);

CREATE TABLE breaks (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    shift_id        UUID NOT NULL REFERENCES shifts(id) ON DELETE CASCADE,
    
    break_start     TIMESTAMPTZ NOT NULL,
    break_end       TIMESTAMPTZ,
    duration_minutes INT GENERATED ALWAYS AS (
        CASE WHEN break_end IS NOT NULL
        THEN EXTRACT(EPOCH FROM (break_end - break_start))::INT / 60
        ELSE NULL END
    ) STORED,
    
    break_type      VARCHAR(50),            -- Rauchen | Essen | Pause | ...
    zig_spicy       INT DEFAULT 0,
    zig_blend       INT DEFAULT 0,
    
    notes           TEXT,
    
    -- Korrekturen
    corrected           BOOLEAN DEFAULT FALSE,
    corrected_at        TIMESTAMPTZ,
    corrected_reason    TEXT,
    original_data       JSONB,
    
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    source          VARCHAR(20) DEFAULT 'shortcut'
);

-- Index für häufige Abfragen
CREATE INDEX idx_shifts_work_start ON shifts(work_start DESC);
CREATE INDEX idx_shifts_shift_type ON shifts(shift_type);
CREATE INDEX idx_breaks_shift_id ON breaks(shift_id);

-- ============================================================
-- HEALTH
-- ============================================================

CREATE TABLE sleep_logs (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    date            DATE NOT NULL UNIQUE,
    
    sleep_start     TIMESTAMPTZ,
    sleep_end       TIMESTAMPTZ,
    duration_minutes INT,                   -- manuell eintragbar, falls kein Start/Ende
    
    quality         SMALLINT CHECK (quality BETWEEN 1 AND 5),
    notes           TEXT,
    
    corrected       BOOLEAN DEFAULT FALSE,
    corrected_at    TIMESTAMPTZ,
    original_data   JSONB,
    
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    source          VARCHAR(20) DEFAULT 'shortcut'
);

CREATE TABLE health_logs (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    timestamp       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    date            DATE NOT NULL DEFAULT CURRENT_DATE,
    
    steps           INT,
    weight_kg       NUMERIC(5,2),
    heart_rate_avg  INT,
    
    -- Medikamente als flexibles JSON Array
    -- z.B. [{"name": "Sertralin", "dose_mg": 50, "time": "08:00"}]
    medications     JSONB DEFAULT '[]',
    
    notes           TEXT,
    source          VARCHAR(20) DEFAULT 'shortcut'
);

CREATE TABLE mood_logs (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    timestamp       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    mood_score      SMALLINT CHECK (mood_score BETWEEN 1 AND 10),
    energy_score    SMALLINT CHECK (energy_score BETWEEN 1 AND 10),
    anxiety_score   SMALLINT CHECK (anxiety_score BETWEEN 1 AND 10),
    
    tags            TEXT[],                 -- z.B. {'gestresst', 'müde', 'motiviert'}
    notes           TEXT,
    
    -- Verknüpfung mit Schicht falls während Dienst
    shift_id        UUID REFERENCES shifts(id) ON DELETE SET NULL,
    
    source          VARCHAR(20) DEFAULT 'shortcut', -- shortcut | obsidian | web
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_mood_logs_timestamp ON mood_logs(timestamp DESC);
CREATE INDEX idx_sleep_logs_date ON sleep_logs(date DESC);

-- ============================================================
-- OBSIDIAN SYNC
-- ============================================================

CREATE TABLE obsidian_entries (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Dateipfad relativ zum Vault-Root
    file_path       TEXT NOT NULL UNIQUE,
    title           TEXT NOT NULL,
    
    -- Timestamps aus Frontmatter oder Dateiname
    entry_date      TIMESTAMPTZ,            -- primäres Datum für Feed-Sortierung
    created_at_obs  TIMESTAMPTZ,            -- date created aus Frontmatter
    modified_at_obs TIMESTAMPTZ,            -- date modified aus Frontmatter
    
    -- Kategorisierung
    entry_type      VARCHAR(50),            -- arbeit|mood|symptome|therapie|diary|idea|project|note|datalog|reflexion|fits
    folder          VARCHAR(100),           -- z.B. "01_Journal/Diary"
    
    -- Frontmatter komplett
    frontmatter     JSONB DEFAULT '{}',
    
    -- Content
    content_preview TEXT,                   -- erste ~500 Zeichen
    content_full    TEXT,                   -- optional: ganzer Content
    word_count      INT,
    
    tags            TEXT[],
    css_class       TEXT,                   -- cssclass aus Frontmatter
    
    -- Feed-Steuerung
    show_in_feed    BOOLEAN DEFAULT TRUE,
    pinned          BOOLEAN DEFAULT FALSE,
    
    -- Sync-Metadaten
    last_synced     TIMESTAMPTZ DEFAULT NOW(),
    file_hash       TEXT,                   -- MD5 um unnötige Sync zu vermeiden
    
    synced_at       TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_obsidian_entry_date ON obsidian_entries(entry_date DESC);
CREATE INDEX idx_obsidian_entry_type ON obsidian_entries(entry_type);
CREATE INDEX idx_obsidian_tags ON obsidian_entries USING GIN(tags);
CREATE INDEX idx_obsidian_content ON obsidian_entries USING GIN(to_tsvector('german', coalesce(content_preview, '')));

-- ============================================================
-- FEED (materialisierte View-Tabelle)
-- ============================================================

CREATE TABLE feed_items (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    timestamp       TIMESTAMPTZ NOT NULL,
    
    -- Typ des Items
    item_type       VARCHAR(30) NOT NULL,   -- shift|break|mood|sleep|health|obsidian|note
    
    -- Referenz zur Quelltabelle
    reference_id    UUID,
    reference_table VARCHAR(50),
    
    -- Anzeige
    title           TEXT,
    preview_text    TEXT,
    icon            TEXT,                   -- Emoji oder Icon-Name
    color           VARCHAR(7),             -- Hex-Farbe
    
    -- Zusatzdaten für schnelle Anzeige ohne JOIN
    metadata        JSONB DEFAULT '{}',
    
    pinned          BOOLEAN DEFAULT FALSE,
    
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_feed_items_timestamp ON feed_items(timestamp DESC);
CREATE INDEX idx_feed_items_type ON feed_items(item_type);

-- ============================================================
-- LOCATION (für iPhone Shortcut)
-- ============================================================

CREATE TABLE location_logs (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    timestamp       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    latitude        NUMERIC(10, 7),
    longitude       NUMERIC(10, 7),
    accuracy        NUMERIC(8, 2),
    altitude        NUMERIC(8, 2),
    
    -- Reverse-geocoded
    city            VARCHAR(100),
    district        VARCHAR(100),
    country         VARCHAR(50),
    
    -- Kontext
    context         VARCHAR(50),            -- work | home | commute | other
    shift_id        UUID REFERENCES shifts(id) ON DELETE SET NULL,
    
    source          VARCHAR(20) DEFAULT 'shortcut'
);

-- ============================================================
-- HILFSFUNKTIONEN
-- ============================================================

-- Funktion: Korrektur mit Snapshot
CREATE OR REPLACE FUNCTION save_correction(
    table_name TEXT,
    record_id UUID,
    reason TEXT
) RETURNS VOID AS $$
BEGIN
    -- Wird von der API verwendet, die vorher den Snapshot macht
    -- Placeholder für spätere Implementierung
    RAISE NOTICE 'Correction logged for % / %', table_name, record_id;
END;
$$ LANGUAGE plpgsql;

-- View: Aktuelle Schicht (für Widget/API)
CREATE OR REPLACE VIEW current_shift AS
SELECT 
    s.*,
    COALESCE(
        (SELECT SUM(b.duration_minutes) FROM breaks b WHERE b.shift_id = s.id AND b.break_end IS NOT NULL),
        0
    ) AS total_break_minutes,
    (SELECT COUNT(*) FROM breaks b WHERE b.shift_id = s.id) AS break_count,
    (SELECT SUM(b.zig_spicy) FROM breaks b WHERE b.shift_id = s.id) AS total_zig_spicy,
    (SELECT SUM(b.zig_blend) FROM breaks b WHERE b.shift_id = s.id) AS total_zig_blend
FROM shifts s
WHERE s.work_end IS NULL
  AND s.work_start > NOW() - INTERVAL '16 hours'
ORDER BY s.work_start DESC
LIMIT 1;

-- View: Tagesübersicht
CREATE OR REPLACE VIEW daily_summary AS
SELECT
    DATE(s.work_start) AS date,
    COUNT(s.id) AS shift_count,
    SUM(s.duration_minutes) AS total_work_minutes,
    SUM(sub.total_break_minutes) AS total_break_minutes,
    SUM(sub.total_zig_spicy) AS total_zig_spicy,
    SUM(sub.total_zig_blend) AS total_zig_blend,
    ARRAY_AGG(s.shift_type) AS shift_types,
    ARRAY_AGG(s.station) AS stations
FROM shifts s
LEFT JOIN (
    SELECT 
        shift_id,
        COALESCE(SUM(duration_minutes), 0) AS total_break_minutes,
        COALESCE(SUM(zig_spicy), 0) AS total_zig_spicy,
        COALESCE(SUM(zig_blend), 0) AS total_zig_blend
    FROM breaks
    GROUP BY shift_id
) sub ON sub.shift_id = s.id
WHERE s.work_end IS NOT NULL
GROUP BY DATE(s.work_start)
ORDER BY date DESC;
