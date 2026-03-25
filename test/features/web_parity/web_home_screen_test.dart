import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile_remote/src/app/app_controller.dart';
import 'package:opencode_mobile_remote/src/app/app_routes.dart';
import 'package:opencode_mobile_remote/src/app/app_scope.dart';
import 'package:opencode_mobile_remote/src/app/flavor.dart';
import 'package:opencode_mobile_remote/src/core/connection/connection_models.dart';
import 'package:opencode_mobile_remote/src/design_system/app_theme.dart';
import 'package:opencode_mobile_remote/src/features/projects/project_models.dart';
import 'package:opencode_mobile_remote/src/features/projects/project_store.dart';
import 'package:opencode_mobile_remote/src/features/web_parity/web_home_screen.dart';
import 'package:opencode_mobile_remote/src/i18n/locale_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
    'opening a recent project from home restores the remembered session route',
    (tester) async {
      final profile = ServerProfile(
        id: 'server',
        label: 'Mock',
        baseUrl: 'http://localhost:3000',
      );
      final store = _FakeProjectStore(
        lastWorkspace: const ProjectTarget(
          directory: '/workspace/demo',
          label: 'Demo',
          source: 'server',
          lastSession: ProjectSessionHint(
            id: 'ses_saved',
            title: 'Saved session',
          ),
        ),
      );
      final controller = _StaticHomeAppController(
        profile: profile,
        recent: const <ProjectTarget>[
          ProjectTarget(
            directory: '/workspace/demo',
            label: 'Demo',
            source: 'server',
          ),
        ],
      );
      addTearDown(controller.dispose);

      final observer = _RecordingNavigatorObserver();

      await tester.pumpWidget(
        AppScope(
          controller: controller,
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: WebParityHomeScreen(
              flavor: AppFlavor.debug,
              localeController: LocaleController(),
              projectStore: store,
            ),
            navigatorObservers: <NavigatorObserver>[observer],
            onGenerateRoute: (settings) => MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const SizedBox.shrink(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ActionChip, 'Demo'));
      await tester.pumpAndSettle();

      expect(
        observer.lastRouteName,
        buildWorkspaceRoute('/workspace/demo', sessionId: 'ses_saved'),
      );
      expect(store.savedTarget?.lastSession?.id, 'ses_saved');
    },
  );
}

class _StaticHomeAppController extends WebParityAppController {
  _StaticHomeAppController({required this.profile, required this.recent});

  final ServerProfile profile;
  final List<ProjectTarget> recent;

  @override
  bool get loading => false;

  @override
  ServerProfile? get selectedProfile => profile;

  @override
  List<ProjectTarget> get recentProjects => recent;
}

class _FakeProjectStore extends ProjectStore {
  _FakeProjectStore({this.lastWorkspace});

  final ProjectTarget? lastWorkspace;
  ProjectTarget? savedTarget;

  @override
  Future<ProjectTarget?> loadLastWorkspace(String serverStorageKey) async {
    return lastWorkspace;
  }

  @override
  Future<List<ProjectTarget>> recordRecentProject(ProjectTarget target) async {
    return <ProjectTarget>[target];
  }

  @override
  Future<void> saveLastWorkspace({
    required String serverStorageKey,
    required ProjectTarget target,
  }) async {
    savedTarget = target;
  }
}

class _RecordingNavigatorObserver extends NavigatorObserver {
  String? lastRouteName;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    lastRouteName = route.settings.name;
    super.didPush(route, previousRoute);
  }
}
