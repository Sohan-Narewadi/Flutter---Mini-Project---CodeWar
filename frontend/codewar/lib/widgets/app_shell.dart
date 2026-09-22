import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_hud.dart';
import 'bottom_nav_bar.dart';

/// Wraps a top-level tab screen (Home/Battle/Practice/Rank/Profile) with the
/// persistent player HUD header and bottom navigation bar.
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.title,
    required this.body,
    required this.navIndex,
    this.showHud = true,
  });

  final String title;
  final Widget body;
  final int navIndex;
  final bool showHud;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (showHud) const AppHud(),
            Expanded(child: body),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: navIndex,
        onTap: (i) {
          const routes = ['/home', '/battle', '/practice', '/rank', '/profile'];
          if (i != navIndex) context.go(routes[i]);
        },
      ),
    );
  }
}
