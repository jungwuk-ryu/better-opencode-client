import 'dart:async';

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
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../test_helpers/responsive_viewports.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'session workspace renders across the responsive viewport matrix',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final viewport in kResponsiveLayoutViewports) {
        await applyResponsiveTestViewport(tester, viewport.size);

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

        final exception = tester.takeException();
        expect(
          exception,
          isNull,
          reason: 'workspace session layout failed on ${viewport.name}',
        );
        expect(
          find.byKey(const ValueKey<String>('session-header-title-ses_1')),
          findsOneWidget,
          reason: viewport.name,
        );
        expect(
          find.byKey(
            const ValueKey<String>('session-header-overflow-menu-button'),
          ),
          findsOneWidget,
          reason: viewport.name,
        );
        expect(
          find.byKey(const ValueKey<String>('composer-text-field')),
          findsOneWidget,
          reason: viewport.name,
        );

        await tester.pumpWidget(const SizedBox.shrink());
        appController.dispose();
        await tester.pump();
      }
    },
  );

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

  testWidgets(
    'desktop session header keeps controls trailing and project metadata below the title',
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
      await tester.pump(const Duration(milliseconds: 120));

      final titleRect = tester.getRect(
        find.byKey(const ValueKey<String>('session-header-title-ses_1')),
      );
      final pathRect = tester.getRect(
        find.byKey(const ValueKey<String>('session-header-project-path')),
      );
      final actionRect = tester.getRect(
        find.byKey(
          const ValueKey<String>('workspace-session-header-action-chips'),
        ),
      );
      final sessionsRect = tester.getRect(
        find.byKey(
          const ValueKey<String>('workspace-toggle-sessions-panel-button'),
        ),
      );

      expect(pathRect.top, greaterThan(titleRect.bottom - 1));
      expect(actionRect.top, greaterThan(titleRect.top + 12));
      expect(sessionsRect.left, greaterThan(titleRect.left + 120));
      expect(pathRect.left, lessThan(actionRect.left));
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
          'session-header-overflow-menu-item-shell-display-auto-collapse',
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('session header menu actions rename, fork, share, and delete', (
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
    late _ActionWorkspaceController controllerInstance;
    final appController = _StaticAppController(
      profile: profile,
      workspaceControllerFactory:
          ({required profile, required directory, initialSessionId}) {
            controllerInstance = _ActionWorkspaceController(
              profile: profile,
              directory: directory,
              initialSessionId: initialSessionId,
            );
            return controllerInstance;
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
    final renameItem = tester.widget<InkWell>(
      find.byKey(
        const ValueKey<String>('session-header-overflow-menu-item-rename'),
      ),
    );
    renameItem.onTap?.call();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'Renamed header session',
    );
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Save'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    expect(controllerInstance.renameCount, 1);
    expect(find.text('Renamed header session'), findsAtLeastNWidgets(1));

    await tester.tap(
      find.byKey(const ValueKey<String>('session-header-overflow-menu-button')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));
    final forkItem = tester.widget<InkWell>(
      find.byKey(
        const ValueKey<String>('session-header-overflow-menu-item-fork'),
      ),
    );
    forkItem.onTap?.call();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    expect(controllerInstance.forkCount, 1);
    expect(find.text('Forked header session'), findsAtLeastNWidgets(1));

    await tester.tap(
      find.byKey(const ValueKey<String>('session-header-overflow-menu-button')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));
    final shareItem = tester.widget<InkWell>(
      find.byKey(
        const ValueKey<String>('session-header-overflow-menu-item-share'),
      ),
    );
    shareItem.onTap?.call();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    expect(controllerInstance.shareCount, 1);
    expect(
      controllerInstance.selectedSession?.shareUrl,
      'https://share.example/ses_forked',
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('session-header-overflow-menu-button')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));
    final deleteItem = tester.widget<InkWell>(
      find.byKey(
        const ValueKey<String>('session-header-overflow-menu-item-delete'),
      ),
    );
    deleteItem.onTap?.call();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    expect(find.text('Delete Session'), findsAtLeastNWidgets(1));
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Delete'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    expect(controllerInstance.deleteCount, 1);
    expect(find.text('Renamed header session'), findsAtLeastNWidgets(1));
  });

  testWidgets('session header shell toggle menu item applies immediately', (
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

    expect(
      appController.shellToolDisplayMode,
      ShellToolDisplayMode.alwaysExpanded,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('session-header-overflow-menu-button')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    await tester.tap(
      find.byKey(
        const ValueKey<String>(
          'session-header-overflow-menu-item-shell-display-collapsed',
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    expect(
      appController.shellToolDisplayMode,
      ShellToolDisplayMode.collapsed,
    );
  });

  testWidgets(
    'session header chat search reveals older matches and navigates between them',
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
              return _LargeSearchWorkspaceController(
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

      expect(
        find.byKey(const ValueKey<String>('timeline-user-message-msg_user_4')),
        findsNothing,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('workspace-chat-search-button')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 220));

      await tester.enterText(
        find.byKey(const ValueKey<String>('workspace-chat-search-field')),
        'needle',
      );
      await tester.pump();
      for (var index = 0; index < 5; index += 1) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(
        find.byKey(const ValueKey<String>('timeline-user-message-msg_user_4')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('timeline-search-match-msg_user_4')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('timeline-search-active-msg_user_4')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('workspace-chat-search-next-button')),
      );
      await tester.pump();
      for (var index = 0; index < 5; index += 1) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(
        find.byKey(const ValueKey<String>('timeline-search-active-msg_user_4')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('timeline-search-match-msg_user_87')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('timeline-search-active-msg_user_87'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('chat search highlights matching text inside the message body', (
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
            return _LargeSearchWorkspaceController(
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
      find.byKey(const ValueKey<String>('workspace-chat-search-button')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    await tester.enterText(
      find.byKey(const ValueKey<String>('workspace-chat-search-field')),
      'needle',
    );
    await tester.pump();
    for (var index = 0; index < 5; index += 1) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    final richTextWidgets = tester
        .widgetList<RichText>(
          find.descendant(
            of: find.byKey(
              const ValueKey<String>('timeline-user-message-msg_user_4'),
            ),
            matching: find.byType(RichText),
          ),
        )
        .toList(growable: false);

    expect(
      richTextWidgets.any(
        (widget) => _inlineSpanContainsHighlightedText(widget.text, 'Needle'),
      ),
      isTrue,
    );
  });

  testWidgets('hiding the terminal panel keeps the PTY connection alive', (
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
    final terminalService = _TrackingPtyService();
    addTearDown(terminalService.dispose);
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
        ptyServiceFactory: () => terminalService,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(terminalService.connectCount('pty_1'), 0);

    await tester.tap(find.byTooltip('Show terminal'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    expect(terminalService.connectCount('pty_1'), 1);

    await tester.tap(find.byTooltip('Hide terminal'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    await tester.tap(find.byTooltip('Show terminal'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    expect(terminalService.connectCount('pty_1'), 1);
  });
}

class _WorkspaceRouteHarness extends StatelessWidget {
  const _WorkspaceRouteHarness({
    required this.controller,
    required this.initialRoute,
    this.ptyServiceFactory,
  });

  final WebParityAppController controller;
  final String initialRoute;
  final PtyService Function()? ptyServiceFactory;

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
                    ptyServiceFactory: ptyServiceFactory ?? _FakePtyService.new,
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
  }) : _shellToolDisplayMode = ShellToolDisplayMode.alwaysExpanded,
       super(workspaceControllerFactory: workspaceControllerFactory);

  final ServerProfile profile;
  ShellToolDisplayMode _shellToolDisplayMode;

  @override
  ServerProfile? get selectedProfile => profile;

  @override
  ShellToolDisplayMode get shellToolDisplayMode => _shellToolDisplayMode;

  @override
  Future<void> setShellToolDisplayMode(ShellToolDisplayMode value) async {
    _shellToolDisplayMode = value;
    notifyListeners();
  }
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

  bool _actionLoading = true;

  @override
  bool get loading => _actionLoading;

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
    _actionLoading = false;
    notifyListeners();
  }
}

class _ActionWorkspaceController extends _HeaderWorkspaceController {
  _ActionWorkspaceController({
    required super.profile,
    required super.directory,
    super.initialSessionId,
  });

  final SessionSummary _rootSession = SessionSummary(
    id: 'ses_1',
    directory: '/workspace/demo',
    title: '코드 작성과 아키텍처 계획 수립',
    version: '1',
    updatedAt: DateTime.fromMillisecondsSinceEpoch(1774454340000),
    createdAt: DateTime.fromMillisecondsSinceEpoch(1774453800000),
  );

  String? _selectedSessionId;
  int renameCount = 0;
  int forkCount = 0;
  int shareCount = 0;
  int deleteCount = 0;
  bool _loading = true;
  late List<SessionSummary> _sessions = <SessionSummary>[_rootSession];

  SessionSummary get _selected =>
      _sessions.firstWhere((session) => session.id == _selectedSessionId);

  @override
  bool get loading => _loading;

  @override
  List<SessionSummary> get sessions =>
      List<SessionSummary>.unmodifiable(_sessions);

  @override
  String? get selectedSessionId => _selectedSessionId;

  @override
  SessionSummary? get selectedSession =>
      _selectedSessionId == null ? null : _selected;

  @override
  SessionStatusSummary? get selectedStatus =>
      const SessionStatusSummary(type: 'busy');

  @override
  Future<void> load() async {
    _loading = false;
    _selectedSessionId = initialSessionId ?? _rootSession.id;
    notifyListeners();
  }

  @override
  Future<SessionSummary?> renameSelectedSession(String title) async {
    renameCount += 1;
    final index = _sessions.indexWhere(
      (session) => session.id == _selectedSessionId,
    );
    final updated = SessionSummary(
      id: _sessions[index].id,
      directory: _sessions[index].directory,
      title: title,
      version: _sessions[index].version,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(1774455000000),
      createdAt: _sessions[index].createdAt,
      parentId: _sessions[index].parentId,
      shareUrl: _sessions[index].shareUrl,
    );
    _sessions[index] = updated;
    notifyListeners();
    return updated;
  }

  @override
  Future<SessionSummary?> forkSelectedSession({String? messageId}) async {
    forkCount += 1;
    final forked = SessionSummary(
      id: 'ses_forked',
      directory: '/workspace/demo',
      title: 'Forked header session',
      version: '1',
      updatedAt: DateTime.fromMillisecondsSinceEpoch(1774455600000),
      createdAt: DateTime.fromMillisecondsSinceEpoch(1774455600000),
      parentId: _selectedSessionId,
    );
    _sessions = <SessionSummary>[forked, ..._sessions];
    _selectedSessionId = forked.id;
    notifyListeners();
    return forked;
  }

  @override
  Future<SessionSummary?> shareSelectedSession() async {
    shareCount += 1;
    final index = _sessions.indexWhere(
      (session) => session.id == _selectedSessionId,
    );
    final updated = SessionSummary(
      id: _sessions[index].id,
      directory: _sessions[index].directory,
      title: _sessions[index].title,
      version: _sessions[index].version,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(1774455700000),
      createdAt: _sessions[index].createdAt,
      parentId: _sessions[index].parentId,
      shareUrl: 'https://share.example/${_sessions[index].id}',
    );
    _sessions[index] = updated;
    notifyListeners();
    return updated;
  }

  @override
  Future<SessionSummary?> deleteSelectedSession() async {
    deleteCount += 1;
    _sessions = _sessions
        .where((session) => session.id != _selectedSessionId)
        .toList(growable: false);
    _selectedSessionId = _sessions.isEmpty ? null : _sessions.last.id;
    notifyListeners();
    return selectedSession;
  }
}

class _LargeSearchWorkspaceController extends _HeaderWorkspaceController {
  _LargeSearchWorkspaceController({
    required super.profile,
    required super.directory,
    super.initialSessionId,
  });

  static final List<ChatMessage> _largeMessages = List<ChatMessage>.generate(
    90,
    (index) => ChatMessage(
      info: ChatMessageInfo(
        id: 'msg_user_$index',
        role: 'user',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          1774453800000 + index * 1000,
        ),
      ),
      parts: <ChatPart>[
        ChatPart(
          id: 'part_user_$index',
          type: 'text',
          text: switch (index) {
            4 => 'Needle result hidden in the earlier part of the chat',
            87 => 'Needle result near the bottom of the chat',
            _ => 'Filler timeline entry $index',
          },
        ),
      ],
    ),
  );

  @override
  List<ChatMessage> get messages => _largeMessages;

  @override
  List<ChatMessage> get orderedMessages => _largeMessages;

  @override
  WorkspaceSessionTimelineState timelineStateForSession(String? sessionId) {
    final normalized = sessionId?.trim();
    if (normalized == null || normalized.isEmpty) {
      return const WorkspaceSessionTimelineState.empty();
    }
    return WorkspaceSessionTimelineState(
      sessionId: normalized,
      messages: _largeMessages,
      orderedMessages: _largeMessages,
      loading: false,
      showingCachedMessages: false,
      error: null,
    );
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

class _TrackingPtyService extends PtyService {
  _TrackingPtyService()
    : super(client: MockClient((request) async => http.Response('[]', 200)));

  final Map<String, int> _connectCounts = <String, int>{};
  final List<_FakeWebSocketChannel> _channels = <_FakeWebSocketChannel>[];

  int connectCount(String ptyId) => _connectCounts[ptyId] ?? 0;

  PtySessionInfo _session(String directory, {String id = 'pty_1'}) =>
      PtySessionInfo(
        id: id,
        title: 'Terminal 1',
        command: '/bin/zsh',
        args: const <String>['-l'],
        cwd: directory,
        status: PtySessionStatus.running,
        pid: 1001,
      );

  @override
  Future<List<PtySessionInfo>> listSessions({
    required ServerProfile profile,
    required String directory,
  }) async {
    return <PtySessionInfo>[_session(directory)];
  }

  @override
  Future<PtySessionInfo?> getSession({
    required ServerProfile profile,
    required String directory,
    required String ptyId,
  }) async {
    return _session(directory, id: ptyId);
  }

  @override
  Future<PtySessionInfo> updateSession({
    required ServerProfile profile,
    required String directory,
    required String ptyId,
    String? title,
    PtySessionSize? size,
  }) async {
    return _session(directory, id: ptyId).copyWith(title: title);
  }

  @override
  WebSocketChannel connectSession({
    required ServerProfile profile,
    required String directory,
    required String ptyId,
    int? cursor,
  }) {
    _connectCounts.update(ptyId, (count) => count + 1, ifAbsent: () => 1);
    final channel = _FakeWebSocketChannel();
    _channels.add(channel);
    return channel;
  }

  @override
  void dispose() {
    for (final channel in _channels) {
      channel.close();
    }
    super.dispose();
  }
}

bool _inlineSpanContainsHighlightedText(InlineSpan span, String needle) {
  if (span is! TextSpan) {
    return false;
  }
  final text = span.text ?? '';
  if (text.toLowerCase().contains(needle.toLowerCase()) &&
      span.style?.backgroundColor != null) {
    return true;
  }
  final children = span.children;
  if (children == null || children.isEmpty) {
    return false;
  }
  for (final child in children) {
    if (_inlineSpanContainsHighlightedText(child, needle)) {
      return true;
    }
  }
  return false;
}

class _FakeWebSocketChannel implements WebSocketChannel {
  _FakeWebSocketChannel();

  final StreamController<dynamic> _controller = StreamController<dynamic>();
  late final _FakeWebSocketSink _sink = _FakeWebSocketSink(_controller);

  @override
  Stream<dynamic> get stream => _controller.stream;

  @override
  WebSocketSink get sink => _sink;

  @override
  Future<void> get ready => Future<void>.value();

  @override
  String? get protocol => null;

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

  Future<void> close() => _sink.close();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeWebSocketSink implements WebSocketSink {
  _FakeWebSocketSink(this._controller);

  final StreamController<dynamic> _controller;

  @override
  void add(event) {}

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream stream) async {}

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    if (!_controller.isClosed) {
      await _controller.close();
    }
  }

  @override
  Future<void> get done => _controller.done;
}
