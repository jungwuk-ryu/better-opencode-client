import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:better_opencode_client/src/core/connection/connection_models.dart';
import 'package:better_opencode_client/src/features/chat/chat_service.dart';
import 'package:better_opencode_client/src/features/chat/prompt_attachment_models.dart';
import 'package:better_opencode_client/src/features/projects/project_models.dart';

void main() {
  late HttpServer server;
  late Uri baseUri;
  Map<String, Object?>? lastPromptBody;
  Map<String, Object?>? lastCommandBody;
  Map<String, String>? lastMessagesQuery;

  setUp(() async {
    lastPromptBody = null;
    lastCommandBody = null;
    lastMessagesQuery = null;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    baseUri = Uri.parse('http://${server.address.address}:${server.port}');
    server.listen((request) async {
      final requestBody = await utf8.decoder.bind(request).join();
      final decodedBody = requestBody.trim().isEmpty
          ? null
          : jsonDecode(requestBody) as Object?;
      if (request.uri.path == '/session/ses_2/message' &&
          request.method == 'POST' &&
          decodedBody is Map) {
        lastPromptBody = decodedBody.cast<String, Object?>();
      }
      if (request.uri.path == '/session/ses_2/command' &&
          request.method == 'POST' &&
          decodedBody is Map) {
        lastCommandBody = decodedBody.cast<String, Object?>();
      }
      if (request.uri.path == '/session/ses_page/message' &&
          request.method == 'GET') {
        lastMessagesQuery = request.uri.queryParameters;
        if (request.uri.queryParameters['before'] == null) {
          request.response.headers.set('x-next-cursor', 'cursor_older_page');
        }
      }
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
            'info': {
              'id': 'msg_1',
              'role': 'user',
              'agent': 'Sisyphus',
              'variant': 'medium',
              'model': {'providerID': 'openai', 'modelID': 'gpt-5.4'},
            },
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
        '/session/ses_2/command' when request.method == 'POST' => {
          'info': {
            'id': 'msg_4',
            'role': 'assistant',
            'sessionID': 'ses_2',
            'providerID': 'openai',
            'modelID': 'gpt-5',
          },
          'parts': [
            {'id': 'prt_5', 'type': 'text', 'text': 'command ok'},
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
        '/session/ses_page/message' =>
          request.uri.queryParameters['before'] == null
              ? [
                  {
                    'info': {'id': 'msg_page_2', 'role': 'assistant'},
                    'parts': [
                      {
                        'id': 'prt_page_2',
                        'type': 'text',
                        'text': 'newer page',
                      },
                    ],
                  },
                ]
              : [
                  {
                    'info': {'id': 'msg_page_1', 'role': 'assistant'},
                    'parts': [
                      {
                        'id': 'prt_page_1',
                        'type': 'text',
                        'text': 'older page',
                      },
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
    'fetches sessions while defaulting selection to the first root session',
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

      expect(bundle.sessions.length, 2);
      expect(bundle.sessions.map((session) => session.id), <String>[
        'ses_1',
        'ses_2',
      ]);
      expect(bundle.selectedSessionId, 'ses_1');
      expect(bundle.statuses['ses_1']?.type, 'busy');
      expect(bundle.messages.length, 2);
      expect(bundle.messages.first.info.agent, 'Sisyphus');
      expect(bundle.messages.first.info.providerId, 'openai');
      expect(bundle.messages.first.info.modelId, 'gpt-5.4');
      expect(bundle.messages.first.info.variant, 'medium');
      expect(bundle.messages.last.parts.last.text, 'done');
      service.dispose();
    },
  );

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

    expect(messages, hasLength(2));
    expect(messages.first.parts.single.text, 'kept message');
    expect(messages.last.info.metadata['quarantined'], isTrue);
    expect(messages.last.info.metadata['reason'], 'parse-failed');
    service.dispose();
  });

  test('fetches a paged session history cursor window', () async {
    final service = ChatService();
    final profile = ServerProfile(
      id: 'server',
      label: 'mock',
      baseUrl: baseUri.toString(),
    );
    const project = ProjectTarget(directory: '/workspace/demo', label: 'Demo');

    final firstPage = await service.fetchMessagesPage(
      profile: profile,
      project: project,
      sessionId: 'ses_page',
      limit: 25,
    );

    expect(firstPage.messages.single.info.id, 'msg_page_2');
    expect(firstPage.nextCursor, 'cursor_older_page');
    expect(lastMessagesQuery, <String, String>{
      'directory': '/workspace/demo',
      'limit': '25',
    });

    final olderPage = await service.fetchMessagesPage(
      profile: profile,
      project: project,
      sessionId: 'ses_page',
      limit: 25,
      before: 'cursor_older_page',
    );

    expect(olderPage.messages.single.info.id, 'msg_page_1');
    expect(olderPage.nextCursor, isNull);
    expect(lastMessagesQuery, <String, String>{
      'directory': '/workspace/demo',
      'limit': '25',
      'before': 'cursor_older_page',
    });
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
      agent: 'Sisyphus',
      providerId: 'openai',
      modelId: 'gpt-5.4',
      variant: 'medium',
      reasoning: 'medium',
    );

    expect(session.id, 'ses_2');
    expect(message.info.id, 'msg_3');
    expect(message.parts.single.text, 'ok');
    expect(lastPromptBody?['agent'], 'Sisyphus');
    expect(lastPromptBody?['providerID'], 'openai');
    expect(lastPromptBody?['modelID'], 'gpt-5.4');
    expect(lastPromptBody?['variant'], 'medium');
    expect(lastPromptBody?['reasoning'], 'medium');
    expect(lastPromptBody?['model'], <String, Object?>{
      'providerID': 'openai',
      'modelID': 'gpt-5.4',
    });
    service.dispose();
  });

  test('sends file attachments alongside a prompt message', () async {
    final service = ChatService();
    final profile = ServerProfile(
      id: 'server',
      label: 'mock',
      baseUrl: baseUri.toString(),
    );

    await service.sendMessage(
      profile: profile,
      project: const ProjectTarget(directory: '/workspace/demo', label: 'Demo'),
      sessionId: 'ses_2',
      prompt: 'Review this file',
      attachments: const <PromptAttachment>[
        PromptAttachment(
          id: 'att_1',
          filename: 'notes.txt',
          mime: 'text/plain',
          url: 'data:text/plain;base64,SGVsbG8=',
        ),
      ],
    );

    expect(lastPromptBody?['parts'], <Map<String, Object?>>[
      <String, Object?>{'type': 'text', 'text': 'Review this file'},
      <String, Object?>{
        'type': 'file',
        'mime': 'text/plain',
        'filename': 'notes.txt',
        'url': 'data:text/plain;base64,SGVsbG8=',
      },
    ]);
    service.dispose();
  });

  test('sends a slash command message', () async {
    final service = ChatService();
    final profile = ServerProfile(
      id: 'server',
      label: 'mock',
      baseUrl: baseUri.toString(),
    );
    const project = ProjectTarget(directory: '/workspace/demo', label: 'Demo');

    final message = await service.sendCommand(
      profile: profile,
      project: project,
      sessionId: 'ses_2',
      command: 'share',
      arguments: 'now',
      agent: 'Sisyphus',
      providerId: 'openai',
      modelId: 'gpt-5.4',
      variant: 'medium',
    );

    expect(message.info.id, 'msg_4');
    expect(message.parts.single.text, 'command ok');
    expect(lastCommandBody?['command'], 'share');
    expect(lastCommandBody?['arguments'], 'now');
    expect(lastCommandBody?['agent'], 'Sisyphus');
    expect(lastCommandBody?['model'], 'openai/gpt-5.4');
    expect(lastCommandBody?['variant'], 'medium');
    service.dispose();
  });

  test('sends file attachments with slash commands', () async {
    final service = ChatService();
    final profile = ServerProfile(
      id: 'server',
      label: 'mock',
      baseUrl: baseUri.toString(),
    );

    await service.sendCommand(
      profile: profile,
      project: const ProjectTarget(directory: '/workspace/demo', label: 'Demo'),
      sessionId: 'ses_2',
      command: 'share',
      attachments: const <PromptAttachment>[
        PromptAttachment(
          id: 'att_1',
          filename: 'diagram.png',
          mime: 'image/png',
          url: 'data:image/png;base64,AA==',
        ),
      ],
    );

    expect(lastCommandBody?['parts'], <Map<String, Object?>>[
      <String, Object?>{
        'type': 'file',
        'mime': 'image/png',
        'filename': 'diagram.png',
        'url': 'data:image/png;base64,AA==',
      },
    ]);
    service.dispose();
  });
}
