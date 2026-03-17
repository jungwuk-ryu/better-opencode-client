import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/connection/connection_models.dart';
import '../projects/project_models.dart';

class IntegrationStatusSnapshot {
  const IntegrationStatusSnapshot({
    required this.providerAuth,
    required this.mcpStatus,
  });

  final Map<String, List<String>> providerAuth;
  final Map<String, String> mcpStatus;
}

class IntegrationStatusService {
  IntegrationStatusService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  Future<IntegrationStatusSnapshot> fetch({
    required ServerProfile profile,
    required ProjectTarget project,
  }) async {
    final providerBody = await _getJson(
      profile: profile,
      project: project,
      path: '/provider/auth',
    );
    final mcpBody = await _getJson(
      profile: profile,
      project: project,
      path: '/mcp',
    );

    final providerAuth = <String, List<String>>{};
    if (providerBody is Map) {
      for (final entry in providerBody.entries) {
        final value = entry.value;
        providerAuth[entry.key.toString()] = value is List
            ? value.map((item) => item.toString()).toList(growable: false)
            : const <String>[];
      }
    }

    final mcpStatus = <String, String>{};
    if (mcpBody is Map) {
      for (final entry in mcpBody.entries) {
        final value = entry.value;
        if (value is Map) {
          mcpStatus[entry.key.toString()] =
              value['status']?.toString() ?? 'unknown';
        }
      }
    }

    return IntegrationStatusSnapshot(
      providerAuth: providerAuth,
      mcpStatus: mcpStatus,
    );
  }

  Future<Object?> _getJson({
    required ServerProfile profile,
    required ProjectTarget project,
    required String path,
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
    final basePath = switch (baseUri.path) {
      '' => '/',
      final value when value.endsWith('/') => value,
      final value => '$value/',
    };
    final uri = baseUri
        .replace(path: basePath)
        .resolve(path.startsWith('/') ? path.substring(1) : path)
        .replace(
          queryParameters: <String, String>{'directory': project.directory},
        );
    final response = await _client.get(uri, headers: headers);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Request failed for $uri with status ${response.statusCode}.',
      );
    }
    return jsonDecode(response.body);
  }

  void dispose() {
    _client.close();
  }
}
