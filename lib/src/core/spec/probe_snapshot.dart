import 'dart:convert';

enum ProbeStatus { success, unsupported, unauthorized, failure, unknown }

class ProbeEndpointResult {
  const ProbeEndpointResult({
    required this.path,
    required this.status,
    this.statusCode,
    this.body,
  });

  final String path;
  final ProbeStatus status;
  final int? statusCode;
  final Object? body;

  factory ProbeEndpointResult.fromJson(Map<String, Object?> json) {
    return ProbeEndpointResult(
      path: json['path']! as String,
      status: ProbeStatus.values.byName(json['status']! as String),
      statusCode: json['statusCode'] as int?,
      body: json['body'],
    );
  }
}

class ProbeSnapshot {
  ProbeSnapshot({
    required this.name,
    required this.version,
    required this.paths,
    required this.endpoints,
    this.config = const {},
    this.providerConfig = const {},
  });

  final String name;
  final String version;
  final Set<String> paths;
  final Map<String, ProbeEndpointResult> endpoints;
  final Map<String, Object?> config;
  final Map<String, Object?> providerConfig;

  factory ProbeSnapshot.fromJsonString(String source) {
    return ProbeSnapshot.fromJson(jsonDecode(source) as Map<String, Object?>);
  }

  factory ProbeSnapshot.fromJson(Map<String, Object?> json) {
    final endpointList = (json['endpoints']! as List<Object?>)
        .cast<Map<String, Object?>>()
        .map(ProbeEndpointResult.fromJson)
        .toList(growable: false);

    return ProbeSnapshot(
      name: json['name']! as String,
      version: json['version']! as String,
      paths: ((json['paths']! as List<Object?>).cast<String>()).toSet(),
      endpoints: {for (final endpoint in endpointList) endpoint.path: endpoint},
      config: ((json['config'] as Map?) ?? const <String, Object?>{})
          .cast<String, Object?>(),
      providerConfig:
          ((json['providerConfig'] as Map?) ?? const <String, Object?>{})
              .cast<String, Object?>(),
    );
  }
}
