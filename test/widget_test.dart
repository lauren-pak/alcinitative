import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:athlete_app/main.dart';
import 'package:athlete_app/models/sign_up_data.dart';
import 'package:athlete_app/screens/sign_up/profile_step.dart';

/// Opens the app and goes from the intro page to the method step as an athlete.
Future<void> _goToMethodStep(WidgetTester tester) async {
  await tester.pumpWidget(const AthleteApp());
  await _tapVisible(tester, 'Get started');
  await tester.pumpAndSettle();
  await tester.tap(find.text('Athlete'));
  await tester.pumpAndSettle();
}

Future<void> _tapVisible(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.tap(find.text(text));
  await tester.pump();
}

void main() {
  group('ageOn', () {
    test('counts the birthday as reached on the day itself', () {
      expect(ageOn(DateTime(2010, 6, 15), DateTime(2028, 6, 15)), 18);
    });

    test('does not count a birthday later in the year', () {
      expect(ageOn(DateTime(2010, 6, 15), DateTime(2028, 6, 14)), 17);
    });
  });

  test('SignUpData.isMinorOn flags members under 18', () {
    final data = SignUpData()..dateOfBirth = DateTime(2010, 6, 15);
    expect(data.isMinorOn(DateTime(2028, 6, 14)), isTrue);
    expect(data.isMinorOn(DateTime(2028, 6, 15)), isFalse);
  });

  testWidgets('intro page leads to role choice, then sign-up method',
      (tester) async {
    await tester.pumpWidget(const AthleteApp());
    expect(find.text('Welcome to Athlete App'), findsOneWidget);

    await _tapVisible(tester, 'Get started');
    await tester.pumpAndSettle();
    expect(find.text('Step 1 of 4'), findsOneWidget);

    await tester.tap(find.text('Athlete'));
    await tester.pumpAndSettle();
    expect(find.text('How do you want to sign up?'), findsOneWidget);
  });

  testWidgets('email sign-up validates email and password', (tester) async {
    await _goToMethodStep(tester);

    await _tapVisible(tester, 'Continue with email');
    await _tapVisible(tester, 'Continue');

    expect(find.text('Enter a valid email address'), findsOneWidget);
    expect(find.text('Use at least 8 characters'), findsOneWidget);
  });

  testWidgets('phone sign-up needs a Singapore number, then a 6-digit code',
      (tester) async {
    await _goToMethodStep(tester);
    await _tapVisible(tester, 'Continue with phone number');

    await tester.enterText(find.byType(TextFormField), '1234');
    await _tapVisible(tester, 'Send code');
    expect(find.text('Enter an 8-digit Singapore number'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), '9123 4567');
    await _tapVisible(tester, 'Send code');
    expect(find.text('6-digit code'), findsOneWidget);

    await _tapVisible(tester, 'Verify');
    expect(find.text('Enter the 6-digit code'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).last, '123456');
    await _tapVisible(tester, 'Verify');
    await tester.pumpAndSettle();
    expect(find.text('About you'), findsOneWidget);
  });

  testWidgets('about step requires name and date of birth', (tester) async {
    await _goToMethodStep(tester);
    await _tapVisible(tester, 'Continue with Google');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();

    await _tapVisible(tester, 'Continue');
    expect(find.text('Enter your name'), findsOneWidget);
    expect(find.text('Enter your date of birth'), findsOneWidget);
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
    expect(finished, isFalse);

    await tester.tap(find.text('Injury'));
    await tester.tap(find.text('Create account'));
    await tester.pump();
    expect(finished, isTrue);
  });

  testWidgets('athlete programme is optional and can be unselected',
      (tester) async {
    var finished = false;
    final data = SignUpData()
      ..role = UserRole.athlete
      ..sport = 'Bocce'
      ..level = CompetitionLevel.club
      ..topics.add(Topic.training);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProfileStep(data: data, onContinue: () => finished = true),
      ),
    ));

    await _tapVisible(tester, 'Special Olympics athlete');
    expect(data.category, AthleteCategory.specialOlympics);
    await _tapVisible(tester, 'Special Olympics athlete');
    expect(data.category, isNull);

    await _tapVisible(tester, 'Create account');
    expect(finished, isTrue);
  });
}
