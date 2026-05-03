import { neon } from '@neondatabase/serverless';

export function json(res, status, body) {
  res.status(status).setHeader('Content-Type', 'application/json');
  res.end(JSON.stringify(body));
}

export function getSql() {
  const url = process.env.DATABASE_URL || process.env.POSTGRES_URL || process.env.NEON_DATABASE_URL;
  return url ? neon(url) : null;
}

export function cleanText(value, fallback = '') {
  return String(value || fallback).replace(/[^\w .'-]/g, '').trim().slice(0, 40) || fallback;
}

export async function ensureSchema(sql) {
  await sql`SELECT pg_advisory_lock(74726301)`;
  try {
    await sql`
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
      )
    `;
    await sql`
      CREATE TABLE IF NOT EXISTS krc_global_plays (
        id BIGSERIAL PRIMARY KEY,
        player_id TEXT NOT NULL,
        player_name TEXT NOT NULL,
        track_key TEXT,
        mode TEXT,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
    `;
    await sql`
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
      )
    `;
    await sql`
      CREATE TABLE IF NOT EXISTS krc_match_lobbies (
        lobby_id TEXT PRIMARY KEY,
        track_key TEXT NOT NULL,
        mode TEXT,
        starts_at TIMESTAMPTZ NOT NULL,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
    `;
  } finally {
    await sql`SELECT pg_advisory_unlock(74726301)`;
  }
}

export async function globalStats(sql) {
  const rows = await sql`
    SELECT
      (SELECT COUNT(*)::INT FROM krc_global_scores) AS races,
      (SELECT COUNT(*)::INT FROM krc_global_plays) AS plays,
      (SELECT COUNT(*)::INT FROM krc_presence WHERE updated_at > NOW() - INTERVAL '2 minutes') AS active_players,
      (SELECT COUNT(*)::INT FROM krc_presence WHERE updated_at > NOW() - INTERVAL '30 seconds') AS live_players,
      (SELECT COUNT(DISTINCT player_id)::INT FROM krc_presence) AS players,
      (SELECT COUNT(*)::INT FROM krc_match_lobbies WHERE starts_at > NOW() - INTERVAL '2 minutes') AS match_lobbies
  `;
  return rows[0] || { races: 0, plays: 0, active_players: 0, live_players: 0, players: 0, match_lobbies: 0 };
}
