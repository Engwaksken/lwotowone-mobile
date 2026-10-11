import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lwotowone_mobile/services/repository.dart';
import 'package:lwotowone_mobile/screens/course.dart';
import 'package:lwotowone_mobile/screens/home.dart';

class TestRepository extends Repository {
  TestRepository() : super(baseUrl: 'https://learning.test/api');
  final actions = <String>[];
  @override
  Future<void> sync() async {}
  @override
  Future<void> act(
    String action,
    Map<String, dynamic> payload, {
    bool offlineAllowed = false,
  }) async {
    actions.add(action);
    if (action == 'cancel-event') {
      final r =
          (data['event_registrations'] as List).first as Map<String, dynamic>;
      expect(payload['registration_id'], r['id']);
      r['status'] = 'cancelled';
      r['can_cancel'] = false;
      notifyListeners();
    }
  }
}

void main() {
  testWidgets('Downloaded course shows progress and gates certificate access', (
    tester,
  ) async {
    final repo = TestRepository();
    repo.data = {
      'lessons': [
        {
          'id': 1,
          'course_id': 1,
          'position': 1,
          'title': 'Practical lesson',
          'body': 'Practise safely.',
        },
      ],
    };
    await tester.pumpWidget(
      MaterialApp(
        home: CourseScreen(
          repo: repo,
          course: const {
            'id': 1,
            'title': 'Poultry skills',
            'summary': 'Learn practically',
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Lesson progress: 0%'), findsOneWidget);
    expect(find.text('Practise safely.'), findsOneWidget);
    final certificate = find.widgetWithText(
      OutlinedButton,
      'Completion certificate (web sign-in required)',
    );
    expect(tester.widget<OutlinedButton>(certificate).onPressed, isNull);
    repo.data['lesson_progress'] = [
      {'lesson_id': 1},
    ];
    repo.notifyListeners();
    await tester.pumpAndSettle();
    expect(find.text('Lesson progress: 100%'), findsOneWidget);
    expect(find.text('Completion certificate ready'), findsOneWidget);
    expect(tester.widget<OutlinedButton>(certificate).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    repo.dispose();
  });
  testWidgets(
    'Event cancellation requires confirmation and enables re-registration',
    (tester) async {
      final repo = TestRepository();
      repo.data = {
        'user': {'name': 'Learner'},
        'events': [
          {
            'id': 1,
            'title': 'Skills day',
            'starts_at': '2026-10-10',
            'location': 'Kampala',
            'description': 'Practise together',
          },
        ],
        'event_registrations': [
          {
            'id': 9,
            'event_id': 1,
            'event_title': 'Skills day',
            'status': 'registered',
            'can_cancel': true,
          },
        ],
      };
      await tester.pumpWidget(MaterialApp(home: Home(repo: repo)));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      final link = find.descendant(
        of: find.byType(Drawer),
        matching: find.text('Events'),
      );
      await tester.scrollUntilVisible(
        link,
        120,
        scrollable: find.descendant(
          of: find.byType(Drawer),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.tap(link);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel registration'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep registration'));
      await tester.pumpAndSettle();
      expect(repo.actions, isEmpty);
      await tester.tap(find.text('Cancel registration'));
      await tester.pumpAndSettle();
      final confirm = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Cancel registration'),
      );
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(repo.actions, ['cancel-event']);
      expect(find.text('Register again (online)'), findsOneWidget);
      expect(find.text('Registration: cancelled'), findsOneWidget);
      (repo.data['events'] as List).first['registration_open'] = false;
      repo.notifyListeners();
      await tester.pumpAndSettle();
      expect(find.text('Registration is closed.'), findsOneWidget);
      expect(find.text('Register again (online)'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      repo.dispose();
    },
  );
}
