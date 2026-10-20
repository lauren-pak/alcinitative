import 'package:flutter/material.dart';

import '../../models/account.dart';
import '../../models/post.dart';
import '../../services/services.dart';
import '../../widgets/feed_widgets.dart';
import '../feed/post_detail_screen.dart';

/// A journey's posts, oldest first, like a playlist.
class JourneyScreen extends StatefulWidget {
  const JourneyScreen({super.key, required this.journey, required this.viewer});

  final Journey journey;
  final Account viewer;

  @override
  State<JourneyScreen> createState() => _JourneyScreenState();
}

class _JourneyScreenState extends State<JourneyScreen> {
  late Future<List<Post>> _posts =
      Services.feed.postsInJourney(widget.journey.id);

  Future<void> _reload() async {
    final next = Services.feed.postsInJourney(widget.journey.id);
    setState(() {
      _posts = next;
    });
    await next.catchError((_) => <Post>[]);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.journey.title)),
      body: FutureBuilder<List<Post>>(
        future: _posts,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final posts = snapshot.data ?? const <Post>[];
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                if (snapshot.hasError)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text("Couldn't load this journey.",
                        style: textTheme.bodyLarge),
                  )
                else if (posts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No posts in this journey yet. Choose it under '
                      '"Add to a journey" when you write a post.',
                      style: textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                  ),
                for (final (i, post) in posts.indexed) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                    child: Text('Part ${i + 1}', style: textTheme.labelLarge),
                  ),
                  PostCard(
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
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
