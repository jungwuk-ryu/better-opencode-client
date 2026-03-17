import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/connection/connection_models.dart';
import '../projects/project_models.dart';
import 'chat_models.dart';

class ChatService {
  ChatService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<ChatSessionBundle> fetchBundle({
    required ServerProfile profile,
    required ProjectTarget project,
  }) async {
    final baseUri = profile.uriOrNull;
    if (baseUri == null) {
      throw const FormatException('Invalid server profile URL.');
    }

    final headers = <String, String>{'accept': 'application/json'};
    final authHeader = profile.basicAuthHeader;
    if (authHeader != null) {
      headers['authorization'] = authHeader;
    }

    final sessionsBody = await _getJson(
      baseUri,
      '/session',
      headers: headers,
      query: <String, String>{'directory': project.directory, 'roots': 'true'},
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
              .map(
                (item) => SessionSummary.fromJson(item.cast<String, Object?>()),
              )
              .toList(growable: false)
        : const <SessionSummary>[];
    final statuses = statusesBody is Map
        ? statusesBody.map(
            (key, value) => MapEntry(
              key.toString(),
              SessionStatusSummary.fromJson(
                (value as Map).cast<String, Object?>(),
              ),
            ),
          )
        : const <String, SessionStatusSummary>{};

    final selectedSessionId = sessions.isEmpty ? null : sessions.first.id;
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

    final headers = <String, String>{'accept': 'application/json'};
    final authHeader = profile.basicAuthHeader;
    if (authHeader != null) {
      headers['authorization'] = authHeader;
    }

    final messagesBody = await _getJson(
      baseUri,
      '/session/$sessionId/message',
      headers: headers,
      query: <String, String>{'directory': project.directory, 'limit': '100'},
    );

    return messagesBody is List
        ? messagesBody
              .whereType<Map>()
              .map((item) => ChatMessage.fromJson(item.cast<String, Object?>()))
              .toList(growable: false)
        : const <ChatMessage>[];
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
