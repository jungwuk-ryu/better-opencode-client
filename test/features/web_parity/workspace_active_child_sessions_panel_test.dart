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
import 'package:better_opencode_client/src/features/web_parity/workspace_controller.dart';
import 'package:better_opencode_client/src/features/web_parity/workspace_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'compact active sub-session panel starts collapsed, opens, collapses, and hides when idle',
    (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final createdControllers = <_ActiveChildSessionsWorkspaceController>[];
      final profile = ServerProfile(
        id: 'server',
        label: 'Mock',
        baseUrl: 'http://localhost:3000',
      );
      final appController = _StaticAppController(
        profile: profile,
        workspaceControllerFactory:
            ({required profile, required directory, initialSessionId}) {
              final controller = _ActiveChildSessionsWorkspaceController(
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
          initialRoute: buildWorkspaceRoute(
            '/workspace/demo',
            sessionId: 'ses_root',
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final controller = createdControllers.single;

      expect(
        find.byKey(const ValueKey<String>('active-subsessions-panel')),
        findsOneWidget,
      );
      expect(find.text('Sub-agents Running'), findsOneWidget);
      expect(find.text('2 running'), findsOneWidget);
      expect(find.text('Bootstrap repo tooling'), findsNothing);
      expect(find.text('Review release checklist'), findsNothing);
      expect(find.text('Running bootstrap command'), findsNothing);
      expect(find.text('Task: Compare release checklist'), findsNothing);
      expect(find.text('Idle child session'), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey<String>('active-subsessions-toggle-button')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('Bootstrap repo tooling'), findsOneWidget);
      expect(find.text('Review release checklist'), findsOneWidget);
      expect(find.text('Running bootstrap command'), findsOneWidget);
      expect(find.text('Task: Compare release checklist'), findsOneWidget);
      expect(find.text('Idle child session'), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey<String>('active-subsessions-toggle-button')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(
        find.byKey(
          const ValueKey<String>('active-subsession-chip-ses_child_busy_1'),
        ),
        findsNothing,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('active-subsessions-toggle-button')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      await tester.tap(
        find.byKey(
          const ValueKey<String>('active-subsession-chip-ses_child_busy_1'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(controller.selectSessionCalls.last, 'ses_child_busy_1');
      expect(find.text('child one active'), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey<String>('workspace-back-to-main-session-button'),
        ),
        findsOneWidget,
      );

      controller.setStatus('ses_child_busy_1', 'idle');
      controller.setStatus('ses_child_busy_2', 'idle');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(
        find.byKey(const ValueKey<String>('active-subsessions-panel')),
        findsNothing,
      );
    },
  );
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

class _ActiveChildSessionsWorkspaceController extends WorkspaceController {
  _ActiveChildSessionsWorkspaceController({
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
      id: 'ses_root',
      directory: '/workspace/demo',
      title: 'Main Session',
      version: '1',
      updatedAt: DateTime.fromMillisecondsSinceEpoch(1710000001000),
    ),
    SessionSummary(
      id: 'ses_child_busy_1',
      directory: '/workspace/demo',
      title: 'Bootstrap repo tooling',
      version: '1',
      updatedAt: DateTime.fromMillisecondsSinceEpoch(1710000004000),
      parentId: 'ses_root',
    ),
    SessionSummary(
      id: 'ses_child_busy_2',
      directory: '/workspace/demo',
      title: 'Review release checklist',
      version: '1',
      updatedAt: DateTime.fromMillisecondsSinceEpoch(1710000003000),
      parentId: 'ses_root',
    ),
    SessionSummary(
      id: 'ses_child_idle',
      directory: '/workspace/demo',
      title: 'Idle child session',
      version: '1',
      updatedAt: DateTime.fromMillisecondsSinceEpoch(1710000002000),
      parentId: 'ses_root',
    ),
  ];

  bool _loading = true;
  String? _selectedSessionId;
  List<ChatMessage> _messages = const <ChatMessage>[];
  Map<String, SessionStatusSummary> _statuses = <String, SessionStatusSummary>{
    'ses_root': const SessionStatusSummary(type: 'idle'),
    'ses_child_busy_1': const SessionStatusSummary(type: 'busy'),
    'ses_child_busy_2': const SessionStatusSummary(type: 'busy'),
    'ses_child_idle': const SessionStatusSummary(type: 'idle'),
  };
  final Map<String, String> _previewBySessionId = <String, String>{
    'ses_child_busy_1': 'Running bootstrap command',
    'ses_child_busy_2': 'Task: Compare release checklist',
  };

  final List<String?> selectSessionCalls = <String?>[];

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
  Map<String, SessionStatusSummary> get statuses => _statuses;

  @override
  Map<String, String> get activeChildSessionPreviewById => _previewBySessionId;

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
    return _statuses[selectedSessionId];
  }

  @override
  List<ChatMessage> get messages => _messages;

  @override
  Future<void> load() async {
    _loading = false;
    _selectedSessionId = initialSessionId ?? 'ses_root';
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

  void setStatus(String sessionId, String status) {
    _statuses = <String, SessionStatusSummary>{
      ..._statuses,
      sessionId: SessionStatusSummary(type: status),
    };
    notifyListeners();
  }

  List<ChatMessage> _messageListFor(String? sessionId) {
    final text = switch (sessionId) {
      'ses_child_busy_1' => 'child one active',
      'ses_child_busy_2' => 'child two active',
      'ses_child_idle' => 'child idle',
      _ => 'main session active',
    };
    return <ChatMessage>[
      ChatMessage(
        info: ChatMessageInfo(
          id: 'msg_${sessionId ?? 'root'}',
          role: 'assistant',
          sessionId: sessionId,
        ),
        parts: <ChatPart>[
          ChatPart(id: 'part_${sessionId ?? 'root'}', type: 'text', text: text),
        ],
      ),
    ];
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
