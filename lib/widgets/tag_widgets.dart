import 'package:flutter/material.dart';

import '../models/post.dart';

/// Adds and removes a post's tags. Typing a space, comma or Enter adds the
/// tag; [normaliseTag] cleans it ("#ACL!" becomes "acl").
class TagEditor extends StatefulWidget {
  const TagEditor({super.key, required this.tags, required this.onChanged});

  final List<String> tags;
  final ValueChanged<List<String>> onChanged;

  @override
  State<TagEditor> createState() => _TagEditorState();
}

class _TagEditorState extends State<TagEditor> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  bool get _full => widget.tags.length >= maxTags;

  void _add(String text) {
    final tag = normaliseTag(text);
    _input.clear();
    if (tag == null || _full || widget.tags.contains(tag)) return;
    widget.onChanged([...widget.tags, tag]);
  }

  void _changed(String text) {
    // A space or comma finishes a tag.
    if (text.endsWith(' ') || text.endsWith(',')) _add(text);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _input,
          enabled: !_full,
          autocorrect: false,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: 'Tags (optional)',
            hintText: _full ? null : 'e.g. acl, marathon, nationals',
            helperText: _full
                ? 'That\'s the most tags ($maxTags).'
                : 'Tags help others find your post. Up to $maxTags.',
            prefixText: '# ',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              tooltip: 'Add tag',
              icon: const Icon(Icons.add),
              onPressed: _full ? null : () => _add(_input.text),
            ),
          ),
          onChanged: _changed,
          onSubmitted: _add,
        ),
        if (widget.tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final tag in widget.tags)
                InputChip(
                  label: Text('#$tag'),
                  onDeleted: () =>
                      widget.onChanged([...widget.tags]..remove(tag)),
                  deleteButtonTooltipMessage: 'Remove #$tag',
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// A post's tags. Tapping one searches for it.
class TagChips extends StatelessWidget {
  const TagChips({super.key, required this.tags, this.onTap});

  final List<String> tags;
  final ValueChanged<String>? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(
      context,
    ).textTheme.labelMedium?.copyWith(color: scheme.primary);
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final tag in tags)
          InkWell(
            onTap: onTap == null ? null : () => onTap!(tag),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text('#$tag', style: style),
            ),
          ),
      ],
    );
  }
}
