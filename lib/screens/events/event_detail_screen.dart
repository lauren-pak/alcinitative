import 'package:flutter/material.dart';

import '../../models/account.dart';
import '../../models/event.dart';
import '../../services/services.dart';
import 'events_screen.dart';

/// One event: details, safety information, and the member's RSVP. Under-18s
/// give a parent or guardian's consent and contact. Organisers also see
/// who's coming and can cancel the event.
class EventDetailScreen extends StatefulWidget {
  const EventDetailScreen({
    super.key,
    required this.account,
    required this.event,
  });

  final Account account;
  final SportEvent event;

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  late SportEvent _event = widget.event;
  Rsvp? _rsvp;
  bool _loaded = false;
  bool _busy = false;
  bool _isOrganiser = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        Services.events.getEvent(_event.id),
        Services.events.myRsvp(_event.id, widget.account),
        Services.events.isOrganiser(widget.account.uid),
      ]);
      if (!mounted) return;
      setState(() {
        _event = (results[0] as SportEvent?) ?? _event;
        _rsvp = results[1] as Rsvp?;
        _isOrganiser = results[2] as bool;
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  void _say(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (_) {
      if (mounted) {
        _say("That didn't work. Check your connection and try again.");
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rsvpNow() async {
    final choice = await showModalBottomSheet<_RsvpChoice>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _RsvpSheet(account: widget.account, event: _event),
    );
    if (choice == null || !mounted) return;
    await _run(() async {
      final rsvp = await Services.events.rsvp(
        widget.account,
        _event,
        supportPerson: choice.supportPerson,
        guardianName: choice.guardianName,
        guardianPhone: choice.guardianPhone,
      );
      if (!mounted) return;
      setState(() => _rsvp = rsvp);
      _say(
        rsvp.isGoing
            ? "You're going! See you there."
            : "It's full, so you're on the waitlist. If a spot opens, you can "
                  'take it here.',
      );
      await _load();
    });
  }

  Future<void> _claim() => _run(() async {
    try {
      final rsvp = await Services.events.claimSpot(widget.account, _event);
      if (!mounted) return;
      setState(() => _rsvp = rsvp);
      _say("You got the spot! You're going.");
    } on StateError {
      if (mounted) _say('Sorry, someone else took it. Still on the waitlist.');
    }
    await _load();
  });

  Future<void> _cancel() async {
    final going = _rsvp?.isGoing ?? false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(going ? 'Give up your spot?' : 'Leave the waitlist?'),
        content: Text(
          going
              ? 'Someone on the waitlist can then take it.'
              : "You won't be able to take a spot if one opens.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(going ? 'Give up spot' : 'Leave waitlist'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _run(() async {
      await Services.events.cancelRsvp(widget.account, _event);
      if (!mounted) return;
      setState(() => _rsvp = null);
      _say(
        going
            ? 'Your spot is free for someone else.'
            : 'You left the waitlist.',
      );
      await _load();
    });
  }

  Future<void> _cancelEvent() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this event?'),
        content: const Text(
          "Everyone who RSVPed will see it's cancelled. Let them know why "
          'through your usual channels too.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep event'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel event'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _run(() async {
      await Services.events.cancelEvent(_event);
      await _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final loc = MaterialLocalizations.of(context);
    final event = _event;
    final start = TimeOfDay.fromDateTime(event.startsAt).format(context);
    final end = TimeOfDay.fromDateTime(event.endsAt).format(context);
    final blocked = EventRules.rsvpBlockedFor(widget.account, event);

    Widget row(IconData icon, String title, String? body) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: scheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: textTheme.titleSmall),
                if (body != null && body.isNotEmpty)
                  Text(body, style: textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Event')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (event.cancelled) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'This event was cancelled.',
                  style: textTheme.titleSmall?.copyWith(
                    color: scheme.onErrorContainer,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EventDateBlock(date: event.startsAt),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(event.title, style: textTheme.headlineSmall),
                ),
              ],
            ),
            const SizedBox(height: 20),
            row(
              Icons.schedule,
              loc.formatFullDate(event.startsAt),
              '$start to $end',
            ),
            row(Icons.place_outlined, event.area, event.meetingPoint),
            row(Icons.sports, eventSportLabel(event), null),
            row(
              Icons.groups_outlined,
              event.isFull
                  ? 'Full (${event.capacity} people)'
                  : '${event.goingCount} going · ${event.spotsLeft} spots left',
              event.adultsOnly
                  ? 'For over-18s only.'
                  : 'Under-18s are welcome with a parent or guardian\'s OK.',
            ),
            if (event.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(event.description, style: textTheme.bodyLarge),
              const SizedBox(height: 16),
            ],
            if (event.accessibility.isNotEmpty)
              row(Icons.accessible, 'Access', event.accessibility),
            row(
              Icons.health_and_safety_outlined,
              'Safety lead: ${event.safeguardingLead}',
              'Find them if you need help or feel unsafe on the day.',
            ),
            const SizedBox(height: 8),
            if (!_loaded)
              const Center(child: CircularProgressIndicator())
            else
              _rsvpSection(textTheme, blocked),
            if (_isOrganiser) ...[
              const Divider(height: 40),
              Text('Organiser', style: textTheme.titleMedium),
              const SizedBox(height: 8),
              _RsvpList(eventId: event.id),
              if (!event.cancelled) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: scheme.error,
                  ),
                  onPressed: _busy ? null : _cancelEvent,
                  icon: const Icon(Icons.event_busy),
                  label: const Text('Cancel event'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _rsvpSection(TextTheme textTheme, String? blocked) {
    final rsvp = _rsvp;
    final event = _event;
    final full = SizedBox(
      width: double.infinity,
      child: switch (rsvp) {
        final r? when r.isGoing => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.tonalIcon(
              onPressed: null,
              icon: const Icon(Icons.check_circle),
              label: Text(
                r.supportPerson
                    ? "You're going, with your support person"
                    : "You're going",
              ),
            ),
            if (!event.hasStarted && !event.cancelled)
              TextButton(
                onPressed: _busy ? null : _cancel,
                child: const Text("I can't go any more"),
              ),
          ],
        ),
        final _? => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text("You're on the waitlist.", style: textTheme.titleSmall),
            const SizedBox(height: 8),
            if (!event.isFull && blocked == null)
              FilledButton.icon(
                onPressed: _busy ? null : _claim,
                icon: const Icon(Icons.celebration_outlined),
                label: const Text('A spot opened! Take it'),
              ),
            if (blocked == null)
              TextButton(
                onPressed: _busy ? null : _cancel,
                child: const Text('Leave the waitlist'),
              ),
          ],
        ),
        null when blocked != null => Text(blocked, style: textTheme.bodyLarge),
        null => FilledButton.icon(
          onPressed: _busy ? null : _rsvpNow,
          icon: Icon(
            event.isFull ? Icons.hourglass_top : Icons.event_available,
          ),
          label: Text(event.isFull ? 'Join the waitlist' : "I'm going"),
        ),
      },
    );
    return full;
  }
}

/// What the member chose in the RSVP sheet.
class _RsvpChoice {
  const _RsvpChoice({
    required this.supportPerson,
    this.guardianName,
    this.guardianPhone,
  });

  final bool supportPerson;
  final String? guardianName;
  final String? guardianPhone;
}

class _RsvpSheet extends StatefulWidget {
  const _RsvpSheet({required this.account, required this.event});

  final Account account;
  final SportEvent event;

  @override
  State<_RsvpSheet> createState() => _RsvpSheetState();
}

class _RsvpSheetState extends State<_RsvpSheet> {
  bool _supportPerson = false;
  bool _consent = false;
  final _guardianName = TextEditingController();
  final _guardianPhone = TextEditingController();

  bool get _minor => EventRules.needsGuardian(widget.account);

  bool get _ready =>
      !_minor ||
      (_consent &&
          _guardianName.text.trim().length > 1 &&
          EventRules.validPhone(_guardianPhone.text));

  @override
  void dispose() {
    _guardianName.dispose();
    _guardianPhone.dispose();
    super.dispose();
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
            Text(
              widget.event.isFull ? 'Join the waitlist' : "You're going to…",
              style: textTheme.titleLarge,
            ),
            Text(widget.event.title, style: textTheme.titleMedium),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text("I'm bringing a support person"),
              subtitle: const Text(
                'A carer, coach or family member who helps you. They '
                "don't need their own spot.",
              ),
              value: _supportPerson,
              onChanged: (v) => setState(() => _supportPerson = v),
            ),
            if (_minor) ...[
              const SizedBox(height: 8),
              Text('Your parent or guardian', style: textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(
                "Because you're under 18, a parent or guardian needs to say "
                "you can go. Only the event organisers see their details, "
                'to contact them if needed.',
                style: textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _guardianName,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: "Parent or guardian's name",
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _guardianPhone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: "Parent or guardian's phone",
                  hintText: '+65 9123 4567',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text(
                  'My parent or guardian says I can go to this event',
                ),
                value: _consent,
                onChanged: (v) => setState(() => _consent = v ?? false),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _ready
                    ? () => Navigator.of(context).pop(
                        _RsvpChoice(
                          supportPerson: _supportPerson,
                          guardianName: _minor ? _guardianName.text : null,
                          guardianPhone: _minor ? _guardianPhone.text : null,
                        ),
                      )
                    : null,
                child: Text(widget.event.isFull ? 'Join waitlist' : 'Confirm'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Organisers: who's coming, with support people and guardian contacts.
class _RsvpList extends StatelessWidget {
  const _RsvpList({required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return FutureBuilder<List<Rsvp>>(
      future: Services.events.rsvpsFor(eventId),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final rsvps = snapshot.data ?? const <Rsvp>[];
        if (rsvps.isEmpty) {
          return Text('No RSVPs yet.', style: textTheme.bodyMedium);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final r in rsvps)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  r.isGoing ? Icons.check_circle : Icons.hourglass_top,
                ),
                title: Text(r.name),
                subtitle: Text(
                  [
                    r.isGoing ? 'Going' : 'Waitlist',
                    if (r.supportPerson) '+ support person',
                    if (r.minor)
                      'Under 18 · guardian ${r.guardianName} ${r.guardianPhone}',
                  ].join(' · '),
                ),
              ),
          ],
        );
      },
    );
  }
}
