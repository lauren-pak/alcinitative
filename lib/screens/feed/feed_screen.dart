import 'package:flutter/material.dart';

import '../../models/account.dart';
import '../../models/post.dart';
import '../../models/sign_up_data.dart';
import '../../services/services.dart';
import '../../widgets/feed_widgets.dart';
import 'post_detail_screen.dart';
import 'tag_search_screen.dart';

/// The feed: "For you" (questions needing answers, then the latest posts in
/// the member's topics), then one tab per topic. New posts are started from
/// the bottom bar in `HomeShell`, which rebuilds this screen afterwards.
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key, required this.account});

  final Account account;

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  /// Part of each tab's key; fixed per FeedScreen instance.
  static const _generation = 0;

  Set<Topic> get _muted => widget.account.profile.mutedTopics;

  /// Topic tabs, minus any the member muted.
  List<Topic> get _tabs =>
      [for (final t in Topic.values) if (!_muted.contains(t)) t];

  Set<Topic> get _myTopics {
    final picked = widget.account.profile.topics.isEmpty
        ? Topic.values.toSet()
        : widget.account.profile.topics;
    return picked.difference(_muted);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 1 + _tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Feed'),
          actions: [
            IconButton(
              tooltip: 'Search tags',
              icon: const Icon(Icons.tag),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TagSearchScreen(account: widget.account),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Get help',
              icon: const Icon(Icons.support_outlined),
              onPressed: () => showSupportSheet(context),
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              const Tab(icon: Icon(Icons.auto_awesome_outlined), text: 'For you'),
              for (final topic in _tabs)
                Tab(icon: Icon(topicIcon(topic)), text: topic.label),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _FeedList(
              key: ValueKey('for-you-$_generation'),
              account: widget.account,
              topics: _myTopics,
            ),
            for (final topic in _tabs)
              _FeedList(
                key: ValueKey('${topic.name}-$_generation'),
                account: widget.account,
                topics: {topic},
                needsAnswerLimit: 3,
              ),
          ],
        ),
      ),
    );
  }
}

class _FeedList extends StatefulWidget {
  const _FeedList({
    super.key,
    required this.account,
    required this.topics,
    this.needsAnswerLimit = 5,
  });

  final Account account;
  final Set<Topic> topics;
  final int needsAnswerLimit;

  @override
  State<_FeedList> createState() => _FeedListState();
}

class _FeedListState extends State<_FeedList>
    with AutomaticKeepAliveClientMixin {
  late Future<(List<Post>, List<Post>)> _load = _fetch();

  @override
  bool get wantKeepAlive => true;

  Future<(List<Post>, List<Post>)> _fetch() async {
    final feed = Services.feed;
    final results = await Future.wait([
      feed.needsAnswer(widget.topics, limit: widget.needsAnswerLimit),
      feed.latest(widget.topics),
      Services.safety.blockedUids(widget.account),
    ]);
    final blocked = results[2] as Set<String>;
    List<Post> shown(Object list) => [
          for (final p in list as List<Post>)
            if (!blocked.contains(p.author?.uid)) p,
        ];
    return (shown(results[0]), shown(results[1]));
  }

  Future<void> _refresh() async {
    final next = _fetch();
    setState(() {
      _load = next;
    });
    await next.catchError((_) => (<Post>[], <Post>[]));
  }

  Future<void> _open(Post post) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PostDetailScreen(post: post, viewer: widget.account),
      ),
    );
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final textTheme = Theme.of(context).textTheme;

    return FutureBuilder<(List<Post>, List<Post>)>(
      future: _load,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          debugPrint('Feed failed to load: ${snapshot.error}');
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  "Couldn't load posts. Pull down to try again.",
                  style: textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }
        final (needs, latest) = snapshot.data!;
        final needIds = {for (final p in needs) p.id};
        final rest = [for (final p in latest) if (!needIds.contains(p.id)) p];

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.only(top: 8, bottom: 96),
            children: [
              if (needs.isNotEmpty) ...[
                const _SectionHeader(
                  title: 'Needs an answer',
                  subtitle: 'Questions waiting for advice from someone '
                      "who's been there.",
                  icon: Icons.contact_support_outlined,
                ),
                for (final post in needs)
                  PostCard(post: post, onTap: () => _open(post)),
              ],
              const _SectionHeader(
                title: 'Latest',
                icon: Icons.schedule,
              ),
              if (rest.isEmpty && needs.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'No posts yet. Be the first to share.',
                    style: textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                )
              else if (rest.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Nothing else yet.', style: textTheme.bodyMedium),
                ),
              for (final post in rest)
                PostCard(post: post, onTap: () => _open(post)),
            ],
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.icon, this.subtitle});

  final String title;
  final IconData icon;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: textTheme.titleMedium),
                if (subtitle != null)
                  Text(subtitle!, style: textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
