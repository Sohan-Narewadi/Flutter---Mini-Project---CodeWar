import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/game_state.dart';
import 'routing/app_router.dart';
import 'utils/theme.dart';

void main() {
  runApp(const CodeWarApp());
}

class CodeWarApp extends StatelessWidget {
  const CodeWarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => GameState()..load(),
      child: MaterialApp.router(
        title: 'CodeWar',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark,
        routerConfig: appRouter,
      ),
    );
  }
}
