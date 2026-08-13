import { cleanText, ensureSchema, getSql, json } from './_db.js';

function lobbyResponse(lobby, players) {
  return {
    ok: true,
    enabled: true,
    lobby: lobby
      ? {
          lobby_id: lobby.lobby_id,
          track_key: lobby.track_key,
          mode: lobby.mode,
          starts_at: lobby.starts_at,
          server_now_ms: Date.now(),
        }
      : null,
    players,
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
    const type = cleanText(body.type, 'join');
    let lobbyId = cleanText(body.lobbyId, '');

    if (type === 'leave') {
      await sql`DELETE FROM krc_presence WHERE player_id = ${playerId}`;
      return json(res, 200, { ok: true, enabled: true, lobby: null, players: [] });
    }

    // Lobbies start on a timer even with 1 player. Cap a room at 8 humans;
    // overflow opens a new lobby. Starts are not frame-synced across phones.
    const maxHumans = 8;
    if (type === 'join' || !lobbyId) {
      const open = await sql`
        SELECT lobby_id, track_key, mode, starts_at
        FROM krc_match_lobbies
        WHERE track_key = ${trackKey}
          AND starts_at > NOW()
        ORDER BY created_at DESC
        LIMIT 1
      `;
      let joinExisting = false;
      if (open.length) {
        const counted = await sql`
          SELECT COUNT(*)::int AS n
          FROM krc_presence
          WHERE lobby_id = ${open[0].lobby_id}
            AND updated_at > NOW() - INTERVAL '2 minutes'
        `;
        joinExisting = (counted[0]?.n ?? 0) < maxHumans;
      }
      if (joinExisting) {
        lobbyId = open[0].lobby_id;
      } else {
        lobbyId = 'krc-' + Math.random().toString(36).slice(2, 10);
        await sql`
          INSERT INTO krc_match_lobbies (lobby_id, track_key, mode, starts_at)
          VALUES (${lobbyId}, ${trackKey}, ${cleanText(body.mode, 'quick')}, NOW() + INTERVAL '8 seconds')
        `;
      }
    }

    if (type === 'finish') {
      await sql`
        UPDATE krc_presence
        SET finish_ms = ${parseInt(body.finishMs, 10) || null},
            position = ${parseInt(body.position, 10) || null},
            updated_at = NOW()
        WHERE player_id = ${playerId}
      `;
    } else {
      await sql`
        INSERT INTO krc_presence (
          player_id, player_name, car_name, car_id, color_int, track_key, mode, lobby_id, updated_at
        )
        VALUES (
          ${playerId}, ${cleanText(body.playerName, 'KRC DRIVER')}, ${cleanText(body.carName, 'KRC CAR')},
          ${cleanText(body.carId, '')}, ${parseInt(body.colorInt, 10) || 0}, ${trackKey},
          ${cleanText(body.mode, 'quick')}, ${lobbyId}, NOW()
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
      SELECT player_id, player_name, car_name, car_id, finish_ms, position, color_int
      FROM krc_presence
      WHERE lobby_id = ${lobbyId}
        AND updated_at > NOW() - INTERVAL '2 minutes'
      ORDER BY
        CASE WHEN finish_ms IS NULL THEN 1 ELSE 0 END,
        finish_ms ASC NULLS LAST,
        updated_at ASC
      LIMIT 8
    `;
    return json(res, 200, lobbyResponse(lobbies[0] || { lobby_id: lobbyId, starts_at: new Date().toISOString() }, players));
  } catch (err) {
    return json(res, 200, { ok: true, enabled: false, error: String(err.message || err), lobby: null, players: [] });
  }
}
