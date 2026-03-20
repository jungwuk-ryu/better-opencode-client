import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../connection/connection_models.dart';
import '../../features/projects/project_models.dart';
import 'request_headers.dart';
import 'sse_frame.dart';
import 'sse_parser.dart';

class EventEnvelope {
  const EventEnvelope({required this.type, required this.properties});

  final String type;
  final Map<String, Object?> properties;

  factory EventEnvelope.fromFrame(SseFrame frame) {
    final decoded = frame.data.isEmpty
        ? const <String, Object?>{}
        : jsonDecode(frame.data) as Map<String, Object?>;
    return EventEnvelope(
      type: frame.event ?? decoded['type']?.toString() ?? 'message',
      properties:
          (decoded['properties'] as Map?)?.cast<String, Object?>() ?? decoded,
    );
  }
}

class EventStreamService {
  EventStreamService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  StreamSubscription<EventEnvelope>? _subscription;

  Future<void> connect({
    required ServerProfile profile,
    required ProjectTarget project,
    required void Function(EventEnvelope event) onEvent,
    void Function()? onDone,
    void Function(Object error, StackTrace stackTrace)? onError,
  }) async {
    await disconnect();

    final baseUri = profile.uriOrNull;
    if (baseUri == null) {
      throw const FormatException('Invalid server profile URL.');
    }
    final basePath = switch (baseUri.path) {
      '' => '/',
      final value when value.endsWith('/') => value,
      final value => '$value/',
    };
    final uri = baseUri
        .replace(path: basePath)
        .resolve('event')
        .replace(
          queryParameters: <String, String>{'directory': project.directory},
        );

    final headers = buildRequestHeaders(profile, accept: 'text/event-stream');

    final request = http.Request('GET', uri)..headers.addAll(headers);
    final response = await _client.send(request);

    final status = response.statusCode;
    final contentType = response.headers['content-type'];
    final isSuccess = status >= 200 && status < 300;
    final isSse =
        contentType != null &&
        contentType.toLowerCase().contains('text/event-stream');
    if (!isSuccess || !isSse) {
      await response.stream.drain<void>();
      throw http.ClientException(
        'Expected SSE response but got status=$status content-type=${contentType ?? "(missing)"}.',
        uri,
      );
    }

    final stream = const SseParser()
        .bind(response.stream)
        .map(EventEnvelope.fromFrame);
    _subscription = stream.listen(
      onEvent,
      onDone: onDone,
      onError: onError,
      cancelOnError: true,
    );
  }

  Future<void> disconnect() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  void dispose() {
    _subscription?.cancel();
    _client.close();
  }
}
