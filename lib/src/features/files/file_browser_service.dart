import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../core/connection/connection_models.dart';
import '../../core/network/request_headers.dart';
import '../../core/network/request_uri.dart';
import '../projects/project_models.dart';
import 'file_models.dart';

const int _fileNodesResponseByteLimit = 3 * 1024 * 1024;
const int _fileStatusResponseByteLimit = 2 * 1024 * 1024;
const int _fileSearchResponseByteLimit = 2 * 1024 * 1024;
const int _fileTextSearchResponseByteLimit = 2 * 1024 * 1024;
const int _fileSymbolResponseByteLimit = 2 * 1024 * 1024;
const int _fileContentResponseByteLimit = 768 * 1024;

const int _fileSearchServerLimit = 12;
const int _textMatchServerLimit = 16;
const int _symbolServerLimit = 16;

const int _fileSearchResultLimit = 12;
const int _textMatchResultLimit = 16;
const int _symbolResultLimit = 16;
const int _filePreviewCharacterLimit = 48000;

class FileBrowserService {
  FileBrowserService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<FileNodeSummary>> fetchNodes({
    required ServerProfile profile,
    required ProjectTarget project,
    String path = '.',
  }) async {
    final body = await _getJson(
      profile: profile,
      path: '/file',
      project: project,
      query: <String, String>{'path': path},
      maxResponseBytes: _fileNodesResponseByteLimit,
    );
    if (body is! List) {
      return const <FileNodeSummary>[];
    }
    return body
        .whereType<Map>()
        .map((item) => FileNodeSummary.fromJson(item.cast<String, Object?>()))
        .toList(growable: false);
  }

  Future<FileBrowserBundle> fetchBundle({
    required ServerProfile profile,
    required ProjectTarget project,
    String searchQuery = '',
  }) async {
    final nodes = await fetchNodes(
      profile: profile,
      project: project,
      path: '.',
    );
    final statusBody = await _getJson(
      profile: profile,
      path: '/file/status',
      project: project,
      maxResponseBytes: _fileStatusResponseByteLimit,
    );
    final trimmedQuery = searchQuery.trim();
    final searchBody = trimmedQuery.isEmpty
        ? const <Object?>[]
        : await _getJsonOrDefault(
            profile: profile,
            path: '/find/file',
            project: project,
            query: <String, String>{
              'query': trimmedQuery,
              'dirs': 'true',
              'limit': '$_fileSearchServerLimit',
            },
            maxResponseBytes: _fileSearchResponseByteLimit,
            fallback: const <Object?>[],
          );
    final textSearchBody = trimmedQuery.isEmpty
        ? const <Object?>[]
        : await _getJsonOrDefault(
            profile: profile,
            path: '/find',
            project: project,
            query: <String, String>{
              'pattern': trimmedQuery,
              'limit': '$_textMatchServerLimit',
            },
            maxResponseBytes: _fileTextSearchResponseByteLimit,
            fallback: const <Object?>[],
          );
    final symbolBody = trimmedQuery.isEmpty
        ? const <Object?>[]
        : await _getJsonOrDefault(
            profile: profile,
            path: '/find/symbol',
            project: project,
            query: <String, String>{
              'query': trimmedQuery,
              'limit': '$_symbolServerLimit',
            },
            maxResponseBytes: _fileSymbolResponseByteLimit,
            fallback: const <Object?>[],
          );

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
        ? searchBody
              .take(_fileSearchResultLimit)
              .map((item) => item.toString())
              .toList(growable: false)
        : const <String>[];
    final textMatches = textSearchBody is List
        ? textSearchBody
              .whereType<Map>()
              .take(_textMatchResultLimit)
              .map(
                (item) =>
                    TextMatchSummary.fromJson(item.cast<String, Object?>()),
              )
              .toList(growable: false)
        : const <TextMatchSummary>[];
    final symbols = symbolBody is List
        ? symbolBody
              .whereType<Map>()
              .take(_symbolResultLimit)
              .map(
                (item) => SymbolSummary.fromJson(item.cast<String, Object?>()),
              )
              .toList(growable: false)
        : const <SymbolSummary>[];

    return FileBrowserBundle(
      nodes: nodes,
      searchResults: searchResults,
      textMatches: textMatches,
      symbols: symbols,
      statuses: statuses,
      preview: null,
      selectedPath: null,
    );
  }

  Future<FileContentSummary?> fetchFileContent({
    required ServerProfile profile,
    required ProjectTarget project,
    required String path,
  }) async {
    try {
      final body = await _getJson(
        profile: profile,
        path: '/file/content',
        project: project,
        query: <String, String>{'path': path},
        maxResponseBytes: _fileContentResponseByteLimit,
      );
      if (body is! Map) {
        return null;
      }
      return _sanitizeFileContentSummary(
        FileContentSummary.fromJson(body.cast<String, Object?>()),
        path: path,
      );
    } on _FileBrowserPayloadTooLarge {
      return FileContentSummary(
        type: 'text',
        content:
            '[Preview omitted because the file response exceeded the safe size limit.]',
      );
    }
  }

  Future<Object?> _getJsonOrDefault({
    required ServerProfile profile,
    required String path,
    required ProjectTarget project,
    required Object? fallback,
    Map<String, String>? query,
    required int maxResponseBytes,
  }) async {
    try {
      return await _getJson(
        profile: profile,
        path: path,
        project: project,
        query: query,
        maxResponseBytes: maxResponseBytes,
      );
    } on _FileBrowserPayloadTooLarge {
      return fallback;
    }
  }

  Future<Object?> _getJson({
    required ServerProfile profile,
    required String path,
    required ProjectTarget project,
    required int maxResponseBytes,
    Map<String, String>? query,
  }) async {
    final baseUri = profile.uriOrNull;
    if (baseUri == null) {
      throw const FormatException('Invalid server profile URL.');
    }
    final headers = buildRequestHeaders(profile, accept: 'application/json');

    final merged = <String, String>{'directory': project.directory, ...?query};
    final uri = buildRequestUri(baseUri, path: path, queryParameters: merged);
    final request = http.Request('GET', uri)..headers.addAll(headers);
    final response = await _client.send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Request failed for $uri with status ${response.statusCode}.',
      );
    }
    final contentLength = response.contentLength;
    if (contentLength != null && contentLength > maxResponseBytes) {
      throw _FileBrowserPayloadTooLarge(
        'Response for $path exceeded the safe size limit.',
      );
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in response.stream) {
      bytes.add(chunk);
      if (bytes.length > maxResponseBytes) {
        throw _FileBrowserPayloadTooLarge(
          'Response for $path exceeded the safe size limit.',
        );
      }
    }
    final body = utf8.decode(bytes.takeBytes(), allowMalformed: true);
    if (body.trim().isEmpty) {
      return null;
    }
    return jsonDecode(body);
  }

  FileContentSummary _sanitizeFileContentSummary(
    FileContentSummary summary, {
    required String path,
  }) {
    final content = summary.content;
    if (content.length <= _filePreviewCharacterLimit) {
      return summary;
    }
    final truncated = content.substring(0, _filePreviewCharacterLimit);
    return FileContentSummary(
      type: summary.type,
      content:
          '$truncated\n\n[Preview truncated for $path because the file is too large to render safely.]',
    );
  }

  void dispose() {
    _client.close();
  }
}

class _FileBrowserPayloadTooLarge implements Exception {
  const _FileBrowserPayloadTooLarge(this.message);

  final String message;

  @override
  String toString() => message;
}
