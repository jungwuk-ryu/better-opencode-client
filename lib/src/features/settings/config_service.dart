import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/connection/connection_models.dart';
import '../../core/network/request_headers.dart';
import '../../core/spec/raw_json_document.dart';
import '../projects/project_models.dart';

class ConfigSnapshot {
  ConfigSnapshot({required this.config, required this.providerConfig});

  final RawJsonDocument config;
  final RawJsonDocument providerConfig;

  late final bool snapshotTrackingEnabled = config.value('snapshot') != false;

  late final ProviderCatalog providerCatalog = ProviderCatalog.fromJson(
    providerConfig.toJson(),
  );
}

class ProviderCatalog {
  const ProviderCatalog({required this.providers, required this.defaults});

  factory ProviderCatalog.fromJson(Map<String, Object?> json) {
    final providers = switch (json['providers']) {
      final List<Object?> list =>
        list
            .whereType<Map>()
            .map(
              (provider) =>
                  ProviderDefinition.fromJson(provider.cast<String, Object?>()),
            )
            .toList(growable: false),
      _ => _legacyProvidersFromJson(json),
    };
    final defaults = switch (json['default']) {
      final Map<Object?, Object?> value => value.map(
        (key, modelId) => MapEntry(key.toString(), modelId?.toString() ?? ''),
      )..removeWhere((_, modelId) => modelId.trim().isEmpty),
      _ => const <String, String>{},
    };
    return ProviderCatalog(providers: providers, defaults: defaults);
  }

  final List<ProviderDefinition> providers;
  final Map<String, String> defaults;

  ProviderModelDefinition? modelForKey(String key) {
    for (final provider in providers) {
      final model = provider.models[key];
      if (model != null) {
        return model;
      }
    }
    return null;
  }

  static List<ProviderDefinition> _legacyProvidersFromJson(
    Map<String, Object?> json,
  ) {
    final providers = <ProviderDefinition>[];
    for (final entry in json.entries) {
      if (entry.key == 'default' || entry.key == 'providers') {
        continue;
      }
      final value = entry.value;
      if (value is! Map) {
        continue;
      }
      providers.add(
        ProviderDefinition.fromLegacyJson(
          id: entry.key,
          json: value.cast<String, Object?>(),
        ),
      );
    }
    return providers;
  }
}

class ProviderDefinition {
  const ProviderDefinition({
    required this.id,
    required this.name,
    required this.source,
    required this.models,
  });

  factory ProviderDefinition.fromJson(Map<String, Object?> json) {
    final id = json['id']?.toString().trim() ?? '';
    final models = <String, ProviderModelDefinition>{};
    final rawModels = json['models'];
    if (rawModels is Map) {
      for (final entry in rawModels.entries) {
        final value = entry.value;
        if (value is! Map) {
          continue;
        }
        final model = ProviderModelDefinition.fromJson(
          providerId: id,
          modelKey: entry.key.toString(),
          json: value.cast<String, Object?>(),
        );
        models[model.key] = model;
      }
    }
    return ProviderDefinition(
      id: id,
      name: json['name']?.toString().trim().isNotEmpty == true
          ? json['name']!.toString().trim()
          : id,
      source: json['source']?.toString().trim() ?? '',
      models: models,
    );
  }

  factory ProviderDefinition.fromLegacyJson({
    required String id,
    required Map<String, Object?> json,
  }) {
    final models = <String, ProviderModelDefinition>{};
    final rawModels = json['models'];
    if (rawModels is List) {
      for (final entry in rawModels) {
        if (entry is String) {
          final model = ProviderModelDefinition.legacy(
            providerId: id,
            modelId: entry,
          );
          models[model.key] = model;
          continue;
        }
        if (entry is Map) {
          final model = ProviderModelDefinition.fromJson(
            providerId: entry['providerID']?.toString() ?? id,
            modelKey:
                entry['id']?.toString() ??
                entry['modelID']?.toString() ??
                entry['modelId']?.toString() ??
                '',
            json: entry.cast<String, Object?>(),
          );
          models[model.key] = model;
        }
      }
    }
    if (rawModels is Map) {
      for (final entry in rawModels.entries) {
        final value = entry.value;
        if (value is! Map) {
          continue;
        }
        final model = ProviderModelDefinition.fromJson(
          providerId: id,
          modelKey: entry.key.toString(),
          json: value.cast<String, Object?>(),
        );
        models[model.key] = model;
      }
    }
    return ProviderDefinition(
      id: id,
      name: json['name']?.toString().trim().isNotEmpty == true
          ? json['name']!.toString().trim()
          : id,
      source: json['source']?.toString().trim() ?? '',
      models: models,
    );
  }

  final String id;
  final String name;
  final String source;
  final Map<String, ProviderModelDefinition> models;
}

class ProviderModelDefinition {
  const ProviderModelDefinition({
    required this.id,
    required this.providerId,
    required this.name,
    required this.status,
    required this.reasoningVariants,
    this.contextLimit,
  });

  factory ProviderModelDefinition.fromJson({
    required String providerId,
    required String modelKey,
    required Map<String, Object?> json,
  }) {
    final id = json['id']?.toString().trim().isNotEmpty == true
        ? json['id']!.toString().trim()
        : modelKey.trim();
    final variants = <String>[];
    final rawVariants = json['variants'];
    final rawLimit = (json['limit'] as Map?)?.cast<String, Object?>();
    if (rawVariants is Map) {
      for (final entry in rawVariants.keys) {
        final value = entry.toString().trim();
        if (value.isEmpty) {
          continue;
        }
        variants.add(value);
      }
    }
    return ProviderModelDefinition(
      id: id,
      providerId: json['providerID']?.toString().trim().isNotEmpty == true
          ? json['providerID']!.toString().trim()
          : providerId,
      name: json['name']?.toString().trim().isNotEmpty == true
          ? json['name']!.toString().trim()
          : id,
      status: json['status']?.toString().trim() ?? '',
      reasoningVariants: variants,
      contextLimit: (rawLimit?['context'] as num?)?.toInt(),
    );
  }

  factory ProviderModelDefinition.legacy({
    required String providerId,
    required String modelId,
  }) {
    return ProviderModelDefinition(
      id: modelId.trim(),
      providerId: providerId.trim(),
      name: modelId.trim(),
      status: '',
      reasoningVariants: const <String>[],
      contextLimit: null,
    );
  }

  final String id;
  final String providerId;
  final String name;
  final String status;
  final List<String> reasoningVariants;
  final int? contextLimit;

  String get key => '$providerId/$id';
}

enum ConfigPermissionAction {
  allow,
  ask,
  deny;

  static ConfigPermissionAction? tryParse(String? value) {
    return switch (value?.trim().toLowerCase()) {
      'allow' => ConfigPermissionAction.allow,
      'deny' => ConfigPermissionAction.deny,
      'ask' => ConfigPermissionAction.ask,
      _ => null,
    };
  }

  String get storageValue => name;

  String get label => switch (this) {
    ConfigPermissionAction.allow => 'Allow',
    ConfigPermissionAction.ask => 'Ask',
    ConfigPermissionAction.deny => 'Deny',
  };
}

class ConfigPermissionToolDefinition {
  const ConfigPermissionToolDefinition({
    required this.id,
    required this.title,
    required this.description,
  });

  final String id;
  final String title;
  final String description;
}

class ConfigPermissionToolPolicy {
  const ConfigPermissionToolPolicy({
    required this.tool,
    required this.action,
    required this.inheritedFromWildcard,
    required this.hasCustomPatterns,
  });

  final ConfigPermissionToolDefinition tool;
  final ConfigPermissionAction action;
  final bool inheritedFromWildcard;
  final bool hasCustomPatterns;
}

const List<ConfigPermissionToolDefinition> configPermissionTools =
    <ConfigPermissionToolDefinition>[
      ConfigPermissionToolDefinition(
        id: 'read',
        title: 'Read',
        description: 'Reading a file (matches the file path)',
      ),
      ConfigPermissionToolDefinition(
        id: 'edit',
        title: 'Edit',
        description:
            'Modify files, including edits, writes, patches, and multi-edits',
      ),
      ConfigPermissionToolDefinition(
        id: 'glob',
        title: 'Glob',
        description: 'Match files using glob patterns',
      ),
      ConfigPermissionToolDefinition(
        id: 'grep',
        title: 'Grep',
        description: 'Search file contents using regular expressions',
      ),
      ConfigPermissionToolDefinition(
        id: 'list',
        title: 'List',
        description: 'List files within a directory',
      ),
      ConfigPermissionToolDefinition(
        id: 'bash',
        title: 'Bash',
        description: 'Run shell commands',
      ),
      ConfigPermissionToolDefinition(
        id: 'task',
        title: 'Task',
        description: 'Launch sub-agents',
      ),
      ConfigPermissionToolDefinition(
        id: 'skill',
        title: 'Skill',
        description: 'Load a skill by name',
      ),
      ConfigPermissionToolDefinition(
        id: 'lsp',
        title: 'LSP',
        description: 'Run language server queries',
      ),
      ConfigPermissionToolDefinition(
        id: 'todowrite',
        title: 'Todo Write',
        description: 'Update the todo list',
      ),
      ConfigPermissionToolDefinition(
        id: 'webfetch',
        title: 'Web Fetch',
        description: 'Fetch content from a URL',
      ),
      ConfigPermissionToolDefinition(
        id: 'websearch',
        title: 'Web Search',
        description: 'Search the web',
      ),
      ConfigPermissionToolDefinition(
        id: 'codesearch',
        title: 'Code Search',
        description: 'Search code on the web',
      ),
      ConfigPermissionToolDefinition(
        id: 'external_directory',
        title: 'External Directory',
        description: 'Access files outside the project directory',
      ),
      ConfigPermissionToolDefinition(
        id: 'doom_loop',
        title: 'Doom Loop',
        description: 'Detect repeated tool calls with identical input',
      ),
    ];

List<ConfigPermissionToolPolicy> resolveConfigPermissionToolPolicies(
  RawJsonDocument? config,
) {
  final permissionConfig = config?.toJson()['permission'];
  return configPermissionTools
      .map(
        (tool) => resolveConfigPermissionToolPolicy(
          permissionConfig: permissionConfig,
          tool: tool,
        ),
      )
      .toList(growable: false);
}

ConfigPermissionToolPolicy resolveConfigPermissionToolPolicy({
  required Object? permissionConfig,
  required ConfigPermissionToolDefinition tool,
}) {
  final specificRule = _permissionRuleForTool(permissionConfig, tool.id);
  final wildcardRule = _permissionWildcardRule(permissionConfig);
  final specificAction = _defaultActionForPermissionRule(specificRule);
  final wildcardAction = _defaultActionForPermissionRule(wildcardRule);
  return ConfigPermissionToolPolicy(
    tool: tool,
    action: specificAction ?? wildcardAction ?? ConfigPermissionAction.ask,
    inheritedFromWildcard: specificAction == null && wildcardAction != null,
    hasCustomPatterns: _permissionRuleHasCustomPatterns(specificRule),
  );
}

Map<String, Object?> buildToolPermissionConfig({
  required Object? currentPermissionConfig,
  required String toolId,
  required ConfigPermissionAction action,
}) {
  final normalizedAction = action.storageValue;
  final nextPermission = switch (currentPermissionConfig) {
    final String value => <String, Object?>{
      if (ConfigPermissionAction.tryParse(value) != null)
        '*': value.trim().toLowerCase(),
    },
    final Map value => _deepJsonMapCopy(value),
    _ => <String, Object?>{},
  };
  final currentToolRule = nextPermission[toolId];
  if (currentToolRule is Map) {
    final nextToolRule = _deepJsonMapCopy(currentToolRule);
    nextToolRule['*'] = normalizedAction;
    nextPermission[toolId] = nextToolRule;
    return nextPermission;
  }
  nextPermission[toolId] = normalizedAction;
  return nextPermission;
}

Map<String, Object?> _deepJsonMapCopy(Map<Object?, Object?> input) {
  return (jsonDecode(jsonEncode(input)) as Map).cast<String, Object?>();
}

Object? _permissionRuleForTool(Object? permissionConfig, String toolId) {
  if (permissionConfig is! Map) {
    return null;
  }
  return permissionConfig[toolId];
}

Object? _permissionWildcardRule(Object? permissionConfig) {
  if (permissionConfig is String) {
    return permissionConfig;
  }
  if (permissionConfig is Map) {
    return permissionConfig['*'];
  }
  return null;
}

ConfigPermissionAction? _defaultActionForPermissionRule(Object? rule) {
  if (rule is String) {
    return ConfigPermissionAction.tryParse(rule);
  }
  if (rule is Map) {
    return ConfigPermissionAction.tryParse(rule['*']?.toString());
  }
  return null;
}

bool _permissionRuleHasCustomPatterns(Object? rule) {
  if (rule is! Map) {
    return false;
  }
  for (final entry in rule.entries) {
    final key = entry.key.toString();
    if (key == '*') {
      continue;
    }
    if (ConfigPermissionAction.tryParse(entry.value?.toString()) != null) {
      return true;
    }
  }
  return false;
}

class ConfigService {
  ConfigService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<ConfigSnapshot> fetch({
    required ServerProfile profile,
    required ProjectTarget project,
  }) async {
    final configBody = await _getJson(
      profile: profile,
      project: project,
      path: '/config',
    );
    final providerBody = await _getJson(
      profile: profile,
      project: project,
      path: '/config/providers',
    );
    return ConfigSnapshot(
      config: RawJsonDocument((configBody as Map).cast<String, Object?>()),
      providerConfig: RawJsonDocument(
        (providerBody as Map).cast<String, Object?>(),
      ),
    );
  }

  Future<RawJsonDocument> updateConfig({
    required ServerProfile profile,
    required ProjectTarget project,
    required Map<String, Object?> config,
  }) async {
    final baseUri = profile.uriOrNull;
    if (baseUri == null) {
      throw const FormatException('Invalid server profile URL.');
    }
    final headers = buildRequestHeaders(
      profile,
      accept: 'application/json',
      jsonBody: true,
    );
    final basePath = switch (baseUri.path) {
      '' => '/',
      final value when value.endsWith('/') => value,
      final value => '$value/',
    };
    final uri = baseUri
        .replace(path: basePath)
        .resolve('config')
        .replace(
          queryParameters: <String, String>{'directory': project.directory},
        );
    final response = await _client.patch(
      uri,
      headers: headers,
      body: jsonEncode(config),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Request failed for $uri with status ${response.statusCode}.',
      );
    }
    return RawJsonDocument(
      (jsonDecode(response.body) as Map).cast<String, Object?>(),
    );
  }

  Future<Object?> _getJson({
    required ServerProfile profile,
    required ProjectTarget project,
    required String path,
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
    final uri = baseUri
        .replace(path: basePath)
        .resolve(path.startsWith('/') ? path.substring(1) : path)
        .replace(
          queryParameters: <String, String>{'directory': project.directory},
        );
    final response = await _client.get(uri, headers: headers);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Request failed for $uri with status ${response.statusCode}.',
      );
    }
    return jsonDecode(response.body);
  }

  void dispose() {
    _client.close();
  }
}
