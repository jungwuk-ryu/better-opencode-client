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

  testWidgets('tool and reasoning rows stay collapsed until tapped', (
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
      workspaceControllerFactory:
          ({required profile, required directory, initialSessionId}) {
            return _TimelineWorkspaceController(
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
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Thinking Reviewing git workflow'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Shell Shows staged and unstaged diff'),
      findsOneWidget,
    );
    expect(
      find.text('Detailed internal reasoning stays hidden.'),
      findsNothing,
    );
    expect(find.textContaining(r'git diff --staged && git diff'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey<String>('timeline-activity-part_reasoning')),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Detailed internal reasoning stays hidden.'),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('timeline-activity-part_tool')),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining(r'git diff --staged && git diff'),
      findsOneWidget,
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
    required WorkspaceControllerFactory workspaceControllerFactory,
  }) : super(workspaceControllerFactory: workspaceControllerFactory);

  final ServerProfile profile;

  @override
  ServerProfile? get selectedProfile => profile;
}

class _TimelineWorkspaceController extends WorkspaceController {
  _TimelineWorkspaceController({
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

  static final SessionSummary _session = SessionSummary(
    id: 'ses_1',
    directory: '/workspace/demo',
    title: 'Investigate branch cleanup',
    version: '1',
    updatedAt: DateTime.fromMillisecondsSinceEpoch(1710000001000),
  );

  static final List<ChatMessage> _messages = <ChatMessage>[
    ChatMessage(
      info: const ChatMessageInfo(
        id: 'msg_user_1',
        role: 'user',
        sessionId: 'ses_1',
      ),
      parts: const <ChatPart>[
        ChatPart(
          id: 'part_user_1',
          type: 'text',
          text: 'Please verify the current git workflow.',
        ),
      ],
    ),
    ChatMessage(
      info: const ChatMessageInfo(
        id: 'msg_assistant_1',
        role: 'assistant',
        sessionId: 'ses_1',
      ),
      parts: <ChatPart>[
        const ChatPart(
          id: 'part_reasoning',
          type: 'reasoning',
          text:
              '## Reviewing git workflow\n\nDetailed internal reasoning stays hidden.',
        ),
        ChatPart(
          id: 'part_tool',
          type: 'tool',
          tool: 'bash',
          metadata: const <String, Object?>{
            'state': <String, Object?>{
              'title': 'Shows staged and unstaged diff',
            },
            'command': r'git diff --staged && git diff',
          },
        ),
      ],
    ),
  ];

  bool _loading = true;

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
  List<ChatMessage> get messages => _messages;

  @override
  Future<void> load() async {
    _loading = false;
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
