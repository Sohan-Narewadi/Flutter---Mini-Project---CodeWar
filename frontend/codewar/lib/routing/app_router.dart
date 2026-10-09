import 'package:go_router/go_router.dart';

import '../providers/game_state.dart';
import '../screens/world_map_screen.dart';
import '../screens/battle_arena_screen.dart';
import '../screens/practice_screen.dart';
import '../screens/practice_play_screen.dart';
import '../screens/rank_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/battle_preparation_screen.dart';
import '../screens/coding_battle_screen.dart';
import '../screens/battle_victory_screen.dart';
import '../screens/battle_defeat_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/settings_screen.dart';

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
      GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingScreen()),
      GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
      GoRoute(path: '/home', builder: (context, state) => const WorldMapScreen()),
      GoRoute(path: '/battle', builder: (context, state) => const BattleArenaScreen()),
      GoRoute(path: '/practice', builder: (context, state) => const PracticeScreen()),
      GoRoute(path: '/practice/play', builder: (context, state) => const PracticePlayScreen()),
      GoRoute(path: '/rank', builder: (context, state) => const RankScreen()),
      GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
      GoRoute(
        path: '/prepare/:enemyId',
        builder: (context, state) => BattlePreparationScreen(
          enemyId: state.pathParameters['enemyId']!,
          levelId: state.uri.queryParameters['levelId'],
        ),
      ),
      GoRoute(path: '/ide', builder: (context, state) => const CodingBattleScreen()),
      GoRoute(path: '/victory', builder: (context, state) => const BattleVictoryScreen()),
      GoRoute(path: '/defeat', builder: (context, state) => const BattleDefeatScreen()),
    ],
  );
}
