import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lwotowone_mobile/services/repository.dart';
import 'package:lwotowone_mobile/screens/home.dart';

void main() {
  testWidgets(
    'Every participant section renders with an empty downloaded account',
    (tester) async {
      final repo = Repository();
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
