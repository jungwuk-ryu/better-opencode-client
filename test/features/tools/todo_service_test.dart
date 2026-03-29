import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:better_opencode_client/src/core/connection/connection_models.dart';
import 'package:better_opencode_client/src/features/projects/project_models.dart';
import 'package:better_opencode_client/src/features/tools/todo_service.dart';

void main() {
  late HttpServer server;
  late Uri baseUri;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    baseUri = Uri.parse('http://${server.address.address}:${server.port}');
    server.listen((request) async {
      if (request.uri.path != '/session/ses_1/todo') {
        request.response.statusCode = 404;
        await request.response.close();
        return;
      }
      request.response.headers.contentType = ContentType.json;
      request.response.add(
        utf8.encode(
          jsonEncode([
            {
              'content': 'Fetch session state',
              'status': 'in_progress',
              'priority': 'high',
            },
            {
              'content': 'Render parts',
              'status': 'pending',
              'priority': 'medium',
            },
            {'status': 'pending', 'priority': 'low'},
          ]),
        ),
      );
      await request.response.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
  });

  test('fetches todos for selected session', () async {
    final service = TodoService();
    final todos = await service.fetchTodos(
      profile: ServerProfile(
        id: 'server',
        label: 'mock',
        baseUrl: baseUri.toString(),
      ),
      project: const ProjectTarget(directory: '/workspace/demo', label: 'Demo'),
      sessionId: 'ses_1',
    );

    expect(todos.length, 2);
    expect(todos.map((item) => item.id), <String>[
      'todo_0_fetch_session_state',
      'todo_1_render_parts',
    ]);
    expect(todos.first.status, 'in_progress');
    service.dispose();
  });
}
