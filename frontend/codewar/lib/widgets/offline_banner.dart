import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/game_state.dart';
import '../utils/theme.dart';

/// Shown above every tab when the server can't be reached, so stale data is
/// never mistaken for live data.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();
    if (!state.offline) return const SizedBox.shrink();
    return Material(
      color: AppColors.dangerDim,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.cloud_off, size: 18, color: AppColors.danger),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Server unreachable. Showing last known data.',
                style: TextStyle(color: AppColors.text, fontSize: 13),
              ),
            ),
            TextButton(
              onPressed: () => state.load(),
              child: const Text('Retry'),
            ),
            IconButton(
              tooltip: 'Server settings',
              icon: const Icon(Icons.settings, size: 18),
              onPressed: () => context.push('/settings'),
            ),
          ],
        ),
      ),
    );
  }
}
