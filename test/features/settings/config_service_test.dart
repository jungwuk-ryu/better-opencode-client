import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile_remote/src/core/connection/connection_models.dart';
import 'package:opencode_mobile_remote/src/features/projects/project_models.dart';
import 'package:opencode_mobile_remote/src/features/settings/config_service.dart';

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
            {'id': 'openai'},
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
}
