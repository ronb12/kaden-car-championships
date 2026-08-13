import { cleanText, ensureSchema, getSql, json } from './_db.js';

export default async function handler(req, res) {
  const sql = getSql();
  if (!sql) return json(res, 200, { ok: true, enabled: false, players: [] });

  try {
    await ensureSchema(sql);
    const body = req.body || {};
    const playerId = cleanText(body.playerId, 'anon');
    const trackKey = cleanText(body.trackKey, 'default');
    const lobbyId = cleanText(body.lobbyId, '');

    if (req.method === 'POST' && body.type === 'leave') {
      await sql`DELETE FROM krc_presence WHERE player_id = ${playerId}`;
      return json(res, 200, { ok: true, enabled: true, players: [] });
    }

    if (req.method === 'POST') {
      await sql`
        INSERT INTO krc_presence (
          player_id, player_name, car_name, car_id, color_int, track_key, mode,
          x, y, z, angle, speed_kmh, lap, progress, lobby_id, updated_at
        )
        VALUES (
          ${playerId}, ${cleanText(body.playerName, 'KRC DRIVER')}, ${cleanText(body.carName, 'KRC CAR')},
          ${cleanText(body.carId, '')}, ${parseInt(body.colorInt, 10) || 0}, ${trackKey}, ${cleanText(body.mode, 'quick')},
          ${Number(body.x) || 0}, ${Number(body.y) || 0}, ${Number(body.z) || 0}, ${Number(body.angle) || 0},
          ${Number(body.speedKmh) || 0}, ${parseInt(body.lap, 10) || 1}, ${Number(body.progress) || 0},
          ${lobbyId || null}, NOW()
        )
        ON CONFLICT (player_id) DO UPDATE SET
          player_name = EXCLUDED.player_name,
          car_name = EXCLUDED.car_name,
          car_id = EXCLUDED.car_id,
          color_int = EXCLUDED.color_int,
          track_key = EXCLUDED.track_key,
          mode = EXCLUDED.mode,
          x = EXCLUDED.x,
          y = EXCLUDED.y,
          z = EXCLUDED.z,
          angle = EXCLUDED.angle,
          speed_kmh = EXCLUDED.speed_kmh,
          lap = EXCLUDED.lap,
          progress = EXCLUDED.progress,
          lobby_id = COALESCE(EXCLUDED.lobby_id, krc_presence.lobby_id),
          updated_at = NOW()
      `;
    }

    // Prefer same lobby when available; otherwise same track.
    const players = lobbyId
      ? await sql`
          SELECT player_id, player_name, car_name, car_id, color_int, x, y, z, angle, speed_kmh, lap, progress, lobby_id
          FROM krc_presence
          WHERE lobby_id = ${lobbyId}
            AND player_id <> ${playerId}
            AND updated_at > NOW() - INTERVAL '15 seconds'
          ORDER BY updated_at DESC
          LIMIT 12
        `
      : await sql`
          SELECT player_id, player_name, car_name, car_id, color_int, x, y, z, angle, speed_kmh, lap, progress, lobby_id
          FROM krc_presence
          WHERE track_key = ${trackKey}
            AND player_id <> ${playerId}
            AND updated_at > NOW() - INTERVAL '15 seconds'
          ORDER BY updated_at DESC
          LIMIT 12
        `;
    return json(res, 200, { ok: true, enabled: true, players });
  } catch (err) {
    return json(res, 200, { ok: true, enabled: false, error: String(err.message || err), players: [] });
  }
}
