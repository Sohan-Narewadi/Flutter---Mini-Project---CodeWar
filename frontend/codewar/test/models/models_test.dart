import 'package:flutter_test/flutter_test.dart';

import 'package:codewar/models/leaderboard.dart';
import 'package:codewar/models/player.dart';
import 'package:codewar/models/practice.dart';
import 'package:codewar/models/profile_models.dart';
import 'package:codewar/models/tier.dart';

void main() {
  group('Tier (must mirror backend/app/tiers.py)', () {
    test('boundaries', () {
      const cases = {
        0: Tier.iron, 899: Tier.iron, 900: Tier.bronze, 1000: Tier.bronze, 1099: Tier.bronze,
        1100: Tier.silver, 1299: Tier.silver, 1300: Tier.gold, 1499: Tier.gold,
        1500: Tier.platinum, 1699: Tier.platinum, 1700: Tier.diamond, 5000: Tier.diamond,
      };
      cases.forEach((rating, tier) => expect(Tier.forRating(rating), tier, reason: 'rating $rating'));
    });

    test('progress to the next tier', () {
      expect(Tier.bronze.progress(1000), closeTo(0.5, 1e-9));
      expect(Tier.diamond.progress(2500), 1);
      expect(Tier.diamond.next, isNull);
      expect(Tier.bronze.next, Tier.silver);
    });

    test('fromKey falls back to the rating for unknown keys', () {
      expect(Tier.fromKey('gold'), Tier.gold);
      expect(Tier.fromKey('???', rating: 1350), Tier.gold);
    });
  });

  test('Player and LeaderboardEntry parse tier, defaulting to bronze', () {
    expect(Player.fromJson({'tier': 'silver'}).tier, 'silver');
    expect(Player.fromJson({}).tier, 'bronze');
    final e = LeaderboardEntry.fromJson({'rank': 1, 'player_id': 2, 'name': 'A', 'level': 3, 'rating': 1200, 'value': 5, 'tier': 'silver'});
    expect(e.tier, 'silver');
  });

  test('BadgeInfo earned state and icon fallback', () {
    final a = BadgeInfo.fromJson({'key': 'k', 'name': 'N', 'description': 'D', 'icon': 'flag', 'earned_at': '2026-10-01T10:00:00Z'});
    expect(a.earned, isTrue);
    final b = BadgeInfo.fromJson({'key': 'k', 'name': 'N', 'description': 'D', 'icon': 'nonsense', 'earned_at': null});
    expect(b.earned, isFalse);
    expect(b.iconData, isNotNull);
  });

  test('MatchRecord parses and decides a win only against others', () {
    final solo = MatchRecord.fromJson({'room_code': 'A', 'rank': 1, 'players_count': 1});
    expect(solo.won, isFalse);
    final m = MatchRecord.fromJson({
      'room_code': 'ABC123', 'mode': 'duel', 'rank': 1, 'players_count': 2, 'rating_delta': 15, 'xp': 30,
      'opponents': ['Bob'], 'finished_at': '2026-10-01T13:00:00Z',
    });
    expect(m.won, isTrue);
    expect(m.opponents, ['Bob']);
    expect(m.finishedAt, isNotNull);
  });

  test('timeAgo buckets', () {
    final now = DateTime.utc(2026, 10, 9, 12);
    expect(timeAgo(now.subtract(const Duration(seconds: 10)), now: now), 'just now');
    expect(timeAgo(now.subtract(const Duration(minutes: 5)), now: now), '5m ago');
    expect(timeAgo(now.subtract(const Duration(hours: 3)), now: now), '3h ago');
    expect(timeAgo(now.subtract(const Duration(days: 2)), now: now), '2d ago');
    expect(timeAgo(DateTime.utc(2026, 1, 2), now: now), '2026-01-02');
    expect(timeAgo(null), '');
  });

  test('PracticeStats label and PracticeSubmitResult badges', () {
    expect(const PracticeStats(streak: 0, solvedToday: 0, topics: [], dailyResetsIn: 5 * 3600 + 12 * 60).dailyResetsLabel, '5h 12m');
    expect(const PracticeStats(streak: 0, solvedToday: 0, topics: [], dailyResetsIn: 20).dailyResetsLabel, '1m');
    expect(PracticeStats.empty.dailyResetsLabel, '');
    final r = PracticeSubmitResult.fromJson({
      'passed_tests': 3, 'total_tests': 3, 'results': [], 'correctness_percent': 100, 'solved': true,
      'new_badges': [{'key': 'first_solve', 'name': 'First Blood', 'description': 'd', 'icon': 'flag', 'earned_at': null}],
    });
    expect(r.newBadges.single.key, 'first_solve');
  });
}
