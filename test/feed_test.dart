import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:athlete_app/models/account.dart';
import 'package:athlete_app/models/moderation.dart';
import 'package:athlete_app/models/post.dart';
import 'package:athlete_app/models/sign_up_data.dart';
import 'package:athlete_app/screens/feed/compose_post_screen.dart';
import 'package:athlete_app/screens/feed/feed_screen.dart';
import 'package:athlete_app/screens/feed/post_detail_screen.dart';
import 'package:athlete_app/screens/home_shell.dart';
import 'package:athlete_app/screens/your_data_screen.dart';
import 'package:athlete_app/services/services.dart';

import 'fakes.dart';

late FakeAuthService auth;
late InMemoryProfileRepository profiles;
late InMemoryFeedRepository feed;

Account _account(
  String uid, {
  String name = 'Sam Taylor',
  int age = 25,
  UserRole role = UserRole.athlete,
}) {
  final now = DateTime.now();
  final profile = SignUpData()
    ..role = role
    ..method = SignUpMethod.email
    ..name = name
    ..dateOfBirth = DateTime(now.year - age, 1, 1)
    ..topics.addAll({Topic.training, Topic.injury});
  if (role == UserRole.athlete) {
    profile
      ..sport = 'Swimming'
      ..level = CompetitionLevel.club;
  }
  return Account(
    uid: uid,
    athleteId: 'AA-$uid',
    profile: profile,
    joinedAt: now,
  );
}

Future<Post> _post(
  Account author, {
  PostType type = PostType.experience,
  Topic topic = Topic.training,
  String text = 'My first 10k swim set went really well this week.',
  ReplyPolicy policy = ReplyPolicy.athletes,
  bool anonymous = false,
}) {
  final draft = NewPost()
    ..type = type
    ..topic = topic
    ..text = text
    ..replyPolicy = policy
    ..anonymous = anonymous;
  return feed.createPost(author, draft);
}

Future<void> _pump(WidgetTester tester, Widget screen) async {
  // A phone-shaped window, so long post pages aren't cut off.
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  // A fresh key so switching viewer builds a new screen, not a reused one.
  await tester.pumpWidget(
    MaterialApp(
      home: KeyedSubtree(key: UniqueKey(), child: screen),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late FakeSafetyRepository safety;
  setUp(() {
    auth = FakeAuthService();
    profiles = InMemoryProfileRepository(auth);
    feed = InMemoryFeedRepository();
    Services.auth = auth;
    Services.profiles = profiles;
    Services.feed = feed;
    safety = FakeSafetyRepository(feed);
    Services.safety = safety;
    Services.moderation = FakeModerationRepository(feed, safety);
    Services.media = FakeMediaRepository();
  });

  group('FeedRules', () {
    test('general public members can only ask questions', () {
      expect(FeedRules.postTypesFor(_account('p', role: UserRole.public)), [
        PostType.question,
      ]);
      expect(FeedRules.postTypesFor(_account('a')), PostType.values);
    });

    test('under-18 Sports nutrition posts wait for a moderator', () async {
      final teen = _account('t', age: 15);
      expect(FeedRules.topicReviewNoteFor(teen, Topic.nutrition), isNotNull);
      expect(FeedRules.topicReviewNoteFor(teen, Topic.training), isNull);
      expect(
        FeedRules.topicReviewNoteFor(_account('a'), Topic.nutrition),
        isNull,
      );

      final held = await _post(teen, topic: Topic.nutrition);
      expect(held.isHeld, isTrue);
      expect(held.holdReason, HoldReason.minorNutrition);
      expect(
        (await _post(_account('a'), topic: Topic.nutrition)).isHeld,
        isFalse,
      );
    });

    test('reply permissions follow the poster and the under-18 rule', () async {
      final adult = _account('a');
      final teen = _account('t', age: 15);
      final public = _account('p', role: UserRole.public);

      final athletesOnly = await _post(adult);
      expect(FeedRules.replyBlockedFor(adult, athletesOnly), isNull);
      expect(
        FeedRules.replyBlockedFor(public, athletesOnly),
        'Only athletes can reply to this post.',
      );

      final everyone = await _post(adult, policy: ReplyPolicy.everyone);
      expect(FeedRules.replyBlockedFor(public, everyone), isNull);

      final closed = await _post(adult, policy: ReplyPolicy.none);
      expect(
        FeedRules.replyBlockedFor(adult, closed),
        'Replies are turned off.',
      );

      final teenPost = await _post(teen);
      expect(
        FeedRules.replyBlockedFor(_account('t2', age: 16), teenPost),
        isNull,
      );
      expect(
        FeedRules.replyBlockedFor(adult, teenPost),
        'Only under-18s can reply to this post.',
      );
    });
  });

  testWidgets('feed shows questions needing answers first', (tester) async {
    final me = _account('me');
    await _post(
      _account('a', name: 'Alex Tan'),
      type: PostType.question,
      text: 'How do you taper before a meet?',
    );
    await _post(_account('b', name: 'Bea Lim'));

    await _pump(tester, FeedScreen(account: me));

    expect(find.text('Needs an answer'), findsOneWidget);
    expect(find.text('How do you taper before a meet?'), findsOneWidget);
    expect(find.text('Bea Lim'), findsOneWidget);
    final needsY = tester.getTopLeft(find.text('Needs an answer')).dy;
    final latestY = tester.getTopLeft(find.text('Latest')).dy;
    expect(needsY, lessThan(latestY));
  });

  testWidgets('pull to refresh shows new posts', (tester) async {
    await _pump(tester, FeedScreen(account: _account('me')));
    expect(find.text('No posts yet. Be the first to share.'), findsOneWidget);

    await _post(_account('a'), text: 'Fresh post after the feed loaded.');
    await tester.fling(find.byType(ListView).first, const Offset(0, 900), 1000);
    await tester.pumpAndSettle();

    expect(find.text('Fresh post after the feed loaded.'), findsOneWidget);
  });

  testWidgets('anonymous posts hide the name and sport', (tester) async {
    await _post(
      _account('a', name: 'Alex Tan'),
      text: 'Struggled with confidence after my injury.',
      anonymous: true,
    );

    await _pump(tester, FeedScreen(account: _account('me')));

    expect(find.text('Anonymous athlete'), findsOneWidget);
    expect(find.text('Alex Tan'), findsNothing);
    expect(find.text('Swimming · Club'), findsNothing);
  });

  testWidgets('injury posts show the not-medical-advice banner', (
    tester,
  ) async {
    await _post(
      _account('a'),
      topic: Topic.injury,
      text: 'Shin splints: what helped me recover.',
    );

    await _pump(tester, FeedScreen(account: _account('me')));

    expect(
      find.textContaining('Shared experience, not medical advice'),
      findsOneWidget,
    );
  });

  testWidgets('composing a post adds it to the feed', (tester) async {
    final me = _account('me');
    await _pump(tester, HomeShell(account: me, isNewAccount: false));

    // "New post" lives in the bottom navigation bar and opens the camera.
    // Tests have no camera, so switch to a text post.
    await tester.tap(find.text('New post'));
    await tester.pumpAndSettle();
    expect(find.text('No camera found on this device.'), findsOneWidget);
    await tester.tap(find.text('Text'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Write a post'));
    await tester.pumpAndSettle();

    // Posting without a topic is caught.
    await tester.tap(find.widgetWithText(FilledButton, 'Post'));
    await tester.pump();
    expect(find.text('Choose a topic'), findsWidgets);

    await tester.tap(find.text('Training'));
    await tester.enterText(
      find.byType(TextField).first,
      'Doubled my stretching and my shoulder feels better.',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Post'));
    await tester.pumpAndSettle();

    expect(
      find.text('Doubled my stretching and my shoulder feels better.'),
      findsOneWidget,
    );
    expect(feed.posts.single.author?.name, 'Sam Taylor');
  });

  testWidgets('public members can only ask, under-18 nutrition is reviewed', (
    tester,
  ) async {
    await _pump(
      tester,
      ComposePostScreen(account: _account('p', role: UserRole.public)),
    );
    expect(find.text('Share an experience'), findsNothing);
    expect(find.textContaining('Question from the public'), findsOneWidget);

    await _pump(tester, ComposePostScreen(account: _account('t', age: 15)));
    final nutrition = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'Sports nutrition'),
    );
    expect(nutrition.onSelected, isNotNull);
    await tester.tap(find.text('Sports nutrition'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Sports nutrition posts from under-18s'),
      findsOneWidget,
    );
  });

  testWidgets('replies, Helpful and "This helped me" answer a question', (
    tester,
  ) async {
    final asker = _account('asker', name: 'Asha Rao');
    final helper = _account('helper', name: 'Ben Ong');
    final question = await _post(
      asker,
      type: PostType.question,
      text: 'Any tips for race-day nerves?',
    );

    // The helper replies and marks nothing yet.
    await _pump(tester, PostDetailScreen(post: question, viewer: helper));
    expect(
      find.textContaining("doesn't mean the person is a qualified"),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextField), 'Box breathing helps me.');
    await tester.tap(find.byTooltip('Send reply'));
    await tester.pumpAndSettle();
    expect(find.text('Box breathing helps me.'), findsOneWidget);
    expect(find.text('This helped me'), findsNothing);

    await tester.tap(find.textContaining('Helpful ·'));
    await tester.pumpAndSettle();
    expect(find.text('Helpful · 1'), findsOneWidget);

    // The asker sees "This helped me" and answers the question.
    await _pump(tester, PostDetailScreen(post: question, viewer: asker));
    await tester.tap(find.text('This helped me'));
    await tester.pumpAndSettle();
    expect(find.text('Helped the asker'), findsOneWidget);
    expect(find.text('Answered'), findsOneWidget);
    expect(await feed.needsAnswer({Topic.training}), isEmpty);
  });

  testWidgets('Been there toggles on and off', (tester) async {
    final post = await _post(_account('a'));
    await _pump(tester, PostDetailScreen(post: post, viewer: _account('me')));

    await tester.tap(find.text('Been there · 0'));
    await tester.pumpAndSettle();
    expect(find.text('Been there · 1'), findsOneWidget);
    await tester.tap(find.text('Been there · 1'));
    await tester.pumpAndSettle();
    expect(find.text('Been there · 0'), findsOneWidget);
  });

  testWidgets('adults see why they cannot reply to an under-18 post', (
    tester,
  ) async {
    final post = await _post(_account('t', age: 15));
    await _pump(tester, PostDetailScreen(post: post, viewer: _account('a')));

    expect(find.text('Only under-18s can reply to this post.'), findsOneWidget);
    expect(find.byTooltip('Send reply'), findsNothing);
  });

  testWidgets('the help button lists support services', (tester) async {
    final post = await _post(_account('a'));
    await _pump(tester, PostDetailScreen(post: post, viewer: _account('me')));

    await tester.tap(find.byTooltip('Get help'));
    await tester.pumpAndSettle();
    expect(find.text('Samaritans of Singapore (SOS)'), findsOneWidget);
    expect(find.textContaining('1767'), findsOneWidget);
  });

  testWidgets('deleting an account deletes its posts too', (tester) async {
    final user = await auth.signUpWithEmail('sam@example.com', 'password123');
    final account = await profiles.create(
      user.uid,
      _account(user.uid).profile..consentGivenAt = DateTime.now(),
    );
    await _post(account);
    await _post(_account('other'), text: 'Someone else wrote this post.');

    await _pump(tester, YourDataScreen(account: account));
    final delete = find.text('Delete my account');
    await tester.ensureVisible(delete);
    await tester.tap(delete);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(feed.posts.map((p) => p.text), ['Someone else wrote this post.']);
  });
}
