import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'api_config.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:video_compress/video_compress.dart';

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

  Future<String?> authenticate(
    Map<String, dynamic> fields, {
    bool register = false,
  }) async {
    final result = await request(
      'POST',
      register ? '/register' : '/login',
      fields,
    );
    if (register && result['token'] == null) {
      return result['message']?.toString() ??
          'Account created. Verify your email before signing in.';
    }
    final resultToken = result['token'];
    final resultUser = result['user'];
    if (resultToken is! String ||
        resultUser is! Map ||
        resultUser['id'] == null) {
      throw ApiFailure('The server returned incomplete sign-in details.', 0);
    }
    token = resultToken;
    owner = resultUser['id'].toString();
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
    return null;
  }

  static const defaultPolicies = {
    'terms': {
      'title': 'Terms of use',
      'body':
          'By creating an account you agree to use Lwotowone services lawfully and respectfully, to give accurate information about yourself, and to keep your password private.\n\nCourse materials are provided for your personal learning. Do not copy, resell or share them without permission.\n\nWe may suspend accounts that misuse the platform, harass other people or try to access information that is not theirs.\n\nContact us if you have questions about these terms.',
    },
    'privacy': {
      'title': 'Privacy notice',
      'body':
          'We collect the details you give us, such as your name, email, phone number and learner profile, to run your training, track progress and connect you with mentors and opportunities.\n\nYour information is shared only with Lwotowone staff, instructors, mentors and partners who support your learning, or when the law requires it.\n\nWe keep your data secure and only for as long as needed for these purposes.\n\nYou can ask to see, correct or delete your information by contacting us.',
    },
  };

  /// Terms of use and privacy notice from the website, falling back to the
  /// built-in text when offline so signup can still show both documents.
  Future<Map<String, Map<String, String>>> policies() async {
    try {
      final result = await request('GET', '/policies');
      final docs = result['policies'];
      if (docs is Map) {
        return {
          for (final key in defaultPolicies.keys)
            key: {
              'title': (docs[key]?['title'] ?? defaultPolicies[key]!['title'])
                  .toString(),
              'body': (docs[key]?['body'] ?? defaultPolicies[key]!['body'])
                  .toString(),
            },
        };
      }
    } catch (_) {
      // Fall through to the built-in copy.
    }
    return {
      for (final entry in defaultPolicies.entries)
        entry.key: Map<String, String>.from(entry.value),
    };
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
      var contentDownloadFailures = 0;
      for (final type in ['lessons', 'resources']) {
        for (final item in rows(type)) {
          final url = item['download_url']?.toString();
          if (item['locked'] == true || url == null || url.isEmpty) continue;
          // Video downloads are large and should only happen when the learner
          // explicitly saves one for offline use.
          if (item['media_type'] == 'video') continue;
          try {
            await _cacheLearningFile(type, item['id'].toString(), url);
          } catch (_) {
            contentDownloadFailures++;
          }
        }
      }
      online = true;
      message = contentDownloadFailures > 0
          ? 'Synced, but $contentDownloadFailures learning file(s) could not be downloaded. Retry while connected.'
          : pending.isEmpty
          ? 'Synchronised successfully. Authorized lessons and resources are ready offline.'
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
    final user = Map<String, dynamic>.from(data['user'] as Map? ?? {});
    user.addAll(fields);
    data['user'] = user;
    await _save('snapshot', data);
    notifyListeners();
    await sync();
  }

  Future<void> uploadProfilePhoto(File photo) async {
    final problem = ApiConfig.validate(baseUrl);
    if (problem != null) throw ApiFailure(problem, 0);
    final uri = Uri.parse('$baseUrl/profile/photo');
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll({
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      })
      ..files.add(await http.MultipartFile.fromPath('photo', photo.path));
    http.Response response;
    try {
      response = await http.Response.fromStream(
        await client.send(request).timeout(const Duration(seconds: 30)),
      );
    } on SocketException {
      throw ApiFailure('No connection. Try again when you are online.', 0);
    } on TimeoutException {
      throw ApiFailure('The upload took too long. Try again.', 0);
    } on http.ClientException {
      throw ApiFailure('Could not connect. Check your internet connection.', 0);
    }
    Map<String, dynamic> result;
    try {
      result = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    } catch (_) {
      throw ApiFailure(
        'The server returned an unexpected response.',
        response.statusCode,
      );
    }
    if (response.statusCode >= 400) {
      final errors = result['errors'];
      final message = errors is Map
          ? errors.values
                .map((value) => value is List ? value.join(' ') : '$value')
                .join('\n')
          : result['message']?.toString() ?? 'Photo upload failed.';
      throw ApiFailure(message, response.statusCode);
    }
    final user = Map<String, dynamic>.from(data['user'] as Map? ?? {});
    user['profile_photo_url'] = result['profile_photo_url'];
    data['user'] = user;
    await _save('snapshot', data);
    notifyListeners();
  }

  Future<void> readNotice(String id) async {
    await request('POST', '/notifications/$id/read');
    await sync();
  }

  Future<File> downloadResource(int id) async {
    final cached = await cachedLearningFile('resources', id.toString());
    if (cached != null) return cached;
    final file = await _cacheLearningFile(
      'resources',
      id.toString(),
      '$baseUrl/resources/$id/download',
    );
    return file;
  }

  Future<File?> cachedLearningFile(String type, String id) async {
    if (!hasCachedLearningFile(type, id)) return null;
    final target = File('${directory!.path}/account_${owner}_${type}_$id');
    final meta = File('${target.path}.name');
    return File('${target.path}_${await meta.readAsString()}');
  }

  Future<int?> cachedLearningFileSize(String type, String id) async {
    final file = await cachedLearningFile(type, id);
    return file?.length();
  }

  Future<void> removeCachedLearningFile(String type, String id) async {
    if (directory == null || owner == null) return;
    final target = File('${directory!.path}/account_${owner}_${type}_$id');
    final meta = File('${target.path}.name');
    if (await meta.exists()) {
      final name = await meta.readAsString();
      final content = File('${target.path}_$name');
      if (await content.exists()) await content.delete();
      await meta.delete();
    }
    notifyListeners();
  }

  Future<File> saveLessonVideoOffline(
    String id,
    String url, {
    void Function(double progress)? onDownloadProgress,
    VoidCallback? onCompressionStart,
  }) async {
    if (directory == null || owner == null) {
      throw ApiFailure('Sign in before saving videos for offline use.', 0);
    }
    final cached = await cachedLearningFile('lessons', id);
    if (cached != null) return cached;
    final problem = ApiConfig.validate(baseUrl);
    if (problem != null) throw ApiFailure(problem, 0);
    final uri = _validatedLearningUri(url);
    final request = http.Request('GET', uri)
      ..headers.addAll({
        'Accept': 'application/octet-stream',
        'Authorization': 'Bearer $token',
      });
    final response = await client
        .send(request)
        .timeout(const Duration(seconds: 45));
    if (response.statusCode != 200) {
      throw ApiFailure(
        'Video download failed. Check course access and connection.',
        response.statusCode,
      );
    }
    const maxVideoBytes = 100 * 1024 * 1024;
    if (response.contentLength != null &&
        response.contentLength! > maxVideoBytes) {
      throw ApiFailure(
        'This video is larger than the 100 MB download limit.',
        0,
      );
    }
    final disposition = response.headers['content-disposition'] ?? '';
    final match = RegExp(r'filename="?([^";]+)').firstMatch(disposition);
    final rawName = match?.group(1) ?? uri.pathSegments.last;
    final extension =
        RegExp(
          r'\.(mp4|webm|ogg)$',
          caseSensitive: false,
        ).firstMatch(rawName)?.group(1)?.toLowerCase() ??
        'mp4';
    final source = File(
      '${directory!.path}/account_${owner}_lesson_video_$id.$extension',
    );
    if (response.contentLength == null) onDownloadProgress?.call(-1);
    final sink = source.openWrite();
    var received = 0;
    try {
      await for (final chunk in response.stream) {
        received += chunk.length;
        if (received > maxVideoBytes) {
          throw ApiFailure(
            'This video is larger than the 100 MB download limit.',
            0,
          );
        }
        sink.add(chunk);
        final length = response.contentLength;
        if (length != null && length > 0) {
          onDownloadProgress?.call((received / length).clamp(0, 1).toDouble());
        }
      }
      await sink.flush();
    } catch (_) {
      await sink.close();
      if (await source.exists()) await source.delete();
      rethrow;
    }
    await sink.close();
    if (received == 0) {
      await source.delete();
      throw ApiFailure('The video file was empty.', 0);
    }

    onCompressionStart?.call();
    File chosen = source;
    try {
      final compressed = await VideoCompress.compressVideo(
        source.path,
        quality: VideoQuality.Res960x540Quality,
        deleteOrigin: false,
      );
      final output = compressed?.file;
      if (output != null &&
          await output.exists() &&
          await output.length() < await source.length()) {
        chosen = output;
      }
    } catch (_) {
      // Preserve access to the original if a device codec cannot transcode it.
    }

    final filename = chosen == source
        ? 'lesson-$id.$extension'
        : 'lesson-$id-offline.mp4';
    final target = File('${directory!.path}/account_${owner}_lessons_$id');
    final meta = File('${target.path}.name');
    final saved = File('${target.path}_$filename');
    try {
      await chosen.copy(saved.path);
      await meta.writeAsString(filename, flush: true);
      onDownloadProgress?.call(1);
      notifyListeners();
      return saved;
    } catch (_) {
      if (await saved.exists()) await saved.delete();
      rethrow;
    } finally {
      if (await source.exists()) await source.delete();
      if (chosen != source && await chosen.exists()) await chosen.delete();
    }
  }

  bool hasCachedLearningFile(String type, String id) {
    if (directory == null || owner == null) return false;
    final target = File('${directory!.path}/account_${owner}_${type}_$id');
    final meta = File('${target.path}.name');
    if (!meta.existsSync()) return false;
    return File('${target.path}_${meta.readAsStringSync()}').existsSync();
  }

  Future<File> _cacheLearningFile(String type, String id, String url) async {
    final problem = ApiConfig.validate(baseUrl);
    if (problem != null) throw ApiFailure(problem, 0);
    final cached = await cachedLearningFile(type, id);
    if (cached != null) return cached;
    final uri = _validatedLearningUri(url);
    final response = await client
        .get(
          uri,
          headers: {
            'Accept': 'application/octet-stream',
            'Authorization': 'Bearer $token',
          },
        )
        .timeout(const Duration(seconds: 45));
    if (response.statusCode != 200) {
      throw ApiFailure(
        'Learning file download failed. Check course access and connection.',
        response.statusCode,
      );
    }
    final disposition = response.headers['content-disposition'] ?? '';
    final match = RegExp(r'filename="?([^";]+)').firstMatch(disposition);
    final uriName = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
    final name =
        (match?.group(1) ?? (uriName.contains('.') ? uriName : '$type-$id.bin'))
            .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final target = File('${directory!.path}/account_${owner}_${type}_$id');
    final meta = File('${target.path}.name');
    final file = File('${target.path}_$name');
    await file.writeAsBytes(response.bodyBytes, flush: true);
    await meta.writeAsString(name, flush: true);
    return file;
  }

  Uri _validatedLearningUri(String url) {
    final uri = Uri.tryParse(url);
    final baseUri = Uri.parse(baseUrl);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.origin != baseUri.origin ||
        uri.userInfo.isNotEmpty ||
        !uri.path.startsWith('/api/')) {
      throw ApiFailure('The learning file address is invalid.', 0);
    }
    return uri;
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
