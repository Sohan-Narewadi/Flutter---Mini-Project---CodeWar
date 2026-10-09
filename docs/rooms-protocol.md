# Rooms protocol (backend, implemented in Stage 4)

Use this when building the Flutter side (Stage 5). Source of truth: `backend/app/routers/rooms.py`,
`backend/app/rooms/manager.py`, `backend/app/rooms/engine.py`, tests in `backend/tests/test_rooms_api.py`.

## REST (all need `Authorization: Bearer <token>`)
- `POST /api/rooms` body `{mode: "race"|"duel", difficulty: "easy"|"medium"|"hard", language: "python"|"typescript"}` -> `201` room snapshot (below). Creator is the host.
- `POST /api/rooms/{code}/join` -> room snapshot. `404` unknown code, `409` full or already started. Codes are case-insensitive. Optional: the WebSocket also joins.
- `GET /api/rooms/{code}` -> room snapshot.

## WebSocket
`ws(s)://<server>/ws/rooms/{code}?token=<token>`. The server accepts, then may close with an application code:
`4401` bad token, `4404` no such room, `4403` rejected (e.g. match already started; an `error` message is sent first), `4000` replaced by a newer connection of the same player.

### Client -> server (JSON)
- `{"type":"start"}` host only; needs 2+ players. Server prepares a problem (snapshot has `preparing: true`), then countdown starts.
- `{"type":"run","code":"...","language":"python"}` private preview; replies `run_result` to the sender only, not scored.
- `{"type":"submit","code":"...","language":"python"}` scored; replies `run_result` to the sender and broadcasts a snapshot.
- `{"type":"leave"}` leave the room (forfeit if the match is running).
- `{"type":"ping"}` -> `{"type":"pong"}`.

### Server -> client
- `{"type":"snapshot","room":{...}}` on connect, after every change, and about once a second while running.
- `{"type":"question","question":{id,title,difficulty,tags,prompt,example_input,example_output,starter_code,test_cases,topic,source}}` when the match turns `running` (and again on reconnect). Judge data is never sent; only the first 3 example test cases are visible and the rest are hidden (shown as "(hidden)" in results).
- `{"type":"run_result","kind":"run"|"submit","passed_tests","total_tests","correctness_percent","results":[{input,expected,actual,passed,duration_ms}]}`
- `{"type":"error","code","message"}` codes: `need_players`, `not_host`, `started`, `full`, `preparing`, `no_question`, `not_running`, `not_member`, `forfeited`, `busy`, `too_long`, `bad_language`, `bad_message`.

### Room snapshot
```
{code, mode, difficulty, language, status: "lobby"|"countdown"|"running"|"finished", host_id, max_players,
 time_limit_s, seconds_left (running only), countdown_left (countdown only), reason: "solved"|"timeout"|"forfeit"|null,
 preparing: bool,
 players: [{player_id, name, connected, is_host, passed, total, best_pct, submissions, forfeited, rank|null}],
 standings: null | [{player_id, name, rank, best_pct, passed, total, forfeited, time_s, rating_delta, xp, gold, rating}]}
```
`standings` appears when `status == "finished"`; `rating_delta/xp/gold/rating` are added once results are persisted (a later snapshot).

## Rules (rulings)
- Race: first player to 100% wins immediately; otherwise at timeout rank by best percent, then who got it first. Ties share a rank. Duel = same rules for exactly 2 players; the UI shows each player's HP as `100 - opponent best_pct`.
- Time limits: easy 300s, medium 480s, hard 720s. Countdown 3s. Disconnect grace 30s, then forfeit (forfeiters rank last; if only one player is left the match ends with reason `forfeit`).
- `run` is private/unscored (ruling: avoids run-spam and keeps progress bars meaningful); `submit` is what counts.
- Rewards: rating Elo K=32 (pairwise, averaged); XP base easy 30 / medium 60 / hard 120 x (rank1 1.0, rank2 0.6, others 0.3) only if best_pct > 0 (or the winner by forfeit); gold = xp // 4; wins/losses updated unless everyone tied. All participants become friends.
- Rooms are in memory: a server restart drops live rooms (finished results are in the DB table `room_results`).
