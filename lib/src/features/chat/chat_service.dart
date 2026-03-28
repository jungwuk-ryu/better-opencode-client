import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/connection/connection_models.dart';
import '../../core/network/request_headers.dart';
import '../projects/project_models.dart';
import 'chat_models.dart';
import 'prompt_attachment_models.dart';

class ChatService {
  ChatService({http.Client? client, int? sessionHistoryPageSize})
    : _client = client ?? http.Client(),
      _sessionHistoryPageSizeOverride = sessionHistoryPageSize;

  static const int defaultSessionHistoryPageSize = 50;
  static const int maxSessionMessageResponseBytes = 16 * 1024 * 1024;
  static int _globalSessionHistoryPageSize = defaultSessionHistoryPageSize;

  final http.Client _client;
  final int? _sessionHistoryPageSizeOverride;

  static int get globalSessionHistoryPageSize => _globalSessionHistoryPageSize;

  static set globalSessionHistoryPageSize(int value) {
    _globalSessionHistoryPageSize = value;
  }

  int get sessionHistoryPageSize =>
      _sessionHistoryPageSizeOverride ?? _globalSessionHistoryPageSize;

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
    List<PromptAttachment> attachments = const <PromptAttachment>[],
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
    final body = _buildPromptRequestBody(
      prompt: prompt,
      attachments: attachments,
      agent: agent,
      providerId: providerId,
      modelId: modelId,
      variant: variant,
      reasoning: reasoning,
    );
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

  Future<bool> sendMessageAsync({
    required ServerProfile profile,
    required ProjectTarget project,
    required String sessionId,
    required String prompt,
    List<PromptAttachment> attachments = const <PromptAttachment>[],
    String? messageId,
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
        .resolve('session/$sessionId/prompt_async')
        .replace(
          queryParameters: <String, String>{'directory': project.directory},
        );
    final body = _buildPromptRequestBody(
      prompt: prompt,
      attachments: attachments,
      messageId: messageId,
      agent: agent,
      providerId: providerId,
      modelId: modelId,
      variant: variant,
      reasoning: reasoning,
    );
    final response = await _client.post(
      uri,
      headers: headers,
      body: jsonEncode(body),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return true;
    }
    if (response.statusCode == 404 ||
        response.statusCode == 405 ||
        response.statusCode == 501) {
      return false;
    }
    throw StateError(
      'Request failed for $uri with status ${response.statusCode}.',
    );
  }

  Future<ChatMessage> sendCommand({
    required ServerProfile profile,
    required ProjectTarget project,
    required String sessionId,
    required String command,
    String arguments = '',
    List<PromptAttachment> attachments = const <PromptAttachment>[],
    String? agent,
    String? providerId,
    String? modelId,
    String? variant,
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
        .resolve('session/$sessionId/command')
        .replace(
          queryParameters: <String, String>{'directory': project.directory},
        );
    final body = <String, Object?>{
      'command': command.trim(),
      'arguments': arguments,
      if (attachments.isNotEmpty)
        'parts': attachments
            .map(
              (attachment) => <String, Object?>{
                'type': 'file',
                'mime': attachment.mime,
                'filename': attachment.filename,
                'url': attachment.url,
              },
            )
            .toList(growable: false),
    };
    if (agent != null && agent.isNotEmpty) {
      body['agent'] = agent;
    }
    if (providerId != null &&
        providerId.isNotEmpty &&
        modelId != null &&
        modelId.isNotEmpty) {
      body['model'] = '$providerId/$modelId';
    }
    final resolvedVariant = variant?.trim();
    if (resolvedVariant != null && resolvedVariant.isNotEmpty) {
      body['variant'] = resolvedVariant;
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
    bool includeSelectedSessionMessages = true,
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
          (session) => session.parentId == null && session.archivedAt == null,
        )
        .toList(growable: false);
    final selectedSessionId = visibleSessions.isNotEmpty
        ? visibleSessions.first.id
        : (sessions.isEmpty ? null : sessions.first.id);
    final messages = !includeSelectedSessionMessages || selectedSessionId == null
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
    final page = await fetchMessagesPage(
      profile: profile,
      project: project,
      sessionId: sessionId,
      limit: sessionHistoryPageSize,
    );
    return page.messages;
  }

  Future<ChatMessagePage> fetchMessagesPage({
    required ServerProfile profile,
    required ProjectTarget project,
    required String sessionId,
    required int limit,
    String? before,
  }) async {
    final baseUri = profile.uriOrNull;
    if (baseUri == null) {
      throw const FormatException('Invalid server profile URL.');
    }

    final headers = buildRequestHeaders(profile, accept: 'application/json');
    final query = <String, String>{
      'directory': project.directory,
      'limit': '$limit',
    };
    final trimmedBefore = before?.trim();
    if (trimmedBefore != null && trimmedBefore.isNotEmpty) {
      query['before'] = trimmedBefore;
    }

    final response = await _getResponse(
      baseUri,
      '/session/$sessionId/message',
      headers: headers,
      query: query,
      maxResponseBytes: maxSessionMessageResponseBytes,
    );
    final messagesBody = response.body.trim().isEmpty
        ? null
        : jsonDecode(response.body);
    return messagesBody is List
        ? ChatMessagePage(
            messages: messagesBody
                .whereType<Map>()
                .map((item) => _safeParseMessage(item.cast<String, Object?>()))
                .whereType<ChatMessage>()
                .toList(growable: false),
            nextCursor: response.headers['x-next-cursor'],
          )
        : ChatMessagePage(
            nextCursor: response.headers['x-next-cursor'],
            messages: const <ChatMessage>[],
          );
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
    final response = await _getResponse(
      baseUri,
      path,
      headers: headers,
      query: query,
    );
    if (response.body.trim().isEmpty) {
      return null;
    }
    return jsonDecode(response.body);
  }

  Future<http.Response> _getResponse(
    Uri baseUri,
    String path, {
    required Map<String, String> headers,
    Map<String, String>? query,
    int? maxResponseBytes,
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
    if (maxResponseBytes == null) {
      final response = await _client.get(uri, headers: headers);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError(
          'Request failed for $uri with status ${response.statusCode}.',
        );
      }
      return response;
    }
    final request = http.Request('GET', uri)..headers.addAll(headers);
    final response = await _client.send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Request failed for $uri with status ${response.statusCode}.',
      );
    }
    final advertisedLength = int.tryParse(response.headers['content-length'] ?? '');
    if (advertisedLength != null && advertisedLength > maxResponseBytes) {
      throw StateError(
        'Session payload too large to load safely from $uri '
        '(${_formatByteCount(advertisedLength)} > ${_formatByteCount(maxResponseBytes)}).',
      );
    }
    final bodyBytes = <int>[];
    var receivedBytes = 0;
    await for (final chunk in response.stream) {
      receivedBytes += chunk.length;
      if (receivedBytes > maxResponseBytes) {
        throw StateError(
          'Session payload too large to load safely from $uri '
          '(>${_formatByteCount(maxResponseBytes)} received).',
        );
      }
      bodyBytes.addAll(chunk);
    }
    return http.Response.bytes(
      bodyBytes,
      response.statusCode,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
      request: response.request,
    );
  }

  String _formatByteCount(int bytes) {
    const units = <String>['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex += 1;
    }
    final text = value >= 10 || unitIndex == 0
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
    return '$text ${units[unitIndex]}';
  }

  void dispose() {
    _client.close();
  }

  Map<String, Object?> _buildPromptRequestBody({
    required String prompt,
    required List<PromptAttachment> attachments,
    String? messageId,
    String? agent,
    String? providerId,
    String? modelId,
    String? variant,
    String? reasoning,
  }) {
    final body = <String, Object?>{
      'parts': <Map<String, Object?>>[
        if (prompt.trim().isNotEmpty)
          <String, Object?>{'type': 'text', 'text': prompt},
        ...attachments.map(
          (attachment) => <String, Object?>{
            'type': 'file',
            'mime': attachment.mime,
            'filename': attachment.filename,
            'url': attachment.url,
          },
        ),
      ],
    };
    final resolvedMessageId = messageId?.trim();
    if (resolvedMessageId != null && resolvedMessageId.isNotEmpty) {
      body['messageID'] = resolvedMessageId;
    }
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
    return body;
  }
}
