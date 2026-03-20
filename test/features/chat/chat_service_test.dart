import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile_remote/src/core/connection/connection_models.dart';
import 'package:opencode_mobile_remote/src/features/chat/chat_service.dart';
import 'package:opencode_mobile_remote/src/features/projects/project_models.dart';

void main() {
  late HttpServer server;
  late Uri baseUri;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    baseUri = Uri.parse('http://${server.address.address}:${server.port}');
    server.listen((request) async {
      final body = switch (request.uri.path) {
        '/session' when request.method == 'POST' => {
          'id': 'ses_2',
          'directory': '/workspace/demo',
          'title': 'New session',
          'version': '1',
          'time': {'created': 1710000006000, 'updated': 1710000006000},
        },
        '/session' => [
          {
            'id': 'ses_1',
            'slug': 'root',
            'projectID': 'proj_1',
            'directory': '/workspace/demo',
            'title': 'Root session',
            'version': '1',
            'time': {'created': 1710000000000, 'updated': 1710000005000},
          },
          if (request.uri.queryParameters['roots'] != 'true')
            {
              'id': 'ses_2',
              'slug': 'child',
              'projectID': 'proj_1',
              'directory': '/workspace/demo',
              'title': 'Nested session',
              'version': '1',
              'parentID': 'ses_1',
              'time': {'created': 1710000002000, 'updated': 1710000007000},
            },
        ],
        '/session/status' => {
          'ses_1': {'type': 'busy'},
        },
        '/session/ses_1/message' => [
          {
            'info': {'id': 'msg_1', 'role': 'user'},
            'parts': [
              {'id': 'prt_1', 'type': 'text', 'text': 'hello'},
            ],
          },
          {
            'info': {
              'id': 'msg_2',
              'role': 'assistant',
              'providerID': 'openai',
              'modelID': 'gpt-5',
            },
            'parts': [
              {'id': 'prt_2', 'type': 'reasoning', 'text': 'thinking'},
              {'id': 'prt_3', 'type': 'text', 'text': 'done'},
            ],
          },
        ],
        '/session/ses_2/message' when request.method == 'POST' => {
          'info': {
            'id': 'msg_3',
            'role': 'assistant',
            'sessionID': 'ses_2',
            'providerID': 'openai',
            'modelID': 'gpt-5',
          },
          'parts': [
            {'id': 'prt_4', 'type': 'text', 'text': 'ok'},
          ],
        },
        '/session/ses_bad/message' => [
          {
            'info': {'id': 'msg_good', 'role': 'assistant'},
            'parts': [
              {'id': 'prt_good', 'type': 'text', 'text': 'kept message'},
            ],
          },
          {
            'info': null,
            'parts': [
              {'id': 'prt_bad', 'type': 'text', 'text': 'broken message'},
            ],
          },
        ],
        _ => null,
      };
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

  test('fetches the full session list for the selected project', () async {
    final service = ChatService();
    final bundle = await service.fetchBundle(
      profile: ServerProfile(
        id: 'server',
        label: 'mock',
        baseUrl: baseUri.toString(),
      ),
      project: const ProjectTarget(directory: '/workspace/demo', label: 'Demo'),
    );

    expect(bundle.sessions.length, 2);
    expect(bundle.sessions.map((session) => session.id), <String>[
      'ses_1',
      'ses_2',
    ]);
    expect(bundle.statuses['ses_1']?.type, 'busy');
    expect(bundle.messages.length, 2);
    expect(bundle.messages.last.parts.last.text, 'done');
    service.dispose();
  });

  test('skips malformed messages when loading a session timeline', () async {
    final service = ChatService();
    final messages = await service.fetchMessages(
      profile: ServerProfile(
        id: 'server',
        label: 'mock',
        baseUrl: baseUri.toString(),
      ),
      project: const ProjectTarget(directory: '/workspace/demo', label: 'Demo'),
      sessionId: 'ses_bad',
    );

    expect(messages, hasLength(1));
    expect(messages.single.parts.single.text, 'kept message');
    service.dispose();
  });

  test('creates a session and sends a prompt message', () async {
    final service = ChatService();
    final profile = ServerProfile(
      id: 'server',
      label: 'mock',
      baseUrl: baseUri.toString(),
    );
    const project = ProjectTarget(directory: '/workspace/demo', label: 'Demo');

    final session = await service.createSession(
      profile: profile,
      project: project,
      title: 'New session',
    );
    final message = await service.sendMessage(
      profile: profile,
      project: project,
      sessionId: session.id,
      prompt: 'hello',
    );

    expect(session.id, 'ses_2');
    expect(message.info.id, 'msg_3');
    expect(message.parts.single.text, 'ok');
    service.dispose();
  });
}
