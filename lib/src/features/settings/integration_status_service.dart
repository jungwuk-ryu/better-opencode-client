import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/connection/connection_models.dart';
import '../../core/network/request_headers.dart';
import '../projects/project_models.dart';

class IntegrationStatusSnapshot {
  const IntegrationStatusSnapshot({
    required this.providerAuth,
    required this.mcpStatus,
    required this.lspStatus,
    required this.formatterStatus,
  });

  final Map<String, List<String>> providerAuth;
  final Map<String, String> mcpStatus;
  final Map<String, String> lspStatus;
  final Map<String, bool> formatterStatus;
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
    final lspBody = await _getJson(
      profile: profile,
      project: project,
      path: '/lsp',
    );
    final formatterBody = await _getJson(
      profile: profile,
      project: project,
      path: '/formatter',
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

    final lspStatus = <String, String>{};
    if (lspBody is List) {
      for (final item in lspBody.whereType<Map>()) {
        final json = item.cast<String, Object?>();
        final name = json['name']?.toString() ?? json['id']?.toString();
        if (name != null) {
          lspStatus[name] = json['status']?.toString() ?? 'unknown';
        }
      }
    }

    final formatterStatus = <String, bool>{};
    if (formatterBody is List) {
      for (final item in formatterBody.whereType<Map>()) {
        final json = item.cast<String, Object?>();
        final name = json['name']?.toString();
        if (name != null) {
          formatterStatus[name] = (json['enabled'] as bool?) ?? false;
        }
      }
    }

    return IntegrationStatusSnapshot(
      providerAuth: providerAuth,
      mcpStatus: mcpStatus,
      lspStatus: lspStatus,
      formatterStatus: formatterStatus,
    );
  }

  Future<String?> startProviderAuth({
    required ServerProfile profile,
    required ProjectTarget project,
    required String providerId,
    int method = 0,
  }) async {
    final result = await _postJson(
      profile: profile,
      project: project,
      path: '/provider/$providerId/oauth/authorize',
      body: <String, Object?>{'method': method},
    );
    if (result is! Map) {
      return null;
    }
    return result['authorizationUrl']?.toString();
  }

  Future<String?> startMcpAuth({
    required ServerProfile profile,
    required ProjectTarget project,
    required String name,
  }) async {
    final result = await _postJson(
      profile: profile,
      project: project,
      path: '/mcp/$name/auth',
      body: const <String, Object?>{},
    );
    if (result is! Map) {
      return null;
    }
    return result['authorizationUrl']?.toString();
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
    final headers = buildRequestHeaders(profile, accept: 'application/json');
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

  Future<Object?> _postJson({
    required ServerProfile profile,
    required ProjectTarget project,
    required String path,
    required Map<String, Object?> body,
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
        .resolve(path.startsWith('/') ? path.substring(1) : path)
        .replace(
          queryParameters: <String, String>{'directory': project.directory},
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
    return jsonDecode(response.body);
  }

  void dispose() {
    _client.close();
  }
}
