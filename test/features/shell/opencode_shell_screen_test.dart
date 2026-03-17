import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile_remote/l10n/app_localizations.dart';
import 'package:opencode_mobile_remote/src/core/connection/connection_models.dart';
import 'package:opencode_mobile_remote/src/core/spec/capability_registry.dart';
import 'package:opencode_mobile_remote/src/design_system/app_theme.dart';
import 'package:opencode_mobile_remote/src/features/chat/chat_models.dart';
import 'package:opencode_mobile_remote/src/features/chat/chat_service.dart';
import 'package:opencode_mobile_remote/src/core/spec/probe_snapshot.dart';
import 'package:opencode_mobile_remote/src/features/projects/project_models.dart';
import 'package:opencode_mobile_remote/src/features/shell/opencode_shell_screen.dart';
import 'package:opencode_mobile_remote/src/features/tools/todo_models.dart';
import 'package:opencode_mobile_remote/src/features/tools/todo_service.dart';

void main() {
  const profile = ServerProfile(
    id: 'server-1',
    label: 'Mock server',
    baseUrl: 'http://127.0.0.1:8787',
  );
  const project = ProjectTarget(
    directory: '/workspace/demo',
    label: 'Demo',
    source: 'server',
    vcs: 'git',
    branch: 'main',
  );
  final capabilities = CapabilityRegistry.fromSnapshot(
    ProbeSnapshot(
      name: 'test',
      version: '1.0.0',
      paths: const <String>{
        '/project',
        '/project/current',
        '/session',
        '/session/status',
        '/event',
        '/session/{sessionID}/todo',
        '/file',
        '/file/content',
        '/file/status',
        '/find/file',
        '/find/symbol',
        '/session/{sessionID}/shell',
        '/config',
        '/config/providers',
        '/question',
        '/permission',
        '/session/{sessionID}/share',
        '/session/{sessionID}/fork',
        '/session/{sessionID}/summarize',
        '/session/{sessionID}/revert',
        '/session/{sessionID}/init',
        '/provider/{providerID}/oauth/authorize',
        '/mcp/{name}/auth',
      },
      endpoints: const <String, ProbeEndpointResult>{},
    ),
  );
  final minimalCapabilities = CapabilityRegistry.fromSnapshot(
    ProbeSnapshot(
      name: 'minimal',
      version: '1.0.0',
      paths: const <String>{'/project', '/project/current'},
      endpoints: const <String, ProbeEndpointResult>{},
    ),
  );

  Future<void> pumpShellWithCapabilities(
    WidgetTester tester, {
    required Size size,
    required CapabilityRegistry capabilitiesToUse,
    ChatService? chatService,
    TodoService? todoService,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: OpenCodeShellScreen(
          profile: profile,
          project: project,
          capabilities: capabilitiesToUse,
          onExit: _noop,
          chatService: chatService,
          todoService: todoService,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpShell(WidgetTester tester, {required Size size}) async {
    await pumpShellWithCapabilities(
      tester,
      size: size,
      capabilitiesToUse: capabilities,
    );
  }

  testWidgets('desktop shell shows left rail and context utilities', (
    tester,
  ) async {
    await pumpShell(tester, size: const Size(1440, 1000));

    expect(find.text('Project and sessions'), findsOneWidget);
    expect(find.text('Context utilities'), findsOneWidget);
    expect(find.text('Conversation'), findsOneWidget);
  });

  testWidgets('tablet portrait shell shows utilities drawer hint', (
    tester,
  ) async {
    await pumpShell(tester, size: const Size(820, 1180));

    expect(find.text('Utilities drawer'), findsOneWidget);
    expect(find.text('Demo'), findsOneWidget);
  });

  testWidgets('mobile shell keeps chat canvas visible', (tester) async {
    await pumpShell(tester, size: const Size(430, 932));

    expect(find.text('Conversation'), findsOneWidget);
    expect(find.text('Back to projects'), findsOneWidget);
  });

  testWidgets('minimal capabilities hide unsupported shell controls', (
    tester,
  ) async {
    await pumpShellWithCapabilities(
      tester,
      size: const Size(1440, 1000),
      capabilitiesToUse: minimalCapabilities,
    );

    expect(find.text('Fork'), findsNothing);
    expect(find.text('Share'), findsNothing);
    expect(find.text('Terminal'), findsNothing);
    expect(find.text('Config'), findsNothing);
  });

  testWidgets(
    'selecting a session skips todo fetch when todos are unsupported',
    (tester) async {
      final chatService = _FakeChatService();
      final todoService = _RecordingTodoService();

      await pumpShellWithCapabilities(
        tester,
        size: const Size(1440, 1000),
        capabilitiesToUse: minimalCapabilities,
        chatService: chatService,
        todoService: todoService,
      );

      expect(todoService.fetchCount, 0);

      await tester.tap(find.text('Second session'));
      await tester.pumpAndSettle();

      expect(chatService.selectedMessagesSessionIds, contains('session-2'));
      expect(todoService.fetchCount, 0);
    },
  );
}

void _noop() {}

class _FakeChatService extends ChatService {
  _FakeChatService();

  final List<String> selectedMessagesSessionIds = <String>[];

  @override
  Future<ChatSessionBundle> fetchBundle({
    required ServerProfile profile,
    required ProjectTarget project,
  }) async {
    return ChatSessionBundle(
      sessions: <SessionSummary>[
        _session('session-1', 'First session'),
        _session('session-2', 'Second session'),
      ],
      statuses: const <String, SessionStatusSummary>{},
      messages: <ChatMessage>[_message('session-1')],
      selectedSessionId: 'session-1',
    );
  }

  @override
  Future<List<ChatMessage>> fetchMessages({
    required ServerProfile profile,
    required ProjectTarget project,
    required String sessionId,
  }) async {
    selectedMessagesSessionIds.add(sessionId);
    return <ChatMessage>[_message(sessionId)];
  }

  SessionSummary _session(String id, String title) {
    return SessionSummary(
      id: id,
      directory: '/workspace/demo',
      title: title,
      version: '1',
      updatedAt: DateTime.utc(2026, 3, 17),
    );
  }

  ChatMessage _message(String sessionId) {
    return ChatMessage(
      info: ChatMessageInfo(
        id: 'msg-$sessionId',
        role: 'assistant',
        sessionId: sessionId,
      ),
      parts: const <ChatPart>[
        ChatPart(id: 'part-1', type: 'text', text: 'hello'),
      ],
    );
  }

  @override
  void dispose() {}
}

class _RecordingTodoService extends TodoService {
  _RecordingTodoService();

  int fetchCount = 0;

  @override
  Future<List<TodoItem>> fetchTodos({
    required ServerProfile profile,
    required ProjectTarget project,
    required String sessionId,
  }) async {
    fetchCount += 1;
    return const <TodoItem>[];
  }

  @override
  void dispose() {}
}
