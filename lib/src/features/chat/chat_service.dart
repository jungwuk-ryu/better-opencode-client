import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/connection/connection_models.dart';
import '../../core/network/request_headers.dart';
import '../projects/project_models.dart';
import 'chat_models.dart';

class ChatService {
  ChatService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<SessionSummary> createSession({
    required ServerProfile profile,
    required ProjectTarget project,
    String? title,
  }) async {
    final baseUri = profile.uriOrNull;
    if (baseUri == null) {
      throw const FormatException('Invalid server profile URL.');
    }

    final headers = buildRequestHeaders(
      profile,
      accept: 'application/json',
      jsonBody: true,
    );
    final basePath = switch (baseUri.path) {
      '' => '/',
      final value when value.endsWith('/') => value,
      final value => '$value/',
    };
    final uri = baseUri
        .replace(path: basePath)
        .resolve('session')
        .replace(
          queryParameters: <String, String>{'directory': project.directory},
        );
    final body = <String, Object?>{};
    if (title != null) {
      body['title'] = title;
    }
    final response = await _client.post(
      uri,
      headers: headers,
      body: jsonEncode(body),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Request failed for $uri with status ${response.statusCode}.',
      );
    }
    return SessionSummary.fromJson(
      (jsonDecode(response.body) as Map).cast<String, Object?>(),
    );
  }

  Future<ChatMessage> sendMessage({
    required ServerProfile profile,
    required ProjectTarget project,
    required String sessionId,
    required String prompt,
    String? agent,
    String? providerId,
    String? modelId,
    String? variant,
    String? reasoning,
  }) async {
    final baseUri = profile.uriOrNull;
    if (baseUri == null) {
      throw const FormatException('Invalid server profile URL.');
    }

    final headers = buildRequestHeaders(
      profile,
      accept: 'application/json',
      jsonBody: true,
    );
    final basePath = switch (baseUri.path) {
      '' => '/',
      final value when value.endsWith('/') => value,
      final value => '$value/',
    };
    final uri = baseUri
        .replace(path: basePath)
        .resolve('session/$sessionId/message')
        .replace(
          queryParameters: <String, String>{'directory': project.directory},
        );
    final body = <String, Object?>{
      'parts': <Map<String, Object?>>[
        <String, Object?>{'type': 'text', 'text': prompt},
      ],
    };
    if (agent != null && agent.isNotEmpty) {
      body['agent'] = agent;
    }
    if (providerId != null &&
        providerId.isNotEmpty &&
        modelId != null &&
        modelId.isNotEmpty) {
      body['model'] = <String, Object?>{
        'providerID': providerId,
        'modelID': modelId,
      };
    }
    if (providerId != null && providerId.isNotEmpty) {
      body['providerID'] = providerId;
    }
    if (modelId != null && modelId.isNotEmpty) {
      body['modelID'] = modelId;
    }
    final resolvedVariant = variant?.trim().isNotEmpty == true
        ? variant!.trim()
        : reasoning?.trim();
    if (resolvedVariant != null && resolvedVariant.isNotEmpty) {
      body['variant'] = resolvedVariant;
    }
    if (reasoning != null && reasoning.isNotEmpty) {
      body['reasoning'] = reasoning;
    }
    final response = await _client.post(
      uri,
      headers: headers,
      body: jsonEncode(body),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Request failed for $uri with status ${response.statusCode}.',
      );
    }
    return ChatMessage.fromJson(
      (jsonDecode(response.body) as Map).cast<String, Object?>(),
    );
  }

  Future<ChatSessionBundle> fetchBundle({
    required ServerProfile profile,
    required ProjectTarget project,
  }) async {
    final baseUri = profile.uriOrNull;
    if (baseUri == null) {
      throw const FormatException('Invalid server profile URL.');
    }

    final headers = buildRequestHeaders(profile, accept: 'application/json');

    final sessionsBody = await _getJson(
      baseUri,
      '/session',
      headers: headers,
      query: <String, String>{'directory': project.directory},
    );
    final statusesBody = await _getJson(
      baseUri,
      '/session/status',
      headers: headers,
      query: <String, String>{'directory': project.directory},
    );

    final sessions = sessionsBody is List
        ? sessionsBody
              .whereType<Map>()
              .map((item) => _safeParseSession(item.cast<String, Object?>()))
              .whereType<SessionSummary>()
              .toList(growable: false)
        : const <SessionSummary>[];
    final statuses = statusesBody is Map
        ? statusesBody.map(
            (key, value) => MapEntry(
              key.toString(),
              _safeParseStatus((value as Map).cast<String, Object?>()) ??
                  const SessionStatusSummary(type: 'idle'),
            ),
          )
        : const <String, SessionStatusSummary>{};

    final visibleSessions = sessions
        .where(
          (session) =>
              session.parentId == null &&
              session.archivedAt == null,
        )
        .toList(growable: false);
    final selectedSessionId = visibleSessions.isNotEmpty
        ? visibleSessions.first.id
        : (sessions.isEmpty ? null : sessions.first.id);
    final messages = selectedSessionId == null
        ? const <ChatMessage>[]
        : await fetchMessages(
            profile: profile,
            project: project,
            sessionId: selectedSessionId,
          );

    return ChatSessionBundle(
      sessions: sessions,
      statuses: statuses,
      messages: messages,
      selectedSessionId: selectedSessionId,
    );
  }

  Future<List<ChatMessage>> fetchMessages({
    required ServerProfile profile,
    required ProjectTarget project,
    required String sessionId,
  }) async {
    final baseUri = profile.uriOrNull;
    if (baseUri == null) {
      throw const FormatException('Invalid server profile URL.');
    }

    final headers = buildRequestHeaders(profile, accept: 'application/json');

    final messagesBody = await _getJson(
      baseUri,
      '/session/$sessionId/message',
      headers: headers,
      query: <String, String>{'directory': project.directory, 'limit': '100'},
    );

    return messagesBody is List
        ? messagesBody
              .whereType<Map>()
              .map((item) => _safeParseMessage(item.cast<String, Object?>()))
              .whereType<ChatMessage>()
              .toList(growable: false)
        : const <ChatMessage>[];
  }

  SessionSummary? _safeParseSession(Map<String, Object?> json) {
    try {
      return SessionSummary.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  SessionStatusSummary? _safeParseStatus(Map<String, Object?> json) {
    try {
      return SessionStatusSummary.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  ChatMessage? _safeParseMessage(Map<String, Object?> json) {
    try {
      return ChatMessage.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<Object?> _getJson(
    Uri baseUri,
    String path, {
    required Map<String, String> headers,
    Map<String, String>? query,
  }) async {
    final basePath = switch (baseUri.path) {
      '' => '/',
      final value when value.endsWith('/') => value,
      final value => '$value/',
    };
    final uri = baseUri
        .replace(path: basePath)
        .resolve(path.startsWith('/') ? path.substring(1) : path)
        .replace(queryParameters: query);
    final response = await _client.get(uri, headers: headers);
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

  void dispose() {
    _client.close();
  }
}
