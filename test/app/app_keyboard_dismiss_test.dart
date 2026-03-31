import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:better_opencode_client/src/app/app.dart';
import 'package:better_opencode_client/src/app/app_controller.dart';
import 'package:better_opencode_client/src/app/app_routes.dart';
import 'package:better_opencode_client/src/core/connection/connection_models.dart';
import 'package:better_opencode_client/src/core/persistence/server_profile_store.dart';
import 'package:better_opencode_client/src/features/chat/chat_models.dart';
import 'package:better_opencode_client/src/features/projects/project_models.dart';
import 'package:better_opencode_client/src/features/projects/project_store.dart';
import 'package:better_opencode_client/src/features/web_parity/workspace_controller.dart';
import 'package:better_opencode_client/src/i18n/locale_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'web_parity.release_notes_enabled': false,
    });
  });

  testWidgets('tapping outside a focused text field dismisses the keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = WebParityAppController(
      profileStore: _FakeProfileStore(),
      projectStore: _FakeProjectStore(),
      workspaceControllerFactory:
          ({required profile, required directory, initialSessionId}) {
            return _KeyboardDismissWorkspaceController(
              profile: profile,
              directory: directory,
            );
          },
    );
    final localeController = LocaleController();
    addTearDown(controller.dispose);
    addTearDown(localeController.dispose);

    await controller.load();

    await tester.pumpWidget(
      OpenCodeRemoteApp(
        appController: controller,
        localeController: localeController,
        autoLoadAppController: false,
      ),
    );
    await tester.pumpAndSettle();

    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    navigator.pushNamed(
      buildWorkspaceRoute('/workspace/demo', sessionId: 'ses_1'),
    );
    await tester.pumpAndSettle();

    final composerFinder = find.byKey(
      const ValueKey<String>('composer-text-field'),
    );
    await tester.tap(composerFinder);
    await tester.pump();

    EditableText editableText() =>
        tester.widget<EditableText>(find.byType(EditableText).first);

    expect(editableText().focusNode.hasFocus, isTrue);
    expect(tester.testTextInput.hasAnyClients, isTrue);

    await tester.tap(find.text('No messages yet.'));
    await tester.pumpAndSettle();

    expect(editableText().focusNode.hasFocus, isFalse);
    expect(tester.testTextInput.hasAnyClients, isFalse);
  });
}

class _FakeProfileStore extends ServerProfileStore {
  static const ServerProfile _profile = ServerProfile(
    id: 'server',
    label: 'Mock',
    baseUrl: 'http://localhost:3000',
  );

  @override
  Future<List<ServerProfile>> load() async => const <ServerProfile>[_profile];
}

class _FakeProjectStore extends ProjectStore {
  @override
  Future<List<ProjectTarget>> loadRecentProjects() async =>
      const <ProjectTarget>[];
}

class _KeyboardDismissWorkspaceController extends WorkspaceController {
  _KeyboardDismissWorkspaceController({
    required super.profile,
    required super.directory,
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
    title: 'Keyboard dismiss session',
    version: '1',
    updatedAt: DateTime.fromMillisecondsSinceEpoch(1710000001000),
  );

  bool _loading = true;

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
  List<SessionSummary> get visibleSessions => <SessionSummary>[_session];

  @override
  Map<String, SessionStatusSummary> get statuses =>
      <String, SessionStatusSummary>{
        _session.id: const SessionStatusSummary(type: 'idle'),
      };

  @override
  String? get selectedSessionId => _session.id;

  @override
  SessionSummary? get selectedSession => _session;

  @override
  List<ChatMessage> get messages => const <ChatMessage>[];

  @override
  Future<void> load() async {
    _loading = false;
    notifyListeners();
  }
}
