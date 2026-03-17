import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/connection/connection_models.dart';
import '../projects/project_models.dart';
import 'file_models.dart';

class FileBrowserService {
  FileBrowserService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<FileBrowserBundle> fetchBundle({
    required ServerProfile profile,
    required ProjectTarget project,
    String searchQuery = '',
  }) async {
    final nodesBody = await _getJson(
      profile: profile,
      path: '/file',
      project: project,
      query: <String, String>{'path': '.'},
    );
    final statusBody = await _getJson(
      profile: profile,
      path: '/file/status',
      project: project,
    );
    final searchBody = searchQuery.trim().isEmpty
        ? const <Object?>[]
        : await _getJson(
            profile: profile,
            path: '/find/file',
            project: project,
            query: <String, String>{
              'query': searchQuery,
              'dirs': 'true',
              'limit': '8',
            },
          );
    final textSearchBody = searchQuery.trim().isEmpty
        ? const <Object?>[]
        : await _getJson(
            profile: profile,
            path: '/find',
            project: project,
            query: <String, String>{'pattern': searchQuery},
          );
    final symbolBody = searchQuery.trim().isEmpty
        ? const <Object?>[]
        : await _getJson(
            profile: profile,
            path: '/find/symbol',
            project: project,
            query: <String, String>{'query': searchQuery},
          );

    final nodes = nodesBody is List
        ? nodesBody
              .whereType<Map>()
              .map(
                (item) =>
                    FileNodeSummary.fromJson(item.cast<String, Object?>()),
              )
              .toList(growable: false)
        : const <FileNodeSummary>[];
    final statuses = statusBody is List
        ? statusBody
              .whereType<Map>()
              .map(
                (item) =>
                    FileStatusSummary.fromJson(item.cast<String, Object?>()),
              )
              .toList(growable: false)
        : const <FileStatusSummary>[];
    final searchResults = searchBody is List
        ? searchBody.map((item) => item.toString()).toList(growable: false)
        : const <String>[];
    final textMatches = textSearchBody is List
        ? textSearchBody
              .whereType<Map>()
              .map(
                (item) =>
                    TextMatchSummary.fromJson(item.cast<String, Object?>()),
              )
              .toList(growable: false)
        : const <TextMatchSummary>[];
    final symbols = symbolBody is List
        ? symbolBody
              .whereType<Map>()
              .map(
                (item) => SymbolSummary.fromJson(item.cast<String, Object?>()),
              )
              .toList(growable: false)
        : const <SymbolSummary>[];

    final selectedPath = searchResults.isNotEmpty
        ? searchResults.first
        : (nodes.isNotEmpty ? nodes.first.path : null);
    final preview = selectedPath == null
        ? null
        : await fetchFileContent(
            profile: profile,
            project: project,
            path: selectedPath,
          );

    return FileBrowserBundle(
      nodes: nodes,
      searchResults: searchResults,
      textMatches: textMatches,
      symbols: symbols,
      statuses: statuses,
      preview: preview,
      selectedPath: selectedPath,
    );
  }

  Future<FileContentSummary?> fetchFileContent({
    required ServerProfile profile,
    required ProjectTarget project,
    required String path,
  }) async {
    final body = await _getJson(
      profile: profile,
      path: '/file/content',
      project: project,
      query: <String, String>{'path': path},
    );
    if (body is! Map) {
      return null;
    }
    return FileContentSummary.fromJson(body.cast<String, Object?>());
  }

  Future<Object?> _getJson({
    required ServerProfile profile,
    required String path,
    required ProjectTarget project,
    Map<String, String>? query,
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
    final merged = <String, String>{'directory': project.directory, ...?query};
    final uri = baseUri
        .replace(path: basePath)
        .resolve(path.startsWith('/') ? path.substring(1) : path)
        .replace(queryParameters: merged);
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
