import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lwotowone_mobile/screens/activities.dart';
import 'package:lwotowone_mobile/screens/home.dart';
import 'package:lwotowone_mobile/services/repository.dart';

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Map<String, dynamic> account() => {
  'user': {
    'id': 1,
    'name': 'Akello Grace',
    'email': 'learner@example.test',
    'profile_complete': true,
  },
  'courses': [
    {
      'id': 1,
      'title': 'Poultry basics',
      'level': 'Beginner',
      'duration_hours': 4,
      'summary': 'Learn poultry care',
    },
    {
      'id': 2,
      'title': 'Crop farming',
      'level': 'Beginner',
      'duration_hours': 5,
      'summary': 'Learn crop production',
    },
  ],
  'enrolments': [
    {'course_id': 1},
  ],
  'lessons': [
    {
      'id': 10,
      'course_id': 1,
      'title': 'Housing',
      'position': 1,
      'sort_order': 0,
      'locked': false,
    },
    {
      'id': 11,
      'course_id': 1,
      'title': 'Feeding',
      'position': 2,
      'sort_order': 1,
      'locked': true,
    },
  ],
  'lesson_progress': [
    {'lesson_id': 10},
  ],
  'enrollment_requests': [],
  'download_requests': [],
};

void main() {
  testWidgets('Five tabs open on a phone without layout errors', (
    tester,
  ) async {
    phone(tester);
    final repo = Repository(baseUrl: 'https://learning.test/api');
    repo.data = account();
    await tester.pumpWidget(MaterialApp(home: Home(repo: repo)));
    await tester.pumpAndSettle();

    expect(find.text('Akello'), findsOneWidget);
    expect(find.text('CONTINUE LEARNING'), findsOneWidget);
    expect(find.text('Poultry basics'), findsOneWidget);
    expect(find.text('1 of 2 lessons · 50%'), findsOneWidget);
    // Stat tiles sit two per row on a phone.
    expect(
      tester.getTopLeft(find.text('Lessons done')).dy,
      tester.getTopLeft(find.text('My courses')).dy,
    );
    expect(
      tester.getTopLeft(find.text('Certificates')).dy,
      greaterThan(tester.getTopLeft(find.text('My courses')).dy),
    );

    for (final (label, title) in [
      ('Courses', 'My courses'),
      ('Activities', 'Activities'),
      ('Inbox', 'Inbox'),
      ('Profile', 'Profile'),
    ]) {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text(title)),
        findsOneWidget,
        reason: label,
      );
      expect(tester.takeException(), isNull, reason: label);
    }
    repo.dispose();
  });

  testWidgets('Every activity opens with an empty account', (tester) async {
    phone(tester);
    final repo = Repository(baseUrl: 'https://learning.test/api');
    repo.data = {
      'user': {'id': 1, 'name': 'Learner', 'profile_complete': true},
    };
    await tester.pumpWidget(MaterialApp(home: Home(repo: repo)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Activities').last);
    await tester.pumpAndSettle();
    for (final section in activitySections.keys.where(
      (s) => s != 'Knowledge game',
    )) {
      await tester.scrollUntilVisible(
        find.text(section).last,
        100,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text(section).last);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text(section)),
        findsOneWidget,
        reason: section,
      );
      expect(tester.takeException(), isNull, reason: section);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
    repo.dispose();
  });

  testWidgets('Learners search courses and ask to join another course', (
    tester,
  ) async {
    phone(tester);
    final posted = <Map<String, dynamic>>[];
    final repo = Repository(
      baseUrl: 'https://learning.test/api',
      client: MockClient((request) async {
        if (request.url.path == '/api/enrollment-requests') {
          posted.add(
            Map<String, dynamic>.from(jsonDecode(request.body) as Map),
          );
          return http.Response(jsonEncode({'message': 'sent'}), 201);
        }
        final data = account();
        data['enrollment_requests'] = [
          for (final row in posted)
            {
              'course_id': row['course_id'],
              'status': 'pending',
              'message': row['message'],
            },
        ];
        return http.Response(jsonEncode(data), 200);
      }),
    );
    repo.data = account();
    repo.token = 'token';
    await tester.pumpWidget(MaterialApp(home: Home(repo: repo)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Courses').last);
    await tester.pumpAndSettle();

    expect(find.text('Poultry basics'), findsOneWidget);
    expect(find.text('Crop farming'), findsNothing);
    await tester.tap(find.text('Browse'));
    await tester.pumpAndSettle();
    expect(find.text('Crop farming'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'poultry');
    await tester.pumpAndSettle();
    expect(find.text('Crop farming'), findsNothing);
    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Request to join'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'I keep goats too');
    await tester.tap(find.text('Send request'));
    await tester.pumpAndSettle();

    expect(posted, [
      {'course_id': 2, 'message': 'I keep goats too'},
    ]);
    expect(find.text('Request pending · waiting for review'), findsOneWidget);
    expect(tester.takeException(), isNull);
    repo.dispose();
  });
}
