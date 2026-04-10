import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:better_opencode_client/src/app/app_controller.dart';
import 'package:better_opencode_client/src/app/app_routes.dart';
import 'package:better_opencode_client/src/app/app_scope.dart';
import 'package:better_opencode_client/src/core/connection/connection_models.dart';
import 'package:better_opencode_client/src/core/network/live_event_applier.dart';
import 'package:better_opencode_client/src/design_system/app_theme.dart';
import 'package:better_opencode_client/src/features/chat/chat_models.dart';
import 'package:better_opencode_client/src/features/projects/project_models.dart';
import 'package:better_opencode_client/src/features/terminal/pty_models.dart';
import 'package:better_opencode_client/src/features/terminal/pty_service.dart';
import 'package:better_opencode_client/src/features/web_parity/workspace_controller.dart';
import 'package:better_opencode_client/src/features/web_parity/workspace_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'assistant text streams live from content updates without showing raw ids',
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
      late _StreamingWorkspaceController controller;
      final appController = _StaticAppController(
        profile: profile,
        workspaceControllerFactory:
            ({required profile, required directory, initialSessionId}) {
              controller = _StreamingWorkspaceController(
                profile: profile,
                directory: directory,
                initialSessionId: initialSessionId,
              );
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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.textContaining('id: part_text_stream'), findsNothing);

      controller.pushPlaceholderPart();
      await tester.pump();

      expect(find.textContaining('id: part_text_stream'), findsNothing);

      controller.pushStreamingContent('hello brave new world');
      await tester.pump();

      expect(
        find.byKey(
          const ValueKey<String>('streaming-text-chunk-part_text_stream-0'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('streaming-text-chunk-part_text_stream-1'),
        ),
        findsNothing,
      );
      expect(find.textContaining('id: part_text_stream'), findsNothing);

      await tester.pump(const Duration(milliseconds: 70));
      expect(
        find.byKey(
          const ValueKey<String>('streaming-text-chunk-part_text_stream-1'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('streaming-text-chunk-part_text_stream-2'),
        ),
        findsNothing,
      );

      await tester.pump(const Duration(milliseconds: 70));
      expect(
        find.byKey(
          const ValueKey<String>('streaming-text-chunk-part_text_stream-2'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('streaming-text-chunk-part_text_stream-3'),
        ),
        findsNothing,
      );

      await tester.pump(const Duration(milliseconds: 70));
      expect(
        find.byKey(
          const ValueKey<String>('streaming-text-chunk-part_text_stream-3'),
        ),
        findsOneWidget,
      );

      controller.pushStreamingContent('hello brave new world again today');
      await tester.pump();

      expect(
        find.byKey(
          const ValueKey<String>('streaming-text-chunk-part_text_stream-4'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('streaming-text-chunk-part_text_stream-5'),
        ),
        findsNothing,
      );

      await tester.pump(const Duration(milliseconds: 70));
      expect(
        find.byKey(
          const ValueKey<String>('streaming-text-chunk-part_text_stream-5'),
        ),
        findsOneWidget,
      );
    },


  testWidgets(
    'long multiline streaming updates catch up immediately instead of rendering blank space',
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
      late _StreamingWorkspaceController controller;
      final appController = _StaticAppController(
        profile: profile,
        workspaceControllerFactory:
            ({required profile, required directory, initialSessionId}) {
              controller = _StreamingWorkspaceController(
                profile: profile,
                directory: directory,
                initialSessionId: initialSessionId,
              );
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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      controller.pushPlaceholderPart();
      await tester.pump();

      controller.pushStreamingContent(
        'Line one arrives fast.\n'
        'Line two lands immediately.\n'
        'Line three should already be visible.\n'
        'Line four should not wait for the fade queue.',
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('streaming-text-part_text_stream')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('streaming-text-chunk-part_text_stream-0'),
        ),
        findsNothing,
      );
      await tester.pump(const Duration(milliseconds: 160));
      expect(
        find.byKey(
          const ValueKey<String>('streaming-text-chunk-part_text_stream-0'),
        ),
        findsNothing,
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
    required WorkspaceControllerFactory workspaceControllerFactory,
  }) : super(workspaceControllerFactory: workspaceControllerFactory);

  final ServerProfile profile;

  @override
  ServerProfile? get selectedProfile => profile;
}

class _StreamingWorkspaceController extends WorkspaceController {
  _StreamingWorkspaceController({
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
    title: 'Streaming text test',
    version: '1',
    updatedAt: DateTime.fromMillisecondsSinceEpoch(1710000001000),
  );

  bool _loading = true;
  List<ChatMessage> _messages = <ChatMessage>[
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
          text: 'Please stream the answer.',
        ),
      ],
    ),
  ];

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

  void pushPlaceholderPart() {
    _messages = applyMessagePartUpdatedEvent(_messages, <String, Object?>{
      'part': <String, Object?>{
        'id': 'part_text_stream',
        'messageID': 'msg_assistant_stream',
        'sessionID': 'ses_1',
        'type': 'text',
      },
    }, selectedSessionId: 'ses_1');
    notifyListeners();
  }

  void pushStreamingContent(String text) {
    _messages = applyMessagePartUpdatedEvent(_messages, <String, Object?>{
      'part': <String, Object?>{
        'id': 'part_text_stream',
        'messageID': 'msg_assistant_stream',
        'sessionID': 'ses_1',
        'type': 'text',
        'content': text,
      },
    }, selectedSessionId: 'ses_1');
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
