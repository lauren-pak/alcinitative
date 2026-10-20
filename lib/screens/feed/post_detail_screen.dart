import 'package:flutter/material.dart';

import '../../models/account.dart';
import '../../models/post.dart';
import '../../services/services.dart';
import '../../widgets/feed_widgets.dart';

/// A post with its replies, reactions and reply box.
class PostDetailScreen extends StatefulWidget {
  const PostDetailScreen({super.key, required this.post, required this.viewer});

  final Post post;
  final Account viewer;

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late Post _post = widget.post;
  List<Reply>? _replies;
  Set<String> _myHelpful = {};
  bool _beenThere = false;
  bool _isMine = false;
  bool _busy = false;
  String? _loadError;
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
        feed.hasBeenThere(_post.id, widget.viewer),
        feed.isMine(_post, widget.viewer),
      ]);
      final replies = results[1] as List<Reply>;
      final helpful = await feed.myHelpful(_post.id, replies, widget.viewer);
      if (!mounted) return;
      setState(() {
        _post = (results[0] as Post?) ?? _post;
        _replies = replies;
        _beenThere = results[2] as bool;
        _isMine = results[3] as bool;
        _myHelpful = helpful;
        _loadError = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _loadError = "Couldn't load replies. Pull to retry.");
      }
    }
  }

  /// The reply that helped the asker first, then most helpful, then oldest.
  List<Reply> get _sortedReplies {
    final replies = [...?_replies];
    replies.sort((a, b) {
      if (a.helpedAsker != b.helpedAsker) return a.helpedAsker ? -1 : 1;
      if (a.helpfulCount != b.helpfulCount) {
        return b.helpfulCount - a.helpfulCount;
      }
      return a.createdAt.compareTo(b.createdAt);
    });
    return replies;
  }

  Future<void> _run(Future<void> Function() action, String failure) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(failure)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleBeenThere() => _run(() async {
        final on = !_beenThere;
        await Services.feed.setBeenThere(_post, widget.viewer, on);
        setState(() {
          _beenThere = on;
          _post = _post.copyWith(
            beenThereCount: _post.beenThereCount + (on ? 1 : -1),
          );
        });
      }, "Couldn't save that. Try again.");

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
      }, "Couldn't save that. Try again.");

  Future<void> _markHelped(Reply reply) => _run(() async {
        await Services.feed.markHelpedAsker(_post, reply);
        setState(() {
          _post = _post.copyWith(answered: true);
          _replies = [
            for (final r in _replies!)
              r.id == reply.id ? r.copyWith(helpedAsker: true) : r,
          ];
        });
      }, "Couldn't save that. Try again.");

  Future<void> _sendReply() async {
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
    }, "Couldn't send your reply. Try again.");
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final post = _post;
    final replyBlocked = FeedRules.replyBlockedFor(widget.viewer, post);
    final canMarkHelped =
        _isMine && post.type == PostType.question && !post.answered;

    return Scaffold(
      appBar: AppBar(
        title: Text(post.typeLabel),
        actions: [
          IconButton(
            tooltip: 'Get help',
            icon: const Icon(Icons.support_outlined),
            onPressed: () => showSupportSheet(context),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    PostHeader(post: post),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        FeedChip(
                          label: post.topic.label,
                          icon: topicIcon(post.topic),
                        ),
                        if (post.answered)
                          const FeedChip(
                            label: 'Answered',
                            icon: Icons.check_circle_outline,
                            emphasis: true,
                          ),
                        if (post.journeyTitle != null)
                          FeedChip(
                            label: post.journeyTitle!,
                            icon: Icons.playlist_play,
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SelectableText(post.text, style: textTheme.bodyLarge),
                    if (post.needsAdviceBanner) ...[
                      const SizedBox(height: 12),
                      AdviceBanner(topic: post.topic),
                    ],
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _beenThere
                          ? FilledButton.icon(
                              onPressed: _busy ? null : _toggleBeenThere,
                              icon: const Icon(Icons.handshake),
                              label: Text('Been there · ${post.beenThereCount}'),
                            )
                          : OutlinedButton.icon(
                              onPressed: _busy ? null : _toggleBeenThere,
                              icon: const Icon(Icons.handshake_outlined),
                              label: Text('Been there · ${post.beenThereCount}'),
                            ),
                    ),
                    const Divider(height: 32),
                    Text(
                      post.replyCount == 1
                          ? '1 reply'
                          : '${post.replyCount} replies',
                      style: textTheme.titleMedium,
                    ),
                    if (post.type == PostType.question) ...[
                      const SizedBox(height: 8),
                      const _HelpfulNote(),
                    ],
                    const SizedBox(height: 8),
                    if (_loadError != null)
                      Text(_loadError!, style: textTheme.bodyMedium)
                    else if (_replies == null)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_replies!.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text('No replies yet.',
                            style: textTheme.bodyMedium),
                      ),
                    for (final reply in _sortedReplies)
                      _ReplyTile(
                        reply: reply,
                        markedHelpful: _myHelpful.contains(reply.id),
                        onHelpful: _busy ? null : () => _toggleHelpful(reply),
                        onHelpedMe: canMarkHelped && !_busy
                            ? () => _markHelped(reply)
                            : null,
                      ),
                  ],
                ),
              ),
            ),
            _ReplyBar(
              blockedReason: replyBlocked,
              controller: _replyText,
              sending: _busy,
              onSend: _sendReply,
            ),
          ],
        ),
      ),
    );
  }
}

class _HelpfulNote extends StatelessWidget {
  const _HelpfulNote();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline, size: 16, color: scheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '"Helpful" means it helped someone. It doesn\'t mean the person '
            'is a qualified coach, doctor or dietitian.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _ReplyTile extends StatelessWidget {
  const _ReplyTile({
    required this.reply,
    required this.markedHelpful,
    required this.onHelpful,
    required this.onHelpedMe,
  });

  final Reply reply;
  final bool markedHelpful;
  final VoidCallback? onHelpful;
  final VoidCallback? onHelpedMe;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: reply.helpedAsker
            ? scheme.primaryContainer.withValues(alpha: 0.5)
            : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (reply.helpedAsker)
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: FeedChip(
                label: 'Helped the asker',
                icon: Icons.check_circle_outline,
                emphasis: true,
              ),
            ),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${reply.author.name} · ${reply.author.subtitle}',
                  style: textTheme.labelLarge,
                ),
              ),
              Text(timeAgo(context, reply.createdAt),
                  style: textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 4),
          SelectableText(reply.text, style: textTheme.bodyMedium),
          Row(
            children: [
              TextButton.icon(
                onPressed: onHelpful,
                icon: Icon(
                  markedHelpful ? Icons.thumb_up : Icons.thumb_up_outlined,
                  size: 18,
                ),
                label: Text('Helpful · ${reply.helpfulCount}'),
              ),
              if (onHelpedMe != null)
                TextButton(
                  onPressed: onHelpedMe,
                  child: const Text('This helped me'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReplyBar extends StatelessWidget {
  const _ReplyBar({
    required this.blockedReason,
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final String? blockedReason;
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: blockedReason != null
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.lock_outline,
                          size: 18, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(blockedReason!,
                            style: Theme.of(context).textTheme.bodyMedium),
                      ),
                    ],
                  ),
                )
              : Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: maxReplyLength,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText: 'Share what worked for you…',
                          border: InputBorder.none,
                          counterText: '',
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Send reply',
                      onPressed: sending ? null : onSend,
                      icon: const Icon(Icons.send),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
