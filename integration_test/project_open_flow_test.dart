import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:better_opencode_client/l10n/app_localizations.dart';
import 'package:better_opencode_client/src/app/flavor.dart';
import 'package:better_opencode_client/src/core/connection/connection_models.dart';
import 'package:better_opencode_client/src/core/network/opencode_server_probe.dart';
import 'package:better_opencode_client/src/core/persistence/stale_cache_store.dart';
import 'package:better_opencode_client/src/core/spec/capability_registry.dart';
import 'package:better_opencode_client/src/core/spec/probe_snapshot.dart';
import 'package:better_opencode_client/src/design_system/app_theme.dart';
import 'package:better_opencode_client/src/features/home/workspace_home_screen.dart';
import 'package:better_opencode_client/src/features/projects/project_catalog_service.dart';
import 'package:better_opencode_client/src/features/projects/project_models.dart';
import 'package:better_opencode_client/src/features/projects/project_store.dart';
import 'package:better_opencode_client/src/features/projects/project_workspace_section.dart';
import 'package:better_opencode_client/src/features/shell/opencode_shell_screen.dart';
import 'package:better_opencode_client/src/i18n/locale_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('ready home flow opens a project from the chooser', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final localeController = LocaleController();
    addTearDown(localeController.dispose);
    final projectStore = _RecordingProjectStore();

    const profile = ServerProfile(
      id: 'studio',
      label: 'Studio',
      baseUrl: 'https://studio.example.com',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: WorkspaceHomeScreen(
          flavor: AppFlavor.release,
          localeController: localeController,
          snapshot: WorkspaceHomeSnapshot(
            savedProfiles: const <ServerProfile>[profile],
            cachedReports: <String, ServerProbeReport>{
              profile.storageKey: _readyReport(),
            },
            selectedProfile: profile,
          ),
          workspaceSectionBuilder: (context, selectedProfile, onOpenProject) {
            return ProjectWorkspaceSection(
              profile: selectedProfile,
              onOpenProject: onOpenProject,
              projectCatalogService: _FakeProjectCatalogService(
                catalog: _catalogWithCurrentProject(),
              ),
              projectStore: projectStore,
              cacheStore: StaleCacheStore(),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Current project'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open project'));
    await tester.pump();

    expect(find.byType(OpenCodeShellScreen), findsOneWidget);
    expect(projectStore.savedWorkspaces, hasLength(1));
    expect(projectStore.savedWorkspaces.single.directory, '/workspace/demo');
  });
}

class _FakeProjectCatalogService extends ProjectCatalogService {
  _FakeProjectCatalogService({required this.catalog});

  final ProjectCatalog catalog;

  @override
  Future<ProjectCatalog> fetchCatalog(ServerProfile profile) async => catalog;

  @override
  Future<ProjectTarget> inspectDirectory({
    required ServerProfile profile,
    required String directory,
  }) async {
    return ProjectTarget(
      directory: directory,
      label: directory.split('/').last,
      source: 'manual',
    );
  }
}

class _RecordingProjectStore extends ProjectStore {
  final List<ProjectTarget> savedWorkspaces = <ProjectTarget>[];

  @override
  Future<List<ProjectTarget>> loadRecentProjects() async {
    return const <ProjectTarget>[];
  }

  @override
  Future<List<ProjectTarget>> recordRecentProject(ProjectTarget target) async {
    return <ProjectTarget>[target];
  }

  @override
  Future<Set<String>> loadPinnedProjects() async {
    return const <String>{};
  }

  @override
  Future<void> saveLastWorkspace({
    required String serverStorageKey,
    required ProjectTarget target,
  }) async {
    savedWorkspaces.add(target);
  }
}

ProjectCatalog _catalogWithCurrentProject() {
  return ProjectCatalog(
    currentProject: const ProjectSummary(
      id: 'demo',
      directory: '/workspace/demo',
      worktree: '/workspace/demo',
      name: 'Demo workspace',
      vcs: 'git',
      updatedAt: null,
    ),
    projects: const <ProjectSummary>[],
    pathInfo: const PathInfo(
      home: '/home/tester',
      state: '/state',
      config: '/config',
      worktree: '/workspace/demo',
      directory: '/workspace/demo',
    ),
    vcsInfo: const VcsInfo(branch: 'main'),
  );
}

ServerProbeReport _readyReport() {
  final snapshot = ProbeSnapshot(
    name: 'Studio Server',
    version: '0.1.0',
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
      '/doc': ProbeEndpointResult(
        path: '/doc',
        status: ProbeStatus.success,
        statusCode: 200,
      ),
    },
  );

  return ServerProbeReport(
    snapshot: snapshot,
    capabilityRegistry: CapabilityRegistry.fromSnapshot(snapshot),
    classification: ConnectionProbeClassification.ready,
    summary: 'Ready',
    checkedAt: DateTime(2026, 3, 19, 10),
    missingCapabilities: const <String>[],
    discoveredExperimentalPaths: const <String>[],
    sseReady: true,
  );
}
