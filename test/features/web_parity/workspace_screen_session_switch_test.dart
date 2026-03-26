import 'dart:async';

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

  testWidgets(
    'switching sessions keeps the same page and reuses the directory controller',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final createdControllers = <_RecordingWorkspaceController>[];
      final profile = ServerProfile(
        id: 'server',
        label: 'Mock',
        baseUrl: 'http://localhost:3000',
      );
      final appController = _StaticAppController(
        profile: profile,
        workspaceControllerFactory:
            ({required profile, required directory, initialSessionId}) {
              final controller = _RecordingWorkspaceController(
                profile: profile,
                directory: directory,
                initialSessionId: initialSessionId,
              );
              createdControllers.add(controller);
              return controller;
            },
      );
      addTearDown(appController.dispose);

      final navigatorKey = GlobalKey<NavigatorState>();
      final observer = _RecordingNavigatorObserver();

      await tester.pumpWidget(
        _WorkspaceRouteHarness(
          controller: appController,
          navigatorKey: navigatorKey,
          navigatorObservers: <NavigatorObserver>[observer],
          initialRoute: '/',
        ),
      );
      navigatorKey.currentState!.pushNamed(
        buildWorkspaceRoute('/workspace/demo', sessionId: 'ses_1'),
      );
      await tester.pumpAndSettle();

      expect(createdControllers, hasLength(1));
      expect(createdControllers.single.loadCount, 1);
      expect(createdControllers.single.selectSessionCalls, isEmpty);
      expect(createdControllers.single.selectedSessionId, 'ses_1');
      expect(find.byType(WebParityWorkspaceScreen), findsOneWidget);
      expect(find.text('Ask anything...'), findsOneWidget);
      expect(find.text('hello from one'), findsOneWidget);

      final initialRouteName = observer.lastRouteName;

      await tester.tap(find.text('Session Two'));
      await tester.pumpAndSettle();

      expect(createdControllers, hasLength(1));
      expect(createdControllers.single.loadCount, 1);
      expect(createdControllers.single.selectSessionCalls, <String?>['ses_2']);
      expect(createdControllers.single.selectedSessionId, 'ses_2');
      expect(find.text('hello from two'), findsOneWidget);
      expect(observer.lastRouteName, initialRouteName);
      expect(find.byType(WebParityWorkspaceScreen), findsOneWidget);
    },
  );

  testWidgets('switching sessions clears composer focus on compact layouts', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final createdControllers = <_RecordingWorkspaceController>[];
    final profile = ServerProfile(
      id: 'server',
      label: 'Mock',
      baseUrl: 'http://localhost:3000',
    );
    final appController = _StaticAppController(
      profile: profile,
      workspaceControllerFactory:
          ({required profile, required directory, initialSessionId}) {
            final controller = _RecordingWorkspaceController(
              profile: profile,
              directory: directory,
              initialSessionId: initialSessionId,
            );
            createdControllers.add(controller);
            return controller;
          },
    );
    addTearDown(appController.dispose);

    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      _WorkspaceRouteHarness(
        controller: appController,
        navigatorKey: navigatorKey,
        initialRoute: '/',
      ),
    );
    navigatorKey.currentState!.pushNamed(
      buildWorkspaceRoute('/workspace/demo', sessionId: 'ses_1'),
    );
    await tester.pumpAndSettle();

    final composerFinder = find.byKey(
      const ValueKey<String>('composer-text-field'),
    );
    await tester.tap(composerFinder);
    await tester.pump();

    EditableText editableText() =>
        tester.widget<EditableText>(find.byType(EditableText));

    expect(editableText().focusNode.hasFocus, isTrue);
    expect(tester.testTextInput.hasAnyClients, isTrue);

    await createdControllers.single.selectSession('ses_2');
    await tester.pumpAndSettle();

    expect(find.text('hello from two'), findsOneWidget);
    expect(editableText().focusNode.hasFocus, isFalse);
    expect(tester.testTextInput.hasAnyClients, isFalse);
  });

  testWidgets(
    'new session button creates a fresh session without replacing the page',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final createdControllers = <_RecordingWorkspaceController>[];
      final profile = ServerProfile(
        id: 'server',
        label: 'Mock',
        baseUrl: 'http://localhost:3000',
      );
      final appController = _StaticAppController(
        profile: profile,
        workspaceControllerFactory:
            ({required profile, required directory, initialSessionId}) {
              final controller = _RecordingWorkspaceController(
                profile: profile,
                directory: directory,
                initialSessionId: initialSessionId,
              );
              createdControllers.add(controller);
              return controller;
            },
      );
      addTearDown(appController.dispose);

      final navigatorKey = GlobalKey<NavigatorState>();
      final observer = _RecordingNavigatorObserver();

      await tester.pumpWidget(
        _WorkspaceRouteHarness(
          controller: appController,
          navigatorKey: navigatorKey,
          navigatorObservers: <NavigatorObserver>[observer],
          initialRoute: '/',
        ),
      );
      navigatorKey.currentState!.pushNamed(
        buildWorkspaceRoute('/workspace/demo', sessionId: 'ses_1'),
      );
      await tester.pumpAndSettle();
      final initialRouteName = observer.lastRouteName;

      expect(createdControllers, hasLength(1));
      await tester.tap(
        find.byKey(
          const ValueKey<String>('workspace-sidebar-new-session-button'),
        ),
      );
      await tester.pumpAndSettle();

      expect(createdControllers.single.createEmptySessionCalls, 1);
      expect(createdControllers.single.selectedSessionId, 'ses_new');
      expect(observer.lastRouteName, initialRouteName);
      expect(find.text('Fresh session'), findsAtLeastNWidgets(1));
    },
  );

  testWidgets(
    'switching projects stays on the same page and reuses cached workspace controllers',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final createdControllers = <_RecordingWorkspaceController>[];
      final profile = ServerProfile(
        id: 'server',
        label: 'Mock',
        baseUrl: 'http://localhost:3000',
      );
      final appController = _StaticAppController(
        profile: profile,
        workspaceControllerFactory:
            ({required profile, required directory, initialSessionId}) {
              final controller = _RecordingWorkspaceController(
                profile: profile,
                directory: directory,
                initialSessionId: initialSessionId,
              );
              createdControllers.add(controller);
              return controller;
            },
      );
      addTearDown(appController.dispose);

      final navigatorKey = GlobalKey<NavigatorState>();
      final observer = _RecordingNavigatorObserver();

      await tester.pumpWidget(
        _WorkspaceRouteHarness(
          controller: appController,
          navigatorKey: navigatorKey,
          navigatorObservers: <NavigatorObserver>[observer],
          initialRoute: '/',
        ),
      );
      navigatorKey.currentState!.pushNamed(
        buildWorkspaceRoute('/workspace/demo', sessionId: 'ses_1'),
      );
      await tester.pumpAndSettle();

      expect(createdControllers, hasLength(1));
      expect(createdControllers.single.loadCount, 1);
      expect(find.text('hello from one'), findsOneWidget);
      final initialRouteName = observer.lastRouteName;

      await tester.tap(
        find.byKey(const ValueKey<String>('workspace-project-/workspace/lab')),
      );
      await tester.pumpAndSettle();

      expect(createdControllers, hasLength(2));
      expect(createdControllers.first.loadCount, 1);
      expect(createdControllers.last.directory, '/workspace/lab');
      expect(createdControllers.last.loadCount, 1);
      expect(find.byType(WebParityWorkspaceScreen), findsOneWidget);
      expect(observer.lastRouteName, initialRouteName);
      expect(find.text('hello from lab'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('workspace-project-/workspace/demo')),
      );
      await tester.pumpAndSettle();

      expect(createdControllers, hasLength(2));
      expect(createdControllers.first.loadCount, 1);
      expect(createdControllers.last.loadCount, 1);
      expect(find.byType(WebParityWorkspaceScreen), findsOneWidget);
      expect(observer.lastRouteName, initialRouteName);
      expect(find.text('hello from one'), findsOneWidget);
    },
  );

  testWidgets(
    'switching to an uncached project keeps the shell mounted and loads project data in place',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final createdControllers = <_RecordingWorkspaceController>[];
      final labLoadCompleter = Completer<void>();
      final profile = ServerProfile(
        id: 'server',
        label: 'Mock',
        baseUrl: 'http://localhost:3000',
      );
      final appController = _StaticAppController(
        profile: profile,
        workspaceControllerFactory:
            ({required profile, required directory, initialSessionId}) {
              final controller = directory == '/workspace/lab'
                  ? _DelayedRecordingWorkspaceController(
                      profile: profile,
                      directory: directory,
                      initialSessionId: initialSessionId,
                      loadCompleter: labLoadCompleter,
                    )
                  : _RecordingWorkspaceController(
                      profile: profile,
                      directory: directory,
                      initialSessionId: initialSessionId,
                    );
              createdControllers.add(controller);
              return controller;
            },
      );
      addTearDown(appController.dispose);

      final navigatorKey = GlobalKey<NavigatorState>();
      final observer = _RecordingNavigatorObserver();

      await tester.pumpWidget(
        _WorkspaceRouteHarness(
          controller: appController,
          navigatorKey: navigatorKey,
          navigatorObservers: <NavigatorObserver>[observer],
          initialRoute: '/',
        ),
      );
      navigatorKey.currentState!.pushNamed(
        buildWorkspaceRoute('/workspace/demo', sessionId: 'ses_1'),
      );
      await tester.pumpAndSettle();

      final initialRouteName = observer.lastRouteName;
      expect(find.text('hello from one'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('workspace-project-/workspace/lab')),
      );
      await tester.pump();

      expect(createdControllers, hasLength(2));
      expect(observer.lastRouteName, initialRouteName);
      expect(find.byType(WebParityWorkspaceScreen), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey<String>('workspace-project-loading-/workspace/lab'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('workspace-sidebar-session-loading-state'),
        ),
        findsOneWidget,
      );
      expect(find.text('Lab'), findsAtLeastNWidgets(1));
      expect(find.text('hello from one'), findsNothing);

      labLoadCompleter.complete();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(observer.lastRouteName, initialRouteName);
      expect(find.text('hello from lab'), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey<String>('workspace-project-loading-/workspace/lab'),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'timeline stays pinned to bottom when streamed content extends the last message',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final createdControllers = <_StreamingWorkspaceController>[];
      final profile = ServerProfile(
        id: 'server',
        label: 'Mock',
        baseUrl: 'http://localhost:3000',
      );
      final appController = _StaticAppController(
        profile: profile,
        workspaceControllerFactory:
            ({required profile, required directory, initialSessionId}) {
              final controller = _StreamingWorkspaceController(
                profile: profile,
                directory: directory,
                initialSessionId: initialSessionId,
              );
              createdControllers.add(controller);
              return controller;
            },
      );
      addTearDown(appController.dispose);

      final navigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        _WorkspaceRouteHarness(
          controller: appController,
          navigatorKey: navigatorKey,
          initialRoute: '/',
        ),
      );
      navigatorKey.currentState!.pushNamed(
        buildWorkspaceRoute('/workspace/demo', sessionId: 'ses_1'),
      );
      await tester.pumpAndSettle();

      final controller = createdControllers.single;
      final listFinder = find.byKey(
        const PageStorageKey<String>('web-parity-message-timeline'),
      );
      final initialPosition = tester
          .widget<SingleChildScrollView>(listFinder)
          .controller!
          .position;
      final initialMaxExtent = initialPosition.maxScrollExtent;

      expect(initialMaxExtent, greaterThan(0));
      expect(initialPosition.pixels, closeTo(initialMaxExtent, 96));

      controller.extendLastAssistantMessage(
        '\n${List<String>.filled(120, 'streamed output line').join('\n')}',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      final updatedPosition = tester
          .widget<SingleChildScrollView>(listFinder)
          .controller!
          .position;
      expect(updatedPosition.maxScrollExtent, greaterThan(initialMaxExtent));
      expect(
        updatedPosition.pixels,
        closeTo(updatedPosition.maxScrollExtent, 96),
      );
    },
  );

  testWidgets(
    'timeline lands at the bottom when opening a long existing session',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final createdControllers = <_LongSessionWorkspaceController>[];
      final profile = ServerProfile(
        id: 'server',
        label: 'Mock',
        baseUrl: 'http://localhost:3000',
      );
      final appController = _StaticAppController(
        profile: profile,
        workspaceControllerFactory:
            ({required profile, required directory, initialSessionId}) {
              final controller = _LongSessionWorkspaceController(
                profile: profile,
                directory: directory,
                initialSessionId: initialSessionId,
              );
              createdControllers.add(controller);
              return controller;
            },
      );
      addTearDown(appController.dispose);

      final navigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        _WorkspaceRouteHarness(
          controller: appController,
          navigatorKey: navigatorKey,
          initialRoute: '/',
        ),
      );
      navigatorKey.currentState!.pushNamed(
        buildWorkspaceRoute('/workspace/demo', sessionId: 'ses_long'),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pumpAndSettle();

      final controller = createdControllers.single;
      expect(controller.selectedSessionId, 'ses_long');

      final listFinder = find.byKey(
        const PageStorageKey<String>('web-parity-message-timeline'),
      );
      final position = tester
          .widget<SingleChildScrollView>(listFinder)
          .controller!
          .position;

      expect(position.maxScrollExtent, greaterThan(0));
      expect(position.pixels, closeTo(position.maxScrollExtent, 96));
    },
  );

  testWidgets(
    'scrolling to the top loads older timeline messages without resetting the viewport',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final createdControllers = <_LongSessionWorkspaceController>[];
      final profile = ServerProfile(
        id: 'server',
        label: 'Mock',
        baseUrl: 'http://localhost:3000',
      );
      final appController = _StaticAppController(
        profile: profile,
        workspaceControllerFactory:
            ({required profile, required directory, initialSessionId}) {
              final controller = _LongSessionWorkspaceController(
                profile: profile,
                directory: directory,
                initialSessionId: initialSessionId,
              );
              createdControllers.add(controller);
              return controller;
            },
      );
      addTearDown(appController.dispose);

      final navigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        _WorkspaceRouteHarness(
          controller: appController,
          navigatorKey: navigatorKey,
          initialRoute: '/',
        ),
      );
      navigatorKey.currentState!.pushNamed(
        buildWorkspaceRoute('/workspace/demo', sessionId: 'ses_long'),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      expect(find.text('user long session message 0'), findsNothing);
      expect(
        find.textContaining('assistant long session message 119'),
        findsOneWidget,
      );
      expect(find.text('60 earlier messages'), findsOneWidget);

      final listFinder = find.byKey(
        const PageStorageKey<String>('web-parity-message-timeline'),
      );
      final scrollView = tester.widget<SingleChildScrollView>(listFinder);

      scrollView.controller!.jumpTo(0);
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('20 earlier messages'), findsOneWidget);
      expect(
        find.textContaining('user long session message 20'),
        findsOneWidget,
      );
      expect(find.text('user long session message 0'), findsNothing);
    },
  );
}

class _WorkspaceRouteHarness extends StatelessWidget {
  const _WorkspaceRouteHarness({
    required this.controller,
    required this.navigatorKey,
    required this.initialRoute,
    this.navigatorObservers = const <NavigatorObserver>[],
  });

  final WebParityAppController controller;
  final GlobalKey<NavigatorState> navigatorKey;
  final String initialRoute;
  final List<NavigatorObserver> navigatorObservers;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      controller: controller,
      child: MaterialApp(
        navigatorKey: navigatorKey,
        navigatorObservers: navigatorObservers,
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

class _RecordingWorkspaceController extends WorkspaceController {
  _RecordingWorkspaceController({
    required super.profile,
    required super.directory,
    super.initialSessionId,
  }) : _sessions = List<SessionSummary>.from(_seedSessionsFor(directory));

  static const ProjectTarget _demoProject = ProjectTarget(
    directory: '/workspace/demo',
    label: 'Demo',
    source: 'server',
    vcs: 'git',
    branch: 'main',
  );
  static const ProjectTarget _labProject = ProjectTarget(
    directory: '/workspace/lab',
    label: 'Lab',
    source: 'server',
    vcs: 'git',
    branch: 'develop',
  );
  static const List<ProjectTarget> _availableProjects = <ProjectTarget>[
    _demoProject,
    _labProject,
  ];
  static final Map<String, SessionStatusSummary> _sessionStatuses =
      <String, SessionStatusSummary>{
        'ses_1': const SessionStatusSummary(type: 'idle'),
        'ses_2': const SessionStatusSummary(type: 'idle'),
        'ses_new': const SessionStatusSummary(type: 'idle'),
        'ses_lab_1': const SessionStatusSummary(type: 'idle'),
      };

  int loadCount = 0;
  int createEmptySessionCalls = 0;
  final List<String?> selectSessionCalls = <String?>[];

  bool _loading = true;
  String? _selectedSessionId;
  List<ChatMessage> _messages = const <ChatMessage>[];
  List<SessionSummary> _sessions;

  @override
  bool get loading => _loading;

  @override
  ProjectTarget? get project => switch (directory) {
    '/workspace/lab' => _labProject,
    _ => _demoProject,
  };

  @override
  List<ProjectTarget> get availableProjects => _availableProjects;

  @override
  List<SessionSummary> get sessions => _sessions;

  @override
  Map<String, SessionStatusSummary> get statuses => _sessionStatuses;

  @override
  String? get selectedSessionId => _selectedSessionId;

  @override
  SessionSummary? get selectedSession {
    final selectedSessionId = _selectedSessionId;
    if (selectedSessionId == null) {
      return null;
    }
    for (final session in _sessions) {
      if (session.id == selectedSessionId) {
        return session;
      }
    }
    return null;
  }

  @override
  SessionStatusSummary? get selectedStatus {
    final selectedSessionId = _selectedSessionId;
    if (selectedSessionId == null) {
      return null;
    }
    return _sessionStatuses[selectedSessionId];
  }

  @override
  List<ChatMessage> get messages => _messages;

  @override
  List<TodoItem> get todos => const <TodoItem>[];

  @override
  PendingRequestBundle get pendingRequests => const PendingRequestBundle(
    questions: <QuestionRequestSummary>[],
    permissions: <PermissionRequestSummary>[],
  );

  @override
  Future<void> load() async {
    loadCount += 1;
    _loading = false;
    _selectedSessionId = initialSessionId ?? _sessions.first.id;
    _messages = _messageListFor(_selectedSessionId);
    notifyListeners();
  }

  @override
  Future<void> selectSession(String? sessionId) async {
    selectSessionCalls.add(sessionId);
    _selectedSessionId = sessionId;
    _messages = _messageListFor(sessionId);
    notifyListeners();
  }

  @override
  Future<SessionSummary?> createEmptySession({String? title}) async {
    createEmptySessionCalls += 1;
    final created = SessionSummary(
      id: directory == '/workspace/lab' ? 'ses_lab_new' : 'ses_new',
      directory: directory,
      title: 'Fresh session',
      version: '1',
      updatedAt: DateTime.fromMillisecondsSinceEpoch(1710000003000),
    );
    _sessions = <SessionSummary>[created, ..._sessions];
    _selectedSessionId = created.id;
    _messages = const <ChatMessage>[];
    notifyListeners();
    return created;
  }

  List<ChatMessage> _messageListFor(String? sessionId) {
    if (sessionId == null) {
      return const <ChatMessage>[];
    }
    final text = switch ((directory, sessionId)) {
      ('/workspace/demo', 'ses_2') => 'hello from two',
      ('/workspace/lab', _) => 'hello from lab',
      _ => 'hello from one',
    };
    return <ChatMessage>[
      ChatMessage(
        info: ChatMessageInfo(
          id: 'msg_$sessionId',
          role: 'assistant',
          sessionId: sessionId,
        ),
        parts: <ChatPart>[
          ChatPart(id: 'part_$sessionId', type: 'text', text: text),
        ],
      ),
    ];
  }

  static List<SessionSummary> _seedSessionsFor(String directory) {
    return switch (directory) {
      '/workspace/lab' => <SessionSummary>[
        SessionSummary(
          id: 'ses_lab_1',
          directory: '/workspace/lab',
          title: 'Lab Session',
          version: '1',
          updatedAt: DateTime.fromMillisecondsSinceEpoch(1710000004000),
        ),
      ],
      _ => <SessionSummary>[
        SessionSummary(
          id: 'ses_1',
          directory: '/workspace/demo',
          title: 'Session One',
          version: '1',
          updatedAt: DateTime.fromMillisecondsSinceEpoch(1710000001000),
        ),
        SessionSummary(
          id: 'ses_2',
          directory: '/workspace/demo',
          title: 'Session Two',
          version: '1',
          updatedAt: DateTime.fromMillisecondsSinceEpoch(1710000002000),
        ),
      ],
    };
  }
}

class _DelayedRecordingWorkspaceController
    extends _RecordingWorkspaceController {
  _DelayedRecordingWorkspaceController({
    required super.profile,
    required super.directory,
    required this.loadCompleter,
    super.initialSessionId,
  });

  final Completer<void> loadCompleter;

  @override
  Future<void> load() async {
    loadCount += 1;
    await loadCompleter.future;
    _loading = false;
    _selectedSessionId = initialSessionId ?? _sessions.first.id;
    _messages = _messageListFor(_selectedSessionId);
    notifyListeners();
  }
}

class _StreamingWorkspaceController extends WorkspaceController {
  _StreamingWorkspaceController({
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

  bool _loading = true;
  String? _selectedSessionId;
  late List<ChatMessage> _messages = _buildMessages();

  @override
  bool get loading => _loading;

  @override
  ProjectTarget? get project => _projectTarget;

  @override
  List<ProjectTarget> get availableProjects => const <ProjectTarget>[
    _projectTarget,
  ];

  @override
  List<SessionSummary> get sessions => <SessionSummary>[
    SessionSummary(
      id: 'ses_1',
      directory: '/workspace/demo',
      title: 'Streaming session',
      version: '1',
      updatedAt: DateTime.fromMillisecondsSinceEpoch(1710000001000),
    ),
  ];

  @override
  String? get selectedSessionId => _selectedSessionId;

  @override
  SessionSummary? get selectedSession => sessions.first;

  @override
  List<ChatMessage> get messages => _messages;

  @override
  Future<void> load() async {
    _loading = false;
    _selectedSessionId = initialSessionId ?? 'ses_1';
    notifyListeners();
  }

  void extendLastAssistantMessage(String extra) {
    final next = List<ChatMessage>.from(_messages);
    final last = next.removeLast();
    final updatedParts = List<ChatPart>.from(last.parts);
    final lastPart = updatedParts.removeLast();
    updatedParts.add(lastPart.copyWith(text: '${lastPart.text ?? ''}$extra'));
    next.add(last.copyWith(parts: updatedParts));
    _messages = next;
    notifyListeners();
  }

  List<ChatMessage> _buildMessages() {
    return List<ChatMessage>.generate(28, (index) {
      final role = index.isEven ? 'user' : 'assistant';
      final text = List<String>.filled(
        8,
        '$role message $index with enough content to wrap across lines.',
      ).join(' ');
      return ChatMessage(
        info: ChatMessageInfo(id: 'msg_$index', role: role, sessionId: 'ses_1'),
        parts: <ChatPart>[
          ChatPart(id: 'part_$index', type: 'text', text: text),
        ],
      );
    });
  }
}

class _LongSessionWorkspaceController extends WorkspaceController {
  _LongSessionWorkspaceController({
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

  bool _loading = true;
  String? _selectedSessionId;
  List<ChatMessage> _messages = const <ChatMessage>[];

  @override
  bool get loading => _loading;

  @override
  ProjectTarget? get project => _projectTarget;

  @override
  List<ProjectTarget> get availableProjects => const <ProjectTarget>[
    _projectTarget,
  ];

  @override
  List<SessionSummary> get sessions => <SessionSummary>[
    SessionSummary(
      id: 'ses_long',
      directory: '/workspace/demo',
      title: 'Long session',
      version: '1',
      updatedAt: DateTime.fromMillisecondsSinceEpoch(1710000001000),
    ),
  ];

  @override
  String? get selectedSessionId => _selectedSessionId;

  @override
  SessionSummary? get selectedSession => sessions.first;

  @override
  List<ChatMessage> get messages => _messages;

  @override
  Future<void> load() async {
    _selectedSessionId = initialSessionId ?? 'ses_long';
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    _messages = List<ChatMessage>.generate(120, (index) {
      final role = index.isEven ? 'user' : 'assistant';
      final text = List<String>.filled(
        10,
        '$role long session message $index with enough content to wrap repeatedly across multiple lines.',
      ).join(' ');
      return ChatMessage(
        info: ChatMessageInfo(
          id: 'msg_long_$index',
          role: role,
          sessionId: 'ses_long',
        ),
        parts: <ChatPart>[
          ChatPart(id: 'part_long_$index', type: 'text', text: text),
        ],
      );
    });
    _loading = false;
    notifyListeners();
  }
}

class _RecordingNavigatorObserver extends NavigatorObserver {
  String? lastRouteName;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    lastRouteName = route.settings.name;
    super.didPush(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    lastRouteName = newRoute?.settings.name;
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
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
