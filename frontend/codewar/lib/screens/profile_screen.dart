import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/profile_models.dart';
import '../models/tier.dart';
import '../providers/game_state.dart';
import '../providers/practice_state.dart';
import '../services/api_service.dart';
import '../ui/app_card.dart';
import '../ui/avatar.dart';
import '../ui/neon_button.dart';
import '../ui/skeleton.dart';
import '../ui/stat_tile.dart';
import '../utils/theme.dart';
import '../widgets/app_shell.dart';

/// Profile: who you are in the game. Everything is read from the server:
/// stats, earned badges, recent online matches and topic mastery.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<BadgeInfo>? _badges;
  List<MatchRecord>? _matches;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    final game = context.read<GameState>();
    final practice = context.read<PracticeState>();
    setState(() => _error = null);
    try {
      await game.refreshProgress();
      final results = await Future.wait([game.api.fetchBadges(), game.api.fetchMatches(limit: 10), practice.loadStats()]);
      if (!mounted) return;
      setState(() {
        _badges = results[0] as List<BadgeInfo>;
        _matches = results[1] as List<MatchRecord>;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load your profile.');
    }
  }

  Future<void> _signOut() async {
    final game = context.read<GameState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'This device keeps your secret key. If you sign out without saving it you will not be able to get this warrior back.',
          style: TextStyle(color: AppColors.textDim, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Stay')),
          TextButton(
            key: const Key('confirmSignOut'),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (ok == true) game.signOut();
  }

  void _showBadge(BadgeInfo b) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.page, 0, AppSpace.page, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _BadgeDisc(badge: b, size: 72),
              const SizedBox(height: 12),
              Text(b.name, style: AppTheme.display(fontSize: 22)),
              const SizedBox(height: 6),
              Text(b.description, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textDim, height: 1.4)),
              const SizedBox(height: 10),
              Text(
                b.earned ? 'EARNED ${timeAgo(b.earnedAt).toUpperCase()}' : 'NOT EARNED YET',
                style: AppTheme.overline(color: b.earned ? AppColors.gold : AppColors.textFaint),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final practice = context.watch<PracticeState>();
    final player = game.player;
    final tier = Tier.fromKey(player.tier, rating: player.rating);
    final games = player.wins + player.losses;
    final winRate = games == 0 ? '—' : '${(100 * player.wins / games).round()}%';
    final next = tier.next;
    final badges = _badges;
    final earnedCount = badges?.where((b) => b.earned).length ?? 0;

    return AppShell(
      title: 'Profile',
      navIndex: 4,
      body: RefreshIndicator(
        color: AppColors.accent,
        backgroundColor: AppColors.surfaceHigh,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpace.page, 20, AppSpace.page, 28),
          children: [
            // ---- Hero ----
            Center(child: PlayerAvatar(name: player.displayName, tier: tier, size: 96, glow: true)),
            const SizedBox(height: 14),
            Center(child: Text(player.displayName, style: AppTheme.display(fontSize: 28))),
            const SizedBox(height: 4),
            Center(child: Text('@${player.username}', style: AppTheme.mono(fontSize: 12, color: AppColors.textDim))),
            const SizedBox(height: 10),
            Center(child: TierBadge(tier: tier)),
            const SizedBox(height: 18),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('LEVEL ${player.level}', style: AppTheme.display(fontSize: 18, color: AppColors.accent)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('${player.xp} / ${player.xpToNext} XP',
                            maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right, style: AppTheme.mono(fontSize: 12, color: AppColors.textDim)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _Bar(value: player.xpProgress, color: AppColors.accent),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Flexible(
                        child: Text(next == null ? '${tier.label.toUpperCase()} · TOP TIER' : '${tier.label.toUpperCase()} → ${next.label.toUpperCase()}',
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.overline(color: tier.color)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(next == null ? '${player.rating} RP' : '${player.rating} / ${next.minRating} RP',
                            maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right, style: AppTheme.mono(fontSize: 12, color: AppColors.textDim)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _Bar(value: tier.progress(player.rating), color: tier.color),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Chip(icon: Icons.monetization_on_rounded, label: '${player.gold} gold', color: AppColors.gold),
                _Chip(icon: Icons.favorite_rounded, label: '${player.hp}/${player.hpMax} HP', color: AppColors.danger),
                _Chip(icon: Icons.local_fire_department_rounded, label: '${player.streak} day streak', color: player.streak > 0 ? AppColors.gold : AppColors.textFaint),
              ],
            ),

            // ---- Stats ----
            const SizedBox(height: 24),
            const SectionTitle('Stats'),
            Row(
              children: [
                Expanded(child: StatTile(icon: Icons.bolt_rounded, color: AppColors.accent, value: '${player.rating}', label: 'Rating')),
                const SizedBox(width: 10),
                Expanded(child: StatTile(icon: Icons.percent_rounded, color: AppColors.success, value: winRate, label: 'Win rate')),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: StatTile(icon: Icons.emoji_events_rounded, color: AppColors.gold, value: '${player.wins}', label: 'Wins')),
                const SizedBox(width: 10),
                Expanded(child: StatTile(icon: Icons.close_rounded, color: AppColors.danger, value: '${player.losses}', label: 'Losses')),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: StatTile(icon: Icons.check_circle_rounded, color: AppColors.accent, value: '${practice.stats.totalSolved}', label: 'Solved')),
                const SizedBox(width: 10),
                Expanded(child: StatTile(icon: Icons.whatshot_rounded, color: AppColors.gold, value: '${player.bestStreak}', label: 'Best streak')),
              ],
            ),

            // ---- Badges ----
            const SizedBox(height: 24),
            SectionTitle('Badges', trailing: badges == null ? null : Text('$earnedCount/${badges.length}', style: AppTheme.mono(fontSize: 12, color: AppColors.textDim))),
            if (badges == null)
              _error != null ? _ErrorCard(message: _error!, onRetry: _load) : const SkeletonBox(height: 120, radius: AppRadius.xl)
            else
              LayoutBuilder(
                builder: (context, c) {
                  final cols = c.maxWidth >= 480 ? 6 : 4;
                  const gap = 10.0;
                  final w = (c.maxWidth - gap * (cols - 1)) / cols;
                  return Wrap(
                    spacing: gap,
                    runSpacing: 14,
                    children: [
                      for (final b in badges)
                        SizedBox(
                          width: w,
                          child: GestureDetector(
                            key: Key('badge_${b.key}'),
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _showBadge(b),
                            child: Column(
                              children: [
                                _BadgeDisc(badge: b, size: 52),
                                const SizedBox(height: 6),
                                Text(b.name,
                                    maxLines: 2,
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 11, height: 1.2, fontWeight: FontWeight.w600, color: b.earned ? AppColors.text : AppColors.textFaint)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),

            // ---- Recent matches ----
            const SizedBox(height: 24),
            const SectionTitle('Recent matches'),
            if (_matches == null)
              _error != null ? const SizedBox.shrink() : const SkeletonList(rows: 3, rowHeight: 64)
            else if (_matches!.isEmpty)
              AppCard(
                child: Row(
                  children: [
                    const Icon(Icons.sports_esports_rounded, color: AppColors.textFaint),
                    const SizedBox(width: 12),
                    const Expanded(child: Text('No online matches yet. Create a room and challenge a friend.', style: TextStyle(color: AppColors.textDim, height: 1.35))),
                    TextButton(onPressed: () => context.go('/online'), child: const Text('Play')),
                  ],
                ),
              )
            else
              for (final m in _matches!) _MatchRow(match: m),

            // ---- Mastery ----
            if (practice.stats.topics.any((t) => t.solved > 0)) ...[
              const SizedBox(height: 24),
              const SectionTitle('Topic mastery'),
              AppCard(
                child: Column(
                  children: [
                    for (final t in practice.stats.topics)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            SizedBox(width: 96, child: Text(t.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
                            Expanded(child: _Bar(value: t.masteryPercent / 100, color: t.masteryPercent >= 100 ? AppColors.gold : AppColors.accent)),
                            SizedBox(width: 44, child: Text('${t.masteryPercent}%', textAlign: TextAlign.right, style: AppTheme.mono(fontSize: 12, color: AppColors.textDim))),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],

            // ---- Account ----
            const SizedBox(height: 28),
            NeonButton(label: 'Settings & server', icon: Icons.settings_rounded, variant: NeonVariant.secondary, onPressed: () => context.push('/settings')),
            const SizedBox(height: 10),
            NeonButton(key: const Key('signOutButton'), label: 'Sign out', icon: Icons.logout_rounded, variant: NeonVariant.danger, onPressed: _signOut),
          ],
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.value, required this.color});
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: value.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => LinearProgressIndicator(value: v, minHeight: 8, backgroundColor: AppColors.line, color: color),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.full), border: Border.all(color: AppColors.line)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(label, style: AppTheme.display(fontSize: 13)),
        ],
      ),
    );
  }
}

class _BadgeDisc extends StatelessWidget {
  const _BadgeDisc({required this.badge, required this.size});
  final BadgeInfo badge;
  final double size;

  @override
  Widget build(BuildContext context) {
    final on = badge.earned;
    final color = on ? AppColors.gold : AppColors.textFaint;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: on ? 0.14 : 0.06),
        border: Border.all(color: color.withValues(alpha: on ? 0.7 : 0.3), width: on ? 2 : 1.5),
        boxShadow: on ? [BoxShadow(color: AppColors.gold.withValues(alpha: 0.3), blurRadius: 14)] : null,
      ),
      child: Icon(on ? badge.iconData : Icons.lock_rounded, color: color, size: size * 0.46),
    );
  }
}

class _MatchRow extends StatelessWidget {
  const _MatchRow({required this.match});
  final MatchRecord match;

  static String _ordinal(int n) {
    if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
    return switch (n % 10) { 1 => '${n}st', 2 => '${n}nd', 3 => '${n}rd', _ => '${n}th' };
  }

  @override
  Widget build(BuildContext context) {
    final m = match;
    final color = m.won ? AppColors.gold : AppColors.textDim;
    final delta = m.ratingDelta;
    final vs = m.opponents.isEmpty ? '' : ' vs ${m.opponents.join(', ')}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.md)),
              child: Text(_ordinal(m.rank), style: AppTheme.display(fontSize: 15, color: color)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${m.mode == 'duel' ? 'Duel' : 'Race'}$vs', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.display(fontSize: 15)),
                  const SizedBox(height: 2),
                  Text('${m.bestPct}% solved  ·  +${m.xp} XP  ·  ${timeAgo(m.finishedAt)}', style: const TextStyle(fontSize: 12, color: AppColors.textDim)),
                ],
              ),
            ),
            if (delta != 0)
              Text(delta > 0 ? '+$delta' : '$delta', style: AppTheme.display(fontSize: 16, color: delta > 0 ? AppColors.success : AppColors.danger)),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      accent: AppColors.danger,
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, color: AppColors.danger),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(color: AppColors.text))),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
