import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:better_opencode_client/src/core/connection/connection_models.dart';
import 'package:better_opencode_client/src/core/network/event_stream_service.dart';
import 'package:better_opencode_client/src/core/persistence/stale_cache_store.dart';
import 'package:better_opencode_client/src/core/spec/raw_json_document.dart';
import 'package:better_opencode_client/src/features/chat/chat_models.dart';
import 'package:better_opencode_client/src/features/chat/chat_service.dart';
import 'package:better_opencode_client/src/features/chat/prompt_attachment_models.dart';
import 'package:better_opencode_client/src/features/chat/session_action_service.dart';
import 'package:better_opencode_client/src/features/files/file_browser_service.dart';
import 'package:better_opencode_client/src/features/files/file_models.dart';
import 'package:better_opencode_client/src/features/files/review_diff_service.dart';
import 'package:better_opencode_client/src/features/projects/project_catalog_service.dart';
import 'package:better_opencode_client/src/features/projects/project_models.dart';
import 'package:better_opencode_client/src/features/projects/project_store.dart';
import 'package:better_opencode_client/src/features/requests/request_models.dart';
import 'package:better_opencode_client/src/features/requests/request_service.dart';
import 'package:better_opencode_client/src/features/settings/agent_service.dart';
import 'package:better_opencode_client/src/features/settings/config_service.dart';
import 'package:better_opencode_client/src/features/tools/todo_models.dart';
import 'package:better_opencode_client/src/features/tools/todo_service.dart';
import 'package:better_opencode_client/src/features/web_parity/workspace_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  const profile = ServerProfile(
    id: 'server',
    label: 'Mock',
    baseUrl: 'http://localhost:3000',
  );
  const project = ProjectTarget(
    directory: '/workspace/demo',
    label: 'Demo',
    source: 'server',
    vcs: 'git',
    branch: 'main',
  );

  test(
    'controller adds externally created root sessions in real time',
    () async {
      final eventStreamService = _ControlledEventStreamService();
      final controller = _buildController(
        profile: profile,
        project: project,
        eventStreamService: eventStreamService,
      );
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.visibleSessions.map((item) => item.id), <String>[
        'ses_1',
      ]);
      expect(controller.selectedSessionId, 'ses_1');

      eventStreamService.emitToScope(
        profile,
        project,
        EventEnvelope(
          type: 'session.created',
          properties: <String, Object?>{
            'sessionID': 'ses_2',
            'info': <String, Object?>{
              'id': 'ses_2',
              'directory': '/workspace/demo',
              'title': 'External session',
              'version': '1',
              'time': <String, Object?>{
                'created': 1710000007000,
                'updated': 1710000007000,
              },
            },
          },
        ),
      );

      expect(controller.visibleSessions.map((item) => item.id), <String>[
        'ses_2',
        'ses_1',
      ]);
      expect(controller.visibleSessions.first.title, 'External session');
      expect(controller.selectedSessionId, 'ses_1');
    },
  );

  test(
    'controller recovers live sync after stream completion without duplicate subscriptions',
    () async {
      final eventStreamService = _ControlledEventStreamService();
      final controller = _buildController(
        profile: profile,
        project: project,
        eventStreamService: eventStreamService,
      );
      addTearDown(controller.dispose);

      await controller.load();
      expect(controller.recoveringEventStream, isFalse);
      expect(controller.eventStreamRecoveryError, isNull);
      expect(
        eventStreamService.activeSubscriptionCountForScope(profile, project),
        1,
      );

      eventStreamService.completeScope(profile, project);
      await _waitFor(
        () =>
            !controller.recoveringEventStream &&
            eventStreamService.connectCallCount >= 2,
      );

      expect(controller.recoveringEventStream, isFalse);
      expect(controller.eventStreamRecoveryError, isNull);
      expect(eventStreamService.connectCallCount, greaterThanOrEqualTo(2));
      expect(eventStreamService.disconnectCallCount, greaterThanOrEqualTo(2));
      expect(
        eventStreamService.activeSubscriptionCountForScope(profile, project),
        1,
      );

      eventStreamService.emitToScope(
        profile,
        project,
        EventEnvelope(
          type: 'message.part.updated',
          properties: <String, Object?>{
            'part': <String, Object?>{
              'id': 'part_recovered',
              'messageID': 'msg_recovered',
              'sessionID': 'ses_1',
              'type': 'text',
              'content': 'Recovered after onDone',
            },
          },
        ),
      );

      expect(controller.messages, hasLength(1));
      expect(
        controller.messages.single.parts.single.text,
        'Recovered after onDone',
      );

      eventStreamService.emitToScope(
        profile,
        project,
        EventEnvelope(
          type: 'session.created',
          properties: <String, Object?>{
            'sessionID': 'ses_2',
            'info': <String, Object?>{
              'id': 'ses_2',
              'directory': '/workspace/demo',
              'title': 'Recovered background session',
              'version': '1',
            },
          },
        ),
      );

      eventStreamService.emitToScope(
        profile,
        project,
        const EventEnvelope(
          type: 'session.error',
          properties: <String, Object?>{'sessionID': 'ses_2'},
        ),
      );

      expect(
        controller.sessionNotificationForSession('ses_2'),
        const WorkspaceSidebarNotificationState(unseenCount: 1, hasError: true),
      );
    },
  );

  test(
    'controller recovers live sync after stream error and continues todo/permission updates',
    () async {
      final eventStreamService = _ControlledEventStreamService();
      final controller = _buildController(
        profile: profile,
        project: project,
        eventStreamService: eventStreamService,
      );
      addTearDown(controller.dispose);

      await controller.load();
      expect(controller.todos, isEmpty);
      expect(controller.currentPermissionRequest, isNull);
      expect(
        eventStreamService.activeSubscriptionCountForScope(profile, project),
        1,
      );

      eventStreamService.emitErrorToScope(
        profile,
        project,
        StateError('stream dropped'),
      );
      await _waitFor(
        () =>
            !controller.recoveringEventStream &&
            eventStreamService.connectCallCount >= 2,
      );

      expect(controller.recoveringEventStream, isFalse);
      expect(controller.eventStreamRecoveryError, isNull);
      expect(eventStreamService.connectCallCount, greaterThanOrEqualTo(2));
      expect(
        eventStreamService.activeSubscriptionCountForScope(profile, project),
        1,
      );

      eventStreamService.emitToScope(
        profile,
        project,
        const EventEnvelope(
          type: 'todo.updated',
          properties: <String, Object?>{
            'sessionID': 'ses_1',
            'todos': <Object?>[
              <String, Object?>{
                'id': 'todo_recovered',
                'content': 'todo after onError',
                'status': 'in_progress',
                'priority': 'high',
              },
            ],
          },
        ),
      );

      expect(controller.todos, hasLength(1));
      expect(controller.todos.single.content, 'todo after onError');

      eventStreamService.emitToScope(
        profile,
        project,
        const EventEnvelope(
          type: 'permission.asked',
          properties: <String, Object?>{
            'id': 'per_recovered',
            'sessionID': 'ses_1',
            'permission': 'bash',
            'patterns': <Object?>['flutter test'],
          },
        ),
      );

      expect(controller.currentPermissionRequest?.id, 'per_recovered');
    },
  );

  test(
    'controller reloads sessions, messages, and pending requests after a stream resync request',
    () async {
      final eventStreamService = _ControlledEventStreamService();
      final requestService = _FakeRequestService();
      final rootSession = _session(
        id: 'ses_root',
        title: 'Root session',
        createdAt: 1710000001000,
        updatedAt: 1710000005000,
      );
      final childSession = _session(
        id: 'ses_child',
        title: 'Running child session',
        createdAt: 1710000002000,
        updatedAt: 1710000009000,
        parentId: 'ses_root',
      );
      final messagesBySessionId = <String, List<ChatMessage>>{
        'ses_root': const <ChatMessage>[],
      };
      final chatService = _FakeChatService(
        bundle: ChatSessionBundle(
          sessions: <SessionSummary>[rootSession],
          statuses: const <String, SessionStatusSummary>{
            'ses_root': SessionStatusSummary(type: 'idle'),
          },
          messages: const <ChatMessage>[],
          selectedSessionId: 'ses_root',
        ),
        fetchMessagesPageHandler:
            ({
              required profile,
              required project,
              required sessionId,
              required limit,
              before,
            }) async => ChatMessagePage(
              messages: messagesBySessionId[sessionId] ?? const <ChatMessage>[],
            ),
      );
      final controller = _buildController(
        profile: profile,
        project: project,
        eventStreamService: eventStreamService,
        chatService: chatService,
        requestService: requestService,
      );
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.messages, isEmpty);
      expect(controller.activeChildSessions, isEmpty);
      expect(controller.pendingRequests.questions, isEmpty);

      messagesBySessionId['ses_root'] = <ChatMessage>[
        _message(
          id: 'msg_resynced',
          sessionId: 'ses_root',
          text: 'Fresh content after resync',
          createdAt: 1710000010000,
        ),
      ];
      chatService.bundle = ChatSessionBundle(
        sessions: <SessionSummary>[childSession, rootSession],
        statuses: const <String, SessionStatusSummary>{
          'ses_root': SessionStatusSummary(type: 'idle'),
          'ses_child': SessionStatusSummary(type: 'busy'),
        },
        messages: const <ChatMessage>[],
        selectedSessionId: 'ses_root',
      );
      requestService.pendingBundle = const PendingRequestBundle(
        questions: <QuestionRequestSummary>[
          QuestionRequestSummary(
            id: 'q_child',
            sessionId: 'ses_child',
            questions: <QuestionPromptSummary>[
              QuestionPromptSummary(
                question: 'Can I proceed?',
                header: 'Approval',
                options: <QuestionOptionSummary>[],
                multiple: false,
              ),
            ],
          ),
        ],
        permissions: <PermissionRequestSummary>[],
      );

      eventStreamService.emitToScope(
        profile,
        project,
        const EventEnvelope(
          type: 'stream.resync_required',
          properties: <String, Object?>{},
        ),
      );
      await _waitFor(
        () =>
            !controller.recoveringEventStream &&
            eventStreamService.connectCallCount >= 2,
      );

      expect(controller.eventStreamRecoveryError, isNull);
      expect(
        controller.messages.single.parts.single.text,
        'Fresh content after resync',
      );
      expect(
        controller.activeChildSessions.map((session) => session.id),
        <String>['ses_child'],
      );
      expect(controller.currentQuestionRequest?.id, 'q_child');
    },
  );

  test(
    'controller tracks unseen sidebar notifications for background sessions',
    () async {
      final eventStreamService = _ControlledEventStreamService();
      final chatService = _FakeChatService(
        bundle: ChatSessionBundle(
          sessions: <SessionSummary>[
            _session(
              id: 'ses_2',
              title: 'Background session',
              createdAt: 1710000007000,
              updatedAt: 1710000007000,
            ),
            _session(
              id: 'ses_1',
              title: 'Initial session',
              createdAt: 1710000001000,
              updatedAt: 1710000005000,
            ),
          ],
          statuses: const <String, SessionStatusSummary>{
            'ses_1': SessionStatusSummary(type: 'idle'),
            'ses_2': SessionStatusSummary(type: 'idle'),
          },
          messages: const <ChatMessage>[],
          selectedSessionId: 'ses_1',
        ),
      );
      final controller = _buildController(
        profile: profile,
        project: project,
        eventStreamService: eventStreamService,
        chatService: chatService,
        initialSessions: <SessionSummary>[
          _session(
            id: 'ses_2',
            title: 'Background session',
            createdAt: 1710000007000,
            updatedAt: 1710000007000,
          ),
          _session(
            id: 'ses_1',
            title: 'Initial session',
            createdAt: 1710000001000,
            updatedAt: 1710000005000,
          ),
        ],
      );
      addTearDown(controller.dispose);

      await controller.load();

      expect(
        controller.sessionNotificationForSession('ses_2'),
        const WorkspaceSidebarNotificationState(),
      );

      eventStreamService.emitToScope(
        profile,
        project,
        const EventEnvelope(
          type: 'session.status',
          properties: <String, Object?>{
            'sessionID': 'ses_2',
            'status': <String, Object?>{'type': 'busy'},
          },
        ),
      );
      eventStreamService.emitToScope(
        profile,
        project,
        const EventEnvelope(
          type: 'session.status',
          properties: <String, Object?>{
            'sessionID': 'ses_2',
            'status': <String, Object?>{'type': 'idle'},
          },
        ),
      );

      expect(
        controller.sessionNotificationForSession('ses_2'),
        const WorkspaceSidebarNotificationState(unseenCount: 1),
      );
      expect(
        controller.projectNotificationForDirectory('/workspace/demo'),
        const WorkspaceSidebarNotificationState(unseenCount: 1),
      );

      eventStreamService.emitToScope(
        profile,
        project,
        const EventEnvelope(
          type: 'session.error',
          properties: <String, Object?>{'sessionID': 'ses_2'},
        ),
      );

      expect(
        controller.sessionNotificationForSession('ses_2'),
        const WorkspaceSidebarNotificationState(unseenCount: 2, hasError: true),
      );

      await controller.selectSession('ses_2');

      expect(
        controller.sessionNotificationForSession('ses_2'),
        const WorkspaceSidebarNotificationState(),
      );
      expect(
        controller.projectNotificationForDirectory('/workspace/demo'),
        const WorkspaceSidebarNotificationState(),
      );
    },
  );

  test('controller caches ordered timeline and context derivations', () async {
    final eventStreamService = _ControlledEventStreamService();
    final olderMessage = ChatMessage(
      info: ChatMessageInfo(
        id: 'msg_older',
        role: 'assistant',
        sessionId: 'ses_1',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1710000001000),
        completedAt: DateTime.fromMillisecondsSinceEpoch(1710000002000),
        cost: 0.12,
        inputTokens: 120,
        outputTokens: 40,
      ),
      parts: const <ChatPart>[
        ChatPart(
          id: 'part_older',
          type: 'text',
          text: 'Older assistant reply',
          messageId: 'msg_older',
          sessionId: 'ses_1',
        ),
      ],
    );
    final newerMessage = ChatMessage(
      info: ChatMessageInfo(
        id: 'msg_newer',
        role: 'user',
        sessionId: 'ses_1',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1710000003000),
        completedAt: DateTime.fromMillisecondsSinceEpoch(1710000003000),
      ),
      parts: const <ChatPart>[
        ChatPart(
          id: 'part_newer',
          type: 'text',
          text: 'Latest user prompt',
          messageId: 'msg_newer',
          sessionId: 'ses_1',
        ),
      ],
    );
    final chatService = _FakeChatService(
      bundle: ChatSessionBundle(
        sessions: <SessionSummary>[
          _session(
            id: 'ses_1',
            title: 'Initial session',
            createdAt: 1710000001000,
            updatedAt: 1710000005000,
          ),
        ],
        statuses: const <String, SessionStatusSummary>{
          'ses_1': SessionStatusSummary(type: 'idle'),
        },
        messages: const <ChatMessage>[],
        selectedSessionId: 'ses_1',
      ),
      fetchMessagesHandler:
          ({
            required ServerProfile profile,
            required ProjectTarget project,
            required String sessionId,
          }) async => <ChatMessage>[newerMessage, olderMessage],
    );
    final controller = _buildController(
      profile: profile,
      project: project,
      eventStreamService: eventStreamService,
      chatService: chatService,
    );
    addTearDown(controller.dispose);

    await controller.load();

    final orderedMessages = controller.orderedMessages;
    final repeatedOrderedMessages = controller.orderedMessages;
    final metrics = controller.sessionContextMetrics;
    final repeatedMetrics = controller.sessionContextMetrics;

    expect(orderedMessages.map((message) => message.info.id), <String>[
      'msg_older',
      'msg_newer',
    ]);
    expect(identical(orderedMessages, repeatedOrderedMessages), isTrue);
    expect(identical(metrics, repeatedMetrics), isTrue);
    expect(controller.timelineContentSignature, isNonZero);
    expect(metrics.totalCost, 0.12);
    expect(controller.userMessageCount, 1);
    expect(controller.assistantMessageCount, 1);
  });

  test(
    'controller falls back to a surviving session when selected tree is deleted remotely',
    () async {
      final eventStreamService = _ControlledEventStreamService();
      final cacheStore = _RecordingCacheStore();
      final projectStore = _MemoryProjectStore();
      cacheStore
              .entries['workspace.messages::${profile.storageKey}::${project.directory}::ses_root'] =
          StaleCacheEntry(
            payloadJson: '[]',
            signature: 'root',
            fetchedAt: DateTime.fromMillisecondsSinceEpoch(1710000002000),
          );
      cacheStore
              .entries['workspace.messages.spill::${profile.storageKey}::${project.directory}::ses_root'] =
          StaleCacheEntry(
            payloadJson: '[]',
            signature: 'root-spill',
            fetchedAt: DateTime.fromMillisecondsSinceEpoch(1710000002000),
          );
      cacheStore
              .entries['workspace.messages::${profile.storageKey}::${project.directory}::ses_child'] =
          StaleCacheEntry(
            payloadJson: '[]',
            signature: 'child',
            fetchedAt: DateTime.fromMillisecondsSinceEpoch(1710000003000),
          );
      cacheStore
              .entries['workspace.messages.spill::${profile.storageKey}::${project.directory}::ses_child'] =
          StaleCacheEntry(
            payloadJson: '[]',
            signature: 'child-spill',
            fetchedAt: DateTime.fromMillisecondsSinceEpoch(1710000003000),
          );
      final chatService = _FakeChatService(
        bundle: ChatSessionBundle(
          sessions: <SessionSummary>[
            _session(
              id: 'ses_root',
              title: 'Root',
              createdAt: 1710000001000,
              updatedAt: 1710000005000,
            ),
            _session(
              id: 'ses_child',
              title: 'Child',
              createdAt: 1710000002000,
              updatedAt: 1710000006000,
              parentId: 'ses_root',
            ),
            _session(
              id: 'ses_other',
              title: 'Other',
              createdAt: 1710000009000,
              updatedAt: 1710000009000,
            ),
          ],
          statuses: const <String, SessionStatusSummary>{
            'ses_root': SessionStatusSummary(type: 'idle'),
            'ses_child': SessionStatusSummary(type: 'idle'),
            'ses_other': SessionStatusSummary(type: 'idle'),
          },
          messages: const <ChatMessage>[],
          selectedSessionId: 'ses_root',
        ),
        fetchMessagesHandler:
            ({required profile, required project, required sessionId}) async {
              if (sessionId != 'ses_other') {
                return const <ChatMessage>[];
              }
              return <ChatMessage>[
                _message(
                  id: 'msg_other',
                  sessionId: 'ses_other',
                  text: 'Fallback session loaded',
                  createdAt: 1710000010000,
                ),
              ];
            },
      );
      final controller = _buildController(
        profile: profile,
        project: project,
        eventStreamService: eventStreamService,
        chatService: chatService,
        cacheStore: cacheStore,
        spillStore: cacheStore,
        projectStore: projectStore,
        initialSelectedSessionId: 'ses_root',
        initialSessions: <SessionSummary>[
          _session(
            id: 'ses_root',
            title: 'Root',
            createdAt: 1710000001000,
            updatedAt: 1710000005000,
          ),
          _session(
            id: 'ses_child',
            title: 'Child',
            createdAt: 1710000002000,
            updatedAt: 1710000006000,
            parentId: 'ses_root',
          ),
          _session(
            id: 'ses_other',
            title: 'Other',
            createdAt: 1710000009000,
            updatedAt: 1710000009000,
          ),
        ],
      );
      addTearDown(controller.dispose);

      await controller.load();
      expect(controller.selectedSessionId, 'ses_root');

      eventStreamService.emitToScope(
        profile,
        project,
        const EventEnvelope(
          type: 'session.deleted',
          properties: <String, Object?>{
            'sessionID': 'ses_root',
            'info': <String, Object?>{'id': 'ses_root'},
          },
        ),
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(controller.selectedSessionId, 'ses_other');
      expect(controller.visibleSessions.map((item) => item.id), <String>[
        'ses_other',
      ]);
      expect(controller.messages.map((message) => message.info.id), <String>[
        'msg_other',
      ]);
      expect(
        cacheStore.entries.containsKey(
          'workspace.messages::${profile.storageKey}::${project.directory}::ses_root',
        ),
        isFalse,
      );
      expect(
        cacheStore.entries.containsKey(
          'workspace.messages.spill::${profile.storageKey}::${project.directory}::ses_root',
        ),
        isFalse,
      );
      expect(
        cacheStore.entries.containsKey(
          'workspace.messages::${profile.storageKey}::${project.directory}::ses_child',
        ),
        isFalse,
      );
      expect(
        cacheStore.entries.containsKey(
          'workspace.messages.spill::${profile.storageKey}::${project.directory}::ses_child',
        ),
        isFalse,
      );
      expect(
        projectStore.savedLastWorkspaceTargets.last.lastSession?.id,
        'ses_other',
      );
    },
  );

  test(
    'controller removes only the non-selected deleted tree and stale session state',
    () async {
      final eventStreamService = _ControlledEventStreamService();
      final cacheStore = _RecordingCacheStore();
      final chatService = _FakeChatService(
        bundle: ChatSessionBundle(
          sessions: <SessionSummary>[
            _session(
              id: 'ses_root',
              title: 'Root',
              createdAt: 1710000001000,
              updatedAt: 1710000005000,
            ),
            _session(
              id: 'ses_child',
              title: 'Child',
              createdAt: 1710000002000,
              updatedAt: 1710000006000,
              parentId: 'ses_root',
            ),
            _session(
              id: 'ses_other',
              title: 'Other',
              createdAt: 1710000007000,
              updatedAt: 1710000007000,
            ),
          ],
          statuses: const <String, SessionStatusSummary>{
            'ses_root': SessionStatusSummary(type: 'idle'),
            'ses_child': SessionStatusSummary(type: 'idle'),
            'ses_other': SessionStatusSummary(type: 'idle'),
          },
          messages: const <ChatMessage>[],
          selectedSessionId: 'ses_root',
        ),
        fetchMessagesHandler:
            ({required profile, required project, required sessionId}) async {
              if (sessionId != 'ses_child') {
                return const <ChatMessage>[];
              }
              return <ChatMessage>[
                _message(
                  id: 'msg_child_preview',
                  sessionId: 'ses_child',
                  text: 'Child preview text',
                  createdAt: 1710000009000,
                  role: 'user',
                ),
              ];
            },
      );
      final requestService = _FakeRequestService(
        pendingBundle: PendingRequestBundle(
          questions: <QuestionRequestSummary>[
            QuestionRequestSummary(
              id: 'q_child',
              sessionId: 'ses_child',
              questions: const <QuestionPromptSummary>[
                QuestionPromptSummary(
                  question: 'Child question?',
                  header: 'Question',
                  multiple: false,
                  options: <QuestionOptionSummary>[],
                ),
              ],
            ),
            QuestionRequestSummary(
              id: 'q_other',
              sessionId: 'ses_other',
              questions: const <QuestionPromptSummary>[
                QuestionPromptSummary(
                  question: 'Other question?',
                  header: 'Question',
                  multiple: false,
                  options: <QuestionOptionSummary>[],
                ),
              ],
            ),
          ],
          permissions: const <PermissionRequestSummary>[],
        ),
      );
      cacheStore
              .entries['workspace.messages::${profile.storageKey}::${project.directory}::ses_child'] =
          StaleCacheEntry(
            payloadJson: '[]',
            signature: 'child',
            fetchedAt: DateTime.fromMillisecondsSinceEpoch(1710000003000),
          );
      cacheStore
              .entries['workspace.messages::${profile.storageKey}::${project.directory}::ses_other'] =
          StaleCacheEntry(
            payloadJson: '[]',
            signature: 'other',
            fetchedAt: DateTime.fromMillisecondsSinceEpoch(1710000004000),
          );
      final controller = _buildController(
        profile: profile,
        project: project,
        eventStreamService: eventStreamService,
        chatService: chatService,
        cacheStore: cacheStore,
        requestService: requestService,
        initialSelectedSessionId: 'ses_root',
        initialSessions: <SessionSummary>[
          _session(
            id: 'ses_root',
            title: 'Root',
            createdAt: 1710000001000,
            updatedAt: 1710000005000,
          ),
          _session(
            id: 'ses_child',
            title: 'Child',
            createdAt: 1710000002000,
            updatedAt: 1710000006000,
            parentId: 'ses_root',
          ),
          _session(
            id: 'ses_other',
            title: 'Other',
            createdAt: 1710000007000,
            updatedAt: 1710000007000,
          ),
        ],
      );
      addTearDown(controller.dispose);

      await controller.load();
      expect(controller.selectedSessionId, 'ses_root');

      eventStreamService.emitToScope(
        profile,
        project,
        const EventEnvelope(
          type: 'todo.updated',
          properties: <String, Object?>{
            'sessionID': 'ses_child',
            'info': <String, Object?>{
              'id': 'todo_child',
              'title': 'Child todo',
            },
          },
        ),
      );
      await controller.prefetchSessionHoverPreview('ses_child');
      eventStreamService.emitToScope(
        profile,
        project,
        const EventEnvelope(
          type: 'session.status',
          properties: <String, Object?>{
            'sessionID': 'ses_child',
            'status': <String, Object?>{'type': 'busy'},
          },
        ),
      );
      eventStreamService.emitToScope(
        profile,
        project,
        const EventEnvelope(
          type: 'message.part.updated',
          properties: <String, Object?>{
            'part': <String, Object?>{
              'id': 'part_child',
              'messageID': 'msg_child',
              'sessionID': 'ses_child',
              'type': 'text',
              'text': 'Working on child session',
            },
          },
        ),
      );

      expect(controller.activeChildSessionPreviewById['ses_child'], isNotNull);

      eventStreamService.emitToScope(
        profile,
        project,
        const EventEnvelope(
          type: 'session.deleted',
          properties: <String, Object?>{
            'sessionID': 'ses_child',
            'info': <String, Object?>{'id': 'ses_child'},
          },
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(controller.selectedSessionId, 'ses_root');
      expect(controller.sessions.map((item) => item.id), <String>[
        'ses_root',
        'ses_other',
      ]);
      expect(controller.todosForSession('ses_child'), isEmpty);
      expect(controller.activeChildSessionPreviewById['ses_child'], isNull);
      expect(
        controller.pendingRequests.questions.where(
          (request) => request.sessionId == 'ses_child',
        ),
        isEmpty,
      );
      expect(
        controller.sessionNotificationForSession('ses_child'),
        const WorkspaceSidebarNotificationState(),
      );
      expect(
        cacheStore.entries.containsKey(
          'workspace.messages::${profile.storageKey}::${project.directory}::ses_child',
        ),
        isFalse,
      );
      expect(
        cacheStore.entries.containsKey(
          'workspace.messages::${profile.storageKey}::${project.directory}::ses_other',
        ),
        isTrue,
      );
    },
  );

  test(
    'controller enters safe empty state when last session is deleted remotely',
    () async {
      final eventStreamService = _ControlledEventStreamService();
      final projectStore = _MemoryProjectStore();
      final cacheStore = _RecordingCacheStore();
      cacheStore
              .entries['workspace.messages::${profile.storageKey}::${project.directory}::ses_1'] =
          StaleCacheEntry(
            payloadJson: '[]',
            signature: 'one',
            fetchedAt: DateTime.fromMillisecondsSinceEpoch(1710000005000),
          );
      cacheStore
              .entries['workspace.messages.spill::${profile.storageKey}::${project.directory}::ses_1'] =
          StaleCacheEntry(
            payloadJson: '[]',
            signature: 'one-spill',
            fetchedAt: DateTime.fromMillisecondsSinceEpoch(1710000005000),
          );
      final chatService = _FakeChatService(
        bundle: ChatSessionBundle(
          sessions: <SessionSummary>[
            _session(
              id: 'ses_1',
              title: 'Only session',
              createdAt: 1710000001000,
              updatedAt: 1710000005000,
            ),
          ],
          statuses: const <String, SessionStatusSummary>{
            'ses_1': SessionStatusSummary(type: 'idle'),
          },
          messages: const <ChatMessage>[],
          selectedSessionId: 'ses_1',
        ),
        fetchMessagesHandler:
            ({required profile, required project, required sessionId}) async {
              return <ChatMessage>[
                _message(
                  id: 'msg_1',
                  sessionId: 'ses_1',
                  text: 'Initial message',
                  createdAt: 1710000006000,
                ),
              ];
            },
      );
      final controller = _buildController(
        profile: profile,
        project: project,
        eventStreamService: eventStreamService,
        chatService: chatService,
        cacheStore: cacheStore,
        spillStore: cacheStore,
        projectStore: projectStore,
        initialSelectedSessionId: 'ses_1',
        initialSessions: <SessionSummary>[
          _session(
            id: 'ses_1',
            title: 'Only session',
            createdAt: 1710000001000,
            updatedAt: 1710000005000,
          ),
        ],
      );
      addTearDown(controller.dispose);

      await controller.load();
      expect(controller.selectedSessionId, 'ses_1');
      expect(controller.messages, isNotEmpty);

      eventStreamService.emitToScope(
        profile,
        project,
        const EventEnvelope(
          type: 'session.deleted',
          properties: <String, Object?>{
            'sessionID': 'ses_1',
            'info': <String, Object?>{'id': 'ses_1'},
          },
        ),
      );
      await _waitFor(
        () =>
            controller.selectedSessionId == null &&
            !cacheStore.entries.containsKey(
              'workspace.messages::${profile.storageKey}::${project.directory}::ses_1',
            ) &&
            !cacheStore.entries.containsKey(
              'workspace.messages.spill::${profile.storageKey}::${project.directory}::ses_1',
            ),
      );

      expect(controller.selectedSessionId, isNull);
      expect(controller.visibleSessions, isEmpty);
      expect(controller.messages, isEmpty);
      expect(controller.todos, isEmpty);
      expect(controller.reviewStatuses, isEmpty);
      expect(controller.reviewDiff, isNull);
      expect(controller.reviewDiffError, isNull);
      expect(controller.pendingRequests.questions, isEmpty);
      expect(controller.pendingRequests.permissions, isEmpty);
      expect(
        cacheStore.entries.containsKey(
          'workspace.messages::${profile.storageKey}::${project.directory}::ses_1',
        ),
        isFalse,
      );
      expect(
        cacheStore.entries.containsKey(
          'workspace.messages.spill::${profile.storageKey}::${project.directory}::ses_1',
        ),
        isFalse,
      );
      expect(projectStore.savedLastWorkspaceTargets.last.lastSession, isNull);
    },
  );

  test(
    'controller ignores remote deletions safely when workspace is already empty',
    () async {
      final eventStreamService = _ControlledEventStreamService();
      final chatService = _FakeChatService(
        bundle: const ChatSessionBundle(
          sessions: <SessionSummary>[],
          statuses: <String, SessionStatusSummary>{},
          messages: <ChatMessage>[],
          selectedSessionId: null,
        ),
      );
      final controller = _buildController(
        profile: profile,
        project: project,
        eventStreamService: eventStreamService,
        chatService: chatService,
        initialSessions: const <SessionSummary>[],
        initialSelectedSessionId: null,
      );
      addTearDown(controller.dispose);

      await controller.load();
      expect(controller.visibleSessions, isEmpty);
      expect(controller.selectedSessionId, isNull);

      eventStreamService.emitToScope(
        profile,
        project,
        const EventEnvelope(
          type: 'session.deleted',
          properties: <String, Object?>{
            'sessionID': 'ses_missing',
            'info': <String, Object?>{'id': 'ses_missing'},
          },
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(controller.visibleSessions, isEmpty);
      expect(controller.selectedSessionId, isNull);
      expect(controller.messages, isEmpty);
      expect(controller.todos, isEmpty);
      expect(controller.pendingRequests.questions, isEmpty);
      expect(controller.pendingRequests.permissions, isEmpty);
    },
  );

  test(
    'controller reuses watched session timelines when switching pane focus',
    () async {
      final eventStreamService = _ControlledEventStreamService();
      final fetchCounts = <String, int>{};
      final cacheStore = _RecordingCacheStore();
      cacheStore
              .entries['workspace.messages::${profile.storageKey}::${project.directory}::ses_2'] =
          StaleCacheEntry(
            payloadJson: jsonEncode(<Object?>[
              _message(
                id: 'msg_ses_2',
                sessionId: 'ses_2',
                text: 'hello two',
                createdAt: 1710000007000,
              ).toJson(),
            ]),
            signature: 'watched-cache',
            fetchedAt: DateTime.fromMillisecondsSinceEpoch(1710000007000),
          );
      final chatService = _FakeChatService(
        bundle: ChatSessionBundle(
          sessions: <SessionSummary>[
            _session(
              id: 'ses_2',
              title: 'Second session',
              createdAt: 1710000007000,
              updatedAt: 1710000007000,
            ),
            _session(
              id: 'ses_1',
              title: 'Initial session',
              createdAt: 1710000001000,
              updatedAt: 1710000005000,
            ),
          ],
          statuses: const <String, SessionStatusSummary>{
            'ses_1': SessionStatusSummary(type: 'idle'),
            'ses_2': SessionStatusSummary(type: 'idle'),
          },
          messages: const <ChatMessage>[],
          selectedSessionId: 'ses_1',
        ),
        fetchMessagesHandler:
            ({required profile, required project, required sessionId}) async {
              fetchCounts[sessionId] = (fetchCounts[sessionId] ?? 0) + 1;
              final text = sessionId == 'ses_2' ? 'hello two' : 'hello one';
              return <ChatMessage>[
                ChatMessage(
                  info: ChatMessageInfo(
                    id: 'msg_$sessionId',
                    role: 'assistant',
                    sessionId: sessionId,
                  ),
                  parts: <ChatPart>[
                    ChatPart(
                      id: 'part_$sessionId',
                      type: 'text',
                      text: text,
                      messageId: 'msg_$sessionId',
                      sessionId: sessionId,
                    ),
                  ],
                ),
              ];
            },
      );
      final controller = _buildController(
        profile: profile,
        project: project,
        eventStreamService: eventStreamService,
        chatService: chatService,
        cacheStore: cacheStore,
        initialSessions: <SessionSummary>[
          _session(
            id: 'ses_2',
            title: 'Second session',
            createdAt: 1710000007000,
            updatedAt: 1710000007000,
          ),
          _session(
            id: 'ses_1',
            title: 'Initial session',
            createdAt: 1710000001000,
            updatedAt: 1710000005000,
          ),
        ],
      );
      addTearDown(controller.dispose);

      await controller.load();

      expect(fetchCounts['ses_1'], 1);
      expect(controller.messages.single.parts.single.text, 'hello one');

      controller.updateWatchedSessionIds(const <String?>['ses_2']);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(fetchCounts['ses_2'], isNull);
      expect(
        controller
            .timelineStateForSession('ses_2')
            .orderedMessages
            .single
            .parts
            .single
            .text,
        'hello two',
      );

      eventStreamService.emitToScope(
        profile,
        project,
        EventEnvelope(
          type: 'message.part.updated',
          properties: <String, Object?>{
            'part': <String, Object?>{
              'id': 'part_msg_ses_2',
              'messageID': 'msg_ses_2',
              'sessionID': 'ses_2',
              'type': 'text',
              'content': 'hello two live',
            },
          },
        ),
      );

      expect(
        controller
            .timelineStateForSession('ses_2')
            .orderedMessages
            .single
            .parts
            .single
            .text,
        'hello two live',
      );

      controller.preserveSelectedSessionTimelineForWatch();
      await controller.selectSession('ses_2');

      expect(controller.selectedSessionId, 'ses_2');
      expect(controller.sessionLoading, isFalse);
      expect(controller.messages.single.parts.single.text, 'hello two live');
      expect(fetchCounts['ses_2'], isNull);
      expect(
        controller
            .timelineStateForSession('ses_1')
            .orderedMessages
            .single
            .parts
            .single
            .text,
        'hello one',
      );
    },
  );

  test(
    'controller backfills older history for the selected session from the server',
    () async {
      final requests = <({String sessionId, int limit, String? before})>[];
      final chatService = _FakeChatService(
        bundle: ChatSessionBundle(
          sessions: <SessionSummary>[
            _session(
              id: 'ses_1',
              title: 'Initial session',
              createdAt: 1710000001000,
              updatedAt: 1710000005000,
            ),
          ],
          statuses: const <String, SessionStatusSummary>{
            'ses_1': SessionStatusSummary(type: 'idle'),
          },
          messages: const <ChatMessage>[],
          selectedSessionId: 'ses_1',
        ),
        fetchMessagesPageHandler:
            ({
              required profile,
              required project,
              required sessionId,
              required limit,
              before,
            }) async {
              requests.add((
                sessionId: sessionId,
                limit: limit,
                before: before,
              ));
              return switch (before) {
                null => ChatMessagePage(
                  messages: <ChatMessage>[
                    _message(
                      id: 'msg_3',
                      sessionId: sessionId,
                      text: 'newer 3',
                      createdAt: 1710000003000,
                    ),
                    _message(
                      id: 'msg_4',
                      sessionId: sessionId,
                      text: 'newer 4',
                      createdAt: 1710000004000,
                    ),
                  ],
                  nextCursor: 'cursor_older_1',
                ),
                'cursor_older_1' => ChatMessagePage(
                  messages: <ChatMessage>[
                    _message(
                      id: 'msg_1',
                      sessionId: sessionId,
                      text: 'older 1',
                      createdAt: 1710000001000,
                    ),
                    _message(
                      id: 'msg_2',
                      sessionId: sessionId,
                      text: 'older 2',
                      createdAt: 1710000002000,
                    ),
                  ],
                ),
                _ => throw StateError('unexpected cursor: $before'),
              };
            },
      );
      final controller = _buildController(
        profile: profile,
        project: project,
        eventStreamService: _ControlledEventStreamService(),
        chatService: chatService,
      );
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.messages.map((message) => message.info.id), <String>[
        'msg_3',
        'msg_4',
      ]);
      expect(controller.timelineStateForSession('ses_1').historyMore, isTrue);

      await controller.loadMoreTimelineSessionHistory('ses_1');

      expect(requests, <({String sessionId, int limit, String? before})>[
        (
          sessionId: 'ses_1',
          limit: ChatService.globalSessionHistoryPageSize,
          before: null,
        ),
        (
          sessionId: 'ses_1',
          limit: ChatService.globalSessionHistoryPageSize,
          before: 'cursor_older_1',
        ),
      ]);
      expect(controller.messages.map((message) => message.info.id), <String>[
        'msg_1',
        'msg_2',
        'msg_3',
        'msg_4',
      ]);
      expect(controller.timelineStateForSession('ses_1').historyMore, isFalse);
      expect(
        controller.timelineStateForSession('ses_1').historyLoading,
        isFalse,
      );
    },
  );

  test(
    'controller keeps watched session history compact until selected',
    () async {
      final chatService = _FakeChatService(
        bundle: ChatSessionBundle(
          sessions: <SessionSummary>[
            _session(
              id: 'ses_2',
              title: 'Watched session',
              createdAt: 1710000007000,
              updatedAt: 1710000007000,
            ),
            _session(
              id: 'ses_1',
              title: 'Initial session',
              createdAt: 1710000001000,
              updatedAt: 1710000005000,
            ),
          ],
          statuses: const <String, SessionStatusSummary>{
            'ses_1': SessionStatusSummary(type: 'idle'),
            'ses_2': SessionStatusSummary(type: 'idle'),
          },
          messages: const <ChatMessage>[],
          selectedSessionId: 'ses_1',
        ),
        fetchMessagesPageHandler:
            ({
              required profile,
              required project,
              required sessionId,
              required limit,
              before,
            }) async {
              if (sessionId == 'ses_1') {
                return ChatMessagePage(
                  messages: <ChatMessage>[
                    _message(
                      id: 'msg_selected',
                      sessionId: sessionId,
                      text: 'selected',
                      createdAt: 1710000001000,
                    ),
                  ],
                );
              }
              return switch (before) {
                null => ChatMessagePage(
                  messages: <ChatMessage>[
                    _message(
                      id: 'msg_watch_3',
                      sessionId: sessionId,
                      text: 'watch newer 3',
                      createdAt: 1710000003000,
                    ),
                    _message(
                      id: 'msg_watch_4',
                      sessionId: sessionId,
                      text: 'watch newer 4',
                      createdAt: 1710000004000,
                    ),
                  ],
                  nextCursor: 'cursor_watch_1',
                ),
                'cursor_watch_1' => ChatMessagePage(
                  messages: <ChatMessage>[
                    _message(
                      id: 'msg_watch_1',
                      sessionId: sessionId,
                      text: 'watch older 1',
                      createdAt: 1710000001000,
                    ),
                    _message(
                      id: 'msg_watch_2',
                      sessionId: sessionId,
                      text: 'watch older 2',
                      createdAt: 1710000002000,
                    ),
                  ],
                ),
                _ => throw StateError('unexpected cursor: $before'),
              };
            },
      );
      final controller = _buildController(
        profile: profile,
        project: project,
        eventStreamService: _ControlledEventStreamService(),
        chatService: chatService,
        initialSessions: <SessionSummary>[
          _session(
            id: 'ses_2',
            title: 'Watched session',
            createdAt: 1710000007000,
            updatedAt: 1710000007000,
          ),
          _session(
            id: 'ses_1',
            title: 'Initial session',
            createdAt: 1710000001000,
            updatedAt: 1710000005000,
          ),
        ],
      );
      addTearDown(controller.dispose);

      await controller.load();
      controller.updateWatchedSessionIds(const <String?>['ses_2']);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(controller.timelineStateForSession('ses_2').historyMore, isFalse);

      await controller.loadMoreTimelineSessionHistory('ses_2');

      expect(controller.timelineStateForSession('ses_2').messages, isEmpty);
      expect(controller.timelineStateForSession('ses_2').historyMore, isFalse);
      expect(
        controller.timelineStateForSession('ses_2').historyLoading,
        isFalse,
      );
    },
  );

  test(
    'controller initializes git for no-VCS projects and refreshes project metadata',
    () async {
      final eventStreamService = _ControlledEventStreamService();
      final projectCatalogService = _FakeProjectCatalogService(
        const ProjectTarget(
          directory: '/workspace/demo',
          label: 'Demo',
          source: 'server',
        ),
      );
      final controller = _buildController(
        profile: profile,
        project: const ProjectTarget(
          directory: '/workspace/demo',
          label: 'Demo',
          source: 'server',
        ),
        eventStreamService: eventStreamService,
        projectCatalogService: projectCatalogService,
      );
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.project?.vcs, isNull);
      expect(controller.reviewStatuses, isEmpty);
      expect(controller.reviewDiffError, isNull);

      await controller.initializeGitRepository();

      expect(projectCatalogService.initGitCallCount, 1);
      expect(controller.project?.vcs, 'git');
      expect(controller.project?.branch, 'main');
      expect(controller.initializingGitRepository, isFalse);
      expect(controller.actionNotice, 'Git repository created.');
    },
  );

  test(
    'controller skips review diff loading when snapshot tracking is disabled',
    () async {
      final eventStreamService = _ControlledEventStreamService();
      final reviewDiffService = _TrackingReviewDiffService();
      final controller = _buildController(
        profile: profile,
        project: project,
        eventStreamService: eventStreamService,
        reviewDiffService: reviewDiffService,
        configService: _FakeConfigService(
          snapshot: ConfigSnapshot(
            config: RawJsonDocument(<String, Object?>{'snapshot': false}),
            providerConfig: RawJsonDocument(<String, Object?>{
              'providers': <Object?>[],
            }),
          ),
        ),
      );
      addTearDown(controller.dispose);

      await controller.load();

      expect(reviewDiffService.fetchCount, 0);
      expect(controller.reviewStatuses, isEmpty);
      expect(controller.reviewDiffError, isNull);
      expect(controller.loadingReviewDiff, isFalse);
    },
  );

  test('controller interrupts the selected busy session', () async {
    final eventStreamService = _ControlledEventStreamService();
    final sessionActionService = _RecordingSessionActionService();
    final controller = _buildController(
      profile: profile,
      project: project,
      eventStreamService: eventStreamService,
      sessionActionService: sessionActionService,
    );
    addTearDown(controller.dispose);

    await controller.load();

    eventStreamService.emitToScope(
      profile,
      project,
      const EventEnvelope(
        type: 'session.status',
        properties: <String, Object?>{
          'sessionID': 'ses_1',
          'status': <String, Object?>{'type': 'busy'},
        },
      ),
    );

    expect(controller.selectedSessionInterruptible, isTrue);

    final interrupted = await controller.interruptSelectedSession();

    expect(interrupted, isTrue);
    expect(sessionActionService.abortCalls, 1);
    expect(sessionActionService.lastAbortedSessionId, 'ses_1');
    expect(controller.selectedStatus?.type, 'idle');
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(controller.interruptingSession, isFalse);
  });

  test(
    'controller refuses session compaction when no available model can be resolved',
    () async {
      final eventStreamService = _ControlledEventStreamService();
      final sessionActionService = _RecordingSessionActionService();
      final controller = _buildController(
        profile: profile,
        project: project,
        eventStreamService: eventStreamService,
        sessionActionService: sessionActionService,
        configService: _FakeConfigService(),
      );
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.selectedModel, isNull);
      await expectLater(
        controller.summarizeSelectedSession,
        throwsA(
          isA<SessionActionException>().having(
            (error) => error.message,
            'message',
            'Session compaction requires an available model on this server.',
          ),
        ),
      );

      expect(sessionActionService.summarizeCalls, 0);
      expect(controller.actionNotice, isNull);
    },
  );

  test(
    'controller falls back to the catalog default when the transcript model is unavailable',
    () async {
      final eventStreamService = _ControlledEventStreamService();
      final sessionActionService = _RecordingSessionActionService();
      final sessionMessages = <ChatMessage>[
        _message(
          id: 'msg_user',
          sessionId: 'ses_1',
          text: 'Ship the fix',
          createdAt: 1710000002000,
          role: 'user',
          providerId: 'anthropic',
          modelId: 'claude-sonnet-4.5',
        ),
      ];
      final chatService = _FakeChatService(
        bundle: ChatSessionBundle(
          sessions: <SessionSummary>[
            _session(
              id: 'ses_1',
              title: 'Initial session',
              createdAt: 1710000001000,
              updatedAt: 1710000005000,
            ),
          ],
          statuses: const <String, SessionStatusSummary>{
            'ses_1': SessionStatusSummary(type: 'idle'),
          },
          messages: sessionMessages,
          selectedSessionId: 'ses_1',
        ),
        fetchMessagesHandler:
            ({
              required ServerProfile profile,
              required ProjectTarget project,
              required String sessionId,
            }) async => sessionMessages,
      );
      final controller = _buildController(
        profile: profile,
        project: project,
        eventStreamService: eventStreamService,
        chatService: chatService,
        sessionActionService: sessionActionService,
        configService: _FakeConfigService(snapshot: _composerConfigSnapshot()),
      );
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.selectedModel?.key, 'openai/gpt-4.1');
      await controller.summarizeSelectedSession();

      expect(sessionActionService.summarizeCalls, 1);
      expect(sessionActionService.lastSummarizedSessionId, 'ses_1');
      expect(sessionActionService.lastSummarizedProviderId, 'openai');
      expect(sessionActionService.lastSummarizedModelId, 'gpt-4.1');
      expect(controller.actionNotice, 'Session compaction requested.');
    },
  );

  test(
    'controller ignores stale configured compaction models when catalog models disagree',
    () async {
      final eventStreamService = _ControlledEventStreamService();
      final sessionActionService = _RecordingSessionActionService();
      final controller = _buildController(
        profile: profile,
        project: project,
        eventStreamService: eventStreamService,
        sessionActionService: sessionActionService,
        configService: _FakeConfigService(
          snapshot: ConfigSnapshot(
            config: RawJsonDocument(<String, Object?>{
              'model': 'anthropic/claude-sonnet-4.5',
            }),
            providerConfig: RawJsonDocument(<String, Object?>{
              'providers': <Object?>[
                <String, Object?>{
                  'id': 'openai',
                  'name': 'OpenAI',
                  'models': <String, Object?>{
                    'gpt-4.1': <String, Object?>{
                      'id': 'gpt-4.1',
                      'name': 'GPT-4.1',
                    },
                  },
                },
              ],
              'default': <String, Object?>{'openai': 'gpt-4.1'},
            }),
          ),
        ),
      );
      addTearDown(controller.dispose);

      await controller.load();

      await controller.summarizeSelectedSession();

      expect(sessionActionService.summarizeCalls, 1);
      expect(sessionActionService.lastSummarizedProviderId, 'openai');
      expect(sessionActionService.lastSummarizedModelId, 'gpt-4.1');
    },
  );

  test(
    'controller prefers an explicitly selected model over transcript metadata',
    () async {
      final eventStreamService = _ControlledEventStreamService();
      final sessionActionService = _RecordingSessionActionService();
      final configSnapshot = _multiProviderComposerConfigSnapshot();
      final sessionMessages = <ChatMessage>[
        _message(
          id: 'msg_user',
          sessionId: 'ses_1',
          text: 'Keep the manual model',
          createdAt: 1710000002100,
          role: 'user',
          providerId: 'anthropic',
          modelId: 'claude-sonnet-4.5',
        ),
      ];
      final chatService = _FakeChatService(
        bundle: ChatSessionBundle(
          sessions: <SessionSummary>[
            _session(
              id: 'ses_1',
              title: 'Initial session',
              createdAt: 1710000001000,
              updatedAt: 1710000005000,
            ),
          ],
          statuses: const <String, SessionStatusSummary>{
            'ses_1': SessionStatusSummary(type: 'idle'),
          },
          messages: sessionMessages,
          selectedSessionId: 'ses_1',
        ),
        fetchMessagesHandler:
            ({
              required ServerProfile profile,
              required ProjectTarget project,
              required String sessionId,
            }) async => sessionMessages,
      );
      final controller = _buildController(
        profile: profile,
        project: project,
        eventStreamService: eventStreamService,
        chatService: chatService,
        sessionActionService: sessionActionService,
        configService: _FakeConfigService(snapshot: configSnapshot),
      );
      addTearDown(controller.dispose);

      await controller.load();
      expect(controller.selectedModel?.key, 'anthropic/claude-sonnet-4.5');
      controller.selectModel('openai/gpt-4.1');
      await Future<void>.delayed(Duration.zero);
      expect(controller.selectedModel?.key, 'openai/gpt-4.1');
      await controller.summarizeSelectedSession();

      expect(sessionActionService.summarizeCalls, 1);
      expect(sessionActionService.lastSummarizedSessionId, 'ses_1');
      expect(sessionActionService.lastSummarizedProviderId, 'openai');
      expect(sessionActionService.lastSummarizedModelId, 'gpt-4.1');
    },
  );

  test(
    'controller re-resolves compact models from the active session transcript after switching away and back',
    () async {
      final eventStreamService = _ControlledEventStreamService();
      final sessionActionService = _RecordingSessionActionService();
      final sessions = <SessionSummary>[
        _session(
          id: 'ses_1',
          title: 'First session',
          createdAt: 1710000001000,
          updatedAt: 1710000005000,
        ),
        _session(
          id: 'ses_2',
          title: 'Second session',
          createdAt: 1710000002000,
          updatedAt: 1710000006000,
        ),
      ];
      final messagesBySessionId = <String, List<ChatMessage>>{
        'ses_1': <ChatMessage>[
          _message(
            id: 'msg_user_1',
            sessionId: 'ses_1',
            text: 'Keep using OpenAI',
            createdAt: 1710000002100,
            role: 'user',
            providerId: 'openai',
            modelId: 'gpt-4.1',
          ),
        ],
        'ses_2': <ChatMessage>[
          _message(
            id: 'msg_user_2',
            sessionId: 'ses_2',
            text: 'Switch to Anthropic here',
            createdAt: 1710000002200,
            role: 'user',
            providerId: 'anthropic',
            modelId: 'claude-sonnet-4.5',
          ),
        ],
      };
      final chatService = _FakeChatService(
        bundle: ChatSessionBundle(
          sessions: sessions,
          statuses: const <String, SessionStatusSummary>{
            'ses_1': SessionStatusSummary(type: 'idle'),
            'ses_2': SessionStatusSummary(type: 'idle'),
          },
          messages: messagesBySessionId['ses_1']!,
          selectedSessionId: 'ses_1',
        ),
        fetchMessagesHandler:
            ({
              required ServerProfile profile,
              required ProjectTarget project,
              required String sessionId,
            }) async => messagesBySessionId[sessionId] ?? const <ChatMessage>[],
      );
      final controller = _buildController(
        profile: profile,
        project: project,
        eventStreamService: eventStreamService,
        chatService: chatService,
        sessionActionService: sessionActionService,
        configService: _FakeConfigService(
          snapshot: _multiProviderComposerConfigSnapshot(),
        ),
      );
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.selectedSessionId, 'ses_1');
      expect(controller.selectedModel?.key, 'openai/gpt-4.1');

      await controller.selectSession('ses_2');
      await controller.summarizeSelectedSession();

      expect(sessionActionService.lastSummarizedSessionId, 'ses_2');
      expect(sessionActionService.lastSummarizedProviderId, 'anthropic');
      expect(sessionActionService.lastSummarizedModelId, 'claude-sonnet-4.5');

      await controller.selectSession('ses_1');
      await controller.summarizeSelectedSession();

      expect(sessionActionService.lastSummarizedSessionId, 'ses_1');
      expect(sessionActionService.lastSummarizedProviderId, 'openai');
      expect(sessionActionService.lastSummarizedModelId, 'gpt-4.1');
    },
  );

  test(
    'controller routes exact /compact prompts through session compaction',
    () async {
      final eventStreamService = _ControlledEventStreamService();
      final sessionActionService = _RecordingSessionActionService();
      var sendMessageCalls = 0;
      final sessionMessages = <ChatMessage>[
        _message(
          id: 'msg_user',
          sessionId: 'ses_1',
          text: 'Compress the transcript',
          createdAt: 1710000002000,
          role: 'user',
          providerId: 'anthropic',
          modelId: 'claude-sonnet-4.5',
        ),
      ];
      final chatService = _FakeChatService(
        bundle: ChatSessionBundle(
          sessions: <SessionSummary>[
            _session(
              id: 'ses_1',
              title: 'Initial session',
              createdAt: 1710000001000,
              updatedAt: 1710000005000,
            ),
          ],
          statuses: const <String, SessionStatusSummary>{
            'ses_1': SessionStatusSummary(type: 'idle'),
          },
          messages: sessionMessages,
          selectedSessionId: 'ses_1',
        ),
        fetchMessagesHandler:
            ({
              required ServerProfile profile,
              required ProjectTarget project,
              required String sessionId,
            }) async => sessionMessages,
        sendMessageHandler:
            ({
              required ServerProfile profile,
              required ProjectTarget project,
              required String sessionId,
              required String prompt,
              List<PromptAttachment> attachments = const <PromptAttachment>[],
              String? agent,
              String? providerId,
              String? modelId,
              String? variant,
              String? reasoning,
            }) async {
              sendMessageCalls += 1;
              return ChatMessage(
                info: ChatMessageInfo(
                  id: 'msg_stub',
                  role: 'assistant',
                  sessionId: sessionId,
                ),
                parts: const <ChatPart>[],
              );
            },
      );
      final controller = _buildController(
        profile: profile,
        project: project,
        eventStreamService: eventStreamService,
        chatService: chatService,
        sessionActionService: sessionActionService,
        configService: _FakeConfigService(),
      );
      addTearDown(controller.dispose);

      await controller.load();
      expect(controller.selectedModel, isNull);
      await controller.submitPrompt('/compact');

      expect(sessionActionService.summarizeCalls, 1);
      expect(sessionActionService.lastSummarizedSessionId, 'ses_1');
      expect(sessionActionService.lastSummarizedProviderId, 'anthropic');
      expect(sessionActionService.lastSummarizedModelId, 'claude-sonnet-4.5');
      expect(sendMessageCalls, 0);
      expect(controller.actionNotice, 'Session compaction requested.');
    },
  );

  test(
    'controller falls back to the configured model when the transcript has no model metadata',
    () async {
      final eventStreamService = _ControlledEventStreamService();
      final sessionActionService = _RecordingSessionActionService();
      final sessionMessages = <ChatMessage>[
        _message(
          id: 'msg_user',
          sessionId: 'ses_1',
          text: 'Ship the fix',
          createdAt: 1710000002000,
          role: 'user',
        ),
      ];
      final controller = _buildController(
        profile: profile,
        project: project,
        eventStreamService: eventStreamService,
        chatService: _FakeChatService(
          bundle: ChatSessionBundle(
            sessions: <SessionSummary>[
              _session(
                id: 'ses_1',
                title: 'Initial session',
                createdAt: 1710000001000,
                updatedAt: 1710000005000,
              ),
            ],
            statuses: const <String, SessionStatusSummary>{
              'ses_1': SessionStatusSummary(type: 'idle'),
            },
            messages: sessionMessages,
            selectedSessionId: 'ses_1',
          ),
          fetchMessagesHandler:
              ({
                required ServerProfile profile,
                required ProjectTarget project,
                required String sessionId,
              }) async => sessionMessages,
        ),
        sessionActionService: sessionActionService,
        configService: _FakeConfigService(snapshot: _composerConfigSnapshot()),
      );
      addTearDown(controller.dispose);

      await controller.load();
      await controller.summarizeSelectedSession();

      expect(sessionActionService.lastSummarizedProviderId, 'openai');
      expect(sessionActionService.lastSummarizedModelId, 'gpt-4.1');
    },
  );

  test(
    'controller falls back to the provider default when the configured model is invalid',
    () async {
      final eventStreamService = _ControlledEventStreamService();
      final sessionActionService = _RecordingSessionActionService();
      final controller = _buildController(
        profile: profile,
        project: project,
        eventStreamService: eventStreamService,
        sessionActionService: sessionActionService,
        configService: _FakeConfigService(
          snapshot: _composerConfigSnapshot(configuredModel: 'missing/model'),
        ),
      );
      addTearDown(controller.dispose);

      await controller.load();
      await controller.summarizeSelectedSession();

      expect(controller.selectedModel?.key, 'openai/gpt-4.1');
      expect(sessionActionService.lastSummarizedProviderId, 'openai');
      expect(sessionActionService.lastSummarizedModelId, 'gpt-4.1');
    },
  );

  test(
    'controller refuses exact /compact prompts without an existing session',
    () async {
      final eventStreamService = _ControlledEventStreamService();
      final sessionActionService = _RecordingSessionActionService();
      final chatService = _FakeChatService(
        bundle: const ChatSessionBundle(
          sessions: <SessionSummary>[],
          statuses: <String, SessionStatusSummary>{},
          messages: <ChatMessage>[],
          selectedSessionId: null,
        ),
      );
      final controller = _buildController(
        profile: profile,
        project: project,
        eventStreamService: eventStreamService,
        chatService: chatService,
        sessionActionService: sessionActionService,
      );
      addTearDown(controller.dispose);

      await controller.load();

      await expectLater(
        () => controller.submitPrompt('/compact'),
        throwsA(
          isA<SessionActionException>().having(
            (error) => error.message,
            'message',
            'Select a session before compacting.',
          ),
        ),
      );
      expect(chatService.createSessionCalls, 0);
      expect(sessionActionService.summarizeCalls, 0);
    },
  );

  test(
    'controller queues busy follow-ups and auto flushes them once idle',
    () async {
      final eventStreamService = _ControlledEventStreamService();
      final asyncPrompts = <String>[];
      final chatService = _FakeChatService(
        bundle: ChatSessionBundle(
          sessions: <SessionSummary>[
            _session(
              id: 'ses_1',
              title: 'Initial session',
              createdAt: 1710000001000,
              updatedAt: 1710000005000,
            ),
          ],
          statuses: const <String, SessionStatusSummary>{
            'ses_1': SessionStatusSummary(type: 'idle'),
          },
          messages: const <ChatMessage>[],
          selectedSessionId: 'ses_1',
        ),
        sendMessageAsyncHandler:
            ({
              required ServerProfile profile,
              required ProjectTarget project,
              required String sessionId,
              required String prompt,
              List<PromptAttachment> attachments = const <PromptAttachment>[],
              String? messageId,
              String? agent,
              String? providerId,
              String? modelId,
              String? variant,
              String? reasoning,
            }) async {
              asyncPrompts.add(prompt);
              return true;
            },
      );
      final controller = _buildController(
        profile: profile,
        project: project,
        eventStreamService: eventStreamService,
        chatService: chatService,
      );
      addTearDown(controller.dispose);

      await controller.load();

      eventStreamService.emitToScope(
        profile,
        project,
        const EventEnvelope(
          type: 'session.status',
          properties: <String, Object?>{
            'sessionID': 'ses_1',
            'status': <String, Object?>{'type': 'busy'},
          },
        ),
      );

      await controller.submitPrompt(
        'Queue this follow-up',
        mode: WorkspacePromptDispatchMode.queue,
      );

      expect(
        controller.selectedSessionQueuedPrompts.map((item) => item.prompt),
        <String>['Queue this follow-up'],
      );
      expect(asyncPrompts, isEmpty);

      eventStreamService.emitToScope(
        profile,
        project,
        const EventEnvelope(
          type: 'session.status',
          properties: <String, Object?>{
            'sessionID': 'ses_1',
            'status': <String, Object?>{'type': 'idle'},
          },
        ),
      );
      await _waitFor(
        () =>
            asyncPrompts.length == 1 &&
            controller.selectedSessionQueuedPrompts.isEmpty,
      );

      expect(asyncPrompts, <String>['Queue this follow-up']);
      expect(controller.selectedSessionQueuedPrompts, isEmpty);
      expect(controller.selectedSessionId, 'ses_1');
    },
  );

  test('controller restores queued follow-ups from cache on load', () async {
    final cacheStore = StaleCacheStore();
    final firstEventStreamService = _ControlledEventStreamService();
    final firstController = _buildController(
      profile: profile,
      project: project,
      eventStreamService: firstEventStreamService,
      cacheStore: cacheStore,
    );
    addTearDown(firstController.dispose);

    await firstController.load();

    firstEventStreamService.emitToScope(
      profile,
      project,
      const EventEnvelope(
        type: 'session.status',
        properties: <String, Object?>{
          'sessionID': 'ses_1',
          'status': <String, Object?>{'type': 'busy'},
        },
      ),
    );

    await firstController.submitPrompt(
      'Persist this follow-up',
      mode: WorkspacePromptDispatchMode.queue,
    );
    await Future<void>.delayed(Duration.zero);

    final restoredEventStreamService = _ControlledEventStreamService();
    final restoredController = _buildController(
      profile: profile,
      project: project,
      eventStreamService: restoredEventStreamService,
      cacheStore: cacheStore,
    );
    addTearDown(restoredController.dispose);

    await restoredController.load();

    expect(
      restoredController.selectedSessionQueuedPrompts.map(
        (item) => item.prompt,
      ),
      <String>['Persist this follow-up'],
    );
  });

  test(
    'controller surfaces child session questions for the selected root session',
    () async {
      final eventStreamService = _ControlledEventStreamService();
      final controller = _buildController(
        profile: profile,
        project: project,
        eventStreamService: eventStreamService,
        initialSelectedSessionId: 'ses_root',
        initialSessions: <SessionSummary>[
          _session(
            id: 'ses_root',
            title: 'Root session',
            createdAt: 1710000001000,
            updatedAt: 1710000005000,
          ),
          _session(
            id: 'ses_child',
            title: 'Child session',
            createdAt: 1710000002000,
            updatedAt: 1710000006000,
            parentId: 'ses_root',
          ),
        ],
        pendingBundle: PendingRequestBundle(
          questions: <QuestionRequestSummary>[
            QuestionRequestSummary(
              id: 'req_1',
              sessionId: 'ses_child',
              questions: const <QuestionPromptSummary>[
                QuestionPromptSummary(
                  question: 'Which environment should I target?',
                  header: 'Environment',
                  multiple: false,
                  options: <QuestionOptionSummary>[
                    QuestionOptionSummary(
                      label: 'Cron/Container',
                      description: 'Simple once-per-day deployment.',
                    ),
                  ],
                ),
              ],
            ),
          ],
          permissions: const <PermissionRequestSummary>[],
        ),
      );
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.selectedSessionId, 'ses_root');
      expect(controller.currentQuestionRequest?.id, 'req_1');
      expect(controller.currentQuestionRequest?.sessionId, 'ses_child');

      eventStreamService.emitToScope(
        profile,
        project,
        const EventEnvelope(
          type: 'question.replied',
          properties: <String, Object?>{
            'sessionID': 'ses_child',
            'requestID': 'req_1',
          },
        ),
      );

      expect(controller.currentQuestionRequest, isNull);

      eventStreamService.emitToScope(
        profile,
        project,
        const EventEnvelope(
          type: 'question.asked',
          properties: <String, Object?>{
            'id': 'req_2',
            'sessionID': 'ses_child',
            'questions': <Object?>[
              <String, Object?>{
                'question': 'Which execution path should I use?',
                'header': 'Execution',
                'multiple': false,
                'options': <Object?>[
                  <String, Object?>{
                    'label': 'GitHub Actions',
                    'description': 'Use the CI runner.',
                  },
                ],
              },
            ],
          },
        ),
      );

      expect(controller.currentQuestionRequest?.id, 'req_2');
    },
  );

  test(
    'controller ignores malformed question live events and still applies later valid ones',
    () async {
      final eventStreamService = _ControlledEventStreamService();
      final controller = _buildController(
        profile: profile,
        project: project,
        eventStreamService: eventStreamService,
        initialSelectedSessionId: 'ses_root',
        initialSessions: <SessionSummary>[
          _session(
            id: 'ses_root',
            title: 'Root session',
            createdAt: 1710000001000,
            updatedAt: 1710000005000,
          ),
          _session(
            id: 'ses_child',
            title: 'Child session',
            createdAt: 1710000002000,
            updatedAt: 1710000006000,
            parentId: 'ses_root',
          ),
        ],
      );
      addTearDown(controller.dispose);

      await controller.load();

      eventStreamService.emitToScope(
        profile,
        project,
        const EventEnvelope(
          type: 'question.asked',
          properties: <String, Object?>{
            'id': 'req_bad',
            'sessionID': 'ses_child',
            'questions': 'invalid',
          },
        ),
      );

      expect(controller.currentQuestionRequest, isNull);

      eventStreamService.emitToScope(
        profile,
        project,
        const EventEnvelope(
          type: 'question.asked',
          properties: <String, Object?>{
            'id': 'req_good',
            'sessionID': 'ses_child',
            'questions': <Object?>[
              <String, Object?>{
                'question': 'Can the controller recover?',
                'header': 'Recovery',
                'multiple': false,
                'options': <Object?>[
                  <String, Object?>{'label': 'Yes', 'description': 'Continue'},
                ],
              },
            ],
          },
        ),
      );

      expect(controller.currentQuestionRequest?.id, 'req_good');
    },
  );

  test(
    'controller auto-accepts child session permissions and persists the preference',
    () async {
      final eventStreamService = _ControlledEventStreamService();
      final requestService = _FakeRequestService(
        pendingBundle: PendingRequestBundle(
          questions: const <QuestionRequestSummary>[],
          permissions: <PermissionRequestSummary>[
            const PermissionRequestSummary(
              id: 'per_1',
              sessionId: 'ses_child',
              permission: 'bash',
              patterns: <String>['npm test'],
            ),
          ],
        ),
      );
      final controller = _buildController(
        profile: profile,
        project: project,
        eventStreamService: eventStreamService,
        requestService: requestService,
        initialSelectedSessionId: 'ses_root',
        initialSessions: <SessionSummary>[
          _session(
            id: 'ses_root',
            title: 'Root session',
            createdAt: 1710000001000,
            updatedAt: 1710000005000,
          ),
          _session(
            id: 'ses_child',
            title: 'Child session',
            createdAt: 1710000002000,
            updatedAt: 1710000006000,
            parentId: 'ses_root',
          ),
        ],
      );
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.currentPermissionRequest?.id, 'per_1');
      expect(controller.currentPermissionRequest?.sessionId, 'ses_child');

      final enabled = await controller.togglePermissionAutoAcceptForSession(
        'ses_root',
      );
      await Future<void>.delayed(Duration.zero);

      expect(enabled, isTrue);
      expect(requestService.permissionReplies, hasLength(1));
      expect(requestService.permissionReplies.single.requestId, 'per_1');
      expect(requestService.permissionReplies.single.reply, 'once');
      expect(controller.currentPermissionRequest, isNull);

      final restoredEventStreamService = _ControlledEventStreamService();
      final restoredRequestService = _FakeRequestService();
      final restoredController = _buildController(
        profile: profile,
        project: project,
        eventStreamService: restoredEventStreamService,
        requestService: restoredRequestService,
        initialSelectedSessionId: 'ses_root',
        initialSessions: <SessionSummary>[
          _session(
            id: 'ses_root',
            title: 'Root session',
            createdAt: 1710000001000,
            updatedAt: 1710000005000,
          ),
          _session(
            id: 'ses_child',
            title: 'Child session',
            createdAt: 1710000002000,
            updatedAt: 1710000006000,
            parentId: 'ses_root',
          ),
        ],
      );
      addTearDown(restoredController.dispose);

      await restoredController.load();

      expect(
        restoredController.autoAcceptsPermissionForSession('ses_child'),
        isTrue,
      );

      restoredEventStreamService.emitToScope(
        profile,
        project,
        const EventEnvelope(
          type: 'permission.asked',
          properties: <String, Object?>{
            'id': 'per_2',
            'sessionID': 'ses_child',
            'permission': 'edit',
            'patterns': <Object?>['lib/**'],
          },
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(restoredRequestService.permissionReplies, hasLength(1));
      expect(
        restoredRequestService.permissionReplies.single.requestId,
        'per_2',
      );
      expect(restoredRequestService.permissionReplies.single.reply, 'once');
      expect(restoredController.currentPermissionRequest, isNull);
    },
  );

  test(
    'controller ignores malformed permission live events and still applies later valid ones',
    () async {
      final eventStreamService = _ControlledEventStreamService();
      final controller = _buildController(
        profile: profile,
        project: project,
        eventStreamService: eventStreamService,
        initialSelectedSessionId: 'ses_root',
        initialSessions: <SessionSummary>[
          _session(
            id: 'ses_root',
            title: 'Root session',
            createdAt: 1710000001000,
            updatedAt: 1710000005000,
          ),
          _session(
            id: 'ses_child',
            title: 'Child session',
            createdAt: 1710000002000,
            updatedAt: 1710000006000,
            parentId: 'ses_root',
          ),
        ],
      );
      addTearDown(controller.dispose);

      await controller.load();

      eventStreamService.emitToScope(
        profile,
        project,
        const EventEnvelope(
          type: 'permission.asked',
          properties: <String, Object?>{
            'id': 'per_bad',
            'sessionID': 'ses_child',
            'permission': 'edit',
            'patterns': 'invalid',
          },
        ),
      );

      expect(controller.currentPermissionRequest, isNull);

      eventStreamService.emitToScope(
        profile,
        project,
        const EventEnvelope(
          type: 'permission.asked',
          properties: <String, Object?>{
            'id': 'per_good',
            'sessionID': 'ses_child',
            'permission': 'edit',
            'patterns': <Object?>['lib/**'],
          },
        ),
      );

      expect(controller.currentPermissionRequest?.id, 'per_good');
    },
  );

  test(
    'controller applies todo updates in real time for the active session',
    () async {
      final eventStreamService = _ControlledEventStreamService();
      final controller = _buildController(
        profile: profile,
        project: project,
        eventStreamService: eventStreamService,
      );
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.todos, isEmpty);

      eventStreamService.emitToScope(
        profile,
        project,
        const EventEnvelope(
          type: 'todo.updated',
          properties: <String, Object?>{
            'sessionID': 'ses_1',
            'todos': <Object?>[
              <String, Object?>{
                'id': 'todo_1',
                'content': 'Write architecture plan skeleton',
                'status': 'in_progress',
                'priority': 'high',
              },
              <String, Object?>{
                'id': 'todo_2',
                'content': 'Append acceptance criteria',
                'status': 'pending',
                'priority': 'medium',
              },
            ],
          },
        ),
      );

      expect(controller.todos, hasLength(2));
      expect(
        controller.todos.first.content,
        'Write architecture plan skeleton',
      );
      expect(controller.todos.first.status, 'in_progress');
    },
  );

  test(
    'controller surfaces a session load error without failing the whole workspace',
    () async {
      final eventStreamService = _ControlledEventStreamService();
      final chatService = _FakeChatService(
        bundle: ChatSessionBundle(
          sessions: <SessionSummary>[
            _session(
              id: 'ses_1',
              title: 'Initial session',
              createdAt: 1710000001000,
              updatedAt: 1710000005000,
            ),
          ],
          statuses: const <String, SessionStatusSummary>{
            'ses_1': SessionStatusSummary(type: 'idle'),
          },
          messages: const <ChatMessage>[],
          selectedSessionId: 'ses_1',
        ),
        fetchMessagesHandler:
            ({required profile, required project, required sessionId}) async {
              throw Exception('connection timed out');
            },
      );
      final controller = _buildController(
        profile: profile,
        project: project,
        eventStreamService: eventStreamService,
        chatService: chatService,
      );
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.error, isNull);
      expect(controller.selectedSessionId, 'ses_1');
      expect(controller.sessionLoading, isFalse);
      expect(controller.sessionLoadError, contains('responding too slowly'));
      expect(controller.messages, isEmpty);
    },
  );

  test(
    'controller shows cached messages first when the server is slow or unavailable',
    () async {
      final eventStreamService = _ControlledEventStreamService();
      final cachedMessages = <ChatMessage>[
        ChatMessage(
          info: const ChatMessageInfo(
            id: 'msg_cached',
            role: 'assistant',
            sessionId: 'ses_1',
          ),
          parts: const <ChatPart>[
            ChatPart(id: 'part_cached', type: 'text', text: 'Cached snapshot'),
          ],
        ),
      ];
      final cacheStore = StaleCacheStore();
      await cacheStore.save(
        'workspace.messages::${profile.storageKey}::${project.directory}::ses_1',
        cachedMessages
            .map((message) => message.toJson())
            .toList(growable: false),
      );

      final chatService = _FakeChatService(
        bundle: ChatSessionBundle(
          sessions: <SessionSummary>[
            _session(
              id: 'ses_1',
              title: 'Initial session',
              createdAt: 1710000001000,
              updatedAt: 1710000005000,
            ),
          ],
          statuses: const <String, SessionStatusSummary>{
            'ses_1': SessionStatusSummary(type: 'idle'),
          },
          messages: const <ChatMessage>[],
          selectedSessionId: 'ses_1',
        ),
        fetchMessagesHandler:
            ({required profile, required project, required sessionId}) async {
              throw Exception('connection timed out');
            },
      );
      final controller = _buildController(
        profile: profile,
        project: project,
        eventStreamService: eventStreamService,
        chatService: chatService,
        cacheStore: cacheStore,
      );
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.messages, hasLength(1));
      expect(controller.messages.single.parts.single.text, 'Cached snapshot');
      expect(controller.showingCachedSessionMessages, isTrue);
      expect(controller.sessionLoadError, contains('responding too slowly'));
    },
  );

  test(
    'controller can retry loading the selected session after a failure',
    () async {
      final eventStreamService = _ControlledEventStreamService();
      var attempts = 0;
      final chatService = _FakeChatService(
        bundle: ChatSessionBundle(
          sessions: <SessionSummary>[
            _session(
              id: 'ses_1',
              title: 'Initial session',
              createdAt: 1710000001000,
              updatedAt: 1710000005000,
            ),
          ],
          statuses: const <String, SessionStatusSummary>{
            'ses_1': SessionStatusSummary(type: 'idle'),
          },
          messages: const <ChatMessage>[],
          selectedSessionId: 'ses_1',
        ),
        fetchMessagesHandler:
            ({required profile, required project, required sessionId}) async {
              attempts += 1;
              if (attempts == 1) {
                throw Exception('server offline');
              }
              return <ChatMessage>[
                ChatMessage(
                  info: const ChatMessageInfo(
                    id: 'msg_1',
                    role: 'assistant',
                    sessionId: 'ses_1',
                  ),
                  parts: const <ChatPart>[
                    ChatPart(
                      id: 'part_1',
                      type: 'text',
                      text: 'Recovered message',
                    ),
                  ],
                ),
              ];
            },
      );
      final controller = _buildController(
        profile: profile,
        project: project,
        eventStreamService: eventStreamService,
        chatService: chatService,
      );
      addTearDown(controller.dispose);

      await controller.load();
      expect(controller.sessionLoadError, isNotNull);
      expect(controller.messages, isEmpty);

      await controller.retrySelectedSessionMessages();

      expect(controller.sessionLoadError, isNull);
      expect(controller.sessionLoading, isFalse);
      expect(controller.messages, hasLength(1));
      expect(controller.messages.single.parts.single.text, 'Recovered message');
    },
  );

  test(
    'controller keeps an optimistic user message visible until the server catches up',
    () async {
      final eventStreamService = _ControlledEventStreamService();
      var fetchMessagesCount = 0;
      final chatService = _FakeChatService(
        bundle: ChatSessionBundle(
          sessions: <SessionSummary>[
            _session(
              id: 'ses_1',
              title: 'Initial session',
              createdAt: 1710000001000,
              updatedAt: 1710000005000,
            ),
          ],
          statuses: const <String, SessionStatusSummary>{
            'ses_1': SessionStatusSummary(type: 'idle'),
          },
          messages: const <ChatMessage>[],
          selectedSessionId: 'ses_1',
        ),
        fetchMessagesHandler:
            ({required profile, required project, required sessionId}) async {
              fetchMessagesCount += 1;
              if (fetchMessagesCount >= 3) {
                return <ChatMessage>[
                  ChatMessage(
                    info: ChatMessageInfo(
                      id: 'msg_server_user',
                      role: 'user',
                      sessionId: sessionId,
                      createdAt: DateTime.fromMillisecondsSinceEpoch(
                        1710000009000,
                      ),
                      completedAt: DateTime.fromMillisecondsSinceEpoch(
                        1710000009000,
                      ),
                    ),
                    parts: const <ChatPart>[
                      ChatPart(
                        id: 'part_server_user',
                        type: 'text',
                        text: 'Ship the fix',
                        messageId: 'msg_server_user',
                        sessionId: 'ses_1',
                      ),
                    ],
                  ),
                ];
              }
              return const <ChatMessage>[];
            },
        sendMessageHandler:
            ({
              required profile,
              required project,
              required sessionId,
              required prompt,
              attachments = const <PromptAttachment>[],
              agent,
              providerId,
              modelId,
              variant,
              reasoning,
            }) async => ChatMessage(
              info: ChatMessageInfo(
                id: 'msg_send_ack',
                role: 'assistant',
                sessionId: sessionId,
              ),
              parts: const <ChatPart>[],
            ),
      );
      final controller = _buildController(
        profile: profile,
        project: project,
        eventStreamService: eventStreamService,
        chatService: chatService,
      );
      addTearDown(controller.dispose);

      await controller.load();
      expect(controller.messages, isEmpty);

      await controller.submitPrompt('Ship the fix');
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(controller.messages, hasLength(1));
      expect(controller.messages.single.info.role, 'user');
      expect(controller.messages.single.parts.single.text, 'Ship the fix');

      await controller.retrySelectedSessionMessages();

      expect(controller.messages, hasLength(1));
      expect(controller.messages.single.info.id, 'msg_server_user');
      expect(controller.messages.single.parts.single.text, 'Ship the fix');
    },
  );

  test(
    'controller coalesces streaming cache writes until updates settle',
    () async {
      final eventStreamService = _ControlledEventStreamService();
      final cacheStore = _RecordingCacheStore();
      final controller = _buildController(
        profile: profile,
        project: project,
        eventStreamService: eventStreamService,
        cacheStore: cacheStore,
      );
      addTearDown(controller.dispose);

      await controller.load();
      cacheStore.saveCalls = 0;
      cacheStore.entries.clear();

      void emitStreamingUpdate(String content) {
        eventStreamService.emitToScope(
          profile,
          project,
          EventEnvelope(
            type: 'message.part.updated',
            properties: <String, Object?>{
              'part': <String, Object?>{
                'id': 'part_stream',
                'messageID': 'msg_stream',
                'sessionID': 'ses_1',
                'type': 'text',
                'content': content,
              },
            },
          ),
        );
      }

      emitStreamingUpdate('hello');
      emitStreamingUpdate('hello brave');
      emitStreamingUpdate('hello brave new world');

      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(cacheStore.saveCalls, 0);

      await Future<void>.delayed(const Duration(milliseconds: 1100));
      expect(cacheStore.saveCalls, 1);

      final entry = cacheStore
          .entries['workspace.messages::${profile.storageKey}::${project.directory}::ses_1'];
      expect(entry, isNotNull);
      final savedMessages =
          ((jsonDecode(entry!.payloadJson) as List)
                  .cast<Map<String, Object?>>())
              .map(ChatMessage.fromJson)
              .toList(growable: false);
      expect(savedMessages, hasLength(1));
      expect(savedMessages.single.parts.single.text, 'hello brave new world');
    },
  );

  test(
    'controller applies message.part.delta updates to thinking text',
    () async {
      final eventStreamService = _ControlledEventStreamService();
      final cacheStore = _RecordingCacheStore();
      final controller = _buildController(
        profile: profile,
        project: project,
        eventStreamService: eventStreamService,
        cacheStore: cacheStore,
      );
      addTearDown(controller.dispose);

      await controller.load();

      eventStreamService.emitToScope(
        profile,
        project,
        const EventEnvelope(
          type: 'message.part.updated',
          properties: <String, Object?>{
            'part': <String, Object?>{
              'id': 'part_reasoning_stream',
              'messageID': 'msg_reasoning_stream',
              'sessionID': 'ses_1',
              'type': 'reasoning',
              'text': '',
            },
          },
        ),
      );

      void emitThinkingDelta(String delta) {
        eventStreamService.emitToScope(
          profile,
          project,
          EventEnvelope(
            type: 'message.part.delta',
            properties: <String, Object?>{
              'sessionID': 'ses_1',
              'messageID': 'msg_reasoning_stream',
              'partID': 'part_reasoning_stream',
              'field': 'text',
              'delta': delta,
            },
          ),
        );
      }

      emitThinkingDelta('Reviewing ');
      emitThinkingDelta('the timeline');

      await _waitFor(
        () =>
            controller.messages.length == 1 &&
            controller.messages.single.parts.single.text ==
                'Reviewing the timeline',
      );

      final cacheKey =
          'workspace.messages::${profile.storageKey}::${project.directory}::ses_1';
      await _waitFor(() {
        final entry = cacheStore.entries[cacheKey];
        if (entry == null) {
          return false;
        }
        final savedMessages =
            ((jsonDecode(entry.payloadJson) as List)
                    .cast<Map<String, Object?>>())
                .map(ChatMessage.fromJson)
                .toList(growable: false);
        return savedMessages.length == 1 &&
            savedMessages.single.parts.single.text == 'Reviewing the timeline';
      });
    },
  );

  test(
    'controller persists selected tool state title updates to session cache',
    () async {
      final eventStreamService = _ControlledEventStreamService();
      final cacheStore = _RecordingCacheStore();
      final controller = _buildController(
        profile: profile,
        project: project,
        eventStreamService: eventStreamService,
        cacheStore: cacheStore,
      );
      addTearDown(controller.dispose);

      await controller.load();

      final cacheKey =
          'workspace.messages::${profile.storageKey}::${project.directory}::ses_1';

      List<ChatMessage> savedMessagesForCache() {
        final entry = cacheStore.entries[cacheKey];
        if (entry == null) {
          return const <ChatMessage>[];
        }
        return ((jsonDecode(entry.payloadJson) as List)
                .cast<Map<String, Object?>>())
            .map(ChatMessage.fromJson)
            .toList(growable: false);
      }

      void emitToolUpdate(String title) {
        eventStreamService.emitToScope(
          profile,
          project,
          EventEnvelope(
            type: 'message.part.updated',
            properties: <String, Object?>{
              'part': <String, Object?>{
                'id': 'part_selected_tool',
                'messageID': 'msg_selected_tool',
                'sessionID': 'ses_1',
                'type': 'tool',
                'tool': 'bash',
                'state': <String, Object?>{'title': title},
              },
            },
          ),
        );
      }

      emitToolUpdate('Inspecting release notes');
      await _waitFor(() {
        final saved = savedMessagesForCache();
        if (saved.length != 1) {
          return false;
        }
        final state = (saved.single.parts.single.metadata['state'] as Map?)
            ?.cast<String, Object?>();
        return state?['title'] == 'Inspecting release notes';
      });

      final saveCallsAfterFirstWrite = cacheStore.saveCalls;
      emitToolUpdate('Comparing release notes');
      await _waitFor(() {
        final saved = savedMessagesForCache();
        if (saved.length != 1 ||
            cacheStore.saveCalls <= saveCallsAfterFirstWrite) {
          return false;
        }
        final state = (saved.single.parts.single.metadata['state'] as Map?)
            ?.cast<String, Object?>();
        return state?['title'] == 'Comparing release notes';
      });

      final saveCallsAfterTitleUpdate = cacheStore.saveCalls;
      eventStreamService.emitToScope(
        profile,
        project,
        const EventEnvelope(
          type: 'message.part.updated',
          properties: <String, Object?>{
            'part': <String, Object?>{
              'id': 'part_selected_tool',
              'messageID': 'msg_selected_tool',
              'sessionID': 'ses_1',
              'type': 'tool',
              'tool': 'bash',
              'state': <String, Object?>{
                'title': 'Comparing release notes',
                'input': <String, Object?>{'command': 'git status'},
              },
            },
          },
        ),
      );
      await _waitFor(() {
        final saved = savedMessagesForCache();
        if (saved.length != 1 ||
            cacheStore.saveCalls <= saveCallsAfterTitleUpdate) {
          return false;
        }
        final state = (saved.single.parts.single.metadata['state'] as Map?)
            ?.cast<String, Object?>();
        final input = (state?['input'] as Map?)?.cast<String, Object?>();
        return state?['title'] == 'Comparing release notes' &&
            input?['command'] == 'git status';
      });
    },
  );

  test(
    'controller keeps selected messages stable while child delta updates active child preview',
    () async {
      final eventStreamService = _ControlledEventStreamService();
      const childSessionId = 'ses_child_busy';
      final chatService = _FakeChatService(
        bundle: ChatSessionBundle(
          sessions: <SessionSummary>[
            _session(
              id: 'ses_root',
              title: 'Root session',
              createdAt: 1710000001000,
              updatedAt: 1710000005000,
            ),
            _session(
              id: childSessionId,
              title: 'Busy child',
              createdAt: 1710000002000,
              updatedAt: 1710000007000,
              parentId: 'ses_root',
            ),
          ],
          statuses: <String, SessionStatusSummary>{
            'ses_root': const SessionStatusSummary(type: 'idle'),
            childSessionId: const SessionStatusSummary(type: 'busy'),
          },
          messages: const <ChatMessage>[],
          selectedSessionId: 'ses_root',
        ),
      );
      final controller = _buildController(
        profile: profile,
        project: project,
        eventStreamService: eventStreamService,
        chatService: chatService,
      );
      addTearDown(controller.dispose);

      await controller.load();
      controller.updateWatchedSessionIds(<String>[childSessionId]);

      eventStreamService.emitToScope(
        profile,
        project,
        const EventEnvelope(
          type: 'message.part.updated',
          properties: <String, Object?>{
            'part': <String, Object?>{
              'id': 'part_root',
              'messageID': 'msg_root',
              'sessionID': 'ses_root',
              'type': 'text',
              'text': 'Root timeline stays put',
            },
          },
        ),
      );
      await _waitFor(
        () =>
            controller.messages.length == 1 &&
            controller.messages.single.parts.single.text ==
                'Root timeline stays put',
      );

      eventStreamService.emitToScope(
        profile,
        project,
        const EventEnvelope(
          type: 'message.part.updated',
          properties: <String, Object?>{
            'part': <String, Object?>{
              'id': 'part_child_reasoning',
              'messageID': 'msg_child_reasoning',
              'sessionID': childSessionId,
              'type': 'reasoning',
              'text': '',
            },
          },
        ),
      );

      eventStreamService.emitToScope(
        profile,
        project,
        const EventEnvelope(
          type: 'message.part.delta',
          properties: <String, Object?>{
            'sessionID': childSessionId,
            'messageID': 'msg_child_reasoning',
            'partID': 'part_child_reasoning',
            'field': 'text',
            'delta': 'Inspecting background child work',
          },
        ),
      );

      await _waitFor(
        () =>
            controller.activeChildSessionPreviewById[childSessionId] ==
            'Inspecting background child work',
      );
      final watchedTimeline = controller.timelineStateForSession(
        childSessionId,
      );
      expect(
        controller.activeChildSessionPreviewById[childSessionId],
        'Inspecting background child work',
      );
      expect(watchedTimeline.messages, hasLength(1));
      expect(
        watchedTimeline.messages.single.parts.single.text,
        'Inspecting background child work',
      );
      expect(controller.messages, hasLength(1));
      expect(
        controller.messages.single.parts.single.text,
        'Root timeline stays put',
      );
      expect(controller.selectedSessionId, 'ses_root');
    },
  );

  test(
    'controller keeps selected messages stable while child message updates watched timeline',
    () async {
      final eventStreamService = _ControlledEventStreamService();
      const childSessionId = 'ses_child_busy';
      final chatService = _FakeChatService(
        bundle: ChatSessionBundle(
          sessions: <SessionSummary>[
            _session(
              id: 'ses_root',
              title: 'Root session',
              createdAt: 1710000001000,
              updatedAt: 1710000005000,
            ),
            _session(
              id: childSessionId,
              title: 'Busy child',
              createdAt: 1710000002000,
              updatedAt: 1710000007000,
              parentId: 'ses_root',
            ),
          ],
          statuses: <String, SessionStatusSummary>{
            'ses_root': const SessionStatusSummary(type: 'idle'),
            childSessionId: const SessionStatusSummary(type: 'busy'),
          },
          messages: const <ChatMessage>[],
          selectedSessionId: 'ses_root',
        ),
      );
      final controller = _buildController(
        profile: profile,
        project: project,
        eventStreamService: eventStreamService,
        chatService: chatService,
      );
      addTearDown(controller.dispose);

      await controller.load();
      controller.updateWatchedSessionIds(<String>[childSessionId]);

      eventStreamService.emitToScope(
        profile,
        project,
        const EventEnvelope(
          type: 'message.part.updated',
          properties: <String, Object?>{
            'part': <String, Object?>{
              'id': 'part_root',
              'messageID': 'msg_root',
              'sessionID': 'ses_root',
              'type': 'text',
              'text': 'Root timeline stays put',
            },
          },
        ),
      );
      await _waitFor(
        () =>
            controller.messages.length == 1 &&
            controller.messages.single.parts.single.text ==
                'Root timeline stays put',
      );

      eventStreamService.emitToScope(
        profile,
        project,
        const EventEnvelope(
          type: 'message.updated',
          properties: <String, Object?>{
            'info': <String, Object?>{
              'id': 'msg_child',
              'role': 'assistant',
              'sessionID': childSessionId,
            },
          },
        ),
      );

      await _waitFor(
        () =>
            controller
                .timelineStateForSession(childSessionId)
                .messages
                .length ==
            1,
      );
      final watchedTimeline = controller.timelineStateForSession(
        childSessionId,
      );
      expect(watchedTimeline.messages, hasLength(1));
      expect(watchedTimeline.messages.single.info.id, 'msg_child');
      expect(controller.messages, hasLength(1));
      expect(
        controller.messages.single.parts.single.text,
        'Root timeline stays put',
      );
      expect(controller.selectedSessionId, 'ses_root');
    },
  );

  test(
    'controller keeps per-session composer selections across revisit and reconnect',
    () async {
      final sessions = <SessionSummary>[
        _session(
          id: 'ses_1',
          title: 'First session',
          createdAt: 1710000001000,
          updatedAt: 1710000005000,
        ),
        _session(
          id: 'ses_2',
          title: 'Second session',
          createdAt: 1710000002000,
          updatedAt: 1710000006000,
        ),
      ];
      final configService = _FakeConfigService(
        snapshot: _composerConfigSnapshot(),
      );
      final controller = _buildController(
        profile: profile,
        project: project,
        eventStreamService: _ControlledEventStreamService(),
        configService: configService,
        initialSessions: sessions,
      );
      addTearDown(controller.dispose);

      await controller.load();

      controller.selectModel('openai/gpt-5.4');
      controller.selectReasoning('high');

      await controller.selectSession('ses_2');
      controller.selectModel('openai/gpt-4.1');
      controller.selectReasoning('medium');

      await controller.selectSession('ses_1');
      expect(controller.selectedModelKey, 'openai/gpt-5.4');
      expect(controller.selectedReasoning, 'high');

      await controller.selectSession('ses_2');
      expect(controller.selectedModelKey, 'openai/gpt-4.1');
      expect(controller.selectedReasoning, 'medium');

      final restoredController = _buildController(
        profile: profile,
        project: project,
        eventStreamService: _ControlledEventStreamService(),
        configService: configService,
        initialSessions: sessions,
      );
      addTearDown(restoredController.dispose);

      await restoredController.load();

      expect(restoredController.selectedSessionId, 'ses_1');
      expect(restoredController.selectedModelKey, 'openai/gpt-5.4');
      expect(restoredController.selectedReasoning, 'high');

      await restoredController.selectSession('ses_2');
      expect(restoredController.selectedModelKey, 'openai/gpt-4.1');
      expect(restoredController.selectedReasoning, 'medium');
    },
  );

  test(
    'controller prefers newer user message metadata over stale persisted composer selections',
    () async {
      final firstController = _buildController(
        profile: profile,
        project: project,
        eventStreamService: _ControlledEventStreamService(),
        configService: _FakeConfigService(snapshot: _composerConfigSnapshot()),
        initialSessions: <SessionSummary>[
          _session(
            id: 'ses_1',
            title: 'Initial session',
            createdAt: 1710000001000,
            updatedAt: 1710000005000,
          ),
        ],
        chatService: _FakeChatService(
          bundle: ChatSessionBundle(
            sessions: <SessionSummary>[
              _session(
                id: 'ses_1',
                title: 'Initial session',
                createdAt: 1710000001000,
                updatedAt: 1710000005000,
              ),
            ],
            statuses: const <String, SessionStatusSummary>{
              'ses_1': SessionStatusSummary(type: 'idle'),
            },
            messages: const <ChatMessage>[],
            selectedSessionId: 'ses_1',
          ),
          fetchMessagesHandler:
              ({
                required ServerProfile profile,
                required ProjectTarget project,
                required String sessionId,
              }) async => <ChatMessage>[
                _message(
                  id: 'msg_old',
                  sessionId: sessionId,
                  text: 'old prompt',
                  role: 'user',
                  createdAt: 1710000004000,
                  providerId: 'openai',
                  modelId: 'gpt-4.1',
                  variant: 'medium',
                ),
              ],
        ),
      );
      addTearDown(firstController.dispose);

      await firstController.load();

      firstController.selectModel('openai/gpt-5.4');
      firstController.selectReasoning('high');

      final restoredController = _buildController(
        profile: profile,
        project: project,
        eventStreamService: _ControlledEventStreamService(),
        configService: _FakeConfigService(snapshot: _composerConfigSnapshot()),
        initialSessions: <SessionSummary>[
          _session(
            id: 'ses_1',
            title: 'Initial session',
            createdAt: 1710000001000,
            updatedAt: 1710000010000,
          ),
        ],
        chatService: _FakeChatService(
          bundle: ChatSessionBundle(
            sessions: <SessionSummary>[
              _session(
                id: 'ses_1',
                title: 'Initial session',
                createdAt: 1710000001000,
                updatedAt: 1710000010000,
              ),
            ],
            statuses: const <String, SessionStatusSummary>{
              'ses_1': SessionStatusSummary(type: 'idle'),
            },
            messages: const <ChatMessage>[],
            selectedSessionId: 'ses_1',
          ),
          fetchMessagesHandler:
              ({
                required ServerProfile profile,
                required ProjectTarget project,
                required String sessionId,
              }) async => <ChatMessage>[
                _message(
                  id: 'msg_new',
                  sessionId: sessionId,
                  text: 'new prompt',
                  role: 'user',
                  createdAt: 1710000009000,
                  providerId: 'openai',
                  modelId: 'gpt-4.1',
                  variant: 'medium',
                ),
              ],
        ),
      );
      addTearDown(restoredController.dispose);

      await restoredController.load();

      expect(restoredController.selectedModelKey, 'openai/gpt-4.1');
      expect(restoredController.selectedReasoning, 'medium');
    },
  );

  test('controller exposes cached previews for active child sessions', () async {
    final eventStreamService = _ControlledEventStreamService();
    final cacheStore = _RecordingCacheStore();
    final childSessionId = 'ses_child_busy';
    cacheStore
            .entries['workspace.messages::${profile.storageKey}::${project.directory}::$childSessionId'] =
        StaleCacheEntry(
          payloadJson: jsonEncode(<Object?>[
            ChatMessage(
              info: ChatMessageInfo(
                id: 'msg_child',
                role: 'assistant',
                sessionId: childSessionId,
              ),
              parts: <ChatPart>[
                ChatPart(
                  id: 'part_child',
                  type: 'text',
                  text: 'Preparing release checklist',
                  messageId: 'msg_child',
                  sessionId: childSessionId,
                ),
              ],
            ).toJson(),
          ]),
          signature: 'child-preview',
          fetchedAt: DateTime.fromMillisecondsSinceEpoch(1710000008000),
        );
    final chatService = _FakeChatService(
      bundle: ChatSessionBundle(
        sessions: <SessionSummary>[
          _session(
            id: 'ses_root',
            title: 'Root session',
            createdAt: 1710000001000,
            updatedAt: 1710000005000,
          ),
          _session(
            id: childSessionId,
            title: 'Busy child',
            createdAt: 1710000002000,
            updatedAt: 1710000007000,
            parentId: 'ses_root',
          ),
        ],
        statuses: <String, SessionStatusSummary>{
          'ses_root': const SessionStatusSummary(type: 'idle'),
          childSessionId: const SessionStatusSummary(type: 'busy'),
        },
        messages: const <ChatMessage>[],
        selectedSessionId: 'ses_root',
      ),
    );
    final controller = _buildController(
      profile: profile,
      project: project,
      eventStreamService: eventStreamService,
      chatService: chatService,
      cacheStore: cacheStore,
    );
    addTearDown(controller.dispose);

    await controller.load();
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(
      controller.activeChildSessionPreviewById[childSessionId],
      'Preparing release checklist',
    );
  });

  test('controller prefetches sidebar hover previews for sessions', () async {
    final eventStreamService = _ControlledEventStreamService();
    final fetchCounts = <String, int>{};
    final cacheStore = _RecordingCacheStore();
    cacheStore
            .entries['workspace.messages::${profile.storageKey}::${project.directory}::ses_2'] =
        StaleCacheEntry(
          payloadJson: jsonEncode(<Object?>[
            _message(
              id: 'msg_user_older',
              sessionId: 'ses_2',
              text: 'Audit sidebar hover parity',
              createdAt: 1710000003000,
              role: 'user',
            ).toJson(),
            _message(
              id: 'msg_assistant_older',
              sessionId: 'ses_2',
              text: 'Preparing the hover preview scaffold',
              createdAt: 1710000003500,
            ).toJson(),
            _message(
              id: 'msg_user_newer',
              sessionId: 'ses_2',
              text: 'Fix the flaky iOS snapshot test',
              createdAt: 1710000004000,
              role: 'user',
            ).toJson(),
            _message(
              id: 'msg_assistant_newer',
              sessionId: 'ses_2',
              text: 'Review diff is ready',
              createdAt: 1710000004500,
            ).toJson(),
          ]),
          signature: 'hover-preview',
          fetchedAt: DateTime.fromMillisecondsSinceEpoch(1710000008000),
        );
    final chatService = _FakeChatService(
      bundle: ChatSessionBundle(
        sessions: <SessionSummary>[
          _session(
            id: 'ses_2',
            title: 'Hover target',
            createdAt: 1710000002000,
            updatedAt: 1710000007000,
          ),
          _session(
            id: 'ses_1',
            title: 'Selected session',
            createdAt: 1710000001000,
            updatedAt: 1710000005000,
          ),
        ],
        statuses: const <String, SessionStatusSummary>{
          'ses_1': SessionStatusSummary(type: 'idle'),
          'ses_2': SessionStatusSummary(type: 'idle'),
        },
        messages: const <ChatMessage>[],
        selectedSessionId: 'ses_1',
      ),
      fetchMessagesHandler:
          ({
            required ServerProfile profile,
            required ProjectTarget project,
            required String sessionId,
          }) async {
            fetchCounts[sessionId] = (fetchCounts[sessionId] ?? 0) + 1;
            if (sessionId != 'ses_2') {
              return const <ChatMessage>[];
            }
            return <ChatMessage>[
              _message(
                id: 'msg_user_older',
                sessionId: sessionId,
                text: 'Audit sidebar hover parity',
                createdAt: 1710000003000,
                role: 'user',
              ),
              _message(
                id: 'msg_assistant_older',
                sessionId: sessionId,
                text: 'Preparing the hover preview scaffold',
                createdAt: 1710000003500,
              ),
              _message(
                id: 'msg_user_newer',
                sessionId: sessionId,
                text: 'Fix the flaky iOS snapshot test',
                createdAt: 1710000004000,
                role: 'user',
              ),
              _message(
                id: 'msg_assistant_newer',
                sessionId: sessionId,
                text: 'Review diff is ready',
                createdAt: 1710000004500,
              ),
            ];
          },
    );
    final controller = _buildController(
      profile: profile,
      project: project,
      eventStreamService: eventStreamService,
      chatService: chatService,
      cacheStore: cacheStore,
      initialSessions: <SessionSummary>[
        _session(
          id: 'ses_2',
          title: 'Hover target',
          createdAt: 1710000002000,
          updatedAt: 1710000007000,
        ),
        _session(
          id: 'ses_1',
          title: 'Selected session',
          createdAt: 1710000001000,
          updatedAt: 1710000005000,
        ),
      ],
      initialSelectedSessionId: 'ses_1',
    );
    addTearDown(controller.dispose);

    await controller.load();
    await controller.prefetchSessionHoverPreview('ses_2');

    final preview = controller.sessionHoverPreviewForSession('ses_2');
    expect(fetchCounts['ses_2'], isNull);
    expect(preview.loading, isFalse);
    expect(preview.summary, 'Review diff is ready');
    expect(preview.messages.map((item) => item.label), <String>[
      'Fix the flaky iOS snapshot test',
      'Audit sidebar hover parity',
    ]);

    await controller.prefetchSessionHoverPreview('ses_2');
    expect(fetchCounts['ses_2'], isNull);
  });

  test(
    'controller updates active child previews from live part events without selecting the child session',
    () async {
      final eventStreamService = _ControlledEventStreamService();
      const childSessionId = 'ses_child_busy';
      final chatService = _FakeChatService(
        bundle: ChatSessionBundle(
          sessions: <SessionSummary>[
            _session(
              id: 'ses_root',
              title: 'Root session',
              createdAt: 1710000001000,
              updatedAt: 1710000005000,
            ),
            _session(
              id: childSessionId,
              title: 'Busy child',
              createdAt: 1710000002000,
              updatedAt: 1710000007000,
              parentId: 'ses_root',
            ),
          ],
          statuses: <String, SessionStatusSummary>{
            'ses_root': const SessionStatusSummary(type: 'idle'),
            childSessionId: const SessionStatusSummary(type: 'busy'),
          },
          messages: const <ChatMessage>[],
          selectedSessionId: 'ses_root',
        ),
      );
      final controller = _buildController(
        profile: profile,
        project: project,
        eventStreamService: eventStreamService,
        chatService: chatService,
      );
      addTearDown(controller.dispose);

      await controller.load();
      controller.updateWatchedSessionIds(<String>[childSessionId]);

      eventStreamService.emitToScope(
        profile,
        project,
        const EventEnvelope(
          type: 'message.part.updated',
          properties: <String, Object?>{
            'part': <String, Object?>{
              'id': 'part_root',
              'messageID': 'msg_root',
              'sessionID': 'ses_root',
              'type': 'text',
              'text': 'Root timeline stays put',
            },
          },
        ),
      );
      await _waitFor(
        () =>
            controller.messages.length == 1 &&
            controller.messages.single.parts.single.text ==
                'Root timeline stays put',
      );

      expect(
        controller.activeChildSessionPreviewById[childSessionId],
        'Working on the latest step',
      );

      void emitPartUpdate(String title) {
        eventStreamService.emitToScope(
          profile,
          project,
          EventEnvelope(
            type: 'message.part.updated',
            properties: <String, Object?>{
              'part': <String, Object?>{
                'id': 'part_child_tool',
                'messageID': 'msg_child_tool',
                'sessionID': childSessionId,
                'type': 'tool',
                'tool': 'bash',
                'state': <String, Object?>{'title': title},
              },
            },
          ),
        );
      }

      emitPartUpdate('Inspecting release notes');
      expect(
        controller.activeChildSessionPreviewById[childSessionId],
        'Shell: Inspecting release notes',
      );

      emitPartUpdate('Comparing release notes');
      expect(
        controller.activeChildSessionPreviewById[childSessionId],
        'Shell: Comparing release notes',
      );
      final watchedTimeline = controller.timelineStateForSession(
        childSessionId,
      );
      expect(watchedTimeline.messages, hasLength(1));
      expect(
        ((watchedTimeline.messages.single.parts.single.metadata['state']
                as Map?)
            ?.cast<String, Object?>())?['title'],
        'Comparing release notes',
      );
      expect(controller.messages, hasLength(1));
      expect(
        controller.messages.single.parts.single.text,
        'Root timeline stays put',
      );
    },
  );

  test(
    'controller keeps active child preview on the newest watched message when older child parts update',
    () async {
      final eventStreamService = _ControlledEventStreamService();
      const childSessionId = 'ses_child_busy';
      final chatService = _FakeChatService(
        bundle: ChatSessionBundle(
          sessions: <SessionSummary>[
            _session(
              id: 'ses_root',
              title: 'Root session',
              createdAt: 1710000001000,
              updatedAt: 1710000005000,
            ),
            _session(
              id: childSessionId,
              title: 'Busy child',
              createdAt: 1710000002000,
              updatedAt: 1710000007000,
              parentId: 'ses_root',
            ),
          ],
          statuses: <String, SessionStatusSummary>{
            'ses_root': const SessionStatusSummary(type: 'idle'),
            childSessionId: const SessionStatusSummary(type: 'busy'),
          },
          messages: const <ChatMessage>[],
          selectedSessionId: 'ses_root',
        ),
      );
      final controller = _buildController(
        profile: profile,
        project: project,
        eventStreamService: eventStreamService,
        chatService: chatService,
      );
      addTearDown(controller.dispose);

      await controller.load();
      controller.updateWatchedSessionIds(<String>[childSessionId]);

      void emitChildPart({
        required String messageId,
        required String partId,
        required String text,
      }) {
        eventStreamService.emitToScope(
          profile,
          project,
          EventEnvelope(
            type: 'message.part.updated',
            properties: <String, Object?>{
              'part': <String, Object?>{
                'id': partId,
                'messageID': messageId,
                'sessionID': childSessionId,
                'type': 'text',
                'text': text,
              },
            },
          ),
        );
      }

      emitChildPart(
        messageId: 'msg_child_old',
        partId: 'part_child_old',
        text: 'Older child activity',
      );
      emitChildPart(
        messageId: 'msg_child_new',
        partId: 'part_child_new',
        text: 'Latest child activity',
      );

      await _waitFor(
        () =>
            controller
                    .timelineStateForSession(childSessionId)
                    .messages
                    .length ==
                2 &&
            controller.activeChildSessionPreviewById[childSessionId] ==
                'Latest child activity',
      );

      emitChildPart(
        messageId: 'msg_child_old',
        partId: 'part_child_old',
        text: 'Older child retry details',
      );

      await _waitFor(
        () =>
            controller.activeChildSessionPreviewById[childSessionId] ==
            'Latest child activity',
      );
      final watchedTimeline = controller.timelineStateForSession(
        childSessionId,
      );
      expect(watchedTimeline.messages, hasLength(2));
      expect(
        watchedTimeline.messages
            .firstWhere((message) => message.info.id == 'msg_child_old')
            .parts
            .single
            .text,
        'Older child retry details',
      );
      expect(
        controller.activeChildSessionPreviewById[childSessionId],
        'Latest child activity',
      );
    },
  );

  test(
    'controller recomputes active child preview after removing an older watched child message',
    () async {
      final eventStreamService = _ControlledEventStreamService();
      const childSessionId = 'ses_child_busy';
      final chatService = _FakeChatService(
        bundle: ChatSessionBundle(
          sessions: <SessionSummary>[
            _session(
              id: 'ses_root',
              title: 'Root session',
              createdAt: 1710000001000,
              updatedAt: 1710000005000,
            ),
            _session(
              id: childSessionId,
              title: 'Busy child',
              createdAt: 1710000002000,
              updatedAt: 1710000007000,
              parentId: 'ses_root',
            ),
          ],
          statuses: <String, SessionStatusSummary>{
            'ses_root': const SessionStatusSummary(type: 'idle'),
            childSessionId: const SessionStatusSummary(type: 'busy'),
          },
          messages: const <ChatMessage>[],
          selectedSessionId: 'ses_root',
        ),
      );
      final controller = _buildController(
        profile: profile,
        project: project,
        eventStreamService: eventStreamService,
        chatService: chatService,
      );
      addTearDown(controller.dispose);

      await controller.load();
      controller.updateWatchedSessionIds(<String>[childSessionId]);

      void emitChildPart({
        required String messageId,
        required String partId,
        required String text,
      }) {
        eventStreamService.emitToScope(
          profile,
          project,
          EventEnvelope(
            type: 'message.part.updated',
            properties: <String, Object?>{
              'part': <String, Object?>{
                'id': partId,
                'messageID': messageId,
                'sessionID': childSessionId,
                'type': 'text',
                'text': text,
              },
            },
          ),
        );
      }

      emitChildPart(
        messageId: 'msg_child_old',
        partId: 'part_child_old',
        text: 'Older child activity',
      );
      emitChildPart(
        messageId: 'msg_child_new',
        partId: 'part_child_new',
        text: 'Latest child activity',
      );

      await _waitFor(
        () =>
            controller
                    .timelineStateForSession(childSessionId)
                    .messages
                    .length ==
                2 &&
            controller.activeChildSessionPreviewById[childSessionId] ==
                'Latest child activity',
      );

      eventStreamService.emitToScope(
        profile,
        project,
        const EventEnvelope(
          type: 'message.removed',
          properties: <String, Object?>{
            'sessionID': childSessionId,
            'messageID': 'msg_child_old',
          },
        ),
      );

      await _waitFor(
        () =>
            controller
                    .timelineStateForSession(childSessionId)
                    .messages
                    .length ==
                1 &&
            controller.activeChildSessionPreviewById[childSessionId] ==
                'Latest child activity',
      );
      final watchedTimeline = controller.timelineStateForSession(
        childSessionId,
      );
      expect(watchedTimeline.messages, hasLength(1));
      expect(watchedTimeline.messages.single.info.id, 'msg_child_new');
      expect(
        controller.activeChildSessionPreviewById[childSessionId],
        'Latest child activity',
      );
    },
  );
}

WorkspaceController _buildController({
  required ServerProfile profile,
  required ProjectTarget project,
  required _ControlledEventStreamService eventStreamService,
  ChatService? chatService,
  ProjectStore? projectStore,
  ProjectCatalogService? projectCatalogService,
  ReviewDiffService? reviewDiffService,
  RequestService? requestService,
  SessionActionService? sessionActionService,
  ConfigService? configService,
  StaleCacheStore? cacheStore,
  StaleCacheStore? spillStore,
  List<SessionSummary>? initialSessions,
  String? initialSelectedSessionId,
  PendingRequestBundle pendingBundle = const PendingRequestBundle(
    questions: <QuestionRequestSummary>[],
    permissions: <PermissionRequestSummary>[],
  ),
}) {
  final sessions =
      initialSessions ??
      <SessionSummary>[
        _session(
          id: 'ses_1',
          title: 'Initial session',
          createdAt: 1710000001000,
          updatedAt: 1710000005000,
        ),
      ];
  return WorkspaceController(
    profile: profile,
    directory: project.directory,
    chatService:
        chatService ??
        _FakeChatService(
          bundle: ChatSessionBundle(
            sessions: sessions,
            statuses: const <String, SessionStatusSummary>{
              'ses_1': SessionStatusSummary(type: 'idle'),
            },
            messages: const <ChatMessage>[],
            selectedSessionId: initialSelectedSessionId ?? 'ses_1',
          ),
        ),
    projectCatalogService:
        projectCatalogService ?? _FakeProjectCatalogService(project),
    projectStore: projectStore ?? _MemoryProjectStore(),
    cacheStore: cacheStore,
    spillStore: spillStore,
    fileBrowserService: _FakeFileBrowserService(),
    reviewDiffService: reviewDiffService ?? _EmptyReviewDiffService(),
    todoService: _FakeTodoService(),
    requestService:
        requestService ?? _FakeRequestService(pendingBundle: pendingBundle),
    eventStreamService: eventStreamService,
    sessionActionService: sessionActionService,
    configService: configService ?? _FakeConfigService(),
    agentService: _FakeAgentService(),
  );
}

SessionSummary _session({
  required String id,
  required String title,
  required int createdAt,
  required int updatedAt,
  String? parentId,
}) {
  return SessionSummary(
    id: id,
    directory: '/workspace/demo',
    title: title,
    version: '1',
    createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAt),
    parentId: parentId,
  );
}

ChatMessage _message({
  required String id,
  required String sessionId,
  required String text,
  required int createdAt,
  String role = 'assistant',
  String? providerId,
  String? modelId,
  String? agent,
  String? variant,
}) {
  return ChatMessage(
    info: ChatMessageInfo(
      id: id,
      role: role,
      sessionId: sessionId,
      providerId: providerId,
      modelId: modelId,
      agent: agent,
      variant: variant,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt),
      completedAt: DateTime.fromMillisecondsSinceEpoch(createdAt),
    ),
    parts: <ChatPart>[
      ChatPart(
        id: 'part_$id',
        type: 'text',
        text: text,
        messageId: id,
        sessionId: sessionId,
      ),
    ],
  );
}

Future<void> _waitFor(bool Function() condition, {int maxTicks = 400}) async {
  for (var index = 0; index < maxTicks; index += 1) {
    if (condition()) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(condition(), isTrue, reason: 'Timed out waiting for condition.');
}

class _ControlledEventStreamService extends EventStreamService {
  final Map<String, List<void Function(EventEnvelope event)>>
  _onEventByScopeKey = <String, List<void Function(EventEnvelope event)>>{};
  final Map<String, List<void Function()>> _onDoneByScopeKey =
      <String, List<void Function()>>{};
  final Map<String, List<void Function(Object error, StackTrace stackTrace)>>
  _onErrorByScopeKey =
      <String, List<void Function(Object error, StackTrace stackTrace)>>{};
  int connectCallCount = 0;
  int disconnectCallCount = 0;

  @override
  Future<void> connect({
    required ServerProfile profile,
    required ProjectTarget project,
    required void Function(EventEnvelope event) onEvent,
    void Function()? onDone,
    void Function(Object error, StackTrace stackTrace)? onError,
  }) async {
    connectCallCount += 1;
    final scopeKey = _scopeKeyFor(profile, project);
    final listeners =
        _onEventByScopeKey[scopeKey] ?? <void Function(EventEnvelope event)>[];
    listeners.add(onEvent);
    _onEventByScopeKey[scopeKey] = listeners;
    if (onDone != null) {
      final doneListeners = _onDoneByScopeKey[scopeKey] ?? <void Function()>[];
      doneListeners.add(onDone);
      _onDoneByScopeKey[scopeKey] = doneListeners;
    }
    if (onError != null) {
      final errorListeners =
          _onErrorByScopeKey[scopeKey] ??
          <void Function(Object error, StackTrace stackTrace)>[];
      errorListeners.add(onError);
      _onErrorByScopeKey[scopeKey] = errorListeners;
    }
  }

  void emitToScope(
    ServerProfile profile,
    ProjectTarget project,
    EventEnvelope event,
  ) {
    final listeners =
        _onEventByScopeKey[_scopeKeyFor(profile, project)] ??
        const <void Function(EventEnvelope event)>[];
    for (final listener in List<void Function(EventEnvelope event)>.from(
      listeners,
    )) {
      listener(event);
    }
  }

  void completeScope(ServerProfile profile, ProjectTarget project) {
    final listeners =
        _onDoneByScopeKey[_scopeKeyFor(profile, project)] ??
        const <void Function()>[];
    for (final listener in List<void Function()>.from(listeners)) {
      listener();
    }
  }

  void emitErrorToScope(
    ServerProfile profile,
    ProjectTarget project,
    Object error,
  ) {
    final listeners =
        _onErrorByScopeKey[_scopeKeyFor(profile, project)] ??
        const <void Function(Object error, StackTrace stackTrace)>[];
    for (final listener
        in List<void Function(Object error, StackTrace stackTrace)>.from(
          listeners,
        )) {
      listener(error, StackTrace.current);
    }
  }

  int activeSubscriptionCountForScope(
    ServerProfile profile,
    ProjectTarget project,
  ) {
    return _onEventByScopeKey[_scopeKeyFor(profile, project)]?.length ?? 0;
  }

  @override
  Future<void> disconnect() async {
    disconnectCallCount += 1;
    _onEventByScopeKey.clear();
    _onDoneByScopeKey.clear();
    _onErrorByScopeKey.clear();
  }

  @override
  void dispose() {
    _onEventByScopeKey.clear();
    _onDoneByScopeKey.clear();
    _onErrorByScopeKey.clear();
  }
}

class _RecordingCacheStore extends StaleCacheStore {
  final Map<String, StaleCacheEntry> entries = <String, StaleCacheEntry>{};
  int saveCalls = 0;

  @override
  Future<StaleCacheEntry?> load(String key) async => entries[key];

  @override
  Future<void> save(
    String key,
    Object? payload, {
    String? signature,
    int? itemCount,
  }) async {
    saveCalls += 1;
    final payloadJson = jsonEncode(payload);
    entries[key] = StaleCacheEntry(
      payloadJson: payloadJson,
      signature: signature ?? payloadJson,
      fetchedAt: DateTime.now(),
    );
  }

  @override
  Future<void> remove(String key) async {
    entries.remove(key);
  }

  @override
  Future<void> clearAll() async {
    entries.clear();
  }
}

class _RecordingSessionActionService extends SessionActionService {
  int abortCalls = 0;
  String? lastAbortedSessionId;
  int summarizeCalls = 0;
  String? lastSummarizedSessionId;
  String? lastSummarizedProviderId;
  String? lastSummarizedModelId;

  @override
  Future<bool> abortSession({
    required ServerProfile profile,
    required ProjectTarget project,
    required String sessionId,
  }) async {
    abortCalls += 1;
    lastAbortedSessionId = sessionId;
    return true;
  }

  @override
  Future<bool> summarizeSession({
    required ServerProfile profile,
    required ProjectTarget project,
    required String sessionId,
    String? providerId,
    String? modelId,
    bool auto = false,
  }) async {
    summarizeCalls += 1;
    lastSummarizedSessionId = sessionId;
    lastSummarizedProviderId = providerId;
    lastSummarizedModelId = modelId;
    return true;
  }
}

String _scopeKeyFor(ServerProfile profile, ProjectTarget project) {
  return '${profile.storageKey}::${project.directory}';
}

ConfigSnapshot _composerConfigSnapshot({
  String configuredModel = 'openai/gpt-4.1',
}) {
  return ConfigSnapshot(
    config: RawJsonDocument(<String, Object?>{
      'model': configuredModel,
      'reasoning': 'medium',
    }),
    providerConfig: RawJsonDocument(<String, Object?>{
      'providers': <Object?>[
        <String, Object?>{
          'id': 'openai',
          'name': 'OpenAI',
          'models': <String, Object?>{
            'gpt-4.1': <String, Object?>{
              'id': 'gpt-4.1',
              'name': 'GPT-4.1',
              'variants': <String, Object?>{
                'medium': <String, Object?>{},
                'high': <String, Object?>{},
              },
            },
            'gpt-5.4': <String, Object?>{
              'id': 'gpt-5.4',
              'name': 'GPT-5.4',
              'variants': <String, Object?>{
                'medium': <String, Object?>{},
                'high': <String, Object?>{},
              },
            },
          },
        },
      ],
      'default': <String, Object?>{'openai': 'gpt-4.1'},
    }),
  );
}

ConfigSnapshot _multiProviderComposerConfigSnapshot({
  String configuredModel = 'openai/gpt-4.1',
}) {
  return ConfigSnapshot(
    config: RawJsonDocument(<String, Object?>{
      'model': configuredModel,
      'reasoning': 'medium',
    }),
    providerConfig: RawJsonDocument(<String, Object?>{
      'providers': <Object?>[
        <String, Object?>{
          'id': 'openai',
          'name': 'OpenAI',
          'models': <String, Object?>{
            'gpt-4.1': <String, Object?>{
              'id': 'gpt-4.1',
              'name': 'GPT-4.1',
              'variants': <String, Object?>{
                'medium': <String, Object?>{},
                'high': <String, Object?>{},
              },
            },
            'gpt-5.4': <String, Object?>{
              'id': 'gpt-5.4',
              'name': 'GPT-5.4',
              'variants': <String, Object?>{
                'medium': <String, Object?>{},
                'high': <String, Object?>{},
              },
            },
          },
        },
        <String, Object?>{
          'id': 'anthropic',
          'name': 'Anthropic',
          'models': <String, Object?>{
            'claude-sonnet-4.5': <String, Object?>{
              'id': 'claude-sonnet-4.5',
              'name': 'Claude Sonnet 4.5',
              'variants': <String, Object?>{
                'medium': <String, Object?>{},
                'high': <String, Object?>{},
              },
            },
          },
        },
      ],
      'default': <String, Object?>{'openai': 'gpt-4.1'},
    }),
  );
}

class _FakeProjectCatalogService extends ProjectCatalogService {
  _FakeProjectCatalogService(this.project);

  ProjectTarget project;
  int initGitCallCount = 0;

  @override
  Future<ProjectCatalog> fetchCatalog(ServerProfile profile) async {
    return ProjectCatalog(
      currentProject: ProjectSummary(
        id: project.directory,
        directory: project.directory,
        worktree: project.directory,
        name: project.label,
        vcs: project.vcs,
        updatedAt: null,
      ),
      projects: <ProjectSummary>[
        ProjectSummary(
          id: project.directory,
          directory: project.directory,
          worktree: project.directory,
          name: project.label,
          vcs: project.vcs,
          updatedAt: null,
        ),
      ],
      pathInfo: const PathInfo(
        home: '/home/test',
        state: '/state',
        config: '/config',
        worktree: '/workspace/demo',
        directory: '/workspace/demo',
      ),
      vcsInfo: VcsInfo(branch: project.branch ?? 'main'),
    );
  }

  @override
  Future<ProjectTarget> inspectDirectory({
    required ServerProfile profile,
    required String directory,
  }) async {
    return project;
  }

  @override
  Future<ProjectTarget> initGit({
    required ServerProfile profile,
    required String directory,
  }) async {
    initGitCallCount += 1;
    project = project.copyWith(vcs: 'git', branch: 'main');
    return project;
  }
}

class _MemoryProjectStore extends ProjectStore {
  List<ProjectTarget> _recentProjects = const <ProjectTarget>[];
  final List<ProjectTarget> savedLastWorkspaceTargets = <ProjectTarget>[];

  @override
  Future<List<ProjectTarget>> loadRecentProjects() async => _recentProjects;

  @override
  Future<List<ProjectTarget>> recordRecentProject(ProjectTarget target) async {
    _recentProjects = <ProjectTarget>[target];
    return _recentProjects;
  }

  @override
  Future<void> saveLastWorkspace({
    required String serverStorageKey,
    required ProjectTarget target,
  }) async {
    savedLastWorkspaceTargets.add(target);
  }
}

class _FakeChatService extends ChatService {
  _FakeChatService({
    required this.bundle,
    this.fetchMessagesHandler,
    this.fetchMessagesPageHandler,
    this.sendMessageHandler,
    this.sendMessageAsyncHandler,
  });

  ChatSessionBundle bundle;
  int createSessionCalls = 0;
  final Future<List<ChatMessage>> Function({
    required ServerProfile profile,
    required ProjectTarget project,
    required String sessionId,
  })?
  fetchMessagesHandler;
  final Future<ChatMessagePage> Function({
    required ServerProfile profile,
    required ProjectTarget project,
    required String sessionId,
    required int limit,
    String? before,
  })?
  fetchMessagesPageHandler;
  final Future<ChatMessage> Function({
    required ServerProfile profile,
    required ProjectTarget project,
    required String sessionId,
    required String prompt,
    List<PromptAttachment> attachments,
    String? agent,
    String? providerId,
    String? modelId,
    String? variant,
    String? reasoning,
  })?
  sendMessageHandler;
  final Future<bool> Function({
    required ServerProfile profile,
    required ProjectTarget project,
    required String sessionId,
    required String prompt,
    List<PromptAttachment> attachments,
    String? messageId,
    String? agent,
    String? providerId,
    String? modelId,
    String? variant,
    String? reasoning,
  })?
  sendMessageAsyncHandler;

  @override
  Future<ChatSessionBundle> fetchBundle({
    required ServerProfile profile,
    required ProjectTarget project,
    bool includeSelectedSessionMessages = true,
  }) async {
    return bundle;
  }

  @override
  Future<SessionSummary> createSession({
    required ServerProfile profile,
    required ProjectTarget project,
    String? title,
  }) async {
    createSessionCalls += 1;
    return SessionSummary(
      id: 'ses_created',
      directory: project.directory,
      title: title ?? 'Created session',
      version: '1',
      createdAt: DateTime.fromMillisecondsSinceEpoch(1710000010000),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(1710000010000),
    );
  }

  @override
  Future<List<ChatMessage>> fetchMessages({
    required ServerProfile profile,
    required ProjectTarget project,
    required String sessionId,
  }) async {
    final handler = fetchMessagesHandler;
    if (handler != null) {
      return handler(profile: profile, project: project, sessionId: sessionId);
    }
    return const <ChatMessage>[];
  }

  @override
  Future<ChatMessagePage> fetchMessagesPage({
    required ServerProfile profile,
    required ProjectTarget project,
    required String sessionId,
    required int limit,
    String? before,
    void Function(List<ChatMessage> messages)? onMessagesProgress,
  }) async {
    final pageHandler = fetchMessagesPageHandler;
    if (pageHandler != null) {
      return pageHandler(
        profile: profile,
        project: project,
        sessionId: sessionId,
        limit: limit,
        before: before,
      );
    }
    final handler = fetchMessagesHandler;
    if (handler != null) {
      return ChatMessagePage(
        messages: await handler(
          profile: profile,
          project: project,
          sessionId: sessionId,
        ),
      );
    }
    return const ChatMessagePage(messages: <ChatMessage>[]);
  }

  @override
  Future<ChatMessage> sendMessage({
    required ServerProfile profile,
    required ProjectTarget project,
    required String sessionId,
    required String prompt,
    List<PromptAttachment> attachments = const <PromptAttachment>[],
    String? agent,
    String? providerId,
    String? modelId,
    String? variant,
    String? reasoning,
  }) async {
    final handler = sendMessageHandler;
    if (handler != null) {
      return handler(
        profile: profile,
        project: project,
        sessionId: sessionId,
        prompt: prompt,
        attachments: attachments,
        agent: agent,
        providerId: providerId,
        modelId: modelId,
        variant: variant,
        reasoning: reasoning,
      );
    }
    return ChatMessage(
      info: ChatMessageInfo(
        id: 'msg_stub',
        role: 'assistant',
        sessionId: sessionId,
      ),
      parts: const <ChatPart>[],
    );
  }

  @override
  Future<bool> sendMessageAsync({
    required ServerProfile profile,
    required ProjectTarget project,
    required String sessionId,
    required String prompt,
    List<PromptAttachment> attachments = const <PromptAttachment>[],
    String? messageId,
    String? agent,
    String? providerId,
    String? modelId,
    String? variant,
    String? reasoning,
  }) async {
    final handler = sendMessageAsyncHandler;
    if (handler != null) {
      return handler(
        profile: profile,
        project: project,
        sessionId: sessionId,
        prompt: prompt,
        attachments: attachments,
        messageId: messageId,
        agent: agent,
        providerId: providerId,
        modelId: modelId,
        variant: variant,
        reasoning: reasoning,
      );
    }
    return true;
  }

  @override
  void dispose() {}
}

class _FakeFileBrowserService extends FileBrowserService {
  @override
  Future<FileBrowserBundle> fetchBundle({
    required ServerProfile profile,
    required ProjectTarget project,
    String searchQuery = '',
  }) async {
    return const FileBrowserBundle(
      nodes: <FileNodeSummary>[],
      searchResults: <String>[],
      textMatches: <TextMatchSummary>[],
      symbols: <SymbolSummary>[],
      statuses: <FileStatusSummary>[],
      preview: null,
      selectedPath: null,
    );
  }

  @override
  void dispose() {}
}

class _EmptyReviewDiffService extends ReviewDiffService {
  @override
  Future<ReviewSessionDiffBundle> fetchSessionDiffs({
    required ServerProfile profile,
    required String sessionId,
    String? messageId,
  }) async {
    return const ReviewSessionDiffBundle(entries: <ReviewSessionDiffEntry>[]);
  }

  @override
  void dispose() {}
}

class _TrackingReviewDiffService extends ReviewDiffService {
  int fetchCount = 0;

  @override
  Future<ReviewSessionDiffBundle> fetchSessionDiffs({
    required ServerProfile profile,
    required String sessionId,
    String? messageId,
  }) async {
    fetchCount += 1;
    return const ReviewSessionDiffBundle(entries: <ReviewSessionDiffEntry>[]);
  }

  @override
  void dispose() {}
}

class _FakeTodoService extends TodoService {
  @override
  Future<List<TodoItem>> fetchTodos({
    required ServerProfile profile,
    required ProjectTarget project,
    required String sessionId,
  }) async {
    return const <TodoItem>[];
  }

  @override
  void dispose() {}
}

class _FakeRequestService extends RequestService {
  _FakeRequestService({
    this.pendingBundle = const PendingRequestBundle(
      questions: <QuestionRequestSummary>[],
      permissions: <PermissionRequestSummary>[],
    ),
  });

  PendingRequestBundle pendingBundle;
  final List<({String requestId, String reply})> permissionReplies =
      <({String requestId, String reply})>[];

  @override
  Future<PendingRequestBundle> fetchPending({
    required ServerProfile profile,
    required ProjectTarget project,
    bool supportsQuestions = true,
    bool supportsPermissions = true,
  }) async {
    return pendingBundle;
  }

  @override
  Future<bool> replyToPermission({
    required ServerProfile profile,
    required ProjectTarget project,
    required String requestId,
    required String reply,
  }) async {
    permissionReplies.add((requestId: requestId, reply: reply));
    pendingBundle = PendingRequestBundle(
      questions: pendingBundle.questions,
      permissions: pendingBundle.permissions
          .where((item) => item.id != requestId)
          .toList(growable: false),
    );
    return true;
  }

  @override
  void dispose() {}
}

class _FakeConfigService extends ConfigService {
  _FakeConfigService({ConfigSnapshot? snapshot}) : _snapshot = snapshot;

  final ConfigSnapshot? _snapshot;

  @override
  Future<ConfigSnapshot> fetch({
    required ServerProfile profile,
    required ProjectTarget project,
  }) async {
    return _snapshot ??
        ConfigSnapshot(
          config: RawJsonDocument(<String, Object?>{}),
          providerConfig: RawJsonDocument(<String, Object?>{
            'providers': <Object?>[],
          }),
        );
  }

  @override
  void dispose() {}
}

class _FakeAgentService extends AgentService {
  @override
  Future<List<AgentDefinition>> fetchAgents({
    required ServerProfile profile,
  }) async {
    return const <AgentDefinition>[];
  }

  @override
  void dispose() {}
}
