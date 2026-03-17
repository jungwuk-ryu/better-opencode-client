import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../connection/connection_models.dart';
import 'request_headers.dart';
import '../spec/capability_registry.dart';
import '../spec/probe_snapshot.dart';

class ServerProbeReport {
  const ServerProbeReport({
    required this.snapshot,
    required this.capabilityRegistry,
    required this.classification,
    required this.summary,
    required this.checkedAt,
    required this.missingCapabilities,
    required this.discoveredExperimentalPaths,
    required this.sseReady,
  });

  final ProbeSnapshot snapshot;
  final CapabilityRegistry capabilityRegistry;
  final ConnectionProbeClassification classification;
  final String summary;
  final DateTime checkedAt;
  final List<String> missingCapabilities;
  final List<String> discoveredExperimentalPaths;
  final bool sseReady;

  bool get isReady => classification == ConnectionProbeClassification.ready;
}

class OpenCodeServerProbe {
  OpenCodeServerProbe({http.Client? client})
    : _client = client ?? http.Client();

  static const _corePaths = <String>[
    '/global/health',
    '/doc',
    '/config',
    '/config/providers',
    '/provider',
    '/provider/auth',
    '/agent',
    '/experimental/tool/ids',
  ];
  static const _requiredPaths = <String>[
    '/global/health',
    '/doc',
    '/config',
    '/config/providers',
    '/provider',
    '/agent',
  ];
  static const _authSensitivePaths = <String>{
    '/doc',
    '/config',
    '/config/providers',
    '/provider',
    '/agent',
  };

  final http.Client _client;

  Future<ServerProbeReport> probe(ServerProfile profile) async {
    final checkedAt = DateTime.now();
    final uri = profile.uriOrNull;
    if (uri == null || uri.host.isEmpty) {
      return _buildFailureReport(
        profile: profile,
        checkedAt: checkedAt,
        classification: ConnectionProbeClassification.connectivityFailure,
        summary: 'Enter a valid server address to begin probing.',
      );
    }

    final headers = buildRequestHeaders(
      profile,
      accept: 'application/json, text/plain;q=0.9, */*;q=0.8',
    );

    final endpoints = <String, ProbeEndpointResult>{};
    final healthResult = await _probeEndpoint(uri, '/global/health', headers);
    endpoints[healthResult.path] = healthResult;

    final docResult = await _probeEndpoint(uri, '/doc', headers);
    endpoints[docResult.path] = docResult;

    final docBody = _asMap(docResult.body);
    final discoveredPaths = _extractPaths(docBody);
    final experimentalPaths = discoveredPaths
        .where(
          (path) =>
              path.startsWith('/experimental/tool/') &&
              !path.contains('{') &&
              !_corePaths.contains(path),
        )
        .toList(growable: false);

    final pathsToProbe = <String>{..._corePaths, ...experimentalPaths};
    for (final path in pathsToProbe) {
      if (endpoints.containsKey(path)) {
        continue;
      }
      endpoints[path] = await _probeEndpoint(uri, path, headers);
    }

    final configBody = _asMap(endpoints['/config']?.body);
    final providerConfigBody = _asMap(endpoints['/config/providers']?.body);
    final version = _extractVersion(docBody, healthResult.body, configBody);
    final name = _extractName(profile, docBody, healthResult.body);

    final snapshot = ProbeSnapshot(
      name: name,
      version: version,
      paths: discoveredPaths,
      endpoints: Map<String, ProbeEndpointResult>.unmodifiable(endpoints),
      config: configBody,
      providerConfig: providerConfigBody,
    );
    final capabilities = CapabilityRegistry.fromSnapshot(snapshot);
    final missingCapabilities = _requiredPaths
        .where(
          (path) =>
              !discoveredPaths.contains(path) &&
              !_isEndpointOperational(endpoints[path]),
        )
        .toList(growable: false);

    final classification = _classify(
      endpoints: endpoints,
      discoveredPaths: discoveredPaths,
      missingCapabilities: missingCapabilities,
      docBody: docBody,
    );

    return ServerProbeReport(
      snapshot: snapshot,
      capabilityRegistry: capabilities,
      classification: classification,
      summary: _summaryForClassification(classification, missingCapabilities),
      checkedAt: checkedAt,
      missingCapabilities: missingCapabilities,
      discoveredExperimentalPaths: experimentalPaths,
      sseReady:
          classification == ConnectionProbeClassification.ready &&
          healthResult.status == ProbeStatus.success,
    );
  }

  Future<ProbeEndpointResult> _probeEndpoint(
    Uri baseUri,
    String path,
    Map<String, String> headers,
  ) async {
    try {
      final response = await _client
          .get(_endpointUri(baseUri, path), headers: headers)
          .timeout(const Duration(seconds: 5));
      return ProbeEndpointResult(
        path: path,
        status: _statusFromCode(response.statusCode),
        statusCode: response.statusCode,
        body: _decodeBody(response.body),
      );
    } on TimeoutException {
      return ProbeEndpointResult(
        path: path,
        status: ProbeStatus.failure,
        body: 'Timed out while contacting $path.',
      );
    } catch (error) {
      return ProbeEndpointResult(
        path: path,
        status: ProbeStatus.failure,
        body: error.toString(),
      );
    }
  }

  ServerProbeReport _buildFailureReport({
    required ServerProfile profile,
    required DateTime checkedAt,
    required ConnectionProbeClassification classification,
    required String summary,
  }) {
    final snapshot = ProbeSnapshot(
      name: profile.effectiveLabel,
      version: 'unknown',
      paths: const <String>{},
      endpoints: const <String, ProbeEndpointResult>{},
    );
    return ServerProbeReport(
      snapshot: snapshot,
      capabilityRegistry: CapabilityRegistry.fromSnapshot(snapshot),
      classification: classification,
      summary: summary,
      checkedAt: checkedAt,
      missingCapabilities: _requiredPaths,
      discoveredExperimentalPaths: const <String>[],
      sseReady: false,
    );
  }

  ConnectionProbeClassification _classify({
    required Map<String, ProbeEndpointResult> endpoints,
    required Set<String> discoveredPaths,
    required List<String> missingCapabilities,
    required Map<String, Object?> docBody,
  }) {
    final healthResult = endpoints['/global/health'];
    final docResult = endpoints['/doc'];
    if (healthResult == null || healthResult.status == ProbeStatus.failure) {
      return ConnectionProbeClassification.connectivityFailure;
    }
    final hasAuthFailure = endpoints.entries.any(
      (entry) =>
          _authSensitivePaths.contains(entry.key) &&
          entry.value.status == ProbeStatus.unauthorized,
    );
    if (hasAuthFailure) {
      return ConnectionProbeClassification.authFailure;
    }
    if (docResult == null || docResult.status == ProbeStatus.failure) {
      return ConnectionProbeClassification.specFetchFailure;
    }
    if (docResult.status == ProbeStatus.unsupported) {
      return ConnectionProbeClassification.unsupportedCapabilities;
    }
    if (docResult.status == ProbeStatus.unknown || docBody.isEmpty) {
      return ConnectionProbeClassification.specFetchFailure;
    }
    if (missingCapabilities.isNotEmpty || !_supportsDocPaths(discoveredPaths)) {
      return ConnectionProbeClassification.unsupportedCapabilities;
    }
    return ConnectionProbeClassification.ready;
  }

  bool _supportsDocPaths(Set<String> discoveredPaths) {
    if (discoveredPaths.isEmpty) {
      return false;
    }
    return _requiredPaths.every(discoveredPaths.contains);
  }

  bool _isEndpointOperational(ProbeEndpointResult? result) {
    if (result == null) {
      return false;
    }
    return switch (result.status) {
      ProbeStatus.success => true,
      ProbeStatus.unauthorized => true,
      ProbeStatus.unknown => true,
      ProbeStatus.unsupported => false,
      ProbeStatus.failure => false,
    };
  }

  ProbeStatus _statusFromCode(int statusCode) {
    if (statusCode >= 200 && statusCode < 300) {
      return ProbeStatus.success;
    }
    if (statusCode == 401 || statusCode == 403) {
      return ProbeStatus.unauthorized;
    }
    if (statusCode == 404) {
      return ProbeStatus.unsupported;
    }
    if (statusCode == 405 || statusCode == 501) {
      return ProbeStatus.unknown;
    }
    if (statusCode >= 500) {
      return ProbeStatus.failure;
    }
    return ProbeStatus.unknown;
  }

  Object? _decodeBody(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    try {
      return jsonDecode(trimmed);
    } catch (_) {
      return trimmed;
    }
  }

  Map<String, Object?> _asMap(Object? value) {
    if (value is Map) {
      return value.cast<String, Object?>();
    }
    return const <String, Object?>{};
  }

  Set<String> _extractPaths(Map<String, Object?> docBody) {
    final rawPaths = docBody['paths'];
    if (rawPaths is! Map) {
      return const <String>{};
    }
    return rawPaths.keys.map((key) => key.toString()).toSet();
  }

  String _extractVersion(
    Map<String, Object?> docBody,
    Object? healthBody,
    Map<String, Object?> configBody,
  ) {
    final info = _asMap(docBody['info']);
    final health = _asMap(healthBody);
    final configVersion = configBody['version'];
    return (info['version'] as String?) ??
        (health['version'] as String?) ??
        (configVersion as String?) ??
        'unknown';
  }

  String _extractName(
    ServerProfile profile,
    Map<String, Object?> docBody,
    Object? healthBody,
  ) {
    final info = _asMap(docBody['info']);
    final health = _asMap(healthBody);
    return (info['title'] as String?) ??
        (health['name'] as String?) ??
        profile.effectiveLabel;
  }

  String _relativePath(String path) =>
      path.startsWith('/') ? path.substring(1) : path;

  Uri _endpointUri(Uri baseUri, String path) {
    final normalizedBasePath = switch (baseUri.path) {
      '' => '/',
      final value when value.endsWith('/') => value,
      final value => '$value/',
    };
    return baseUri
        .replace(path: normalizedBasePath)
        .resolve(_relativePath(path));
  }

  String _summaryForClassification(
    ConnectionProbeClassification classification,
    List<String> missingCapabilities,
  ) {
    return switch (classification) {
      ConnectionProbeClassification.ready =>
        'Core endpoints responded and the server looks ready for SSE handoff.',
      ConnectionProbeClassification.authFailure =>
        'The server responded, but at least one core endpoint rejected the supplied credentials.',
      ConnectionProbeClassification.specFetchFailure =>
        'The server is reachable, but the OpenAPI spec could not be fetched or parsed cleanly.',
      ConnectionProbeClassification.unsupportedCapabilities =>
        'The server spec is readable, but required endpoints are missing: ${missingCapabilities.join(', ')}.',
      ConnectionProbeClassification.connectivityFailure =>
        'The server could not be reached reliably enough to complete probing.',
    };
  }

  void dispose() {
    _client.close();
  }
}
