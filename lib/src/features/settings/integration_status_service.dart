import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/connection/connection_models.dart';
import '../../core/network/request_headers.dart';
import '../../core/network/request_uri.dart';
import '../projects/project_models.dart';

class McpIntegrationStatus {
  const McpIntegrationStatus({required this.status, this.error});

  final String status;
  final String? error;

  bool get connected => status == 'connected';
  bool get needsAuth => status == 'needs_auth';
}

class IntegrationStatusSnapshot {
  const IntegrationStatusSnapshot({
    required this.providerAuth,
    required this.mcpDetails,
    required this.lspStatus,
    required this.formatterStatus,
  });

  final Map<String, List<String>> providerAuth;
  final Map<String, McpIntegrationStatus> mcpDetails;
  final Map<String, String> lspStatus;
  final Map<String, bool> formatterStatus;

  Map<String, String> get mcpStatus => <String, String>{
    for (final entry in mcpDetails.entries) entry.key: entry.value.status,
  };
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
    final mcpDetails = await fetchMcpDetails(
      profile: profile,
      project: project,
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
      mcpDetails: mcpDetails,
      lspStatus: lspStatus,
      formatterStatus: formatterStatus,
    );
  }

  Future<Map<String, McpIntegrationStatus>> fetchMcpDetails({
    required ServerProfile profile,
    required ProjectTarget project,
  }) async {
    final mcpBody = await _getJson(
      profile: profile,
      project: project,
      path: '/mcp',
    );
    return _parseMcpDetails(mcpBody);
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
    return _authorizationUrlFromResult(result);
  }

  Future<String?> startMcpAuth({
    required ServerProfile profile,
    required ProjectTarget project,
    required String name,
    String? redirectUri,
  }) async {
    final resolvedRedirectUri =
        _normalizedOptional(redirectUri) ?? _defaultMcpRedirectUri(profile);
    final result = await _postJsonWithCompatRetry(
      profile: profile,
      project: project,
      path: '/mcp/$name/auth',
      body: resolvedRedirectUri == null
          ? const <String, Object?>{}
          : <String, Object?>{'redirectUri': resolvedRedirectUri},
    );
    if (result is! Map) {
      return null;
    }
    return _authorizationUrlFromResult(result);
  }

  Future<void> connectMcp({
    required ServerProfile profile,
    required ProjectTarget project,
    required String name,
  }) async {
    await _postJson(
      profile: profile,
      project: project,
      path: '/mcp/$name/connect',
      body: const <String, Object?>{},
    );
  }

  Future<void> disconnectMcp({
    required ServerProfile profile,
    required ProjectTarget project,
    required String name,
  }) async {
    await _postJson(
      profile: profile,
      project: project,
      path: '/mcp/$name/disconnect',
      body: const <String, Object?>{},
    );
  }

  Map<String, McpIntegrationStatus> _parseMcpDetails(Object? body) {
    final mcpDetails = <String, McpIntegrationStatus>{};
    if (body is! Map) {
      return mcpDetails;
    }
    for (final entry in body.entries) {
      final value = entry.value;
      if (value is! Map) {
        continue;
      }
      mcpDetails[entry.key.toString()] = McpIntegrationStatus(
        status: value['status']?.toString() ?? 'unknown',
        error: value['error']?.toString(),
      );
    }
    return mcpDetails;
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
    final uri = buildRequestUri(
      baseUri,
      path: path,
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
    final uri = buildRequestUri(
      baseUri,
      path: path,
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

  Future<Object?> _postJsonWithCompatRetry({
    required ServerProfile profile,
    required ProjectTarget project,
    required String path,
    required Map<String, Object?> body,
  }) async {
    if (body['redirectUri'] == null) {
      return _postJson(
        profile: profile,
        project: project,
        path: path,
        body: body,
      );
    }

    try {
      return await _postJson(
        profile: profile,
        project: project,
        path: path,
        body: body,
      );
    } on StateError catch (error) {
      if (!error.toString().contains('status 400')) {
        rethrow;
      }
      return _postJson(
        profile: profile,
        project: project,
        path: path,
        body: const <String, Object?>{},
      );
    }
  }

  String? _defaultMcpRedirectUri(ServerProfile profile) {
    final baseUri = profile.uriOrNull;
    if (baseUri == null) {
      return null;
    }
    final scheme = baseUri.scheme.trim().toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      return null;
    }

    final basePath = switch (baseUri.path) {
      '' => '',
      '/' => '',
      final value when value.endsWith('/') => value.substring(
        0,
        value.length - 1,
      ),
      final value => value,
    };
    return Uri(
      scheme: baseUri.scheme,
      host: baseUri.host,
      port: baseUri.hasPort ? baseUri.port : null,
      path: '$basePath/mcp/oauth/callback',
    ).toString();
  }

  String? _normalizedOptional(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  String? _authorizationUrlFromResult(Map<dynamic, dynamic> result) {
    final primary = _normalizedOptional(result['authorizationUrl']?.toString());
    if (primary != null) {
      return primary;
    }
    return _normalizedOptional(result['url']?.toString());
  }

  void dispose() {
    _client.close();
  }
}
