import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile_remote/src/app/app_controller.dart';
import 'package:opencode_mobile_remote/src/app/app_routes.dart';
import 'package:opencode_mobile_remote/src/app/app_scope.dart';
import 'package:opencode_mobile_remote/src/app/flavor.dart';
import 'package:opencode_mobile_remote/src/core/connection/connection_models.dart';
import 'package:opencode_mobile_remote/src/core/network/opencode_server_probe.dart';
import 'package:opencode_mobile_remote/src/core/spec/capability_registry.dart';
import 'package:opencode_mobile_remote/src/core/spec/probe_snapshot.dart';
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
      _setLargeSurface(tester);
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

  testWidgets('see servers sheet shows status and server details inline', (
    tester,
  ) async {
    _setLargeSurface(tester);
    final alpha = ServerProfile(
      id: 'alpha',
      label: 'Alpha',
      baseUrl: 'https://alpha.example.com',
      username: 'ci-bot',
    );
    final beta = ServerProfile(
      id: 'beta',
      label: 'Beta',
      baseUrl: 'https://beta.example.com',
    );
    final controller = _MutableHomeAppController(
      profiles: <ServerProfile>[alpha, beta],
      selected: alpha,
      reports: <String, ServerProbeReport>{
        alpha.storageKey: _probeReport(
          alpha,
          version: '1.2.3',
          classification: ConnectionProbeClassification.ready,
        ),
        beta.storageKey: _probeReport(
          beta,
          version: '0.9.0',
          classification: ConnectionProbeClassification.authFailure,
        ),
      },
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      AppScope(
        controller: controller,
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: WebParityHomeScreen(
            flavor: AppFlavor.debug,
            localeController: LocaleController(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'See Servers'));
    await tester.pumpAndSettle();

    expect(find.text('Manage Servers'), findsNothing);
    expect(find.text('Add Server'), findsOneWidget);
    expect(find.text('https://alpha.example.com'), findsOneWidget);
    expect(find.text('https://beta.example.com'), findsOneWidget);
    expect(find.text('v1.2.3'), findsOneWidget);
    expect(find.text('ci-bot'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Ready'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });

  testWidgets('see servers sheet can add delete and reorder servers', (
    tester,
  ) async {
    _setLargeSurface(tester);
    final alpha = ServerProfile(
      id: 'alpha',
      label: 'Alpha',
      baseUrl: 'https://alpha.example.com',
    );
    final beta = ServerProfile(
      id: 'beta',
      label: 'Beta',
      baseUrl: 'https://beta.example.com',
    );
    final controller = _MutableHomeAppController(
      profiles: <ServerProfile>[alpha, beta],
      selected: alpha,
      reports: <String, ServerProbeReport>{
        alpha.storageKey: _probeReport(alpha, version: '1.0.0'),
        beta.storageKey: _probeReport(beta, version: '1.0.1'),
      },
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      AppScope(
        controller: controller,
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: WebParityHomeScreen(
            flavor: AppFlavor.debug,
            localeController: LocaleController(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'See Servers'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('servers-sheet-select-beta')),
    );
    await tester.pumpAndSettle();
    expect(controller.selectedProfile?.id, 'beta');

    await tester.tap(
      find.byKey(const ValueKey<String>('servers-sheet-add-button')),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('servers-editor-label-field')),
      'Gamma',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('servers-editor-url-field')),
      'https://gamma.example.com',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('servers-editor-save-button')),
    );
    await tester.pumpAndSettle();

    final gammaId = controller.selectedProfile?.id;
    expect(gammaId, isNotNull);
    expect(
      find.byKey(ValueKey<String>('servers-sheet-card-$gammaId')),
      findsOneWidget,
    );
    expect(controller.profiles.first.id, gammaId);

    await tester.tap(
      find.byKey(ValueKey<String>('servers-sheet-move-down-$gammaId')),
    );
    await tester.pumpAndSettle();
    expect(controller.profiles[1].id, gammaId);

    await tester.tap(
      find.byKey(const ValueKey<String>('servers-sheet-delete-beta')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(controller.profiles.any((profile) => profile.id == 'beta'), isFalse);
  });
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

class _MutableHomeAppController extends WebParityAppController {
  _MutableHomeAppController({
    required List<ServerProfile> profiles,
    required ServerProfile selected,
    required Map<String, ServerProbeReport> reports,
  }) : _profiles = List<ServerProfile>.from(profiles),
       _selectedProfile = selected,
       _reports = Map<String, ServerProbeReport>.from(reports);

  List<ServerProfile> _profiles;
  ServerProfile? _selectedProfile;
  Map<String, ServerProbeReport> _reports;

  @override
  bool get loading => false;

  @override
  List<ServerProfile> get profiles =>
      List<ServerProfile>.unmodifiable(_profiles);

  @override
  Map<String, ServerProbeReport> get reports =>
      Map<String, ServerProbeReport>.unmodifiable(_reports);

  @override
  ServerProfile? get selectedProfile => _selectedProfile;

  @override
  ServerProbeReport? get selectedReport {
    final selectedProfile = _selectedProfile;
    if (selectedProfile == null) {
      return null;
    }
    return _reports[selectedProfile.storageKey];
  }

  @override
  Future<void> selectProfile(ServerProfile profile) async {
    for (final candidate in _profiles) {
      if (candidate.id == profile.id) {
        _selectedProfile = candidate;
        notifyListeners();
        return;
      }
    }
  }

  @override
  Future<ServerProfile> saveProfile(ServerProfile profile) async {
    final existingIndex = _profiles.indexWhere(
      (candidate) => candidate.id == profile.id,
    );
    if (existingIndex >= 0) {
      _profiles[existingIndex] = profile;
    } else {
      _profiles.insert(0, profile);
    }
    _selectedProfile = profile;
    _reports = <String, ServerProbeReport>{
      ..._reports,
      profile.storageKey: _probeReport(profile, version: '2.0.0'),
    };
    notifyListeners();
    return profile;
  }

  @override
  Future<void> deleteServerProfile(ServerProfile profile) async {
    _profiles = _profiles
        .where((candidate) => candidate.id != profile.id)
        .toList(growable: false);
    _reports.remove(profile.storageKey);
    if (_selectedProfile?.id == profile.id) {
      _selectedProfile = _profiles.isEmpty ? null : _profiles.first;
    }
    notifyListeners();
  }

  @override
  Future<void> moveProfile(String profileId, int offset) async {
    final currentIndex = _profiles.indexWhere(
      (candidate) => candidate.id == profileId,
    );
    if (currentIndex < 0) {
      return;
    }
    final nextIndex = (currentIndex + offset).clamp(0, _profiles.length - 1);
    if (nextIndex == currentIndex) {
      return;
    }
    final item = _profiles.removeAt(currentIndex);
    _profiles.insert(nextIndex, item);
    notifyListeners();
  }

  @override
  Future<void> refreshProbe(ServerProfile profile) async {
    _reports = <String, ServerProbeReport>{
      ..._reports,
      profile.storageKey: _probeReport(profile, version: '9.9.9'),
    };
    notifyListeners();
  }
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

ServerProbeReport _probeReport(
  ServerProfile profile, {
  required String version,
  ConnectionProbeClassification classification =
      ConnectionProbeClassification.ready,
}) {
  final snapshot = ProbeSnapshot(
    name: '${profile.effectiveLabel} server',
    version: version,
    paths: const <String>{
      '/global/health',
      '/doc',
      '/config',
      '/config/providers',
      '/provider',
      '/agent',
    },
    endpoints: const <String, ProbeEndpointResult>{
      '/global/health': ProbeEndpointResult(
        path: '/global/health',
        status: ProbeStatus.success,
        statusCode: 200,
      ),
    },
  );
  return ServerProbeReport(
    snapshot: snapshot,
    capabilityRegistry: CapabilityRegistry.fromSnapshot(snapshot),
    classification: classification,
    summary: 'unused',
    checkedAt: DateTime(2026, 3, 26, 16, 9),
    missingCapabilities: const <String>[],
    discoveredExperimentalPaths: const <String>[],
    sseReady: classification == ConnectionProbeClassification.ready,
    authScheme: classification == ConnectionProbeClassification.authFailure
        ? 'basic'
        : null,
  );
}

class _RecordingNavigatorObserver extends NavigatorObserver {
  String? lastRouteName;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    lastRouteName = route.settings.name;
    super.didPush(route, previousRoute);
  }
}

void _setLargeSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 2200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
