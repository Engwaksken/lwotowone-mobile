import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lwotowone_mobile/services/repository.dart';

/// A server whose download request state can change between syncs.
class FakeServer {
  String? state;
  final requests = <String>[];
  final posted = <Map<String, dynamic>>[];

  Map<String, dynamic> snapshot() => {
    'lessons': [
      {
        'id': 2,
        'course_id': 1,
        'locked': false,
        'downloadable': true,
        'media_type': 'pdf',
        'download_url': 'https://learning.test/api/lessons/2/download',
        'attachments': [
          {'id': 40, 'name': 'notes.pdf'},
        ],
      },
    ],
    'resources': [
      {
        'id': 7,
        'course_id': 1,
        'locked': false,
        'downloadable': true,
        'download_url': 'https://learning.test/api/resources/7/download',
      },
    ],
    'download_requests': [
      if (state != null)
        {
          'id': 90,
          'item_type': 'lessons',
          'item_id': 2,
          'state': state,
          'downloads_left': 3,
          'expires_at': '2026-11-08T10:00:00Z',
          'download_url': state == 'approved'
              ? 'https://learning.test/api/downloads/90'
              : null,
        },
    ],
    'download_policy': {'valid_days': 7, 'max_downloads': 3},
  };

  MockClient client() => MockClient((request) async {
    requests.add('${request.method} ${request.url.path}');
    expect(request.headers['Authorization'], 'Bearer paid-token');
    if (request.url.path == '/api/snapshot') {
      return http.Response(jsonEncode(snapshot()), 200);
    }
    if (request.url.path == '/api/download-requests') {
      posted.add(Map<String, dynamic>.from(jsonDecode(request.body) as Map));
      state = 'pending';
      return http.Response(jsonEncode({'message': 'sent'}), 201);
    }
    return http.Response(
      'file ${request.url.path}',
      200,
      headers: {'content-disposition': 'attachment; filename="lesson.pdf"'},
    );
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late FakeServer server;
  late Repository repo;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('lwotowone-content-');
    FlutterSecureStorage.setMockInitialValues({
      'token': 'paid-token',
      'owner': '12',
    });
    server = FakeServer();
    repo = Repository(
      baseUrl: 'https://learning.test/api',
      client: server.client(),
    );
    await repo.init(storageDirectory: directory);
  });

  tearDown(() async {
    repo.dispose();
    await directory.delete(recursive: true);
  });

  test(
    'Sync never saves learning files and clears copies saved without approval',
    () async {
      // A copy left by an older app version that saved documents automatically.
      await File(
        '${directory.path}/account_12_resources_7_old.pdf',
      ).writeAsString('old copy');
      await File(
        '${directory.path}/account_12_resources_7.name',
      ).writeAsString('old.pdf');
      expect(repo.hasSavedFile('resources', 7), isTrue);

      await repo.sync();

      expect(server.requests, ['GET /api/snapshot']);
      expect(repo.hasSavedFile('resources', 7), isFalse);
      expect(repo.hasSavedFile('lessons', 2), isFalse);
    },
  );

  test('Content streams into memory without writing a file', () async {
    await repo.sync();
    final bytes = await repo.fetchBytes(
      'https://learning.test/api/lessons/2/download',
    );

    expect(utf8.decode(bytes), 'file /api/lessons/2/download');
    expect(await repo.savedFiles(), isEmpty);
    await expectLater(
      repo.fetchBytes('https://elsewhere.test/api/lessons/2/download'),
      throwsA(isA<ApiFailure>()),
    );
  });

  test(
    'Saving needs an approved request and a withdrawn approval removes the copy',
    () async {
      await repo.sync();
      await expectLater(
        repo.saveApprovedDownload('lessons', 2),
        throwsA(isA<ApiFailure>()),
      );

      await repo.requestDownload('lessons', 2, 'No data at home');
      expect(server.posted.single, {
        'item_type': 'lessons',
        'item_id': 2,
        'message': 'No data at home',
      });
      expect(repo.downloadRequestFor('lessons', 2)?['state'], 'pending');

      server.state = 'approved';
      await repo.sync();
      final saved = await repo.saveApprovedDownload('lessons', 2);
      expect(await saved.readAsString(), 'file /api/downloads/90');
      await repo.saveApprovedAttachment(2, 40);
      expect(
        await (await repo.savedFile('attachments', 40))!.readAsString(),
        'file /api/downloads/90/attachments/40',
      );

      // Saving again reuses the copy instead of using up another download.
      await repo.saveApprovedDownload('lessons', 2);
      expect(
        server.requests.where((r) => r == 'GET /api/downloads/90'),
        hasLength(1),
      );

      // Running out of downloads keeps what was already saved.
      server.state = 'used_up';
      await repo.sync();
      expect(repo.hasSavedFile('lessons', 2), isTrue);
      expect(repo.hasSavedFile('attachments', 40), isTrue);

      server.state = 'revoked';
      await repo.sync();
      expect(repo.hasSavedFile('lessons', 2), isFalse);
      expect(repo.hasSavedFile('attachments', 40), isFalse);
      expect(await repo.savedFiles(), isEmpty);
    },
  );
}
