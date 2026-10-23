import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:athlete_app/models/account.dart';
import 'package:athlete_app/models/moderation.dart';
import 'package:athlete_app/models/post.dart';
import 'package:athlete_app/models/sign_up_data.dart';
import 'package:athlete_app/screens/feed/compose_post_screen.dart';
import 'package:athlete_app/screens/feed/huddle_screen.dart';
import 'package:athlete_app/screens/feed/post_detail_screen.dart';
import 'package:athlete_app/screens/moderation/moderation_screen.dart';
import 'package:athlete_app/services/services.dart';

import 'fakes.dart';

late InMemoryFeedRepository feed;
late FakeSafetyRepository safety;

Account _account(String uid, {String name = 'Sam Taylor', int age = 25}) {
  final now = DateTime.now();
  final profile = SignUpData()
    ..role = UserRole.athlete
    ..method = SignUpMethod.email
    ..name = name
    ..dateOfBirth = DateTime(now.year - age, 1, 1)
    ..sport = 'Swimming'
    ..level = CompetitionLevel.club
    ..topics.addAll({Topic.training, Topic.mindset});
  return Account(
    // Test athletes are verified unless a test says otherwise.
    verified: true,
    uid: uid,
    athleteId: 'AA-$uid',
    profile: profile,
    joinedAt: now,
  );
}

Future<Post> _post(
  Account author, {
  String text = 'Good session today.',
  Topic topic = Topic.training,
  bool adultRepliesAllowed = false,
}) => feed.createPost(
  author,
  NewPost()
    ..topic = topic
    ..text = text
    ..replyPolicy = ReplyPolicy.everyone
    ..adultRepliesAllowed = adultRepliesAllowed,
);

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
    feed = InMemoryFeedRepository();
    safety = FakeSafetyRepository(feed);
    Services.auth = auth;
    Services.profiles = InMemoryProfileRepository(auth);
    Services.feed = feed;
    Services.media = FakeMediaRepository();
    Services.events = InMemoryEventsRepository();
    Services.verification = FakeVerificationRepository(
      Services.profiles as InMemoryProfileRepository,
    );
    Services.safety = safety;
    Services.moderation = FakeModerationRepository(feed, safety);
  });

  group('flagged words', () {
    test('match whole phrases, ignoring case', () {
      expect(
        containsFlaggedWords('I keep SKIPPING MEALS before races'),
        isTrue,
      );
      expect(
        containsFlaggedWords('Trying a weight cut\nfor nationals'),
        isTrue,
      );
      expect(containsFlaggedWords('Great meal after training'), isFalse);
    });

    test('hold posts and replies out of the feed', () async {
      final adult = _account('a');
      final held = await _post(
        adult,
        text: 'I want to stop eating before meets',
      );
      expect(held.holdReason, HoldReason.flaggedWords);
      expect(await feed.latest({Topic.training}), isEmpty);

      final post = await _post(adult);
      final reply = await feed.addReply(_account('b'), post, 'Laxative tip');
      expect(reply.isHeld, isTrue);
      expect(await feed.replies(post.id), isEmpty);
      // The writer still sees their own held reply.
      expect(await feed.replies(post.id, viewer: _account('b')), [reply]);
    });

    testWidgets('ask "Are you okay?" before posting', (tester) async {
      await _pump(tester, ComposePostScreen(account: _account('a')));
      await tester.tap(find.text('Training wins'));
      await tester.enterText(
        find.byType(TextField).first,
        "I've been starving myself to make weight",
      );
      await tester.ensureVisible(find.text('Post'));
      await tester.tap(find.text('Post'));
      await tester.pumpAndSettle();
      expect(find.text('Are you okay?'), findsOneWidget);
      await tester.tap(find.text('Edit my post'));
      await tester.pumpAndSettle();
      expect(feed.posts, isEmpty);
    });
  });

  group('under-18 adult replies', () {
    test('are off unless the poster allows them, then held', () async {
      final teen = _account('t', age: 15);
      final adult = _account('a');
      final closed = await _post(teen);
      expect(FeedRules.replyBlockedFor(adult, closed), isNotNull);

      final open = await _post(teen, adultRepliesAllowed: true);
      expect(open.adultRepliesAllowed, isTrue);
      expect(FeedRules.replyBlockedFor(adult, open), isNull);
      final reply = await feed.addReply(adult, open, 'Nice work!');
      expect(reply.holdReason, HoldReason.adultReplyToMinor);
      // Other under-18s' replies go straight through.
      final peer = await feed.addReply(_account('t2', age: 16), open, 'Same!');
      expect(peer.isHeld, isFalse);
    });

    test('adults cannot turn it on for themselves', () async {
      final post = await _post(_account('a'), adultRepliesAllowed: true);
      expect(post.adultRepliesAllowed, isFalse);
    });
  });

  test('3 reports hide a post until a moderator checks it', () async {
    final post = await _post(_account('a'));
    for (final uid in ['r1', 'r2']) {
      expect(
        await safety.reportPost(_account(uid), post, ReportReason.bullying),
        isTrue,
      );
    }
    // Reporting twice doesn't count twice.
    expect(
      await safety.reportPost(_account('r1'), post, ReportReason.spam),
      isFalse,
    );
    expect(await feed.latest({Topic.training}), hasLength(1));
    await safety.reportPost(_account('r3'), post, ReportReason.bullying);
    expect(await feed.latest({Topic.training}), isEmpty);
    expect(feed.posts.single.reportCount, 3);
  });

  testWidgets('blocking hides that member from the feed', (tester) async {
    final me = _account('me');
    final other = _account('x', name: 'Alex Lee');
    await _post(other, text: 'Post from Alex');
    await _pump(tester, HuddleScreen(account: me, onCompose: (_) {}));
    expect(find.text('Post from Alex'), findsOneWidget);

    await safety.block(me, Author.of(other));
    await _pump(tester, HuddleScreen(account: me, onCompose: (_) {}));
    expect(find.text('Post from Alex'), findsNothing);
  });

  testWidgets('report from the post menu', (tester) async {
    final post = await _post(_account('a'));
    await _pump(tester, PostDetailScreen(post: post, viewer: _account('me')));
    await tester.tap(find.byTooltip('More').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Report post'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ReportReason.unsafeAdvice.label));
    await tester.pump();
    await tester.tap(find.text('Send report'));
    await tester.pumpAndSettle();
    expect(safety.reports, hasLength(1));
    expect(safety.reports.values.single.reason, ReportReason.unsafeAdvice);
  });

  testWidgets('muted categories drop out of Huddle', (tester) async {
    final me = _account('me')..profile.mutedTopics.add(Topic.mindset);
    await _pump(tester, HuddleScreen(account: me, onCompose: (_) {}));
    expect(
      find.widgetWithText(ChoiceChip, '🏋️ Training wins'),
      findsOneWidget,
    );
    expect(find.widgetWithText(ChoiceChip, '🧠 Mindset'), findsNothing);
  });

  testWidgets('moderators approve held posts', (tester) async {
    await _post(_account('a'), text: 'Tips to purge before weigh-in?');
    await _pump(tester, const ModerationScreen());
    expect(find.text('Tips to purge before weigh-in?'), findsOneWidget);
    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();
    expect(feed.posts.single.status, ContentStatus.visible);
    expect(find.text('Nothing waiting. 🎉'), findsOneWidget);
  });
}
