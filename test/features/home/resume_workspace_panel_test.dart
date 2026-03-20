import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile_remote/l10n/app_localizations.dart';
import 'package:opencode_mobile_remote/src/app/flavor.dart';
import 'package:opencode_mobile_remote/src/core/connection/connection_models.dart';
import 'package:opencode_mobile_remote/src/core/network/opencode_server_probe.dart';
import 'package:opencode_mobile_remote/src/core/spec/capability_registry.dart';
import 'package:opencode_mobile_remote/src/core/spec/probe_snapshot.dart';
import 'package:opencode_mobile_remote/src/design_system/app_theme.dart';
import 'package:opencode_mobile_remote/src/features/home/workspace_home_screen.dart';
import 'package:opencode_mobile_remote/src/features/projects/project_store.dart';
import 'package:opencode_mobile_remote/src/features/projects/project_catalog_service.dart';
import 'package:opencode_mobile_remote/src/features/projects/project_models.dart';
import 'package:opencode_mobile_remote/src/features/shell/opencode_shell_screen.dart';
import 'package:opencode_mobile_remote/src/i18n/locale_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('home shows a prominent resume workspace panel', (tester) async {
    _setLargeSurface(tester);
    final localeController = LocaleController();
    addTearDown(localeController.dispose);

    const profile = ServerProfile(
      id: 'studio',
      label: 'Studio',
      baseUrl: 'https://studio.example.com',
    );

    await tester.pumpWidget(
      _TestApp(
        child: WorkspaceHomeScreen(
          flavor: AppFlavor.release,
          localeController: localeController,
          snapshot: WorkspaceHomeSnapshot(
            savedProfiles: const <ServerProfile>[profile],
            cachedReports: <String, ServerProbeReport>{
              profile.storageKey: _readyReport(),
            },
            selectedProfile: profile,
            recentWorkspace: const ProjectTarget(
              directory: '/workspace/demo',
              label: 'Demo workspace',
              source: 'server',
              lastSession: ProjectSessionHint(
                title: 'Sprint planning',
                status: 'running',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('resume-workspace-panel')), findsOneWidget);
    expect(find.text('Resume last workspace'), findsWidgets);
    expect(find.text('Project: Demo workspace'), findsOneWidget);
    expect(find.text('Last session: Sprint planning'), findsOneWidget);
    expect(find.byType(OpenCodeShellScreen), findsNothing);
  });

  testWidgets(
    'status-only last session hint falls back to opening the last project',
    (tester) async {
      _setLargeSurface(tester);
      final localeController = LocaleController();
      addTearDown(localeController.dispose);

      const profile = ServerProfile(
        id: 'studio',
        label: 'Studio',
        baseUrl: 'https://studio.example.com',
      );

      await tester.pumpWidget(
        _TestApp(
          child: WorkspaceHomeScreen(
            flavor: AppFlavor.release,
            localeController: localeController,
            snapshot: WorkspaceHomeSnapshot(
              savedProfiles: const <ServerProfile>[profile],
              cachedReports: <String, ServerProbeReport>{
                profile.storageKey: _readyReport(),
              },
              selectedProfile: profile,
              recentWorkspace: const ProjectTarget(
                directory: '/workspace/demo',
                label: 'Demo workspace',
                source: 'server',
                lastSession: ProjectSessionHint(status: 'running'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('resume-workspace-panel')), findsOneWidget);
      expect(find.text('Open last project'), findsWidgets);
      expect(find.text('Project: Demo workspace'), findsOneWidget);
      expect(find.textContaining('Last session:'), findsNothing);
      expect(find.textContaining('Status:'), findsNothing);
      expect(find.byType(OpenCodeShellScreen), findsNothing);
    },
  );

  testWidgets('missing remembered project falls back to chooser with message', (
    tester,
  ) async {
    _setLargeSurface(tester);
    final localeController = LocaleController();
    addTearDown(localeController.dispose);

    const profile = ServerProfile(
      id: 'studio',
      label: 'Studio',
      baseUrl: 'https://studio.example.com',
    );

    await tester.pumpWidget(
      _TestApp(
        child: WorkspaceHomeScreen(
          flavor: AppFlavor.release,
          localeController: localeController,
          projectCatalogService: _FakeProjectCatalogService(
            const ProjectCatalog(
              currentProject: null,
              projects: <ProjectSummary>[],
              pathInfo: null,
              vcsInfo: null,
            ),
          ),
          snapshot: WorkspaceHomeSnapshot(
            savedProfiles: const <ServerProfile>[profile],
            cachedReports: <String, ServerProbeReport>{
              profile.storageKey: _readyReport(),
            },
            selectedProfile: profile,
            recentWorkspace: const ProjectTarget(
              directory: '/workspace/missing',
              label: 'Missing workspace',
              source: 'server',
              lastSession: ProjectSessionHint(
                title: 'Yesterday',
                status: 'complete',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('resume-workspace-panel')),
        matching: find.byType(ElevatedButton),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Your last workspace is no longer available. Choose a project to continue.',
      ),
      findsOneWidget,
    );
    expect(find.byType(OpenCodeShellScreen), findsNothing);
  });

  testWidgets(
    'switching profiles clears stale remembered workspace immediately',
    (tester) async {
      _setLargeSurface(tester);
      final localeController = LocaleController();
      addTearDown(localeController.dispose);

      const studio = ServerProfile(
        id: 'studio',
        label: 'Studio',
        baseUrl: 'https://studio.example.com',
      );
      const cloud = ServerProfile(
        id: 'cloud',
        label: 'Cloud',
        baseUrl: 'https://cloud.example.com',
      );

      final projectStore = _FakeProjectStore(<String, ProjectTarget?>{
        studio.storageKey: const ProjectTarget(
          directory: '/workspace/studio',
          label: 'Studio workspace',
          source: 'server',
          lastSession: ProjectSessionHint(
            title: 'Studio session',
            status: 'run',
          ),
        ),
        cloud.storageKey: null,
      });

      await tester.pumpWidget(
        _TestApp(
          child: WorkspaceHomeScreen(
            flavor: AppFlavor.release,
            localeController: localeController,
            projectStore: projectStore,
            snapshot: WorkspaceHomeSnapshot(
              savedProfiles: const <ServerProfile>[studio, cloud],
              cachedReports: <String, ServerProbeReport>{
                studio.storageKey: _readyReport(),
                cloud.storageKey: _readyReport(),
              },
              selectedProfile: studio,
              recentWorkspace: const ProjectTarget(
                directory: '/workspace/studio',
                label: 'Studio workspace',
                source: 'server',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('resume-workspace-panel')), findsOneWidget);
      expect(find.text('Project: Studio workspace'), findsOneWidget);

      await tester.tap(find.text('Cloud'));
      await tester.pump();

      expect(find.byKey(const Key('resume-workspace-panel')), findsNothing);
      expect(find.textContaining('Studio workspace'), findsNothing);
    },
  );

  testWidgets(
    'stale resume completion cannot open the old workspace after switching profiles',
    (tester) async {
      _setLargeSurface(tester);
      final localeController = LocaleController();
      addTearDown(localeController.dispose);

      const studio = ServerProfile(
        id: 'studio',
        label: 'Studio',
        baseUrl: 'https://studio.example.com',
      );
      const cloud = ServerProfile(
        id: 'cloud',
        label: 'Cloud',
        baseUrl: 'https://cloud.example.com',
      );

      final studioCatalogStarted = Completer<void>();
      final studioCatalogGate = Completer<void>();
      final projectStore = _FakeProjectStore(<String, ProjectTarget?>{
        studio.storageKey: const ProjectTarget(
          directory: '/workspace/studio',
          label: 'Studio workspace',
          source: 'server',
        ),
        cloud.storageKey: const ProjectTarget(
          directory: '/workspace/cloud',
          label: 'Cloud workspace',
          source: 'server',
        ),
      });
      final projectCatalogService = _ControlledProjectCatalogService(
        catalogsByStorageKey: <String, ProjectCatalog>{
          studio.storageKey: const ProjectCatalog(
            currentProject: ProjectSummary(
              id: 'studio-project',
              directory: '/workspace/studio',
              worktree: '/workspace/studio',
              name: 'Studio workspace',
              vcs: 'git',
              updatedAt: null,
            ),
            projects: <ProjectSummary>[],
            pathInfo: null,
            vcsInfo: null,
          ),
        },
        gateByStorageKey: <String, Completer<void>>{
          studio.storageKey: studioCatalogGate,
        },
        startedByStorageKey: <String, Completer<void>>{
          studio.storageKey: studioCatalogStarted,
        },
      );

      await tester.pumpWidget(
        _TestApp(
          child: WorkspaceHomeScreen(
            flavor: AppFlavor.release,
            localeController: localeController,
            projectStore: projectStore,
            projectCatalogService: projectCatalogService,
            workspaceSectionBuilder: (context, profile, onOpenProject) {
              return const SizedBox.shrink();
            },
            snapshot: WorkspaceHomeSnapshot(
              savedProfiles: const <ServerProfile>[studio, cloud],
              cachedReports: <String, ServerProbeReport>{
                studio.storageKey: _readyReport(),
                cloud.storageKey: _readyReport(),
              },
              selectedProfile: studio,
              recentWorkspace: const ProjectTarget(
                directory: '/workspace/studio',
                label: 'Studio workspace',
                source: 'server',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('resume-workspace-panel')),
          matching: find.byType(ElevatedButton),
        ),
      );
      await tester.pump();
      await studioCatalogStarted.future;

      await tester.tap(find.text('Cloud'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('resume-workspace-panel')), findsNothing);
      expect(find.byType(OpenCodeShellScreen), findsNothing);

      studioCatalogGate.complete();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('resume-workspace-panel')), findsNothing);
      expect(find.byType(OpenCodeShellScreen), findsNothing);
      expect(find.textContaining('Studio workspace'), findsNothing);
    },
  );
}

class _FakeProjectStore extends ProjectStore {
  _FakeProjectStore(this._recentWorkspaces);

  final Map<String, ProjectTarget?> _recentWorkspaces;

  @override
  Future<ProjectTarget?> loadLastWorkspace(String serverStorageKey) async {
    return _recentWorkspaces[serverStorageKey];
  }
}

void _setLargeSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 2200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

class _FakeProjectCatalogService extends ProjectCatalogService {
  _FakeProjectCatalogService(this._catalog);

  final ProjectCatalog _catalog;

  @override
  Future<ProjectCatalog> fetchCatalog(ServerProfile profile) async => _catalog;

  @override
  void dispose() {}
}

class _ControlledProjectCatalogService extends ProjectCatalogService {
  _ControlledProjectCatalogService({
    required this.catalogsByStorageKey,
    Map<String, Completer<void>>? gateByStorageKey,
    Map<String, Completer<void>>? startedByStorageKey,
  }) : gateByStorageKey = gateByStorageKey ?? const <String, Completer<void>>{},
       startedByStorageKey =
           startedByStorageKey ?? const <String, Completer<void>>{};

  final Map<String, ProjectCatalog> catalogsByStorageKey;
  final Map<String, Completer<void>> gateByStorageKey;
  final Map<String, Completer<void>> startedByStorageKey;

  @override
  Future<ProjectCatalog> fetchCatalog(ServerProfile profile) async {
    final storageKey = profile.storageKey;
    final started = startedByStorageKey[storageKey];
    if (started != null && !started.isCompleted) {
      started.complete();
    }
    final gate = gateByStorageKey[storageKey];
    if (gate != null) {
      await gate.future;
    }
    return catalogsByStorageKey[storageKey] ??
        const ProjectCatalog(
          currentProject: null,
          projects: <ProjectSummary>[],
          pathInfo: null,
          vcsInfo: null,
        );
  }

  @override
  void dispose() {}
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
