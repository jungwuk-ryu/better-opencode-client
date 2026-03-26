import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile_remote/src/core/connection/connection_models.dart';
import 'package:opencode_mobile_remote/src/core/network/event_stream_service.dart';
import 'package:opencode_mobile_remote/src/core/persistence/stale_cache_store.dart';
import 'package:opencode_mobile_remote/src/core/spec/raw_json_document.dart';
import 'package:opencode_mobile_remote/src/features/chat/chat_models.dart';
import 'package:opencode_mobile_remote/src/features/chat/chat_service.dart';
import 'package:opencode_mobile_remote/src/features/chat/prompt_attachment_models.dart';
import 'package:opencode_mobile_remote/src/features/chat/session_action_service.dart';
import 'package:opencode_mobile_remote/src/features/files/file_browser_service.dart';
import 'package:opencode_mobile_remote/src/features/files/file_models.dart';
import 'package:opencode_mobile_remote/src/features/projects/project_catalog_service.dart';
import 'package:opencode_mobile_remote/src/features/projects/project_models.dart';
import 'package:opencode_mobile_remote/src/features/projects/project_store.dart';
import 'package:opencode_mobile_remote/src/features/requests/request_models.dart';
import 'package:opencode_mobile_remote/src/features/requests/request_service.dart';
import 'package:opencode_mobile_remote/src/features/settings/agent_service.dart';
import 'package:opencode_mobile_remote/src/features/settings/config_service.dart';
import 'package:opencode_mobile_remote/src/features/tools/todo_models.dart';
import 'package:opencode_mobile_remote/src/features/tools/todo_service.dart';
import 'package:opencode_mobile_remote/src/features/web_parity/workspace_controller.dart';
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

  test('controller removes externally deleted sessions in real time', () async {
    final eventStreamService = _ControlledEventStreamService();
    final controller = _buildController(
      profile: profile,
      project: project,
      eventStreamService: eventStreamService,
      initialSessions: <SessionSummary>[
        _session(
          id: 'ses_2',
          title: 'External session',
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

    expect(controller.visibleSessions.map((item) => item.id), <String>[
      'ses_2',
      'ses_1',
    ]);

    eventStreamService.emitToScope(
      profile,
      project,
      const EventEnvelope(
        type: 'session.deleted',
        properties: <String, Object?>{
          'sessionID': 'ses_2',
          'info': <String, Object?>{'id': 'ses_2'},
        },
      ),
    );

    expect(controller.visibleSessions.map((item) => item.id), <String>[
      'ses_1',
    ]);
  });

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
    expect(controller.interruptingSession, isFalse);
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
}

WorkspaceController _buildController({
  required ServerProfile profile,
  required ProjectTarget project,
  required _ControlledEventStreamService eventStreamService,
  ChatService? chatService,
  SessionActionService? sessionActionService,
  StaleCacheStore? cacheStore,
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
    projectCatalogService: _FakeProjectCatalogService(project),
    projectStore: _MemoryProjectStore(),
    cacheStore: cacheStore,
    fileBrowserService: _FakeFileBrowserService(),
    todoService: _FakeTodoService(),
    requestService: _FakeRequestService(pendingBundle: pendingBundle),
    eventStreamService: eventStreamService,
    sessionActionService: sessionActionService,
    configService: _FakeConfigService(),
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

class _ControlledEventStreamService extends EventStreamService {
  final Map<String, void Function(EventEnvelope event)> _onEventByScopeKey =
      <String, void Function(EventEnvelope event)>{};

  @override
  Future<void> connect({
    required ServerProfile profile,
    required ProjectTarget project,
    required void Function(EventEnvelope event) onEvent,
    void Function()? onDone,
    void Function(Object error, StackTrace stackTrace)? onError,
  }) async {
    _onEventByScopeKey[_scopeKeyFor(profile, project)] = onEvent;
  }

  void emitToScope(
    ServerProfile profile,
    ProjectTarget project,
    EventEnvelope event,
  ) {
    _onEventByScopeKey[_scopeKeyFor(profile, project)]?.call(event);
  }

  @override
  Future<void> disconnect() async {}

  @override
  void dispose() {}
}

class _RecordingSessionActionService extends SessionActionService {
  int abortCalls = 0;
  String? lastAbortedSessionId;

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
}

String _scopeKeyFor(ServerProfile profile, ProjectTarget project) {
  return '${profile.storageKey}::${project.directory}';
}

class _FakeProjectCatalogService extends ProjectCatalogService {
  _FakeProjectCatalogService(this.project);

  final ProjectTarget project;

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
}

class _MemoryProjectStore extends ProjectStore {
  List<ProjectTarget> _recentProjects = const <ProjectTarget>[];

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
  }) async {}
}

class _FakeChatService extends ChatService {
  _FakeChatService({
    required this.bundle,
    this.fetchMessagesHandler,
    this.sendMessageHandler,
  });

  final ChatSessionBundle bundle;
  final Future<List<ChatMessage>> Function({
    required ServerProfile profile,
    required ProjectTarget project,
    required String sessionId,
  })?
  fetchMessagesHandler;
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

  @override
  Future<ChatSessionBundle> fetchBundle({
    required ServerProfile profile,
    required ProjectTarget project,
  }) async {
    return bundle;
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
  _FakeRequestService({required this.pendingBundle});

  final PendingRequestBundle pendingBundle;

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
  void dispose() {}
}

class _FakeConfigService extends ConfigService {
  @override
  Future<ConfigSnapshot> fetch({
    required ServerProfile profile,
    required ProjectTarget project,
  }) async {
    return ConfigSnapshot(
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
