import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:better_opencode_client/src/core/connection/connection_models.dart';
import 'package:better_opencode_client/src/features/projects/project_models.dart';
import 'package:better_opencode_client/src/features/requests/request_service.dart';

void main() {
  late HttpServer server;
  late Uri baseUri;
  late Object? questionBody;
  late Object? permissionBody;

  setUp(() async {
    questionBody = [
      {
        'id': 'que_1',
        'sessionID': 'ses_1',
        'questions': [
          {
            'question': 'Proceed with tool execution?',
            'header': 'Proceed',
            'custom': false,
            'options': [
              {'label': 'Yes', 'description': 'Allow it'},
              {'label': 'No', 'description': 'Reject it'},
            ],
          },
        ],
      },
    ];
    permissionBody = [
      {
        'id': 'per_1',
        'sessionID': 'ses_1',
        'permission': 'bash',
        'patterns': ['npm test'],
        'metadata': {},
        'always': [],
      },
    ];
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
      if (request.method == 'GET' && routePath == '/question') {
        body = questionBody;
      }
      if (request.method == 'GET' && routePath == '/permission') {
        body = permissionBody;
      }
      if (request.method == 'POST' && routePath == '/permission/per_1/reply') {
        body = true;
      }
      if (request.method == 'POST' && routePath == '/question/que_1/reply') {
        body = true;
      }
      if (request.method == 'POST' && routePath == '/question/que_1/reject') {
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
    expect(result.questions.first.questions.first.custom, isFalse);
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

  test(
    'fetchPending skips malformed pending items and keeps valid siblings',
    () async {
      questionBody = [
        {
          'id': 'que_1',
          'sessionID': 'ses_1',
          'questions': [
            {
              'question': 'Proceed with tool execution?',
              'header': 'Proceed',
              'custom': false,
              'options': [
                {'label': 'Yes', 'description': 'Allow it'},
              ],
            },
          ],
        },
        {'id': 'que_bad', 'sessionID': 'ses_2', 'questions': 'invalid'},
        {
          'id': 'que_2',
          'sessionID': 'ses_2',
          'questions': [
            {
              'question': 'Use fallback path?',
              'header': 'Fallback',
              'options': [
                {'label': 'Retry', 'description': 'Try again'},
              ],
            },
          ],
        },
      ];
      permissionBody = [
        {
          'id': 'per_1',
          'sessionID': 'ses_1',
          'permission': 'bash',
          'patterns': ['npm test'],
        },
        {
          'id': 'per_bad',
          'sessionID': 'ses_2',
          'permission': 'edit',
          'patterns': 'invalid',
        },
        {
          'id': 'per_2',
          'sessionID': 'ses_2',
          'permission': 'edit',
          'patterns': ['lib/**'],
        },
      ];

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
      );

      expect(result.questions.map((item) => item.id), <String>[
        'que_1',
        'que_2',
      ]);
      expect(result.permissions.map((item) => item.id), <String>[
        'per_1',
        'per_2',
      ]);
      expect(result.questions.last.questions.single.header, 'Fallback');
      expect(result.permissions.last.patterns, <String>['lib/**']);
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
