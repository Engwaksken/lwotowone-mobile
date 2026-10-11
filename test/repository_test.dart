import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lwotowone_mobile/services/repository.dart';

void main() {
  test('Registration handles email-verification response without a token', () async {
    final repo = Repository(
      baseUrl: 'https://learning.test/api',
      client: MockClient((request) async {
        expect(request.url.path, '/api/register');
        return http.Response(
          jsonEncode({'message': 'Check your email to verify your account.'}),
          201,
        );
      }),
    );

    final message = await repo.authenticate({
      'name': 'New Learner',
      'email': 'learner@example.test',
      'password': 'A-long-test-password',
    }, register: true);

    expect(message, 'Check your email to verify your account.');
    expect(repo.token, isNull);
    repo.dispose();
  });

  test(
    'API sends bearer credentials and exposes validation feedback',
    () async {
      final repo = Repository(
        baseUrl: 'https://learning.test/api',
        client: MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer secret');
          return http.Response(
            jsonEncode({
              'message': 'Invalid',
              'errors': {
                'amount': ['Amount must be positive.'],
              },
            }),
            422,
          );
        }),
      );
      repo.token = 'secret';
      await expectLater(
        repo.request('POST', '/actions/income', {'amount': -1}),
        throwsA(
          isA<ApiFailure>().having(
            (e) => e.message,
            'message',
            'Amount must be positive.',
          ),
        ),
      );
      repo.dispose();
    },
  );
  test('Unexpected server response becomes a usable error', () async {
    final repo = Repository(
      baseUrl: 'https://learning.test/api',
      client: MockClient((_) async => http.Response('<html>Error</html>', 502)),
    );
    await expectLater(
      repo.request('GET', '/snapshot'),
      throwsA(isA<ApiFailure>()),
    );
    repo.dispose();
  });
}
