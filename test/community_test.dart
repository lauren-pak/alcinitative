import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:athlete_app/models/account.dart';
import 'package:athlete_app/models/event.dart';
import 'package:athlete_app/models/moderation.dart';
import 'package:athlete_app/models/post.dart';
import 'package:athlete_app/models/sign_up_data.dart';
import 'package:athlete_app/models/streaks.dart';
import 'package:athlete_app/screens/feed/huddle_screen.dart';
import 'package:athlete_app/screens/profile/journey_screen.dart';
import 'package:athlete_app/screens/profile/profile_screen.dart';
import 'package:athlete_app/screens/verification/get_verified_screen.dart';
import 'package:athlete_app/screens/verification/verification_queue_screen.dart';
import 'package:athlete_app/services/services.dart';

import 'fakes.dart';

late InMemoryProfileRepository profiles;
late InMemoryFeedRepository feed;
late FakeSafetyRepository safety;
late FakeVerificationRepository verification;
late InMemoryEventsRepository events;

Account _account(
  String uid, {
  String name = 'Sam Taylor',
  bool verified = false,
  UserRole role = UserRole.athlete,
}) {
  final now = DateTime.now();
  final profile = SignUpData()
    ..role = role
    ..method = SignUpMethod.email
    ..name = name
    ..dateOfBirth = DateTime(now.year - 25, 1, 1);
  if (role == UserRole.athlete) {
    profile
      ..sport = 'Swimming'
      ..level = CompetitionLevel.national
      ..category = AthleteCategory.national;
  }
  final account = Account(
    uid: uid,
    athleteId: 'AA-${uid.toUpperCase()}',
    profile: profile,
    joinedAt: now,
    verified: verified,
  );
  profiles.accounts[uid] = account;
  return account;
}

Future<void> _pump(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(800, 2400);
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
    profiles = InMemoryProfileRepository(auth);
    feed = InMemoryFeedRepository();
    safety = FakeSafetyRepository(feed);
    verification = FakeVerificationRepository(profiles);
    events = InMemoryEventsRepository();
    Services.auth = auth;
    Services.profiles = profiles;
    Services.feed = feed;
    Services.media = FakeMediaRepository();
    Services.safety = safety;
    Services.moderation = FakeModerationRepository(feed, safety);
    Services.events = events;
    Services.verification = verification;
  });

  group('weekly streaks', () {
    final now = DateTime(2026, 10, 23); // a Friday

    test('weeks start on Monday', () {
      expect(weekStart(now), DateTime(2026, 10, 19));
      expect(weekStart(DateTime(2026, 10, 19, 8)), DateTime(2026, 10, 19));
    });

    test('count weeks in a row, once per week', () {
      final s = computeStreak([
        now,
        now.subtract(const Duration(days: 1)), // same week
        now.subtract(const Duration(days: 7)),
        now.subtract(const Duration(days: 14)),
      ], now);
      expect(s.current, 3);
      expect(s.longest, 3);
      expect(s.activeThisWeek, isTrue);
    });

    test("stay alive until this week ends, then reset", () {
      final lastWeek = computeStreak([
        now.subtract(const Duration(days: 7)),
      ], now);
      expect(lastWeek.current, 1);
      expect(lastWeek.activeThisWeek, isFalse);
      final gone = computeStreak([now.subtract(const Duration(days: 21))], now);
      expect(gone.current, 0);
      expect(gone.longest, 1);
    });

    test('badges follow the longest streak and activity', () {
      final badges = badgesFor(
        streak: const StreakSummary(
          current: 0,
          longest: 4,
          activeThisWeek: false,
          activeWeeks: 4,
        ),
        spotlights: 1,
        posts: 3,
        eventsAttended: 0,
        verified: true,
      );
      bool earned(String title) =>
          badges.firstWhere((b) => b.title == title).earned;
      expect(earned('1 month'), isTrue);
      expect(earned('2 months'), isFalse);
      expect(earned('Spotlight'), isTrue);
      expect(earned('First meetup'), isFalse);
      expect(earned('Verified'), isTrue);
      expect(nextMilestone(4), 8);
      expect(nextMilestone(12), isNull);
    });

    testWidgets('the profile shows the streak and badges', (tester) async {
      final me = _account('me', verified: true);
      await feed.createPost(
        me,
        NewPost()
          ..topic = Topic.training
          ..text = 'Morning swim set done!',
      );
      // An event they went to yesterday.
      final past = events.add(startsIn: const Duration(days: -1));
      events.rsvps[past.id] = {
        me.uid: Rsvp(
          uid: me.uid,
          eventId: past.id,
          name: me.profile.name,
          status: RsvpStatus.going,
          createdAt: DateTime.now(),
        ),
      };
      await _pump(tester, ProfileScreen(account: me, isNewAccount: false));
      expect(find.text('1-week streak'), findsOneWidget);
      expect(find.textContaining("You've kept it going"), findsOneWidget);
      expect(find.textContaining('Badges · '), findsOneWidget);
      expect(find.text('Morning swim set done!'), findsOneWidget);
    });
  });

  group('verification', () {
    test('only verified athletes share spotlights', () {
      final athlete = _account('a');
      expect(FeedRules.postTypesFor(athlete), [PostType.question]);
      expect(FeedRules.spotlightBlockedFor(athlete), isNotNull);
      athlete.verified = true;
      expect(FeedRules.postTypesFor(athlete), PostType.values);
      expect(FeedRules.spotlightBlockedFor(athlete), isNull);
    });

    test('questions are answered by verified athletes or the asker', () async {
      final asker = _account('asker', role: UserRole.public);
      final question = await feed.createPost(
        asker,
        NewPost()
          ..type = PostType.question
          ..topic = Topic.mindset
          ..replyPolicy = ReplyPolicy.everyone
          ..text = 'How do you stay calm?',
      );
      expect(question.holdReason, HoldReason.newQuestion);
      expect(FeedRules.replyBlockedFor(_account('b'), question), isNotNull);
      expect(
        FeedRules.replyBlockedFor(_account('v', verified: true), question),
        isNull,
      );
      expect(FeedRules.replyBlockedFor(asker, question, isMine: true), isNull);
    });

    testWidgets('ask, then a reviewer verifies', (tester) async {
      final athlete = _account('a');
      await _pump(tester, GetVerifiedScreen(account: athlete));
      await tester.enterText(find.byType(TextField), 'Team Singapore swimming');
      await tester.tap(find.text('Ask to be verified'));
      await tester.pumpAndSettle();
      expect(find.text('Request sent ⏳'), findsOneWidget);

      final reviewer = _account('mod');
      verification.reviewers.add('mod');
      await _pump(tester, VerificationQueueScreen(reviewer: reviewer));
      expect(find.text('Says they are: National athlete'), findsOneWidget);
      await tester.tap(find.text('Verify'));
      await tester.pumpAndSettle();
      expect(athlete.verified, isTrue);
      expect(find.text('No requests waiting. 🎉'), findsOneWidget);
    });

    testWidgets('unverified athletes see how to share spotlights', (
      tester,
    ) async {
      await _pump(
        tester,
        HuddleScreen(account: _account('a'), onCompose: (_) {}),
      );
      expect(find.text('Share a spotlight'), findsNothing);
      expect(
        find.textContaining('Ask to be verified in Settings'),
        findsOneWidget,
      );
    });
  });

  group('weekly Huddle question', () {
    testWidgets('moderators set it; verified athletes answer it', (
      tester,
    ) async {
      final mod = _account('mod');
      safety.moderators.add('mod');
      await _pump(tester, HuddleScreen(account: mod, onCompose: (_) {}));
      await tester.tap(find.text("Set this week's Huddle question"));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        'What do you do the night before a final?',
      );
      await tester.tap(find.text('Post question'));
      await tester.pumpAndSettle();
      expect(feed.prompts, hasLength(1));
      expect(
        find.text('What do you do the night before a final?'),
        findsOneWidget,
      );

      WeeklyPrompt? answering;
      await _pump(
        tester,
        HuddleScreen(
          account: _account('v', verified: true),
          onCompose: (_) {},
          onAnswerPrompt: (p) => answering = p,
        ),
      );
      await tester.tap(find.text('Answer it'));
      expect(answering?.text, 'What do you do the night before a final?');
    });

    testWidgets('answers are listed under the question', (tester) async {
      final prompt = await feed.createPrompt(
        _account('mod'),
        'Favourite warm-up?',
      );
      await feed.createPost(
        _account('v', verified: true),
        NewPost()
          ..topic = Topic.gameDay
          ..text = 'Skipping and loud music!'
          ..prompt = prompt,
      );
      await _pump(
        tester,
        HuddleScreen(account: _account('me'), onCompose: (_) {}),
      );
      expect(find.text('Answer it'), findsNothing);
      expect(
        find.textContaining('Huddle question: Favourite warm-up?'),
        findsOneWidget,
      );
      await tester.tap(find.text('See answers'));
      await tester.pumpAndSettle();
      expect(find.text('Skipping and loud music!'), findsOneWidget);
    });
  });

  testWidgets('journey stories: intro and chapters, editable by the owner', (
    tester,
  ) async {
    final me = _account('me', verified: true);
    final journey = await feed.createJourney(me, 'Road to the SEA Games');
    await feed.createPost(
      me,
      NewPost()
        ..topic = Topic.training
        ..text = 'First national trials.'
        ..journey = journey,
    );
    await _pump(tester, JourneyScreen(journey: journey, viewer: me));
    expect(find.text('Chapter 1'), findsOneWidget);
    await tester.tap(find.byTooltip('Edit story'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Where it started'),
      'I started swimming at 9.',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('I started swimming at 9.'), findsOneWidget);

    await _pump(tester, JourneyScreen(journey: journey, viewer: _account('x')));
    expect(find.byTooltip('Edit story'), findsNothing);
  });
}
