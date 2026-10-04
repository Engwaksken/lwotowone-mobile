import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'api_config.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class ApiFailure implements Exception {
  final String message;
  final int status;
  ApiFailure(this.message, this.status);
  @override
  String toString() => message;
}

class Repository extends ChangeNotifier {
  static const base = ApiConfig.base;
  final http.Client client;
  final FlutterSecureStorage secure;
  final String baseUrl;
  Repository({
    http.Client? client,
    FlutterSecureStorage? secure,
    this.baseUrl = base,
  }) : client = client ?? http.Client(),
       secure = secure ?? const FlutterSecureStorage();
  String? token;
  Map<String, dynamic> data = {};
  List<Map<String, dynamic>> pending = [];
  bool busy = false;
  bool online = false;
  String? message;
  Directory? directory;
  String? owner;
  bool get loggedIn => token != null;
  List<Map<String, dynamic>> rows(String key) => (data[key] as List? ?? [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
  Future<void> init({Directory? storageDirectory}) async {
    directory = storageDirectory ?? await getApplicationSupportDirectory();
    token = await secure.read(key: 'token');
    owner = await secure.read(key: 'owner');
    if (token != null && owner != null) {
      data = await _loadMap('snapshot');
      final list = await _loadMap('pending');
      pending = (list['items'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    notifyListeners();
  }

  File _file(String name) =>
      File('${directory!.path}/account_${owner ?? 'none'}_$name.json');
  Future<Map<String, dynamic>> _loadMap(String name) async {
    try {
      return Map<String, dynamic>.from(
        jsonDecode(await _file(name).readAsString()) as Map,
      );
    } catch (_) {
      return {};
    }
  }

  Future<void> _save(String name, Map<String, dynamic> value) async {
    final target = _file(name);
    final temporary = File('${target.path}.tmp');
    await temporary.writeAsString(jsonEncode(value), flush: true);
    await temporary.rename(target.path);
  }

  Future<Map<String, dynamic>> request(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final problem = ApiConfig.validate(baseUrl);
    if (problem != null) throw ApiFailure(problem, 0);
    final uri = Uri.parse('$baseUrl$path');
    final headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    http.Response response;
    try {
      response =
          await (method == 'GET'
                  ? client.get(uri, headers: headers)
                  : client.post(
                      uri,
                      headers: headers,
                      body: jsonEncode(body ?? {}),
                    ))
              .timeout(const Duration(seconds: 20));
    } on SocketException {
      throw ApiFailure(
        'No connection. Downloaded content is available offline.',
        0,
      );
    } on TimeoutException {
      throw ApiFailure(
        'The server took too long to respond. Try synchronising again.',
        0,
      );
    } on http.ClientException {
      throw ApiFailure('Could not connect. Check your internet connection.', 0);
    }
    Map<String, dynamic> value;
    try {
      value = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    } catch (_) {
      throw ApiFailure(
        'The server returned an unexpected response.',
        response.statusCode,
      );
    }
    if (response.statusCode == 401 && token != null) {
      token = null;
      await secure.delete(key: 'token');
      notifyListeners();
    }
    if (response.statusCode >= 400) {
      final errors = value['errors'];
      final text = errors is Map
          ? errors.values
                .map((e) => e is List ? e.join(' ') : e.toString())
                .join('\n')
          : value['message']?.toString() ?? 'Request failed.';
      throw ApiFailure(text, response.statusCode);
    }
    return value;
  }

  Future<void> authenticate(
    Map<String, dynamic> fields, {
    bool register = false,
  }) async {
    final result = await request(
      'POST',
      register ? '/register' : '/login',
      fields,
    );
    token = result['token'] as String;
    owner = (result['user']['id']).toString();
    await secure.write(key: 'token', value: token);
    await secure.write(key: 'owner', value: owner);
    data = await _loadMap('snapshot');
    pending = [];
    // Recover queued work from a previous session for this same account.
    final old = await _loadMap('pending');
    pending = (old['items'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    notifyListeners();
    await sync();
  }

  Future<void> sync() async {
    if (busy || token == null) return;
    busy = true;
    message = null;
    notifyListeners();
    try {
      for (final item in List<Map<String, dynamic>>.from(pending)) {
        if (item['error'] != null) continue;
        try {
          await request(
            'POST',
            '/actions/${item['action']}',
            Map<String, dynamic>.from(item['payload'] as Map),
          );
          pending.removeWhere((p) => p['id'] == item['id']);
          await _save('pending', {'items': pending});
        } on ApiFailure catch (e) {
          if (e.status == 422 ||
              e.status == 403 ||
              e.status == 404 ||
              e.status == 409) {
            item['error'] = e.message;
            await _save('pending', {'items': pending});
          } else {
            rethrow;
          }
        }
      }
      data = await request('GET', '/snapshot');
      await _save('snapshot', data);
      online = true;
      message = pending.isEmpty
          ? 'Synchronised successfully.'
          : 'Some pending work needs your attention.';
    } on ApiFailure catch (e) {
      online = false;
      message = e.status == 401
          ? 'Session expired. Synchronise after signing in again. Your pending work is retained.'
          : e.message;
    } catch (_) {
      online = false;
      message = 'Could not save or synchronise. Please try again.';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> act(
    String action,
    Map<String, dynamic> payload, {
    bool offlineAllowed = false,
  }) async {
    if (busy) throw ApiFailure('Please wait for synchronisation to finish.', 0);
    if (offlineAllowed) {
      final id = const Uuid().v4();
      pending.add({
        'id': id,
        'action': action,
        'payload': {...payload, 'client_id': id},
        'created_at': DateTime.now().toIso8601String(),
      });
      await _save('pending', {'items': pending});
      notifyListeners();
      await sync();
    } else {
      await request('POST', '/actions/$action', payload);
      await sync();
    }
  }

  Future<void> discard(String id) async {
    pending.removeWhere((p) => p['id'] == id);
    await _save('pending', {'items': pending});
    notifyListeners();
  }

  Future<void> retry(String id) async {
    for (final item in pending) {
      if (item['id'] == id) item.remove('error');
    }
    await _save('pending', {'items': pending});
    await sync();
  }

  Future<void> profile(Map<String, dynamic> fields) async {
    await request('POST', '/profile', fields);
    await sync();
  }

  Future<void> readNotice(String id) async {
    await request('POST', '/notifications/$id/read');
    await sync();
  }

  Future<File> downloadResource(int id) async {
    final problem = ApiConfig.validate(baseUrl);
    if (problem != null) throw ApiFailure(problem, 0);
    final target = File('${directory!.path}/account_${owner}_resource_$id');
    final meta = File('${target.path}.name');
    if (meta.existsSync()) {
      final cached = File('${target.path}_${await meta.readAsString()}');
      if (cached.existsSync()) return cached;
    }
    final response = await client
        .get(
          Uri.parse('$baseUrl/resources/$id/download'),
          headers: {
            'Accept': 'application/octet-stream',
            'Authorization': 'Bearer $token',
          },
        )
        .timeout(const Duration(seconds: 45));
    if (response.statusCode != 200) {
      throw ApiFailure(
        'Download failed. Check enrolment and connection.',
        response.statusCode,
      );
    }
    final disposition = response.headers['content-disposition'] ?? '';
    final match = RegExp(r'filename="?([^";]+)').firstMatch(disposition);
    final name = (match?.group(1) ?? 'resource.pdf').replaceAll(
      RegExp(r'[^a-zA-Z0-9._-]'),
      '_',
    );
    final file = File('${target.path}_$name');
    await file.writeAsBytes(response.bodyBytes, flush: true);
    await meta.writeAsString(name, flush: true);
    return file;
  }

  Future<void> logout({bool discardPending = false}) async {
    if (busy) {
      throw ApiFailure(
        'Wait for synchronisation to finish before signing out.',
        0,
      );
    }
    if (pending.isNotEmpty && !discardPending) {
      throw ApiFailure(
        'Synchronise pending work first, or explicitly discard it.',
        0,
      );
    }
    // Require successful revocation before discarding the local credential.
    await request('POST', '/logout');
    final prefix = 'account_${owner}_';
    for (final f in directory!.listSync()) {
      if (f is File && f.uri.pathSegments.last.startsWith(prefix)) {
        await f.delete();
      }
    }
    await secure.delete(key: 'token');
    await secure.delete(key: 'owner');
    token = null;
    owner = null;
    data = {};
    pending = [];
    online = false;
    notifyListeners();
  }

  @override
  void dispose() {
    client.close();
    super.dispose();
  }
}
