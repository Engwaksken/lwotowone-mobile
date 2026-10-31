import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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
  Timer? _messageTimer;
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
    _messageTimer?.cancel();
    _messageTimer = null;
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
      await _removeFilesWithoutApproval();
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
      final shownMessage = message;
      if (shownMessage != null) {
        _messageTimer = Timer(const Duration(seconds: 5), () {
          if (message == shownMessage) {
            message = null;
            notifyListeners();
          }
        });
      }
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

  Map<String, String> get authHeaders => {
    if (token != null) 'Authorization': 'Bearer $token',
  };

  /// Download requests keep only these states' files on the phone. Pending,
  /// rejected and withdrawn requests never leave a copy behind.
  static const keepSavedStates = {'approved', 'used_up', 'expired'};

  Map<String, dynamic>? downloadRequestFor(String type, Object? id) {
    for (final row in rows('download_requests')) {
      if (row['item_type'] == type && '${row['item_id']}' == '$id') return row;
    }
    return null;
  }

  Map<String, dynamic>? enrollmentRequestFor(Object? courseId) {
    for (final row in rows('enrollment_requests')) {
      if ('${row['course_id']}' == '$courseId') return row;
    }
    return null;
  }

  Future<void> requestEnrollment(Object? courseId, String? message) async {
    await request('POST', '/enrollment-requests', {
      'course_id': courseId,
      if (message != null && message.isNotEmpty) 'message': message,
    });
    await sync();
  }

  Future<void> requestDownload(String type, Object? id, String? message) async {
    await request('POST', '/download-requests', {
      'item_type': type,
      'item_id': id,
      if (message != null && message.isNotEmpty) 'message': message,
    });
    await sync();
  }

  /// Reads a protected learning file into memory for the in-app viewers.
  /// Nothing is written to the device.
  Future<Uint8List> fetchBytes(
    String url, {
    int maxBytes = 80 * 1024 * 1024,
  }) async {
    final problem = ApiConfig.validate(baseUrl);
    if (problem != null) throw ApiFailure(problem, 0);
    final uri = _validatedLearningUri(url);
    http.StreamedResponse response;
    try {
      response = await client
          .send(http.Request('GET', uri)..headers.addAll(authHeaders))
          .timeout(const Duration(seconds: 45));
    } on SocketException {
      throw ApiFailure(
        'No connection. Connect to the internet to open this content.',
        0,
      );
    } on TimeoutException {
      throw ApiFailure('The content took too long to load. Try again.', 0);
    } on http.ClientException {
      throw ApiFailure('Could not connect. Check your internet connection.', 0);
    }
    if (response.statusCode != 200) {
      throw ApiFailure(
        response.statusCode == 403
            ? 'This content is locked. Finish the earlier lessons or check your course access.'
            : 'Could not load this content.',
        response.statusCode,
      );
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in response.stream) {
      builder.add(chunk);
      if (builder.length > maxBytes) {
        throw ApiFailure('This file is too large to open in the app.', 0);
      }
    }
    return builder.takeBytes();
  }

  File _savedTarget(String type, String id) =>
      File('${directory!.path}/account_${owner}_${type}_$id');

  bool hasSavedFile(String type, Object? id) {
    if (directory == null || owner == null) return false;
    final target = _savedTarget(type, '$id');
    final meta = File('${target.path}.name');
    if (!meta.existsSync()) return false;
    return File('${target.path}_${meta.readAsStringSync()}').existsSync();
  }

  Future<File?> savedFile(String type, Object? id) async {
    if (!hasSavedFile(type, id)) return null;
    final target = _savedTarget(type, '$id');
    final meta = File('${target.path}.name');
    return File('${target.path}_${await meta.readAsString()}');
  }

  Future<void> removeSavedFile(String type, Object? id) async {
    if (directory == null || owner == null) return;
    final target = _savedTarget(type, '$id');
    final meta = File('${target.path}.name');
    if (await meta.exists()) {
      final content = File('${target.path}_${await meta.readAsString()}');
      if (await content.exists()) await content.delete();
      await meta.delete();
    }
    notifyListeners();
  }

  /// Everything saved through approved downloads, for the Profile tab.
  Future<List<SavedFile>> savedFiles() async {
    if (directory == null || owner == null) return [];
    final prefix = 'account_${owner}_';
    final found = <SavedFile>[];
    for (final entry in directory!.listSync()) {
      final name = entry.uri.pathSegments.last;
      if (entry is! File ||
          !name.startsWith(prefix) ||
          !name.endsWith('.name')) {
        continue;
      }
      final match = RegExp(
        r'^(lessons|resources|attachments)_(\d+)\.name$',
      ).firstMatch(name.substring(prefix.length));
      if (match == null) continue;
      final file = await savedFile(match.group(1)!, match.group(2));
      if (file != null) {
        found.add(
          SavedFile(
            match.group(1)!,
            match.group(2)!,
            file,
            await file.length(),
          ),
        );
      }
    }
    return found;
  }

  /// Saves an approved lesson or resource file inside the app. Each save uses
  /// one of the approval's downloads, so a saved file is never fetched again.
  Future<File> saveApprovedDownload(
    String type,
    Object? id, {
    void Function(double progress)? onProgress,
  }) async {
    final approval = downloadRequestFor(type, id);
    final url = approval?['download_url']?.toString();
    if (approval == null || approval['state'] != 'approved' || url == null) {
      throw ApiFailure(
        'This download has not been approved. Send a request first.',
        403,
      );
    }
    final existing = await savedFile(type, id);
    if (existing != null) return existing;
    final file = await _saveFrom(url, type, '$id', onProgress: onProgress);
    await sync();
    return file;
  }

  /// A lesson's attached files come with the lesson's approval and do not use a download.
  Future<File> saveApprovedAttachment(
    Object? lessonId,
    Object? attachmentId, {
    void Function(double progress)? onProgress,
  }) async {
    final approval = downloadRequestFor('lessons', lessonId);
    final url = approval?['download_url']?.toString();
    if (approval == null || approval['state'] != 'approved' || url == null) {
      throw ApiFailure(
        'Request a download of this lesson to save its files.',
        403,
      );
    }
    final existing = await savedFile('attachments', attachmentId);
    if (existing != null) return existing;
    return _saveFrom(
      '$url/attachments/$attachmentId',
      'attachments',
      '$attachmentId',
      onProgress: onProgress,
    );
  }

  Future<File> _saveFrom(
    String url,
    String type,
    String id, {
    void Function(double progress)? onProgress,
  }) async {
    if (directory == null || owner == null) {
      throw ApiFailure('Sign in before saving learning files.', 0);
    }
    final problem = ApiConfig.validate(baseUrl);
    if (problem != null) throw ApiFailure(problem, 0);
    final uri = _validatedLearningUri(url);
    http.StreamedResponse response;
    try {
      response = await client
          .send(
            http.Request('GET', uri)
              ..headers.addAll({
                ...authHeaders,
                'Accept': 'application/octet-stream',
              }),
          )
          .timeout(const Duration(seconds: 45));
    } on SocketException {
      throw ApiFailure(
        'No connection. Connect to the internet to save this file.',
        0,
      );
    } on TimeoutException {
      throw ApiFailure('The download took too long to start. Try again.', 0);
    } on http.ClientException {
      throw ApiFailure('Could not connect. Check your internet connection.', 0);
    }
    if (response.statusCode != 200) {
      throw ApiFailure(
        'This download is no longer available. Send a new request.',
        response.statusCode,
      );
    }
    final disposition = response.headers['content-disposition'] ?? '';
    final match = RegExp(r'filename="?([^";]+)').firstMatch(disposition);
    final name = (match?.group(1) ?? '$type-$id.bin').replaceAll(
      RegExp(r'[^a-zA-Z0-9._-]'),
      '_',
    );
    final target = _savedTarget(type, id);
    final partial = File('${target.path}.part');
    final sink = partial.openWrite();
    var received = 0;
    try {
      await for (final chunk in response.stream) {
        received += chunk.length;
        sink.add(chunk);
        final length = response.contentLength;
        onProgress?.call(
          length != null && length > 0
              ? (received / length).clamp(0, 1).toDouble()
              : -1,
        );
      }
      await sink.close();
    } catch (_) {
      await sink.close();
      if (await partial.exists()) await partial.delete();
      throw ApiFailure(
        'The download was interrupted. Try again while connected.',
        0,
      );
    }
    if (received == 0) {
      await partial.delete();
      throw ApiFailure('The downloaded file was empty.', 0);
    }
    final saved = await partial.rename('${target.path}_$name');
    await File('${target.path}.name').writeAsString(name, flush: true);
    onProgress?.call(1);
    notifyListeners();
    return saved;
  }

  /// Removes files the learner is no longer approved to keep: withdrawn or
  /// rejected approvals, content they lost access to, and files that older
  /// versions of the app saved automatically.
  Future<void> _removeFilesWithoutApproval() async {
    bool approved(String type, Object? id) =>
        keepSavedStates.contains(downloadRequestFor(type, id)?['state']) &&
        rows(
          type,
        ).any((row) => '${row['id']}' == '$id' && row['locked'] != true);
    final keptAttachments = <String>{
      for (final lesson in rows('lessons'))
        if (approved('lessons', lesson['id']))
          for (final file in lesson['attachments'] as List? ?? const [])
            if (file is Map) '${file['id']}',
    };
    for (final saved in await savedFiles()) {
      final keep = saved.type == 'attachments'
          ? keptAttachments.contains(saved.id)
          : approved(saved.type, saved.id);
      if (!keep) await removeSavedFile(saved.type, saved.id);
    }
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
    _messageTimer?.cancel();
    client.close();
    super.dispose();
  }
}

/// A learning file saved on this phone through an approved download.
class SavedFile {
  final String type;
  final String id;
  final File file;
  final int size;
  const SavedFile(this.type, this.id, this.file, this.size);
}
