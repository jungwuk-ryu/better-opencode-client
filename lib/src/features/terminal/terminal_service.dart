import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/connection/connection_models.dart';
import '../projects/project_models.dart';

class ShellCommandResult {
  const ShellCommandResult({
    required this.messageId,
    required this.sessionId,
    required this.modelId,
    required this.providerId,
  });

  final String messageId;
  final String sessionId;
  final String? modelId;
  final String? providerId;

  factory ShellCommandResult.fromJson(Map<String, Object?> json) {
    return ShellCommandResult(
      messageId: (json['id'] as String?) ?? '',
      sessionId: (json['sessionID'] as String?) ?? '',
      modelId: json['modelID'] as String?,
      providerId: json['providerID'] as String?,
    );
  }
}

class TerminalService {
  TerminalService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<ShellCommandResult> runShellCommand({
    required ServerProfile profile,
    required ProjectTarget project,
    required String sessionId,
    required String command,
    String agent = 'build',
  }) async {
    final baseUri = profile.uriOrNull;
    if (baseUri == null) {
      throw const FormatException('Invalid server profile URL.');
    }

    final headers = <String, String>{
      'accept': 'application/json',
      'content-type': 'application/json',
    };
    final authHeader = profile.basicAuthHeader;
    if (authHeader != null) {
      headers['authorization'] = authHeader;
    }

    final basePath = switch (baseUri.path) {
      '' => '/',
      final value when value.endsWith('/') => value,
      final value => '$value/',
    };
    final uri = baseUri
        .replace(path: basePath)
        .resolve('session/$sessionId/shell')
        .replace(
          queryParameters: <String, String>{'directory': project.directory},
        );

    final response = await _client.post(
      uri,
      headers: headers,
      body: jsonEncode(<String, Object?>{'agent': agent, 'command': command}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Request failed for $uri with status ${response.statusCode}.',
      );
    }

    return ShellCommandResult.fromJson(
      (jsonDecode(response.body) as Map).cast<String, Object?>(),
    );
  }

  void dispose() {
    _client.close();
  }
}
