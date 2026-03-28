import 'dart:async';
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
  static const int _streamedDecodeYieldInterval = 8;
  static int globalSessionHistoryPageSize = defaultSessionHistoryPageSize;

  final http.Client _client;
  final int? _sessionHistoryPageSizeOverride;

  int get sessionHistoryPageSize =>
      _sessionHistoryPageSizeOverride ?? globalSessionHistoryPageSize;

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
    void Function(List<ChatMessage> messages)? onMessagesProgress,
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

    final response = await _sendGetRequest(
      baseUri,
      '/session/$sessionId/message',
      headers: headers,
      query: query,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final uri = response.request?.url ?? baseUri;
      throw StateError(
        'Request failed for $uri with status ${response.statusCode}.',
      );
    }
    return ChatMessagePage(
      messages: await _decodeMessagesFromResponse(
        response,
        maxResponseBytes: maxSessionMessageResponseBytes,
        onMessagesProgress: onMessagesProgress,
      ),
      nextCursor: response.headers['x-next-cursor'],
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

  Future<List<ChatMessage>> _decodeMessagesFromResponse(
    http.StreamedResponse response, {
    required int maxResponseBytes,
    void Function(List<ChatMessage> messages)? onMessagesProgress,
  }) async {
    final uri = response.request?.url;
    final advertisedLength = int.tryParse(
      response.headers['content-length'] ?? '',
    );
    if (advertisedLength != null && advertisedLength > maxResponseBytes) {
      throw StateError(
        'Session payload too large to load safely from ${uri ?? 'unknown request'} '
        '(${_formatByteCount(advertisedLength)} > ${_formatByteCount(maxResponseBytes)}).',
      );
    }

    final parser = _JsonArrayObjectStreamParser(
      uri: uri,
      maxResponseBytes: maxResponseBytes,
    );
    final messages = <ChatMessage>[];
    var decodedSinceYield = 0;

    await for (final chunk in response.stream
        .transform(parser.byteCountingTransformer)
        .transform(utf8.decoder)) {
      final objects = parser.addChunk(chunk);
      for (final objectJson in objects) {
        final decoded = jsonDecode(objectJson);
        if (decoded is! Map) {
          continue;
        }
        final message = _safeParseMessage(decoded.cast<String, Object?>());
        if (message != null) {
          messages.add(message);
          decodedSinceYield += 1;
        }
        if (decodedSinceYield >= _streamedDecodeYieldInterval) {
          decodedSinceYield = 0;
          onMessagesProgress?.call(
            List<ChatMessage>.unmodifiable(List<ChatMessage>.from(messages)),
          );
          await Future<void>.delayed(Duration.zero);
        }
      }
    }

    parser.close();
    if (decodedSinceYield > 0 && messages.isNotEmpty) {
      onMessagesProgress?.call(
        List<ChatMessage>.unmodifiable(List<ChatMessage>.from(messages)),
      );
    }
    return List<ChatMessage>.unmodifiable(messages);
  }

  Future<http.StreamedResponse> _sendGetRequest(
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
    final request = http.Request('GET', uri)..headers.addAll(headers);
    return _client.send(request);
  }

  Future<http.Response> _getResponse(
    Uri baseUri,
    String path, {
    required Map<String, String> headers,
    Map<String, String>? query,
    int? maxResponseBytes,
  }) async {
    final response = await _sendGetRequest(
      baseUri,
      path,
      headers: headers,
      query: query,
    );
    final uri = response.request?.url ?? baseUri;
    if (maxResponseBytes == null) {
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError(
          'Request failed for $uri with status ${response.statusCode}.',
        );
      }
      return http.Response.fromStream(response);
    }
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

class _JsonArrayObjectStreamParser {
  _JsonArrayObjectStreamParser({
    required this.uri,
    required this.maxResponseBytes,
  });

  final Uri? uri;
  final int maxResponseBytes;

  bool _startedArray = false;
  bool _finishedArray = false;
  bool _capturingObject = false;
  bool _insideString = false;
  bool _escaping = false;
  bool _sawNonWhitespace = false;
  int _bytesRead = 0;
  int _compositeDepth = 0;
  StringBuffer? _currentObject;

  StreamTransformer<List<int>, List<int>> get byteCountingTransformer =>
      StreamTransformer<List<int>, List<int>>.fromHandlers(
        handleData: (List<int> data, EventSink<List<int>> sink) {
          _bytesRead += data.length;
          if (_bytesRead > maxResponseBytes) {
            sink.addError(
              StateError(
                'Session payload too large to load safely from ${uri ?? 'unknown request'} '
                '(>${_formatStaticByteCount(maxResponseBytes)} received).',
              ),
            );
            return;
          }
          sink.add(data);
        },
      );

  List<String> addChunk(String chunk) {
    if (chunk.isEmpty) {
      return const <String>[];
    }
    final objects = <String>[];
    for (var index = 0; index < chunk.length; index += 1) {
      final codeUnit = chunk.codeUnitAt(index);

      if (_finishedArray) {
        if (!_isJsonWhitespace(codeUnit)) {
          throw const FormatException(
            'Unexpected data found after the end of the JSON array.',
          );
        }
        continue;
      }

      if (!_capturingObject) {
        if (!_startedArray) {
          if (_isJsonWhitespace(codeUnit)) {
            continue;
          }
          _sawNonWhitespace = true;
          if (codeUnit != 0x5B) {
            throw const FormatException(
              'Expected a JSON array when streaming session messages.',
            );
          }
          _startedArray = true;
          continue;
        }

        if (_isJsonWhitespace(codeUnit) || codeUnit == 0x2C) {
          continue;
        }
        if (codeUnit == 0x5D) {
          _finishedArray = true;
          continue;
        }
        if (codeUnit != 0x7B) {
          throw const FormatException(
            'Expected each session message entry to be a JSON object.',
          );
        }
        _capturingObject = true;
        _insideString = false;
        _escaping = false;
        _compositeDepth = 1;
        _currentObject = StringBuffer()..writeCharCode(codeUnit);
        continue;
      }

      final buffer = _currentObject;
      if (buffer == null) {
        throw const FormatException('JSON object parser lost its buffer state.');
      }
      buffer.writeCharCode(codeUnit);

      if (_insideString) {
        if (_escaping) {
          _escaping = false;
          continue;
        }
        if (codeUnit == 0x5C) {
          _escaping = true;
          continue;
        }
        if (codeUnit == 0x22) {
          _insideString = false;
        }
        continue;
      }

      if (codeUnit == 0x22) {
        _insideString = true;
        continue;
      }
      if (codeUnit == 0x7B || codeUnit == 0x5B) {
        _compositeDepth += 1;
        continue;
      }
      if (codeUnit == 0x7D || codeUnit == 0x5D) {
        _compositeDepth -= 1;
        if (_compositeDepth < 0) {
          throw const FormatException(
            'Unexpected closing token in streamed session JSON.',
          );
        }
        if (_compositeDepth == 0) {
          objects.add(buffer.toString());
          _capturingObject = false;
          _currentObject = null;
        }
      }
    }
    return objects;
  }

  void close() {
    if (!_sawNonWhitespace) {
      return;
    }
    if (!_startedArray || !_finishedArray || _capturingObject) {
      throw const FormatException(
        'Session message response ended before the JSON array was complete.',
      );
    }
    if (_insideString || _escaping || _compositeDepth != 0) {
      throw const FormatException(
        'Session message response ended with an incomplete JSON token.',
      );
    }
  }

  static bool _isJsonWhitespace(int codeUnit) {
    return codeUnit == 0x20 ||
        codeUnit == 0x09 ||
        codeUnit == 0x0A ||
        codeUnit == 0x0D;
  }

  static String _formatStaticByteCount(int bytes) {
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
}
