import 'package:flutter/material.dart';

import '../../models/account.dart';
import '../../models/post.dart';
import '../../services/services.dart';
import '../../widgets/media_widgets.dart';
import 'easy_widgets.dart';

/// A post in Easy mode: big text, "Me too", a simple list of replies, and a
/// big reply box. Same rules as the standard view (`FeedRules`).
class EasyPostScreen extends StatefulWidget {
  const EasyPostScreen({super.key, required this.post, required this.viewer});

  final Post post;
  final Account viewer;

  @override
  State<EasyPostScreen> createState() => _EasyPostScreenState();
}

class _EasyPostScreenState extends State<EasyPostScreen> {
  late Post _post = widget.post;
  List<Reply>? _replies;
  List<Post> _responses = [];
  Set<String> _myHelpful = {};
  bool _meToo = false;
  bool _isMine = false;
  bool _busy = false;
  final _replyText = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _replyText.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final feed = Services.feed;
    try {
      final results = await Future.wait([
        feed.getPost(_post.id),
        feed.replies(_post.id),
        feed.responsesTo(_post.id),
        feed.hasBeenThere(_post.id, widget.viewer),
        feed.isMine(_post, widget.viewer),
      ]);
      final replies = (results[1] as List<Reply>)
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      final helpful = await feed.myHelpful(_post.id, replies, widget.viewer);
      if (!mounted) return;
      setState(() {
        _post = (results[0] as Post?) ?? _post;
        _replies = replies;
        _responses = results[2] as List<Post>;
        _meToo = results[3] as bool;
        _isMine = results[4] as bool;
        _myHelpful = helpful;
      });
    } catch (_) {
      if (mounted) setState(() => _replies = const []);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('That did not work. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleMeToo() => _run(() async {
        final on = !_meToo;
        await Services.feed.setBeenThere(_post, widget.viewer, on);
        setState(() {
          _meToo = on;
          _post = _post.copyWith(
              beenThereCount: _post.beenThereCount + (on ? 1 : -1));
        });
      });

  Future<void> _toggleHelpful(Reply reply) => _run(() async {
        final on = !_myHelpful.contains(reply.id);
        await Services.feed.setHelpful(reply, widget.viewer, on);
        setState(() {
          on ? _myHelpful.add(reply.id) : _myHelpful.remove(reply.id);
          _replies = [
            for (final r in _replies!)
              r.id == reply.id
                  ? r.copyWith(helpfulCount: r.helpfulCount + (on ? 1 : -1))
                  : r,
          ];
        });
      });

  Future<void> _markHelped(Reply reply) => _run(() async {
        await Services.feed.markHelpedAsker(_post, reply);
        setState(() {
          _post = _post.copyWith(answered: true);
          _replies = [
            for (final r in _replies!)
              r.id == reply.id ? r.copyWith(helpedAsker: true) : r,
          ];
        });
      });

  Future<void> _send() async {
    final text = _replyText.text.trim();
    if (text.isEmpty) return;
    await _run(() async {
      final reply = await Services.feed.addReply(widget.viewer, _post, text);
      if (!mounted) return;
      _replyText.clear();
      FocusScope.of(context).unfocus();
      setState(() {
        _replies = [...?_replies, reply];
        _post = _post.copyWith(replyCount: _post.replyCount + 1);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final post = _post;
    final blocked = FeedRules.replyBlockedFor(widget.viewer, post);
    final canMarkHelped =
        _isMine && post.type == PostType.question && !post.answered;

    return Scaffold(
      appBar: AppBar(
        title: Text(post.type == PostType.question ? 'Question' : 'Post'),
        actions: const [EasyHelpButton()],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                EasyAvatar(name: post.authorName, anonymous: post.anonymous),
                const SizedBox(width: 12),
                Expanded(child: Text(post.authorName, style: textTheme.titleLarge)),
              ],
            ),
            const SizedBox(height: 16),
            SelectableText(post.text, style: textTheme.titleMedium),
            if (post.media.isNotEmpty) ...[
              const SizedBox(height: 16),
              PostMediaView(media: post.media),
            ],
            if (post.needsAdviceBanner) ...[
              const SizedBox(height: 16),
              easyAdviceNote(post.topic),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: _meToo
                  ? FilledButton(
                      onPressed: _busy ? null : _toggleMeToo,
                      child: Text('👋 Me too · ${post.beenThereCount}'),
                    )
                  : OutlinedButton(
                      onPressed: _busy ? null : _toggleMeToo,
                      child: Text('👋 Me too · ${post.beenThereCount}'),
                    ),
            ),
            const SizedBox(height: 24),
            Text('💬 Talk', style: textTheme.titleLarge),
            if (post.type == PostType.question) ...[
              const SizedBox(height: 8),
              const EasyNote(
                text: '👍 means the answer helped someone. The person may not '
                    'be a coach or doctor.',
              ),
            ],
            const SizedBox(height: 8),
            if (_replies == null)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_replies!.isEmpty && _responses.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('Nobody has replied yet.', style: textTheme.bodyLarge),
              ),
            for (final reply in _replies ?? const <Reply>[])
              _EasyReply(
                reply: reply,
                helpful: _myHelpful.contains(reply.id),
                onHelpful: _busy ? null : () => _toggleHelpful(reply),
                onHelpedMe:
                    canMarkHelped && !_busy ? () => _markHelped(reply) : null,
              ),
            for (final response in _responses)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.post_add, size: 32),
                  title: Text('${response.authorName} answered with a post'),
                  subtitle: Text(response.text,
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) =>
                        EasyPostScreen(post: response, viewer: widget.viewer),
                  )),
                ),
              ),
            const SizedBox(height: 16),
            if (blocked != null)
              EasyNote(text: blocked, icon: Icons.lock_outline)
            else ...[
              TextField(
                controller: _replyText,
                minLines: 2,
                maxLines: 5,
                maxLength: maxReplyLength,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Write a reply',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _send,
                  icon: const Icon(Icons.send),
                  label: const Text('Send'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EasyReply extends StatelessWidget {
  const _EasyReply({
    required this.reply,
    required this.helpful,
    required this.onHelpful,
    required this.onHelpedMe,
  });

  final Reply reply;
  final bool helpful;
  final VoidCallback? onHelpful;
  final VoidCallback? onHelpedMe;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: reply.helpedAsker
            ? scheme.primaryContainer
            : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (reply.helpedAsker)
            Text('✅ This helped', style: textTheme.titleSmall),
          Row(
            children: [
              EasyAvatar(name: reply.author.name),
              const SizedBox(width: 12),
              Expanded(child: Text(reply.author.name, style: textTheme.titleMedium)),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(reply.text, style: textTheme.bodyLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: onHelpful,
                child: Text('${helpful ? '👍' : '👍🏻'} ${reply.helpfulCount}'),
              ),
              if (onHelpedMe != null)
                FilledButton(
                  onPressed: onHelpedMe,
                  child: const Text('✅ This helped me'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
