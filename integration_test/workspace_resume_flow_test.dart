import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:better_opencode_client/l10n/app_localizations.dart';
import 'package:better_opencode_client/src/core/connection/connection_models.dart';
import 'package:better_opencode_client/src/core/spec/capability_registry.dart';
import 'package:better_opencode_client/src/core/spec/probe_snapshot.dart';
import 'package:better_opencode_client/src/design_system/app_theme.dart';
import 'package:better_opencode_client/src/features/chat/chat_models.dart';
import 'package:better_opencode_client/src/features/chat/chat_service.dart';
import 'package:better_opencode_client/src/features/projects/project_models.dart';
import 'package:better_opencode_client/src/features/projects/project_store.dart';
import 'package:better_opencode_client/src/features/shell/opencode_shell_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const profile = ServerProfile(
    id: 'server-1',
    label: 'Mock server',
    baseUrl: 'http://127.0.0.1:8787',
  );
  final sessionCapabilities = CapabilityRegistry.fromSnapshot(
    ProbeSnapshot(
      name: 'sessions',
      version: '1.0.0',
      paths: const <String>{
        '/project',
        '/project/current',
        '/session',
        '/session/status',
      },
      endpoints: const <String, ProbeEndpointResult>{},
    ),
  );

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
    'matching remembered session is restored instead of first session',
    (tester) async {
      final chatService = _FakeChatService(
        sessions: <SessionSummary>[
          _session('session-1', 'First session'),
          _session('session-2', 'Sprint planning'),
        ],
        defaultSelectedSessionId: 'session-1',
      );

      await _pumpShell(
        tester,
        profile: profile,
        capabilities: sessionCapabilities,
        chatService: chatService,
        project: const ProjectTarget(
          directory: '/workspace/demo',
          label: 'Demo',
          source: 'server',
          lastSession: ProjectSessionHint(
            title: 'Sprint planning',
            status: 'idle',
          ),
        ),
      );

      expect(chatService.selectedMessagesSessionIds, contains('session-2'));

      final stored = await ProjectStore().loadLastWorkspace(profile.storageKey);
      expect(stored?.directory, '/workspace/demo');
      expect(stored?.lastSession?.title, 'Sprint planning');
    },
  );

  testWidgets(
    'missing remembered session falls back to draft state with clear notice',
    (tester) async {
      final chatService = _FakeChatService(
        sessions: <SessionSummary>[_session('session-1', 'Another thread')],
        defaultSelectedSessionId: 'session-1',
      );

      await _pumpShell(
        tester,
        profile: profile,
        capabilities: sessionCapabilities,
        chatService: chatService,
        project: const ProjectTarget(
          directory: '/workspace/demo',
          label: 'Demo',
          source: 'server',
          lastSession: ProjectSessionHint(
            title: 'Missing thread',
            status: 'running',
          ),
        ),
      );

      expect(find.text('New session draft'), findsOneWidget);
      expect(find.text('Ready to start'), findsOneWidget);
      expect(
        find.text(
          'Your last session is no longer available. Choose another session or start a new one.',
        ),
        findsOneWidget,
      );

      final stored = await ProjectStore().loadLastWorkspace(profile.storageKey);
      expect(stored?.directory, '/workspace/demo');
      expect(stored?.lastSession, isNull);
    },
  );
}

Future<void> _pumpShell(
  WidgetTester tester, {
  required ServerProfile profile,
  required ProjectTarget project,
  required CapabilityRegistry capabilities,
  required ChatService chatService,
}) async {
  tester.view.physicalSize = const Size(1280, 900);
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
        onExit: () {},
        chatService: chatService,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeChatService extends ChatService {
  _FakeChatService({
    required this.sessions,
    required this.defaultSelectedSessionId,
  });

  final List<SessionSummary> sessions;
  final String? defaultSelectedSessionId;
  final List<String> selectedMessagesSessionIds = <String>[];

  @override
  Future<ChatSessionBundle> fetchBundle({
    required ServerProfile profile,
    required ProjectTarget project,
    bool includeSelectedSessionMessages = true,
  }) async {
    return ChatSessionBundle(
      sessions: sessions,
      statuses: const <String, SessionStatusSummary>{},
      messages: defaultSelectedSessionId == null
          ? const <ChatMessage>[]
          : <ChatMessage>[_message(defaultSelectedSessionId!)],
      selectedSessionId: defaultSelectedSessionId,
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
}

SessionSummary _session(String id, String title) {
  return SessionSummary(
    id: id,
    directory: '/workspace/demo',
    title: title,
    version: '1',
    updatedAt: DateTime(2026, 3, 19, 12),
  );
}

ChatMessage _message(String sessionId) {
  return ChatMessage(
    info: ChatMessageInfo(
      id: 'message-$sessionId',
      role: 'assistant',
      sessionId: sessionId,
    ),
    parts: const <ChatPart>[
      ChatPart(id: 'part-1', type: 'text', text: 'Hello from the session.'),
    ],
  );
}
