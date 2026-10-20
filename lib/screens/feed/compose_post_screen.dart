import 'package:flutter/material.dart';

import '../../models/account.dart';
import '../../models/post.dart';
import '../../models/sign_up_data.dart';
import '../../services/services.dart';
import '../../widgets/feed_widgets.dart';

/// Write an experience or a question. Pops with the created [Post].
class ComposePostScreen extends StatefulWidget {
  const ComposePostScreen({super.key, required this.account});

  final Account account;

  @override
  State<ComposePostScreen> createState() => _ComposePostScreenState();
}

class _ComposePostScreenState extends State<ComposePostScreen> {
  static const _minLength = 10;

  final _draft = NewPost();
  List<Journey> _journeys = [];
  bool _posting = false;
  String? _error;

  Account get _account => widget.account;
  bool get _isAthlete => _account.profile.role == UserRole.athlete;
  bool get _isMinor => FeedRules.isMinor(_account);

  @override
  void initState() {
    super.initState();
    _draft.type = FeedRules.postTypesFor(_account).first;
    if (_isAthlete) _loadJourneys();
  }

  Future<void> _loadJourneys() async {
    try {
      final journeys = await Services.feed.myJourneys(_account);
      if (mounted) setState(() => _journeys = journeys);
    } catch (_) {
      // Journeys are optional; posting still works without them.
    }
  }

  Future<void> _newJourney() async {
    final title = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('New journey'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 60,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'e.g. ACL rehab 2026',
              helperText: 'Tag posts into it, like a playlist.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
    if (title == null || title.isEmpty || !mounted) return;
    try {
      final journey = await Services.feed.createJourney(_account, title);
      if (!mounted) return;
      setState(() {
        _journeys = [journey, ..._journeys];
        _draft.journey = journey;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't create the journey.")),
        );
      }
    }
  }

  Future<void> _post() async {
    FocusScope.of(context).unfocus();
    final topic = _draft.topic;
    String? error;
    if (topic == null) {
      error = 'Choose a topic';
    } else if (FeedRules.topicBlockedFor(_account, topic) case final reason?) {
      error = reason;
    } else if (_draft.text.trim().length < _minLength) {
      error = 'Write at least $_minLength characters';
    }
    setState(() => _error = error);
    if (error != null) {
      // The form is long, so also show the problem where it can be seen.
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    setState(() => _posting = true);
    try {
      final post = await Services.feed.createPost(_account, _draft);
      if (mounted) Navigator.of(context).pop(post);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _posting = false;
        _error = "Couldn't post. Check your connection and try again.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final isQuestion = _draft.type == PostType.question;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isAthlete ? 'New post' : 'Ask a question'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              onPressed: _posting ? null : _post,
              child: const Text('Post'),
            ),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: AbsorbPointer(
          absorbing: _posting,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_isAthlete)
                SegmentedButton<PostType>(
                  segments: const [
                    ButtonSegment(
                      value: PostType.experience,
                      icon: Icon(Icons.auto_stories_outlined),
                      label: Text('Share an experience'),
                    ),
                    ButtonSegment(
                      value: PostType.question,
                      icon: Icon(Icons.help_outline),
                      label: Text('Ask a question'),
                    ),
                  ],
                  selected: {_draft.type},
                  onSelectionChanged: (s) =>
                      setState(() => _draft.type = s.first),
                )
              else
                Text(
                  'Ask athletes for advice. Your question will be labelled '
                  '"Question from the public".',
                  style: textTheme.bodyMedium,
                ),
              const SizedBox(height: 20),
              Text('Topic', style: textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final topic in Topic.values)
                    ChoiceChip(
                      avatar: Icon(topicIcon(topic), size: 18),
                      label: Text(topic.label),
                      selected: _draft.topic == topic,
                      onSelected:
                          FeedRules.topicBlockedFor(_account, topic) != null
                              ? null
                              : (_) => setState(() {
                                    _draft.topic = topic;
                                    _error = null;
                                  }),
                    ),
                ],
              ),
              if (FeedRules.topicBlockedFor(_account, Topic.nutrition)
                  case final reason?) ...[
                const SizedBox(height: 6),
                Text(reason, style: textTheme.bodySmall),
              ],
              if (_draft.topic == Topic.injury ||
                  _draft.topic == Topic.nutrition) ...[
                const SizedBox(height: 12),
                AdviceBanner(topic: _draft.topic!, compact: true),
              ],
              const SizedBox(height: 20),
              TextField(
                minLines: 5,
                maxLines: 12,
                maxLength: maxPostLength,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: isQuestion ? 'Your question' : 'Your experience',
                  hintText: isQuestion
                      ? 'What would you like advice on?'
                      : 'What happened, and what did you learn?',
                  alignLabelWithHint: true,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() {
                  _draft.text = v;
                  _error = null;
                }),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ReplyPolicy>(
                initialValue: _draft.replyPolicy,
                decoration: InputDecoration(
                  labelText: 'Who can reply',
                  helperText: _isMinor
                      ? 'Only other under-18s can reply to your posts.'
                      : null,
                  border: const OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: ReplyPolicy.athletes,
                    child: Text('Athletes'),
                  ),
                  DropdownMenuItem(
                    value: ReplyPolicy.everyone,
                    child: Text('Everyone, including the public'),
                  ),
                  DropdownMenuItem(
                    value: ReplyPolicy.none,
                    child: Text('No replies'),
                  ),
                ],
                onChanged: (v) => setState(() => _draft.replyPolicy = v!),
              ),
              const SizedBox(height: 4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _draft.anonymous,
                onChanged: (v) => setState(() => _draft.anonymous = v),
                title: const Text('Post anonymously'),
                subtitle: const Text(
                  "Other members won't see your name. Moderators can still "
                  'see who posted, to keep everyone safe.',
                ),
              ),
              if (_isAthlete && !_draft.anonymous) ...[
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  // Rebuilt when a journey is created, to show it selected.
                  key: ValueKey('${_draft.journey?.id}-${_journeys.length}'),
                  initialValue: _draft.journey?.id ?? '',
                  decoration: const InputDecoration(
                    labelText: 'Add to a journey (optional)',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('None')),
                    for (final j in _journeys)
                      DropdownMenuItem(value: j.id, child: Text(j.title)),
                    const DropdownMenuItem(
                      value: '+new',
                      child: Text('+ New journey…'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v == '+new') {
                      _newJourney();
                      return;
                    }
                    setState(() => _draft.journey = v == null || v.isEmpty
                        ? null
                        : _journeys.firstWhere((j) => j.id == v));
                  },
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: TextStyle(color: scheme.error)),
              ],
              if (_posting) ...[
                const SizedBox(height: 16),
                const Center(child: CircularProgressIndicator()),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
