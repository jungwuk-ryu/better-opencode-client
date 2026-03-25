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
import 'package:opencode_mobile_remote/src/features/terminal/pty_models.dart';
import 'package:opencode_mobile_remote/src/features/terminal/pty_service.dart';
import 'package:opencode_mobile_remote/src/features/web_parity/workspace_controller.dart';
import 'package:opencode_mobile_remote/src/features/web_parity/workspace_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'task activity link opens a child session and top bar returns to the main session',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final createdControllers = <_ChildSessionWorkspaceController>[];
      final profile = ServerProfile(
        id: 'server',
        label: 'Mock',
        baseUrl: 'http://localhost:3000',
      );
      final appController = _StaticAppController(
        profile: profile,
        workspaceControllerFactory:
            ({required profile, required directory, initialSessionId}) {
              final controller = _ChildSessionWorkspaceController(
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
      await tester.pumpAndSettle();

      final controller = createdControllers.single;
      expect(
        find.byKey(const ValueKey<String>('timeline-activity-link-part_task')),
        findsOneWidget,
      );
      expect(find.text('hello from main session'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('timeline-activity-link-part_task')),
      );
      await tester.pumpAndSettle();

      expect(controller.selectSessionCalls, isNotEmpty);
      expect(controller.selectSessionCalls.last, 'ses_child');
      expect(find.text('hello from child session'), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey<String>('workspace-back-to-main-session-link'),
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(
          const ValueKey<String>('workspace-back-to-main-session-link'),
        ),
      );
      await tester.pumpAndSettle();

      expect(controller.selectSessionCalls, isNotEmpty);
      expect(controller.selectSessionCalls.last, 'ses_root');
      expect(find.text('hello from main session'), findsOneWidget);
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

class _ChildSessionWorkspaceController extends WorkspaceController {
  _ChildSessionWorkspaceController({
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
      id: 'ses_child',
      directory: '/workspace/demo',
      title: 'Bootstrap repo tooling',
      version: '1',
      updatedAt: DateTime.fromMillisecondsSinceEpoch(1710000002000),
      parentId: 'ses_root',
    ),
  ];

  static final Map<String, SessionStatusSummary> _statuses =
      <String, SessionStatusSummary>{
        'ses_root': const SessionStatusSummary(type: 'idle'),
        'ses_child': const SessionStatusSummary(type: 'idle'),
      };

  bool _loading = true;
  String? _selectedSessionId;
  List<ChatMessage> _messages = const <ChatMessage>[];

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
  List<SessionSummary> get visibleSessions => _sessions
      .where((session) => session.parentId == null)
      .toList(growable: false);

  @override
  Map<String, SessionStatusSummary> get statuses => _statuses;

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

  List<ChatMessage> _messageListFor(String? sessionId) {
    if (sessionId == 'ses_child') {
      return <ChatMessage>[
        const ChatMessage(
          info: ChatMessageInfo(
            id: 'msg_child',
            role: 'assistant',
            sessionId: 'ses_child',
          ),
          parts: <ChatPart>[
            ChatPart(
              id: 'part_child',
              type: 'text',
              text: 'hello from child session',
            ),
          ],
        ),
      ];
    }
    return <ChatMessage>[
      const ChatMessage(
        info: ChatMessageInfo(
          id: 'msg_root_user',
          role: 'user',
          sessionId: 'ses_root',
        ),
        parts: <ChatPart>[
          ChatPart(
            id: 'part_root_user',
            type: 'text',
            text: 'please delegate bootstrap repo tooling',
          ),
        ],
      ),
      const ChatMessage(
        info: ChatMessageInfo(
          id: 'msg_root_assistant',
          role: 'assistant',
          sessionId: 'ses_root',
        ),
        parts: <ChatPart>[
          ChatPart(
            id: 'part_root_text',
            type: 'text',
            text: 'hello from main session',
          ),
          ChatPart(
            id: 'part_task',
            type: 'tool',
            tool: 'task',
            metadata: <String, Object?>{
              'state': <String, Object?>{
                'status': 'completed',
                'input': <String, Object?>{
                  'description': 'Bootstrap repo tooling',
                },
                'metadata': <String, Object?>{'sessionId': 'ses_child'},
              },
              'command': 'delegate bootstrap repo tooling',
            },
          ),
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
