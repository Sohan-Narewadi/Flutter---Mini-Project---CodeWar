# Changelog

Newest first. Add an entry for every user-visible or developer-visible change.

## 2.0: Online play, endless problems and a full redesign

**New**
- **Online rooms:** Race (2 to 8 players) and Duel (1v1) over WebSockets, joined with a 6-character code; live progress bars, reconnect handling, Elo ratings, XP and gold, and a "new room, same settings" button on the results screen.
- **Endless problems:** a built-in generator (34 templates, random inputs) and an optional AI-written path. Expected answers always come from running a reference solution through the judge. Hints, per-topic mastery, a day streak and a daily challenge with double XP.
- **Real leaderboard:** global, weekly and friends, by XP or rating, refreshed every 15 seconds. Tap a player for their public profile.
- **Rank tiers (Iron to Diamond) and 17 badges**, earned only from real activity.
- **Profile:** tier progress, win rate, best streak, match history with rating changes, topic mastery.
- **Accounts:** a display name plus a device token (no email or password).
- **Sound and haptics**, with switches in Settings.
- **One-click local play:** `play.bat` / `play.sh`; the server also serves the web app, and on the web the app uses the address it was loaded from.

**Changed**
- Complete visual redesign ("neon arcade"): one design system in `lib/ui/` and `lib/utils/theme.dart`, one header on Home only, restyled battle, practice, room and result screens.
- **Faster code judging:** all test cases of a submission run in one process (run and submit went from about 0.41s to about 0.10s).
- Wins and losses now count online matches only (campaign battles no longer inflate them). Existing databases are repaired automatically on upgrade.
- Existing databases are upgraded automatically on start-up (new columns are added); you no longer need to delete `codewar.db`.

**Fixed**
- Removed invented content from the battle screens (a made-up defence debuff, a fake defeat debrief, a retry cost for a mechanic that does not exist, hardcoded level names).
- Code editor no longer wraps long lines (line numbers always match); retry after a defeat starts a real new battle; layout overflows with large text or big numbers; Profile no longer shows placeholder numbers when the server is unreachable.
- Concurrent badge awards can no longer abort saving a match result.

## 1.0: Campaign

- Flutter app with a campaign world map, enemies and a coding battle screen.
- FastAPI backend with a Python and TypeScript code judge.
