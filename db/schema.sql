CREATE TABLE IF NOT EXISTS krc_global_scores (
  id BIGSERIAL PRIMARY KEY,
  player_id TEXT NOT NULL,
  player_name TEXT NOT NULL,
  car_name TEXT,
  car_id TEXT,
  track_key TEXT NOT NULL,
  track_name TEXT,
  mode TEXT,
  total_ms INTEGER NOT NULL,
  best_lap_ms INTEGER,
  position INTEGER,
  racer_count INTEGER,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS krc_global_plays (
  id BIGSERIAL PRIMARY KEY,
  player_id TEXT NOT NULL,
  player_name TEXT NOT NULL,
  track_key TEXT,
  mode TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS krc_presence (
  player_id TEXT PRIMARY KEY,
  player_name TEXT NOT NULL,
  car_name TEXT,
  car_id TEXT,
  color_int INTEGER,
  track_key TEXT,
  mode TEXT,
  x DOUBLE PRECISION,
  z DOUBLE PRECISION,
  angle DOUBLE PRECISION,
  speed_kmh DOUBLE PRECISION,
  lap INTEGER,
  progress DOUBLE PRECISION,
  lobby_id TEXT,
  finish_ms INTEGER,
  position INTEGER,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS krc_match_lobbies (
  lobby_id TEXT PRIMARY KEY,
  track_key TEXT NOT NULL,
  mode TEXT,
  starts_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
