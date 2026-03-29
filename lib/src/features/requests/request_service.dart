import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/connection/connection_models.dart';
import '../../core/network/request_headers.dart';
import '../../core/network/request_uri.dart';
import '../projects/project_models.dart';
import 'request_models.dart';

class RequestService {
  RequestService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<PendingRequestBundle> fetchPending({
    required ServerProfile profile,
    required ProjectTarget project,
    bool supportsQuestions = true,
    bool supportsPermissions = true,
  }) async {
    final questionsBody = supportsQuestions
        ? await _getJson(profile: profile, project: project, path: '/question')
        : null;
    final permissionsBody = supportsPermissions
        ? await _getJson(
            profile: profile,
            project: project,
            path: '/permission',
          )
        : null;

    final questions = questionsBody is List
        ? _decodeQuestions(questionsBody)
        : const <QuestionRequestSummary>[];
    final permissions = permissionsBody is List
        ? _decodePermissions(permissionsBody)
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
    return buildRequestUri(
      baseUri,
      path: path,
      queryParameters: <String, String>{'directory': project.directory},
    );
  }

  Map<String, String> _headers(ServerProfile profile, {bool jsonBody = false}) {
    return buildRequestHeaders(
      profile,
      accept: 'application/json',
      jsonBody: jsonBody,
    );
  }

  List<QuestionRequestSummary> _decodeQuestions(List body) {
    final questions = <QuestionRequestSummary>[];
    for (final item in body.whereType<Map>()) {
      final request = _tryParseQuestionRequest(item);
      if (request != null) {
        questions.add(request);
      }
    }
    return questions.toList(growable: false);
  }

  List<PermissionRequestSummary> _decodePermissions(List body) {
    final permissions = <PermissionRequestSummary>[];
    for (final item in body.whereType<Map>()) {
      final request = _tryParsePermissionRequest(item);
      if (request != null) {
        permissions.add(request);
      }
    }
    return permissions.toList(growable: false);
  }

  QuestionRequestSummary? _tryParseQuestionRequest(Map item) {
    try {
      final request = QuestionRequestSummary.fromJson(
        item.cast<String, Object?>(),
      );
      if (request.id.isEmpty ||
          request.sessionId.isEmpty ||
          request.questions.isEmpty) {
        return null;
      }
      return request;
    } catch (_) {
      return null;
    }
  }

  PermissionRequestSummary? _tryParsePermissionRequest(Map item) {
    try {
      final request = PermissionRequestSummary.fromJson(
        item.cast<String, Object?>(),
      );
      if (request.id.isEmpty ||
          request.sessionId.isEmpty ||
          request.permission.isEmpty) {
        return null;
      }
      return request;
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    _client.close();
  }
}
