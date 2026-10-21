import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:athlete_app/models/account.dart';
import 'package:athlete_app/models/moderation.dart';
import 'package:athlete_app/models/post.dart';
import 'package:athlete_app/models/sign_up_data.dart';
import 'package:athlete_app/screens/easy/easy_post_screen.dart';
import 'package:athlete_app/screens/feed/compose_post_screen.dart';
import 'package:athlete_app/screens/feed/edit_post_screen.dart';
import 'package:athlete_app/screens/feed/post_detail_screen.dart';
import 'package:athlete_app/screens/feed/tag_search_screen.dart';
import 'package:athlete_app/screens/find_athlete_screen.dart';
import 'package:athlete_app/screens/profile/safety_settings_screen.dart';
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
    athleteId: 'AA-${uid.toUpperCase()}',
    profile: profile,
    joinedAt: now,
  );
}

Future<Post> _post(
  Account author, {
  String text = 'Rehab week three, knee feels stronger.',
  List<String> tags = const [],
  Topic topic = Topic.injury,
}) => feed.createPost(
  author,
  NewPost()
    ..topic = topic
    ..text = text
    ..replyPolicy = ReplyPolicy.everyone
    ..tags = [...tags],
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
    auth = FakeAuthService();
    profiles = InMemoryProfileRepository(auth);
    feed = InMemoryFeedRepository();
    final safety = FakeSafetyRepository(feed);
    Services.auth = auth;
    Services.profiles = profiles;
    Services.feed = feed;
    Services.media = FakeMediaRepository();
    Services.safety = safety;
    Services.moderation = FakeModerationRepository(feed, safety);
  });

  group('tags', () {
    test('are cleaned to lowercase letters and numbers', () {
      expect(normaliseTag('#ACL'), 'acl');
      expect(normaliseTag('Half-Marathon!'), 'halfmarathon');
      expect(normaliseTag('#'), isNull);
      expect(normaliseTag('a'), isNull);
      expect(normaliseTag('x' * 30), hasLength(20));
    });

    test('find visible posts only', () async {
      final me = _account('a');
      await _post(me, tags: ['acl']);
      await _post(me, text: 'I want to stop eating', tags: ['acl']);
      await _post(me, tags: ['marathon']);
      final found = await feed.withTag('acl');
      expect(found, hasLength(1));
      expect(found.single.isHeld, isFalse);
    });

    test('with flagged words hold the post', () async {
      final post = await _post(_account('a'), tags: ['weight', 'purging']);
      expect(post.holdReason, HoldReason.flaggedWords);
    });

    testWidgets('can be added in the composer', (tester) async {
      Post? created;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  created = await Navigator.of(context).push<Post>(
                    MaterialPageRoute(
                      builder: (_) => ComposePostScreen(account: _account('a')),
                    ),
                  ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Training'));
      await tester.enterText(
        find.byType(TextField).first,
        'Long swim set this morning.',
      );
      final tagField = find.widgetWithText(TextField, 'Tags (optional)');
      await tester.enterText(tagField, '#Swimming ');
      await tester.pump();
      await tester.enterText(tagField, 'endurance');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(find.text('#swimming'), findsOneWidget);
      expect(find.text('#endurance'), findsOneWidget);
      await tester.ensureVisible(find.text('Post'));
      await tester.tap(find.text('Post'));
      await tester.pumpAndSettle();
      expect(created?.tags, ['swimming', 'endurance']);
    });

    testWidgets('tapping a tag searches for it', (tester) async {
      final post = await _post(_account('a'), tags: ['acl']);
      await _post(_account('b'), text: 'Another ACL story', tags: ['acl']);
      await _pump(tester, PostDetailScreen(post: post, viewer: _account('me')));
      await tester.tap(find.text('#acl'));
      await tester.pumpAndSettle();
      expect(find.byType(TagSearchScreen), findsOneWidget);
      expect(find.text('Another ACL story'), findsOneWidget);
    });
  });

  group('editing and deleting', () {
    test('only the author can edit; edits are marked', () async {
      final post = await _post(_account('a'));
      final edited = await feed.editPost(
        _account('a'),
        post,
        text: 'Week four now.',
        tags: ['rehab'],
      );
      expect(edited.text, 'Week four now.');
      expect(edited.tags, ['rehab']);
      expect(edited.editedAt, isNotNull);
      expect(
        () => feed.editPost(_account('b'), post, text: 'Hacked', tags: []),
        throwsStateError,
      );
    });

    test('adding flagged words sends the post back for review', () async {
      final post = await _post(_account('a'));
      final edited = await feed.editPost(
        _account('a'),
        post,
        text: 'Honestly I keep skipping meals',
        tags: [],
      );
      expect(edited.isHeld, isTrue);
      expect(await feed.latest({Topic.injury}), isEmpty);
    });

    testWidgets('edit from the post menu', (tester) async {
      final post = await _post(_account('a'));
      await _pump(tester, PostDetailScreen(post: post, viewer: _account('a')));
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit post'));
      await tester.pumpAndSettle();
      expect(find.byType(EditPostScreen), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'Updated text.');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Updated text.'), findsOneWidget);
      expect(find.textContaining('edited'), findsOneWidget);
    });

    testWidgets('delete from the post menu', (tester) async {
      final post = await _post(_account('a'));
      await _pump(tester, PostDetailScreen(post: post, viewer: _account('a')));
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete post'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(feed.posts, isEmpty);
    });

    testWidgets("others don't get edit or delete", (tester) async {
      final post = await _post(_account('a'));
      await _pump(tester, PostDetailScreen(post: post, viewer: _account('b')));
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      expect(find.text('Edit post'), findsNothing);
      expect(find.text('Report post'), findsOneWidget);
    });

    testWidgets('Easy mode: change and delete my post', (tester) async {
      final post = await _post(_account('a'));
      await _pump(tester, EasyPostScreen(post: post, viewer: _account('a')));
      expect(find.text('✏️ Change my post'), findsOneWidget);
      await tester.tap(find.text('🗑️ Delete my post'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(feed.posts, isEmpty);
    });
  });

  testWidgets('Easy mode: answer with a post', (tester) async {
    final post = await _post(_account('a', name: 'Alex Lee'));
    await _pump(tester, EasyPostScreen(post: post, viewer: _account('me')));
    await tester.ensureVisible(find.text('Answer with a video or post'));
    await tester.tap(find.text('Answer with a video or post'));
    await tester.pumpAndSettle();
    // The camera opens first; close it to answer with words only.
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('💬 You are answering Alex Lee'), findsOneWidget);
    await tester.enterText(
      find.byType(TextField),
      'Keep going, it gets better!',
    );
    await tester.pump();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    // Skip tags.
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Post it'));
    await tester.pumpAndSettle();

    final response = feed.posts.last;
    expect(response.respondsToId, post.id);
    expect(response.topic, Topic.injury);
    expect(find.textContaining('Your post is up'), findsOneWidget);
  });

  group('find athlete by name', () {
    Future<Account> member(
      String uid,
      String name, {
      int age = 25,
      bool findable = true,
    }) async {
      final a = _account(uid, name: name, age: age);
      a.profile.findable = findable;
      profiles.accounts[uid] = a;
      return a;
    }

    test('only finds adult athletes who opted in', () async {
      await member('a', 'Sam Taylor');
      await member('b', 'Sam Lim', findable: false);
      await member('c', 'Samantha Ng', age: 15);
      final found = await profiles.searchByName('sam');
      expect([for (final a in found) a.profile.name], ['Sam Taylor']);
      expect(await profiles.searchByName('tay'), hasLength(1));
      expect(await profiles.searchByName('sam ng'), isEmpty);
    });

    test('browse by sport and programme, adults who show up only', () async {
      final a = await member('a', 'Sam Taylor');
      a.profile.category = AthleteCategory.national;
      (await member('b', 'Ann Lim')).profile.sport = 'Badminton';
      await member('c', 'Kid Tan', age: 15);
      await member('d', 'Hidden Ho', findable: false);
      final swimmers = await profiles.browse(sport: 'Swimming');
      expect([for (final x in swimmers) x.profile.name], ['Sam Taylor']);
      final national = await profiles.browse(
        category: AthleteCategory.national,
      );
      expect(national.single.profile.name, 'Sam Taylor');
      expect(await profiles.browse(), hasLength(2));
    });

    testWidgets('Browse shows athletes', (tester) async {
      await member('a', 'Sam Taylor');
      await _pump(tester, const FindAthleteScreen());
      await tester.tap(find.text('Show athletes'));
      await tester.pumpAndSettle();
      expect(find.text('Sam Taylor'), findsOneWidget);
    });

    test('search keys are prefixes of each name word', () {
      expect(
        nameSearchKeys('Sam Taylor'),
        containsAll(['s', 'sa', 'sam', 't', 'tay', 'taylor']),
      );
      expect(matchesName('Sam Taylor', ['sa', 'tay']), isTrue);
      expect(matchesName('Sam Taylor', ['tom']), isFalse);
    });

    testWidgets('searches by name in Find athlete', (tester) async {
      await member('a', 'Sam Taylor');
      await _pump(tester, const FindAthleteScreen());
      await tester.tap(find.text('Name'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Sam');
      await tester.tap(find.text('Find'));
      await tester.pumpAndSettle();
      expect(find.text('Sam Taylor'), findsOneWidget);
    });

    testWidgets('under-18s cannot turn on name search', (tester) async {
      await _pump(
        tester,
        SafetySettingsScreen(account: _account('t', age: 15)),
      );
      final toggle = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, 'Show me in Find athlete'),
      );
      expect(toggle.onChanged, isNull);
      expect(find.textContaining("Under-18s can't be found"), findsOneWidget);
    });
  });
}
