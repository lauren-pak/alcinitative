import 'package:flutter/material.dart';

import '../../models/account.dart';
import '../../models/post.dart';
import '../../services/services.dart';
import '../../widgets/brand.dart';
import '../../widgets/feed_widgets.dart';
import 'post_detail_screen.dart';

/// "This week's Huddle question" at the top of Spotlight. Verified
/// athletes answer with a spotlight; everyone can see the answers.
/// Moderators can set a new question.
class WeeklyPromptBanner extends StatefulWidget {
  const WeeklyPromptBanner({
    super.key,
    required this.account,
    this.onAnswer,
    this.easy = false,
  });

  final Account account;

  /// Null hides the Answer button (members who can't share spotlights).
  final void Function(WeeklyPrompt prompt)? onAnswer;
  final bool easy;

  @override
  State<WeeklyPromptBanner> createState() => _WeeklyPromptBannerState();
}

class _WeeklyPromptBannerState extends State<WeeklyPromptBanner> {
  late Future<(WeeklyPrompt?, bool)> _load = _fetch();

  Future<(WeeklyPrompt?, bool)> _fetch() async {
    final results = await Future.wait([
      Services.feed.currentPrompt(),
      Services.safety.isModerator(widget.account.uid),
    ]);
    return (results[0] as WeeklyPrompt?, results[1] as bool);
  }

  Future<void> _setQuestion() async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("This week's Huddle question"),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: maxPromptLength,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'What do you do the night before a big competition?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Post question'),
          ),
        ],
      ),
    );
    // Not disposed here: the dialog's closing animation still uses it.
    if (text == null || text.length < 5 || !mounted) return;
    await Services.feed.createPrompt(widget.account, text);
    if (mounted) {
      setState(() {
        _load = _fetch();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(WeeklyPrompt?, bool)>(
      future: _load,
      builder: (context, snapshot) {
        final (prompt, moderator) = snapshot.data ?? (null, false);
        if (prompt == null) {
          if (!moderator) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: OutlinedButton.icon(
              onPressed: _setQuestion,
              icon: const Icon(Icons.add_comment_outlined),
              label: const Text("Set this week's Huddle question"),
            ),
          );
        }
        final white = OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.white70),
        );
        return GradientBanner(
          title: widget.easy
              ? '💬 Question of the week'
              : "This week's Huddle question",
          body: prompt.text,
          emoji: widget.easy ? null : '💬',
          gradient: Brand.night,
          action: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (widget.onAnswer != null)
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Brand.gold,
                    foregroundColor: Brand.navy,
                  ),
                  onPressed: () => widget.onAnswer!(prompt),
                  child: const Text('Answer it'),
                ),
              OutlinedButton(
                style: white,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PromptAnswersScreen(
                      prompt: prompt,
                      account: widget.account,
                    ),
                  ),
                ),
                child: const Text('See answers'),
              ),
              if (moderator)
                OutlinedButton(
                  style: white,
                  onPressed: _setQuestion,
                  child: const Text('New question'),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Everyone's answers to a weekly Huddle question.
class PromptAnswersScreen extends StatelessWidget {
  const PromptAnswersScreen({
    super.key,
    required this.prompt,
    required this.account,
  });

  final WeeklyPrompt prompt;
  final Account account;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Answers')),
      body: FutureBuilder<List<Post>>(
        future: Services.feed.answersTo(prompt.id),
        builder: (context, snapshot) {
          final posts = snapshot.data ?? const <Post>[];
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              GradientBanner(
                title: "This week's Huddle question",
                body: prompt.text,
                emoji: '💬',
                gradient: Brand.night,
              ),
              if (snapshot.connectionState != ConnectionState.done)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (posts.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'No answers yet. Athletes are thinking about it…',
                    style: textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                ),
              for (final post in posts)
                PostCard(
                  post: post,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          PostDetailScreen(post: post, viewer: account),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
