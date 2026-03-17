import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile_remote/src/core/connection/connection_models.dart';
import 'package:opencode_mobile_remote/src/features/projects/project_models.dart';
import 'package:opencode_mobile_remote/src/features/settings/integration_status_service.dart';

void main() {
  late HttpServer server;
  late Uri baseUri;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    baseUri = Uri.parse('http://${server.address.address}:${server.port}');
    server.listen((request) async {
      Object? body;
      if (request.uri.path == '/provider/auth') {
        body = {
          'openai': ['api_key'],
          'anthropic': ['oauth'],
        };
      }
      if (request.uri.path == '/mcp') {
        body = {
          'github': {'status': 'connected'},
          'docs': {'status': 'needs_auth'},
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

  test('fetches provider auth methods and mcp status', () async {
    final service = IntegrationStatusService();
    final snapshot = await service.fetch(
      profile: ServerProfile(
        id: 'server',
        label: 'mock',
        baseUrl: baseUri.toString(),
      ),
      project: const ProjectTarget(directory: '/workspace/demo', label: 'Demo'),
    );

    expect(snapshot.providerAuth['openai']?.first, 'api_key');
    expect(snapshot.mcpStatus['github'], 'connected');
    service.dispose();
  });
}
