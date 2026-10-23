import 'package:flutter/material.dart';

import '../../models/account.dart';
import '../../models/post.dart';
import '../../services/services.dart';
import '../../widgets/brand.dart';
import '../../widgets/feed_widgets.dart';
import '../feed/post_detail_screen.dart';

/// A journey told as a story: the title and intro ("where it started"),
/// then its posts as chapters, oldest first, along a timeline. Meant to
/// inspire other athletes and recreational members. The owner can edit the
/// title and intro.
class JourneyScreen extends StatefulWidget {
  const JourneyScreen({super.key, required this.journey, required this.viewer});

  final Journey journey;
  final Account viewer;

  @override
  State<JourneyScreen> createState() => _JourneyScreenState();
}

class _JourneyScreenState extends State<JourneyScreen> {
  late Journey _journey = widget.journey;
  late Future<List<Post>> _posts = Services.feed.postsInJourney(
    widget.journey.id,
  );

  bool get _isOwner => _journey.ownerUid == widget.viewer.uid;

  Future<void> _reload() async {
    final next = Services.feed.postsInJourney(_journey.id);
    setState(() {
      _posts = next;
    });
    await next.catchError((_) => <Post>[]);
  }

  Future<void> _edit() async {
    final title = TextEditingController(text: _journey.title);
    final intro = TextEditingController(text: _journey.intro);
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit your story'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                maxLength: 60,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: intro,
                maxLength: maxJourneyIntroLength,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Where it started',
                  hintText: 'I started swimming at 9 at my school pool…',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    final newTitle = title.text.trim();
    final newIntro = intro.text.trim();
    // Not disposed here: the dialog's closing animation still uses them.
    if (save != true || newTitle.isEmpty || !mounted) return;
    try {
      final updated = await Services.feed.updateJourney(
        _journey,
        title: newTitle,
        intro: newIntro,
      );
      if (mounted) setState(() => _journey = updated);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Couldn't save. Check your connection."),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Journey'),
        actions: [
          if (_isOwner)
            IconButton(
              tooltip: 'Edit story',
              icon: const Icon(Icons.edit_outlined),
              onPressed: _edit,
            ),
        ],
      ),
      body: FutureBuilder<List<Post>>(
        future: _posts,
        builder: (context, snapshot) {
          final posts = snapshot.data ?? const <Post>[];
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                GradientBanner(
                  title: _journey.title,
                  body: _journey.intro.isNotEmpty
                      ? _journey.intro
                      : _isOwner
                      ? 'Tap ✏️ to tell people where your journey '
                            'started.'
                      : 'An athlete\'s journey, one chapter at a time.',
                  emoji: '📖',
                ),
                if (snapshot.connectionState != ConnectionState.done)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (snapshot.hasError)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      "Couldn't load this journey.",
                      style: textTheme.bodyLarge,
                    ),
                  )
                else if (posts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _isOwner
                          ? 'No chapters yet. Choose this journey under '
                                '"Add to a journey" when you share a spotlight.'
                          : 'No chapters yet.',
                      style: textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                  ),
                for (final (i, post) in posts.indexed)
                  _Chapter(
                    number: i + 1,
                    last: i == posts.length - 1,
                    child: PostCard(
                      post: post,
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PostDetailScreen(
                              post: post,
                              viewer: widget.viewer,
                            ),
                          ),
                        );
                        if (mounted) _reload();
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// A numbered dot on a timeline line, next to the chapter's post.
class _Chapter extends StatelessWidget {
  const _Chapter({
    required this.number,
    required this.last,
    required this.child,
  });

  final int number;
  final bool last;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 56,
            child: Column(
              children: [
                const SizedBox(height: 14),
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: Brand.sunrise,
                  ),
                  child: Text(
                    '$number',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (!last)
                  Expanded(child: Container(width: 3, color: Brand.gold)),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text('Chapter $number', style: textTheme.labelLarge),
                ),
                Transform.translate(offset: const Offset(-16, 0), child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
