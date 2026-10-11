import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lwotowone_mobile/services/repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Sync caches authorized lesson and resource files for offline use',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'lwotowone-content-',
      );
      FlutterSecureStorage.setMockInitialValues({
        'token': 'paid-token',
        'owner': '12',
      });
      final requestedDownloads = <String>[];
      final repo = Repository(
        baseUrl: 'https://learning.test/api',
        client: MockClient((request) async {
          if (request.url.path == '/api/snapshot') {
            return http.Response(
              jsonEncode({
                'lessons': [
                  {
                    'id': 2,
                    'locked': false,
                    'download_url':
                        'https://learning.test/api/lessons/2/download',
                  },
                  {
                    'id': 3,
                    'locked': true,
                    'download_url':
                        'https://learning.test/api/lessons/3/download',
                  },
                ],
                'resources': [
                  {
                    'id': 7,
                    'locked': false,
                    'download_url':
                        'https://learning.test/api/resources/7/download',
                  },
                ],
                'enrolments': [
                  {'course_id': 1, 'payment_confirmed_at': '2026-10-01'},
                ],
              }),
              200,
            );
          }
          expect(request.headers['Authorization'], 'Bearer paid-token');
          requestedDownloads.add(request.url.path);
          return http.Response(
            'cached ${request.url.path}',
            200,
            headers: {
              'content-type': 'application/pdf',
              'content-disposition': 'attachment; filename="lesson.pdf"',
            },
          );
        }),
      );

      await repo.init(storageDirectory: directory);
      await repo.sync();

      expect(requestedDownloads, [
        '/api/lessons/2/download',
        '/api/resources/7/download',
      ]);
      expect(repo.hasCachedLearningFile('lessons', '2'), isTrue);
      expect(repo.hasCachedLearningFile('resources', '7'), isTrue);
      expect(repo.hasCachedLearningFile('lessons', '3'), isFalse);
      expect(
        await (await repo.cachedLearningFile('resources', '7'))!.readAsString(),
        'cached /api/resources/7/download',
      );

      repo.dispose();
      await directory.delete(recursive: true);
    },
  );
}
