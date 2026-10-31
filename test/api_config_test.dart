import 'package:flutter_test/flutter_test.dart';
import 'package:lwotowone_mobile/services/api_config.dart';
import 'package:lwotowone_mobile/services/repository.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;

void main() {
  test('official API address is the default app connection', () {
    expect(ApiConfig.base, 'https://www.lwotowone.com/api');
    expect(ApiConfig.validate(ApiConfig.base), isNull);
  });
  test(
    'API build configuration rejects placeholders and credential-bearing addresses',
    () {
      for (final url in [
        'https://example.com/api',
        'https://YOUR-DOMAIN/api',
        'http://learning.test/api',
        'https://learning.test',
        'https://user:password@learning.test/api',
        'https://learning.test/api?token=x',
        'https://learning.test/api#x',
      ]) {
        expect(ApiConfig.validate(url), isNotNull, reason: url);
      }
      expect(ApiConfig.validate('https://learning.test/api'), isNull);
    },
  );
  test('Unconfigured app never sends a network request', () async {
    var calls = 0;
    final repo = Repository(
      baseUrl: 'https://example.com/api',
      client: MockClient((r) async {
        calls++;
        return http.Response('{}', 200);
      }),
    );
    await expectLater(
      repo.request('POST', '/login', {
        'email': 'test@example.test',
        'password': 'test',
      }),
      throwsA(isA<ApiFailure>()),
    );
    expect(calls, 0);
    repo.dispose();
  });
}
