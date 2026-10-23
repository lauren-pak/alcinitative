import 'package:flutter/material.dart';

import '../../models/account.dart';
import '../../models/post.dart';
import '../../models/sign_up_data.dart';
import '../../services/services.dart';
import '../../widgets/feed_widgets.dart';
import 'post_detail_screen.dart';
import 'prompt_widgets.dart';
import 'tag_search_screen.dart';

/// Huddle: where athletes share. Two tabs:
/// - **Spotlight**: quick clips and stories from athletes' own journeys.
/// - **Ask an athlete**: questions answered with "what worked for me".
/// Each tab can be narrowed to one category. The button at the bottom
/// starts a post of that tab's kind through [onCompose], which `HomeShell`
/// handles (and rebuilds this screen afterwards).
class HuddleScreen extends StatefulWidget {
  const HuddleScreen({
    super.key,
    required this.account,
    required this.onCompose,
    this.onAnswerPrompt,
  });

  final Account account;
  final void Function(PostType type) onCompose;

  /// Answering this week's Huddle question with a spotlight.
  final void Function(WeeklyPrompt prompt)? onAnswerPrompt;

  @override
  State<HuddleScreen> createState() => _HuddleScreenState();
}

class _HuddleScreenState extends State<HuddleScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this)
    ..addListener(() {
      if (!_tabs.indexIsChanging) setState(() {});
    });

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  bool get _onAsk => _tabs.index == 1;

  /// Only verified athletes share spotlights; anyone can ask.
  bool get _canShare => FeedRules.spotlightBlockedFor(widget.account) == null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Huddle'),
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
          controller: _tabs,
          tabs: const [
            Tab(icon: Icon(Icons.auto_awesome_outlined), text: 'Spotlight'),
            Tab(
              icon: Icon(Icons.question_answer_outlined),
              text: 'Ask an athlete',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _HuddleList(
            account: widget.account,
            type: PostType.experience,
            header: [
              WeeklyPromptBanner(
                account: widget.account,
                onAnswer: _canShare ? widget.onAnswerPrompt : null,
              ),
              if (!_canShare)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: Text(
                    '✨ ${FeedRules.spotlightBlockedFor(widget.account)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ),
          _HuddleList(account: widget.account, type: PostType.question),
        ],
      ),
      floatingActionButton: _onAsk
          ? FloatingActionButton.extended(
              heroTag: 'ask',
              onPressed: () => widget.onCompose(PostType.question),
              icon: const Icon(Icons.help_outline),
              label: const Text('Ask a question'),
            )
          : _canShare
          ? FloatingActionButton.extended(
              heroTag: 'share',
              onPressed: () => widget.onCompose(PostType.experience),
              icon: const Icon(Icons.videocam_outlined),
              label: const Text('Share a spotlight'),
            )
          : null,
    );
  }
}

/// One Huddle tab: an intro line, category chips, then posts.
class _HuddleList extends StatefulWidget {
  const _HuddleList({
    required this.account,
    required this.type,
    this.header = const [],
  });

  final Account account;
  final PostType type;

  /// Shown above the intro, e.g. the weekly question.
  final List<Widget> header;

  @override
  State<_HuddleList> createState() => _HuddleListState();
}

class _HuddleListState extends State<_HuddleList>
    with AutomaticKeepAliveClientMixin {
  /// Null for all categories.
  Topic? _topic;
  late Future<(List<Post>, List<Post>)> _load = _fetch();

  @override
  bool get wantKeepAlive => true;

  bool get _isAsk => widget.type == PostType.question;

  Set<Topic> get _muted => widget.account.profile.mutedTopics;

  /// Categories to show as chips, minus any the member muted.
  List<Topic> get _chips => [
    for (final t in Topic.values)
      if (!_muted.contains(t)) t,
  ];

  Set<Topic> get _topics => _topic == null ? _chips.toSet() : {_topic!};

  /// (questions needing an answer, latest posts), without blocked members.
  Future<(List<Post>, List<Post>)> _fetch() async {
    final feed = Services.feed;
    final results = await Future.wait([
      _isAsk ? feed.needsAnswer(_topics) : Future.value(<Post>[]),
      feed.latest(_topics, type: widget.type),
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

  void _pick(Topic? topic) {
    setState(() => _topic = topic);
    _refresh();
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

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 96),
        children: [
          ...widget.header,
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              _isAsk
                  ? 'Ask athletes what worked for them. Answers are their own '
                        'experience, not professional advice.'
                  : 'Quick clips and moments from athletes\' journeys: '
                        'training wins, mindset, game day and team life.',
              style: textTheme.bodyMedium,
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: _topic == null,
                  onSelected: (_) => _pick(null),
                ),
                for (final topic in _chips) ...[
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text('${topicEmoji(topic)} ${topic.label}'),
                    selected: _topic == topic,
                    selectedColor: topicColor(topic).withValues(alpha: 0.22),
                    showCheckmark: false,
                    onSelected: (_) => _pick(topic),
                  ),
                ],
              ],
            ),
          ),
          FutureBuilder<(List<Post>, List<Post>)>(
            future: _load,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                debugPrint('Huddle failed to load: ${snapshot.error}');
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    "Couldn't load posts. Pull down to try again.",
                    style: textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                );
              }
              final (needs, latest) = snapshot.data!;
              final needIds = {for (final p in needs) p.id};
              final rest = [
                for (final p in latest)
                  if (!needIds.contains(p.id)) p,
              ];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (needs.isNotEmpty) ...[
                    const _SectionHeader(
                      title: 'Needs an answer',
                      subtitle:
                          'Questions waiting for an athlete who has '
                          'been there.',
                      icon: Icons.contact_support_outlined,
                    ),
                    for (final post in needs)
                      PostCard(post: post, onTap: () => _open(post)),
                  ],
                  if (_isAsk && needs.isNotEmpty)
                    const _SectionHeader(title: 'Latest', icon: Icons.schedule),
                  if (rest.isEmpty && needs.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _isAsk
                            ? 'No questions yet. Ask the first one!'
                            : 'No spotlights yet. Be the first to share.',
                        style: textTheme.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  for (final post in rest)
                    PostCard(post: post, onTap: () => _open(post)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.icon,
    this.subtitle,
  });

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
