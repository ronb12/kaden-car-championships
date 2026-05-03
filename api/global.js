import { cleanText, ensureSchema, getSql, globalStats, json } from './_db.js';

export default async function handler(req, res) {
  const sql = getSql();
  if (!sql) return json(res, 200, { ok: true, enabled: false, leaderboard: [], stats: {} });

  try {
    await ensureSchema(sql);

    if (req.method === 'POST') {
      const body = req.body || {};
      const playerId = cleanText(body.playerId, 'anon');
      const playerName = cleanText(body.playerName, 'KRC DRIVER');
      const trackKey = cleanText(body.trackKey, 'default');
      if (body.type === 'play_start') {
        await sql`
          INSERT INTO krc_global_plays (player_id, player_name, track_key, mode)
          VALUES (${playerId}, ${playerName}, ${trackKey}, ${cleanText(body.mode, 'quick')})
        `;
      }
      if (body.type === 'finish') {
        await sql`
          INSERT INTO krc_global_scores (
            player_id, player_name, car_name, car_id, track_key, track_name, mode,
            total_ms, best_lap_ms, position, racer_count
          )
          VALUES (
            ${playerId}, ${playerName}, ${cleanText(body.carName, 'KRC CAR')}, ${cleanText(body.carId, '')},
            ${trackKey}, ${cleanText(body.trackName, '')}, ${cleanText(body.mode, 'quick')},
            ${Math.max(0, parseInt(body.totalMs, 10) || 0)},
            ${body.bestLapMs == null ? null : Math.max(0, parseInt(body.bestLapMs, 10) || 0)},
            ${parseInt(body.position, 10) || null},
            ${parseInt(body.racerCount, 10) || null}
          )
        `;
      }
    }

    const trackKey = cleanText(req.query.trackKey || req.body?.trackKey, '');
    const leaderboard = trackKey
      ? await sql`
          SELECT player_name, car_name, total_ms
          FROM krc_global_scores
          WHERE track_key = ${trackKey}
          ORDER BY total_ms ASC
          LIMIT 10
        `
      : [];
    const stats = await globalStats(sql);
    return json(res, 200, { ok: true, enabled: true, leaderboard, stats });
  } catch (err) {
    return json(res, 200, { ok: true, enabled: false, error: String(err.message || err), leaderboard: [], stats: {} });
  }
}
