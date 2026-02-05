-- =============================================================================
-- TierPulse – PostgreSQL Schema Migration 001
-- Creates all tables if they do not exist.
-- =============================================================================

-- 1) metric_definitions
CREATE TABLE IF NOT EXISTS metric_definitions (
  metric_id        SERIAL PRIMARY KEY,
  tier_level       INTEGER NOT NULL CHECK (tier_level IN (1, 2)),
  sqdcp_category   VARCHAR(20) NOT NULL,
  functional_area  VARCHAR(50) NOT NULL,
  metric_name      VARCHAR(200) NOT NULL,
  metric_prompt    TEXT,
  target_text      VARCHAR(200),
  active_bool      BOOLEAN NOT NULL DEFAULT TRUE
);

-- 2) metric_entries
CREATE TABLE IF NOT EXISTS metric_entries (
  entry_id          SERIAL PRIMARY KEY,
  metric_id         INTEGER NOT NULL REFERENCES metric_definitions(metric_id),
  entry_date        DATE NOT NULL,
  status            VARCHAR(10) NOT NULL CHECK (status IN ('MET', 'TBD', 'NOT_MET')),
  value_text        TEXT,
  explanation_text  TEXT,
  is_escalated_bool BOOLEAN NOT NULL DEFAULT FALSE,
  created_at        TIMESTAMP NOT NULL DEFAULT NOW(),
  created_by        VARCHAR(100)
);

-- 3) issues
CREATE TABLE IF NOT EXISTS issues (
  issue_id         SERIAL PRIMARY KEY,
  issue_type       VARCHAR(20) NOT NULL CHECK (issue_type IN ('ACTION', 'ESCALATION')),
  source_tier      INTEGER NOT NULL CHECK (source_tier IN (1, 2)),
  target_tier      INTEGER NOT NULL CHECK (target_tier IN (1, 2, 3)),
  status           VARCHAR(20) NOT NULL DEFAULT 'OPEN'
                     CHECK (status IN ('OPEN', 'IN_PROGRESS', 'RESOLVED', 'VERIFIED')),
  functional_area  VARCHAR(50),
  sqdcp_category   VARCHAR(20),
  description      TEXT NOT NULL,
  owner            VARCHAR(100),
  due_date         DATE,
  created_at       TIMESTAMP NOT NULL DEFAULT NOW(),
  created_by       VARCHAR(100),
  linked_entry_id  INTEGER REFERENCES metric_entries(entry_id)
);

-- 4) attendance
CREATE TABLE IF NOT EXISTS attendance (
  attendance_id    SERIAL PRIMARY KEY,
  tier_level       INTEGER NOT NULL CHECK (tier_level IN (1, 2)),
  meeting_date     DATE NOT NULL,
  functional_area  VARCHAR(50),
  person_name      VARCHAR(100) NOT NULL,
  present_bool     BOOLEAN NOT NULL DEFAULT TRUE,
  notes            TEXT
);

-- 5) meetings
CREATE TABLE IF NOT EXISTS meetings (
  meeting_id          SERIAL PRIMARY KEY,
  tier_level          INTEGER NOT NULL CHECK (tier_level IN (1, 2)),
  meeting_date        DATE NOT NULL,
  scheduled_start_time TIME,
  timebox_minutes     INTEGER NOT NULL DEFAULT 8,
  facilitator_name    VARCHAR(100),
  created_at          TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Indexes for common queries
CREATE INDEX IF NOT EXISTS idx_metric_entries_date     ON metric_entries(entry_date);
CREATE INDEX IF NOT EXISTS idx_metric_entries_metric   ON metric_entries(metric_id);
CREATE INDEX IF NOT EXISTS idx_issues_status           ON issues(status);
CREATE INDEX IF NOT EXISTS idx_issues_target_tier      ON issues(target_tier);
CREATE INDEX IF NOT EXISTS idx_issues_source_tier      ON issues(source_tier);
