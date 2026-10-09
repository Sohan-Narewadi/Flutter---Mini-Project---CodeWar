import 'package:flutter/material.dart';
import '../utils/theme.dart';

class NavItem {
  final IconData icon;
  final String label;
  final String route;
  const NavItem(this.icon, this.label, this.route);
}

/// Index of the centered "Play" button (opens online play, never "active").
const int kPlayIndex = 2;

const List<NavItem> kNavItems = [
  NavItem(Icons.cottage, 'Home', '/home'),
  NavItem(Icons.terminal, 'Practice', '/practice'),
  NavItem(Icons.bolt, 'Play', '/online'),
  NavItem(Icons.military_tech, 'Rank', '/rank'),
  NavItem(Icons.shield, 'Profile', '/profile'),
];

class BottomNavBar extends StatelessWidget {
  const BottomNavBar({super.key, required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLow,
        border: Border(top: BorderSide(color: AppColors.outlineVariant)),
      ),
      padding: const EdgeInsets.only(top: 6, bottom: 4),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (var i = 0; i < kNavItems.length; i++)
              if (i == kPlayIndex)
                _PlayButton(item: kNavItems[i], onTap: () => onTap(i))
              else
                _NavButton(
                  item: kNavItems[i],
                  active: i == currentIndex,
                  onTap: () => onTap(i),
                ),
          ],
        ),
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.item, required this.onTap});
  final NavItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Play online',
      child: GestureDetector(
        key: const Key('navPlay'),
        onTap: onTap,
        child: Transform.translate(
          offset: const Offset(0, -10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryContainer, AppColors.secondaryContainer],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(color: AppColors.primaryContainer.withValues(alpha: 0.45), blurRadius: 16, offset: const Offset(0, 4)),
                  ],
                ),
                child: Icon(item.icon, color: Colors.white, size: 30),
              ),
              const SizedBox(height: 2),
              Text(item.label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary)),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.item, required this.active, required this.onTap});

  final NavItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primary : AppColors.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(item.icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              item.label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
            ),
            const SizedBox(height: 3),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: active ? 16 : 0,
              height: 3,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
