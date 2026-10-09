import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'providers/game_state.dart';
import 'routing/app_router.dart';
import 'services/api_service.dart';
import 'services/settings_store.dart';
import 'utils/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await SettingsStore.open();
  runApp(CodeWarApp(settings: settings));
}

class CodeWarApp extends StatefulWidget {
  const CodeWarApp({super.key, this.settings, this.api});

  /// Injected in tests; defaults to persisted settings.
  final SettingsStore? settings;
  final ApiService? api;

  @override
  State<CodeWarApp> createState() => _CodeWarAppState();
}

class _CodeWarAppState extends State<CodeWarApp> {
  late final GameState _state;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    final api = widget.api ?? ApiService(settings: widget.settings ?? SettingsStore.memory());
    _state = GameState(api: api)..load();
    _router = buildRouter(_state);
  }

  @override
  void dispose() {
    _router.dispose();
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _state,
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
