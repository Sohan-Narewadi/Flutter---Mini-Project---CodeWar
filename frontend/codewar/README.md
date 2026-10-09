# CodeWar app (Flutter)

The Flutter client for CodeWar: campaign battles, endless Practice, online Race/Duel rooms and a live leaderboard. See the [root README](../../README.md) for setup of the whole project.

## Run

```bash
flutter pub get
flutter run                       # uses http://127.0.0.1:8000 (Android emulator: http://10.0.2.2:8000)
flutter run --dart-define=API_URL=https://your-tunnel.trycloudflare.com
```

The server address can also be changed in the app: onboarding > Advanced, or Profile > Settings.

## Layout

| Path | What |
|------|------|
| `lib/services/` | `ApiService` (REST), `RoomChannel` (WebSocket seam), `SettingsStore` (token + server URL) |
| `lib/providers/` | `GameState` (campaign), `PracticeState`, `RoomState` (online rooms) |
| `lib/screens/` | one file per screen; `room_screen.dart` covers lobby, countdown, match and results |
| `lib/ui/` | shared building blocks: `AppCard`, skeleton loaders, shake effect |
| `lib/widgets/` | HUD, bottom nav, editor panel, bars and tiles |
| `test/` | unit and widget tests (fake HTTP client and fake socket, no server needed) |

## Checks

```bash
flutter analyze
flutter test
```
