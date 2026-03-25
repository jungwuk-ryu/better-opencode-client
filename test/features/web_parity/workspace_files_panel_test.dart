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
import 'package:opencode_mobile_remote/src/features/files/file_models.dart';
import 'package:opencode_mobile_remote/src/features/projects/project_models.dart';
import 'package:opencode_mobile_remote/src/features/requests/request_models.dart';
import 'package:opencode_mobile_remote/src/features/terminal/pty_models.dart';
import 'package:opencode_mobile_remote/src/features/terminal/pty_service.dart';
import 'package:opencode_mobile_remote/src/features/tools/todo_models.dart';
import 'package:opencode_mobile_remote/src/features/web_parity/workspace_controller.dart';
import 'package:opencode_mobile_remote/src/features/web_parity/workspace_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('files panel selects a file and updates the preview', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final createdControllers = <_FilesWorkspaceController>[];
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
        final controller = _FilesWorkspaceController(
          profile: profile,
          directory: directory,
          initialSessionId: initialSessionId,
        );
        createdControllers.add(controller);
        return controller;
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

    expect(createdControllers, hasLength(1));
    expect(createdControllers.single.fileBundle?.selectedPath, 'README.md');
    expect(find.text('# README preview'), findsOneWidget);

    await tester.tap(find.text('pubspec.yaml').first);
    await tester.pumpAndSettle();

    expect(createdControllers.single.selectFileCalls, <String>['pubspec.yaml']);
    expect(createdControllers.single.fileBundle?.selectedPath, 'pubspec.yaml');
    expect(find.text('name: demo_workspace'), findsOneWidget);
  });

  testWidgets('files panel expands folders and reveals nested files', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final createdControllers = <_FilesWorkspaceController>[];
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
        final controller = _FilesWorkspaceController(
          profile: profile,
          directory: directory,
          initialSessionId: initialSessionId,
        );
        createdControllers.add(controller);
        return controller;
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

    expect(find.text('main.dart'), findsNothing);

    await tester.tap(find.text('lib').first);
    await tester.pumpAndSettle();

    expect(createdControllers.single.toggleDirectoryCalls, <String>['lib']);
    expect(find.text('main.dart'), findsOneWidget);

    await tester.tap(find.text('main.dart').first);
    await tester.pumpAndSettle();

    expect(
      createdControllers.single.selectFileCalls,
      <String>['lib/main.dart'],
    );
    expect(createdControllers.single.fileBundle?.selectedPath, 'lib/main.dart');
    expect(find.text('// lib/main.dart preview'), findsOneWidget);

    await tester.tap(find.text('lib').first);
    await tester.pumpAndSettle();

    expect(
      createdControllers.single.toggleDirectoryCalls,
      <String>['lib', 'lib'],
    );
    expect(find.text('main.dart'), findsNothing);
  });

  testWidgets('files panel preview can be resized by dragging the handle', (
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
      workspaceControllerFactory: ({
        required profile,
        required directory,
        initialSessionId,
      }) {
        return _FilesWorkspaceController(
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

    final panelFinder = find.byKey(const ValueKey<String>('files-preview-panel'));
    final handleFinder = find.byKey(
      const ValueKey<String>('files-preview-resize-handle'),
    );

    final initialHeight = tester.getSize(panelFinder).height;
    await tester.drag(handleFinder, const Offset(0, -120));
    await tester.pump();

    final resizedHeight = tester.getSize(panelFinder).height;
    expect(resizedHeight, greaterThan(initialHeight));
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

class _FilesWorkspaceController extends WorkspaceController {
  _FilesWorkspaceController({
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
      title: 'Session One',
      version: '1',
      updatedAt: DateTime.fromMillisecondsSinceEpoch(1710000001000),
    ),
  ];

  static final Map<String, String> _previewByPath = <String, String>{
    'README.md': '# README preview',
    'pubspec.yaml': 'name: demo_workspace',
    'lib/main.dart': '// lib/main.dart preview',
  };

  final List<String> selectFileCalls = <String>[];
  final List<String> toggleDirectoryCalls = <String>[];

  bool _loading = true;
  WorkspaceSideTab _sideTab = WorkspaceSideTab.files;
  String? _selectedSessionId;
  FileBrowserBundle? _fileBundle;
  Set<String> _expandedDirectories = <String>{};

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
  WorkspaceSideTab get sideTab => _sideTab;

  @override
  FileBrowserBundle? get fileBundle => _fileBundle;

  @override
  bool get loadingFilePreview => false;

  @override
  Set<String> get expandedFileDirectories => _expandedDirectories;

  @override
  String? get loadingFileDirectoryPath => null;

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
    _fileBundle = FileBrowserBundle(
      nodes: const <FileNodeSummary>[
        FileNodeSummary(
          name: 'README.md',
          path: 'README.md',
          type: 'file',
          ignored: false,
        ),
        FileNodeSummary(
          name: 'pubspec.yaml',
          path: 'pubspec.yaml',
          type: 'file',
          ignored: false,
        ),
        FileNodeSummary(
          name: 'lib',
          path: 'lib',
          type: 'directory',
          ignored: false,
        ),
      ],
      searchResults: const <String>[],
      textMatches: const <TextMatchSummary>[],
      symbols: const <SymbolSummary>[],
      statuses: const <FileStatusSummary>[],
      preview: const FileContentSummary(
        type: 'text',
        content: '# README preview',
      ),
      selectedPath: 'README.md',
    );
    notifyListeners();
  }

  @override
  void setSideTab(WorkspaceSideTab value) {
    _sideTab = value;
    notifyListeners();
  }

  @override
  Future<void> selectFile(String path) async {
    selectFileCalls.add(path);
    _fileBundle = _fileBundle?.copyWith(
      selectedPath: path,
      preview: FileContentSummary(
        type: 'text',
        content: _previewByPath[path] ?? '',
      ),
    );
    notifyListeners();
  }

  @override
  Future<void> toggleFileDirectory(String path) async {
    toggleDirectoryCalls.add(path);
    if (_expandedDirectories.contains(path)) {
      _expandedDirectories = <String>{..._expandedDirectories}..remove(path);
    } else {
      _expandedDirectories = <String>{..._expandedDirectories, path};
      if (path == 'lib' &&
          !(_fileBundle?.nodes.any((node) => node.path == 'lib/main.dart') ??
              false)) {
        _fileBundle = _fileBundle?.copyWith(
          nodes: <FileNodeSummary>[
            ...?_fileBundle?.nodes,
            const FileNodeSummary(
              name: 'main.dart',
              path: 'lib/main.dart',
              type: 'file',
              ignored: false,
            ),
          ],
        );
      }
    }
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
