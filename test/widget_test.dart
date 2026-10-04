import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lwotowone_mobile/services/repository.dart';
import 'package:lwotowone_mobile/screens/login.dart';

void main() {
  testWidgets('Participant login validates empty email and password', (
    tester,
  ) async {
    final repo = Repository();
    await tester.pumpWidget(MaterialApp(home: Login(repo: repo)));
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();
    expect(find.text('Enter your email address'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
    repo.dispose();
  });
}
