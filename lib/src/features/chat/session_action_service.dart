import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/connection/connection_models.dart';
import '../projects/project_models.dart';
import 'chat_models.dart';

class SessionActionService {
  SessionActionService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  Future<SessionSummary> forkSession({
    required ServerProfile profile,
    required ProjectTarget project,
    required String sessionId,
    String? messageId,
  }) async {
    final body = await _postJson(
      profile: profile,
      project: project,
      path: '/session/$sessionId/fork',
      body: messageId == null
          ? const <String, Object?>{}
          : <String, Object?>{'messageID': messageId},
    );
    return SessionSummary.fromJson((body as Map).cast<String, Object?>());
  }

  Future<bool> abortSession({
    required ServerProfile profile,
    required ProjectTarget project,
    required String sessionId,
  }) async {
    final body = await _postJson(
      profile: profile,
      project: project,
      path: '/session/$sessionId/abort',
      body: const <String, Object?>{},
    );
    return body == true;
  }

  Future<bool> shareSession({
    required ServerProfile profile,
    required ProjectTarget project,
    required String sessionId,
  }) async {
    final body = await _postJson(
      profile: profile,
      project: project,
      path: '/session/$sessionId/share',
      body: const <String, Object?>{},
    );
    return body is Map;
  }

  Future<bool> unshareSession({
    required ServerProfile profile,
    required ProjectTarget project,
    required String sessionId,
  }) async {
    final uri = _uri(profile, project, '/session/$sessionId/share');
    final response = await _client.delete(uri, headers: _headers(profile));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Request failed for $uri with status ${response.statusCode}.',
      );
    }
    return response.body.trim().isNotEmpty;
  }

  Future<SessionSummary> revertSession({
    required ServerProfile profile,
    required ProjectTarget project,
    required String sessionId,
    required String messageId,
    String? partId,
  }) async {
    final body = await _postJson(
      profile: profile,
      project: project,
      path: '/session/$sessionId/revert',
      body: <String, Object?>{
        'messageID': messageId,
        ...?(partId == null ? null : <String, Object?>{'partID': partId}),
      },
    );
    return SessionSummary.fromJson((body as Map).cast<String, Object?>());
  }

  Future<SessionSummary> unrevertSession({
    required ServerProfile profile,
    required ProjectTarget project,
    required String sessionId,
  }) async {
    final body = await _postJson(
      profile: profile,
      project: project,
      path: '/session/$sessionId/unrevert',
      body: const <String, Object?>{},
    );
    return SessionSummary.fromJson((body as Map).cast<String, Object?>());
  }

  Future<bool> initSession({
    required ServerProfile profile,
    required ProjectTarget project,
    required String sessionId,
    required String messageId,
    required String providerId,
    required String modelId,
  }) async {
    final body = await _postJson(
      profile: profile,
      project: project,
      path: '/session/$sessionId/init',
      body: <String, Object?>{
        'messageID': messageId,
        'providerID': providerId,
        'modelID': modelId,
      },
    );
    return body == true;
  }

  Future<Object?> _postJson({
    required ServerProfile profile,
    required ProjectTarget project,
    required String path,
    required Map<String, Object?> body,
  }) async {
    final uri = _uri(profile, project, path);
    final response = await _client.post(
      uri,
      headers: _headers(profile, jsonBody: true),
      body: jsonEncode(body),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Request failed for $uri with status ${response.statusCode}.',
      );
    }
    if (response.body.trim().isEmpty) {
      return null;
    }
    return jsonDecode(response.body);
  }

  Uri _uri(ServerProfile profile, ProjectTarget project, String path) {
    final baseUri = profile.uriOrNull;
    if (baseUri == null) {
      throw const FormatException('Invalid server profile URL.');
    }
    final basePath = switch (baseUri.path) {
      '' => '/',
      final value when value.endsWith('/') => value,
      final value => '$value/',
    };
    return baseUri
        .replace(path: basePath)
        .resolve(path.startsWith('/') ? path.substring(1) : path)
        .replace(
          queryParameters: <String, String>{'directory': project.directory},
        );
  }

  Map<String, String> _headers(ServerProfile profile, {bool jsonBody = false}) {
    final headers = <String, String>{'accept': 'application/json'};
    if (jsonBody) {
      headers['content-type'] = 'application/json';
    }
    final authHeader = profile.basicAuthHeader;
    if (authHeader != null) {
      headers['authorization'] = authHeader;
    }
    return headers;
  }

  void dispose() {
    _client.close();
  }
}
