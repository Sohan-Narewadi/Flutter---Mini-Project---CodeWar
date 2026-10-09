# CodeWar Launch Polish: Implementation Plan (Stages 7-12)

> **For a resuming session:** read `docs/superpowers/PROGRESS.md` first (status + gotchas), then this file. Do the first unchecked task. After each task: run its verification, tick the box HERE and in PROGRESS.md, commit. Do not redo ticked tasks (trust `git log` over memory). Work on branch `feature/online`.

## 0. Why this exists (user's words, 2026-10-09)
The user's original brief: (1) polish the UI/UX completely, "launch ready final game with no problems at all", it currently "looks vibe coded" and is "sticky and unpleasant"; (2) online game mode with friends via room id; (3) unlimited real-time-fed coding questions; (4) nothing fabricated, leaderboard realtime of online players, profile and practice pages need a lot of improvement, "industry ready as other online games". They invited extra ideas and research.

Items 2, 3 and the real leaderboard are DONE (Stages 1-6, see PROGRESS.md). What is NOT done is the visual/UX quality: Stage 6 was never looked at in a running app. This plan covers that.

## 1. Decisions already made (do not re-ask)
- Visual direction: **Neon arcade** (user-confirmed). Dark base, ONE electric accent, glow on key actions only, bold display font, subtle grid/vignette backdrop.
- Extras (user-confirmed, all four): **achievements/badges, rank tiers, sound + haptics (with mute), match history**.
- Everything shown must be real data. No placeholder players, fake stats or invented badges. Empty states say so honestly ("No matches yet").
- User delegated all other design decisions to Claude and wants resumable sessions.
- The user wants suggestions: at the end, list further ideas in the final message rather than silently building them.

## 2. Audit of the current UI (found by running the web build, mobile 390x844)
1. `AppHud` (avatar, name, XP, HP, gold, streak) is repeated on Home, Practice and Rank: wastes ~25% of the screen and duplicates the Profile.
2. Primary button colour is inconsistent (lavender `primary` vs cyan `secondaryContainer`); segmented controls have uneven widths.
3. Generic Material 3 look; no brand identity, no backdrop, no display typography.
4. Rank is a flat list: no podium, no tier, no way to inspect a player.
5. Profile is thin: no tier, match history, per-topic stats, badges.
6. `/online` (Play) is pushed without the nav bar and has large dead space.
7. Numbers/labels are small; weak hierarchy; lots of equal-weight bordered cards.

## 3. Design system spec (Stage 7 builds exactly this)
File: `frontend/codewar/lib/utils/theme.dart` (replace palette, keep class names `AppColors`, `AppRadius`, `AppTheme` so existing screens compile) plus new `lib/ui/` primitives.

Colour tokens (`AppColors`):
| token | value | use |
|---|---|---|
| background | `#0A0C14` | scaffold |
| surface | `#11141F` | cards |
| surfaceHigh | `#181C2B` | raised/selected |
| surfaceLow | `#0D1019` | nav, inputs |
| outline | `#262B3F` | hairlines |
| accent | `#2BE4FF` | THE accent: primary buttons, active nav, progress |
| accentDeep | `#7C5CFF` | only as the second stop of the accent gradient |
| gold | `#FFC24B` | coins, rewards, 1st place |
| success | `#34F5A5` | solved, pass |
| danger | `#FF5C7A` | fail, HP loss, defeat |
| text / textDim / textFaint | `#EEF1FF` / `#A4ABC8` / `#6C7391` | text |
Keep the old token names as aliases pointing to the new values (so nothing breaks mid-migration), then delete aliases in Stage 9 when no longer referenced (`grep` to confirm).

Typography (google_fonts): display + numerals = **Chakra Petch** (w600/w700); body = **Inter**; code = **JetBrains Mono**. Scale: display 32/28, title 20, section 12 caps letter-spacing 1.2, body 14, caption 12. Numbers in stat tiles use tabular figures.

Radius: 14 cards, 12 inputs/buttons, 999 pills. Spacing scale 4/8/12/16/24/32. Page horizontal padding 20. Max content width 560 centred on wide screens (web/tablet), backdrop fills the rest.

Primitives (each with a widget test; all in `lib/ui/`):
- `NeonButton` (variants: primary gradient accent->accentDeep with glow, secondary outline, ghost; sizes; loading state; disabled; min tap 48; pressed scale 0.97; haptic + sound hook).
- `GlowCard` (replaces `AppCard`; keep `AppCard` as a thin wrapper until migration finishes). Variants: plain, highlight (accent border + glow), flat.
- `SegmentedTabs<T>` (equal-width, animated sliding indicator; use for Easy/Medium/Hard, mode, global/weekly/friends).
- `SectionHeader(title, action)` (caps overline style).
- `StatTile(value, label, icon, color)` (big Chakra Petch number).
- `ArcadeBackdrop` (gradient + faint grid + top vignette; used by `AppScaffold`).
- `AppScaffold` (backdrop + SafeArea + max width + optional bottom nav + offline banner). Replaces ad-hoc Scaffolds.
- `TierBadge(tier)`, `BadgeIcon(badge)`, `RankDelta` (up/down arrow) added in Stage 9/10.
- `Skeleton` already exists; restyle to new tokens.
Motion: 180-240ms easeOutCubic for transitions; list items stagger-in (30ms step, max 8); number count-up for XP/rating; no animation longer than 400ms except celebratory ones (victory/podium). Respect `MediaQuery.disableAnimations`.

## 4. Stage tasks

### Stage 7: Design system
- [x] 7.1 New tokens + fonts in `theme.dart`; `AppTheme.darkTheme` rebuilt (buttons, inputs, chips, dialogs, snackbars, tooltip, page transitions). Old names kept as aliases. Verify: `flutter analyze` clean, `flutter test` still 34 pass.
- [x] 7.2 `lib/ui/neon_button.dart`, `glow_card.dart`, `segmented_tabs.dart`, `section_header.dart`, `stat_tile.dart` + tests (render, tap, disabled, loading).
- [x] 7.3 `lib/ui/arcade_backdrop.dart` + `lib/ui/app_scaffold.dart` + test. Commit: "feat(ui): neon arcade design system".

### Stage 8: Shell and navigation
- [x] 8.1 Rewrite `widgets/app_shell.dart` to use `AppScaffold`; remove `AppHud` from Practice/Rank/Profile. Home gets a compact `HomeHeader` (avatar + name + level ring + gold + streak in ONE row, ~64px) instead of the 4-row HUD. Delete `app_hud.dart` once unused (keep `hudSkeleton` test intent in new header).
- [x] 8.2 Restyle `bottom_nav_bar.dart`: translucent blurred bar, accent active pill, centered Play button with glow and subtle idle pulse (stop pulsing when `disableAnimations`). Keep keys `navPlay`, `hudAvatar` equivalents (`homeAvatar`) so tests can be updated minimally.
- [x] 8.3 Make `/online` a tab-level screen WITH the nav bar (Play highlighted); `/room` stays full-screen. Update router + tests.
- [ ] 8.4 Page transitions: shared-axis fade/slide, tab switches use fade-through only. Verify with Playwright screenshots (Stage 12 harness) at 390x844.

### Stage 9: Screens (all real data)
- [x] 9.1 **Home** (`world_map_screen.dart`): header; "Continue" hero card for the current level (enemy, reward, one NeonButton); compact Battle Arena / Play Online entry tiles; sector path restyled with node connectors; locked nodes dimmed but legible. No fake progress.
- [x] 9.2 (screen done; practice_play_screen restyle still pending, see 11.3) **Practice** (`practice_screen.dart`): top row of StatTiles (streak, solved today, total solved); Daily Challenge hero (gradient, countdown "resets in HH:MM" computed from local midnight UTC rule the backend uses, done-state when already solved); difficulty `SegmentedTabs`; topics as a 2-column grid of cards with mastery ring, solved count, locked/unlocked honesty; "Surprise me" as secondary button. `practice_play_screen.dart`: problem header with difficulty + topic chips, tabs Problem/Editor/Tests on narrow screens, hint button with remaining count, clear result sheet (pass/fail per case, hidden cases marked), XP reward animation.
- [x] 9.3 **Rank** (`rank_screen.dart`): top-3 podium (avatars, crowns/gold-silver-bronze, XP or rating), the rest as rows with tier badge, level, value; own row pinned at the bottom if out of view; tabs Global/Weekly/Friends via `SegmentedTabs`; metric toggle; pull-to-refresh AND auto-refresh every 15s while visible (cancel on dispose); skeleton + honest empty states ("Add friends to see them here"); tapping a row opens a bottom sheet profile card (name, level, tier, rating, wins/losses) using `GET /api/players/{id}/public` (task 10.4). Add-friend dialog restyled.
- [x] 9.4 **Profile** (`profile_screen.dart`): hero (avatar ring coloured by tier, name, `@username`, tier badge, level with XP ring); stat grid (rating, wins, losses, win rate computed, best streak, total solved, enemies defeated); "Badges" grid (earned = colour, unearned = dim with how-to-earn text; from API 10.1); "Recent matches" list (from API 10.2: placement, mode, rating delta green/red, xp, relative time, empty state); "Mastery" summary from `/api/practice/stats`; Settings & server row; Sign out with confirm dialog.
- [ ] 9.5 Remove obsolete widgets/aliases (`app_hud.dart`, `stat_chip.dart` if unused, old colour aliases) after `grep` shows no references.

### Stage 10: Backend for real data (TDD, `cd backend && python -m pytest -q`)
- [x] 10.1 **Badges.** New model `PlayerBadge(player_id, key, earned_at)` (unique on player_id+key). New module `app/badges.py` with a static catalogue `BADGES = {key: {name, description, icon}}` and `award_badges(db, player) -> list[str]` that checks REAL conditions and inserts only new ones. Catalogue (initial, extend only with real conditions): `first_win` (wins>=1), `win_5`, `win_25`, `first_solve` (any solved practice attempt or completed level), `solve_10`, `solve_100`, `streak_3`, `streak_7`, `streak_30` (use stored `best_streak`, see below), `daily_done` (solved a daily challenge), `topic_master` (any topic mastery 100), `rival` (played 10 rooms), `climber` (reach Silver tier or above), `perfectionist` (a submit with 100% on first attempt, hard difficulty). Call `award_badges` at every point that changes the inputs (after `progress.award_xp`, after room persist, after battle win). Add `best_streak` column on Player (update inside the existing streak logic). Endpoint `GET /api/badges` returns catalogue merged with `earned_at` for the caller. Tests: each condition true/false, idempotent, endpoint shape.
- [x] 10.2 **Match history.** `GET /api/matches?limit=20` for the caller from `RoomResult` joined to opponents' names (top 3 other participants by rank). Fields: room_code, mode, rank, players_count, best_pct, rating_before, rating_delta, xp, gold, finished_at (ISO UTC). Add index on (player_id, finished_at). Tests with seeded results; ordering; limit; other players' results never leak.
- [x] 10.3 **Tiers.** `app/tiers.py` pure function `tier_for(rating) -> {key,name,min,next_min}`: Iron <900, Bronze 900-1099, Silver 1100-1299, Gold 1300-1499, Platinum 1500-1699, Diamond >=1700 (default rating 1000 = Bronze). Add `tier` to `PlayerOut`, `LeaderboardEntry`. Mirror in Dart (`models/tier.dart`) with the SAME thresholds and a test that both agree on the boundary values.
- [x] 10.4 **Public profile.** `GET /api/players/{id}/public`: display_name, level, rating, tier, wins, losses, total_xp, badges earned (keys only), created_at; NO token/email/gold/hp. Tests incl. 404.
- [x] 10.5 Leaderboard: confirm rows are computed live per request (no cache) and include `tier`, `rating`, `wins`; add `rank_change` ONLY if real (compare against a stored previous-snapshot; skip if not cheap; do not fake). Update `docs/superpowers/rooms-protocol.md` / README with new endpoints.
- Flutter models/services: `models/badge.dart`, `models/match_record.dart`, `models/tier.dart`, `ApiService.badges()/matches()/publicProfile(id)`, with unit tests using canned JSON.

### Stage 11: Online, battle and feedback polish
- [x] 11.1 **Play (online hub)** `play_online_screen.dart`: hero "Race or Duel", room code input as 6 separate boxes with auto-advance + paste support + uppercase + validation message, recent-room shortcut only if real, mode cards with player count and description; share sheet button that copies "Join my CodeWar room XYZ123 at <server url>" (clipboard).
- [x] 11.2 **Room** `room_screen.dart`: lobby with player chips (avatar, tier, ready/host), big copyable room code, host start button with min-players hint; countdown 3-2-1 full-screen with scale animation; match view with live opponents progress bars (real % from server events), timer; results = podium + rating delta count-up + XP/gold + "Rematch" (creates new room with same settings and shares code) and "Back to lobby".
- [ ] 11.3 **Battle flow** (`battle_arena`, `battle_preparation`, `coding_battle`, `victory`, `defeat`, `onboarding`, `settings`) restyled with the new primitives. Code editor: Chakra/JetBrains font, line numbers kept, dark theme with accent caret, run/submit buttons docked at the bottom with test-case drawer. Victory/defeat: celebratory but short animation, real rewards only, clear next action.
- [x] 11.4 **Sound + haptics.** `lib/services/feedback.dart` (`Feedback.tap/success/error/levelUp/countdown/win`). Haptics via `HapticFeedback` (no new dependency). Sound: add `audioplayers` ONLY if a tiny, licence-clean asset set is available; generate short original WAV cues programmatically (a small Python script `tools/make_sfx.py` that synthesises sine/chirp blips into `assets/sfx/*.wav`, so there are no licensing issues; commit the script and the files). Mute + haptics toggles in Settings, persisted in `SettingsStore`. Tests with a fake `Feedback` implementation; default on, never crash if audio unavailable (web autoplay policy: first sound only after a user gesture).
- [ ] 11.5 Accessibility + resilience pass: semantic labels on icon buttons, minimum 48dp targets, contrast >= 4.5:1 for body text (check `textDim` against `background`), text scale 1.3 does not overflow (test pump with `textScaler`), offline banner restyled, every network failure shows retry (not a blank screen), no raw exception text shown to users.

### Stage 12: Visual QA and release readiness
- [ ] 12.1 Screenshot harness `tools/qa_shots.py` (committed). Runs against the web build; writes PNGs to `docs/qa/` (git-ignored). Covers every route above at widths 360, 390, 768, 1280 (heights 800) and light/dark N/A (dark only). Uses Playwright with `channel='chrome'`; enables Flutter semantics via `document.querySelector('flt-semantics-placeholder').click()`; nav by coordinates (nav y = viewport height - 49) or semantics roles.
- [ ] 12.2 Two-browser online test: script creates two players (two Playwright contexts), A creates a Race, B joins by code, both submit a solution, verify results and leaderboard update. Also run `backend/scripts/smoke_rooms.py`.
- [ ] 12.3 Review every screenshot against the audit list in section 2 and against: alignment on an 8px grid, consistent button colours, no clipped text, no empty dead zones, loading/empty/error states present. Fix and re-shoot until clean. Keep a short `docs/qa/CHECKLIST.md` with per-screen pass/fail.
- [ ] 12.4 Performance: `flutter build web --release` size noted; no jank on leaderboard auto-refresh; dispose all timers/sockets (test: leaving Rank cancels the timer).
- [ ] 12.5 Full verification: `cd backend && python -m pytest -q` (expect 177+ new), `cd frontend/codewar && flutter analyze && flutter test`. Update README (screens, badges, tiers, sound), PROGRESS.md, and CI if new steps are needed.
- [ ] 12.6 Final whole-branch review by a fresh opus reviewer (use `superpowers:requesting-code-review`), fix Critical/Important with tests first, then ask the user: merge to main, PR, or iterate. List remaining suggestions (section 7).

## 5. Conventions and gotchas (carry over)
- Git: run from `D:\FLutter Mini Project\Flutter---Mini-Project---CodeWar` (the home dir `C:\Users\sohan` is also a git repo with many untracked files; never commit there). Commit message trailer: `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`.
- Flutter SDK: `export PATH="/d/flutter/bin:$PATH"` in bash. Tests: `cd frontend/codewar && flutter test`. Fake-socket tests need two `pump()` calls.
- Backend: `cd backend && .venv/Scripts/python -m pytest -q` (about 70s). Delete `backend/codewar.db` after schema changes (`create_all` does not migrate); mention this in the README when new tables/columns are added (Stage 10 adds `player_badges` and `players.best_streak`).
- Bash tool chokes on big heredocs: use the Write tool for multi-file content. Edit tip: write script files instead of triple-quote heredocs.
- Visual loop: backend `cd backend && (.venv/Scripts/python -m uvicorn app.main:app --port 8000 &)`; app `cd frontend/codewar && flutter build web --dart-define=API_URL=http://localhost:8000` (about 65s); serve `build/web` with `python -m http.server 8080`; screenshot with Playwright (`channel='chrome'`, no browser download needed). The Claude-in-Chrome extension was NOT connected in the first session. Screenshots saved under `D:\shots` for the first audit.
- Python on this machine: `python` has Playwright installed; Windows temp is `C:\Users\sohan\AppData\Local\Temp` (bash `/tmp` differs from Python's temp, use `D:/shots` or `/d/...` paths for files shared between them).
- Test accounts in the dev DB (`smokeA*`, `smokeB*`, `Tester*`) are local test data from smoke/QA runs, not seed data. Delete `backend/codewar.db` before any demo/release so the leaderboard starts clean.
- Do not add dependencies lightly; each needs a note in PROGRESS.md.

## 6. Definition of done
Every item in section 4 ticked; all backend and Flutter tests green; analyze clean; every route screenshotted at 4 widths with no visual defects; two real browsers completed an online match; no fabricated data anywhere (grep for hard-coded names/numbers in `lib/`); README and PROGRESS.md current; final review findings fixed.

## 7. Suggestions to offer the user at the end (do NOT build without asking)
Push notifications for friend invites; account recovery / optional email login; spectator mode for rooms; seasonal ladder resets with rewards; cosmetic avatars/frames unlocked by badges and tiers; more languages (Java/C++ judge sandboxing); a proper sandboxed judge (containers) before public launch; analytics/crash reporting; app-store packaging (Android/iOS icons, splash, store listing); anti-cheat (paste detection, plagiarism similarity in rooms); a hosted deployment instead of a home tunnel.
