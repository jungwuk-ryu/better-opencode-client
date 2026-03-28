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
import 'package:opencode_mobile_remote/src/features/projects/project_models.dart';
import 'package:opencode_mobile_remote/src/features/requests/request_models.dart';
import 'package:opencode_mobile_remote/src/features/terminal/pty_models.dart';
import 'package:opencode_mobile_remote/src/features/terminal/pty_service.dart';
import 'package:opencode_mobile_remote/src/features/tools/todo_models.dart';
import 'package:opencode_mobile_remote/src/features/web_parity/workspace_controller.dart';
import 'package:opencode_mobile_remote/src/features/web_parity/workspace_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'timeline shows loading and retry states instead of an empty placeholder',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final createdControllers = <_SessionLoadingWorkspaceController>[];
      final profile = ServerProfile(
        id: 'server',
        label: 'Mock',
        baseUrl: 'http://localhost:3000',
      );
      final appController = _StaticAppController(
        profile: profile,
        workspaceControllerFactory:
            ({required profile, required directory, initialSessionId}) {
              final controller = _SessionLoadingWorkspaceController(
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
            sessionId: 'ses_1',
          ),
        ),
      );
      await _pumpUntilVisible(tester, find.text('Session Two'));

      final controller = createdControllers.single;
      expect(find.text('Session Two'), findsOneWidget);

      await tester.tap(find.text('Session Two'));
      await tester.pump();

      expect(find.text('Loading messages...'), findsOneWidget);
      expect(find.text('No messages yet.'), findsNothing);

      controller.failPendingSelection();
      await _pumpUntilVisible(tester, find.text('Couldn\'t load this session'));

      expect(find.text('Couldn\'t load this session'), findsOneWidget);
      expect(find.textContaining('responding too slowly'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Retry'), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Retry'));
      await tester.pump();
      expect(find.text('Loading messages...'), findsOneWidget);

      await _pumpUntilVisible(tester, find.text('hello from two'));
      expect(find.text('hello from two'), findsOneWidget);
      expect(find.text('Couldn\'t load this session'), findsNothing);
    },
  );

  testWidgets(
    'timeline keeps cached messages visible while a shimmer refresh banner is shown',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final createdControllers = <_CachedSessionWorkspaceController>[];
      final profile = ServerProfile(
        id: 'server',
        label: 'Mock',
        baseUrl: 'http://localhost:3000',
      );
      final appController = _StaticAppController(
        profile: profile,
        workspaceControllerFactory:
            ({required profile, required directory, initialSessionId}) {
              final controller = _CachedSessionWorkspaceController(
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
            sessionId: 'ses_1',
          ),
        ),
      );
      await _pumpUntilVisible(tester, find.text('Session Two'));

      await tester.tap(find.text('Session Two'));
      await tester.pump();

      expect(find.text('cached hello from two'), findsOneWidget);
      expect(find.text('Refreshing cached messages...'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('timeline-cached-refresh-shimmer')),
        findsOneWidget,
      );

      createdControllers.single.completePendingSelection();
      await _pumpUntilVisible(tester, find.text('fresh hello from two'));

      expect(find.text('fresh hello from two'), findsOneWidget);
      expect(find.text('Refreshing cached messages...'), findsNothing);
    },
  );
}

Future<void> _pumpUntilVisible(
  WidgetTester tester,
  Finder finder, {
  int maxTicks = 12,
}) async {
  for (var tick = 0; tick < maxTicks; tick += 1) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
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

class _SessionLoadingWorkspaceController extends WorkspaceController {
  _SessionLoadingWorkspaceController({
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
      id: 'ses_1',
      directory: '/workspace/demo',
      title: 'Session One',
      version: '1',
      updatedAt: DateTime.fromMillisecondsSinceEpoch(1710000001000),
    ),
    SessionSummary(
      id: 'ses_2',
      directory: '/workspace/demo',
      title: 'Session Two',
      version: '1',
      updatedAt: DateTime.fromMillisecondsSinceEpoch(1710000002000),
    ),
  ];

  static final Map<String, SessionStatusSummary> _statuses =
      <String, SessionStatusSummary>{
        'ses_1': const SessionStatusSummary(type: 'idle'),
        'ses_2': const SessionStatusSummary(type: 'idle'),
      };

  bool _loading = true;
  bool _sessionLoading = false;
  String? _sessionLoadError;
  String? _selectedSessionId;
  List<ChatMessage> _messages = const <ChatMessage>[];
  Completer<void>? _selectionCompleter;
  bool _retryShouldSucceed = false;

  @override
  bool get loading => _loading;

  @override
  bool get sessionLoading => _sessionLoading;

  @override
  String? get sessionLoadError => _sessionLoadError;

  @override
  ProjectTarget? get project => _projectTarget;

  @override
  List<ProjectTarget> get availableProjects => const <ProjectTarget>[
    _projectTarget,
  ];

  @override
  List<SessionSummary> get sessions => _sessions;

  @override
  List<SessionSummary> get visibleSessions => _sessions;

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
  List<TodoItem> get todos => const <TodoItem>[];

  @override
  WorkspaceSessionTimelineState timelineStateForSession(String? sessionId) {
    final normalized = sessionId?.trim();
    if (normalized == null || normalized.isEmpty) {
      return const WorkspaceSessionTimelineState.empty();
    }
    if (normalized == _selectedSessionId) {
      return WorkspaceSessionTimelineState(
        sessionId: normalized,
        messages: _messages,
        orderedMessages: _messages,
        loading: _sessionLoading,
        showingCachedMessages: false,
        error: _sessionLoadError,
      );
    }
    final messages = _messageListFor(normalized);
    return WorkspaceSessionTimelineState(
      sessionId: normalized,
      messages: messages,
      orderedMessages: messages,
      loading: false,
      showingCachedMessages: false,
    );
  }

  @override
  PendingRequestBundle get pendingRequests => const PendingRequestBundle(
    questions: <QuestionRequestSummary>[],
    permissions: <PermissionRequestSummary>[],
  );

  @override
  Future<void> load() async {
    _loading = false;
    _selectedSessionId = initialSessionId ?? 'ses_1';
    _messages = _messageListFor('ses_1');
    notifyListeners();
  }

  @override
  Future<void> selectSession(String? sessionId) async {
    _selectedSessionId = sessionId;
    _messages = const <ChatMessage>[];
    _sessionLoadError = null;
    _sessionLoading = true;
    _selectionCompleter = Completer<void>();
    notifyListeners();
    await _selectionCompleter!.future;
  }

  void failPendingSelection() {
    _sessionLoading = false;
    _sessionLoadError =
        'The server may be offline or responding too slowly.\nconnection timed out';
    _selectionCompleter?.complete();
    _selectionCompleter = null;
    _retryShouldSucceed = true;
    notifyListeners();
  }

  @override
  Future<void> retrySelectedSessionMessages() async {
    _sessionLoadError = null;
    _sessionLoading = true;
    notifyListeners();
    await Future<void>.delayed(Duration.zero);
    if (_retryShouldSucceed) {
      _messages = _messageListFor('ses_2');
      _sessionLoading = false;
      notifyListeners();
      return;
    }
    _sessionLoading = false;
    _sessionLoadError = 'retry failed';
    notifyListeners();
  }

  List<ChatMessage> _messageListFor(String sessionId) {
    final text = sessionId == 'ses_2' ? 'hello from two' : 'hello from one';
    return <ChatMessage>[
      ChatMessage(
        info: ChatMessageInfo(
          id: 'msg_$sessionId',
          role: 'assistant',
          sessionId: sessionId,
        ),
        parts: <ChatPart>[
          ChatPart(id: 'part_$sessionId', type: 'text', text: text),
        ],
      ),
    ];
  }
}

class _CachedSessionWorkspaceController extends WorkspaceController {
  _CachedSessionWorkspaceController({
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
      id: 'ses_1',
      directory: '/workspace/demo',
      title: 'Session One',
      version: '1',
      updatedAt: DateTime.fromMillisecondsSinceEpoch(1710000001000),
    ),
    SessionSummary(
      id: 'ses_2',
      directory: '/workspace/demo',
      title: 'Session Two',
      version: '1',
      updatedAt: DateTime.fromMillisecondsSinceEpoch(1710000002000),
    ),
  ];

  static final Map<String, SessionStatusSummary> _statuses =
      <String, SessionStatusSummary>{
        'ses_1': const SessionStatusSummary(type: 'idle'),
        'ses_2': const SessionStatusSummary(type: 'idle'),
      };

  bool _loading = true;
  bool _sessionLoading = false;
  bool _showingCachedSessionMessages = false;
  String? _selectedSessionId;
  List<ChatMessage> _messages = const <ChatMessage>[];
  Completer<void>? _selectionCompleter;

  @override
  bool get loading => _loading;

  @override
  bool get sessionLoading => _sessionLoading;

  @override
  bool get showingCachedSessionMessages => _showingCachedSessionMessages;

  @override
  ProjectTarget? get project => _projectTarget;

  @override
  List<ProjectTarget> get availableProjects => const <ProjectTarget>[
    _projectTarget,
  ];

  @override
  List<SessionSummary> get sessions => _sessions;

  @override
  List<SessionSummary> get visibleSessions => _sessions;

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
  List<TodoItem> get todos => const <TodoItem>[];

  @override
  WorkspaceSessionTimelineState timelineStateForSession(String? sessionId) {
    final normalized = sessionId?.trim();
    if (normalized == null || normalized.isEmpty) {
      return const WorkspaceSessionTimelineState.empty();
    }
    if (normalized == _selectedSessionId) {
      return WorkspaceSessionTimelineState(
        sessionId: normalized,
        messages: _messages,
        orderedMessages: _messages,
        loading: _sessionLoading,
        showingCachedMessages: _showingCachedSessionMessages,
      );
    }
    final messages = _messageListFor(normalized, fresh: true);
    return WorkspaceSessionTimelineState(
      sessionId: normalized,
      messages: messages,
      orderedMessages: messages,
      loading: false,
      showingCachedMessages: false,
    );
  }

  @override
  PendingRequestBundle get pendingRequests => const PendingRequestBundle(
    questions: <QuestionRequestSummary>[],
    permissions: <PermissionRequestSummary>[],
  );

  @override
  Future<void> load() async {
    _loading = false;
    _selectedSessionId = initialSessionId ?? 'ses_1';
    _messages = _messageListFor('ses_1', fresh: true);
    notifyListeners();
  }

  @override
  Future<void> selectSession(String? sessionId) async {
    _selectedSessionId = sessionId;
    _messages = _messageListFor(sessionId ?? 'ses_2', fresh: false);
    _sessionLoading = true;
    _showingCachedSessionMessages = true;
    _selectionCompleter = Completer<void>();
    notifyListeners();
    await _selectionCompleter!.future;
  }

  void completePendingSelection() {
    _messages = _messageListFor('ses_2', fresh: true);
    _sessionLoading = false;
    _showingCachedSessionMessages = false;
    _selectionCompleter?.complete();
    _selectionCompleter = null;
    notifyListeners();
  }

  List<ChatMessage> _messageListFor(String sessionId, {required bool fresh}) {
    final text = switch ((sessionId, fresh)) {
      ('ses_2', false) => 'cached hello from two',
      ('ses_2', true) => 'fresh hello from two',
      (_, _) => 'hello from one',
    };
    return <ChatMessage>[
      ChatMessage(
        info: ChatMessageInfo(
          id: 'msg_${sessionId}_${fresh ? 'fresh' : 'cached'}',
          role: 'assistant',
          sessionId: sessionId,
        ),
        parts: <ChatPart>[
          ChatPart(
            id: 'part_${sessionId}_${fresh ? 'fresh' : 'cached'}',
            type: 'text',
            text: text,
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
