import 'package:flutter/material.dart';

import '../../models/account.dart';
import '../../models/post.dart';
import '../../models/sign_up_data.dart';
import '../../services/services.dart';
import '../../widgets/feed_widgets.dart';
import '../feed/prompt_widgets.dart';
import 'easy_post_screen.dart';
import 'easy_widgets.dart';

/// Easy mode Huddle: a big "Share" button, four big category pictures,
/// then new posts in the member's categories.
class EasyHomeScreen extends StatefulWidget {
  const EasyHomeScreen({
    super.key,
    required this.account,
    required this.onCompose,
    this.onAnswerPrompt,
  });

  final Account account;

  /// Starts the step-by-step posting guide.
  final VoidCallback onCompose;

  /// Answering this week's Huddle question.
  final void Function(WeeklyPrompt prompt)? onAnswerPrompt;

  @override
  State<EasyHomeScreen> createState() => _EasyHomeScreenState();
}

class _EasyHomeScreenState extends State<EasyHomeScreen> {
  late Future<List<Post>> _posts = _fetch();

  Set<Topic> get _muted => widget.account.profile.mutedTopics;

  Set<Topic> get _topics {
    final picked = widget.account.profile.topics.isEmpty
        ? Topic.values.toSet()
        : widget.account.profile.topics;
    return picked.difference(_muted);
  }

  Future<List<Post>> _fetch() async {
    final results = await Future.wait([
      Services.feed.latest(_topics, limit: 20),
      Services.safety.blockedUids(widget.account),
    ]);
    final blocked = results[1] as Set<String>;
    return [
      for (final p in results[0] as List<Post>)
        if (!blocked.contains(p.author?.uid)) p,
    ];
  }

  Future<void> _refresh() async {
    final next = _fetch();
    setState(() {
      _posts = next;
    });
    await next.catchError((_) => <Post>[]);
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Huddle'),
        actions: const [EasyHelpButton()],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: widget.onCompose,
                  icon: const Icon(Icons.videocam_outlined),
                  label: const Text('Share or ask'),
                ),
              ),
            ),
            WeeklyPromptBanner(
              account: widget.account,
              easy: true,
              onAnswer: FeedRules.spotlightBlockedFor(widget.account) == null
                  ? widget.onAnswerPrompt
                  : null,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Text(
                'What do you want to see?',
                style: textTheme.titleLarge,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.3,
                children: [
                  for (final topic in Topic.values)
                    if (!_muted.contains(topic))
                      EasyTile(
                        icon: topicIcon(topic),
                        label: easyTopicLabel(topic),
                        onTap: () => _open(
                          EasyTopicScreen(
                            account: widget.account,
                            topic: topic,
                          ),
                        ),
                      ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
              child: Text('New posts', style: textTheme.titleLarge),
            ),
            _EasyPostList(
              posts: _posts,
              onOpen: (post) =>
                  _open(EasyPostScreen(post: post, viewer: widget.account)),
            ),
          ],
        ),
      ),
    );
  }
}

/// All posts in one topic.
class EasyTopicScreen extends StatefulWidget {
  const EasyTopicScreen({
    super.key,
    required this.account,
    required this.topic,
  });

  final Account account;
  final Topic topic;

  @override
  State<EasyTopicScreen> createState() => _EasyTopicScreenState();
}

class _EasyTopicScreenState extends State<EasyTopicScreen> {
  late Future<List<Post>> _posts = Services.feed.latest({widget.topic});

  Future<void> _refresh() async {
    final next = Services.feed.latest({widget.topic});
    setState(() {
      _posts = next;
    });
    await next.catchError((_) => <Post>[]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(topicIcon(widget.topic)),
            const SizedBox(width: 8),
            Text(easyTopicLabel(widget.topic)),
          ],
        ),
        actions: const [EasyHelpButton()],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            _EasyPostList(
              posts: _posts,
              onOpen: (post) async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        EasyPostScreen(post: post, viewer: widget.account),
                  ),
                );
                if (mounted) _refresh();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _EasyPostList extends StatelessWidget {
  const _EasyPostList({required this.posts, required this.onOpen});

  final Future<List<Post>> posts;
  final ValueChanged<Post> onOpen;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return FutureBuilder<List<Post>>(
      future: posts,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Something went wrong. Pull down to try again.',
              style: textTheme.bodyLarge,
            ),
          );
        }
        final list = snapshot.data!;
        if (list.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'No posts yet. You can be the first!',
              style: textTheme.bodyLarge,
            ),
          );
        }
        return Column(
          children: [
            for (final post in list)
              EasyPostCard(post: post, onTap: () => onOpen(post)),
          ],
        );
      },
    );
  }
}
