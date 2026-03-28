import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile_remote/l10n/app_localizations.dart';
import 'package:opencode_mobile_remote/src/core/connection/connection_models.dart';
import 'package:opencode_mobile_remote/src/core/spec/capability_registry.dart';
import 'package:opencode_mobile_remote/src/core/spec/probe_snapshot.dart';
import 'package:opencode_mobile_remote/src/design_system/app_theme.dart';
import 'package:opencode_mobile_remote/src/features/chat/chat_models.dart';
import 'package:opencode_mobile_remote/src/features/chat/chat_service.dart';
import 'package:opencode_mobile_remote/src/features/projects/project_models.dart';
import 'package:opencode_mobile_remote/src/features/shell/opencode_shell_screen.dart';
import 'package:opencode_mobile_remote/src/features/tools/todo_models.dart';
import 'package:opencode_mobile_remote/src/features/tools/todo_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

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

  Future<void> pumpShell(
    WidgetTester tester, {
    required Size size,
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
          capabilities: capabilities,
          onExit: _noop,
          chatService: chatService,
          todoService: todoService,
        ),
      ),
    );
    await _pumpShellFrames(tester);
  }

  testWidgets('stable primary destinations appear at every target width', (
    tester,
  ) async {
    for (final width in <double>[390, 768, 1024, 1366]) {
      await pumpShell(tester, size: Size(width, 1000));

      expect(find.text('Sessions'), findsAtLeastNWidgets(1));
      expect(find.text('Chat'), findsAtLeastNWidgets(1));
      expect(find.text('Context'), findsAtLeastNWidgets(1));
      expect(find.text('Settings'), findsAtLeastNWidgets(1));
    }
  });

  testWidgets('compact layouts switch sessions explicitly and return to chat', (
    tester,
  ) async {
    final chatService = _FakeChatService();

    await pumpShell(
      tester,
      size: const Size(430, 932),
      chatService: chatService,
      todoService: _FakeTodoService(),
    );

    await tester.tap(find.text('Sessions').first);
    await _pumpShellFrames(tester);

    expect(
      find.byKey(const ValueKey<String>('new-session-button')),
      findsOneWidget,
    );

    await tester.tap(find.text('Chat').first);
    await _pumpShellFrames(tester);

    expect(find.text('Conversation'), findsOneWidget);

    await tester.tap(find.text('Context').first);
    await _pumpShellFrames(tester);
    expect(find.text('Files'), findsOneWidget);

    await tester.tap(find.text('Settings').first);
    await _pumpShellFrames(tester);
    expect(find.text('Cache settings'), findsAtLeastNWidgets(1));
  });
}

void _noop() {}

Future<void> _pumpShellFrames(WidgetTester tester) async {
  await tester.pump();
  for (var index = 0; index < 5; index += 1) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

class _FakeChatService extends ChatService {
  final List<String> selectedMessagesSessionIds = <String>[];

  @override
  Future<ChatSessionBundle> fetchBundle({
    required ServerProfile profile,
    required ProjectTarget project,
    bool includeSelectedSessionMessages = true,
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
      parts: <ChatPart>[
        ChatPart(
          id: 'part-$sessionId',
          type: 'text',
          text: 'Message for $sessionId',
        ),
      ],
    );
  }

  @override
  void dispose() {}
}

class _FakeTodoService extends TodoService {
  @override
  Future<List<TodoItem>> fetchTodos({
    required ServerProfile profile,
    required ProjectTarget project,
    required String sessionId,
  }) async {
    return const <TodoItem>[];
  }

  @override
  void dispose() {}
}
