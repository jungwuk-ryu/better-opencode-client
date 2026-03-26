import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/connection/connection_models.dart';
import '../../core/network/request_headers.dart';
import 'pty_models.dart';

class PtyService {
  PtyService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<PtySessionInfo>> listSessions({
    required ServerProfile profile,
    required String directory,
  }) async {
    final response = await _client.get(
      buildPtyHttpUri(profile: profile, directory: directory, path: 'pty'),
      headers: buildRequestHeaders(profile, accept: 'application/json'),
    );
    _ensureSuccess(response, 'pty list');
    final decoded = jsonDecode(response.body) as List;
    return decoded
        .whereType<Map>()
        .map((item) => PtySessionInfo.fromJson(item.cast<String, Object?>()))
        .toList(growable: false);
  }

  Future<PtySessionInfo?> getSession({
    required ServerProfile profile,
    required String directory,
    required String ptyId,
  }) async {
    final response = await _client.get(
      buildPtyHttpUri(
        profile: profile,
        directory: directory,
        path: 'pty/$ptyId',
      ),
      headers: buildRequestHeaders(profile, accept: 'application/json'),
    );
    if (response.statusCode == 404) {
      return null;
    }
    _ensureSuccess(response, 'pty get');
    return PtySessionInfo.fromJson(
      (jsonDecode(response.body) as Map).cast<String, Object?>(),
    );
  }

  Future<PtySessionInfo> createSession({
    required ServerProfile profile,
    required String directory,
    String? title,
    String? cwd,
    String? command,
    List<String>? args,
    Map<String, String>? env,
  }) async {
    final body = <String, Object?>{};
    if (title != null && title.trim().isNotEmpty) {
      body['title'] = title.trim();
    }
    if (cwd != null && cwd.trim().isNotEmpty) {
      body['cwd'] = cwd.trim();
    }
    if (command != null && command.trim().isNotEmpty) {
      body['command'] = command.trim();
    }
    if (args != null && args.isNotEmpty) {
      body['args'] = args;
    }
    if (env != null && env.isNotEmpty) {
      body['env'] = env;
    }

    final response = await _client.post(
      buildPtyHttpUri(profile: profile, directory: directory, path: 'pty'),
      headers: buildRequestHeaders(
        profile,
        accept: 'application/json',
        jsonBody: true,
      ),
      body: jsonEncode(body),
    );
    _ensureSuccess(response, 'pty create');
    return PtySessionInfo.fromJson(
      (jsonDecode(response.body) as Map).cast<String, Object?>(),
    );
  }

  Future<PtySessionInfo> updateSession({
    required ServerProfile profile,
    required String directory,
    required String ptyId,
    String? title,
    PtySessionSize? size,
  }) async {
    final body = <String, Object?>{};
    if (title != null && title.trim().isNotEmpty) {
      body['title'] = title.trim();
    }
    if (size != null) {
      body['size'] = size.toJson();
    }

    final response = await _client.put(
      buildPtyHttpUri(
        profile: profile,
        directory: directory,
        path: 'pty/$ptyId',
      ),
      headers: buildRequestHeaders(
        profile,
        accept: 'application/json',
        jsonBody: true,
      ),
      body: jsonEncode(body),
    );
    _ensureSuccess(response, 'pty update');
    return PtySessionInfo.fromJson(
      (jsonDecode(response.body) as Map).cast<String, Object?>(),
    );
  }

  Future<void> removeSession({
    required ServerProfile profile,
    required String directory,
    required String ptyId,
  }) async {
    final response = await _client.delete(
      buildPtyHttpUri(
        profile: profile,
        directory: directory,
        path: 'pty/$ptyId',
      ),
      headers: buildRequestHeaders(profile, accept: 'application/json'),
    );
    if (response.statusCode == 404) {
      return;
    }
    _ensureSuccess(response, 'pty delete');
  }

  WebSocketChannel connectSession({
    required ServerProfile profile,
    required String directory,
    required String ptyId,
    int? cursor,
  }) {
    return WebSocketChannel.connect(
      buildPtyWebSocketUri(
        profile: profile,
        directory: directory,
        ptyId: ptyId,
        cursor: cursor,
      ),
    );
  }

  void dispose() {
    _client.close();
  }

  void _ensureSuccess(http.Response response, String operation) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }
    throw StateError(
      'Request failed during $operation with status ${response.statusCode}.',
    );
  }
}

Uri buildPtyHttpUri({
  required ServerProfile profile,
  required String directory,
  required String path,
  Map<String, String>? extraQueryParameters,
}) {
  final baseUri = profile.uriOrNull;
  if (baseUri == null) {
    throw const FormatException('Invalid server profile URL.');
  }

  final basePath = switch (baseUri.path) {
    '' => '/',
    final value when value.endsWith('/') => value,
    final value => '$value/',
  };
  final queryParameters = <String, String>{
    ...baseUri.queryParameters,
    'directory': directory,
    ...?extraQueryParameters,
  };

  return baseUri
      .replace(path: basePath, queryParameters: baseUri.queryParameters)
      .resolve(path)
      .replace(queryParameters: queryParameters);
}

Uri buildPtyWebSocketUri({
  required ServerProfile profile,
  required String directory,
  required String ptyId,
  int? cursor,
}) {
  final httpUri = buildPtyHttpUri(
    profile: profile,
    directory: directory,
    path: 'pty/$ptyId/connect',
    extraQueryParameters: cursor == null
        ? null
        : <String, String>{'cursor': '$cursor'},
  );

  final username = profile.username?.trim() ?? '';
  final password = profile.password ?? '';
  final userInfo = profile.hasBasicAuth ? '$username:$password' : null;

  return Uri(
    scheme: httpUri.scheme == 'https' ? 'wss' : 'ws',
    userInfo: userInfo ?? '',
    host: httpUri.host,
    port: httpUri.hasPort ? httpUri.port : null,
    path: httpUri.path,
    queryParameters: httpUri.queryParameters.isEmpty
        ? null
        : httpUri.queryParameters,
  );
}
