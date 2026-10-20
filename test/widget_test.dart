import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:athlete_app/main.dart';
import 'package:athlete_app/models/account.dart';
import 'package:athlete_app/models/sign_up_data.dart';
import 'package:athlete_app/screens/profile/profile_screen.dart';
import 'package:athlete_app/screens/sign_up/profile_step.dart';
import 'package:athlete_app/screens/your_data_screen.dart';
import 'package:athlete_app/services/auth_service.dart';
import 'package:athlete_app/services/services.dart';

import 'fakes.dart';

late FakeAuthService auth;
late InMemoryProfileRepository profiles;

Future<void> _tapVisible(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.tap(find.text(text));
  await tester.pump();
}

Future<void> _tapButton(WidgetTester tester, String text) async {
  final button = find.widgetWithText(FilledButton, text);
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

/// Intro → consent → Athlete → the sign-up method step.
Future<void> _goToMethodStep(WidgetTester tester) async {
  await tester.pumpWidget(const AthleteApp());
  await _tapVisible(tester, 'Get started');
  await tester.pumpAndSettle();
  await tester.tap(find.byType(Checkbox));
  await tester.pump();
  await tester.tap(find.text('Athlete'));
  await tester.pumpAndSettle();
}

Future<void> _signUpWithEmail(WidgetTester tester, String email) async {
  await _tapVisible(tester, 'Continue with email');
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), email);
  await tester.enterText(fields.at(1), 'password123');
  await _tapButton(tester, 'Continue');
}

SignUpData _profile({int age = 25, UserRole role = UserRole.athlete}) {
  final now = DateTime.now();
  return SignUpData()
    ..role = role
    ..method = SignUpMethod.email
    ..name = 'Sam Taylor'
    ..dateOfBirth = DateTime(now.year - age, 1, 1)
    ..sport = 'Swimming'
    ..level = CompetitionLevel.club
    ..topics.add(Topic.training)
    ..consentGivenAt = now;
}

void main() {
  setUp(() {
    auth = FakeAuthService();
    profiles = InMemoryProfileRepository(auth);
    Services.auth = auth;
    Services.profiles = profiles;
    Services.feed = InMemoryFeedRepository();
    Services.media = FakeMediaRepository();
  });

  group('age rules', () {
    test('ageOn counts the birthday on the day itself', () {
      expect(ageOn(DateTime(2010, 6, 15), DateTime(2028, 6, 15)), 18);
      expect(ageOn(DateTime(2010, 6, 15), DateTime(2028, 6, 14)), 17);
    });

    test('isMinorOn flags members under 18', () {
      final data = SignUpData()..dateOfBirth = DateTime(2010, 6, 15);
      expect(data.isMinorOn(DateTime(2028, 6, 14)), isTrue);
      expect(data.isMinorOn(DateTime(2028, 6, 15)), isFalse);
    });

    test('adultFromBirthDate is the 18th birthday', () {
      expect(
          adultFromBirthDate(DateTime(2010, 6, 15)), DateTime.utc(2028, 6, 15));
      // Leap-day birthdays turn 18 on 1 March.
      expect(
          adultFromBirthDate(DateTime(2008, 2, 29)), DateTime.utc(2026, 3, 1));
    });
  });

  group('athlete IDs', () {
    test('are readable and use no look-alike characters', () {
      for (var i = 0; i < 50; i++) {
        expect(newAthleteId(), matches(RegExp(r'^AA-[A-HJ-NP-Z2-9]{6}$')));
      }
    });

    test('typed IDs are normalised', () {
      for (final input in ['aa-7kq2mx', '7KQ2MX', 'AA 7KQ2MX', ' aa7kq2mx ']) {
        expect(normaliseAthleteId(input), 'AA-7KQ2MX');
      }
    });
  });

  testWidgets('roles stay disabled until the Privacy Notice is agreed',
      (tester) async {
    await tester.pumpWidget(const AthleteApp());
    expect(find.text('Welcome to Athlete App'), findsOneWidget);
    await _tapVisible(tester, 'Get started');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Athlete'));
    await tester.pumpAndSettle();
    expect(find.text('Step 1 of 4'), findsOneWidget);

    await _tapVisible(tester, 'Read the Privacy Notice');
    await tester.pumpAndSettle();
    expect(find.text('How we look after your information'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.text('Athlete'));
    await tester.pumpAndSettle();
    expect(find.text('How do you want to sign up?'), findsOneWidget);
  });

  testWidgets('email sign-up validates, then reports a taken email',
      (tester) async {
    await auth.signUpWithEmail('taken@example.com', 'password123');
    await auth.signOut();
    await _goToMethodStep(tester);

    await _tapVisible(tester, 'Continue with email');
    await _tapButton(tester, 'Continue');
    expect(find.text('Enter a valid email address'), findsOneWidget);
    expect(find.text('Use at least 8 characters'), findsOneWidget);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'taken@example.com');
    await tester.enterText(fields.at(1), 'password123');
    await _tapButton(tester, 'Continue');
    expect(
      find.text('This email already has an account. Log in instead.'),
      findsOneWidget,
    );
  });

  testWidgets('phone sign-up checks the number, then the code',
      (tester) async {
    await _goToMethodStep(tester);
    await _tapVisible(tester, 'Continue with phone number');

    await tester.enterText(find.byType(TextFormField), '1234');
    await _tapButton(tester, 'Send code');
    expect(find.text('Enter an 8-digit Singapore number'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), '9123 4567');
    await _tapButton(tester, 'Send code');
    expect(find.text('We texted a code to +65 91234567.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).last, '000000');
    await _tapButton(tester, 'Verify');
    expect(find.text("That code isn't right. Try again."), findsOneWidget);

    await tester.enterText(
        find.byType(TextFormField).last, FakeAuthService.validCode);
    await _tapButton(tester, 'Verify');
    expect(find.text('About you'), findsOneWidget);
    expect(auth.currentUser?.phone, '+6591234567');
  });

  testWidgets('Google explains when it is not set up', (tester) async {
    await _goToMethodStep(tester);
    await _tapVisible(tester, 'Continue with Google');
    await tester.pumpAndSettle();

    expect(
        find.textContaining("isn't set up for this app yet"), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('How do you want to sign up?'), findsOneWidget);
  });

  testWidgets('Google sign-up pre-fills the name', (tester) async {
    auth.googleUser = const AuthUser(
      uid: 'g1',
      method: SignUpMethod.google,
      email: 'sam@gmail.com',
      displayName: 'Sam Google',
    );
    await _goToMethodStep(tester);
    await _tapVisible(tester, 'Continue with Google');
    await tester.pumpAndSettle();

    expect(find.text('About you'), findsOneWidget);
    expect(find.text('Sam Google'), findsOneWidget);
  });

  testWidgets('about step requires name and date of birth', (tester) async {
    await _goToMethodStep(tester);
    await _signUpWithEmail(tester, 'new@example.com');
    expect(find.text('About you'), findsOneWidget);

    await _tapButton(tester, 'Continue');
    expect(find.text('Enter your name'), findsOneWidget);
    expect(find.text('Enter your date of birth'), findsOneWidget);
  });

  testWidgets('going back past the method step deletes the new sign-in',
      (tester) async {
    await _goToMethodStep(tester);
    await _signUpWithEmail(tester, 'leaving@example.com');
    expect(auth.currentUser, isNotNull);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('How do you want to sign up?'), findsOneWidget);
    expect(auth.deletedUsers, 1);
    expect(auth.currentUser, isNull);
  });

  testWidgets('public members only pick topics', (tester) async {
    var finished = false;
    final data = SignUpData()..role = UserRole.public;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProfileStep(data: data, onContinue: () => finished = true),
      ),
    ));

    expect(find.text('Sport'), findsNothing);
    expect(find.text('Athlete programme'), findsNothing);

    await tester.tap(find.text('Create account'));
    await tester.pump();
    expect(find.text('Pick at least one topic'), findsOneWidget);

    await tester.tap(find.text('Injury'));
    await tester.tap(find.text('Create account'));
    await tester.pump();
    expect(finished, isTrue);
  });

  testWidgets('athlete programme is optional; "Other" needs a sport name',
      (tester) async {
    var finished = false;
    final data = SignUpData()
      ..role = UserRole.athlete
      ..sport = otherSport
      ..level = CompetitionLevel.club
      ..topics.add(Topic.training);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProfileStep(data: data, onContinue: () => finished = true),
      ),
    ));

    // The "Name of your sport" box takes focus and scrolls the page, so let
    // that finish between taps.
    await _tapVisible(tester, 'Special Olympics athlete');
    await tester.pumpAndSettle();
    expect(data.category, AthleteCategory.specialOlympics);
    await _tapVisible(tester, 'Special Olympics athlete');
    await tester.pumpAndSettle();
    expect(data.category, isNull);

    await _tapVisible(tester, 'Create account');
    expect(find.text('Type the name of your sport'), findsOneWidget);
    expect(finished, isFalse);

    await tester.enterText(find.byType(TextFormField).last, 'Fencing');
    await _tapVisible(tester, 'Create account');
    expect(finished, isTrue);
    expect(data.sportName, 'Fencing');
  });

  testWidgets('log in by email opens the account', (tester) async {
    final user = await auth.signUpWithEmail('sam@example.com', 'password123');
    final account = await profiles.create(user.uid, _profile());
    await auth.signOut();

    await tester.pumpWidget(const AthleteApp());
    await _tapVisible(tester, 'I already have an account');
    await tester.pumpAndSettle();
    await _tapVisible(tester, 'Continue with email');
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'sam@example.com');
    await tester.enterText(fields.at(1), 'wrong-password');
    await _tapButton(tester, 'Log in');
    expect(find.text('Email or password is incorrect'), findsOneWidget);

    await tester.enterText(fields.at(1), 'password123');
    await _tapButton(tester, 'Log in');
    // Returning members land on the feed; their ID is one tab away.
    expect(find.text('Needs an answer'), findsNothing);
    expect(find.text('No posts yet. Be the first to share.'), findsOneWidget);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Sam Taylor'), findsOneWidget);
    expect(find.text(account.athleteId), findsOneWidget);
  });

  testWidgets('a sign-in with no profile resumes sign-up', (tester) async {
    await auth.signUpWithEmail('unfinished@example.com', 'password123');

    await tester.pumpWidget(const AthleteApp());
    await tester.pumpAndSettle();
    expect(find.text('Finish signing up · 1 of 3'), findsOneWidget);
  });

  testWidgets('profile shows the ID card without date of birth',
      (tester) async {
    final account = await profiles.create(
      'u1',
      _profile()
        ..dateOfBirth = DateTime(1998, 3, 15)
        ..category = AthleteCategory.specialOlympics,
    );

    await tester.pumpWidget(MaterialApp(
      home: ProfileScreen(account: account, isNewAccount: true),
    ));

    expect(find.text('Welcome, Sam!'), findsOneWidget);
    expect(find.text('ATHLETE ID'), findsOneWidget);
    expect(find.text(account.athleteId), findsOneWidget);
    expect(find.text('Swimming · Club'), findsOneWidget);
    expect(find.text('Special Olympics athlete'), findsOneWidget);
    expect(find.textContaining('1998'), findsNothing);
  });

  group('Your data & privacy', () {
    Future<Account> pumpYourData(WidgetTester tester) async {
      final user = await auth.signUpWithEmail('sam@example.com', 'password123');
      final account = await profiles.create(
          user.uid, _profile()..dateOfBirth = DateTime(1998, 3, 15));
      await tester.pumpWidget(MaterialApp(
        home: YourDataScreen(account: account),
      ));
      return account;
    }

    testWidgets('shows the member everything stored, including birth date',
        (tester) async {
      final account = await pumpYourData(tester);
      expect(find.text('03/15/1998'), findsOneWidget);
      expect(find.text(account.athleteId), findsOneWidget);
      expect(find.text('Email · sam@example.com'), findsOneWidget);
    });

    testWidgets('deleting removes the profile and the sign-in',
        (tester) async {
      await pumpYourData(tester);
      await _tapVisible(tester, 'Delete my account');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      // A progress spinner stays behind the message, so don't wait to settle.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Account deleted'), findsOneWidget);
      expect(profiles.accounts, isEmpty);
      expect(auth.deletedUsers, 1);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome to Athlete App'), findsOneWidget);
    });

    testWidgets('deleting needs a recent log-in and deletes nothing otherwise',
        (tester) async {
      auth.recentSignIn = false;
      await pumpYourData(tester);
      await _tapVisible(tester, 'Delete my account');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Please log in again'), findsOneWidget);
      expect(profiles.accounts, hasLength(1));
      expect(auth.deletedUsers, 0);
    });
  });

  test('adults cannot look up an under-18 athlete ID', () async {
    final teen = await profiles.create('teen', _profile(age: 15));
    await profiles.create('otherTeen', _profile(age: 16));
    final adult = await profiles.create('adult', _profile(age: 30));

    auth.googleUser = const AuthUser(uid: 'adult', method: SignUpMethod.google);
    await auth.signInWithGoogle();
    expect(await profiles.findById(teen.athleteId), isNull);
    expect(await profiles.findById(adult.athleteId), adult);

    auth.googleUser =
        const AuthUser(uid: 'otherTeen', method: SignUpMethod.google);
    await auth.signInWithGoogle();
    expect(await profiles.findById(teen.athleteId), teen);
  });
}
