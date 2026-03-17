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
      directory: pathInfo?.directory.isNotEmpty == true
          ? pathInfo!.directory
          : directory,
      label: project.title,
      source: 'manual',
      vcs: project.vcs,
      branch: vcsInfo?.branch,
    );
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
