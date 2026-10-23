import 'package:flutter/material.dart';

import '../../models/account.dart';
import '../../models/post.dart';
import '../../services/services.dart';
import '../../widgets/feed_widgets.dart';
import 'post_detail_screen.dart';

/// Find posts by tag, e.g. #acl. Only visible posts, without blocked
/// members. Searches post tags only, never people.
class TagSearchScreen extends StatefulWidget {
  const TagSearchScreen({super.key, required this.account, this.initialTag});

  final Account account;
  final String? initialTag;

  @override
  State<TagSearchScreen> createState() => _TagSearchScreenState();
}

class _TagSearchScreenState extends State<TagSearchScreen> {
  late final _input = TextEditingController(text: widget.initialTag ?? '');
  String? _tag;
  Future<List<Post>>? _results;

  @override
  void initState() {
    super.initState();
    if (normaliseTag(widget.initialTag ?? '') case final tag?) {
      _tag = tag;
      _results = _fetch(tag);
    }
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _search() {
    final tag = normaliseTag(_input.text);
    FocusScope.of(context).unfocus();
    if (tag == null) return;
    _input.text = tag;
    setState(() {
      _tag = tag;
      _results = _fetch(tag);
    });
  }

  Future<List<Post>> _fetch(String tag) async {
    final results = await Future.wait([
      Services.feed.withTag(tag),
      Services.safety.blockedUids(widget.account),
    ]);
    final blocked = results[1] as Set<String>;
    final muted = widget.account.profile.mutedTopics;
    return [
      for (final p in results[0] as List<Post>)
        if (!blocked.contains(p.author?.uid) && !muted.contains(p.topic)) p,
    ];
  }

  Future<void> _open(Post post) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PostDetailScreen(post: post, viewer: widget.account),
      ),
    );
    if (mounted && _tag != null) {
      setState(() {
        _results = _fetch(_tag!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Search tags')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _input,
              autofocus: widget.initialTag == null,
              autocorrect: false,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                prefixText: '# ',
                hintText: 'acl, marathon, nationals…',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: 'Search',
                  icon: const Icon(Icons.search),
                  onPressed: _search,
                ),
              ),
              onSubmitted: (_) => _search(),
            ),
          ),
          Expanded(
            child: _results == null
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Search for posts by their tags.',
                      style: textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                  )
                : FutureBuilder<List<Post>>(
                    future: _results,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        debugPrint('Tag search failed: ${snapshot.error}');
                        return Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            "Couldn't search. Try again.",
                            style: textTheme.bodyLarge,
                          ),
                        );
                      }
                      final posts = snapshot.data!;
                      if (posts.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'No posts tagged #$_tag yet.',
                            style: textTheme.bodyLarge,
                          ),
                        );
                      }
                      return ListView(
                        padding: const EdgeInsets.only(bottom: 24),
                        children: [
                          for (final post in posts)
                            PostCard(post: post, onTap: () => _open(post)),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
