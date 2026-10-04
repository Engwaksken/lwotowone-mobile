import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lwotowone_mobile/services/repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Offline activity persists across restart and sends exactly once after recovery',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'lwotowone-test-',
      );
      FlutterSecureStorage.setMockInitialValues({
        'token': 'test-token',
        'owner': '7',
      });
      final offline = Repository(
        client: MockClient((_) async => throw const SocketException('Offline')),
      );
      await offline.init(storageDirectory: directory);
      await offline.act('practice', {
        'skill_id': 1,
        'title': 'Feed record',
        'body': 'Observed feeding',
        'minutes': 30,
        'practised_on': '2026-10-04',
      }, offlineAllowed: true);
      expect(offline.pending.length, 1);
      final id = offline.pending.first['id'];
      offline.dispose();
      var sent = 0;
      final online = Repository(
        client: MockClient((request) async {
          if (request.method == 'POST') {
            sent++;
            expect(jsonDecode(request.body)['client_id'], id);
            return http.Response('{"ok":true}', 200);
          }
          return http.Response(
            '{"user":{"id":7,"name":"Learner"},"lessons":[]}',
            200,
          );
        }),
      );
      await online.init(storageDirectory: directory);
      expect(online.pending.single['id'], id);
      await online.sync();
      await online.sync();
      expect(sent, 1);
      expect(online.pending, isEmpty);
      online.dispose();
      await directory.delete(recursive: true);
    },
  );
  test(
    'Rejected offline work is retained with feedback; other accounts do not load it',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'lwotowone-test-',
      );
      FlutterSecureStorage.setMockInitialValues({'token': 'a', 'owner': '1'});
      final first = Repository(
        client: MockClient(
          (r) async => r.method == 'POST'
              ? http.Response(
                  '{"errors":{"minutes":["Check your duration."]}}',
                  422,
                )
              : http.Response('{"user":{"id":1}}', 200),
        ),
      );
      await first.init(storageDirectory: directory);
      await first.act('practice', {'minutes': 0}, offlineAllowed: true);
      expect(first.pending.single['error'], 'Check your duration.');
      first.dispose();
      FlutterSecureStorage.setMockInitialValues({'token': 'b', 'owner': '2'});
      final second = Repository();
      await second.init(storageDirectory: directory);
      expect(second.pending, isEmpty);
      expect(second.data, isEmpty);
      second.dispose();
      await directory.delete(recursive: true);
    },
  );
}
