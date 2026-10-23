import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/account.dart';
import '../../models/display_mode.dart';
import '../../models/event.dart';
import '../../models/media.dart';
import '../../models/post.dart';
import '../../models/sign_up_data.dart';
import '../../models/streaks.dart';
import '../../services/services.dart';
import '../../widgets/athlete_id_card.dart';
import '../../widgets/brand.dart';
import '../../widgets/feed_widgets.dart';
import '../../widgets/minor_protections_notice.dart';
import '../feed/post_detail_screen.dart';
import '../find_athlete_screen.dart';
import '../intro_screen.dart';
import '../moderation/moderation_screen.dart';
import '../verification/verification_queue_screen.dart';
import 'journey_screen.dart';
import 'settings_screen.dart';

/// How the member signs in, read from Firebase Auth (not stored in the
/// profile).
String? signInSummary() {
  final user = Services.auth.currentUser;
  if (user == null) return null;
  return switch (user.method) {
    SignUpMethod.google => 'Google · ${user.email ?? ''}',
    SignUpMethod.phone => 'Phone · ${user.phone ?? ''}',
    SignUpMethod.email => 'Email · ${user.email ?? ''}',
  };
}

/// Everything the profile shows, loaded together.
class _ProfileData {
  const _ProfileData({
    required this.posts,
    required this.journeys,
    required this.attended,
    required this.streak,
    required this.badges,
  });

  final List<Post> posts;
  final List<Journey> journeys;
  final List<SportEvent> attended;
  final StreakSummary streak;
  final List<AthleteBadge> badges;
}

/// The member's own profile, laid out like a social profile: avatar and
/// stats, name and sport, actions, weekly streak, badges, journey stories,
/// then a grid of their posts. Settings is at the top and the bottom.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.account,
    required this.isNewAccount,
  });

  final Account account;
  final bool isNewAccount;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<_ProfileData> _data = _fetch();
  late final Future<(bool, bool)> _roles = _fetchRoles();

  Account get _account => widget.account;

  Future<(bool, bool)> _fetchRoles() async {
    final results = await Future.wait([
      Services.safety.isModerator(_account.uid),
      Services.verification.canVerify(_account.uid),
    ]);
    return (results[0], results[1]);
  }

  Future<_ProfileData> _fetch() async {
    final results = await Future.wait<Object>([
      Services.feed.postsBy(_account),
      Services.feed.myJourneys(_account),
      Services.events.attended(_account).catchError((_) => <SportEvent>[]),
    ]);
    final posts = results[0] as List<Post>;
    final attended = results[2] as List<SportEvent>;
    final streak = computeStreak([
      for (final p in posts) p.createdAt,
      for (final e in attended) e.startsAt,
    ], DateTime.now());
    return _ProfileData(
      posts: posts,
      journeys: results[1] as List<Journey>,
      attended: attended,
      streak: streak,
      badges: badgesFor(
        streak: streak,
        spotlights: posts.where((p) => p.type == PostType.experience).length,
        posts: posts.length,
        eventsAttended: attended.length,
        verified: _account.verified,
      ),
    );
  }

  Future<void> _reload() async {
    final next = _fetch();
    setState(() {
      _data = next;
    });
    await next;
  }

  Future<void> _shareId(BuildContext buttonContext) async {
    final idName = _account.profile.role == UserRole.athlete
        ? 'athlete ID'
        : 'member ID';
    // iPad needs to know where to anchor the share sheet.
    final box = buttonContext.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        text:
            "I'm on Athlete App! Find me with my $idName: "
            '${_account.athleteId}',
        subject: 'My Athlete App $idName',
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  Future<void> _openSettings() => _open(SettingsScreen(account: _account));

  void _showIdCard() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      child: AthleteIdCard(account: _account),
    ),
  );

  Future<void> _logOut() async {
    await Services.auth.signOut();
    // The next person starts in the standard view.
    displayMode.value = DisplayMode.standard;
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const IntroScreen()),
      (_) => false,
    );
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (mounted) _reload().catchError((_) {});
  }

  Future<void> _newJourney() async {
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New journey story'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 60,
          decoration: const InputDecoration(
            hintText: 'e.g. Road to the SEA Games',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    // Not disposed here: the dialog's closing animation still uses it.
    if (title == null || title.isEmpty || !mounted) return;
    final journey = await Services.feed.createJourney(_account, title);
    if (mounted) _open(JourneyScreen(journey: journey, viewer: _account));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final profile = _account.profile;
    final firstName = profile.name.split(' ').first;
    final isMinor = profile.isMinorOn(DateTime.now());
    final details = [
      if (profile.role == UserRole.athlete) ...[
        ?profile.sportName,
        ?profile.level?.label,
      ] else
        profile.role?.label,
    ].whereType<String>().where((s) => s.isNotEmpty).join(' · ');

    return Scaffold(
      appBar: AppBar(
        title: Text(_account.athleteId),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: _openSettings,
          ),
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout),
            onPressed: _logOut,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _reload().catchError((_) {}),
        child: FutureBuilder<_ProfileData>(
          future: _data,
          builder: (context, snapshot) {
            final data = snapshot.data;
            if (snapshot.hasError) {
              debugPrint('Profile failed to load: ${snapshot.error}');
            }
            return ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.isNewAccount) ...[
                        Text(
                          'Welcome, $firstName!',
                          style: textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "You're all set. Here's your ID card.",
                          style: textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 12),
                        AthleteIdCard(account: _account),
                        const SizedBox(height: 20),
                      ],
                      Row(
                        children: [
                          GradientAvatar(
                            name: profile.name,
                            radius: 40,
                            verified: _account.verified,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _Stat(
                                  value: '${data?.posts.length ?? '–'}',
                                  label: 'Posts',
                                ),
                                _Stat(
                                  value: data == null
                                      ? '–'
                                      : '🔥${data.streak.current}',
                                  label: 'Week streak',
                                ),
                                _Stat(
                                  value: data == null
                                      ? '–'
                                      : '${data.badges.where((b) => b.earned).length}',
                                  label: 'Badges',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              profile.name,
                              style: textTheme.titleLarge,
                            ),
                          ),
                          if (_account.verified) ...[
                            const SizedBox(width: 6),
                            const VerifiedBadge(size: 20),
                          ],
                        ],
                      ),
                      if (details.isNotEmpty)
                        Text(details, style: textTheme.bodyMedium),
                      if (profile.category case final c?)
                        Text(
                          c.label,
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.tonal(
                              onPressed: _showIdCard,
                              child: const Text('ID card'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Builder(
                              builder: (buttonContext) => OutlinedButton(
                                onPressed: () => _shareId(buttonContext),
                                child: const FittedBox(
                                  child: Text('Share my ID'),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _open(const FindAthleteScreen()),
                              child: const FittedBox(
                                child: Text('Find athlete'),
                              ),
                            ),
                          ),
                        ],
                      ),
                      FutureBuilder<(bool, bool)>(
                        future: _roles,
                        builder: (context, snapshot) {
                          final (moderator, reviewer) =
                              snapshot.data ?? (false, false);
                          if (!moderator && !reviewer) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Wrap(
                              spacing: 8,
                              children: [
                                if (moderator)
                                  ActionChip(
                                    avatar: const Icon(Icons.gavel, size: 18),
                                    label: const Text('Moderation'),
                                    onPressed: () =>
                                        _open(const ModerationScreen()),
                                  ),
                                if (reviewer)
                                  ActionChip(
                                    avatar: const Icon(
                                      Icons.verified,
                                      size: 18,
                                    ),
                                    label: const Text('Verify athletes'),
                                    onPressed: () => _open(
                                      VerificationQueueScreen(
                                        reviewer: _account,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                      if (isMinor) ...[
                        const SizedBox(height: 12),
                        const MinorProtectionsNotice(),
                      ],
                    ],
                  ),
                ),
                if (data == null && !snapshot.hasError)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (data == null)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      "Couldn't load your profile. Pull down to try again.",
                      style: textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                  )
                else ...[
                  StreakCard(streak: data.streak),
                  _BadgeRow(badges: data.badges),
                  if (profile.role == UserRole.athlete)
                    _JourneyRow(
                      journeys: data.journeys,
                      onOpen: (j) =>
                          _open(JourneyScreen(journey: j, viewer: _account)),
                      onNew: _newJourney,
                    ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        Icon(Icons.grid_on),
                        SizedBox(width: 8),
                        Text(
                          'Posts',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                  _PostGrid(
                    posts: data.posts,
                    onOpen: (post) =>
                        _open(PostDetailScreen(post: post, viewer: _account)),
                  ),
                ],
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                  child: OutlinedButton.icon(
                    onPressed: _openSettings,
                    icon: const Icon(Icons.settings_outlined),
                    label: const Text('Settings'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        Text(
          value,
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        Text(label, style: textTheme.bodySmall),
      ],
    );
  }
}

/// "🔥 3-week streak", with progress to the next badge.
class StreakCard extends StatelessWidget {
  const StreakCard({super.key, required this.streak});

  final StreakSummary streak;

  @override
  Widget build(BuildContext context) {
    final next = nextMilestone(streak.current);
    final weeks = streak.current;
    final title = weeks == 0 ? 'Start a streak!' : '$weeks-week streak';
    final body = weeks == 0
        ? 'Share a post or go to an event this week to start your streak.'
        : streak.activeThisWeek
        ? "You've kept it going this week. See you next week!"
        : 'Post or go to an event this week to keep it going.';
    return GradientBanner(
      title: title,
      body: body,
      emoji: weeks == 0 ? '🌱' : '🔥',
      action: next == null
          ? Text(
              'Longest streak: ${streak.longest} weeks 👑',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: weeks / next,
                    minHeight: 8,
                    color: Colors.white,
                    backgroundColor: Colors.white24,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${next - weeks} more ${next - weeks == 1 ? 'week' : 'weeks'} '
                  'to your $next-week badge',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
    );
  }
}

/// Badges as round "highlights": earned ones glow, locked ones are grey.
class _BadgeRow extends StatelessWidget {
  const _BadgeRow({required this.badges});

  final List<AthleteBadge> badges;

  void _explain(BuildContext context, AthleteBadge b) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: Text(b.emoji, style: const TextStyle(fontSize: 44)),
      title: Text(b.title),
      content: Text(b.earned ? 'Earned! ${b.howTo}' : b.howTo),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final earned = badges.where((b) => b.earned).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            'Badges · $earned of ${badges.length}',
            style: textTheme.titleMedium,
          ),
        ),
        SizedBox(
          height: 96,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final b in badges)
                InkWell(
                  borderRadius: BorderRadius.circular(40),
                  onTap: () => _explain(context, b),
                  child: SizedBox(
                    width: 76,
                    child: Column(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: b.earned ? Brand.ring : null,
                            color: b.earned ? null : Colors.black12,
                          ),
                          child: Container(
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                            alignment: Alignment.center,
                            child: Opacity(
                              opacity: b.earned ? 1 : 0.3,
                              child: Text(
                                b.emoji,
                                style: const TextStyle(fontSize: 26),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          b.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Journey stories as round highlights, with "New" first.
class _JourneyRow extends StatelessWidget {
  const _JourneyRow({
    required this.journeys,
    required this.onOpen,
    required this.onNew,
  });

  final List<Journey> journeys;
  final ValueChanged<Journey> onOpen;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    Widget circle({required Widget child, Gradient? gradient}) => Container(
      width: 64,
      height: 64,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: gradient,
        border: gradient == null
            ? Border.all(color: Brand.navy.withValues(alpha: 0.2))
            : null,
      ),
      child: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
        alignment: Alignment.center,
        child: child,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text('My journey stories', style: textTheme.titleMedium),
        ),
        SizedBox(
          height: 100,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              InkWell(
                onTap: onNew,
                borderRadius: BorderRadius.circular(40),
                child: SizedBox(
                  width: 80,
                  child: Column(
                    children: [
                      circle(child: const Icon(Icons.add, size: 28)),
                      const SizedBox(height: 4),
                      Text('New', style: textTheme.labelSmall),
                    ],
                  ),
                ),
              ),
              for (final j in journeys)
                InkWell(
                  onTap: () => onOpen(j),
                  borderRadius: BorderRadius.circular(40),
                  child: SizedBox(
                    width: 80,
                    child: Column(
                      children: [
                        circle(
                          gradient: Brand.sunrise,
                          child: const Text(
                            '📖',
                            style: TextStyle(fontSize: 26),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          j.title,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Three-column grid of the member's posts, coloured by category.
class _PostGrid extends StatelessWidget {
  const _PostGrid({required this.posts, required this.onOpen});

  final List<Post> posts;
  final ValueChanged<Post> onOpen;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    if (posts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          "You haven't posted yet. Share your first spotlight in Huddle!",
          style: textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
      );
    }
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 2),
      mainAxisSpacing: 2,
      crossAxisSpacing: 2,
      children: [
        for (final post in posts)
          InkWell(
            onTap: () => onOpen(post),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    topicColor(post.topic),
                    Color.lerp(topicColor(post.topic), Brand.navy, 0.45)!,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        topicEmoji(post.topic),
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: Text(
                          post.text,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Row(
                      children: [
                        if (post.media.any((m) => m.kind == MediaKind.video))
                          const Icon(
                            Icons.videocam,
                            size: 16,
                            color: Colors.white,
                          ),
                        if (post.anonymous)
                          const Tooltip(
                            message:
                                'Posted anonymously. Only you can see '
                                'it is yours.',
                            child: Icon(
                              Icons.visibility_off,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        if (post.isHeld)
                          const Tooltip(
                            message: 'Waiting for a moderator',
                            child: Icon(
                              Icons.hourglass_top,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
