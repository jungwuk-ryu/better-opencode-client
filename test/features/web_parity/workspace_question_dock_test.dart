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
import 'package:opencode_mobile_remote/src/features/web_parity/workspace_controller.dart';
import 'package:opencode_mobile_remote/src/features/web_parity/workspace_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('question dock replaces composer and submits answers', (
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
    final workspaceController = _QuestionDockWorkspaceController(
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
          sessionId: 'ses_root',
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('1 of 1 questions'), findsOneWidget);
    expect(find.text('Which execution path should I use?'), findsOneWidget);
    expect(find.text('Ask anything...'), findsNothing);

    await tester.tap(find.text('Cron/Container'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(
      find.byKey(const ValueKey<String>('question-dock-submit')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(workspaceController.submittedAnswers, <List<String>>[
      <String>['Cron/Container'],
    ]);
    expect(find.text('Ask anything...'), findsOneWidget);
    expect(find.text('Which execution path should I use?'), findsNothing);
  });

  testWidgets('question dock accepts a custom answer from Other', (
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
    final workspaceController = _QuestionDockWorkspaceController(
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
          sessionId: 'ses_root',
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    await tester.tap(find.text('Other'));
    await tester.pump();

    await tester.enterText(
      find.byKey(const ValueKey<String>('question-dock-custom-input-0')),
      'Run it as a one-off worker',
    );
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey<String>('question-dock-submit')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(workspaceController.submittedAnswers, <List<String>>[
      <String>['Run it as a one-off worker'],
    ]);
  });

  testWidgets('question dock hides Other when custom answers are disabled', (
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
    final workspaceController = _QuestionDockWorkspaceController(
      profile: profile,
      directory: '/workspace/demo',
      customAllowed: false,
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
          sessionId: 'ses_root',
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Other'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('question-dock-custom-input-0')),
      findsNothing,
    );
  });

  testWidgets('permission dock replaces composer and submits responses', (
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
    final workspaceController = _PermissionDockWorkspaceController(
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
          sessionId: 'ses_root',
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Permission Request'), findsOneWidget);
    expect(find.text('bash'), findsOneWidget);
    expect(find.text('npm test'), findsOneWidget);
    expect(find.text('Ask anything...'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey<String>('permission-dock-allow-always')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      workspaceController.permissionReplies,
      <({String requestId, String reply})>[
        (requestId: 'per_1', reply: 'always'),
      ],
    );
    expect(find.text('Ask anything...'), findsOneWidget);
    expect(find.text('Permission Request'), findsNothing);
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

class _QuestionDockWorkspaceController extends WorkspaceController {
  _QuestionDockWorkspaceController({
    required super.profile,
    required super.directory,
    this.customAllowed = true,
  }) : _request = QuestionRequestSummary(
         id: 'req_1',
         sessionId: 'ses_child',
         questions: <QuestionPromptSummary>[
           QuestionPromptSummary(
             question: 'Which execution path should I use?',
             header: 'Execution',
             multiple: false,
             custom: customAllowed,
             options: <QuestionOptionSummary>[
               const QuestionOptionSummary(
                 label: 'Cron/Container',
                 description: 'Simple once-per-day deployment.',
               ),
             ],
           ),
         ],
       );

  final bool customAllowed;

  static const ProjectTarget _projectTarget = ProjectTarget(
    directory: '/workspace/demo',
    label: 'Demo',
    source: 'server',
    vcs: 'git',
    branch: 'main',
  );

  static final SessionSummary _rootSession = SessionSummary(
    id: 'ses_root',
    directory: '/workspace/demo',
    title: 'Design initial architecture',
    version: '1',
    updatedAt: DateTime.fromMillisecondsSinceEpoch(1710000001000),
  );

  static final SessionSummary _childSession = SessionSummary(
    id: 'ses_child',
    directory: '/workspace/demo',
    title: 'Sub-agent question',
    version: '1',
    updatedAt: DateTime.fromMillisecondsSinceEpoch(1710000002000),
    parentId: 'ses_root',
  );

  static final List<ChatMessage> _messages = <ChatMessage>[
    ChatMessage(
      info: const ChatMessageInfo(
        id: 'msg_assistant_1',
        role: 'assistant',
        sessionId: 'ses_root',
      ),
      parts: const <ChatPart>[
        ChatPart(
          id: 'part_reasoning',
          type: 'reasoning',
          text: '## Planning\n\nInvestigating the right execution path.',
        ),
        ChatPart(
          id: 'part_question_pending',
          type: 'tool',
          tool: 'question',
          metadata: <String, Object?>{
            'state': <String, Object?>{
              'status': 'pending',
              'input': <String, Object?>{
                'questions': <Object?>[
                  <String, Object?>{
                    'question': 'Which execution path should I use?',
                    'header': 'Execution',
                    'multiple': false,
                    'options': <Object?>[
                      <String, Object?>{
                        'label': 'Cron/Container',
                        'description': 'Simple once-per-day deployment.',
                      },
                    ],
                  },
                ],
              },
            },
          },
        ),
      ],
    ),
  ];

  bool _loading = true;
  QuestionRequestSummary? _request;
  List<List<String>>? submittedAnswers;

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
    _rootSession,
    _childSession,
  ];

  @override
  List<SessionSummary> get visibleSessions => <SessionSummary>[_rootSession];

  @override
  String? get selectedSessionId => 'ses_root';

  @override
  SessionSummary? get selectedSession => _rootSession;

  @override
  List<ChatMessage> get messages => _messages;

  @override
  PendingRequestBundle get pendingRequests => PendingRequestBundle(
    questions: _request == null
        ? const <QuestionRequestSummary>[]
        : <QuestionRequestSummary>[_request!],
    permissions: const <PermissionRequestSummary>[],
  );

  @override
  Future<void> load() async {
    _loading = false;
    notifyListeners();
  }

  @override
  Future<void> replyToQuestion(
    String requestId,
    List<List<String>> answers,
  ) async {
    submittedAnswers = answers;
    _request = null;
    notifyListeners();
  }

  @override
  Future<void> rejectQuestion(String requestId) async {
    _request = null;
    notifyListeners();
  }
}

class _PermissionDockWorkspaceController extends WorkspaceController {
  _PermissionDockWorkspaceController({
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

  static final SessionSummary _rootSession = SessionSummary(
    id: 'ses_root',
    directory: '/workspace/demo',
    title: 'Design initial architecture',
    version: '1',
    updatedAt: DateTime.fromMillisecondsSinceEpoch(1710000001000),
  );

  static final SessionSummary _childSession = SessionSummary(
    id: 'ses_child',
    directory: '/workspace/demo',
    title: 'Sub-agent permission',
    version: '1',
    updatedAt: DateTime.fromMillisecondsSinceEpoch(1710000002000),
    parentId: 'ses_root',
  );

  static final List<ChatMessage> _messages = <ChatMessage>[
    ChatMessage(
      info: const ChatMessageInfo(
        id: 'msg_assistant_permission',
        role: 'assistant',
        sessionId: 'ses_root',
      ),
      parts: const <ChatPart>[
        ChatPart(
          id: 'part_permission_pending',
          type: 'tool',
          tool: 'permission',
          metadata: <String, Object?>{
            'state': <String, Object?>{
              'status': 'pending',
              'input': <String, Object?>{
                'permission': 'bash',
                'patterns': <Object?>['npm test'],
              },
            },
          },
        ),
      ],
    ),
  ];

  bool _loading = true;
  PermissionRequestSummary? _request = const PermissionRequestSummary(
    id: 'per_1',
    sessionId: 'ses_child',
    permission: 'bash',
    patterns: <String>['npm test'],
  );
  final List<({String requestId, String reply})> permissionReplies =
      <({String requestId, String reply})>[];

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
    _rootSession,
    _childSession,
  ];

  @override
  List<SessionSummary> get visibleSessions => <SessionSummary>[_rootSession];

  @override
  String? get selectedSessionId => 'ses_root';

  @override
  SessionSummary? get selectedSession => _rootSession;

  @override
  List<ChatMessage> get messages => _messages;

  @override
  PendingRequestBundle get pendingRequests => PendingRequestBundle(
    questions: const <QuestionRequestSummary>[],
    permissions: _request == null
        ? const <PermissionRequestSummary>[]
        : <PermissionRequestSummary>[_request!],
  );

  @override
  Future<void> load() async {
    _loading = false;
    notifyListeners();
  }

  @override
  Future<void> replyToPermission(String requestId, String reply) async {
    permissionReplies.add((requestId: requestId, reply: reply));
    _request = null;
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
