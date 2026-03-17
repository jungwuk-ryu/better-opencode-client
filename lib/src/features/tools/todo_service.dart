import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/connection/connection_models.dart';
import '../projects/project_models.dart';
import 'todo_models.dart';

class TodoService {
  TodoService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<TodoItem>> fetchTodos({
    required ServerProfile profile,
    required ProjectTarget project,
    required String sessionId,
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
        .resolve('session/$sessionId/todo')
        .replace(
          queryParameters: <String, String>{'directory': project.directory},
        );
    final response = await _client.get(uri, headers: headers);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Request failed for $uri with status ${response.statusCode}.',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      return const <TodoItem>[];
    }

    return decoded
        .whereType<Map>()
        .map((item) => TodoItem.fromJson(item.cast<String, Object?>()))
        .toList(growable: false);
  }

  void dispose() {
    _client.close();
  }
}
