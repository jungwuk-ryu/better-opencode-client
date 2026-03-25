import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/connection/connection_models.dart';
import '../../core/network/request_headers.dart';

class AgentDefinition {
  const AgentDefinition({
    required this.name,
    required this.mode,
    this.description,
    this.hidden = false,
    this.modelProviderId,
    this.modelId,
    this.variant,
  });

  factory AgentDefinition.fromJson(Map<String, Object?> json) {
    final model = (json['model'] as Map?)?.cast<String, Object?>();
    return AgentDefinition(
      name: json['name']?.toString().trim() ?? '',
      mode: json['mode']?.toString().trim().isNotEmpty == true
          ? json['mode']!.toString().trim()
          : 'all',
      description: json['description']?.toString().trim(),
      hidden: json['hidden'] == true,
      modelProviderId: model?['providerID']?.toString().trim(),
      modelId: model?['modelID']?.toString().trim(),
      variant: json['variant']?.toString().trim(),
    );
  }

  final String name;
  final String mode;
  final String? description;
  final bool hidden;
  final String? modelProviderId;
  final String? modelId;
  final String? variant;

  bool get visible => !hidden && mode != 'subagent' && name.trim().isNotEmpty;

  String get modelKey {
    final providerId = modelProviderId?.trim();
    final modelId = this.modelId?.trim();
    if (providerId == null ||
        providerId.isEmpty ||
        modelId == null ||
        modelId.isEmpty) {
      return '';
    }
    return '$providerId/$modelId';
  }
}

class AgentService {
  AgentService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<AgentDefinition>> fetchAgents({
    required ServerProfile profile,
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
    final uri = baseUri.replace(path: basePath).resolve('agent');
    final response = await _client.get(uri, headers: headers);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Request failed for $uri with status ${response.statusCode}.',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      return const <AgentDefinition>[];
    }

    return decoded
        .whereType<Map>()
        .map((item) => AgentDefinition.fromJson(item.cast<String, Object?>()))
        .toList(growable: false);
  }

  void dispose() {
    _client.close();
  }
}
