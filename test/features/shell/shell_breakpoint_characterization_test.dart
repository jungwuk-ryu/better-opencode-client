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
        '/session/{sessionID}/shell',
      },
      endpoints: const <String, ProbeEndpointResult>{},
    ),
  );

  Future<void> pumpShell(WidgetTester tester, {required Size size}) async {
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
          chatService: _FakeChatService(),
          todoService: _FakeTodoService(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }

  testWidgets('width 390 keeps stable destinations on compact shell', (
    tester,
  ) async {
    await pumpShell(tester, size: const Size(390, 900));

    expect(find.text('Sessions'), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('Context'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Conversation'), findsOneWidget);
  });

  testWidgets('widths below 700 use the compact mobile shell', (tester) async {
    await pumpShell(tester, size: const Size(699, 900));

    expect(find.text('Conversation'), findsOneWidget);
    expect(find.text('Sessions'), findsOneWidget);
    expect(find.text('Back to servers'), findsOneWidget);
    expect(find.text('Project and sessions'), findsNothing);
    expect(find.text('Terminal'), findsNothing);
  });

  testWidgets('width 768 keeps stable destinations on portrait shell', (
    tester,
  ) async {
    await pumpShell(tester, size: const Size(768, 1100));

    expect(find.text('Sessions'), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('Context'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('widths from 700 use the tablet portrait shell', (tester) async {
    await pumpShell(tester, size: const Size(700, 1100));

    expect(find.text('Demo'), findsOneWidget);
    expect(find.text('Conversation'), findsOneWidget);
    expect(find.text('Sessions'), findsOneWidget);
    expect(find.text('Back to servers'), findsOneWidget);
    expect(find.text('Project and sessions'), findsNothing);
    expect(find.text('Terminal'), findsNothing);
  });

  testWidgets('width 1024 keeps stable destinations on landscape shell', (
    tester,
  ) async {
    await pumpShell(tester, size: const Size(1024, 1100));

    expect(find.text('Sessions'), findsAtLeastNWidgets(1));
    expect(find.text('Chat'), findsAtLeastNWidgets(1));
    expect(find.text('Context'), findsAtLeastNWidgets(1));
    expect(find.text('Settings'), findsAtLeastNWidgets(1));
  });

  testWidgets('widths from 960 use landscape rails with stable navigation', (
    tester,
  ) async {
    await pumpShell(tester, size: const Size(960, 1100));

    expect(find.text('Project and sessions'), findsOneWidget);
    expect(find.text('Context'), findsAtLeastNWidgets(1));
    expect(find.text('Conversation'), findsOneWidget);
    expect(find.text('Terminal'), findsNothing);
    expect(find.text('Back to servers'), findsOneWidget);
  });

  testWidgets('width 1366 keeps stable destinations on desktop shell', (
    tester,
  ) async {
    await pumpShell(tester, size: const Size(1366, 1000));

    expect(find.text('Sessions'), findsAtLeastNWidgets(1));
    expect(find.text('Chat'), findsAtLeastNWidgets(1));
    expect(find.text('Context'), findsAtLeastNWidgets(1));
    expect(find.text('Settings'), findsAtLeastNWidgets(1));
  });

  testWidgets('widths from 1320 use the desktop shell with stable settings', (
    tester,
  ) async {
    await pumpShell(tester, size: const Size(1320, 1000));

    expect(find.text('Project and sessions'), findsOneWidget);
    expect(find.text('Context'), findsAtLeastNWidgets(1));
    expect(find.text('Conversation'), findsOneWidget);

    await tester.tap(find.text('Settings').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Cache settings'), findsAtLeastNWidgets(1));
    expect(find.text('Terminal'), findsNothing);
  });
}

void _noop() {}

class _FakeChatService extends ChatService {
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
