import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/connection/connection_models.dart';
import '../../core/network/request_headers.dart';
import '../projects/project_models.dart';

class CommandDefinition {
  const CommandDefinition({
    required this.name,
    this.description,
    this.source,
    this.hints = const <String>[],
  });

  factory CommandDefinition.fromJson(Map<String, Object?> json) {
    final hints = switch (json['hints']) {
      final List<Object?> list =>
        list
            .map((item) => item?.toString().trim() ?? '')
            .where((item) => item.isNotEmpty)
            .toList(growable: false),
      _ => const <String>[],
    };
    return CommandDefinition(
      name: json['name']?.toString().trim() ?? '',
      description: json['description']?.toString().trim(),
      source: json['source']?.toString().trim(),
      hints: hints,
    );
  }

  final String name;
  final String? description;
  final String? source;
  final List<String> hints;

  bool get isValid => name.trim().isNotEmpty;
}

class CommandService {
  CommandService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<CommandDefinition>> fetchCommands({
    required ServerProfile profile,
    ProjectTarget? project,
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
    var uri = baseUri.replace(path: basePath).resolve('command');
    final directory = project?.directory.trim();
    if (directory != null && directory.isNotEmpty) {
      uri = uri.replace(
        queryParameters: <String, String>{'directory': directory},
      );
    }

    final response = await _client.get(uri, headers: headers);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Request failed for $uri with status ${response.statusCode}.',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      return const <CommandDefinition>[];
    }

    return decoded
        .whereType<Map>()
        .map((item) => CommandDefinition.fromJson(item.cast<String, Object?>()))
        .where((item) => item.isValid)
        .toList(growable: false);
  }

  void dispose() {
    _client.close();
  }
}
