import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:better_opencode_client/src/core/connection/connection_models.dart';
import 'package:better_opencode_client/src/core/spec/raw_json_document.dart';
import 'package:better_opencode_client/src/features/projects/project_models.dart';
import 'package:better_opencode_client/src/features/settings/config_service.dart';

void main() {
  late HttpServer server;
  late Uri baseUri;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    baseUri = Uri.parse('http://${server.address.address}:${server.port}');
    server.listen((request) async {
      Object? body;
      if (request.uri.path == '/config') {
        body = {
          'model': 'openai/gpt-5',
          'x-future': {'enabled': true},
        };
      }
      if (request.uri.path == '/config/providers') {
        body = {
          'providers': [
            {
              'id': 'openai',
              'name': 'OpenAI',
              'source': 'custom',
              'env': ['OPENAI_API_KEY'],
              'options': {},
              'models': {
                'gpt-5': {
                  'id': 'gpt-5',
                  'providerID': 'openai',
                  'name': 'GPT-5',
                  'status': 'active',
                  'variants': {'low': {}, 'medium': {}},
                },
              },
            },
          ],
          'default': {'openai': 'gpt-5'},
        };
      }
      if (body == null) {
        request.response.statusCode = 404;
      } else {
        request.response.headers.contentType = ContentType.json;
        request.response.add(utf8.encode(jsonEncode(body)));
      }
      await request.response.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
  });

  test('fetches config snapshots as raw-preserving documents', () async {
    final service = ConfigService();
    final snapshot = await service.fetch(
      profile: ServerProfile(
        id: 'server',
        label: 'mock',
        baseUrl: baseUri.toString(),
      ),
      project: const ProjectTarget(directory: '/workspace/demo', label: 'Demo'),
    );

    expect(snapshot.config.toJson()['model'], 'openai/gpt-5');
    expect((snapshot.config.toJson()['x-future'] as Map)['enabled'], true);
    expect(
      (snapshot.providerConfig.toJson()['default'] as Map)['openai'],
      'gpt-5',
    );
    expect(snapshot.providerCatalog.providers, hasLength(1));
    expect(snapshot.providerCatalog.providers.single.id, 'openai');
    expect(
      snapshot.providerCatalog.providers.single.models['openai/gpt-5']?.id,
      'gpt-5',
    );
    expect(snapshot.providerCatalog.defaults['openai'], 'gpt-5');
    service.dispose();
  });

  test('updates config through patch endpoint', () async {
    final service = ConfigService();
    final updated = await service.updateConfig(
      profile: ServerProfile(
        id: 'server',
        label: 'mock',
        baseUrl: baseUri.toString(),
      ),
      project: const ProjectTarget(directory: '/workspace/demo', label: 'Demo'),
      config: <String, Object?>{
        'model': 'anthropic/claude-sonnet-4.5',
        'x-future': <String, Object?>{'enabled': true},
      },
    );

    expect(updated.toJson()['model'], 'openai/gpt-5');
    service.dispose();
  });

  test(
    'resolves effective tool permission policies from wildcard defaults',
    () {
      final policies = resolveConfigPermissionToolPolicies(
        RawJsonDocument(<String, Object?>{
          'permission': <String, Object?>{
            '*': 'deny',
            'bash': 'allow',
            'edit': <String, Object?>{'*': 'ask', '~/scratch/**': 'deny'},
          },
        }),
      );

      final bash = policies.firstWhere((policy) => policy.tool.id == 'bash');
      final read = policies.firstWhere((policy) => policy.tool.id == 'read');
      final edit = policies.firstWhere((policy) => policy.tool.id == 'edit');

      expect(bash.action, ConfigPermissionAction.allow);
      expect(bash.inheritedFromWildcard, isFalse);
      expect(read.action, ConfigPermissionAction.deny);
      expect(read.inheritedFromWildcard, isTrue);
      expect(edit.action, ConfigPermissionAction.ask);
      expect(edit.hasCustomPatterns, isTrue);
    },
  );

  test('builds tool permission updates while preserving custom patterns', () {
    final nextPermission = buildToolPermissionConfig(
      currentPermissionConfig: <String, Object?>{
        '*': 'ask',
        'edit': <String, Object?>{'*': 'deny', '~/scratch/**': 'allow'},
      },
      toolId: 'edit',
      action: ConfigPermissionAction.allow,
    );

    expect(nextPermission['*'], 'ask');
    expect(
      (nextPermission['edit'] as Map<String, Object?>)['*'],
      ConfigPermissionAction.allow.storageValue,
    );
    expect(
      (nextPermission['edit'] as Map<String, Object?>)['~/scratch/**'],
      'allow',
    );
  });
}
