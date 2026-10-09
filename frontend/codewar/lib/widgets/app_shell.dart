import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../ui/app_scaffold.dart';
import 'bottom_nav_bar.dart';
import 'offline_banner.dart';

/// Wraps a top-level tab screen with the arcade backdrop, offline banner and
/// bottom navigation. Each tab owns its own header (only Home shows the
/// player strip), so nothing is repeated across tabs.
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.body,
    required this.navIndex,
    this.title = '',
  });

  /// Kept for call-site readability / semantics; the visible title lives in
  /// each screen's own header.
  final String title;
  final Widget body;
  final int navIndex;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(child: body),
        ],
      ),
      bottom: BottomNavBar(
        currentIndex: navIndex,
        onTap: (i) {
          if (i != navIndex) context.go(kNavItems[i].route);
        },
      ),
    );
  }
}
