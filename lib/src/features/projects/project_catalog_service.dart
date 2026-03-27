import 'dart:collection';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/connection/connection_models.dart';
import '../../core/network/request_headers.dart';
import 'project_models.dart';

class ProjectCatalogService {
  ProjectCatalogService({
    http.Client? client,
    int pathInfoCacheSize = 8,
    int directoryListCacheSize = 96,
  }) : assert(pathInfoCacheSize > 0),
       assert(directoryListCacheSize > 0),
       _client = client ?? http.Client(),
       _pathInfoCache = _FutureLruCache<String, PathInfo?>(
         maximumSize: pathInfoCacheSize,
       ),
       _directoryListCache = _FutureLruCache<String, List<_DirectoryCandidate>>(
         maximumSize: directoryListCacheSize,
       );

  final http.Client _client;
  final _FutureLruCache<String, PathInfo?> _pathInfoCache;
  final _FutureLruCache<String, List<_DirectoryCandidate>> _directoryListCache;

  Future<ProjectCatalog> fetchCatalog(ServerProfile profile) async {
    final baseUri = profile.uriOrNull;
    if (baseUri == null) {
      throw const FormatException('Invalid server profile URL.');
    }

    final headers = buildRequestHeaders(profile, accept: 'application/json');

    final currentBody = await _getJson(
      baseUri,
      '/project/current',
      headers: headers,
    );
    final listBody = await _getJson(baseUri, '/project', headers: headers);
    final pathBody = await _getJson(baseUri, '/path', headers: headers);
    final vcsBody = await _getJson(baseUri, '/vcs', headers: headers);

    final currentMap = currentBody is Map
        ? currentBody.cast<String, Object?>()
        : null;
    final projectList = listBody is List
        ? listBody
              .whereType<Map>()
              .map(
                (item) => ProjectSummary.fromJson(item.cast<String, Object?>()),
              )
              .toList(growable: false)
        : const <ProjectSummary>[];

    final pathInfo = pathBody is Map
        ? PathInfo.fromJson(pathBody.cast<String, Object?>())
        : null;
    if (pathInfo != null) {
      _pathInfoCache.set(profile.storageKey, Future<PathInfo?>.value(pathInfo));
    }

    return ProjectCatalog(
      currentProject: currentMap == null
          ? null
          : ProjectSummary.fromJson(currentMap),
      projects: projectList,
      pathInfo: pathInfo,
      vcsInfo: vcsBody is Map
          ? VcsInfo.fromJson(vcsBody.cast<String, Object?>())
          : null,
    );
  }

  Future<ProjectTarget> inspectDirectory({
    required ServerProfile profile,
    required String directory,
  }) async {
    final baseUri = profile.uriOrNull;
    if (baseUri == null) {
      throw const FormatException('Invalid server profile URL.');
    }

    final headers = buildRequestHeaders(profile, accept: 'application/json');

    Uri withDirectory(String path) {
      final uri = baseUri.resolve(
        path.startsWith('/') ? path.substring(1) : path,
      );
      final query = Map<String, String>.from(uri.queryParameters);
      query['directory'] = directory;
      return uri.replace(queryParameters: query);
    }

    final currentBody = await _getJsonUri(
      withDirectory('/project/current'),
      headers: headers,
    );
    final pathBody = await _getJsonUri(
      withDirectory('/path'),
      headers: headers,
    );
    final vcsBody = await _getJsonUri(withDirectory('/vcs'), headers: headers);

    final project = currentBody is Map
        ? ProjectSummary.fromJson(currentBody.cast<String, Object?>())
        : ProjectSummary(
            id: directory,
            directory: directory,
            worktree: directory,
            name: null,
            vcs: null,
            updatedAt: null,
          );
    final pathInfo = pathBody is Map
        ? PathInfo.fromJson(pathBody.cast<String, Object?>())
        : null;
    final vcsInfo = vcsBody is Map
        ? VcsInfo.fromJson(vcsBody.cast<String, Object?>())
        : null;

    return ProjectTarget(
      id: project.id,
      directory: pathInfo?.directory.isNotEmpty == true
          ? pathInfo!.directory
          : directory,
      label: project.title,
      name: project.name,
      source: 'manual',
      vcs: project.vcs,
      branch: vcsInfo?.branch,
      icon: project.icon,
      commands: project.commands,
    );
  }

  Future<List<String>> suggestDirectories({
    required ServerProfile profile,
    required String input,
    PathInfo? pathInfo,
    int limit = 8,
  }) async {
    final cleaned = _cleanDirectoryInput(input);
    if (cleaned.isEmpty) {
      return const <String>[];
    }

    final raw = _normalizeDriveRoot(cleaned);
    final resolvedPathInfo = pathInfo ?? await _resolvePathInfo(profile);
    final home = _trimDirectoryPath(resolvedPathInfo?.home ?? '');
    final start =
        _firstNonEmpty(<String?>[
          home,
          resolvedPathInfo?.directory,
          resolvedPathInfo?.worktree,
          _rootOfDirectoryPath(raw),
        ]) ??
        '/';
    final scoped = _scopedDirectoryInput(raw, start: start, home: home);
    if (scoped == null) {
      return const <String>[];
    }

    final isPathLike =
        raw.startsWith('~') ||
        _rootOfDirectoryPath(raw).isNotEmpty ||
        raw.contains('/');
    final query = _normalizeDriveRoot(scoped.path);
    if (!isPathLike) {
      return _findDirectories(
        profile: profile,
        directory: scoped.directory,
        query: query,
        limit: limit,
      );
    }

    final trimmedQuery = query.replaceFirst(RegExp(r'^/+'), '');
    final segments = trimmedQuery.split('/');
    final head = <String>[
      for (var index = 0; index < segments.length - 1; index += 1)
        if (segments[index].isNotEmpty && segments[index] != '.')
          segments[index],
    ];
    final tail = segments.isEmpty ? '' : segments.last;

    var paths = <String>[scoped.directory];
    const branchLimit = 4;
    const branchCap = 12;

    for (final segment in head) {
      if (segment == '..') {
        paths = paths
            .map(_parentDirectoryPath)
            .toSet()
            .take(branchCap)
            .toList(growable: false);
        continue;
      }

      final next = <String>{};
      for (final path in paths) {
        next.addAll(
          await _matchDirectoryChildren(
            profile: profile,
            directory: path,
            query: segment,
            limit: branchLimit,
          ),
        );
      }
      paths = next.take(branchCap).toList(growable: false);
      if (paths.isEmpty) {
        return const <String>[];
      }
    }

    final matches = <String>{};
    for (final path in paths) {
      matches.addAll(
        await _matchDirectoryChildren(
          profile: profile,
          directory: path,
          query: tail,
          limit: limit * 4,
        ),
      );
    }
    final suggestions = matches.toList(growable: false);
    if (!raw.endsWith('/') && tail.isNotEmpty) {
      String? exactPath;
      for (final suggestion in suggestions) {
        if (_directoryBasename(suggestion).toLowerCase() ==
            tail.toLowerCase()) {
          exactPath = suggestion;
          break;
        }
      }
      if (exactPath != null) {
        final children = await _matchDirectoryChildren(
          profile: profile,
          directory: exactPath,
          query: '',
          limit: limit,
        );
        final expanded = <String>{...suggestions, ...children};
        return expanded.take(limit).toList(growable: false);
      }
    }
    return suggestions.take(limit).toList(growable: false);
  }

  Future<ProjectTarget> updateProject({
    required ServerProfile profile,
    required ProjectTarget project,
    String? name,
    ProjectIconInfo? icon,
    ProjectCommandsInfo? commands,
  }) async {
    final baseUri = profile.uriOrNull;
    if (baseUri == null) {
      throw const FormatException('Invalid server profile URL.');
    }

    final projectId = project.id?.trim();
    if (projectId == null || projectId.isEmpty) {
      throw StateError('Project id is required to update project.');
    }

    final headers = <String, String>{
      ...buildRequestHeaders(profile, accept: 'application/json'),
      'content-type': 'application/json',
    };
    final uri = baseUri.resolve('project/$projectId');
    final queryParameters = Map<String, String>.from(uri.queryParameters);
    final directory = project.directory.trim();
    if (directory.isNotEmpty) {
      queryParameters['directory'] = directory;
    }
    final requestUri = uri.replace(queryParameters: queryParameters);
    final body = <String, Object?>{'name': name?.trim() ?? ''};
    final iconPayload = _buildIconPayload(icon);
    if (iconPayload != null) {
      body['icon'] = iconPayload;
    }
    body['commands'] = _buildCommandsPayload(commands);
    final response = await _client.patch(
      requestUri,
      headers: headers,
      body: jsonEncode(body),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Request failed for $requestUri with status ${response.statusCode}.',
      );
    }
    if (response.body.trim().isEmpty) {
      throw StateError('Project update response was empty.');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const FormatException('Unexpected project update payload.');
    }
    final summary = ProjectSummary.fromJson(decoded.cast<String, Object?>());
    return ProjectTarget(
      id: summary.id,
      directory: summary.directory,
      label: summary.title,
      name: summary.name,
      source: project.source,
      vcs: summary.vcs ?? project.vcs,
      branch: project.branch,
      icon: summary.icon,
      commands: summary.commands,
      lastSession: project.lastSession,
    );
  }

  Map<String, Object?>? _buildIconPayload(ProjectIconInfo? icon) {
    if (icon == null) {
      return null;
    }
    final payload = <String, Object?>{};
    final url = _trimToNull(icon.url);
    if (url != null) {
      payload['url'] = url;
    } else if (icon.url != null) {
      payload['url'] = '';
    }

    final override = _trimToNull(icon.override);
    if (override != null) {
      payload['override'] = override;
    } else if (icon.override != null) {
      payload['override'] = '';
    }

    final color = _trimToNull(icon.color);
    if (color != null) {
      payload['color'] = color;
    }
    return payload.isEmpty ? null : payload;
  }

  Map<String, Object?> _buildCommandsPayload(ProjectCommandsInfo? commands) {
    return <String, Object?>{'start': commands?.start?.trim() ?? ''};
  }

  String? _trimToNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  Future<PathInfo?> _resolvePathInfo(ServerProfile profile) {
    final storageKey = profile.storageKey;
    final existing = _pathInfoCache.get(storageKey);
    if (existing != null) {
      return existing;
    }

    final request = () async {
      final baseUri = profile.uriOrNull;
      if (baseUri == null) {
        throw const FormatException('Invalid server profile URL.');
      }
      final headers = buildRequestHeaders(profile, accept: 'application/json');
      final body = await _getJson(baseUri, '/path', headers: headers);
      if (body is! Map) {
        return null;
      }
      return PathInfo.fromJson(body.cast<String, Object?>());
    }();

    _pathInfoCache.set(storageKey, request);
    return request.whenComplete(() async {
      try {
        await request;
      } catch (_) {
        _pathInfoCache.remove(storageKey);
      }
    });
  }

  Future<List<String>> _findDirectories({
    required ServerProfile profile,
    required String directory,
    required String query,
    required int limit,
  }) async {
    final baseUri = profile.uriOrNull;
    if (baseUri == null) {
      throw const FormatException('Invalid server profile URL.');
    }
    final headers = buildRequestHeaders(profile, accept: 'application/json');
    final uri = _buildQueryUri(
      baseUri,
      '/find/file',
      queryParameters: <String, String>{
        'directory': _trimDirectoryPath(directory),
        'query': query,
        'type': 'directory',
        'limit': '$limit',
      },
    );
    final body = await _getJsonUri(uri, headers: headers);
    if (body is! List) {
      return const <String>[];
    }

    final results = <String>{};
    for (final item in body) {
      final value = item.toString().trim();
      if (value.isEmpty) {
        continue;
      }
      results.add(
        value.startsWith('/')
            ? _trimDirectoryPath(value)
            : _joinDirectoryPath(directory, value),
      );
    }
    return results.take(limit).toList(growable: false);
  }

  Future<List<String>> _matchDirectoryChildren({
    required ServerProfile profile,
    required String directory,
    required String query,
    required int limit,
  }) async {
    final directories = await _listDirectories(
      profile: profile,
      directory: directory,
    );
    final normalizedQuery = query.trim().toLowerCase();
    final ranked = <_RankedDirectoryCandidate>[];
    for (final candidate in directories) {
      final lowerName = candidate.name.toLowerCase();
      if (normalizedQuery.isNotEmpty && !lowerName.contains(normalizedQuery)) {
        continue;
      }
      ranked.add(
        _RankedDirectoryCandidate(
          candidate: candidate,
          lowerName: lowerName,
          score: _directoryMatchScore(lowerName, normalizedQuery),
        ),
      );
    }
    ranked.sort((a, b) {
      if (a.score != b.score) {
        return a.score.compareTo(b.score);
      }
      if (a.candidate.name.length != b.candidate.name.length) {
        return a.candidate.name.length.compareTo(b.candidate.name.length);
      }
      return a.lowerName.compareTo(b.lowerName);
    });

    return ranked
        .map((entry) => entry.candidate.absolute)
        .take(limit)
        .toList(growable: false);
  }

  int _directoryMatchScore(String lowerCandidate, String query) {
    if (query.isEmpty) {
      return 0;
    }
    if (lowerCandidate == query) {
      return 0;
    }
    if (lowerCandidate.startsWith(query)) {
      return 1;
    }
    if (lowerCandidate.contains(query)) {
      return 2;
    }
    return 3;
  }

  Future<List<_DirectoryCandidate>> _listDirectories({
    required ServerProfile profile,
    required String directory,
  }) {
    final normalizedDirectory = _trimDirectoryPath(directory);
    final cacheKey = '${profile.storageKey}\n$normalizedDirectory';
    final existing = _directoryListCache.get(cacheKey);
    if (existing != null) {
      return existing;
    }

    final request = () async {
      final baseUri = profile.uriOrNull;
      if (baseUri == null) {
        throw const FormatException('Invalid server profile URL.');
      }
      final headers = buildRequestHeaders(profile, accept: 'application/json');
      final uri = _buildQueryUri(
        baseUri,
        '/file',
        queryParameters: <String, String>{
          'directory': normalizedDirectory,
          'path': '',
        },
      );
      final body = await _getJsonUri(uri, headers: headers);
      if (body is! List) {
        return const <_DirectoryCandidate>[];
      }
      final seen = <String>{};
      final results = <_DirectoryCandidate>[];
      for (final item in body.whereType<Map>()) {
        final json = item.cast<String, Object?>();
        if (json['type']?.toString() != 'directory') {
          continue;
        }
        final absolute =
            _trimToNull(json['absolute']?.toString()) ??
            _resolveDirectoryAbsolute(
              baseDirectory: normalizedDirectory,
              relativePath:
                  _trimToNull(json['path']?.toString()) ??
                  _trimToNull(json['name']?.toString()) ??
                  '',
            );
        if (absolute == null || !seen.add(absolute)) {
          continue;
        }
        results.add(
          _DirectoryCandidate(
            name:
                _trimToNull(json['name']?.toString()) ??
                _directoryBasename(absolute),
            absolute: absolute,
          ),
        );
      }
      return results;
    }();

    _directoryListCache.set(cacheKey, request);
    return request.whenComplete(() async {
      try {
        await request;
      } catch (_) {
        _directoryListCache.remove(cacheKey);
      }
    });
  }

  String? _resolveDirectoryAbsolute({
    required String baseDirectory,
    required String relativePath,
  }) {
    final trimmed = relativePath.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    if (_rootOfDirectoryPath(trimmed).isNotEmpty || trimmed.startsWith('/')) {
      return _trimDirectoryPath(trimmed);
    }
    return _joinDirectoryPath(baseDirectory, trimmed);
  }

  Uri _buildQueryUri(
    Uri baseUri,
    String path, {
    required Map<String, String> queryParameters,
  }) {
    final uri = baseUri.resolve(
      path.startsWith('/') ? path.substring(1) : path,
    );
    return uri.replace(queryParameters: queryParameters);
  }

  Future<Object?> _getJson(
    Uri baseUri,
    String path, {
    required Map<String, String> headers,
  }) {
    return _getJsonUri(
      baseUri.resolve(path.startsWith('/') ? path.substring(1) : path),
      headers: headers,
    );
  }

  Future<Object?> _getJsonUri(
    Uri uri, {
    required Map<String, String> headers,
  }) async {
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
    _pathInfoCache.clear();
    _directoryListCache.clear();
    _client.close();
  }
}

class _ScopedDirectoryInput {
  const _ScopedDirectoryInput({required this.directory, required this.path});

  final String directory;
  final String path;
}

class _DirectoryCandidate {
  const _DirectoryCandidate({required this.name, required this.absolute});

  final String name;
  final String absolute;
}

class _RankedDirectoryCandidate {
  const _RankedDirectoryCandidate({
    required this.candidate,
    required this.lowerName,
    required this.score,
  });

  final _DirectoryCandidate candidate;
  final String lowerName;
  final int score;
}

class _FutureLruCache<K, V> {
  _FutureLruCache({required this.maximumSize});

  final int maximumSize;
  final LinkedHashMap<K, Future<V>> _entries = LinkedHashMap<K, Future<V>>();

  Future<V>? get(K key) {
    if (!_entries.containsKey(key)) {
      return null;
    }
    final value = _entries.remove(key)!;
    _entries[key] = value;
    return value;
  }

  void set(K key, Future<V> value) {
    _entries.remove(key);
    _entries[key] = value;
    while (_entries.length > maximumSize) {
      _entries.remove(_entries.keys.first);
    }
  }

  void remove(K key) {
    _entries.remove(key);
  }

  void clear() {
    _entries.clear();
  }
}

String _cleanDirectoryInput(String value) {
  final firstLine = (value).split(RegExp(r'\r?\n')).firstOrNull ?? '';
  return firstLine.replaceAll(RegExp(r'[\u0000-\u001F\u007F]'), '').trim();
}

String _normalizeDirectoryPath(String input) {
  final normalized = input.replaceAll('\\', '/');
  if (normalized.startsWith('//') && !normalized.startsWith('///')) {
    return '//${normalized.substring(2).replaceAll(RegExp(r'/+'), '/')}';
  }
  return normalized.replaceAll(RegExp(r'/+'), '/');
}

String _normalizeDriveRoot(String input) {
  final normalized = _normalizeDirectoryPath(input);
  if (RegExp(r'^[A-Za-z]:$').hasMatch(normalized)) {
    return '$normalized/';
  }
  return normalized;
}

String _trimDirectoryPath(String input) {
  final normalized = _normalizeDriveRoot(input);
  if (normalized == '/' || normalized == '//' || normalized.isEmpty) {
    return normalized;
  }
  if (RegExp(r'^[A-Za-z]:/$').hasMatch(normalized)) {
    return normalized;
  }
  return normalized.replaceFirst(RegExp(r'/+$'), '');
}

String _joinDirectoryPath(String base, String relative) {
  final trimmedBase = _trimDirectoryPath(base);
  final trimmedRelative = _trimDirectoryPath(
    relative,
  ).replaceFirst(RegExp(r'^/+'), '');
  if (trimmedBase.isEmpty) {
    return trimmedRelative;
  }
  if (trimmedRelative.isEmpty) {
    return trimmedBase;
  }
  if (trimmedBase.endsWith('/')) {
    return '$trimmedBase$trimmedRelative';
  }
  return '$trimmedBase/$trimmedRelative';
}

String _rootOfDirectoryPath(String input) {
  final normalized = _normalizeDriveRoot(input);
  if (normalized.startsWith('//')) {
    return '//';
  }
  if (normalized.startsWith('/')) {
    return '/';
  }
  final match = RegExp(r'^[A-Za-z]:/').firstMatch(normalized);
  if (match != null) {
    return match.group(0)!;
  }
  return '';
}

String _parentDirectoryPath(String input) {
  final normalized = _trimDirectoryPath(input);
  if (normalized == '/' ||
      normalized == '//' ||
      RegExp(r'^[A-Za-z]:/$').hasMatch(normalized)) {
    return normalized;
  }

  final index = normalized.lastIndexOf('/');
  if (index <= 0) {
    return '/';
  }
  if (index == 2 && RegExp(r'^[A-Za-z]:').hasMatch(normalized)) {
    return normalized.substring(0, 3);
  }
  return normalized.substring(0, index);
}

String _directoryBasename(String input) {
  final normalized = _trimDirectoryPath(input);
  if (normalized == '/' || normalized == '//' || normalized.isEmpty) {
    return normalized;
  }
  final segments = normalized.split('/');
  for (var index = segments.length - 1; index >= 0; index -= 1) {
    final segment = segments[index].trim();
    if (segment.isNotEmpty) {
      return segment;
    }
  }
  return normalized;
}

_ScopedDirectoryInput? _scopedDirectoryInput(
  String value, {
  required String start,
  required String home,
}) {
  final normalizedStart = _trimDirectoryPath(start);
  if (normalizedStart.isEmpty) {
    return null;
  }

  final raw = _normalizeDriveRoot(value);
  if (raw.isEmpty) {
    return _ScopedDirectoryInput(directory: normalizedStart, path: '');
  }

  final normalizedHome = _trimDirectoryPath(home);
  if (raw == '~') {
    return _ScopedDirectoryInput(
      directory: normalizedHome.isNotEmpty ? normalizedHome : normalizedStart,
      path: '',
    );
  }
  if (raw.startsWith('~/')) {
    return _ScopedDirectoryInput(
      directory: normalizedHome.isNotEmpty ? normalizedHome : normalizedStart,
      path: raw.substring(2),
    );
  }

  final root = _rootOfDirectoryPath(raw);
  if (root.isNotEmpty) {
    return _ScopedDirectoryInput(
      directory: _trimDirectoryPath(root),
      path: raw.substring(root.length),
    );
  }

  return _ScopedDirectoryInput(directory: normalizedStart, path: raw);
}

String? _firstNonEmpty(Iterable<String?> values) {
  for (final value in values) {
    final trimmed = _trimDirectoryPath(value ?? '');
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
  }
  return null;
}

extension on List<String> {
  String? get firstOrNull => isEmpty ? null : first;
}
