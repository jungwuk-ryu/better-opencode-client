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

  testWidgets('reasoning stays collapsed while shell output is shown live', (
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
      initialShellToolPartsExpanded: true,
      initialTimelineProgressDetailsVisible: false,
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      find.textContaining('Thinking Reviewing git workflow'),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('timeline-activity-shimmer-part_reasoning'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('timeline-shell-shimmer-part_tool')),
      findsOneWidget,
    );
    expect(find.text('Which environment should I target?'), findsNothing);
    expect(
      find.text('Detailed internal reasoning stays hidden.'),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('timeline-activity-part_step_start')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('timeline-activity-part_step_finish')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('timeline-activity-part_todo')),
      findsNothing,
    );
    expect(find.text('Verify bot runtime module'), findsNothing);
    expect(
      find.textContaining(r'$ git diff --staged && git diff'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('timeline-shell-copy-part_tool')),
      findsOneWidget,
    );
    expect(find.textContaining('release-checklist'), findsOneWidget);
    expect(find.text('Explored 4 reads'), findsOneWidget);
    expect(find.textContaining('daily-job.spec.ts'), findsNothing);
    expect(
      tester
          .getTopLeft(
            find.byKey(
              const ValueKey<String>('timeline-activity-part_reasoning'),
            ),
          )
          .dy,
      greaterThan(
        tester
            .getTopLeft(
              find.byKey(
                const ValueKey<String>('timeline-compaction-part_compaction'),
              ),
            )
            .dy,
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('timeline-activity-part_reasoning')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      find.text('Detailed internal reasoning stays hidden.'),
      findsOneWidget,
    );
  });

  testWidgets('read tool calls are grouped into an explored summary', (
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
      initialShellToolPartsExpanded: true,
      initialTimelineProgressDetailsVisible: false,
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Explored 4 reads'), findsOneWidget);
    expect(find.textContaining('daily-job.spec.ts'), findsNothing);

    await tester.tap(
      find.byKey(
        const ValueKey<String>('timeline-explored-reads-header-part_read_1'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.textContaining('daily-job.spec.ts  offset=261'), findsOneWidget);
    expect(
      find.textContaining('runtime-state.spec.ts  offset=1  limit=220'),
      findsOneWidget,
    );
    expect(find.textContaining('bot-once.ts  offset=261  limit=80'), findsOneWidget);
  });

  testWidgets('shell output can be collapsed from the workspace setting', (
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
      initialShellToolPartsExpanded: true,
      initialTimelineProgressDetailsVisible: false,
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      find.textContaining(r'$ git diff --staged && git diff'),
      findsOneWidget,
    );

    await appController.setShellToolPartsExpanded(false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      find.textContaining(r'$ git diff --staged && git diff'),
      findsNothing,
    );
  });

  testWidgets('compaction renders as a divider instead of an activity card', (
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
      initialShellToolPartsExpanded: true,
      initialTimelineProgressDetailsVisible: false,
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      find.byKey(const ValueKey<String>('timeline-compaction-part_compaction')),
      findsOneWidget,
    );
    expect(find.text('Session compacted'), findsOneWidget);
    expect(find.text('Goal'), findsOneWidget);
    expect(find.textContaining('id: prt_compaction_1'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('timeline-activity-part_compaction')),
      findsNothing,
    );
  });

  testWidgets(
    'step and to-do details stay hidden by default and can be shown from settings',
    (tester) async {
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
        initialShellToolPartsExpanded: true,
        initialTimelineProgressDetailsVisible: false,
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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(
        find.byKey(const ValueKey<String>('timeline-activity-part_step_start')),
        findsNothing,
      );
      expect(
        find.byKey(
          const ValueKey<String>('timeline-activity-part_step_finish'),
        ),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('timeline-activity-part_todo')),
        findsNothing,
      );

      await appController.setTimelineProgressDetailsVisible(true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(
        find.byKey(const ValueKey<String>('timeline-activity-part_step_start')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('timeline-activity-part_step_finish'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('timeline-activity-part_todo')),
        findsOneWidget,
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
    required bool initialShellToolPartsExpanded,
    required bool initialTimelineProgressDetailsVisible,
    required WorkspaceControllerFactory workspaceControllerFactory,
  }) : _shellToolPartsExpanded = initialShellToolPartsExpanded,
       _timelineProgressDetailsVisible = initialTimelineProgressDetailsVisible,
       super(workspaceControllerFactory: workspaceControllerFactory);

  final ServerProfile profile;
  bool _shellToolPartsExpanded;
  bool _timelineProgressDetailsVisible;

  @override
  ServerProfile? get selectedProfile => profile;

  @override
  bool get shellToolPartsExpanded => _shellToolPartsExpanded;

  @override
  bool get timelineProgressDetailsVisible => _timelineProgressDetailsVisible;

  @override
  Future<void> setShellToolPartsExpanded(bool value) async {
    _shellToolPartsExpanded = value;
    notifyListeners();
  }

  @override
  Future<void> setTimelineProgressDetailsVisible(bool value) async {
    _timelineProgressDetailsVisible = value;
    notifyListeners();
  }
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
          id: 'part_read_1',
          type: 'tool',
          tool: 'read',
          metadata: <String, Object?>{
            'state': <String, Object?>{
              'status': 'completed',
              'input': <String, Object?>{
                'filePath': 'test/unit/job/daily-job.spec.ts',
                'offset': 261,
                'limit': 260,
              },
            },
          },
        ),
        const ChatPart(
          id: 'part_read_2',
          type: 'tool',
          tool: 'read',
          metadata: <String, Object?>{
            'state': <String, Object?>{
              'status': 'completed',
              'input': <String, Object?>{
                'filePath': 'test/unit/shared/runtime-state.spec.ts',
                'offset': 1,
                'limit': 220,
              },
            },
          },
        ),
        const ChatPart(
          id: 'part_read_3',
          type: 'tool',
          tool: 'read',
          metadata: <String, Object?>{
            'state': <String, Object?>{
              'status': 'completed',
              'input': <String, Object?>{
                'filePath': 'test/integration/bot-once.ts',
                'offset': 1,
                'limit': 260,
              },
            },
          },
        ),
        const ChatPart(
          id: 'part_read_4',
          type: 'tool',
          tool: 'read',
          metadata: <String, Object?>{
            'state': <String, Object?>{
              'status': 'completed',
              'input': <String, Object?>{
                'filePath': 'test/integration/bot-once.ts',
                'offset': 261,
                'limit': 80,
              },
            },
          },
        ),
        const ChatPart(
          id: 'part_reasoning',
          type: 'reasoning',
          text:
              '## Reviewing git workflow\n\nDetailed internal reasoning stays hidden.',
        ),
        const ChatPart(
          id: 'part_question_pending',
          type: 'tool',
          tool: 'question',
          metadata: <String, Object?>{
            'state': <String, Object?>{
              'status': 'pending',
              'input': <String, Object?>{
                'questions': <Object?>[
                  <String, Object?>{
                    'question': 'Which environment should I target?',
                    'header': 'Environment',
                    'multiple': false,
                    'options': <Object?>[
                      <String, Object?>{
                        'label': 'Production',
                        'description': 'Use the production runner.',
                      },
                    ],
                  },
                ],
              },
            },
          },
        ),
        ChatPart(
          id: 'part_tool',
          type: 'tool',
          tool: 'bash',
          metadata: const <String, Object?>{
            'state': <String, Object?>{
              'status': 'running',
              'title': 'Shows staged and unstaged diff',
              'input': <String, Object?>{
                'description': 'Verify bot runtime module',
                'command': 'git diff --staged && git diff',
              },
              'output': 'M README.md\n M lib/main.dart',
            },
          },
        ),
        const ChatPart(
          id: 'part_skill',
          type: 'tool',
          tool: 'skill',
          metadata: <String, Object?>{
            'state': <String, Object?>{
              'status': 'completed',
              'input': <String, Object?>{
                'name': 'release-checklist',
                'description': 'Review the release safety checklist',
              },
            },
          },
        ),
        const ChatPart(
          id: 'part_step_start',
          type: 'step-start',
          metadata: <String, Object?>{
            'title': 'Planning implementation steps',
            'description': 'Draft the next sequence of changes.',
          },
        ),
        const ChatPart(
          id: 'part_step_finish',
          type: 'step-finish',
          metadata: <String, Object?>{
            'reason': 'Completed milestone checkpoint',
            'message': 'Ready to move on to the next task.',
          },
        ),
        const ChatPart(
          id: 'part_todo',
          type: 'tool',
          tool: 'todowrite',
          metadata: <String, Object?>{
            'todos': <Object?>[
              <String, Object?>{
                'id': 'todo_1',
                'content': 'Ship the timeline update',
                'status': 'in_progress',
                'priority': 'high',
              },
            ],
          },
        ),
      ],
    ),
    const ChatMessage(
      info: ChatMessageInfo(
        id: 'msg_assistant_2',
        role: 'assistant',
        sessionId: 'ses_1',
      ),
      parts: <ChatPart>[
        ChatPart(
          id: 'part_compaction',
          type: 'compaction',
          metadata: <String, Object?>{
            'id': 'prt_compaction_1',
            'sessionID': 'ses_1',
            'messageID': 'msg_assistant_2',
            'type': 'compaction',
          },
        ),
        ChatPart(
          id: 'part_compaction_text',
          type: 'text',
          text:
              'Goal\n\nCreate and implement the planned architecture for the repo workflow.',
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
