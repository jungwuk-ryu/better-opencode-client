import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:opencode_mobile_remote/src/app/app_controller.dart';
import 'package:opencode_mobile_remote/src/app/app_routes.dart';
import 'package:opencode_mobile_remote/src/app/app_scope.dart';
import 'package:opencode_mobile_remote/src/core/connection/connection_models.dart';
import 'package:opencode_mobile_remote/src/design_system/app_theme.dart';
import 'package:opencode_mobile_remote/src/features/chat/chat_models.dart';
import 'package:opencode_mobile_remote/src/features/projects/project_models.dart';
import 'package:opencode_mobile_remote/src/features/requests/request_models.dart';
import 'package:opencode_mobile_remote/src/features/terminal/pty_models.dart';
import 'package:opencode_mobile_remote/src/features/terminal/pty_service.dart';
import 'package:opencode_mobile_remote/src/features/tools/todo_models.dart';
import 'package:opencode_mobile_remote/src/features/web_parity/workspace_controller.dart';
import 'package:opencode_mobile_remote/src/features/web_parity/workspace_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('sidebar only shows user-created root sessions', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final profile = ServerProfile(
      id: 'server',
      label: 'Mock',
      baseUrl: 'http://localhost:3000',
    );
    final appController = _StaticAppController(
      profile: profile,
      workspaceControllerFactory: ({
        required profile,
        required directory,
        initialSessionId,
      }) {
        return _SidebarWorkspaceController(
          profile: profile,
          directory: directory,
          initialSessionId: initialSessionId,
        );
      },
    );
    addTearDown(appController.dispose);

    await tester.pumpWidget(
      _WorkspaceRouteHarness(
        controller: appController,
        initialRoute: buildWorkspaceRoute('/workspace/demo', sessionId: 'ses_1'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Root session'), findsAtLeastNWidgets(1));
    expect(find.text('Another root session'), findsAtLeastNWidgets(1));
    expect(find.text('Nested subagent session'), findsNothing);
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
    required WorkspaceControllerFactory workspaceControllerFactory,
  }) : super(workspaceControllerFactory: workspaceControllerFactory);

  final ServerProfile profile;

  @override
  ServerProfile? get selectedProfile => profile;
}

class _SidebarWorkspaceController extends WorkspaceController {
  _SidebarWorkspaceController({
    required super.profile,
    required super.directory,
    super.initialSessionId,
  });

  static const ProjectTarget _projectTarget = ProjectTarget(
    directory: '/workspace/demo',
    label: 'Demo',
    source: 'server',
    vcs: 'git',
    branch: 'main',
  );

  static final List<SessionSummary> _sessions = <SessionSummary>[
    SessionSummary(
      id: 'ses_1',
      directory: '/workspace/demo',
      title: 'Root session',
      version: '1',
      updatedAt: DateTime.fromMillisecondsSinceEpoch(1710000001000),
    ),
    SessionSummary(
      id: 'ses_child',
      directory: '/workspace/demo',
      title: 'Nested subagent session',
      version: '1',
      updatedAt: DateTime.fromMillisecondsSinceEpoch(1710000001500),
      parentId: 'ses_1',
    ),
    SessionSummary(
      id: 'ses_2',
      directory: '/workspace/demo',
      title: 'Another root session',
      version: '1',
      updatedAt: DateTime.fromMillisecondsSinceEpoch(1710000002000),
    ),
  ];

  bool _loading = true;
  String? _selectedSessionId;

  @override
  bool get loading => _loading;

  @override
  ProjectTarget? get project => _projectTarget;

  @override
  List<ProjectTarget> get availableProjects => const <ProjectTarget>[
    _projectTarget,
  ];

  @override
  List<SessionSummary> get sessions => _sessions;

  @override
  String? get selectedSessionId => _selectedSessionId;

  @override
  SessionSummary? get selectedSession => _sessions.first;

  @override
  List<ChatMessage> get messages => const <ChatMessage>[];

  @override
  List<TodoItem> get todos => const <TodoItem>[];

  @override
  PendingRequestBundle get pendingRequests => const PendingRequestBundle(
    questions: <QuestionRequestSummary>[],
    permissions: <PermissionRequestSummary>[],
  );

  @override
  Future<void> load() async {
    _loading = false;
    _selectedSessionId = initialSessionId ?? 'ses_1';
    notifyListeners();
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
