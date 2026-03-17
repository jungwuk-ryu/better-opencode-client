import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/connection/connection_models.dart';
import '../projects/project_models.dart';
import 'request_models.dart';

class RequestService {
  RequestService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<PendingRequestBundle> fetchPending({
    required ServerProfile profile,
    required ProjectTarget project,
  }) async {
    final questionsBody = await _getJson(
      profile: profile,
      project: project,
      path: '/question',
    );
    final permissionsBody = await _getJson(
      profile: profile,
      project: project,
      path: '/permission',
    );

    final questions = questionsBody is List
        ? questionsBody
              .whereType<Map>()
              .map(
                (item) => QuestionRequestSummary.fromJson(
                  item.cast<String, Object?>(),
                ),
              )
              .toList(growable: false)
        : const <QuestionRequestSummary>[];
    final permissions = permissionsBody is List
        ? permissionsBody
              .whereType<Map>()
              .map(
                (item) => PermissionRequestSummary.fromJson(
                  item.cast<String, Object?>(),
                ),
              )
              .toList(growable: false)
        : const <PermissionRequestSummary>[];

    return PendingRequestBundle(questions: questions, permissions: permissions);
  }

  Future<bool> replyToPermission({
    required ServerProfile profile,
    required ProjectTarget project,
    required String requestId,
    required String reply,
  }) async {
    final result = await _postJson(
      profile: profile,
      project: project,
      path: '/permission/$requestId/reply',
      body: <String, Object?>{'reply': reply},
    );
    return result == true;
  }

  Future<bool> replyToQuestion({
    required ServerProfile profile,
    required ProjectTarget project,
    required String requestId,
    required List<List<String>> answers,
  }) async {
    final result = await _postJson(
      profile: profile,
      project: project,
      path: '/question/$requestId/reply',
      body: <String, Object?>{'answers': answers},
    );
    return result == true;
  }

  Future<bool> rejectQuestion({
    required ServerProfile profile,
    required ProjectTarget project,
    required String requestId,
  }) async {
    final result = await _postJson(
      profile: profile,
      project: project,
      path: '/question/$requestId/reject',
      body: const <String, Object?>{},
    );
    return result == true;
  }

  Future<Object?> _getJson({
    required ServerProfile profile,
    required ProjectTarget project,
    required String path,
  }) async {
    final uri = _uri(profile, project, path);
    final response = await _client.get(uri, headers: _headers(profile));
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
