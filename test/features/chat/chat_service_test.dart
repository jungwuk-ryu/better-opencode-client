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

  test(
    'fetches sessions, statuses, and messages for selected project',
    () async {
      final service = ChatService();
      final bundle = await service.fetchBundle(
        profile: ServerProfile(
          id: 'server',
          label: 'mock',
          baseUrl: baseUri.toString(),
        ),
        project: const ProjectTarget(
          directory: '/workspace/demo',
          label: 'Demo',
        ),
      );

      expect(bundle.sessions.length, 1);
      expect(bundle.statuses['ses_1']?.type, 'busy');
      expect(bundle.messages.length, 2);
      expect(bundle.messages.last.parts.last.text, 'done');
      service.dispose();
    },
  );
}
