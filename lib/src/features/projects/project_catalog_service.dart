import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/connection/connection_models.dart';
import '../../core/network/request_headers.dart';
import 'project_models.dart';

class ProjectCatalogService {
  ProjectCatalogService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

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

    return ProjectCatalog(
      currentProject: currentMap == null
          ? null
          : ProjectSummary.fromJson(currentMap),
      projects: projectList,
      pathInfo: pathBody is Map
          ? PathInfo.fromJson(pathBody.cast<String, Object?>())
          : null,
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
    final effectiveImage = _trimToNull(icon.effectiveImage);
    if (effectiveImage != null) {
      payload['url'] = effectiveImage;
    }
    final override = _trimToNull(icon.override);
    if (override != null) {
      payload['override'] = override;
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
    _client.close();
  }
}
