import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile_remote/src/core/connection/connection_models.dart';
import 'package:opencode_mobile_remote/src/features/projects/project_models.dart';
import 'package:opencode_mobile_remote/src/features/requests/request_service.dart';

void main() {
  late HttpServer server;
  late Uri baseUri;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    baseUri = Uri.parse('http://${server.address.address}:${server.port}');
    server.listen((request) async {
      Object? body;
      if (request.method == 'GET' && request.uri.path == '/question') {
        body = [
          {
            'id': 'que_1',
            'sessionID': 'ses_1',
            'questions': [
              {
                'question': 'Proceed with tool execution?',
                'header': 'Proceed',
                'options': [
                  {'label': 'Yes', 'description': 'Allow it'},
                  {'label': 'No', 'description': 'Reject it'},
                ],
              },
            ],
          },
        ];
      }
      if (request.method == 'GET' && request.uri.path == '/permission') {
        body = [
          {
            'id': 'per_1',
            'sessionID': 'ses_1',
            'permission': 'bash',
            'patterns': ['npm test'],
            'metadata': {},
            'always': [],
          },
        ];
      }
      if (request.method == 'POST' &&
          request.uri.path == '/permission/per_1/reply') {
        body = true;
      }
      if (request.method == 'POST' &&
          request.uri.path == '/question/que_1/reply') {
        body = true;
      }
      if (request.method == 'POST' &&
          request.uri.path == '/question/que_1/reject') {
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

  test('fetches pending questions and permissions', () async {
    final service = RequestService();
    final result = await service.fetchPending(
      profile: ServerProfile(
        id: 'server',
        label: 'mock',
        baseUrl: baseUri.toString(),
      ),
      project: const ProjectTarget(directory: '/workspace/demo', label: 'Demo'),
    );

    expect(result.questions.length, 1);
    expect(result.permissions.length, 1);
    expect(result.questions.first.questions.first.options.first.label, 'Yes');
    service.dispose();
  });

  test(
    'skips unsupported pending endpoints when capability is absent',
    () async {
      final service = RequestService();
      final result = await service.fetchPending(
        profile: ServerProfile(
          id: 'server',
          label: 'mock',
          baseUrl: baseUri.toString(),
        ),
        project: const ProjectTarget(
          directory: '/workspace/demo',
          label: 'Demo',
        ),
        supportsQuestions: false,
        supportsPermissions: true,
      );

      expect(result.questions, isEmpty);
      expect(result.permissions.length, 1);
      expect(result.permissions.first.permission, 'bash');
      service.dispose();
    },
  );

  test('replies to permission and question requests', () async {
    final service = RequestService();
    final profile = ServerProfile(
      id: 'server',
      label: 'mock',
      baseUrl: baseUri.toString(),
    );
    const project = ProjectTarget(directory: '/workspace/demo', label: 'Demo');

    expect(
      await service.replyToPermission(
        profile: profile,
        project: project,
        requestId: 'per_1',
        reply: 'once',
      ),
      isTrue,
    );
    expect(
      await service.replyToQuestion(
        profile: profile,
        project: project,
        requestId: 'que_1',
        answers: const <List<String>>[
          ['Yes'],
        ],
      ),
      isTrue,
    );
    expect(
      await service.rejectQuestion(
        profile: profile,
        project: project,
        requestId: 'que_1',
      ),
      isTrue,
    );
    service.dispose();
  });
}
