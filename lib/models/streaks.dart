/// Weekly streaks and badges (see `docs/events.md`, step 5).
///
/// A week counts when the member posts in Huddle or goes to an event at
/// least once in it (Monday to Sunday, local time). Weekly rather than
/// daily on purpose: less pressure to post anything just to keep a streak,
/// and fairer for athletes who need help to post.
///
/// Worked out in the app from the member's own posts and events. Without
/// a server function (Blaze), a determined member could fake activity, so
/// badges are for fun, not for anything that matters.
library;

/// Midnight on the Monday of [t]'s week.
DateTime weekStart(DateTime t) {
  final day = DateTime(t.year, t.month, t.day);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

/// Whole weeks between two week starts.
int _weeksBetween(DateTime a, DateTime b) =>
    (b.difference(a).inHours / (24 * 7)).round();

class StreakSummary {
  const StreakSummary({
    required this.current,
    required this.longest,
    required this.activeThisWeek,
    required this.activeWeeks,
  });

  /// Weeks in a row up to now. A streak stays alive through the current
  /// week until it ends, so last week's streak still counts on Monday.
  final int current;
  final int longest;

  /// Already counted this week.
  final bool activeThisWeek;

  /// Weeks with any activity, ever.
  final int activeWeeks;

  static const none = StreakSummary(
    current: 0,
    longest: 0,
    activeThisWeek: false,
    activeWeeks: 0,
  );
}

StreakSummary computeStreak(Iterable<DateTime> activity, DateTime now) {
  final weeks = {for (final t in activity) weekStart(t)}.toList()..sort();
  if (weeks.isEmpty) return StreakSummary.none;

  var longest = 1;
  var run = 1;
  for (var i = 1; i < weeks.length; i++) {
    run = _weeksBetween(weeks[i - 1], weeks[i]) == 1 ? run + 1 : 1;
    if (run > longest) longest = run;
  }

  final thisWeek = weekStart(now);
  final gap = _weeksBetween(weeks.last, thisWeek);
  // `run` is the streak ending at the latest active week.
  final current = gap <= 1 ? run : 0;
  return StreakSummary(
    current: current,
    longest: longest,
    activeThisWeek: gap == 0,
    activeWeeks: weeks.length,
  );
}

/// Streak lengths (in weeks) that earn a badge.
const streakMilestones = [1, 2, 4, 8, 12];

/// The next milestone above [weeks], or null after the last one.
int? nextMilestone(int weeks) {
  for (final m in streakMilestones) {
    if (m > weeks) return m;
  }
  return null;
}

class AthleteBadge {
  const AthleteBadge({
    required this.emoji,
    required this.title,
    required this.howTo,
    required this.earned,
  });

  final String emoji;
  final String title;

  /// How to earn it, shown when tapped.
  final String howTo;
  final bool earned;
}

/// Every badge, earned or not, in display order.
List<AthleteBadge> badgesFor({
  required StreakSummary streak,
  required int spotlights,
  required int posts,
  required int eventsAttended,
  required bool verified,
}) {
  AthleteBadge streakBadge(int weeks, String emoji, String title) =>
      AthleteBadge(
        emoji: emoji,
        title: title,
        howTo:
            'Keep a $weeks-week streak: post or go to an event at least '
            'once a week, $weeks ${weeks == 1 ? 'week' : 'weeks in a row'}.',
        earned: streak.longest >= weeks,
      );
  return [
    streakBadge(1, '🔥', 'First week'),
    streakBadge(2, '⚡', '2 weeks'),
    streakBadge(4, '🌟', '1 month'),
    streakBadge(8, '💎', '2 months'),
    streakBadge(12, '👑', '3 months'),
    AthleteBadge(
      emoji: '🎬',
      title: 'Spotlight',
      howTo: 'Share your first spotlight in Huddle.',
      earned: spotlights >= 1,
    ),
    AthleteBadge(
      emoji: '📣',
      title: '10 posts',
      howTo: 'Share 10 posts in Huddle.',
      earned: posts >= 10,
    ),
    AthleteBadge(
      emoji: '🤝',
      title: 'First meetup',
      howTo: 'Go to your first event.',
      earned: eventsAttended >= 1,
    ),
    AthleteBadge(
      emoji: '🎉',
      title: 'Regular',
      howTo: 'Go to 5 events.',
      earned: eventsAttended >= 5,
    ),
    AthleteBadge(
      emoji: '✅',
      title: 'Verified',
      howTo:
          'Get verified as a national, Paralympic or Special Olympics '
          'athlete (Settings → Get verified).',
      earned: verified,
    ),
  ];
}
