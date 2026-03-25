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
    'prompt clears immediately, shows busy state, and ignores duplicate taps',
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

      expect(workspaceController.submitPromptCalls, 1);
      expect(tester.widget<TextField>(fieldFinder).controller?.text, isEmpty);
      expect(
        find.descendant(
          of: buttonFinder,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );

      workspaceController.completeSubmit();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

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
  Future<String?> submitPrompt(
    String prompt, {
    List<PromptAttachment> attachments = const <PromptAttachment>[],
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
