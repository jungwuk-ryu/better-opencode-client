import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:better_opencode_client/src/app/app_controller.dart';
import 'package:better_opencode_client/src/app/app_routes.dart';
import 'package:better_opencode_client/src/app/app_scope.dart';
import 'package:better_opencode_client/src/core/connection/connection_models.dart';
import 'package:better_opencode_client/src/design_system/app_theme.dart';
import 'package:better_opencode_client/src/features/chat/chat_models.dart';
import 'package:better_opencode_client/src/features/projects/project_models.dart';
import 'package:better_opencode_client/src/features/terminal/pty_models.dart';
import 'package:better_opencode_client/src/features/terminal/pty_service.dart';
import 'package:better_opencode_client/src/features/tools/todo_models.dart';
import 'package:better_opencode_client/src/features/web_parity/workspace_controller.dart';
import 'package:better_opencode_client/src/features/web_parity/workspace_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'todo dock mirrors live todos, collapses, and clears stale state',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final profile = ServerProfile(
        id: 'server',
        label: 'Mock',
        baseUrl: 'http://localhost:3000',
      );
      final workspaceController = _TodoDockWorkspaceController(
        profile: profile,
        directory: '/workspace/demo',
      );
      final appController = _StaticAppController(
        profile: profile,
        workspaceController: workspaceController,
      );
      addTearDown(appController.dispose);

      await tester.pumpWidget(
        _WorkspaceRouteHarness(
          controller: appController,
          initialRoute: buildWorkspaceRoute(
            '/workspace/demo',
            sessionId: 'ses_1',
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('0 of 2 todos completed'), findsOneWidget);
      expect(find.text('Planning session gap list'), findsOneWidget);
      expect(find.text('Append acceptance criteria'), findsOneWidget);
      expect(find.text('call_todo_write_1'), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey<String>('session-todo-toggle-button')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('Append acceptance criteria'), findsNothing);
      expect(find.text('Planning session gap list'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('session-todo-toggle-button')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      workspaceController.updateTodos(<TodoItem>[
        const TodoItem(
          id: 'todo_1',
          content: 'Planning session gap list',
          status: 'completed',
          priority: 'high',
        ),
        const TodoItem(
          id: 'todo_2',
          content: 'Append acceptance criteria',
          status: 'in_progress',
          priority: 'medium',
        ),
      ]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('1 of 2 todos completed'), findsOneWidget);

      workspaceController.updateStatus(
        const SessionStatusSummary(type: 'idle'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));

      expect(find.text('1 of 2 todos completed'), findsNothing);
      expect(workspaceController.todos, isEmpty);
    },
  );

  testWidgets('compact activity bar hides todos once all items are complete', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final profile = ServerProfile(
      id: 'server',
      label: 'Mock',
      baseUrl: 'http://localhost:3000',
    );
    final workspaceController = _TodoDockWorkspaceController(
      profile: profile,
      directory: '/workspace/demo',
    );
    final appController = _StaticAppController(
      profile: profile,
      workspaceController: workspaceController,
    );
    addTearDown(appController.dispose);

    await tester.pumpWidget(
      _WorkspaceRouteHarness(
        controller: appController,
        initialRoute: buildWorkspaceRoute(
          '/workspace/demo',
          sessionId: 'ses_1',
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      find.byKey(const ValueKey<String>('compact-session-todos-button')),
      findsOneWidget,
    );

    workspaceController.updateTodos(<TodoItem>[
      const TodoItem(
        id: 'todo_1',
        content: 'Planning session gap list',
        status: 'completed',
        priority: 'high',
      ),
      const TodoItem(
        id: 'todo_2',
        content: 'Append acceptance criteria',
        status: 'completed',
        priority: 'medium',
      ),
    ]);
    workspaceController.updateStatus(const SessionStatusSummary(type: 'idle'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));

    expect(
      find.byKey(const ValueKey<String>('compact-session-todos-button')),
      findsNothing,
    );
  });
}

class _WorkspaceRouteHarness extends StatelessWidget {
  const _WorkspaceRouteHarness({
    required this.controller,
    required this.initialRoute,
  });

  final WebParityAppController controller;
  final String initialRoute;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      controller: controller,
      child: MaterialApp(
        theme: AppTheme.dark(),
        initialRoute: initialRoute,
        onGenerateRoute: (settings) {
          final route = AppRouteData.parse(settings.name);
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (context) {
              return switch (route) {
                HomeRouteData() => const SizedBox.shrink(),
                WorkspaceRouteData(:final directory, :final sessionId) =>
                  WebParityWorkspaceScreen(
                    key: ValueKey<String>('workspace-$directory'),
                    directory: directory,
                    sessionId: sessionId,
                    ptyServiceFactory: _FakePtyService.new,
                  ),
              };
            },
          );
        },
      ),
    );
  }
}

class _StaticAppController extends WebParityAppController {
  _StaticAppController({
    required this.profile,
    required this.workspaceController,
  }) : super(
         workspaceControllerFactory:
             ({required profile, required directory, initialSessionId}) {
               return workspaceController;
             },
       );

  final ServerProfile profile;
  final WorkspaceController workspaceController;

  @override
  ServerProfile? get selectedProfile => profile;
}

class _TodoDockWorkspaceController extends WorkspaceController {
  _TodoDockWorkspaceController({
    required super.profile,
    required super.directory,
  });

  static const ProjectTarget _projectTarget = ProjectTarget(
    directory: '/workspace/demo',
    label: 'Demo',
    source: 'server',
    vcs: 'git',
    branch: 'main',
  );

  static final SessionSummary _session = SessionSummary(
    id: 'ses_1',
    directory: '/workspace/demo',
    title: 'Plan implementation steps',
    version: '1',
    updatedAt: DateTime.fromMillisecondsSinceEpoch(1710000001000),
  );

  static final List<ChatMessage> _messages = <ChatMessage>[
    ChatMessage(
      info: const ChatMessageInfo(
        id: 'msg_assistant_1',
        role: 'assistant',
        sessionId: 'ses_1',
      ),
      parts: const <ChatPart>[
        ChatPart(
          id: 'part_reasoning',
          type: 'reasoning',
          text: '## Planning implementation steps',
        ),
        ChatPart(
          id: 'part_todo_write',
          type: 'tool',
          tool: 'todowrite',
          metadata: <String, Object?>{
            'callID': 'call_todo_write_1',
            'state': <String, Object?>{'status': 'completed'},
          },
        ),
      ],
    ),
  ];

  bool _loading = true;
  SessionStatusSummary _status = const SessionStatusSummary(type: 'running');
  List<TodoItem> _todos = const <TodoItem>[
    TodoItem(
      id: 'todo_1',
      content: 'Planning session gap list',
      status: 'in_progress',
      priority: 'high',
    ),
    TodoItem(
      id: 'todo_2',
      content: 'Append acceptance criteria',
      status: 'pending',
      priority: 'medium',
    ),
  ];

  @override
  bool get loading => _loading;

  @override
  ProjectTarget? get project => _projectTarget;

  @override
  List<ProjectTarget> get availableProjects => const <ProjectTarget>[
    _projectTarget,
  ];

  @override
  List<SessionSummary> get sessions => <SessionSummary>[_session];

  @override
  String? get selectedSessionId => _session.id;

  @override
  SessionSummary? get selectedSession => _session;

  @override
  SessionStatusSummary? get selectedStatus => _status;

  @override
  List<ChatMessage> get messages => _messages;

  @override
  List<TodoItem> get todos => _todos;

  @override
  Future<void> load() async {
    _loading = false;
    notifyListeners();
  }

  void updateTodos(List<TodoItem> todos) {
    _todos = List<TodoItem>.unmodifiable(todos);
    notifyListeners();
  }

  void updateStatus(SessionStatusSummary status) {
    _status = status;
    notifyListeners();
  }

  @override
  void clearTodos() {
    _todos = const <TodoItem>[];
    notifyListeners();
  }

  @override
  void clearTodosForSession(String? sessionId) {
    if (sessionId != _session.id) {
      return;
    }
    clearTodos();
  }
}

class _FakePtyService extends PtyService {
  _FakePtyService()
    : super(client: MockClient((request) async => http.Response('[]', 200)));

  @override
  Future<List<PtySessionInfo>> listSessions({
    required ServerProfile profile,
    required String directory,
  }) async {
    return const <PtySessionInfo>[];
  }
}
