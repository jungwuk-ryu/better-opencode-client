import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:opencode_mobile_remote/src/app/app_controller.dart';
import 'package:opencode_mobile_remote/src/app/app_routes.dart';
import 'package:opencode_mobile_remote/src/app/app_scope.dart';
import 'package:opencode_mobile_remote/src/core/connection/connection_models.dart';
import 'package:opencode_mobile_remote/src/core/spec/raw_json_document.dart';
import 'package:opencode_mobile_remote/src/design_system/app_theme.dart';
import 'package:opencode_mobile_remote/src/features/chat/chat_models.dart';
import 'package:opencode_mobile_remote/src/features/projects/project_models.dart';
import 'package:opencode_mobile_remote/src/features/settings/config_service.dart';
import 'package:opencode_mobile_remote/src/features/terminal/pty_models.dart';
import 'package:opencode_mobile_remote/src/features/terminal/pty_service.dart';
import 'package:opencode_mobile_remote/src/features/web_parity/workspace_controller.dart';
import 'package:opencode_mobile_remote/src/features/web_parity/workspace_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'session header shows the title, busy state, and context usage ring',
    (tester) async {
      tester.view.physicalSize = const Size(1480, 960);
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
              return _HeaderWorkspaceController(
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
      await tester.pump(const Duration(milliseconds: 80));

      expect(
        find.byKey(const ValueKey<String>('session-header-title-ses_1')),
        findsOneWidget,
      );
      expect(find.text('Busy'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('session-header-context-ring-ses_1')),
        findsOneWidget,
      );
      expect(
        find.byTooltip('5% of context window used (51,945 / 1,050,000 tokens)'),
        findsOneWidget,
      );
    },
  );

  testWidgets('session header menu opens with the styled overflow panel', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1480, 960);
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
            return _HeaderWorkspaceController(
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
    await tester.pump(const Duration(milliseconds: 120));

    await tester.tap(
      find.byKey(const ValueKey<String>('session-header-overflow-menu-button')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    expect(
      find.byKey(const ValueKey<String>('session-header-overflow-menu-panel')),
      findsOneWidget,
    );
    expect(find.byType(BackdropFilter), findsWidgets);
    expect(find.text('Rename Session'), findsOneWidget);
    expect(find.text('Delete Session'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey<String>(
          'session-header-overflow-menu-item-shell-default',
        ),
      ),
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

class _HeaderWorkspaceController extends WorkspaceController {
  _HeaderWorkspaceController({
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
    title: '코드 작성과 아키텍처 계획 수립',
    version: '1',
    updatedAt: DateTime.fromMillisecondsSinceEpoch(1774454340000),
    createdAt: DateTime.fromMillisecondsSinceEpoch(1774453800000),
  );

  static final ConfigSnapshot _snapshot = ConfigSnapshot(
    config: RawJsonDocument(<String, Object?>{'model': 'openai/gpt-5.4'}),
    providerConfig: RawJsonDocument(<String, Object?>{
      'providers': <Map<String, Object?>>[
        <String, Object?>{
          'id': 'openai',
          'name': 'OpenAI',
          'models': <String, Object?>{
            'gpt-5.4': <String, Object?>{
              'id': 'gpt-5.4',
              'name': 'GPT-5.4',
              'limit': <String, Object?>{'context': 1050000},
            },
          },
        },
      ],
    }),
  );

  static final List<ChatMessage> _messages = <ChatMessage>[
    ChatMessage(
      info: ChatMessageInfo(
        id: 'msg_user_1',
        role: 'user',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1774453800000),
        systemPrompt: 'You are OpenCode. Stay concise.',
      ),
      parts: const <ChatPart>[
        ChatPart(id: 'part_user_1', type: 'text', text: '프로젝트 규칙 정리'),
      ],
    ),
    ChatMessage(
      info: ChatMessageInfo(
        id: 'msg_assistant_1',
        role: 'assistant',
        providerId: 'openai',
        modelId: 'gpt-5.4',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1774454340000),
        cost: 0,
        inputTokens: 311,
        outputTokens: 373,
        reasoningTokens: 61,
        cacheReadTokens: 51200,
        cacheWriteTokens: 0,
      ),
      parts: const <ChatPart>[
        ChatPart(id: 'part_assistant_text', type: 'text', text: '정리했습니다.'),
      ],
    ),
  ];

  bool _loading = true;

  @override
  bool get loading => _loading;

  @override
  ProjectTarget? get project => _projectTarget;

  @override
  List<ProjectTarget> get availableProjects => <ProjectTarget>[_projectTarget];

  @override
  List<SessionSummary> get sessions => <SessionSummary>[_session];

  @override
  String? get selectedSessionId => _session.id;

  @override
  SessionSummary? get selectedSession => _session;

  @override
  SessionStatusSummary? get selectedStatus =>
      const SessionStatusSummary(type: 'busy');

  @override
  List<ChatMessage> get messages => _messages;

  @override
  ConfigSnapshot? get configSnapshot => _snapshot;

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
