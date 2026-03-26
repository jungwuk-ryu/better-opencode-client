import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:opencode_mobile_remote/src/app/app_controller.dart';
import 'package:opencode_mobile_remote/src/app/app_routes.dart';
import 'package:opencode_mobile_remote/src/app/app_scope.dart';
import 'package:opencode_mobile_remote/src/core/connection/connection_models.dart';
import 'package:opencode_mobile_remote/src/core/network/opencode_server_probe.dart';
import 'package:opencode_mobile_remote/src/core/spec/capability_registry.dart';
import 'package:opencode_mobile_remote/src/core/spec/probe_snapshot.dart';
import 'package:opencode_mobile_remote/src/design_system/app_theme.dart';
import 'package:opencode_mobile_remote/src/features/chat/chat_models.dart';
import 'package:opencode_mobile_remote/src/features/projects/project_catalog_service.dart';
import 'package:opencode_mobile_remote/src/features/projects/project_models.dart';
import 'package:opencode_mobile_remote/src/features/requests/request_models.dart';
import 'package:opencode_mobile_remote/src/features/terminal/pty_models.dart';
import 'package:opencode_mobile_remote/src/features/terminal/pty_service.dart';
import 'package:opencode_mobile_remote/src/features/tools/todo_models.dart';
import 'package:opencode_mobile_remote/src/features/web_parity/workspace_controller.dart';
import 'package:opencode_mobile_remote/src/features/web_parity/workspace_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('sidebar hides nested sessions by default', (tester) async {
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
      workspaceControllerFactory:
          ({required profile, required directory, initialSessionId}) {
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
        initialRoute: buildWorkspaceRoute(
          '/workspace/demo',
          sessionId: 'ses_1',
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Demo'), findsOneWidget);
    expect(find.text('/workspace/demo'), findsOneWidget);
    expect(find.text('New session'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey<String>('workspace-sidebar-project-menu-button'),
      ),
      findsOneWidget,
    );
    expect(find.text('Root session'), findsAtLeastNWidgets(1));
    expect(find.text('Another root session'), findsAtLeastNWidgets(1));
    expect(find.text('Nested subagent session'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('workspace-session-entry-ses_child-1')),
      findsNothing,
    );
    expect(find.text('Sessions'), findsNothing);
    expect(find.text('idle'), findsNothing);
    expect(find.text('busy'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('sidebar-session-shimmer-ses_1')),
      findsOneWidget,
    );
  });

  testWidgets('sidebar settings opens a real workspace settings sheet', (
    tester,
  ) async {
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
      shellToolPartsExpandedValue: true,
      timelineProgressDetailsVisibleValue: false,
      sidebarChildSessionsVisibleValue: false,
      report: _readyReport,
      workspaceControllerFactory:
          ({required profile, required directory, initialSessionId}) {
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
        initialRoute: buildWorkspaceRoute(
          '/workspace/demo',
          sessionId: 'ses_1',
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byIcon(Icons.help_outline_rounded), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey<String>('workspace-sidebar-settings-button')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 240));

    expect(
      find.byKey(const ValueKey<String>('workspace-settings-sheet')),
      findsOneWidget,
    );
    expect(find.text('Workspace Settings'), findsOneWidget);
    expect(find.text('Manage Servers'), findsOneWidget);
    expect(find.text('Ready'), findsOneWidget);
    expect(find.text('Nested subagent session'), findsNothing);

    final shellSwitch = find.descendant(
      of: find.byKey(const ValueKey<String>('workspace-settings-shell-toggle')),
      matching: find.byType(Switch),
    );
    await tester.tap(shellSwitch);
    await tester.pump();

    expect(appController.shellToolPartsExpanded, isFalse);

    await tester.dragUntilVisible(
      find.byKey(
        const ValueKey<String>(
          'workspace-settings-sidebar-child-sessions-toggle',
        ),
      ),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));

    final sidebarToggle = find.descendant(
      of: find.byKey(
        const ValueKey<String>(
          'workspace-settings-sidebar-child-sessions-toggle',
        ),
      ),
      matching: find.byType(Switch),
    );
    await tester.tap(sidebarToggle);
    await tester.pump();

    expect(appController.sidebarChildSessionsVisible, isTrue);
    expect(find.text('Nested subagent session'), findsAtLeastNWidgets(1));
  });

  testWidgets('project tile context menu edits and removes projects', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final profile = ServerProfile(
      id: 'server',
      label: 'Mock',
      baseUrl: 'http://localhost:3000',
    );
    late _EditableSidebarWorkspaceController controllerInstance;
    final appController = _StaticAppController(
      profile: profile,
      workspaceControllerFactory:
          ({required profile, required directory, initialSessionId}) {
            controllerInstance = _EditableSidebarWorkspaceController(
              profile: profile,
              directory: directory,
              initialSessionId: initialSessionId,
            );
            return controllerInstance;
          },
    );
    addTearDown(appController.dispose);

    await tester.pumpWidget(
      _WorkspaceRouteHarness(
        controller: appController,
        initialRoute: buildWorkspaceRoute(
          '/workspace/demo',
          sessionId: 'ses_1',
        ),
        projectCatalogService: _FakeProjectCatalogService(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    final labTile = find.byKey(
      const ValueKey<String>('workspace-project-/workspace/lab'),
    );
    expect(labTile, findsOneWidget);

    await tester.longPress(labTile);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));

    expect(find.text('Edit project'), findsOneWidget);
    expect(find.text('Delete project'), findsOneWidget);

    await tester.tap(find.text('Edit project'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    expect(find.text('Edit project'), findsAtLeastNWidgets(1));
    final nameField = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == 'Name',
    );
    final startupField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.labelText == 'Workspace startup script',
    );
    await tester.enterText(nameField, 'Lab Renamed');
    await tester.enterText(startupField, 'bun install');
    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    final updatedProject = controllerInstance.availableProjects.firstWhere(
      (project) => project.directory == '/workspace/lab',
    );
    expect(updatedProject.name, 'Lab Renamed');
    expect(updatedProject.commands?.start, 'bun install');

    await tester.longPress(labTile);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));
    await tester.tap(find.text('Delete project'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    expect(
      find.byKey(const ValueKey<String>('workspace-project-/workspace/lab')),
      findsNothing,
    );
  });
}

class _WorkspaceRouteHarness extends StatelessWidget {
  const _WorkspaceRouteHarness({
    required this.controller,
    required this.initialRoute,
    this.projectCatalogService,
  });

  final WebParityAppController controller;
  final String initialRoute;
  final ProjectCatalogService? projectCatalogService;

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
                    projectCatalogService: projectCatalogService,
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
    this.report,
    this.shellToolPartsExpandedValue = true,
    this.timelineProgressDetailsVisibleValue = false,
    this.sidebarChildSessionsVisibleValue = false,
    required WorkspaceControllerFactory workspaceControllerFactory,
  }) : super(workspaceControllerFactory: workspaceControllerFactory);

  final ServerProfile profile;
  final ServerProbeReport? report;
  bool shellToolPartsExpandedValue;
  bool timelineProgressDetailsVisibleValue;
  bool sidebarChildSessionsVisibleValue;

  @override
  ServerProfile? get selectedProfile => profile;

  @override
  ServerProbeReport? get selectedReport => report;

  @override
  bool get shellToolPartsExpanded => shellToolPartsExpandedValue;

  @override
  bool get timelineProgressDetailsVisible =>
      timelineProgressDetailsVisibleValue;

  @override
  bool get sidebarChildSessionsVisible => sidebarChildSessionsVisibleValue;

  @override
  Future<void> setShellToolPartsExpanded(bool value) async {
    shellToolPartsExpandedValue = value;
    notifyListeners();
  }

  @override
  Future<void> setTimelineProgressDetailsVisible(bool value) async {
    timelineProgressDetailsVisibleValue = value;
    notifyListeners();
  }

  @override
  Future<void> setSidebarChildSessionsVisible(bool value) async {
    sidebarChildSessionsVisibleValue = value;
    notifyListeners();
  }
}

final ProbeSnapshot _readySnapshot = ProbeSnapshot(
  name: 'OpenCode',
  version: '1.0.0',
  paths: <String>{'/global/health', '/config', '/agent'},
  endpoints: <String, ProbeEndpointResult>{},
  config: const <String, Object?>{},
  providerConfig: const <String, Object?>{},
);

final ServerProbeReport _readyReport = ServerProbeReport(
  snapshot: _readySnapshot,
  capabilityRegistry: CapabilityRegistry.fromSnapshot(_readySnapshot),
  classification: ConnectionProbeClassification.ready,
  summary: 'Server is ready for web parity features.',
  checkedAt: DateTime.fromMillisecondsSinceEpoch(1710000000000),
  missingCapabilities: const <String>[],
  discoveredExperimentalPaths: const <String>[],
  sseReady: true,
);

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

  static const Map<String, SessionStatusSummary> _statuses =
      <String, SessionStatusSummary>{
        'ses_1': SessionStatusSummary(type: 'running'),
        'ses_2': SessionStatusSummary(type: 'idle'),
        'ses_child': SessionStatusSummary(type: 'idle'),
      };

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
  Map<String, SessionStatusSummary> get statuses => _statuses;

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

class _EditableSidebarWorkspaceController extends _SidebarWorkspaceController {
  _EditableSidebarWorkspaceController({
    required super.profile,
    required super.directory,
    super.initialSessionId,
  });

  List<ProjectTarget> _projects = const <ProjectTarget>[
    ProjectTarget(
      id: 'project-demo',
      directory: '/workspace/demo',
      label: 'Demo',
      name: 'Demo',
      source: 'server',
      vcs: 'git',
      branch: 'main',
    ),
    ProjectTarget(
      id: 'project-lab',
      directory: '/workspace/lab',
      label: 'Lab',
      name: 'Lab',
      source: 'server',
      vcs: 'git',
      branch: 'develop',
    ),
  ];

  @override
  ProjectTarget? get project => _projects.first;

  @override
  List<ProjectTarget> get availableProjects => _projects;

  @override
  void applyProjectTargetUpdate(ProjectTarget target, {bool notify = true}) {
    _projects = _projects
        .map(
          (project) => project.directory == target.directory ? target : project,
        )
        .toList(growable: false);
    if (notify) {
      notifyListeners();
    }
  }

  @override
  void applyProjectRemoval(String directory, {bool notify = true}) {
    _projects = _projects
        .where((project) => project.directory != directory)
        .toList(growable: false);
    if (notify) {
      notifyListeners();
    }
  }
}

class _FakeProjectCatalogService extends ProjectCatalogService {
  @override
  Future<ProjectTarget> updateProject({
    required ServerProfile profile,
    required ProjectTarget project,
    String? name,
    ProjectIconInfo? icon,
    ProjectCommandsInfo? commands,
  }) async {
    return project.copyWith(
      label: projectDisplayLabel(project.directory, name: name),
      name: name,
      icon: icon,
      commands: commands,
      clearName: name == null,
      clearIcon: icon == null,
      clearCommands: commands == null,
    );
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
