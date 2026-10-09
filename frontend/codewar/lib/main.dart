import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'providers/game_state.dart';
import 'providers/practice_state.dart';
import 'providers/room_state.dart';
import 'services/room_channel.dart';
import 'routing/app_router.dart';
import 'services/api_service.dart';
import 'services/settings_store.dart';
import 'services/sfx.dart';
import 'utils/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await SettingsStore.open();
  Sfx.player = AudioCuePlayer();
  runApp(CodeWarApp(settings: settings));
}

class CodeWarApp extends StatefulWidget {
  const CodeWarApp({super.key, this.settings, this.api, this.channelFactory});

  /// Injected in tests; defaults to persisted settings.
  final SettingsStore? settings;
  final ApiService? api;
  final RoomChannelFactory? channelFactory;

  @override
  State<CodeWarApp> createState() => _CodeWarAppState();
}

class _CodeWarAppState extends State<CodeWarApp> {
  late final GameState _state;
  late final PracticeState _practice;
  late final RoomState _rooms;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    final api = widget.api ?? ApiService(settings: widget.settings ?? SettingsStore.memory());
    Sfx.soundOn = api.settings.soundOn;
    Sfx.hapticsOn = api.settings.hapticsOn;
    _state = GameState(api: api)..load();
    _practice = PracticeState(api, onProgress: _state.refreshProgress);
    _rooms = RoomState(api, channelFactory: widget.channelFactory, onFinished: _state.refreshProgress);
    _state.onSignOut = () {
      _practice.reset();
      _rooms.reset();
    };
    _router = buildRouter(_state);
  }

  @override
  void dispose() {
    _router.dispose();
    _rooms.dispose();
    _practice.dispose();
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<GameState>.value(value: _state),
        ChangeNotifierProvider<PracticeState>.value(value: _practice),
        ChangeNotifierProvider<RoomState>.value(value: _rooms),
      ],
      child: MaterialApp.router(
        title: 'CodeWar',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark,
        routerConfig: _router,
      ),
    );
  }
}
