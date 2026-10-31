import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lwotowone_mobile/screens/activities.dart';
import 'package:lwotowone_mobile/screens/content.dart';
import 'package:lwotowone_mobile/screens/course.dart';
import 'package:lwotowone_mobile/services/repository.dart';

class TestRepository extends Repository {
  TestRepository() : super(baseUrl: 'https://learning.test/api');
  final actions = <String>[];
  final downloadRequests = <String>[];
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
    if (action == 'complete') {
      data['lesson_progress'] = [
        {'lesson_id': payload['lesson_id']},
      ];
      notifyListeners();
    }
  }

  @override
  Future<void> requestDownload(String type, Object? id, String? message) async {
    downloadRequests.add('$type-$id-$message');
    data['download_requests'] = [
      {'item_type': type, 'item_id': id, 'state': 'pending'},
    ];
    notifyListeners();
  }
}

void main() {
  testWidgets(
    'Course shows progress, opens lessons and gates the certificate',
    (tester) async {
      final repo = TestRepository();
      repo.data = {
        'lessons': [
          {
            'id': 1,
            'course_id': 1,
            'position': 1,
            'title': 'Practical lesson',
            'body': 'Practise safely.',
            'module_title': 'Getting started',
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
      expect(find.text('0%'), findsOneWidget);
      expect(find.text('Getting started'), findsOneWidget);
      expect(find.text('Up next'), findsOneWidget);

      await tester.tap(find.text('Practical lesson'));
      await tester.pumpAndSettle();
      expect(find.text('Practise safely.'), findsOneWidget);
      expect(find.text('Lesson 1 of 1 · Getting started'), findsOneWidget);
      await tester.tap(find.text('Mark lesson complete'));
      await tester.pumpAndSettle();
      expect(repo.actions, ['complete']);
      expect(find.text('Completed'), findsWidgets);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('100%'), findsOneWidget);

      await tester.tap(find.text('Assignments'));
      await tester.pumpAndSettle();
      final certificate = find.widgetWithText(
        OutlinedButton,
        'Completion certificate (web sign-in required)',
      );
      expect(tester.widget<OutlinedButton>(certificate).onPressed, isNotNull);
      repo.data['lesson_progress'] = [];
      repo.notifyListeners();
      await tester.pumpAndSettle();
      expect(tester.widget<OutlinedButton>(certificate).onPressed, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      repo.dispose();
    },
  );

  testWidgets('Lessons offer a download request and show its approval', (
    tester,
  ) async {
    final repo = TestRepository();
    repo.data = {
      'download_policy': {'valid_days': 7, 'max_downloads': 3},
      'lessons': [
        {
          'id': 5,
          'course_id': 1,
          'title': 'Video lesson',
          'body': 'Watch first.',
          'media_type': 'video',
          'content_source': 'upload',
          'downloadable': true,
          'download_url': 'https://learning.test/api/lessons/5/download',
        },
      ],
    };
    await tester.pumpWidget(
      MaterialApp(
        home: ContentScreen(repo: repo, type: 'lessons', id: 5),
      ),
    );
    await tester.pumpAndSettle();
    // The player waits for the learner, so opening the lesson uses no data.
    expect(find.text('Play video'), findsOneWidget);
    await tester.ensureVisible(find.text('Request download'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Request download'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Weak network at home');
    await tester.tap(find.text('Send request'));
    await tester.pumpAndSettle();
    expect(repo.downloadRequests, ['lessons-5-Weak network at home']);
    expect(
      find.text('Download requested · waiting for approval'),
      findsOneWidget,
    );

    repo.data['download_requests'] = [
      {
        'id': 3,
        'item_type': 'lessons',
        'item_id': 5,
        'state': 'approved',
        'downloads_left': 3,
        'expires_at': '2026-11-08T10:00:00Z',
        'download_url': 'https://learning.test/api/downloads/3',
      },
    ];
    repo.notifyListeners();
    await tester.pumpAndSettle();
    expect(find.text('Save in the app'), findsOneWidget);
    expect(find.textContaining('3 of 3 left until 8 Nov 2026'), findsOneWidget);

    repo.data['download_requests'] = [
      {
        'item_type': 'lessons',
        'item_id': 5,
        'state': 'rejected',
        'decision_note': 'Watch it online',
      },
    ];
    repo.notifyListeners();
    await tester.pumpAndSettle();
    expect(find.textContaining('Watch it online'), findsOneWidget);
    expect(find.text('Request download again'), findsOneWidget);
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
      await tester.pumpWidget(
        MaterialApp(
          home: ActivityScreen(repo: repo, section: 'Events'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel registration').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep registration'));
      await tester.pumpAndSettle();
      expect(repo.actions, isEmpty);
      await tester.tap(find.text('Cancel registration').first);
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
