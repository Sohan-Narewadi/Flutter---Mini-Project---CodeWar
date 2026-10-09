import 'dart:ui';

import 'package:flutter/material.dart';

import '../services/sfx.dart';
import '../utils/theme.dart';

class NavItem {
  final IconData icon;
  final String label;
  final String route;
  const NavItem(this.icon, this.label, this.route);
}

/// Index of the centered "Play" button.
const int kPlayIndex = 2;

/// navIndex of the Play tab (same as [kPlayIndex]).
const int kPlayTab = kPlayIndex;

const List<NavItem> kNavItems = [
  NavItem(Icons.home_rounded, 'Home', '/home'),
  NavItem(Icons.terminal_rounded, 'Practice', '/practice'),
  NavItem(Icons.bolt_rounded, 'Play', '/online'),
  NavItem(Icons.leaderboard_rounded, 'Rank', '/rank'),
  NavItem(Icons.person_rounded, 'Profile', '/profile'),
];

class BottomNavBar extends StatelessWidget {
  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return MediaQuery.withNoTextScaling(
      child: SizedBox(
        height: 68 + bottomInset,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLow.withValues(alpha: 0.9),
                      border: const Border(
                        top: BorderSide(color: AppColors.line),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: Row(
                children: [
                  for (var i = 0; i < kNavItems.length; i++)
                    Expanded(
                      child: i == kPlayIndex
                          ? _PlayButton(
                              item: kNavItems[i],
                              active: i == currentIndex,
                              onTap: () => onTap(i),
                            )
                          : _NavButton(
                              item: kNavItems[i],
                              active: i == currentIndex,
                              onTap: () => onTap(i),
                            ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({
    required this.item,
    required this.active,
    required this.onTap,
  });
  final NavItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      label: 'Play online',
      excludeSemantics: true,
      child: GestureDetector(
        key: const Key('navPlay'),
        behavior: HitTestBehavior.opaque,
        onTap: () {
          Sfx.play(Cue.select);
          onTap();
        },
        child: OverflowBox(
          maxHeight: 90,
          alignment: Alignment.bottomCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.accentGradient,
                  border: Border.all(color: AppColors.background, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withValues(
                        alpha: active ? 0.55 : 0.35,
                      ),
                      blurRadius: active ? 24 : 18,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(item.icon, color: AppColors.onAccent, size: 28),
              ),
              const SizedBox(height: 2),
              Text(
                item.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: active ? AppColors.accent : AppColors.textDim,
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.active,
    required this.onTap,
  });

  final NavItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.accent : AppColors.textFaint;
    return Semantics(
      button: true,
      selected: active,
      label: item.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          Sfx.play(Cue.select);
          onTap();
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: active
                    ? AppColors.accent.withValues(alpha: 0.14)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Icon(item.icon, color: color, size: 24),
            ),
            const SizedBox(height: 2),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
