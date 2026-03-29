import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:better_opencode_client/src/app/app_controller.dart';
import 'package:better_opencode_client/src/app/app_routes.dart';
import 'package:better_opencode_client/src/app/app_scope.dart';
import 'package:better_opencode_client/src/core/connection/connection_models.dart';
import 'package:better_opencode_client/src/core/spec/raw_json_document.dart';
import 'package:better_opencode_client/src/design_system/app_theme.dart';
import 'package:better_opencode_client/src/features/chat/chat_models.dart';
import 'package:better_opencode_client/src/features/projects/project_models.dart';
import 'package:better_opencode_client/src/features/settings/config_service.dart';
import 'package:better_opencode_client/src/features/terminal/pty_models.dart';
import 'package:better_opencode_client/src/features/terminal/pty_service.dart';
import 'package:better_opencode_client/src/features/web_parity/workspace_controller.dart';
import 'package:better_opencode_client/src/features/web_parity/workspace_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('context panel mirrors session metrics and raw messages', (
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
            return _ContextWorkspaceController(
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

    expect(find.text('Context Limit'), findsOneWidget);
    expect(find.text('1,050,000'), findsOneWidget);
    expect(find.text('Context Breakdown'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('context-breakdown-bar')),
      findsOneWidget,
    );
    expect(find.textContaining('Tool Calls'), findsWidgets);
    await tester.dragUntilVisible(
      find.text('System Prompt'),
      find.byKey(const PageStorageKey<String>('web-parity-context-panel')),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(find.text('System Prompt'), findsOneWidget);
    expect(find.text('OpenAI'), findsOneWidget);
    expect(find.text('51,945'), findsOneWidget);

    await tester.dragUntilVisible(
      find.text('Raw messages'),
      find.byKey(const PageStorageKey<String>('web-parity-context-panel')),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();

    expect(find.text('Raw messages'), findsOneWidget);
    expect(
      find.byKey(
        const PageStorageKey<String>(
          'context-raw-message-expansion-msg_assistant_1',
        ),
      ),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(
        const PageStorageKey<String>(
          'context-raw-message-expansion-msg_assistant_1',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final rawTile = tester.widget<Container>(
      find.byKey(
        const ValueKey<String>('context-raw-message-tile-msg_assistant_1'),
      ),
    );
    final rawTileDecoration = rawTile.decoration! as BoxDecoration;
    expect(rawTileDecoration.color, Colors.transparent);
    expect(
      find.byKey(
        const ValueKey<String>('context-raw-message-content-msg_assistant_1'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('"providerID"'), findsOneWidget);
    expect(find.textContaining('"openai"'), findsOneWidget);
    expect(find.textContaining('"parts"'), findsOneWidget);
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

class _ContextWorkspaceController extends WorkspaceController {
  _ContextWorkspaceController({
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
    title: '디스코드 봇 리포지토리 규칙 초기 설계',
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
      parts: <ChatPart>[
        const ChatPart(
          id: 'part_assistant_text',
          type: 'text',
          text: '정리했습니다.',
        ),
        ChatPart(
          id: 'part_assistant_tool',
          type: 'tool',
          metadata: const <String, Object?>{
            'state': <String, Object?>{
              'status': 'completed',
              'input': <String, Object?>{'query': 'git status'},
              'output': 'clean',
            },
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
  List<ProjectTarget> get availableProjects => <ProjectTarget>[_projectTarget];

  @override
  List<SessionSummary> get sessions => <SessionSummary>[_session];

  @override
  String? get selectedSessionId => _session.id;

  @override
  SessionSummary? get selectedSession => _session;

  @override
  List<ChatMessage> get messages => _messages;

  @override
  WorkspaceSideTab get sideTab => WorkspaceSideTab.context;

  @override
  ConfigSnapshot? get configSnapshot => _snapshot;

  @override
  String? get sessionSystemPrompt => 'You are OpenCode. Stay concise.';

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
