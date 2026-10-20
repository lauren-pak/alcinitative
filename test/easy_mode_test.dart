import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:athlete_app/main.dart';
import 'package:athlete_app/models/account.dart';
import 'package:athlete_app/models/display_mode.dart';
import 'package:athlete_app/models/post.dart';
import 'package:athlete_app/models/sign_up_data.dart';
import 'package:athlete_app/screens/easy/easy_compose_screen.dart';
import 'package:athlete_app/screens/easy/easy_post_screen.dart';
import 'package:athlete_app/screens/home_shell.dart';
import 'package:athlete_app/screens/profile/profile_screen.dart';
import 'package:athlete_app/screens/sign_up/profile_step.dart';
import 'package:athlete_app/services/services.dart';

import 'fakes.dart';

late InMemoryFeedRepository feed;
late InMemoryProfileRepository profiles;

Account _account(String uid,
    {int age = 25, DisplayMode mode = DisplayMode.easy}) {
  final now = DateTime.now();
  return Account(
    uid: uid,
    athleteId: 'AA-$uid',
    joinedAt: now,
    profile: SignUpData()
      ..role = UserRole.athlete
      ..method = SignUpMethod.email
      ..name = 'Sam Taylor'
      ..dateOfBirth = DateTime(now.year - age, 1, 1)
      ..sport = 'Bowling'
      ..level = CompetitionLevel.club
      ..category = AthleteCategory.specialOlympics
      ..topics.add(Topic.training)
      ..displayMode = mode,
  );
}

Future<void> _pump(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(MaterialApp(home: screen));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    final auth = FakeAuthService();
    feed = InMemoryFeedRepository();
    profiles = InMemoryProfileRepository(auth);
    Services.auth = auth;
    Services.profiles = profiles;
    Services.feed = feed;
    Services.media = FakeMediaRepository();
    displayMode.value = DisplayMode.standard;
  });

  testWidgets('Easy mode switch on the intro page enlarges text',
      (tester) async {
    await tester.pumpWidget(const AthleteApp());
    await tester.pumpAndSettle();
    double scale() => MediaQuery.textScalerOf(
            tester.element(find.text('Welcome to Athlete App')))
        .scale(10) /
        10;
    expect(scale(), 1.0);

    await tester.tap(find.text('Easy mode'));
    await tester.pumpAndSettle();
    expect(displayMode.value, DisplayMode.easy);
    expect(scale(), greaterThanOrEqualTo(1.3));
  });

  testWidgets('choosing Special Olympics switches Easy mode on',
      (tester) async {
    final data = SignUpData()
      ..role = UserRole.athlete
      ..sport = 'Bowling'
      ..level = CompetitionLevel.club;
    await _pump(tester, Scaffold(body: ProfileStep(data: data, onContinue: () {})));

    final chip = find.text('Special Olympics athlete');
    await tester.ensureVisible(chip);
    await tester.tap(chip);
    await tester.pumpAndSettle();

    expect(data.displayMode, DisplayMode.easy);
    expect(displayMode.value, DisplayMode.easy);
  });

  testWidgets('Easy home shows Home · Post · Me and big topic pictures',
      (tester) async {
    await _pump(tester, HomeShell(account: _account('me'), isNewAccount: false));

    for (final label in ['Home', 'Post', 'Me', 'What do you want to see?',
        'Injuries', 'Training', 'Food', 'Competing']) {
      expect(find.text(label), findsWidgets, reason: label);
    }
    expect(find.text('I need help'), findsOneWidget);
  });

  testWidgets('Easy posting guide: topic, share or ask, write, check',
      (tester) async {
    Post? created;
    await _pump(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () async => created = await Navigator.of(context)
                  .push<Post>(MaterialPageRoute(
                      builder: (_) => EasyComposeScreen(account: _account('me')))),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Step 1 of 4'), findsOneWidget);
    expect(find.text('What is your post about?'), findsOneWidget);
    await tester.tap(find.text('Training'));
    await tester.pump();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('What do you want to do?'), findsOneWidget);
    await tester.tap(find.text('Ask a question'));
    await tester.pump();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Topic and share-or-ask come first; then the camera opens, video first.
    expect(find.text('No camera found on this device.'), findsOneWidget);
    expect(
      tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Video')).selected,
      isTrue,
    );
    // Closing the camera goes back to the share-or-ask question.
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('What do you want to do?'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Text'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Just use words'));
    await tester.pumpAndSettle();

    expect(find.text('Write your question'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'How do I warm up?');
    await tester.pump();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Is this right?'), findsOneWidget);
    expect(find.text('How do I warm up?'), findsOneWidget);
    await tester.tap(find.text('Post it'));
    await tester.pumpAndSettle();

    expect(created?.text, 'How do I warm up?');
    expect(created?.type, PostType.question);
    expect(created?.topic, Topic.training);
    expect(created?.anonymous, isFalse);
  });

  testWidgets('Easy posting keeps under-18s out of Food for now',
      (tester) async {
    await _pump(tester, EasyComposeScreen(account: _account('t', age: 15)));
    expect(find.textContaining('Posts about food from under-18s'),
        findsOneWidget);
    await tester.tap(find.text('Food'));
    await tester.pump();
    final next = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Next'));
    expect(next.onPressed, isNull);
  });

  testWidgets('Easy post page: Me too and replying', (tester) async {
    final post = await feed.createPost(
      _account('a'),
      NewPost()
        ..topic = Topic.injury
        ..text = 'My knee hurt after bowling.',
    );
    await _pump(tester, EasyPostScreen(post: post, viewer: _account('me')));

    expect(find.textContaining("It is not advice from a doctor"), findsOneWidget);
    await tester.tap(find.text('👋 Me too · 0'));
    await tester.pumpAndSettle();
    expect(find.text('👋 Me too · 1'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Rest and ice helped me.');
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    expect(find.text('Rest and ice helped me.'), findsOneWidget);
  });

  testWidgets('Easy post page explains when you cannot reply', (tester) async {
    final teenPost = await feed.createPost(
      _account('t', age: 15),
      NewPost()
        ..topic = Topic.training
        ..text = 'My first match.',
    );
    await _pump(tester, EasyPostScreen(post: teenPost, viewer: _account('adult')));
    expect(find.text('Only under-18s can reply to this post.'), findsOneWidget);
    expect(find.text('Send'), findsNothing);
  });

  testWidgets('profile switch saves the view to the account', (tester) async {
    final user = await Services.auth.signUpWithEmail('s@example.com', 'password1');
    final account = await profiles.create(
        user.uid, _account(user.uid, mode: DisplayMode.standard).profile);

    await _pump(tester, ProfileScreen(account: account, isNewAccount: false));
    await tester.tap(find.text('Easy'));
    await tester.pumpAndSettle();

    expect(displayMode.value, DisplayMode.easy);
    expect((await profiles.load(user.uid))!.profile.displayMode,
        DisplayMode.easy);
  });
}
