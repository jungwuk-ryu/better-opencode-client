import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile_remote/src/core/connection/connection_models.dart';
import 'package:opencode_mobile_remote/src/core/network/event_stream_service.dart';
import 'package:opencode_mobile_remote/src/core/spec/raw_json_document.dart';
import 'package:opencode_mobile_remote/src/features/chat/chat_models.dart';
import 'package:opencode_mobile_remote/src/features/chat/chat_service.dart';
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

void main() {
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
}

WorkspaceController _buildController({
  required ServerProfile profile,
  required ProjectTarget project,
  required _ControlledEventStreamService eventStreamService,
  List<SessionSummary>? initialSessions,
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
    chatService: _FakeChatService(
      bundle: ChatSessionBundle(
        sessions: sessions,
        statuses: const <String, SessionStatusSummary>{
          'ses_1': SessionStatusSummary(type: 'idle'),
        },
        messages: const <ChatMessage>[],
        selectedSessionId: 'ses_1',
      ),
    ),
    projectCatalogService: _FakeProjectCatalogService(project),
    projectStore: _MemoryProjectStore(),
    fileBrowserService: _FakeFileBrowserService(),
    todoService: _FakeTodoService(),
    requestService: _FakeRequestService(),
    eventStreamService: eventStreamService,
    configService: _FakeConfigService(),
    agentService: _FakeAgentService(),
  );
}

SessionSummary _session({
  required String id,
  required String title,
  required int createdAt,
  required int updatedAt,
}) {
  return SessionSummary(
    id: id,
    directory: '/workspace/demo',
    title: title,
    version: '1',
    createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAt),
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
  _FakeChatService({required this.bundle});

  final ChatSessionBundle bundle;

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
    return const <ChatMessage>[];
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
  @override
  Future<PendingRequestBundle> fetchPending({
    required ServerProfile profile,
    required ProjectTarget project,
    bool supportsQuestions = true,
    bool supportsPermissions = true,
  }) async {
    return const PendingRequestBundle(
      questions: <QuestionRequestSummary>[],
      permissions: <PermissionRequestSummary>[],
    );
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
