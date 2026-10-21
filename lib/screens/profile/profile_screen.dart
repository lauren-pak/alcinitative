import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/account.dart';
import '../../models/display_mode.dart';
import '../../models/post.dart';
import '../../models/sign_up_data.dart';
import '../../services/services.dart';
import '../../widgets/athlete_id_card.dart';
import '../../widgets/feed_widgets.dart';
import '../../widgets/minor_protections_notice.dart';
import '../feed/post_detail_screen.dart';
import '../find_athlete_screen.dart';
import '../intro_screen.dart';
import '../moderation/moderation_screen.dart';
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

enum _ProfileTab { posts, journeys }

/// The member's own profile: ID card and actions, then their posts and
/// journeys as two tabs.
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
  _ProfileTab _tab = _ProfileTab.posts;
  late Future<List<Post>> _posts = Services.feed.postsBy(widget.account);
  late Future<List<Journey>> _journeys =
      Services.feed.myJourneys(widget.account);
  late final Future<bool> _isModerator =
      Services.safety.isModerator(widget.account.uid);

  Account get _account => widget.account;

  Future<void> _reload() async {
    final posts = Services.feed.postsBy(_account);
    final journeys = Services.feed.myJourneys(_account);
    setState(() {
      _posts = posts;
      _journeys = journeys;
    });
    try {
      await Future.wait<Object>([posts, journeys]);
    } catch (_) {
      // Shown by each list's FutureBuilder.
    }
  }

  Future<void> _shareId(BuildContext buttonContext, String idName) async {
    // iPad needs to know where to anchor the share sheet.
    final box = buttonContext.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        text: "I'm on Athlete App! Find me with my $idName: "
            '${_account.athleteId}',
        subject: 'My Athlete App $idName',
        sharePositionOrigin:
            box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }
  Future<void> _openSettings() => _open(SettingsScreen(account: _account));


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
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final profile = _account.profile;
    final firstName = profile.name.split(' ').first;
    final isMinor = profile.isMinorOn(DateTime.now());
    final idName =
        profile.role == UserRole.athlete ? 'athlete ID' : 'member ID';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: _openSettings,
          ),
          TextButton(onPressed: _logOut, child: const Text('Log out')),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.isNewAccount) ...[
                    Text('Welcome, $firstName!',
                        style: textTheme.headlineSmall),
                    const SizedBox(height: 4),
                    Text("You're all set. Here's your $idName.",
                        style: textTheme.bodyLarge),
                    const SizedBox(height: 16),
                  ],
                  AthleteIdCard(account: _account),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Builder(
                          builder: (buttonContext) => FilledButton.tonalIcon(
                            onPressed: () => _shareId(buttonContext, idName),
                            icon: const Icon(Icons.ios_share),
                            label: const Text('Share my ID'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _open(const FindAthleteScreen()),
                          icon: const Icon(Icons.person_search_outlined),
                          label: const Text('Find athlete'),
                        ),
                      ),
                    ],
                  ),
                  FutureBuilder<bool>(
                    future: _isModerator,
                    builder: (context, snapshot) => snapshot.data == true
                        ? Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: FilledButton.tonalIcon(
                              onPressed: () => _open(const ModerationScreen()),
                              icon: const Icon(Icons.gavel),
                              label: const Text('Moderation'),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  if (isMinor) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Only share your ID with people you know. Adults '
                      "can't look up under-18s' IDs.",
                      style: textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    const MinorProtectionsNotice(),
                  ],
                  const SizedBox(height: 20),
                  SegmentedButton<_ProfileTab>(
                    segments: const [
                      ButtonSegment(
                        value: _ProfileTab.posts,
                        icon: Icon(Icons.article_outlined),
                        label: Text('Posts'),
                      ),
                      ButtonSegment(
                        value: _ProfileTab.journeys,
                        icon: Icon(Icons.playlist_play),
                        label: Text('Journeys'),
                      ),
                    ],
                    selected: {_tab},
                    onSelectionChanged: (s) => setState(() => _tab = s.first),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            if (_tab == _ProfileTab.posts) _postsList() else _journeysList(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
              child: OutlinedButton.icon(
                onPressed: _openSettings,
                icon: const Icon(Icons.settings_outlined),
                label: const Text('Settings'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty(String text) => Padding(
        padding: const EdgeInsets.all(24),
        child: Text(text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge),
      );

  Widget _postsList() {
    return FutureBuilder<List<Post>>(
      future: _posts,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return _empty("Couldn't load your posts. Pull down to try again.");
        }
        final posts = snapshot.data!;
        if (posts.isEmpty) return _empty("You haven't posted yet.");
        return Column(
          children: [
            for (final post in posts) ...[
              if (post.anonymous)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                  child: Row(
                    children: [
                      const Icon(Icons.visibility_off_outlined, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Posted anonymously. Only you can see it is yours.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              PostCard(
                post: post,
                onTap: () =>
                    _open(PostDetailScreen(post: post, viewer: _account)),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _journeysList() {
    return FutureBuilder<List<Journey>>(
      future: _journeys,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return _empty("Couldn't load your journeys. Pull down to try again.");
        }
        final journeys = snapshot.data!;
        if (journeys.isEmpty) {
          return _empty('No journeys yet. Create one when you write a post, '
              'then tag your posts into it.');
        }
        return Column(
          children: [
            for (final journey in journeys)
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.playlist_play)),
                title: Text(journey.title),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _open(
                  JourneyScreen(journey: journey, viewer: _account),
                ),
              ),
          ],
        );
      },
    );
  }
}
