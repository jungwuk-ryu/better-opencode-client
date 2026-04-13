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
import 'package:better_opencode_client/src/features/web_parity/web_home_screen.dart';
import 'package:better_opencode_client/src/features/web_parity/workspace_controller.dart';
import 'package:better_opencode_client/src/features/web_parity/workspace_screen.dart';
import 'package:better_opencode_client/src/features/connection/connection_home_screen.dart';
import 'package:better_opencode_client/src/features/home/workspace_home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('app launch routes into the workspace home scaffold', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const OpenCodeRemoteApp());
    await tester.pumpAndSettle();

    expect(find.byType(WebParityHomeScreen), findsOneWidget);
    expect(find.byType(ConnectionHomeScreen), findsNothing);
    expect(find.byType(WorkspaceHomeScreen), findsNothing);
    expect(find.text('Probe server'), findsNothing);
    expect(find.text('Live capability probe'), findsNothing);
  });

  testWidgets('app launch restores the remembered workspace route', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'web_parity.release_notes_enabled': false,
      'web_parity.launch_location': buildWorkspaceRoute(
        '/workspace/demo',
        sessionId: 'ses_1',
      ),
    });
    tester.view.physicalSize = const Size(1800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final createdInitialSessionIds = <String?>[];
    final controller = WebParityAppController(
      profileStore: _FakeProfileStore(),
      projectStore: _FakeProjectStore(),
      workspaceControllerFactory:
          ({required profile, required directory, initialSessionId}) {
            createdInitialSessionIds.add(initialSessionId);
            return _FakeWorkspaceController(
              profile: profile,
              directory: directory,
              initialSessionId: initialSessionId,
            );
          },
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(OpenCodeRemoteApp(appController: controller));
    await tester.pumpAndSettle();

    expect(find.byType(WebParityWorkspaceScreen), findsOneWidget);
    expect(find.byType(WebParityHomeScreen), findsNothing);
    final workspace = tester.widget<WebParityWorkspaceScreen>(
      find.byType(WebParityWorkspaceScreen),
    );
    expect(workspace.directory, '/workspace/demo');
    expect(workspace.sessionId, 'ses_1');
    expect(
      controller.launchLocation,
      buildWorkspaceRoute('/workspace/demo', sessionId: 'ses_1'),
    );
    expect(createdInitialSessionIds, <String?>['ses_1']);

    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    final popped = await navigator.maybePop();
    await tester.pumpAndSettle();

    expect(popped, isFalse);
    expect(find.byType(WebParityWorkspaceScreen), findsOneWidget);
  });

  testWidgets('app launch restores a workspace route without a session id', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'web_parity.release_notes_enabled': false,
      'web_parity.launch_location': buildWorkspaceRoute('/workspace/demo'),
    });
    tester.view.physicalSize = const Size(1800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = WebParityAppController(
      profileStore: _FakeProfileStore(),
      projectStore: _FakeProjectStore(),
      workspaceControllerFactory:
          ({required profile, required directory, initialSessionId}) {
            return _FakeWorkspaceController(
              profile: profile,
              directory: directory,
              initialSessionId: initialSessionId,
            );
          },
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(OpenCodeRemoteApp(appController: controller));
    await tester.pumpAndSettle();

    expect(find.byType(WebParityWorkspaceScreen), findsOneWidget);
    final workspace = tester.widget<WebParityWorkspaceScreen>(
      find.byType(WebParityWorkspaceScreen),
    );
    expect(workspace.directory, '/workspace/demo');
    expect(workspace.sessionId, isNull);
    expect(controller.launchLocation, buildWorkspaceRoute('/workspace/demo'));
  });

  testWidgets('stale workspace launch route falls back home without a server', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'web_parity.release_notes_enabled': false,
      'web_parity.launch_location': buildWorkspaceRoute(
        '/workspace/missing-server',
        sessionId: 'ses_1',
      ),
    });
    tester.view.physicalSize = const Size(1800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = WebParityAppController(
      profileStore: _EmptyProfileStore(),
      projectStore: _FakeProjectStore(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(OpenCodeRemoteApp(appController: controller));
    await tester.pumpAndSettle();

    expect(find.byType(WebParityHomeScreen), findsOneWidget);
    expect(find.byType(WebParityWorkspaceScreen), findsNothing);
    expect(controller.launchLocation, '/');
  });

  testWidgets('returning home updates the remembered launch route', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'web_parity.release_notes_enabled': false,
    });
    tester.view.physicalSize = const Size(1800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = WebParityAppController(
      profileStore: _FakeProfileStore(),
      projectStore: _FakeProjectStore(),
      workspaceControllerFactory:
          ({required profile, required directory, initialSessionId}) {
            return _FakeWorkspaceController(
              profile: profile,
              directory: directory,
              initialSessionId: initialSessionId,
            );
          },
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(OpenCodeRemoteApp(appController: controller));
    await tester.pumpAndSettle();

    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    navigator.pushNamed(buildWorkspaceRoute('/workspace/demo'));
    await tester.pumpAndSettle();

    expect(find.byType(WebParityWorkspaceScreen), findsOneWidget);
    expect(controller.launchLocation, buildWorkspaceRoute('/workspace/demo'));

    navigator.pushNamedAndRemoveUntil('/', (route) => false);
    await tester.pumpAndSettle();

    expect(find.byType(WebParityHomeScreen), findsOneWidget);
    expect(controller.launchLocation, '/');
  });
}

class _FakeProfileStore extends ServerProfileStore {
  static const ServerProfile profile = ServerProfile(
    id: 'server',
    label: 'Studio',
    baseUrl: 'http://localhost:4096',
  );

  @override
  Future<List<ServerProfile>> load() async => const <ServerProfile>[profile];
}

class _EmptyProfileStore extends ServerProfileStore {
  @override
  Future<List<ServerProfile>> load() async => const <ServerProfile>[];
}

class _FakeProjectStore extends ProjectStore {
  @override
  Future<List<ProjectTarget>> loadRecentProjects() async =>
      const <ProjectTarget>[];
}

class _FakeWorkspaceController extends WorkspaceController {
  _FakeWorkspaceController({
    required super.profile,
    required super.directory,
    String? initialSessionId,
  }) : _sessionId = initialSessionId;

  final String? _sessionId;
  bool _loading = true;

  @override
  bool get loading => _loading;

  @override
  ProjectTarget? get project =>
      ProjectTarget(directory: directory, label: 'Demo', source: 'server');

  @override
  List<ProjectTarget> get availableProjects => <ProjectTarget>[
    ProjectTarget(directory: directory, label: 'Demo', source: 'server'),
  ];

  @override
  List<SessionSummary> get sessions => _sessionId == null
      ? const <SessionSummary>[]
      : <SessionSummary>[
          SessionSummary(
            id: _sessionId,
            directory: directory,
            title: 'Remembered session',
            version: '1',
            updatedAt: DateTime.fromMillisecondsSinceEpoch(1710000001000),
          ),
        ];

  @override
  List<SessionSummary> get visibleSessions => sessions;

  @override
  Map<String, SessionStatusSummary> get statuses => _sessionId == null
      ? const <String, SessionStatusSummary>{}
      : <String, SessionStatusSummary>{
          _sessionId: const SessionStatusSummary(type: 'idle'),
        };

  @override
  String? get selectedSessionId => _sessionId;

  @override
  SessionSummary? get selectedSession =>
      sessions.isEmpty ? null : sessions.first;

  @override
  List<ChatMessage> get messages => const <ChatMessage>[];

  @override
  Future<void> load() async {
    _loading = false;
    notifyListeners();
  }
}
