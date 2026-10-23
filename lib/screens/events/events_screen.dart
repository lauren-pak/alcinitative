import 'package:flutter/material.dart';

import '../../models/account.dart';
import '../../models/event.dart';
import '../../services/services.dart';
import '../../widgets/brand.dart';
import 'event_detail_screen.dart';
import 'event_form_screen.dart';

/// The home tab: upcoming in-person social sporting events. Members RSVP
/// from an event's page; organisers also get a "New event" button.
class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key, required this.account});

  final Account account;

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  late Future<List<(SportEvent, Rsvp?)>> _events = _fetch();
  late final Future<bool> _isOrganiser = Services.events.isOrganiser(
    widget.account.uid,
  );

  /// Upcoming events, each with the member's own RSVP (if any).
  Future<List<(SportEvent, Rsvp?)>> _fetch() async {
    final events = await Services.events.upcoming();
    final rsvps = await Future.wait([
      for (final e in events) Services.events.myRsvp(e.id, widget.account),
    ]);
    return [for (var i = 0; i < events.length; i++) (events[i], rsvps[i])];
  }

  Future<void> _refresh() async {
    final next = _fetch();
    setState(() {
      _events = next;
    });
    await next.catchError((_) => <(SportEvent, Rsvp?)>[]);
  }

  Future<void> _open(SportEvent event) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            EventDetailScreen(account: widget.account, event: event),
      ),
    );
    if (mounted) _refresh();
  }

  Future<void> _create() async {
    final created = await Navigator.of(context).push<SportEvent>(
      MaterialPageRoute(
        builder: (_) => EventFormScreen(organiser: widget.account),
      ),
    );
    if (created != null && mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Events')),
      floatingActionButton: FutureBuilder<bool>(
        future: _isOrganiser,
        builder: (context, snapshot) => snapshot.data == true
            ? FloatingActionButton.extended(
                heroTag: 'new-event',
                onPressed: _create,
                icon: const Icon(Icons.add),
                label: const Text('New event'),
              )
            : const SizedBox.shrink(),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<(SportEvent, Rsvp?)>>(
          future: _events,
          builder: (context, snapshot) {
            const intro = GradientBanner(
              title: 'Meet up in real life',
              body:
                  'Turn your Huddle friends into training buddies. New '
                  'social events every couple of weeks.',
              emoji: '🙌',
            );
            if (snapshot.connectionState != ConnectionState.done) {
              return ListView(
                children: [
                  intro,
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ],
              );
            }
            if (snapshot.hasError) {
              debugPrint('Events failed to load: ${snapshot.error}');
            }
            final events = snapshot.data ?? const [];
            return ListView(
              padding: const EdgeInsets.only(bottom: 96),
              children: [
                intro,
                if (snapshot.hasError)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      "Couldn't load events. Pull down to try again.",
                      style: textTheme.bodyLarge,
                    ),
                  )
                else if (events.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No events coming up yet. Check back soon!',
                      style: textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                  ),
                for (final (event, rsvp) in events)
                  EventCard(
                    event: event,
                    rsvp: rsvp,
                    onTap: () => _open(event),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// An event in the list: a date block, title, place and spots.
class EventCard extends StatelessWidget {
  const EventCard({
    super.key,
    required this.event,
    required this.onTap,
    this.rsvp,
  });

  final SportEvent event;
  final Rsvp? rsvp;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final loc = MaterialLocalizations.of(context);
    final time = TimeOfDay.fromDateTime(event.startsAt).format(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EventDateBlock(date: event.startsAt),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(event.title, style: textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      '${loc.formatShortMonthDay(event.startsAt)} · $time · '
                      '${event.area}',
                      style: textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _Chip(eventSportLabel(event), Icons.sports),
                        if (event.cancelled)
                          _Chip(
                            'Cancelled',
                            Icons.event_busy,
                            color: scheme.errorContainer,
                          )
                        else if (rsvp?.isGoing ?? false)
                          _Chip(
                            "You're going",
                            Icons.check_circle,
                            color: scheme.primaryContainer,
                          )
                        else if (rsvp != null)
                          _Chip(
                            'On the waitlist',
                            Icons.hourglass_top,
                            color: scheme.secondaryContainer,
                          )
                        else if (event.isFull)
                          _Chip('Full: join the waitlist', Icons.groups)
                        else
                          _Chip('${event.spotsLeft} spots left', Icons.groups),
                        if (event.adultsOnly)
                          const _Chip('18+', Icons.badge_outlined),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "OCT / 24" calendar-style block.
class EventDateBlock extends StatelessWidget {
  const EventDateBlock({super.key, required this.date});

  final DateTime date;

  static const _months = [
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: 60,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        gradient: Brand.sunrise,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            _months[date.month - 1],
            style: textTheme.labelMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          Text(
            '${date.day}',
            style: textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, this.icon, {this.color});

  final String label;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color ?? scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 4),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}
