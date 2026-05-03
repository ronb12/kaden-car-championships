import { cleanText, ensureSchema, getSql, json } from './_db.js';

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return json(res, 405, { ok: false, error: 'Method not allowed' });
  }

  const sql = getSql();
  if (!sql) {
    return json(res, 200, { ok: true, enabled: false, deleted: false });
  }

  try {
    await ensureSchema(sql);
    const body = req.body || {};
    const playerId = cleanText(body.playerId, '');

    if (!playerId) {
      return json(res, 400, { ok: false, error: 'Missing playerId' });
    }

    const scores = await sql`DELETE FROM krc_global_scores WHERE player_id = ${playerId}`;
    const plays = await sql`DELETE FROM krc_global_plays WHERE player_id = ${playerId}`;
    const presence = await sql`DELETE FROM krc_presence WHERE player_id = ${playerId}`;

    return json(res, 200, {
      ok: true,
      enabled: true,
      deleted: true,
      removed: {
        scores: scores.count || 0,
        plays: plays.count || 0,
        presence: presence.count || 0
      }
    });
  } catch (err) {
    return json(res, 200, {
      ok: false,
      enabled: false,
      deleted: false,
      error: String(err.message || err)
    });
  }
}
