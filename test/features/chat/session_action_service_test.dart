import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile_remote/src/core/connection/connection_models.dart';
import 'package:opencode_mobile_remote/src/features/chat/session_action_service.dart';
import 'package:opencode_mobile_remote/src/features/projects/project_models.dart';

void main() {
  late HttpServer server;
  late Uri baseUri;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    baseUri = Uri.parse('http://${server.address.address}:${server.port}');
    server.listen((request) async {
      Object? body;
      if (request.method == 'POST' &&
          request.uri.path == '/session/ses_1/fork') {
        body = {
          'id': 'ses_2',
          'directory': '/workspace/demo',
          'title': 'Forked session',
          'version': '1',
          'time': {'updated': 1710000000000},
        };
      }
      if (request.method == 'POST' &&
          request.uri.path == '/session/ses_1/abort') {
        body = true;
      }
      if (request.method == 'POST' &&
          request.uri.path == '/session/ses_1/share') {
        body = {'id': 'ses_1'};
      }
      if (request.method == 'DELETE' &&
          request.uri.path == '/session/ses_1/share') {
        body = {'id': 'ses_1'};
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
      await service.shareSession(
        profile: profile,
        project: project,
        sessionId: 'ses_1',
      ),
      isTrue,
    );
    expect(
      await service.unshareSession(
        profile: profile,
        project: project,
        sessionId: 'ses_1',
      ),
      isTrue,
    );
    service.dispose();
  });
}
