import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:better_opencode_client/src/core/connection/connection_models.dart';
import 'package:better_opencode_client/src/features/chat/session_action_service.dart';
import 'package:better_opencode_client/src/features/projects/project_models.dart';

void main() {
  late HttpServer server;
  late Uri baseUri;

  setUp(() async {
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
      if (request.method == 'POST' && routePath == '/session/ses_1/summarize') {
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
