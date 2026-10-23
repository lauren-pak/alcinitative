import 'package:flutter/material.dart';

import '../../models/account.dart';
import '../../models/event.dart';
import '../../models/sign_up_data.dart';
import '../../services/services.dart';

/// Organisers create an event. Pops with the created [SportEvent].
class EventFormScreen extends StatefulWidget {
  const EventFormScreen({super.key, required this.organiser});

  final Account organiser;

  @override
  State<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends State<EventFormScreen> {
  final _draft = EventDraft();
  final _form = GlobalKey<FormState>();
  DateTime? _day;
  TimeOfDay _start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 11, minute: 0);
  bool _saving = false;
  String? _error;

  DateTime _at(TimeOfDay t) =>
      DateTime(_day!.year, _day!.month, _day!.day, t.hour, t.minute);

  Future<void> _pickDay() async {
    final now = DateTime.now();
    final day = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDate: _day ?? now.add(const Duration(days: 14)),
    );
    if (day != null) setState(() => _day = day);
  }

  Future<void> _pickTime(bool start) async {
    final time = await showTimePicker(
      context: context,
      initialTime: start ? _start : _end,
    );
    if (time == null) return;
    setState(() => start ? _start = time : _end = time);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_day == null) {
      setState(() => _error = 'Choose a date');
      return;
    }
    _draft
      ..startsAt = _at(_start)
      ..endsAt = _at(_end);
    if (!_draft.endsAt!.isAfter(_draft.startsAt!)) {
      setState(() => _error = 'The end time must be after the start time');
      return;
    }
    if (!_draft.startsAt!.isAfter(DateTime.now())) {
      setState(() => _error = 'The event must start in the future');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final event = await Services.events.createEvent(widget.organiser, _draft);
      if (mounted) Navigator.of(context).pop(event);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = "Couldn't save. Check your connection and try again.";
      });
    }
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  @override
  Widget build(BuildContext context) {
    final loc = MaterialLocalizations.of(context);
    InputDecoration box(String label, {String? hint, String? helper}) =>
        InputDecoration(
          labelText: label,
          hintText: hint,
          helperText: helper,
          helperMaxLines: 2,
          border: const OutlineInputBorder(),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('New event')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              decoration: box('Title', hint: 'Sunday morning run & brunch'),
              maxLength: 80,
              validator: (v) => (v == null || v.trim().length < 3)
                  ? 'At least 3 letters'
                  : null,
              onChanged: (v) => _draft.title = v,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              initialValue: null,
              isExpanded: true,
              decoration: box('Sport'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Any sport')),
                for (final s in sports)
                  DropdownMenuItem(
                    value: s,
                    child: Text(s == otherSport ? 'Other sports' : s),
                  ),
              ],
              onChanged: (v) => _draft.sport = v,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _pickDay,
              icon: const Icon(Icons.calendar_today),
              label: Text(
                _day == null ? 'Choose a date' : loc.formatFullDate(_day!),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickTime(true),
                    child: Text('Starts ${_start.format(context)}'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickTime(false),
                    child: Text('Ends ${_end.format(context)}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: box('Area or venue', hint: 'Kallang'),
              maxLength: 80,
              validator: _required,
              onChanged: (v) => _draft.area = v,
            ),
            TextFormField(
              decoration: box(
                'Meeting point',
                hint: 'Outside the stadium main entrance',
              ),
              maxLength: 200,
              onChanged: (v) => _draft.meetingPoint = v,
            ),
            TextFormField(
              decoration: box('What will happen?'),
              maxLength: 2000,
              minLines: 3,
              maxLines: 8,
              onChanged: (v) => _draft.description = v,
            ),
            TextFormField(
              decoration: box(
                'Access',
                hint: 'Step-free, quiet area, support workers welcome',
              ),
              maxLength: 500,
              onChanged: (v) => _draft.accessibility = v,
            ),
            TextFormField(
              decoration: box(
                'Safety lead',
                helper:
                    'The person responsible for safety on the day. '
                    'Shown on the event.',
              ),
              maxLength: 80,
              validator: _required,
              onChanged: (v) => _draft.safeguardingLead = v,
            ),
            const SizedBox(height: 8),
            TextFormField(
              decoration: box('Spots'),
              initialValue: '${_draft.capacity}',
              keyboardType: TextInputType.number,
              validator: (v) {
                final n = int.tryParse(v ?? '');
                return n == null || n < 1 || n > 500 ? '1 to 500' : null;
              },
              onChanged: (v) => _draft.capacity = int.tryParse(v) ?? 0,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Over-18s only'),
              subtitle: const Text(
                'Otherwise under-18s can come with a parent or guardian\'s '
                'consent.',
              ),
              value: _draft.adultsOnly,
              onChanged: (v) => setState(() => _draft.adultsOnly = v),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const CircularProgressIndicator()
                  : const Text('Publish event'),
            ),
          ],
        ),
      ),
    );
  }
}
