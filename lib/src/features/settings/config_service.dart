import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/connection/connection_models.dart';
import '../../core/spec/raw_json_document.dart';
import '../projects/project_models.dart';

class ConfigSnapshot {
  const ConfigSnapshot({required this.config, required this.providerConfig});

  final RawJsonDocument config;
  final RawJsonDocument providerConfig;
}

class ConfigService {
  ConfigService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<ConfigSnapshot> fetch({
    required ServerProfile profile,
    required ProjectTarget project,
  }) async {
    final configBody = await _getJson(
      profile: profile,
      project: project,
      path: '/config',
    );
    final providerBody = await _getJson(
      profile: profile,
      project: project,
      path: '/config/providers',
    );
    return ConfigSnapshot(
      config: RawJsonDocument((configBody as Map).cast<String, Object?>()),
      providerConfig: RawJsonDocument(
        (providerBody as Map).cast<String, Object?>(),
      ),
    );
  }

  Future<RawJsonDocument> updateConfig({
    required ServerProfile profile,
    required ProjectTarget project,
    required Map<String, Object?> config,
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
        .resolve('config')
        .replace(
          queryParameters: <String, String>{'directory': project.directory},
        );
    final response = await _client.patch(
      uri,
      headers: headers,
      body: jsonEncode(config),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Request failed for $uri with status ${response.statusCode}.',
      );
    }
    return RawJsonDocument(
      (jsonDecode(response.body) as Map).cast<String, Object?>(),
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
