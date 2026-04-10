import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:better_opencode_client/src/core/connection/connection_models.dart';
import 'package:better_opencode_client/src/features/chat/session_action_service.dart';
import 'package:better_opencode_client/src/features/projects/project_models.dart';

void main() {
  late HttpServer server;
  late Uri baseUri;
  bool promptAsyncUnsupported = false;
  int promptAsyncCalls = 0;
  int summarizeEndpointCalls = 0;
  String? summarizeRoutePath;
  Object? summarizeRequestBody;
  Object? summarizeEndpointRequestBody;

  setUp(() async {
    promptAsyncUnsupported = false;
    promptAsyncCalls = 0;
    summarizeEndpointCalls = 0;
    summarizeRoutePath = null;
    summarizeRequestBody = null;
    summarizeEndpointRequestBody = null;
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
      final requestBody = await utf8.decoder.bind(request).join();
      final decodedRequestBody = requestBody.trim().isEmpty
          ? null
          : jsonDecode(requestBody);
      Object? body;
      if (request.method == 'POST' && routePath == '/session/ses_1/fork') {
        body = {
          'id': 'ses_2',
          'directory': '/workspace/demo',
          'title': 'Forked session',
          'version': '1',
          'time': {'updated': 1710000000000},
        };
      }
      if (request.method == 'POST' && routePath == '/session/ses_1/abort') {
        body = true;
      }
      if (request.method == 'POST' && routePath == '/session/ses_1/share') {
        body = {
          'id': 'ses_1',
          'directory': '/workspace/demo',
          'title': 'Shared session',
          'version': '1',
          'share': {'url': 'https://share.example/ses_1'},
          'time': {'updated': 1710000000000},
        };
      }
      if (request.method == 'DELETE' && routePath == '/session/ses_1') {
        body = true;
      }
      if (request.method == 'PATCH' && routePath == '/session/ses_1') {
        body = {
          'id': 'ses_1',
          'directory': '/workspace/demo',
          'title': 'Renamed session',
          'version': '4',
          'time': {'updated': 1710000003000},
        };
      }
      if (request.method == 'DELETE' && routePath == '/session/ses_1/share') {
        body = {
          'id': 'ses_1',
          'directory': '/workspace/demo',
          'title': 'Private session',
          'version': '1',
          'time': {'updated': 1710000000000},
        };
      }
      if (request.method == 'POST' && routePath == '/session/ses_1/revert') {
        body = {
          'id': 'ses_1',
          'directory': '/workspace/demo',
          'title': 'Reverted session',
          'version': '2',
          'time': {'updated': 1710000001000},
        };
      }
      if (request.method == 'POST' && routePath == '/session/ses_1/unrevert') {
        body = {
          'id': 'ses_1',
          'directory': '/workspace/demo',
          'title': 'Restored session',
          'version': '3',
          'time': {'updated': 1710000002000},
        };
      }
      if (request.method == 'POST' && routePath == '/session/ses_1/init') {
        body = true;
      }
      if (request.method == 'POST' &&
          routePath == '/session/ses_1/prompt_async') {
        promptAsyncCalls += 1;
        if (promptAsyncUnsupported) {
          request.response.statusCode = 404;
          await request.response.close();
          return;
        }
        summarizeRoutePath = routePath;
        summarizeRequestBody = decodedRequestBody;
        request.response.statusCode = 204;
        await request.response.close();
        return;
      }
      if (request.method == 'POST' && routePath == '/session/ses_1/summarize') {
        summarizeEndpointCalls += 1;
        summarizeEndpointRequestBody = decodedRequestBody;
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

  test('runs fork, share, unshare, and abort actions', () async {
    final service = SessionActionService();
    final profile = ServerProfile(
      id: 'server',
      label: 'mock',
      baseUrl: baseUri.toString(),
    );
    const project = ProjectTarget(directory: '/workspace/demo', label: 'Demo');

    final forked = await service.forkSession(
      profile: profile,
      project: project,
      sessionId: 'ses_1',
    );
    expect(forked.id, 'ses_2');
    expect(
      await service.abortSession(
        profile: profile,
        project: project,
        sessionId: 'ses_1',
      ),
      isTrue,
    );
    expect(
      (await service.shareSession(
        profile: profile,
        project: project,
        sessionId: 'ses_1',
      )).shareUrl,
      'https://share.example/ses_1',
    );
    expect(
      (await service.unshareSession(
        profile: profile,
        project: project,
        sessionId: 'ses_1',
      )).shareUrl,
      isNull,
    );
    expect(
      await service.deleteSession(
        profile: profile,
        project: project,
        sessionId: 'ses_1',
      ),
      isTrue,
    );
    expect(
      (await service.updateSession(
        profile: profile,
        project: project,
        sessionId: 'ses_1',
        title: 'Renamed session',
      )).title,
      'Renamed session',
    );
    expect(
      (await service.revertSession(
        profile: profile,
        project: project,
        sessionId: 'ses_1',
        messageId: 'msg_1',
      )).title,
      'Reverted session',
    );
    expect(
      (await service.unrevertSession(
        profile: profile,
        project: project,
        sessionId: 'ses_1',
      )).title,
      'Restored session',
    );
    expect(
      await service.initSession(
        profile: profile,
        project: project,
        sessionId: 'ses_1',
        messageId: 'msg_1',
        providerId: 'openai',
        modelId: 'gpt-5',
      ),
      isTrue,
    );
    expect(
      await service.summarizeSession(
        profile: profile,
        project: project,
        sessionId: 'ses_1',
        providerId: 'openai',
        modelId: 'gpt-5',
      ),
      isTrue,
    );
    expect(summarizeRoutePath, '/session/ses_1/prompt_async');
    expect(summarizeRequestBody, <String, Object?>{
      'parts': const <Map<String, Object?>>[
        <String, Object?>{'type': 'text', 'text': '/compact'},
      ],
      'model': <String, Object?>{'providerID': 'openai', 'modelID': 'gpt-5'},
      'providerID': 'openai',
      'modelID': 'gpt-5',
    });
    expect(promptAsyncCalls, 1);
    expect(summarizeEndpointCalls, 0);
    service.dispose();
  });

  test(
    'summarize falls back to the legacy endpoint when prompt_async is unsupported',
    () async {
      promptAsyncUnsupported = true;
      final service = SessionActionService();
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
        await service.summarizeSession(
          profile: profile,
          project: project,
          sessionId: 'ses_1',
          providerId: 'openai',
          modelId: 'gpt-5',
        ),
        isTrue,
      );
      expect(promptAsyncCalls, 1);
      expect(summarizeEndpointCalls, 1);
      expect(summarizeEndpointRequestBody, <String, Object?>{
        'providerID': 'openai',
        'modelID': 'gpt-5',
        'auto': false,
      });
      service.dispose();
    },
  );

  test('summarize preserves auto mode on the legacy endpoint', () async {
    final service = SessionActionService();
    final profile = ServerProfile(
      id: 'server',
      label: 'mock',
      baseUrl: baseUri.toString(),
    );
    const project = ProjectTarget(directory: '/workspace/demo', label: 'Demo');

    expect(
      await service.summarizeSession(
        profile: profile,
        project: project,
        sessionId: 'ses_1',
        providerId: 'openai',
        modelId: 'gpt-5',
        auto: true,
      ),
      isTrue,
    );
    expect(promptAsyncCalls, 0);
    expect(summarizeEndpointCalls, 1);
    expect(summarizeEndpointRequestBody, <String, Object?>{
      'providerID': 'openai',
      'modelID': 'gpt-5',
      'auto': true,
    });
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
