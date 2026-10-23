import 'package:flutter/material.dart';

import '../config/support_config.dart';
import '../models/post.dart';
import '../models/sign_up_data.dart';
import 'brand.dart';
import 'media_widgets.dart';
import 'tag_widgets.dart';

/// Each category's colour, used for its chip and accents.
Color topicColor(Topic topic) => switch (topic) {
  Topic.training => Brand.coral,
  Topic.mindset => Brand.violet,
  Topic.gameDay => const Color(0xFFE09A00),
  Topic.teamLife => Brand.teal,
};

/// A fun emoji for each category.
String topicEmoji(Topic topic) => switch (topic) {
  Topic.training => '🏋️',
  Topic.mindset => '🧠',
  Topic.gameDay => '🏆',
  Topic.teamLife => '🤝',
};

/// A post's category as a coloured pill with its emoji.
class TopicChip extends StatelessWidget {
  const TopicChip({super.key, required this.topic});

  final Topic topic;

  @override
  Widget build(BuildContext context) {
    final color = topicColor(topic);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '${topicEmoji(topic)} ${topic.label}',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Color.lerp(color, Brand.navy, 0.35),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Picture icon for each topic, used everywhere the topic appears.
IconData topicIcon(Topic topic) => switch (topic) {
  Topic.training => Icons.fitness_center,
  Topic.mindset => Icons.psychology_outlined,
  Topic.gameDay => Icons.emoji_events_outlined,
  Topic.teamLife => Icons.groups_outlined,
};

/// "Experience, not professional advice", on "Ask an athlete" questions.
class AdviceBanner extends StatelessWidget {
  const AdviceBanner({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: EdgeInsets.all(compact ? 8 : 12),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: scheme.onTertiaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Athletes share what worked for them. It isn\'t professional '
              'advice: check with your coach, doctor or physio before '
              'trying anything.',
              style: (compact ? textTheme.bodySmall : textTheme.bodyMedium)
                  ?.copyWith(color: scheme.onTertiaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens the list of support services.
Future<void> showSupportSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      final textTheme = Theme.of(context).textTheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Need to talk to someone?', style: textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                "You don't have to deal with things on your own. These "
                'services are free and confidential.',
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              for (final service in supportServices)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(service.name, style: textTheme.titleMedium),
                      Text(service.detail, style: textTheme.bodyMedium),
                      SelectableText(
                        service.contact,
                        style: textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              Text(
                "If you're under 18, you can also talk to a parent, "
                'guardian, coach or teacher you trust.',
                style: textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Small label chip, e.g. a topic, "Question" or "Answered".
class FeedChip extends StatelessWidget {
  const FeedChip({
    super.key,
    required this.label,
    this.icon,
    this.emphasis = false,
  });

  final String label;
  final IconData? icon;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = emphasis ? scheme.onPrimaryContainer : scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: emphasis
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg),
          ),
        ],
      ),
    );
  }
}

/// Short relative time, e.g. "5m", "3h", "2d", or a date.
String timeAgo(BuildContext context, DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inHours < 1) return '${diff.inMinutes}m';
  if (diff.inDays < 1) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  return MaterialLocalizations.of(context).formatShortMonthDay(time);
}

/// A post in the feed. Tapping opens the full post.
class PostCard extends StatelessWidget {
  const PostCard({super.key, required this.post, required this.onTap});

  final Post post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (post.isHeld) ...[
                const FeedChip(
                  label: 'Waiting for a moderator',
                  icon: Icons.hourglass_top,
                ),
                const SizedBox(height: 8),
              ],
              PostHeader(post: post),
              if (post.respondsToText != null) ...[
                const SizedBox(height: 8),
                RespondsToLine(text: post.respondsToText!),
              ],
              if (post.promptText != null) ...[
                const SizedBox(height: 8),
                PromptLine(text: post.promptText!),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  TopicChip(topic: post.topic),
                  FeedChip(label: post.typeLabel),
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
              const SizedBox(height: 10),
              Text(
                post.text,
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyLarge,
              ),
              if (post.media.isNotEmpty) ...[
                const SizedBox(height: 10),
                MediaPreviewGrid(media: post.media),
              ],
              if (post.tags.isNotEmpty) ...[
                const SizedBox(height: 6),
                TagChips(tags: post.tags),
              ],
              if (post.needsAdviceBanner) ...[
                const SizedBox(height: 10),
                const AdviceBanner(compact: true),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.handshake_outlined,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${post.beenThereCount} been there',
                    style: textTheme.bodySmall,
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    commentLabel(post.commentCount),
                    style: textTheme.bodySmall,
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

/// Avatar, name and sport line for a post. Anonymous posts show no details.
class PostHeader extends StatelessWidget {
  const PostHeader({super.key, required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final author = post.author;

    return Row(
      children: [
        GradientAvatar(
          name: post.authorName,
          radius: 18,
          anonymous: author == null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(post.authorName, style: textTheme.titleSmall),
                  ),
                  if (author?.verified ?? false) ...[
                    const SizedBox(width: 4),
                    const VerifiedBadge(size: 16),
                  ],
                ],
              ),
              if (author != null)
                Text(author.subtitle, style: textTheme.bodySmall),
            ],
          ),
        ),
        Text(
          post.editedAt == null
              ? timeAgo(context, post.createdAt)
              : '${timeAgo(context, post.createdAt)} · edited',
          style: textTheme.bodySmall,
        ),
      ],
    );
  }
}

String commentLabel(int count) => count == 1 ? '1 comment' : '$count comments';

/// The "In response to: ..." line on response posts.
class RespondsToLine extends StatelessWidget {
  const RespondsToLine({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.subdirectory_arrow_right,
          size: 16,
          color: scheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            'In response to: "$text"',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
          ),
        ),
      ],
    );
  }
}

/// "💬 Huddle question: …" on posts answering the weekly question.
class PromptLine extends StatelessWidget {
  const PromptLine({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Brand.violet.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        '💬 Huddle question: $text',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Brand.navy,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
