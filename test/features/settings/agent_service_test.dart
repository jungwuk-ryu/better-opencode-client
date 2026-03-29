import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:better_opencode_client/src/core/connection/connection_models.dart';
import 'package:better_opencode_client/src/features/settings/agent_service.dart';

void main() {
  late HttpServer server;
  late Uri baseUri;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    baseUri = Uri.parse('http://${server.address.address}:${server.port}');
    server.listen((request) async {
      Object? body;
      if (request.uri.path == '/agent') {
        body = <Map<String, Object?>>[
          <String, Object?>{
            'name': 'Sisyphus',
            'description': 'Ultraworker',
            'mode': 'all',
            'variant': 'medium',
            'model': <String, Object?>{
              'providerID': 'openai',
              'modelID': 'gpt-5.4',
            },
          },
          <String, Object?>{
            'name': 'Hidden',
            'mode': 'subagent',
            'hidden': true,
          },
        ];
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

  test('fetches agent definitions with model and variant metadata', () async {
    final service = AgentService();
    final agents = await service.fetchAgents(
      profile: ServerProfile(
        id: 'server',
        label: 'mock',
        baseUrl: baseUri.toString(),
      ),
    );

    expect(agents, hasLength(2));
    expect(agents.first.name, 'Sisyphus');
    expect(agents.first.description, 'Ultraworker');
    expect(agents.first.modelProviderId, 'openai');
    expect(agents.first.modelId, 'gpt-5.4');
    expect(agents.first.variant, 'medium');
    expect(agents.first.modelKey, 'openai/gpt-5.4');
    service.dispose();
  });
}
