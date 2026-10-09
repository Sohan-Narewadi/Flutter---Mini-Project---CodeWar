import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../providers/game_state.dart';
import '../screens/world_map_screen.dart';
import '../screens/battle_arena_screen.dart';
import '../screens/practice_screen.dart';
import '../screens/practice_play_screen.dart';
import '../screens/play_online_screen.dart';
import '../screens/room_screen.dart';
import '../screens/rank_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/battle_preparation_screen.dart';
import '../screens/coding_battle_screen.dart';
import '../screens/battle_victory_screen.dart';
import '../screens/battle_defeat_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/settings_screen.dart';

/// Fade + slight upward slide used for every route.
CustomTransitionPage<void> _page(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 220),
    reverseTransitionDuration: const Duration(milliseconds: 160),
    transitionsBuilder: (context, animation, secondary, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Builds the app router. Signed-out users (no device token) are always sent
/// to onboarding; signed-in users never see it.
GoRouter buildRouter(GameState state) {
  return GoRouter(
    initialLocation: '/home',
    refreshListenable: state,
    redirect: (context, routerState) {
      final atOnboarding = routerState.matchedLocation == '/onboarding';
      if (!state.hasToken && !atOnboarding) return '/onboarding';
      if (state.hasToken && atOnboarding) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/onboarding', pageBuilder: (context, state) => _page(state, const OnboardingScreen())),
      GoRoute(path: '/settings', pageBuilder: (context, state) => _page(state, const SettingsScreen())),
      GoRoute(path: '/home', pageBuilder: (context, state) => _page(state, const WorldMapScreen())),
      GoRoute(path: '/battle', pageBuilder: (context, state) => _page(state, const BattleArenaScreen())),
      GoRoute(path: '/practice', pageBuilder: (context, state) => _page(state, const PracticeScreen())),
      GoRoute(path: '/online', pageBuilder: (context, state) => _page(state, const PlayOnlineScreen())),
      GoRoute(path: '/room', pageBuilder: (context, state) => _page(state, const RoomScreen())),
      GoRoute(path: '/practice/play', pageBuilder: (context, state) => _page(state, const PracticePlayScreen())),
      GoRoute(path: '/rank', pageBuilder: (context, state) => _page(state, const RankScreen())),
      GoRoute(path: '/profile', pageBuilder: (context, state) => _page(state, const ProfileScreen())),
      GoRoute(
        path: '/prepare/:enemyId',
        pageBuilder: (context, state) => _page(
          state,
          BattlePreparationScreen(
            enemyId: state.pathParameters['enemyId']!,
            levelId: state.uri.queryParameters['levelId'],
          ),
        ),
      ),
      GoRoute(path: '/ide', pageBuilder: (context, state) => _page(state, const CodingBattleScreen())),
      GoRoute(path: '/victory', pageBuilder: (context, state) => _page(state, const BattleVictoryScreen())),
      GoRoute(path: '/defeat', pageBuilder: (context, state) => _page(state, const BattleDefeatScreen())),
    ],
  );
}
