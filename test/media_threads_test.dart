import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:athlete_app/models/account.dart';
import 'package:athlete_app/models/media.dart';
import 'package:athlete_app/models/moderation.dart';
import 'package:athlete_app/models/post.dart';
import 'package:athlete_app/models/sign_up_data.dart';
import 'package:athlete_app/screens/feed/capture_screen.dart';
import 'package:athlete_app/screens/feed/compose_post_screen.dart';
import 'package:athlete_app/screens/feed/huddle_screen.dart';
import 'package:athlete_app/screens/feed/post_detail_screen.dart';
import 'package:athlete_app/screens/profile/profile_screen.dart';
import 'package:athlete_app/services/media_prep.dart';
import 'package:athlete_app/services/services.dart';

import 'fakes.dart';

late InMemoryFeedRepository feed;
late FakeMediaRepository media;

Account _account(String uid, {String name = 'Sam Taylor', int age = 25}) {
  final now = DateTime.now();
  return Account(
    // Test athletes are verified unless a test says otherwise.
    verified: true,
    uid: uid,
    athleteId: 'AA-$uid',
    joinedAt: now,
    profile: SignUpData()
      ..role = UserRole.athlete
      ..method = SignUpMethod.email
      ..name = name
      ..dateOfBirth = DateTime(now.year - age, 1, 1)
      ..sport = 'Swimming'
      ..level = CompetitionLevel.club
      ..topics.add(Topic.training),
  );
}

Future<Post> _post(
  Account author, {
  String text = 'Tapering for my first national meet.',
  bool anonymous = false,
  Journey? journey,
  List<MediaItem> withMedia = const [],
}) {
  return feed.createPost(
    author,
    NewPost()
      ..type = PostType.question
      ..topic = Topic.training
      ..text = text
      ..anonymous = anonymous
      ..journey = journey
      ..media = withMedia,
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

/// A JPEG carrying GPS coordinates, like one straight off a phone camera.
Uint8List _photoWithLocation({int width = 3000, int height = 2000}) {
  final image = img.Image(width: width, height: height);
  image.exif.gpsIfd['GPSLatitude'] = img.IfdValueRational(1, 1);
  image.exif.gpsIfd['GPSLatitudeRef'] = img.IfdValueAscii('N');
  image.exif.imageIfd['Make'] = img.IfdValueAscii('PhoneCo');
  return img.encodeJpg(image);
}

void main() {
  late FakeSafetyRepository safety;
  setUp(() {
    final auth = FakeAuthService();
    feed = InMemoryFeedRepository();
    media = FakeMediaRepository();
    Services.auth = auth;
    Services.profiles = InMemoryProfileRepository(auth);
    Services.feed = feed;
    safety = FakeSafetyRepository(feed);
    Services.safety = safety;
    Services.moderation = FakeModerationRepository(feed, safety);
    Services.media = media;
    Services.events = InMemoryEventsRepository();
    Services.verification = FakeVerificationRepository(
      Services.profiles as InMemoryProfileRepository,
    );
  });

  group('cleanPhoto', () {
    test('removes GPS and camera metadata', () {
      final original = _photoWithLocation(width: 400, height: 300);
      // The test photo really does carry a location to start with.
      expect(img.decodeJpgExif(original)!.gpsIfd.isEmpty, isFalse);

      final cleaned = cleanPhoto(original);
      final exif = img.decodeJpgExif(Uint8List.fromList(cleaned.jpeg));
      expect(exif == null || exif.gpsIfd.isEmpty, isTrue);
      expect(exif == null || exif.imageIfd['Make'] == null, isTrue);
    });

    test('shrinks large photos to at most 1600px on the long side', () {
      final cleaned = cleanPhoto(_photoWithLocation());
      expect(cleaned.width, 1600);
      expect(cleaned.height, closeTo(1067, 1));
    });
  });

  test('under-18 videos wait for a moderator', () {
    expect(FeedRules.videoReviewNoteFor(_account('t', age: 15)), isNotNull);
    expect(FeedRules.videoReviewNoteFor(_account('a')), isNull);
    final draft = NewPost()
      ..topic = Topic.training
      ..text = 'Watch my start'
      ..media = [
        const MediaItem(id: 'v', kind: MediaKind.video, width: 1, height: 1),
      ];
    expect(
      FeedRules.holdReasonFor(_account('t', age: 15), draft),
      HoldReason.minorVideo,
    );
    expect(FeedRules.holdReasonFor(_account('a'), draft), isNull);
  });

  testWidgets('photos show on feed cards', (tester) async {
    final photo = cleanPhoto(_photoWithLocation(width: 200, height: 100));
    final item = await media.uploadPhoto(_account('a'), photo);
    feed.publish(await _post(_account('a'), withMedia: [item]));

    await _pump(
      tester,
      HuddleScreen(account: _account('me'), onCompose: (_) {}),
    );
    // The helper posts questions, so they're under "Ask an athlete".
    await tester.tap(find.text('Ask an athlete'));
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsWidgets);
  });

  testWidgets('replies can be replied to, shown nested', (tester) async {
    final asker = _account('asker', name: 'Asha Rao');
    final question = await _post(asker);
    final first = await feed.addReply(
      _account('ben', name: 'Ben Ong'),
      question,
      'Sleep well the week before.',
    );

    await _pump(
      tester,
      PostDetailScreen(post: question, viewer: _account('cai')),
    );
    await tester.tap(find.widgetWithText(TextButton, 'Reply'));
    await tester.pumpAndSettle();
    expect(find.text('Replying to Ben Ong'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'How many hours?');
    await tester.tap(find.byTooltip('Send reply'));
    await tester.pumpAndSettle();

    final replies = await feed.replies(question.id);
    expect(replies.last.parentReplyId, first.id);
    // The nested reply sits to the right of its parent.
    final parentX = tester
        .getTopLeft(find.text('Sleep well the week before.'))
        .dx;
    final childX = tester.getTopLeft(find.text('How many hours?')).dx;
    expect(childX, greaterThan(parentX));
  });

  testWidgets("adults can't reply to an under-18's reply", (tester) async {
    final post = await _post(_account('a'));
    final teenReply = await feed.addReply(
      _account('t', age: 15),
      post,
      'I tried that too.',
    );
    expect(
      FeedRules.replyBlockedFor(_account('adult'), post, parent: teenReply),
      'Only under-18s can reply to this reply.',
    );

    await _pump(
      tester,
      PostDetailScreen(post: post, viewer: _account('adult')),
    );
    expect(find.widgetWithText(TextButton, 'Reply'), findsNothing);
  });

  testWidgets('a response post shows in the original comments thread', (
    tester,
  ) async {
    final original = await _post(
      _account('a', name: 'Alex Tan'),
      text: 'What does your taper week look like?',
    );
    final me = _account('me');

    await _pump(tester, PostDetailScreen(post: original, viewer: me));
    await tester.tap(find.text('Respond with a post'));
    await tester.pumpAndSettle();
    expect(find.text('Responding to a post'), findsOneWidget); // camera
    await tester.tap(find.text('Text'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Write a post'));
    await tester.pumpAndSettle();
    expect(find.text('Respond with a post'), findsOneWidget); // composer title
    expect(find.textContaining('In response to'), findsOneWidget);

    await tester.enterText(
      find.byType(TextField).first,
      'Here is my full taper plan with the sets I swim.',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Post'));
    await tester.pumpAndSettle();

    expect(find.text('Response post'), findsOneWidget);
    expect(
      find.text('Here is my full taper plan with the sets I swim.'),
      findsOneWidget,
    );
    expect((await feed.getPost(original.id))!.responseCount, 1);
  });

  testWidgets('response posts show "In response to" in the feed', (
    tester,
  ) async {
    final original = await _post(_account('a'), text: 'Original question here');
    await feed.createPost(
      _account('b'),
      NewPost()
        ..topic = Topic.training
        ..text = 'My answer as a whole post.'
        ..respondingTo = original,
    );

    await _pump(
      tester,
      HuddleScreen(account: _account('me'), onCompose: (_) {}),
    );
    expect(
      find.textContaining('In response to: "Original question here"'),
      findsOneWidget,
    );
  });

  testWidgets('profile lists my posts, including anonymous ones', (
    tester,
  ) async {
    final me = _account('me');
    await _post(me, text: 'My named post about pacing.');
    await _post(me, text: 'My anonymous post about nerves.', anonymous: true);
    await _post(_account('other'), text: 'Not mine.');

    await _pump(tester, ProfileScreen(account: me, isNewAccount: false));
    expect(find.text('My named post about pacing.'), findsOneWidget);
    expect(find.text('My anonymous post about nerves.'), findsOneWidget);
    expect(
      find.byTooltip('Posted anonymously. Only you can see it is yours.'),
      findsOneWidget,
    );
    expect(find.text('Not mine.'), findsNothing);
  });

  testWidgets('journeys tab opens a journey with its posts in order', (
    tester,
  ) async {
    final me = _account('me');
    final journey = await feed.createJourney(me, 'ACL rehab 2026');
    feed.publish(
      await _post(me, text: 'Week 1: surgery went well.', journey: journey),
    );
    feed.publish(
      await _post(me, text: 'Week 2: first physio session.', journey: journey),
    );

    await _pump(tester, ProfileScreen(account: me, isNewAccount: false));
    // Journeys are story highlights on the profile.
    await tester.tap(find.text('ACL rehab 2026'));
    await tester.pumpAndSettle();

    expect(find.text('Chapter 1'), findsOneWidget);
    expect(find.text('Chapter 2'), findsOneWidget);
    final week1 = tester.getTopLeft(find.text('Week 1: surgery went well.')).dy;
    final week2 = tester
        .getTopLeft(find.text('Week 2: first physio session.'))
        .dy;
    expect(week1, lessThan(week2));
  });

  testWidgets('composer offers photos and video, with limits explained', (
    tester,
  ) async {
    await _pump(tester, ComposePostScreen(account: _account('a')));
    expect(find.text('Add photos'), findsOneWidget);
    expect(find.text('Add video'), findsOneWidget);
    expect(find.textContaining('Location data is removed'), findsOneWidget);

    await _pump(tester, ComposePostScreen(account: _account('t', age: 15)));
    expect(find.textContaining('Videos from under-18s'), findsOneWidget);
  });

  group('camera screen', () {
    ChoiceChip chip(WidgetTester tester, String label) =>
        tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label));

    testWidgets('opens in Video mode, with Photo and Text available', (
      tester,
    ) async {
      await _pump(tester, CaptureScreen(account: _account('a')));
      expect(chip(tester, 'Video').selected, isTrue);
      expect(chip(tester, 'Photo').onSelected, isNotNull);
      expect(chip(tester, 'Text').onSelected, isNotNull);
      // No camera in tests (or on the simulator): Library and Text still work.
      expect(find.text('No camera found on this device.'), findsOneWidget);
      expect(find.text('Library'), findsOneWidget);
    });

    testWidgets('under-18s can record video, with a review note', (
      tester,
    ) async {
      await _pump(tester, CaptureScreen(account: _account('t', age: 15)));
      expect(chip(tester, 'Video').selected, isTrue);
      expect(find.textContaining('Videos from under-18s'), findsOneWidget);
    });

    testWidgets('Text mode opens the composer without media', (tester) async {
      await _pump(tester, CaptureScreen(account: _account('a')));
      await tester.tap(find.text('Text'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Write a post'));
      await tester.pumpAndSettle();
      expect(find.text('New post'), findsOneWidget);
      expect(find.text('Your spotlight'), findsOneWidget);
    });
  });

  testWidgets('a photo post only needs a short caption', (tester) async {
    final photo = cleanPhoto(_photoWithLocation(width: 300, height: 200));
    await _pump(
      tester,
      Builder(
        builder: (context) => FilledButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ComposePostScreen(
                account: _account('a'),
                initialPhotos: [photo],
              ),
            ),
          ),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Caption'), findsOneWidget);
    await tester.tap(find.text('Training wins'));
    await tester.enterText(find.byType(TextField).first, 'PB!');
    await tester.tap(find.widgetWithText(FilledButton, 'Post'));
    await tester.pumpAndSettle();

    final post = feed.posts.single;
    expect(post.text, 'PB!');
    expect(post.media.single.kind, MediaKind.photo);
  });
}
