import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
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
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

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
        '/provider/{providerID}/oauth/authorize',
        '/mcp/{name}/auth',
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
    await _pumpShellFrames(tester);
  }

  testWidgets('advanced tooling is reachable only via settings path', (
    tester,
  ) async {
    await pumpShell(tester, size: const Size(390, 1000));

    expect(find.text('Terminal'), findsNothing);
    expect(find.text('Config'), findsNothing);
    expect(find.text('Inspector'), findsNothing);
    expect(find.text('Integrations'), findsNothing);

    await tester.tap(find.text('Settings').first);
    await _pumpShellFrames(tester);

    final openAdvanced = find.byKey(
      const ValueKey<String>('settings-open-advanced'),
    );
    expect(openAdvanced, findsOneWidget);
    await tester.tap(openAdvanced);
    await _pumpShellFrames(tester);

    final settingsList = find.byKey(
      const ValueKey<String>('settings-rail-scroll'),
    );
    expect(find.text('Terminal'), findsAtLeastNWidgets(1));
    await tester.drag(settingsList, const Offset(0, -300));
    await _pumpShellFrames(tester);
    expect(
      find.byKey(const ValueKey<String>('advanced-config-panel')),
      findsAtLeastNWidgets(1),
    );
    expect(find.text('Integrations'), findsAtLeastNWidgets(1));
    await tester.drag(settingsList, const Offset(0, -500));
    await _pumpShellFrames(tester);
    expect(find.text('Inspector'), findsAtLeastNWidgets(1));
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
