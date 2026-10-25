import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lwotowone_mobile/screens/home.dart';
import 'package:lwotowone_mobile/screens/learner_profile.dart';
import 'package:lwotowone_mobile/screens/login.dart';
import 'package:lwotowone_mobile/screens/policy_reader.dart';
import 'package:lwotowone_mobile/services/repository.dart';

Future<void> openSection(WidgetTester tester, String section) async {
  await tester.tap(find.byTooltip('Open navigation menu'));
  await tester.pumpAndSettle();
  final link = find.descendant(
    of: find.byType(Drawer),
    matching: find.text(section),
  );
  await tester.scrollUntilVisible(
    link,
    120,
    scrollable: find.descendant(
      of: find.byType(Drawer),
      matching: find.byType(Scrollable),
    ),
  );
  await Scrollable.ensureVisible(tester.element(link), alignment: 0.5);
  await tester.pumpAndSettle();
  await tester.tap(link);
  await tester.pumpAndSettle();
}

Future<void> readToEnd(WidgetTester tester) async {
  await tester.drag(
    find.descendant(
      of: find.byType(PolicyReader),
      matching: find.byType(SingleChildScrollView),
    ),
    const Offset(0, -20000),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, 'I have read this'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Policy reader unlocks only after scrolling to the end', (
    tester,
  ) async {
    bool? accepted;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => accepted = await showPolicyReader(
              context,
              title: 'Terms of use',
              body: List.filled(80, 'A long line of terms text.').join('\n\n'),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final accept = find.widgetWithText(FilledButton, 'I have read this');
    expect(tester.widget<FilledButton>(accept).onPressed, isNull);
    expect(find.text('Scroll to the end to continue.'), findsOneWidget);

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -20000),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(accept).onPressed, isNotNull);
    await tester.tap(accept);
    await tester.pumpAndSettle();
    expect(accepted, isTrue);
  });

  testWidgets('Signup asks for both policies before agreeing', (tester) async {
    final repo = Repository(baseUrl: 'https://learning.test/api');
    await tester.pumpWidget(MaterialApp(home: Login(repo: repo)));
    await tester.tap(find.text('New here? Create an account'));
    await tester.pumpAndSettle();
    expect(find.text('Not read yet'), findsNWidgets(2));

    final consent = find.byType(CheckboxListTile);
    await tester.ensureVisible(consent);
    await tester.tap(consent);
    await tester.pumpAndSettle();
    // Terms opens first; offline, the built-in copy is shown.
    expect(find.text('Terms of use'), findsWidgets);
    expect(find.byType(PolicyReader), findsOneWidget);
    await readToEnd(tester);
    expect(find.text('Privacy notice'), findsWidgets);
    expect(find.byType(PolicyReader), findsOneWidget);
    await readToEnd(tester);

    expect(find.byType(PolicyReader), findsNothing);
    expect(find.text('Read'), findsNWidgets(2));
    expect(tester.widget<CheckboxListTile>(consent).value, isTrue);
    repo.dispose();
  });

  testWidgets('Incomplete profiles lock learning and show progress', (
    tester,
  ) async {
    final repo = Repository(baseUrl: 'https://learning.test/api');
    repo.data = {
      'user': {
        'id': 1,
        'name': 'Learner',
        'phone': '+256700000001',
        'profile_complete': false,
      },
      'access': {
        'free_access': true,
        'profile_complete': false,
        'profile_percent': 20,
        'profile_missing': ['Course choice', 'Gender'],
      },
      'courses': [
        {'id': 3, 'title': 'Solar repair'},
      ],
      'settlements': [
        {'id': 9, 'name': 'Bidibidi'},
      ],
    };
    await tester.pumpWidget(MaterialApp(home: Home(repo: repo)));
    await tester.pumpAndSettle();
    expect(
      find.text('Complete your profile to unlock learning'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Still needed: Course choice, Gender'),
      findsOneWidget,
    );
    expect(find.textContaining('Free access:'), findsOneWidget);

    await openSection(tester, 'Learn');
    expect(
      find.text('This section opens once your learner profile is complete.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Complete my profile'));
    await tester.pumpAndSettle();
    expect(find.byType(LearnerProfile), findsOneWidget);
    expect(find.text('18%'), findsOneWidget);
    final locationField = find.widgetWithText(
      TextFormField,
      'Location (village, town or city)',
    );
    await tester.scrollUntilVisible(
      locationField,
      200,
      scrollable: find
          .descendant(
            of: find.byType(LearnerProfile),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Location (village, town or city)'),
      'Gulu',
    );
    await tester.pumpAndSettle();
    // The progress card sits at the top of the form.
    await tester.drag(
      find
          .descendant(
            of: find.byType(LearnerProfile),
            matching: find.byType(Scrollable),
          )
          .first,
      const Offset(0, 3000),
    );
    await tester.pumpAndSettle();
    expect(find.text('27%'), findsOneWidget);
    repo.dispose();
  });

  testWidgets('Events show their fee once free access ends', (tester) async {
    final repo = Repository(baseUrl: 'https://learning.test/api');
    repo.data = {
      'user': {'id': 1, 'name': 'Learner', 'profile_complete': true},
      'events': [
        {
          'id': 1,
          'title': 'Paid fair',
          'starts_at': '2026-11-01 09:00',
          'location': 'Arua',
          'description': 'Market day',
          'payment_amount': '5000.00',
          'fee_due': true,
          'currency': 'UGX',
          'registration_open': true,
        },
        {
          'id': 2,
          'title': 'Open day',
          'starts_at': '2026-11-02 09:00',
          'location': 'Gulu',
          'description': 'Welcome',
          'payment_amount': null,
          'registration_open': true,
        },
      ],
    };
    await tester.pumpWidget(MaterialApp(home: Home(repo: repo)));
    await tester.pumpAndSettle();
    await openSection(tester, 'Events');
    expect(find.textContaining('Fee: 5000.00 UGX'), findsOneWidget);
    expect(find.textContaining('\nFree\n'), findsOneWidget);
    repo.dispose();
  });

  testWidgets('Profile always opens the full learner profile form', (
    tester,
  ) async {
    final repo = Repository(baseUrl: 'https://learning.test/api');
    // Snapshot from a server without profile progress data.
    repo.data = {
      'user': {'id': 1, 'name': 'Learner', 'email': 'learner@example.test'},
    };
    await tester.pumpWidget(MaterialApp(home: Home(repo: repo)));
    await tester.pumpAndSettle();
    await openSection(tester, 'Profile');
    await tester.tap(find.text('Edit learner profile'));
    await tester.pumpAndSettle();
    expect(find.byType(LearnerProfile), findsOneWidget);
    expect(find.text('Add or change photo'), findsOneWidget);
    for (final label in [
      'Course selection',
      'Gender',
      'Urban or rural',
      'Are you a refugee?',
      'Do you have a disability?',
      'Education level',
      'Are you currently employed?',
    ]) {
      await tester.scrollUntilVisible(
        find.text(label),
        200,
        scrollable: find
            .descendant(
              of: find.byType(LearnerProfile),
              matching: find.byType(Scrollable),
            )
            .last,
      );
      expect(find.text(label), findsOneWidget, reason: label);
    }
    repo.dispose();
  });
}
