import 'package:flutter/material.dart';

import '../../models/sign_up_data.dart';

/// Sport, level, programme and topics. Also used to edit a saved profile.
class ProfileStep extends StatefulWidget {
  const ProfileStep({
    super.key,
    required this.data,
    required this.onContinue,
    this.submitLabel = 'Create account',
    this.header,
  });

  final SignUpData data;
  final VoidCallback onContinue;
  final String submitLabel;

  /// Shown above everything else, e.g. a name field when editing.
  final Widget? header;

  @override
  State<ProfileStep> createState() => _ProfileStepState();
}

class _ProfileStepState extends State<ProfileStep> {
  String? _error;

  bool get _isAthlete => widget.data.role == UserRole.athlete;

  void _submit() {
    final data = widget.data;
    if (_isAthlete && (data.sport == null || data.level == null)) {
      setState(() => _error = 'Choose your sport and level');
      return;
    }
    if (_isAthlete && data.sport == otherSport && data.customSport.isEmpty) {
      setState(() => _error = 'Type the name of your sport');
      return;
    }
    if (data.topics.isEmpty) {
      setState(() => _error = 'Pick at least one topic');
      return;
    }
    widget.onContinue();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ?widget.header,
          if (_isAthlete) ...[
            Text('Your sport', style: textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Shown on your profile so others know where your advice '
              'comes from.',
              style: textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            DropdownButtonFormField<String>(
              initialValue: data.sport,
              decoration: const InputDecoration(
                labelText: 'Sport',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final sport in sports)
                  DropdownMenuItem(value: sport, child: Text(sport)),
              ],
              onChanged: (v) => setState(() {
                data.sport = v;
                _error = null;
              }),
            ),
            if (data.sport == otherSport) ...[
              const SizedBox(height: 16),
              TextFormField(
                initialValue: data.customSport,
                autofocus: data.customSport.isEmpty,
                decoration: const InputDecoration(
                  labelText: 'Name of your sport',
                  hintText: 'e.g. Fencing',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
                maxLength: 40,
                onChanged: (v) => setState(() {
                  data.customSport = v.trim();
                  _error = null;
                }),
              ),
            ],
            const SizedBox(height: 16),
            Text('Level', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final level in CompetitionLevel.values)
                  ChoiceChip(
                    label: Text(level.label),
                    selected: data.level == level,
                    onSelected: (_) => setState(() {
                      data.level = level;
                      _error = null;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Text('Athlete programme', style: textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Optional. Choose one if it applies to you.',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final category in AthleteCategory.values)
                  ChoiceChip(
                    label: Text(category.label),
                    selected: data.category == category,
                    onSelected: (on) =>
                        setState(() => data.category = on ? category : null),
                  ),
              ],
            ),
            const SizedBox(height: 32),
          ],
          Text(
            'What do you want to see?',
            style: _isAthlete ? textTheme.titleLarge : textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Your feed starts with these topics. You can change them later.',
            style: textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final topic in Topic.values)
                FilterChip(
                  label: Text(topic.label),
                  selected: data.topics.contains(topic),
                  onSelected: (on) => setState(() {
                    on ? data.topics.add(topic) : data.topics.remove(topic);
                    _error = null;
                  }),
                ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: scheme.error)),
          ],
          const SizedBox(height: 24),
          FilledButton(onPressed: _submit, child: Text(widget.submitLabel)),
        ],
      ),
    );
  }
}
