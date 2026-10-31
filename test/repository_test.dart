import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lwotowone_mobile/services/repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Profile edits are saved locally even if an incomplete profile cannot sync',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'lwotowone-profile-',
      );
      FlutterSecureStorage.setMockInitialValues({
        'token': 'profile-token',
        'owner': '4',
      });
      final repo = Repository(
        baseUrl: 'https://learning.test/api',
        client: MockClient((request) async {
          if (request.url.path == '/api/profile') {
            expect(jsonDecode(request.body), {
              'name': 'Updated Learner',
              'phone': '+256700000001',
              'district': 'Kampala',
            });
            return http.Response('{"ok":true}', 200);
          }
          return http.Response(
            '{"message":"Complete your profile first."}',
            403,
          );
        }),
      );
      await repo.init(storageDirectory: directory);
      repo.data = {
        'user': {'id': 4, 'name': 'Learner', 'email': 'learner@example.test'},
      };

      await repo.profile({
        'name': 'Updated Learner',
        'phone': '+256700000001',
        'district': 'Kampala',
      });

      expect(repo.data['user'], {
        'id': 4,
        'name': 'Updated Learner',
        'email': 'learner@example.test',
        'phone': '+256700000001',
        'district': 'Kampala',
      });
      repo.dispose();
      final restored = Repository(baseUrl: 'https://learning.test/api');
      await restored.init(storageDirectory: directory);
      expect(restored.data['user'], repo.data['user']);
      restored.dispose();
      await directory.delete(recursive: true);
    },
  );

  test(
    'Registration handles email-verification response without a token',
    () async {
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
    },
  );

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

  test(
    'Synchronisation does not download large videos automatically',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'lwotowone-video-sync-',
      );
      final paths = <String>[];
      final repo = Repository(
        baseUrl: 'https://learning.test/api',
        client: MockClient((request) async {
          paths.add(request.url.path);
          return http.Response(
            jsonEncode({
              'lessons': [
                {
                  'id': 17,
                  'locked': false,
                  'media_type': 'video',
                  'download_url':
                      'https://learning.test/api/lessons/17/download',
                },
              ],
              'resources': [],
            }),
            200,
          );
        }),
      );
      await repo.init(storageDirectory: directory);
      repo.token = 'video-token';
      repo.owner = 'learner-1';

      await repo.sync();

      expect(paths, ['/api/snapshot']);
      expect(repo.hasSavedFile('lessons', '17'), isFalse);
      repo.dispose();
      await directory.delete(recursive: true);
    },
  );
}
