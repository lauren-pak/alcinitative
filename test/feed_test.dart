import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:athlete_app/models/account.dart';
import 'package:athlete_app/models/post.dart';
import 'package:athlete_app/models/sign_up_data.dart';
import 'package:athlete_app/screens/feed/compose_post_screen.dart';
import 'package:athlete_app/screens/feed/huddle_screen.dart';
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
    ..topics.addAll({Topic.training, Topic.mindset});
  if (role == UserRole.athlete) {
    profile
      ..sport = 'Swimming'
      ..level = CompetitionLevel.club;
  }
  return Account(
    // Test athletes are verified unless a test says otherwise.
    verified: role == UserRole.athlete,
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
    Services.events = InMemoryEventsRepository();
    Services.verification = FakeVerificationRepository(profiles);
  });

  group('FeedRules', () {
    test('general public members can only ask questions', () {
      expect(FeedRules.postTypesFor(_account('p', role: UserRole.public)), [
        PostType.question,
      ]);
      expect(FeedRules.postTypesFor(_account('a')), PostType.values);
    });

    test('old topics are read as the new categories', () {
      expect(Topic.fromStored('injury'), Topic.training);
      expect(Topic.fromStored('nutrition'), Topic.training);
      expect(Topic.fromStored('competition'), Topic.gameDay);
      expect(Topic.fromStored('mindset'), Topic.mindset);
      expect(Topic.fromStored('nonsense'), isNull);
      expect(
        Topic.training.storedNames,
        unorderedEquals(['training', 'injury', 'nutrition']),
      );
    });

    test('only questions carry the advice banner', () async {
      final spotlight = await _post(_account('a'));
      final question = await _post(_account('a'), type: PostType.question);
      expect(spotlight.needsAdviceBanner, isFalse);
      expect(question.needsAdviceBanner, isTrue);
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

  testWidgets('Huddle splits spotlights and questions', (tester) async {
    final me = _account('me');
    // New questions wait for a moderator; these were approved.
    feed.publish(
      await _post(
        _account('a', name: 'Alex Tan'),
        type: PostType.question,
        text: 'How do you taper before a meet?',
      ),
    );
    feed.publish(
      await _post(
        _account('a', name: 'Alex Tan'),
        type: PostType.question,
        text: 'Favourite warm-up song?',
      ),
    );
    await _post(_account('b', name: 'Bea Lim'));

    await _pump(tester, HuddleScreen(account: me, onCompose: (_) {}));
    // Spotlight first: only the spotlight.
    expect(find.text('Bea Lim'), findsOneWidget);
    expect(find.text('How do you taper before a meet?'), findsNothing);
    expect(find.text('Share a spotlight'), findsOneWidget);

    await tester.tap(find.text('Ask an athlete'));
    await tester.pumpAndSettle();
    expect(find.text('Needs an answer'), findsOneWidget);
    expect(find.text('How do you taper before a meet?'), findsOneWidget);
    expect(find.text('Bea Lim'), findsNothing);
    expect(find.text('Ask a question'), findsOneWidget);
  });

  testWidgets('category chips narrow Huddle', (tester) async {
    await _post(_account('a'), text: 'Hill sprints!');
    await _post(_account('a'), topic: Topic.gameDay, text: 'My medal day.');
    await _pump(
      tester,
      HuddleScreen(account: _account('me'), onCompose: (_) {}),
    );
    expect(find.text('Hill sprints!'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, '🏆 Game day'));
    await tester.pumpAndSettle();
    expect(find.text('Hill sprints!'), findsNothing);
    expect(find.text('My medal day.'), findsOneWidget);
  });

  testWidgets('pull to refresh shows new posts', (tester) async {
    await _pump(
      tester,
      HuddleScreen(account: _account('me'), onCompose: (_) {}),
    );
    expect(
      find.text('No spotlights yet. Be the first to share.'),
      findsOneWidget,
    );

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

    await _pump(
      tester,
      HuddleScreen(account: _account('me'), onCompose: (_) {}),
    );

    expect(find.text('Anonymous athlete'), findsOneWidget);
    expect(find.text('Alex Tan'), findsNothing);
    expect(find.text('Swimming · Club'), findsNothing);
  });

  testWidgets('questions show the not-professional-advice banner', (
    tester,
  ) async {
    final post = await _post(
      _account('a'),
      type: PostType.question,
      text: 'How do you calm nerves before a final?',
    );
    await _pump(tester, PostDetailScreen(post: post, viewer: _account('me')));
    expect(find.textContaining("It isn't professional advice"), findsOneWidget);
  });

  testWidgets('composing a post adds it to the feed', (tester) async {
    final me = _account('me');
    await _pump(tester, HomeShell(account: me, isNewAccount: false));

    // Events is the home tab; spotlights are shared from Huddle, starting
    // at the camera. Tests have no camera, so switch to a text post.
    expect(find.text('Events'), findsWidgets);
    await tester.tap(find.text('Huddle'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share a spotlight'));
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

    await tester.tap(find.text('Training wins'));
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

  testWidgets('public members can only ask', (tester) async {
    await _pump(
      tester,
      ComposePostScreen(account: _account('p', role: UserRole.public)),
    );
    expect(find.text('Share a spotlight'), findsNothing);
    expect(find.textContaining('Question from the public'), findsOneWidget);
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
