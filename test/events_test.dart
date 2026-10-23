import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:athlete_app/models/account.dart';
import 'package:athlete_app/models/event.dart';
import 'package:athlete_app/models/sign_up_data.dart';
import 'package:athlete_app/screens/events/event_detail_screen.dart';
import 'package:athlete_app/screens/events/events_screen.dart';
import 'package:athlete_app/services/services.dart';

import 'fakes.dart';

late InMemoryEventsRepository events;

Account _account(String uid, {String name = 'Sam Taylor', int age = 25}) {
  final now = DateTime.now();
  return Account(
    uid: uid,
    athleteId: 'AA-${uid.toUpperCase()}',
    profile: SignUpData()
      ..role = UserRole.athlete
      ..method = SignUpMethod.email
      ..name = name
      ..dateOfBirth = DateTime(now.year - age, 1, 1)
      ..sport = 'Swimming'
      ..level = CompetitionLevel.club,
    joinedAt: now,
  );
}

Future<void> _pump(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: KeyedSubtree(key: UniqueKey(), child: screen),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    final auth = FakeAuthService();
    final feed = InMemoryFeedRepository();
    final safety = FakeSafetyRepository(feed);
    events = InMemoryEventsRepository();
    Services.auth = auth;
    Services.profiles = InMemoryProfileRepository(auth);
    Services.feed = feed;
    Services.media = FakeMediaRepository();
    Services.safety = safety;
    Services.moderation = FakeModerationRepository(feed, safety);
    Services.events = events;
    Services.verification = FakeVerificationRepository(
      Services.profiles as InMemoryProfileRepository,
    );
  });

  group('RSVPs', () {
    test('take a spot, then the waitlist when full', () async {
      final event = events.add(capacity: 1);
      final a = await events.rsvp(_account('a'), event);
      expect(a.isGoing, isTrue);
      final b = await events.rsvp(_account('b'), events.events[event.id]!);
      expect(b.status, RsvpStatus.waitlist);
      expect(events.events[event.id]!.goingCount, 1);
    });

    test('a freed spot can be claimed from the waitlist', () async {
      final event = events.add(capacity: 1);
      await events.rsvp(_account('a'), event);
      await events.rsvp(_account('b'), events.events[event.id]!);
      expect(
        () => events.claimSpot(_account('b'), events.events[event.id]!),
        throwsStateError,
      );
      await events.cancelRsvp(_account('a'), event);
      final claimed = await events.claimSpot(
        _account('b'),
        events.events[event.id]!,
      );
      expect(claimed.isGoing, isTrue);
      expect(events.events[event.id]!.goingCount, 1);
    });

    test('under-18s need a guardian, and not at 18+ events', () async {
      final teen = _account('t', age: 15);
      final open = events.add();
      expect(() => events.rsvp(teen, open), throwsStateError);
      final r = await events.rsvp(
        teen,
        open,
        guardianName: 'Mary Tan',
        guardianPhone: '+65 9123 4567',
      );
      expect(r.minor, isTrue);
      expect(r.guardianName, 'Mary Tan');

      final adults = events.add(adultsOnly: true);
      expect(EventRules.rsvpBlockedFor(teen, adults), isNotNull);
      expect(EventRules.rsvpBlockedFor(_account('a'), adults), isNull);
    });

    test('adults never store guardian details', () async {
      final r = await events.rsvp(
        _account('a'),
        events.add(),
        guardianName: 'Someone',
        guardianPhone: '91234567',
      );
      expect(r.guardianName, isNull);
      expect(r.guardianPhone, isNull);
    });

    test('deleting an account frees its spots', () async {
      final event = events.add(capacity: 2);
      await events.rsvp(_account('a'), event);
      await events.cancelAllMyRsvps(_account('a'));
      expect(events.events[event.id]!.goingCount, 0);
    });
  });

  testWidgets('Events lists upcoming events with spots', (tester) async {
    events.add(title: 'Sunday run & brunch', capacity: 12);
    events.add(title: 'Already happened', startsIn: const Duration(days: -1));
    await _pump(tester, EventsScreen(account: _account('me')));
    expect(find.text('Sunday run & brunch'), findsOneWidget);
    expect(find.text('Already happened'), findsNothing);
    expect(find.text('12 spots left'), findsOneWidget);
    expect(find.text('New event'), findsNothing);
  });

  testWidgets('organisers get a New event button', (tester) async {
    events.organisers.add('org');
    await _pump(tester, EventsScreen(account: _account('org')));
    expect(find.text('New event'), findsOneWidget);
  });

  testWidgets("RSVP from the event page and give up the spot", (tester) async {
    final event = events.add(capacity: 5);
    await _pump(
      tester,
      EventDetailScreen(account: _account('me'), event: event),
    );
    expect(find.textContaining('Safety lead: Coach Lim'), findsOneWidget);
    await tester.tap(find.text("I'm going"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("I'm bringing a support person"));
    await tester.pump();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(find.text("You're going, with your support person"), findsOneWidget);
    expect(events.events[event.id]!.goingCount, 1);

    await tester.tap(find.text("I can't go any more"));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Give up spot'));
    await tester.pumpAndSettle();
    expect(events.events[event.id]!.goingCount, 0);
    expect(find.text("I'm going"), findsOneWidget);
  });

  testWidgets('under-18s fill in a guardian before confirming', (tester) async {
    final event = events.add();
    await _pump(
      tester,
      EventDetailScreen(account: _account('t', age: 15), event: event),
    );
    await tester.tap(find.text("I'm going"));
    await tester.pumpAndSettle();
    FilledButton confirm() =>
        tester.widget(find.widgetWithText(FilledButton, 'Confirm'));
    expect(confirm().onPressed, isNull);

    await tester.enterText(
      find.widgetWithText(TextField, "Parent or guardian's name"),
      'Mary Tan',
    );
    await tester.enterText(
      find.widgetWithText(TextField, "Parent or guardian's phone"),
      '+65 9123 4567',
    );
    await tester.pump();
    expect(confirm().onPressed, isNull);
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(confirm().onPressed, isNotNull);
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(events.rsvps[event.id]!['t']!.guardianPhone, '+65 9123 4567');
  });

  testWidgets('18+ events tell under-18s they can\'t go', (tester) async {
    final event = events.add(adultsOnly: true);
    await _pump(
      tester,
      EventDetailScreen(account: _account('t', age: 15), event: event),
    );
    expect(find.text('This event is for over-18s only.'), findsOneWidget);
    expect(find.text("I'm going"), findsNothing);
  });
}
