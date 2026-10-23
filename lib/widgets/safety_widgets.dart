import 'package:flutter/material.dart';

import '../models/moderation.dart';
import 'feed_widgets.dart';

/// Shown before posting text with flagged words. Offers support first.
/// Returns true to post anyway (it will wait for a moderator).
Future<bool> confirmFlaggedPost(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.favorite_outline),
      title: const Text('Are you okay?'),
      content: const Text(
        'Some of what you wrote sounds like things might be hard right now. '
        "You don't have to deal with it on your own.\n\n"
        'If you post it, a moderator will read it first before others see it.',
      ),
      actions: [
        TextButton(
          onPressed: () async {
            Navigator.pop(context, false);
            await showSupportSheet(context);
          },
          child: const Text('Talk to someone'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Edit my post'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Post for review'),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Lets a member report something. [onReport] returns false if they had
/// already reported it.
Future<void> showReportSheet(
  BuildContext context, {
  required String what,
  required Future<bool> Function(ReportReason reason, String details) onReport,
}) async {
  final sent = await showModalBottomSheet<ReportReason>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _ReportSheet(what: what, onReport: onReport),
  );
  if (sent == null || !context.mounted) return;
  if (sent == ReportReason.wellbeing) {
    // Worried about someone (or yourself): show where to get help too.
    await showSupportSheet(context);
  }
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({required this.what, required this.onReport});

  final String what;
  final Future<bool> Function(ReportReason reason, String details) onReport;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  ReportReason? _reason;
  final _details = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final reason = _reason;
    if (reason == null) return;
    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final isNew = await widget.onReport(reason, _details.text);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            isNew
                ? 'Thanks for telling us. A moderator will look at it.'
                : "You've already reported this. A moderator will look at it.",
          ),
        ),
      );
      if (mounted) Navigator.of(context).pop(reason);
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't send your report. Try again.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Report ${widget.what}', style: textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              "What's wrong? The person won't know you reported it.",
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            RadioGroup<ReportReason>(
              groupValue: _reason,
              onChanged: (r) => setState(() => _reason = r),
              child: Column(
                children: [
                  for (final reason in ReportReason.values)
                    RadioListTile<ReportReason>(
                      contentPadding: EdgeInsets.zero,
                      value: reason,
                      title: Text(reason.label),
                    ),
                ],
              ),
            ),
            TextField(
              controller: _details,
              maxLength: 500,
              maxLines: 3,
              minLines: 1,
              decoration: const InputDecoration(
                labelText: 'Anything else? (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _reason == null || _sending ? null : _send,
                child: const Text('Send report'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Asks before blocking. Returns true to block.
Future<bool> confirmBlock(BuildContext context, String name) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Block $name?'),
      content: Text(
        "You won't see $name's posts or replies, and they won't be able to "
        "reply to your posts. They won't be told. You can unblock them from "
        'your profile.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Block'),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Shown to the author on their own post or reply while it's held.
class HeldBanner extends StatelessWidget {
  const HeldBanner({super.key, this.reason});

  final HoldReason? reason;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            Icons.hourglass_top,
            size: 18,
            color: scheme.onSecondaryContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Waiting for a moderator to check it. Only you can see it for now.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
