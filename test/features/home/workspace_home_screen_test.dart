import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:better_opencode_client/l10n/app_localizations.dart';
import 'package:better_opencode_client/src/app/flavor.dart';
import 'package:better_opencode_client/src/core/connection/connection_models.dart';
import 'package:better_opencode_client/src/core/network/opencode_server_probe.dart';
import 'package:better_opencode_client/src/core/persistence/server_profile_store.dart';
import 'package:better_opencode_client/src/core/persistence/stale_cache_store.dart';
import 'package:better_opencode_client/src/core/spec/capability_registry.dart';
import 'package:better_opencode_client/src/core/spec/probe_snapshot.dart';
import 'package:better_opencode_client/src/design_system/app_theme.dart';
import 'package:better_opencode_client/src/features/home/workspace_home_screen.dart';
import 'package:better_opencode_client/src/features/projects/project_catalog_service.dart';
import 'package:better_opencode_client/src/features/projects/project_store.dart';
import 'package:better_opencode_client/src/features/projects/project_models.dart';
import 'package:better_opencode_client/src/features/shell/opencode_shell_screen.dart';
import 'package:better_opencode_client/src/features/shell/server_workspace_shell_screen.dart';
import 'package:better_opencode_client/src/i18n/locale_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../test_helpers/responsive_viewports.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('home first run renders across the responsive viewport matrix', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final localeController = LocaleController();
    addTearDown(localeController.dispose);

    for (final viewport in kResponsiveLayoutViewports) {
      await applyResponsiveTestViewport(tester, viewport.size);
      await tester.pumpWidget(
        _TestApp(
          child: WorkspaceHomeScreen(
            flavor: AppFlavor.debug,
            localeController: localeController,
            snapshot: const WorkspaceHomeSnapshot(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final exception = tester.takeException();
      expect(
        exception,
        isNull,
        reason: 'home first-run layout failed on ${viewport.name}',
      );
      expect(
        find.byType(WorkspaceHomeScreen),
        findsOneWidget,
        reason: viewport.name,
      );
      expect(find.text('Workspace'), findsOneWidget, reason: viewport.name);
      expect(
        find.text('better-opencode-client (BOC)'),
        findsOneWidget,
        reason: viewport.name,
      );
      expect(find.text('Add server'), findsWidgets, reason: viewport.name);
    }
  });

  testWidgets(
    'home workspace-ready state renders across the responsive viewport matrix',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final localeController = LocaleController();
      addTearDown(localeController.dispose);

      const profile = ServerProfile(
        id: 'alpha',
        label: 'Studio',
        baseUrl: 'https://studio.example.com',
      );

      for (final viewport in kResponsiveLayoutViewports) {
        await applyResponsiveTestViewport(tester, viewport.size);
        await tester.pumpWidget(
          _TestApp(
            child: WorkspaceHomeScreen(
              flavor: AppFlavor.debug,
              localeController: localeController,
              snapshot: WorkspaceHomeSnapshot(
                savedProfiles: const <ServerProfile>[profile],
                cachedReports: <String, ServerProbeReport>{
                  profile.storageKey: _readyReport(),
                },
                selectedProfile: profile,
              ),
              workspaceSectionBuilder:
                  (context, selectedProfile, onOpenProject) {
                    return const Placeholder(
                      key: Key('workspace-section-seam'),
                    );
                  },
            ),
          ),
        );
        await tester.pumpAndSettle();

        final exception = tester.takeException();
        expect(
          exception,
          isNull,
          reason: 'home ready-state layout failed on ${viewport.name}',
        );
        expect(
          find.text('Back to servers'),
          findsOneWidget,
          reason: viewport.name,
        );
        expect(
          find.byKey(const Key('workspace-section-seam')),
          findsOneWidget,
          reason: viewport.name,
        );
        expect(find.text('Studio'), findsWidgets, reason: viewport.name);
      }
    },
  );

  testWidgets('first run shows branded home scaffold without probe jargon', (
    tester,
  ) async {
    final localeController = LocaleController();
    addTearDown(localeController.dispose);

    await tester.pumpWidget(
      _TestApp(
        child: WorkspaceHomeScreen(
          flavor: AppFlavor.debug,
          localeController: localeController,
          snapshot: const WorkspaceHomeSnapshot(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Workspace'), findsOneWidget);
    expect(find.text('better-opencode-client (BOC)'), findsOneWidget);
    expect(find.text('Add server'), findsWidgets);
    expect(find.text('Saved servers'), findsOneWidget);
    expect(find.text('Choose a server'), findsWidgets);
    expect(
      find.text('Select a server from the list or add a new one.'),
      findsWidgets,
    );
  });

  testWidgets('saved ready server shows workspace section seam', (
    tester,
  ) async {
    final localeController = LocaleController();
    addTearDown(localeController.dispose);

    const profile = ServerProfile(
      id: 'alpha',
      label: 'Studio',
      baseUrl: 'https://studio.example.com',
    );
    final report = _readyReport();

    await tester.pumpWidget(
      _TestApp(
        child: WorkspaceHomeScreen(
          flavor: AppFlavor.debug,
          localeController: localeController,
          snapshot: WorkspaceHomeSnapshot(
            savedProfiles: const <ServerProfile>[profile],
            recentConnections: <RecentConnection>[
              RecentConnection(
                id: 'alpha',
                label: 'Studio',
                baseUrl: 'https://studio.example.com',
                attemptedAt: DateTime(2026, 3, 19, 9, 0),
                classification: ConnectionProbeClassification.ready,
                summary: 'Ready',
              ),
            ],
            cachedReports: <String, ServerProbeReport>{
              profile.storageKey: report,
            },
            selectedProfile: profile,
          ),
          workspaceSectionBuilder: (context, selectedProfile, onOpenProject) {
            return const Placeholder(key: Key('workspace-section-seam'));
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Studio'), findsWidgets);
    expect(find.text('Back to servers'), findsOneWidget);
    expect(find.byKey(const Key('workspace-section-seam')), findsOneWidget);
  });

  testWidgets('saved ready server can continue straight into the chat shell', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final localeController = LocaleController();
    addTearDown(localeController.dispose);

    const profile = ServerProfile(
      id: 'alpha',
      label: 'Studio',
      baseUrl: 'https://studio.example.com',
    );

    await tester.pumpWidget(
      _TestApp(
        child: WorkspaceHomeScreen(
          flavor: AppFlavor.debug,
          localeController: localeController,
          projectCatalogService: _FakeProjectCatalogService(
            catalog: _catalogWithCurrentProject(),
          ),
          snapshot: WorkspaceHomeSnapshot(
            savedProfiles: const <ServerProfile>[profile],
            cachedReports: <String, ServerProbeReport>{
              profile.storageKey: _readyReport(),
            },
            selectedProfile: profile,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final continueButton = find.byKey(
      const ValueKey<String>('home-workspace-continue-button'),
    );
    expect(continueButton, findsOneWidget);

    await tester.ensureVisible(continueButton);
    await tester.tap(continueButton);
    await tester.pumpAndSettle();

    expect(find.byType(ServerWorkspaceShellScreen), findsOneWidget);
    expect(find.byType(OpenCodeShellScreen), findsOneWidget);
  });

  testWidgets(
    'launch auto-resumes straight into the last remembered session shell',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final localeController = LocaleController();
      addTearDown(localeController.dispose);

      const profile = ServerProfile(
        id: 'alpha',
        label: 'Studio',
        baseUrl: 'https://studio.example.com',
      );
      const recentWorkspace = ProjectTarget(
        directory: '/workspace/demo',
        label: 'Demo workspace',
        source: 'server',
        lastSession: ProjectSessionHint(
          title: 'Sprint planning',
          status: 'running',
        ),
      );

      await tester.pumpWidget(
        _TestApp(
          child: WorkspaceHomeScreen(
            flavor: AppFlavor.debug,
            localeController: localeController,
            profileStore: _FakeProfileStore(
              savedProfiles: const <ServerProfile>[profile],
            ),
            cacheStore: _FakeCacheStore(
              entries: <String, StaleCacheEntry>{
                'probe::${profile.storageKey}': StaleCacheEntry(
                  payloadJson: jsonEncode(_readyReport().toJson()),
                  signature: 'ready-report',
                  fetchedAt: DateTime(2026, 3, 21, 9),
                ),
              },
            ),
            projectStore: _FakeProjectStore(
              lastWorkspaceByServerKey: <String, ProjectTarget?>{
                profile.storageKey: recentWorkspace,
              },
            ),
            projectCatalogService: _FakeProjectCatalogService(
              catalog: _catalogWithCurrentProject(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ServerWorkspaceShellScreen), findsOneWidget);
      expect(find.text('Continue'), findsNothing);
    },
  );

  testWidgets('workspace header can return to the server selection state', (
    tester,
  ) async {
    final localeController = LocaleController();
    addTearDown(localeController.dispose);

    const profile = ServerProfile(
      id: 'alpha',
      label: 'Studio',
      baseUrl: 'https://studio.example.com',
    );

    await tester.pumpWidget(
      _TestApp(
        child: WorkspaceHomeScreen(
          flavor: AppFlavor.debug,
          localeController: localeController,
          snapshot: WorkspaceHomeSnapshot(
            savedProfiles: const <ServerProfile>[profile],
            cachedReports: <String, ServerProbeReport>{
              profile.storageKey: _readyReport(),
            },
            selectedProfile: profile,
          ),
          workspaceSectionBuilder: (context, selectedProfile, onOpenProject) {
            return const Placeholder(key: Key('workspace-section-seam'));
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Back to servers'), findsOneWidget);
    expect(find.byKey(const Key('workspace-section-seam')), findsOneWidget);

    await tester.tap(find.text('Back to servers'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('workspace-section-seam')), findsNothing);
    expect(find.text('Choose a server'), findsWidgets);
  });

  testWidgets(
    'unsupported server can still open the workspace chooser surface',
    (tester) async {
      final localeController = LocaleController();
      addTearDown(localeController.dispose);

      const profile = ServerProfile(
        id: 'alpha',
        label: 'Studio',
        baseUrl: 'https://studio.example.com',
      );
      final report = ServerProbeReport(
        snapshot: ProbeSnapshot(
          name: 'Studio Server',
          version: '1.2.27',
          paths: const <String>{
            '/global/health',
            '/config',
            '/config/providers',
            '/provider',
            '/agent',
            '/project',
            '/project/current',
            '/session',
            '/session/status',
            '/path',
            '/vcs',
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
        ),
        capabilityRegistry: CapabilityRegistry.fromSnapshot(
          ProbeSnapshot(
            name: 'Studio Server',
            version: '1.2.27',
            paths: const <String>{
              '/global/health',
              '/config',
              '/config/providers',
              '/provider',
              '/agent',
              '/project',
              '/project/current',
              '/session',
              '/session/status',
              '/path',
              '/vcs',
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
          ),
        ),
        classification: ConnectionProbeClassification.unsupportedCapabilities,
        summary: 'Needs attention',
        checkedAt: DateTime(2026, 3, 19, 9, 0),
        missingCapabilities: const <String>[],
        discoveredExperimentalPaths: const <String>[],
        sseReady: false,
      );

      await tester.pumpWidget(
        _TestApp(
          child: WorkspaceHomeScreen(
            flavor: AppFlavor.debug,
            localeController: localeController,
            snapshot: WorkspaceHomeSnapshot(
              savedProfiles: const <ServerProfile>[profile],
              cachedReports: <String, ServerProbeReport>{
                profile.storageKey: report,
              },
              selectedProfile: profile,
            ),
            workspaceSectionBuilder: (context, selectedProfile, onOpenProject) {
              return const Placeholder(
                key: Key('workspace-section-seam-unsupported'),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('workspace-section-seam-unsupported')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'spec fetch failures do not present a generic update-required warning',
    (tester) async {
      final localeController = LocaleController();
      addTearDown(localeController.dispose);

      const profile = ServerProfile(
        id: 'alpha',
        label: 'Studio',
        baseUrl: 'https://studio.example.com',
      );

      await tester.pumpWidget(
        _TestApp(
          child: WorkspaceHomeScreen(
            flavor: AppFlavor.debug,
            localeController: localeController,
            snapshot: WorkspaceHomeSnapshot(
              savedProfiles: const <ServerProfile>[profile],
              cachedReports: <String, ServerProbeReport>{
                profile.storageKey: _specFetchFailureReport(),
              },
              selectedProfile: profile,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Update required'), findsNothing);
      expect(
        find.text(
          'The server is reachable, but the OpenAPI spec could not be fetched or parsed cleanly.',
        ),
        findsWidgets,
      );
    },
  );
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.dark(),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      home: child,
    );
  }
}

class _FakeProjectCatalogService extends ProjectCatalogService {
  _FakeProjectCatalogService({required this.catalog});

  final ProjectCatalog catalog;

  @override
  Future<ProjectCatalog> fetchCatalog(ServerProfile profile) async => catalog;
}

class _FakeProfileStore extends ServerProfileStore {
  _FakeProfileStore({required this.savedProfiles});

  final List<ServerProfile> savedProfiles;

  @override
  Future<List<ServerProfile>> load() async => savedProfiles;

  @override
  Future<List<RecentConnection>> loadRecentConnections() async =>
      const <RecentConnection>[];

  @override
  Future<Set<String>> loadPinnedProfiles() async => const <String>{};
}

class _FakeCacheStore extends StaleCacheStore {
  _FakeCacheStore({required this.entries});

  final Map<String, StaleCacheEntry> entries;

  @override
  Future<StaleCacheEntry?> load(String key) async => entries[key];
}

class _FakeProjectStore extends ProjectStore {
  _FakeProjectStore({required this.lastWorkspaceByServerKey});

  final Map<String, ProjectTarget?> lastWorkspaceByServerKey;

  @override
  Future<ProjectTarget?> loadLastWorkspace(String serverStorageKey) async {
    return lastWorkspaceByServerKey[serverStorageKey];
  }

  @override
  Future<List<ProjectTarget>> loadRecentProjects() async {
    return lastWorkspaceByServerKey.values.whereType<ProjectTarget>().toList(
      growable: false,
    );
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
    lastWorkspaceByServerKey[serverStorageKey] = target;
  }
}

ProjectCatalog _catalogWithCurrentProject() {
  return const ProjectCatalog(
    currentProject: ProjectSummary(
      id: 'demo',
      directory: '/workspace/demo',
      worktree: '/workspace/demo',
      name: 'Demo workspace',
      vcs: 'git',
      updatedAt: null,
    ),
    projects: <ProjectSummary>[],
    pathInfo: PathInfo(
      home: '/home/tester',
      state: '/state',
      config: '/config',
      worktree: '/workspace/demo',
      directory: '/workspace/demo',
    ),
    vcsInfo: VcsInfo(branch: 'main'),
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
    checkedAt: DateTime(2026, 3, 19, 9, 0),
    missingCapabilities: const <String>[],
    discoveredExperimentalPaths: const <String>[],
    sseReady: true,
  );
}

ServerProbeReport _specFetchFailureReport() {
  final ready = _readyReport();
  return ServerProbeReport(
    snapshot: ready.snapshot,
    capabilityRegistry: ready.capabilityRegistry,
    classification: ConnectionProbeClassification.specFetchFailure,
    summary: 'Spec fetch failure',
    checkedAt: ready.checkedAt,
    missingCapabilities: ready.missingCapabilities,
    discoveredExperimentalPaths: ready.discoveredExperimentalPaths,
    sseReady: false,
  );
}
