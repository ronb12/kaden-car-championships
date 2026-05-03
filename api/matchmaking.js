import { cleanText, ensureSchema, getSql, json } from './_db.js';

function lobbyResponse(lobby, players) {
  return {
    ok: true,
    enabled: true,
    lobby: { ...lobby, server_now_ms: Date.now() },
    players
  };
}

export default async function handler(req, res) {
  const sql = getSql();
  if (!sql) return json(res, 200, { ok: true, enabled: false, lobby: null, players: [] });

  try {
    await ensureSchema(sql);
    const body = req.body || {};
    const playerId = cleanText(body.playerId, 'anon');
    const trackKey = cleanText(body.trackKey, 'default');
    let lobbyId = cleanText(body.lobbyId, '');

    if (body.type === 'join' || !lobbyId) {
      const open = await sql`
        SELECT lobby_id, track_key, mode, starts_at
        FROM krc_match_lobbies
        WHERE track_key = ${trackKey}
          AND starts_at > NOW()
        ORDER BY created_at DESC
        LIMIT 1
      `;
      if (open.length) {
        lobbyId = open[0].lobby_id;
      } else {
        lobbyId = 'krc-' + Math.random().toString(36).slice(2, 10);
        await sql`
          INSERT INTO krc_match_lobbies (lobby_id, track_key, mode, starts_at)
          VALUES (${lobbyId}, ${trackKey}, ${cleanText(body.mode, 'quick')}, NOW() + INTERVAL '8 seconds')
        `;
      }
    }

    if (body.type === 'finish') {
      await sql`
        UPDATE krc_presence
        SET finish_ms = ${parseInt(body.finishMs, 10) || null}, position = ${parseInt(body.position, 10) || null}, updated_at = NOW()
        WHERE player_id = ${playerId}
      `;
    } else {
      await sql`
        INSERT INTO krc_presence (player_id, player_name, car_name, car_id, color_int, track_key, mode, lobby_id, updated_at)
        VALUES (
          ${playerId}, ${cleanText(body.playerName, 'KRC DRIVER')}, ${cleanText(body.carName, 'KRC CAR')},
          ${cleanText(body.carId, '')}, ${parseInt(body.colorInt, 10) || 0}, ${trackKey}, ${cleanText(body.mode, 'quick')}, ${lobbyId}, NOW()
        )
        ON CONFLICT (player_id) DO UPDATE SET
          player_name = EXCLUDED.player_name,
          car_name = EXCLUDED.car_name,
          car_id = EXCLUDED.car_id,
          color_int = EXCLUDED.color_int,
          track_key = EXCLUDED.track_key,
          mode = EXCLUDED.mode,
          lobby_id = EXCLUDED.lobby_id,
          updated_at = NOW()
      `;
    }

    const lobbies = await sql`
      SELECT lobby_id, track_key, mode, starts_at
      FROM krc_match_lobbies
      WHERE lobby_id = ${lobbyId}
      LIMIT 1
    `;
    const players = await sql`
      SELECT player_id, player_name, car_name, car_id, finish_ms, position
      FROM krc_presence
      WHERE lobby_id = ${lobbyId}
        AND updated_at > NOW() - INTERVAL '2 minutes'
      ORDER BY updated_at ASC
      LIMIT 6
    `;
    return json(res, 200, lobbyResponse(lobbies[0] || { lobby_id: lobbyId, starts_at: new Date().toISOString() }, players));
  } catch (err) {
    return json(res, 200, { ok: true, enabled: false, error: String(err.message || err), lobby: null, players: [] });
  }
}
