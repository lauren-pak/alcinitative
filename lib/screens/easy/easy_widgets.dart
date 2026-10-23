import 'package:flutter/material.dart';

import '../../models/post.dart';
import '../../models/sign_up_data.dart';
import '../../widgets/feed_widgets.dart';
import '../../widgets/media_widgets.dart';

/// Building blocks for Easy mode: big targets, a picture with every choice,
/// short plain sentences.

/// Plain-language topic names for Easy mode.
String easyTopicLabel(Topic topic) => switch (topic) {
  Topic.training => 'Training',
  Topic.mindset => 'My mind',
  Topic.gameDay => 'Game day',
  Topic.teamLife => 'Team & fun',
};

/// A big square picture button for a topic or a choice.
class EasyTile extends StatelessWidget {
  const EasyTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onTap != null;
    return Material(
      color: selected ? scheme.primary : scheme.primaryContainer,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Opacity(
          opacity: enabled ? 1 : 0.4,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 48,
                  color: selected
                      ? scheme.onPrimary
                      : scheme.onPrimaryContainer,
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: selected
                        ? scheme.onPrimary
                        : scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A short, plain safety note with an icon.
class EasyNote extends StatelessWidget {
  const EasyNote({
    super.key,
    required this.text,
    this.icon = Icons.info_outline,
  });

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, size: 28, color: scheme.onTertiaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: scheme.onTertiaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The plain-language "not medical advice" note.
EasyNote easyAdviceNote() => const EasyNote(
  text:
      "This is what worked for one athlete. Ask your coach or doctor "
      'before you try it.',
);

/// The big "I need help" button for app bars.
class EasyHelpButton extends StatelessWidget {
  const EasyHelpButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilledButton.tonalIcon(
        style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
        onPressed: () => showSupportSheet(context),
        icon: const Icon(Icons.support),
        label: const Text('I need help'),
      ),
    );
  }
}

/// Initials in a big circle (anonymous posts show a hidden-eye icon).
class EasyAvatar extends StatelessWidget {
  const EasyAvatar({super.key, required this.name, this.anonymous = false});

  final String name;
  final bool anonymous;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final initials = name
        .split(' ')
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();
    return CircleAvatar(
      radius: 26,
      backgroundColor: scheme.secondaryContainer,
      child: anonymous
          ? Icon(
              Icons.visibility_off_outlined,
              color: scheme.onSecondaryContainer,
            )
          : Text(
              initials,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: scheme.onSecondaryContainer,
              ),
            ),
    );
  }
}

/// A post in Easy mode: who, what, a photo, and two big buttons.
class EasyPostCard extends StatelessWidget {
  const EasyPostCard({super.key, required this.post, required this.onTap});

  final Post post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  EasyAvatar(name: post.authorName, anonymous: post.anonymous),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(post.authorName, style: textTheme.titleMedium),
                  ),
                  Icon(topicIcon(post.topic), color: scheme.primary, size: 32),
                ],
              ),
              const SizedBox(height: 12),
              if (post.type == PostType.question)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    post.answered ? '✅ Question (answered)' : '❓ Question',
                    style: textTheme.titleSmall,
                  ),
                ),
              Text(
                post.text,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyLarge,
              ),
              if (post.media.isNotEmpty) ...[
                const SizedBox(height: 12),
                MediaPreviewGrid(media: post.media.take(1).toList()),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    '👋 ${post.beenThereCount}',
                    style: textTheme.titleMedium,
                  ),
                  const SizedBox(width: 24),
                  Text('💬 ${post.commentCount}', style: textTheme.titleMedium),
                  const Spacer(),
                  Text(
                    'Open ›',
                    style: textTheme.titleMedium?.copyWith(
                      color: scheme.primary,
                    ),
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
