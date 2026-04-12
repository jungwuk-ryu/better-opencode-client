import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:better_opencode_client/src/core/connection/connection_models.dart';
import 'package:better_opencode_client/src/features/projects/project_models.dart';
import 'package:better_opencode_client/src/features/settings/integration_status_service.dart';

void main() {
  late HttpServer server;
  late Uri baseUri;
  late List<String> requestLog;
  Map<String, Object?>? lastMcpAuthBody;

  setUp(() async {
    requestLog = <String>[];
    lastMcpAuthBody = null;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    baseUri = Uri.parse(
      'http://${server.address.address}:${server.port}/api?token=abc',
    );
    server.listen((request) async {
      if (!_hasExpectedBaseContext(request.uri) ||
          request.uri.queryParameters['directory'] != '/workspace/demo') {
        request.response.statusCode = 400;
        await request.response.close();
        return;
      }
      final routePath = _routePath(request.uri);
      requestLog.add('${request.method} ${request.uri.path}');
      final requestBody = await utf8.decoder.bind(request).join();
      final decodedRequestBody = requestBody.trim().isEmpty
          ? null
          : jsonDecode(requestBody) as Object?;
      if (request.method == 'POST' &&
          routePath == '/mcp/github/auth' &&
          decodedRequestBody is Map) {
        lastMcpAuthBody = decodedRequestBody.cast<String, Object?>();
      }
      Object? body;
      if (routePath == '/provider/auth') {
        body = {
          'openai': ['api_key'],
          'anthropic': ['oauth'],
        };
      }
      if (routePath == '/mcp') {
        body = {
          'github': {'status': 'connected'},
          'docs': {'status': 'needs_auth'},
          'broken': {
            'status': 'failed',
            'error': 'Timed out while probing the MCP server.',
          },
        };
      }
      if (routePath == '/lsp') {
        body = [
          {
            'id': 'ts',
            'name': 'typescript',
            'root': '/workspace/demo',
            'status': 'connected',
          },
        ];
      }
      if (routePath == '/formatter') {
        body = [
          {
            'name': 'prettier',
            'extensions': ['.ts'],
            'enabled': true,
          },
        ];
      }
      if (request.method == 'POST' &&
          routePath == '/provider/openai/oauth/authorize') {
        body = {'authorizationUrl': 'https://provider.example/auth'};
      }
      if (request.method == 'POST' &&
          routePath == '/provider/anthropic/oauth/authorize') {
        body = {'url': 'https://legacy-provider.example/auth'};
      }
      if (request.method == 'POST' && routePath == '/mcp/github/auth') {
        body = {'authorizationUrl': 'https://mcp.example/auth'};
      }
      if (request.method == 'POST' && routePath == '/mcp/docs/auth') {
        body = {'url': 'https://legacy-mcp.example/auth'};
      }
      if (request.method == 'POST' && routePath == '/mcp/docs/connect') {
        body = true;
      }
      if (request.method == 'POST' && routePath == '/mcp/github/disconnect') {
        body = true;
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
    expect(snapshot.mcpDetails['broken']?.error, contains('Timed out'));
    expect(snapshot.lspStatus['typescript'], 'connected');
    expect(snapshot.formatterStatus['prettier'], isTrue);
    service.dispose();
  });

  test('starts provider and mcp auth flows', () async {
    final service = IntegrationStatusService();
    final profile = ServerProfile(
      id: 'server',
      label: 'mock',
      baseUrl: baseUri.toString(),
    );
    const project = ProjectTarget(directory: '/workspace/demo', label: 'Demo');

    expect(
      await service.startProviderAuth(
        profile: profile,
        project: project,
        providerId: 'openai',
      ),
      'https://provider.example/auth',
    );
    expect(
      await service.startMcpAuth(
        profile: profile,
        project: project,
        name: 'github',
      ),
      'https://mcp.example/auth',
    );
    expect(lastMcpAuthBody, isNotNull);
    expect(
      lastMcpAuthBody!['redirectUri'],
      'http://${server.address.address}:${server.port}/api/mcp/oauth/callback',
    );
    service.dispose();
  });

  test(
    'accepts legacy auth url fields from provider and mcp endpoints',
    () async {
      final service = IntegrationStatusService();
      final profile = ServerProfile(
        id: 'server',
        label: 'mock',
        baseUrl: baseUri.toString(),
      );
      const project = ProjectTarget(
        directory: '/workspace/demo',
        label: 'Demo',
      );

      expect(
        await service.startProviderAuth(
          profile: profile,
          project: project,
          providerId: 'anthropic',
        ),
        'https://legacy-provider.example/auth',
      );
      expect(
        await service.startMcpAuth(
          profile: profile,
          project: project,
          name: 'docs',
        ),
        'https://legacy-mcp.example/auth',
      );
      service.dispose();
    },
  );

  test('connects and disconnects MCP servers', () async {
    final service = IntegrationStatusService();
    final profile = ServerProfile(
      id: 'server',
      label: 'mock',
      baseUrl: baseUri.toString(),
    );
    const project = ProjectTarget(directory: '/workspace/demo', label: 'Demo');

    await service.connectMcp(profile: profile, project: project, name: 'docs');
    await service.disconnectMcp(
      profile: profile,
      project: project,
      name: 'github',
    );

    expect(requestLog, contains('POST /api/mcp/docs/connect'));
    expect(requestLog, contains('POST /api/mcp/github/disconnect'));
    service.dispose();
  });
}

bool _hasExpectedBaseContext(Uri uri) {
  final hasApiPrefix = uri.path == '/api' || uri.path.startsWith('/api/');
  return hasApiPrefix && uri.queryParameters['token'] == 'abc';
}

String _routePath(Uri uri) {
  if (uri.path == '/api') {
    return '/';
  }
  return uri.path.substring('/api'.length);
}
