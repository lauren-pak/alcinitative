import 'package:flutter/material.dart';

import '../../models/account.dart';
import '../../models/moderation.dart';
import '../../models/post.dart';
import '../../services/services.dart';
import '../../widgets/feed_widgets.dart';
import '../../widgets/media_widgets.dart';
import '../../widgets/safety_widgets.dart';
import '../../widgets/tag_widgets.dart';
import 'capture_screen.dart';
import 'edit_post_screen.dart';
import 'tag_search_screen.dart';

/// A post with its comments thread: replies (which can be replied to,
/// shown indented) and response posts (shown as linked cards).
class PostDetailScreen extends StatefulWidget {
  const PostDetailScreen({super.key, required this.post, required this.viewer});

  final Post post;
  final Account viewer;

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

/// Deeper replies are shown at this indent rather than drifting right.
const _maxIndent = 3;

class _PostDetailScreenState extends State<PostDetailScreen> {
  late Post _post = widget.post;
  List<Reply>? _replies;
  List<Post> _responses = [];
  Set<String> _myHelpful = {};
  bool _beenThere = false;
  bool _isMine = false;
  bool _busy = false;
  String? _loadError;

  /// The reply being answered, or null to reply to the post.
  Reply? _replyingTo;
  final _replyText = TextEditingController();
  final _replyFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _replyText.dispose();
    _replyFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final feed = Services.feed;
    try {
      final results = await Future.wait([
        feed.getPost(_post.id),
        feed.replies(_post.id, viewer: widget.viewer),
        feed.responsesTo(_post.id),
        feed.hasBeenThere(_post.id, widget.viewer),
        feed.isMine(_post, widget.viewer),
        Services.safety.blockedUids(widget.viewer),
      ]);
      final blocked = results[5] as Set<String>;
      final replies = [
        for (final r in results[1] as List<Reply>)
          if (!blocked.contains(r.author.uid)) r,
      ];
      final helpful = await feed.myHelpful(_post.id, replies, widget.viewer);
      if (!mounted) return;
      setState(() {
        _post = (results[0] as Post?) ?? _post;
        _replies = replies;
        _responses = results[2] as List<Post>;
        _beenThere = results[3] as bool;
        _isMine = results[4] as bool;
        _responses = [
          for (final p in results[2] as List<Post>)
            if (!blocked.contains(p.author?.uid)) p,
        ];
        _myHelpful = helpful;
        _loadError = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _loadError = "Couldn't load comments. Pull to retry.");
      }
    }
  }

  /// Best first: the reply that helped the asker, then most Helpful, then
  /// oldest.
  static int _byHelpfulness(Reply a, Reply b) {
    if (a.helpedAsker != b.helpedAsker) return a.helpedAsker ? -1 : 1;
    if (a.helpfulCount != b.helpfulCount) return b.helpfulCount - a.helpfulCount;
    return a.createdAt.compareTo(b.createdAt);
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

  void _startReplyTo(Reply reply) {
    setState(() => _replyingTo = reply);
    _replyFocus.requestFocus();
  }

  Future<void> _sendReply() async {
    final text = _replyText.text.trim();
    if (text.isEmpty) return;
    if (containsFlaggedWords(text) && !await confirmFlaggedPost(context)) {
      return;
    }
    await _run(() async {
      final reply = await Services.feed
          .addReply(widget.viewer, _post, text, parent: _replyingTo);
      if (!mounted) return;
      _replyText.clear();
      FocusScope.of(context).unfocus();
      setState(() {
        _replies = [...?_replies, reply];
        _replyingTo = null;
        _post = _post.copyWith(replyCount: _post.replyCount + 1);
      });
      if (reply.isHeld) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Thanks! Your reply will show once a moderator has '
              'checked it.'),
        ));
      }
    }, "Couldn't send your reply. Try again.");
  }

  Future<void> _reportPost() => showReportSheet(
        context,
        what: 'this post',
        onReport: (reason, details) => Services.safety
            .reportPost(widget.viewer, _post, reason, details: details),
      );

  Future<void> _reportReply(Reply reply) => showReportSheet(
        context,
        what: 'this reply',
        onReport: (reason, details) => Services.safety
            .reportReply(widget.viewer, reply, reason, details: details),
      );

  Future<void> _block(Author author) async {
    if (!await confirmBlock(context, author.name)) return;
    await _run(() async {
      await Services.safety.block(widget.viewer, author);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You blocked ${author.name}.')),
      );
      if (_post.author?.uid == author.uid) {
        Navigator.of(context).pop();
      } else {
        await _load();
      }
    }, "Couldn't block. Try again.");
  }

  Future<void> _respondWithPost() async {
    final created = await Navigator.of(context).push<Post>(
      MaterialPageRoute(
        builder: (_) => CaptureScreen(
          account: widget.viewer,
          respondingTo: _post,
        ),
      ),
    );
    if (created != null && mounted) _load();
  }

  Future<void> _edit() async {
    final edited = await Navigator.of(context).push<Post>(
      MaterialPageRoute(
        builder: (_) => EditPostScreen(account: widget.viewer, post: _post),
      ),
    );
    if (edited == null || !mounted) return;
    setState(() => _post = edited);
    if (edited.isHeld && !widget.post.isHeld) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Saved. A moderator will check it before others '
            'see it again.'),
      ));
    }
  }

  Future<void> _delete() async {
    if (!await confirmDeletePost(context)) return;
    await _run(() async {
      await Services.feed.deletePost(widget.viewer, _post);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Post deleted.')));
      Navigator.of(context).pop();
    }, "Couldn't delete it. Try again.");
  }

  void _searchTag(String tag) => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              TagSearchScreen(account: widget.viewer, initialTag: tag),
        ),
      );

  Future<void> _openPost(Post post) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PostDetailScreen(post: post, viewer: widget.viewer),
      ),
    );
    if (mounted) _load();
  }

  /// Top-level comments: replies to the post and response posts, best
  /// replies first, then by time.
  List<Widget> _thread() {
    final replies = _replies ?? const [];
    final children = <String, List<Reply>>{};
    for (final r in replies) {
      if (r.parentReplyId != null) {
        (children[r.parentReplyId!] ??= []).add(r);
      }
    }
    final topLevel = replies.where((r) => r.parentReplyId == null).toList()
      ..sort(_byHelpfulness);
    final canMarkHelped =
        _isMine && _post.type == PostType.question && !_post.answered;

    Iterable<Widget> replyTree(Reply reply, int depth) sync* {
      yield Padding(
        padding: EdgeInsets.only(left: 20.0 * depth.clamp(0, _maxIndent)),
        child: _ReplyTile(
          reply: reply,
          isNested: depth > 0,
          markedHelpful: _myHelpful.contains(reply.id),
          onHelpful: _busy ? null : () => _toggleHelpful(reply),
          onReply: FeedRules.replyBlockedFor(widget.viewer, _post,
                      parent: reply) ==
                  null
              ? () => _startReplyTo(reply)
              : null,
          onHelpedMe:
              canMarkHelped && !_busy ? () => _markHelped(reply) : null,
          onReport: () => _reportReply(reply),
          onBlock: reply.author.uid == widget.viewer.uid
              ? null
              : () => _block(reply.author),
        ),
      );
      // A copy: sorting the shared (or empty const) list would throw.
      final kids = [...?children[reply.id]]
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      for (final child in kids) {
        yield* replyTree(child, depth + 1);
      }
    }

    // Merge response posts in by time, after replies the asker marked.
    final items = <(DateTime, Widget)>[
      for (final r in topLevel)
        (
          r.helpedAsker ? DateTime(0) : r.createdAt,
          Column(children: [...replyTree(r, 0)]),
        ),
      for (final p in _responses)
        (
          p.createdAt,
          _ResponseCard(post: p, onTap: () => _openPost(p)),
        ),
    ];
    // Keep the helpfulness order of replies; slot responses in by time.
    final ordered = <Widget>[];
    final responses = items.where((i) => i.$2 is _ResponseCard).toList()
      ..sort((a, b) => a.$1.compareTo(b.$1));
    final replyItems = items.where((i) => i.$2 is! _ResponseCard).toList();
    var ri = 0;
    for (final reply in replyItems) {
      while (ri < responses.length && responses[ri].$1.isBefore(reply.$1)) {
        ordered.add(responses[ri++].$2);
      }
      ordered.add(reply.$2);
    }
    while (ri < responses.length) {
      ordered.add(responses[ri++].$2);
    }
    return ordered;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final post = _post;
    final postReplyBlocked = FeedRules.replyBlockedFor(widget.viewer, post);
    final barBlocked = _replyingTo == null
        ? postReplyBlocked
        : FeedRules.replyBlockedFor(widget.viewer, post, parent: _replyingTo);
    final commentCount = (_replies?.length ?? post.replyCount) +
        (_replies == null ? post.responseCount : _responses.length);

    return Scaffold(
      appBar: AppBar(
        title: Text(post.typeLabel),
        actions: [
          IconButton(
            tooltip: 'Get help',
            icon: const Icon(Icons.support_outlined),
            onPressed: () => showSupportSheet(context),
          ),
          if (_isMine)
            PopupMenuButton<String>(
              tooltip: 'More',
              onSelected: (choice) => choice == 'edit' ? _edit() : _delete(),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Edit post'),
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete_outline),
                    title: Text('Delete post'),
                  ),
                ),
              ],
            )
          else
            PopupMenuButton<String>(
              tooltip: 'More',
              onSelected: (choice) => choice == 'report'
                  ? _reportPost()
                  : _block(post.author!),
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'report',
                  child: ListTile(
                    leading: Icon(Icons.flag_outlined),
                    title: Text('Report post'),
                  ),
                ),
                if (post.author case final author?)
                  PopupMenuItem(
                    value: 'block',
                    child: ListTile(
                      leading: const Icon(Icons.block),
                      title: Text('Block ${author.name}'),
                    ),
                  ),
              ],
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
                    if (post.isHeld) ...[
                      HeldBanner(reason: post.holdReason),
                      const SizedBox(height: 12),
                    ],
                    PostHeader(post: post),
                    if (post.respondsToText != null) ...[
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () async {
                          final original =
                              await Services.feed.getPost(post.respondsToId!);
                          if (original != null && mounted) _openPost(original);
                        },
                        child: RespondsToLine(text: post.respondsToText!),
                      ),
                    ],
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
                    if (post.media.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      PostMediaView(media: post.media),
                    ],
                    if (post.tags.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      TagChips(tags: post.tags, onTap: _searchTag),
                    ],
                    if (post.needsAdviceBanner) ...[
                      const SizedBox(height: 12),
                      AdviceBanner(topic: post.topic),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _beenThere
                            ? FilledButton.icon(
                                onPressed: _busy ? null : _toggleBeenThere,
                                icon: const Icon(Icons.handshake),
                                label:
                                    Text('Been there · ${post.beenThereCount}'),
                              )
                            : OutlinedButton.icon(
                                onPressed: _busy ? null : _toggleBeenThere,
                                icon: const Icon(Icons.handshake_outlined),
                                label:
                                    Text('Been there · ${post.beenThereCount}'),
                              ),
                        if (postReplyBlocked == null)
                          OutlinedButton.icon(
                            onPressed: _respondWithPost,
                            icon: const Icon(Icons.post_add),
                            label: const Text('Respond with a post'),
                          ),
                      ],
                    ),
                    const Divider(height: 32),
                    Text(commentLabel(commentCount),
                        style: textTheme.titleMedium),
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
                    else if (_replies!.isEmpty && _responses.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text('No comments yet.',
                            style: textTheme.bodyMedium),
                      )
                    else
                      ..._thread(),
                  ],
                ),
              ),
            ),
            _ReplyBar(
              blockedReason: barBlocked,
              replyingTo: _replyingTo,
              onCancelReplyTo: () => setState(() => _replyingTo = null),
              controller: _replyText,
              focusNode: _replyFocus,
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

/// A response post inside the comments thread.
class _ResponseCard extends StatelessWidget {
  const _ResponseCard({required this.post, required this.onTap});

  final Post post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const FeedChip(label: 'Response post', icon: Icons.post_add),
              const SizedBox(height: 8),
              PostHeader(post: post),
              const SizedBox(height: 6),
              Text(post.text,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium),
              if (post.media.isNotEmpty) ...[
                const SizedBox(height: 8),
                MediaPreviewGrid(media: post.media),
              ],
              const SizedBox(height: 6),
              Text('Open post · ${commentLabel(post.commentCount)}',
                  style: textTheme.labelMedium
                      ?.copyWith(color: scheme.primary)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReplyTile extends StatelessWidget {
  const _ReplyTile({
    required this.reply,
    required this.isNested,
    required this.markedHelpful,
    required this.onHelpful,
    required this.onReply,
    required this.onHelpedMe,
    required this.onReport,
    required this.onBlock,
  });

  final Reply reply;
  final bool isNested;
  final bool markedHelpful;
  final VoidCallback? onHelpful;
  final VoidCallback? onReply;
  final VoidCallback? onHelpedMe;
  final VoidCallback onReport;

  /// Null for the viewer's own replies.
  final VoidCallback? onBlock;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 0),
      decoration: BoxDecoration(
        color: reply.helpedAsker
            ? scheme.primaryContainer.withValues(alpha: 0.5)
            : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: isNested
            ? Border(left: BorderSide(color: scheme.outlineVariant, width: 3))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (reply.isHeld)
            Padding(
              padding: const EdgeInsets.only(bottom: 6, right: 8),
              child: HeldBanner(reason: reply.holdReason),
            ),
          if (reply.helpedAsker)
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: FeedChip(
                label: 'Helped the asker',
                icon: Icons.check_circle_outline,
                emphasis: true,
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${reply.author.name} · ${reply.author.subtitle}',
                    style: textTheme.labelLarge,
                  ),
                ),
                Text(timeAgo(context, reply.createdAt),
                    style: textTheme.bodySmall),
                if (onBlock != null)
                  PopupMenuButton<String>(
                    tooltip: 'More',
                    iconSize: 18,
                    padding: EdgeInsets.zero,
                    onSelected: (c) => c == 'report' ? onReport() : onBlock!(),
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                          value: 'report', child: Text('Report reply')),
                      PopupMenuItem(
                          value: 'block',
                          child: Text('Block ${reply.author.name}')),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SelectableText(reply.text, style: textTheme.bodyMedium),
          ),
          Wrap(
            children: [
              TextButton.icon(
                onPressed: onHelpful,
                icon: Icon(
                  markedHelpful ? Icons.thumb_up : Icons.thumb_up_outlined,
                  size: 18,
                ),
                label: Text('Helpful · ${reply.helpfulCount}'),
              ),
              if (onReply != null)
                TextButton.icon(
                  onPressed: onReply,
                  icon: const Icon(Icons.reply, size: 18),
                  label: const Text('Reply'),
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
    required this.replyingTo,
    required this.onCancelReplyTo,
    required this.controller,
    required this.focusNode,
    required this.sending,
    required this.onSend,
  });

  final String? blockedReason;
  final Reply? replyingTo;
  final VoidCallback onCancelReplyTo;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: scheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (replyingTo != null)
                Row(
                  children: [
                    Icon(Icons.reply, size: 16, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text('Replying to ${replyingTo!.author.name}',
                          style: textTheme.labelMedium),
                    ),
                    IconButton(
                      tooltip: 'Cancel reply',
                      visualDensity: VisualDensity.compact,
                      onPressed: onCancelReplyTo,
                      icon: const Icon(Icons.close, size: 18),
                    ),
                  ],
                ),
              if (blockedReason != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.lock_outline,
                          size: 18, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(blockedReason!, style: textTheme.bodyMedium),
                      ),
                    ],
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        focusNode: focusNode,
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
            ],
          ),
        ),
      ),
    );
  }
}
