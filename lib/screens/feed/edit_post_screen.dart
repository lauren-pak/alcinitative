import 'package:flutter/material.dart';

import '../../models/account.dart';
import '../../models/display_mode.dart';
import '../../models/post.dart';
import '../../services/services.dart';
import '../../widgets/safety_widgets.dart';
import '../../widgets/tag_widgets.dart';

/// Edit the text and tags of your own post. Topic, type, media and who can
/// reply stay as posted. Pops with the edited [Post].
class EditPostScreen extends StatefulWidget {
  const EditPostScreen({super.key, required this.account, required this.post});

  final Account account;
  final Post post;

  @override
  State<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen> {
  late final _text = TextEditingController(text: widget.post.text);
  late List<String> _tags = [...widget.post.tags];
  bool _saving = false;

  bool get _easy => isEasyMode;
  int get _minLength => widget.post.media.isEmpty ? 3 : 1;
  bool get _canSave => !_saving && _text.text.trim().length >= _minLength;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _text.text.trim();
    if (FeedRules.flagged(text, _tags) &&
        !widget.post.isHeld &&
        !await confirmFlaggedPost(context)) {
      return;
    }
    if (!mounted) return;
    setState(() => _saving = true);
    try {
      final edited = await Services.feed.editPost(
        widget.account,
        widget.post,
        text: text,
        tags: _tags,
      );
      if (mounted) Navigator.of(context).pop(edited);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_easy
            ? 'That did not save. Try again.'
            : "Couldn't save. Check your connection and try again."),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_easy ? 'Change my post' : 'Edit post'),
        actions: [
          if (!_easy)
            TextButton(
              onPressed: _canSave ? _save : null,
              child: const Text('Save'),
            ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _text,
              minLines: 5,
              maxLines: 12,
              maxLength: maxPostLength,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: _easy ? 'Your words' : 'Text',
                alignLabelWithHint: true,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TagEditor(
              tags: _tags,
              onChanged: (tags) => setState(() => _tags = tags),
            ),
            if (!_easy) ...[
              const SizedBox(height: 12),
              Text(
                'Others will see that you edited this post. To change the '
                'topic, photos or video, delete it and post again.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (_easy) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _canSave ? _save : null,
                  child: _saving
                      ? const CircularProgressIndicator()
                      : const Text('Save'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Asks before deleting a post. Returns true to delete.
Future<bool> confirmDeletePost(BuildContext context, {bool easy = false}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(easy ? 'Delete your post?' : 'Delete this post?'),
      content: Text(easy
          ? 'Your post will be gone for good.'
          : 'It will be deleted for good, with its photos and video. '
              "Other people's replies will no longer be shown."),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return result ?? false;
}

