import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lwotowone_mobile/services/repository.dart';
import 'package:lwotowone_mobile/screens/home.dart';

void main() {
  testWidgets('Search opens from the toolbar icon and filters the section', (
    tester,
  ) async {
    final repo = Repository(baseUrl: 'https://learning.test/api');
    repo.data = {
      'user': {'id': 1, 'name': 'Learner'},
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
      'enrolments': [],
      'lesson_progress': [],
    };
    await tester.pumpWidget(MaterialApp(home: Home(repo: repo)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Learn').last);
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'poultry');
    await tester.pumpAndSettle();
    expect(find.text('Poultry basics'), findsOneWidget);
    expect(find.text('Crop farming'), findsNothing);

    await tester.tap(find.byTooltip('Close search'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Crop farming'), findsOneWidget);
    expect(tester.takeException(), isNull);
    repo.dispose();
  });

  testWidgets(
    'Every participant section renders with an empty downloaded account',
    (tester) async {
      final repo = Repository(baseUrl: 'https://learning.test/api');
      repo.data = {
        'user': {'id': 1, 'name': 'Learner', 'email': 'learner@example.test'},
      };
      await tester.pumpWidget(MaterialApp(home: Home(repo: repo)));
      await tester.pumpAndSettle();
      for (final section in [
        'Learn',
        'Practice',
        'Mentorship',
        'Opportunities',
        'Enterprise',
        'Events',
        'Notifications',
        'Pending',
        'Profile',
      ]) {
        await tester.tap(find.byTooltip('Open navigation menu'));
        await tester.pumpAndSettle();
        final link = find.descendant(
          of: find.byType(Drawer),
          matching: find.text(section == 'Pending' ? 'Pending (0)' : section),
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
        expect(tester.takeException(), isNull, reason: section);
        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.text(section),
          ),
          findsOneWidget,
          reason: section,
        );
      }
      repo.dispose();
    },
  );
}
