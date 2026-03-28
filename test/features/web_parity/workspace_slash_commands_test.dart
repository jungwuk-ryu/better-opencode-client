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
import 'package:opencode_mobile_remote/src/features/chat/prompt_attachment_models.dart';
import 'package:opencode_mobile_remote/src/features/commands/command_service.dart';
import 'package:opencode_mobile_remote/src/features/projects/project_models.dart';
import 'package:opencode_mobile_remote/src/features/settings/agent_service.dart';
import 'package:opencode_mobile_remote/src/features/terminal/pty_models.dart';
import 'package:opencode_mobile_remote/src/features/terminal/pty_service.dart';
import 'package:opencode_mobile_remote/src/features/web_parity/workspace_controller.dart';
import 'package:opencode_mobile_remote/src/features/web_parity/workspace_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('slash query shows suggestions and inserts custom command', (
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
    final workspaceController = _SlashWorkspaceController(
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
          sessionId: 'ses_1',
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    await tester.enterText(
      find.byKey(const ValueKey<String>('composer-text-field')),
      '/s',
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('composer-slash-popover')),
      findsOneWidget,
    );
    expect(find.text('/share'), findsOneWidget);
    expect(find.text('/search-docs'), findsOneWidget);

    await tester.tap(
      find.byKey(
        const ValueKey<String>('composer-slash-option-custom.search-docs'),
      ),
    );
    await tester.pump();

    final field = tester.widget<TextField>(
      find.byKey(const ValueKey<String>('composer-text-field')),
    );
    expect(field.controller?.text, '/search-docs ');
  });

  testWidgets('submitting an exact builtin slash command runs the action', (
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
    final workspaceController = _SlashWorkspaceController(
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
          sessionId: 'ses_1',
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    await tester.enterText(
      find.byKey(const ValueKey<String>('composer-text-field')),
      '/new',
    );
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey<String>('composer-submit-button')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(workspaceController.createEmptySessionCalls, 1);
    expect(workspaceController.submitPromptCalls, 0);
    expect(find.text('Fresh session'), findsAtLeastNWidgets(1));
  });

  testWidgets(
    'builtin side-tab slash commands reopen the side panel on desktop layouts',
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
      final workspaceController = _SlashWorkspaceController(
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
            sessionId: 'ses_1',
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final sidePanelReveal = find.byKey(
        const ValueKey<String>('workspace-desktop-side-panel-reveal'),
      );

      await tester.tap(
        find.byKey(
          const ValueKey<String>('workspace-toggle-side-panel-button'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 260));

      expect(tester.getSize(sidePanelReveal).width, closeTo(0, 0.1));

      await tester.enterText(
        find.byKey(const ValueKey<String>('composer-text-field')),
        '/context',
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey<String>('composer-submit-button')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 260));

      expect(workspaceController.sideTab, WorkspaceSideTab.context);
      expect(tester.getSize(sidePanelReveal).width, greaterThan(300));
    },
  );

  testWidgets(
    'prompt clears immediately, shows an interrupt button, and ignores duplicate taps',
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
      final workspaceController = _DelayedSubmitWorkspaceController(
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
            sessionId: 'ses_1',
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final fieldFinder = find.byKey(
        const ValueKey<String>('composer-text-field'),
      );
      final buttonFinder = find.byKey(
        const ValueKey<String>('composer-submit-button'),
      );

      await tester.enterText(fieldFinder, 'Ship the fix');
      await tester.pump();

      await tester.tap(buttonFinder);
      await tester.tap(buttonFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(workspaceController.submitPromptCalls, 1);
      expect(tester.widget<TextField>(fieldFinder).controller?.text, isEmpty);
      expect(
        find.descendant(
          of: buttonFinder,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: buttonFinder,
          matching: find.byIcon(Icons.stop_rounded),
        ),
        findsOneWidget,
      );

      workspaceController.completeSubmit();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(
        find.descendant(
          of: buttonFinder,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsNothing,
      );
      expect(tester.widget<TextField>(fieldFinder).controller?.text, isEmpty);
    },
  );

  testWidgets(
    'late restored draft updates are discarded after submit without blocking new input',
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
      final workspaceController = _DelayedSubmitWorkspaceController(
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
            sessionId: 'ses_1',
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final fieldFinder = find.byKey(
        const ValueKey<String>('composer-text-field'),
      );
      final buttonFinder = find.byKey(
        const ValueKey<String>('composer-submit-button'),
      );

      await tester.tap(fieldFinder);
      await tester.pump();

      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '안녕하세요',
          selection: TextSelection.collapsed(offset: 5),
          composing: TextRange(start: 0, end: 5),
        ),
      );
      await tester.pump();

      await tester.tap(buttonFinder);
      await tester.pump();

      expect(workspaceController.submitPromptCalls, 1);
      expect(tester.widget<TextField>(fieldFinder).controller?.text, isEmpty);

      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '안녕하세요',
          selection: TextSelection.collapsed(offset: 5),
        ),
      );
      await tester.pump();

      expect(tester.widget<TextField>(fieldFinder).controller?.text, isEmpty);

      await tester.tap(fieldFinder);
      await tester.pump();
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '다음 질문',
          selection: TextSelection.collapsed(offset: 5),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      expect(tester.widget<TextField>(fieldFinder).controller?.text, '다음 질문');
    },
  );

  testWidgets(
    'busy sessions queue by default and honor steer mode when configured',
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
      final workspaceController = _QueuedWorkspaceController(
        profile: profile,
        directory: '/workspace/demo',
      );
      final appController = _StaticAppController(
        profile: profile,
        workspaceController: workspaceController,
        busyFollowupModeValue: WorkspaceFollowupMode.queue,
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

      final fieldFinder = find.byKey(
        const ValueKey<String>('composer-text-field'),
      );
      final buttonFinder = find.byKey(
        const ValueKey<String>('composer-submit-button'),
      );

      await tester.enterText(fieldFinder, 'Queue this follow-up');
      await tester.pump();
      await tester.tap(buttonFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(workspaceController.submissions.length, 1);
      expect(
        workspaceController.submissions.single.mode,
        WorkspacePromptDispatchMode.queue,
      );

      await tester.pump(const Duration(seconds: 2));
      await appController.setBusyFollowupMode(WorkspaceFollowupMode.steer);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      await workspaceController.submitPrompt(
        'Steer this follow-up',
        mode: WorkspacePromptDispatchMode.steer,
      );

      expect(workspaceController.submissions.length, 2);
      expect(
        workspaceController.submissions.last.mode,
        WorkspacePromptDispatchMode.steer,
      );
    },
  );

  testWidgets('queued follow-up rows can be edited and deleted', (
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
    final workspaceController = _QueuedWorkspaceController(
      profile: profile,
      directory: '/workspace/demo',
      queuedPrompts: <WorkspaceQueuedPrompt>[
        WorkspaceQueuedPrompt(
          id: 'queued_1',
          sessionId: 'ses_1',
          prompt: 'Queued follow-up draft',
          attachments: const <PromptAttachment>[
            PromptAttachment(
              id: 'att_1',
              filename: 'notes.txt',
              mime: 'text/plain',
              url: 'data:text/plain;base64,bm90ZXM=',
            ),
          ],
          createdAt: DateTime.fromMillisecondsSinceEpoch(1710000001000),
          agentName: 'Sisyphus',
          modelKey: 'openai/gpt-5.4',
          reasoning: 'high',
        ),
        WorkspaceQueuedPrompt(
          id: 'queued_2',
          sessionId: 'ses_1',
          prompt: 'Second queued draft',
          attachments: const <PromptAttachment>[],
          createdAt: DateTime.fromMillisecondsSinceEpoch(1710000002000),
        ),
      ],
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
          sessionId: 'ses_1',
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      find.byKey(const ValueKey<String>('composer-queued-dock')),
      findsOneWidget,
    );
    expect(find.text('Queued follow-up draft'), findsOneWidget);
    expect(find.text('Second queued draft'), findsOneWidget);

    await tester.tap(
      find.byKey(
        const ValueKey<String>('composer-queued-delete-button-queued_2'),
      ),
    );
    await tester.pump();

    expect(workspaceController.deletedQueuedPromptIds, <String>['queued_2']);
    expect(find.text('Second queued draft'), findsNothing);

    await tester.tap(
      find.byKey(
        const ValueKey<String>('composer-queued-edit-button-queued_1'),
      ),
    );
    await tester.pump();

    expect(workspaceController.editedQueuedPromptIds, <String>['queued_1']);
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey<String>('composer-text-field')),
          )
          .controller
          ?.text,
      'Queued follow-up draft',
    );
    expect(find.text('notes.txt'), findsOneWidget);
    expect(find.text('Queued follow-up draft'), findsOneWidget);
  });

  testWidgets('busy sessions show a stop button that interrupts the agent', (
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
    final workspaceController = _InterruptibleWorkspaceController(
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
          sessionId: 'ses_1',
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final buttonFinder = find.byKey(
      const ValueKey<String>('composer-submit-button'),
    );

    expect(
      find.descendant(
        of: buttonFinder,
        matching: find.byIcon(Icons.stop_rounded),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: buttonFinder,
        matching: find.byType(CircularProgressIndicator),
      ),
      findsNothing,
    );

    await tester.tap(buttonFinder);
    await tester.pump();

    expect(workspaceController.interruptCalls, 1);
    expect(workspaceController.submitPromptCalls, 0);
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
    this.busyFollowupModeValue = WorkspaceFollowupMode.queue,
  }) : super(
         workspaceControllerFactory:
             ({required profile, required directory, initialSessionId}) {
               return workspaceController;
             },
       );

  final ServerProfile profile;
  final WorkspaceController workspaceController;
  WorkspaceFollowupMode busyFollowupModeValue;

  @override
  ServerProfile? get selectedProfile => profile;

  @override
  WorkspaceFollowupMode get busyFollowupMode => busyFollowupModeValue;

  @override
  Future<void> setBusyFollowupMode(WorkspaceFollowupMode value) async {
    busyFollowupModeValue = value;
    notifyListeners();
  }
}

class _SlashWorkspaceController extends WorkspaceController {
  _SlashWorkspaceController({required super.profile, required super.directory});

  static const ProjectTarget _projectTarget = ProjectTarget(
    directory: '/workspace/demo',
    label: 'Demo',
    source: 'server',
    vcs: 'git',
    branch: 'main',
  );

  static const WorkspaceComposerModelOption _model =
      WorkspaceComposerModelOption(
        key: 'openai/gpt-5.4',
        providerId: 'openai',
        providerName: 'OpenAI',
        modelId: 'gpt-5.4',
        name: 'GPT-5.4',
        reasoningValues: <String>['medium', 'high'],
      );

  static const AgentDefinition _agent = AgentDefinition(
    name: 'Sisyphus',
    mode: 'all',
    description: 'Ultraworker',
  );

  bool _loading = true;
  SessionSummary _selectedSession = SessionSummary(
    id: 'ses_1',
    directory: '/workspace/demo',
    title: 'Existing session',
    version: '1',
    updatedAt: DateTime.fromMillisecondsSinceEpoch(1710000001000),
  );
  int createEmptySessionCalls = 0;
  int submitPromptCalls = 0;

  @override
  bool get loading => _loading;

  @override
  ProjectTarget? get project => _projectTarget;

  @override
  List<ProjectTarget> get availableProjects => const <ProjectTarget>[
    _projectTarget,
  ];

  @override
  List<SessionSummary> get sessions => <SessionSummary>[_selectedSession];

  @override
  List<SessionSummary> get visibleSessions => <SessionSummary>[
    _selectedSession,
  ];

  @override
  Map<String, SessionStatusSummary> get statuses =>
      <String, SessionStatusSummary>{
        _selectedSession.id: const SessionStatusSummary(type: 'idle'),
      };

  @override
  String? get selectedSessionId => _selectedSession.id;

  @override
  SessionSummary? get selectedSession => _selectedSession;

  @override
  List<ChatMessage> get messages => const <ChatMessage>[];

  @override
  List<AgentDefinition> get composerAgents => const <AgentDefinition>[_agent];

  @override
  List<WorkspaceComposerModelOption> get composerModels =>
      const <WorkspaceComposerModelOption>[_model];

  @override
  List<CommandDefinition> get composerCommands => const <CommandDefinition>[
    CommandDefinition(
      name: 'search-docs',
      description: 'Find documentation snippets',
      source: 'skill',
    ),
  ];

  @override
  String? get selectedAgentName => _agent.name;

  @override
  WorkspaceComposerModelOption? get selectedModel => _model;

  @override
  String? get selectedReasoning => 'medium';

  @override
  List<String> get availableReasoningValues => const <String>['medium', 'high'];

  @override
  Future<void> load() async {
    _loading = false;
    notifyListeners();
  }

  @override
  Future<String?> submitPrompt(
    String prompt, {
    List<PromptAttachment> attachments = const <PromptAttachment>[],
    WorkspacePromptDispatchMode? mode,
  }) async {
    submitPromptCalls += 1;
    return selectedSessionId;
  }

  @override
  Future<SessionSummary?> createEmptySession({String? title}) async {
    createEmptySessionCalls += 1;
    _selectedSession = SessionSummary(
      id: 'ses_new',
      directory: '/workspace/demo',
      title: 'Fresh session',
      version: '1',
      updatedAt: DateTime.fromMillisecondsSinceEpoch(1710000002000),
    );
    notifyListeners();
    return _selectedSession;
  }
}

class _DelayedSubmitWorkspaceController extends _SlashWorkspaceController {
  _DelayedSubmitWorkspaceController({
    required super.profile,
    required super.directory,
  });

  final Completer<String?> _submitCompleter = Completer<String?>();
  bool _submitting = false;

  @override
  bool get submittingPrompt => _submitting;

  @override
  bool get selectedSessionInterruptible => _submitting;

  @override
  Future<String?> submitPrompt(
    String prompt, {
    List<PromptAttachment> attachments = const <PromptAttachment>[],
    WorkspacePromptDispatchMode? mode,
  }) async {
    submitPromptCalls += 1;
    _submitting = true;
    notifyListeners();
    final result = await _submitCompleter.future;
    _submitting = false;
    notifyListeners();
    return result;
  }

  void completeSubmit() {
    if (!_submitCompleter.isCompleted) {
      _submitCompleter.complete(selectedSessionId);
    }
  }
}

class _InterruptibleWorkspaceController extends _SlashWorkspaceController {
  _InterruptibleWorkspaceController({
    required super.profile,
    required super.directory,
  });

  int interruptCalls = 0;

  @override
  SessionStatusSummary? get selectedStatus =>
      const SessionStatusSummary(type: 'busy');

  @override
  bool get selectedSessionInterruptible => true;

  @override
  Future<bool> interruptSelectedSession() async {
    interruptCalls += 1;
    notifyListeners();
    return true;
  }
}

class _QueuedWorkspaceController extends _SlashWorkspaceController {
  _QueuedWorkspaceController({
    required super.profile,
    required super.directory,
    List<WorkspaceQueuedPrompt> queuedPrompts = const <WorkspaceQueuedPrompt>[],
  }) : _queuedPrompts = List<WorkspaceQueuedPrompt>.from(queuedPrompts);
  final List<_RecordedSubmission> submissions = <_RecordedSubmission>[];
  final List<String> deletedQueuedPromptIds = <String>[];
  final List<String> editedQueuedPromptIds = <String>[];
  final List<String> sentQueuedPromptIds = <String>[];
  List<WorkspaceQueuedPrompt> _queuedPrompts;

  @override
  SessionStatusSummary? get selectedStatus =>
      const SessionStatusSummary(type: 'busy');

  @override
  bool get selectedSessionInterruptible => true;

  @override
  bool submittingPromptForSession(String? sessionId) => false;

  @override
  List<WorkspaceQueuedPrompt> get selectedSessionQueuedPrompts =>
      List<WorkspaceQueuedPrompt>.unmodifiable(_queuedPrompts);

  @override
  Future<String?> submitPrompt(
    String prompt, {
    List<PromptAttachment> attachments = const <PromptAttachment>[],
    WorkspacePromptDispatchMode? mode,
  }) async {
    submissions.add(
      _RecordedSubmission(prompt: prompt, attachments: attachments, mode: mode),
    );
    return selectedSessionId;
  }

  @override
  Future<WorkspaceQueuedPrompt?> editSelectedQueuedPrompt(
    String queuedPromptId,
  ) async {
    WorkspaceQueuedPrompt? edited;
    _queuedPrompts = _queuedPrompts
        .where((item) {
          final matches = item.id == queuedPromptId;
          if (matches) {
            edited = item;
          }
          return !matches;
        })
        .toList(growable: false);
    if (edited != null) {
      editedQueuedPromptIds.add(queuedPromptId);
      notifyListeners();
    }
    return edited;
  }

  @override
  Future<void> deleteSelectedQueuedPrompt(String queuedPromptId) async {
    deletedQueuedPromptIds.add(queuedPromptId);
    _queuedPrompts = _queuedPrompts
        .where((item) => item.id != queuedPromptId)
        .toList(growable: false);
    notifyListeners();
  }

  @override
  Future<void> sendSelectedQueuedPromptNow(String queuedPromptId) async {
    sentQueuedPromptIds.add(queuedPromptId);
    notifyListeners();
  }
}

class _RecordedSubmission {
  const _RecordedSubmission({
    required this.prompt,
    required this.attachments,
    required this.mode,
  });

  final String prompt;
  final List<PromptAttachment> attachments;
  final WorkspacePromptDispatchMode? mode;
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
