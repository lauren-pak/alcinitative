import 'package:flutter/material.dart';

/// Explains the extra safeguards applied to members under 18.
class MinorProtectionsNotice extends StatelessWidget {
  const MinorProtectionsNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.shield_outlined, color: scheme.onSecondaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Extra protections for under-18s',
                    style: textTheme.titleSmall?.copyWith(
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your profile is hidden from search. Only other under-18s '
                    'can reply to your posts, unless you let adults reply, '
                    'and then a moderator checks their replies first. Your '
                    'videos are checked before they go live, and you can go '
                    "to events with a parent or guardian's OK.",
                    style: textTheme.bodyMedium?.copyWith(
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
