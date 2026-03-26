import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile_remote/l10n/app_localizations.dart';
import 'package:opencode_mobile_remote/src/app/flavor.dart';
import 'package:opencode_mobile_remote/src/core/connection/connection_models.dart';
import 'package:opencode_mobile_remote/src/core/network/opencode_server_probe.dart';
import 'package:opencode_mobile_remote/src/core/persistence/stale_cache_store.dart';
import 'package:opencode_mobile_remote/src/core/spec/capability_registry.dart';
import 'package:opencode_mobile_remote/src/core/spec/probe_snapshot.dart';
import 'package:opencode_mobile_remote/src/design_system/app_theme.dart';
import 'package:opencode_mobile_remote/src/features/connection/connection_home_screen.dart';
import 'package:opencode_mobile_remote/src/features/home/workspace_home_screen.dart';
import 'package:opencode_mobile_remote/src/features/projects/project_catalog_service.dart';
import 'package:opencode_mobile_remote/src/features/projects/project_models.dart';
import 'package:opencode_mobile_remote/src/features/projects/project_store.dart';
import 'package:opencode_mobile_remote/src/features/projects/project_workspace_section.dart';
import 'package:opencode_mobile_remote/src/i18n/locale_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('workspace home is the ready-state project chooser surface', (
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
                catalog: _catalogWithServerProject(),
              ),
              projectStore: _FakeProjectStore(),
              cacheStore: StaleCacheStore(),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Choose a project'), findsOneWidget);
    expect(find.text('Projects on this server'), findsOneWidget);
    expect(find.text('Demo workspace'), findsOneWidget);
    expect(find.text('Server check'), findsNothing);
    expect(find.text('Live capability probe'), findsNothing);
  });

  testWidgets('project chooser stays usable when the catalog is unavailable', (
    tester,
  ) async {
    _setLargeSurface(tester);

    await tester.pumpWidget(
      _TestApp(
        child: ProjectWorkspaceSection(
          profile: const ServerProfile(
            id: 'studio',
            label: 'Studio',
            baseUrl: 'https://studio.example.com',
          ),
          onOpenProject: (_) {},
          projectCatalogService: _FakeProjectCatalogService(
            error: StateError('500 exploded while loading catalog'),
          ),
          projectStore: _FakeProjectStore(
            recentProjects: const <ProjectTarget>[
              ProjectTarget(
                directory: '/workspace/recent',
                label: 'Recent workspace',
                source: 'recent',
                lastSession: ProjectSessionHint(
                  title: 'Planning',
                  status: 'idle',
                ),
              ),
            ],
          ),
          cacheStore: StaleCacheStore(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Project list unavailable'), findsOneWidget);
    expect(
      find.text(
        "We couldn't load this server's project list just now. You can still open a recent workspace or enter a folder path.",
      ),
      findsOneWidget,
    );
    expect(find.text('Recent projects'), findsOneWidget);
    expect(find.text('Recent workspace'), findsOneWidget);
    expect(find.text('Open a folder path'), findsOneWidget);
    expect(find.text('500 exploded while loading catalog'), findsNothing);
  });

  testWidgets('project chooser can filter server and recent projects', (
    tester,
  ) async {
    _setLargeSurface(tester);

    await tester.pumpWidget(
      _TestApp(
        child: ProjectWorkspaceSection(
          profile: const ServerProfile(
            id: 'studio',
            label: 'Studio',
            baseUrl: 'https://studio.example.com',
          ),
          onOpenProject: (_) {},
          projectCatalogService: _FakeProjectCatalogService(
            catalog: ProjectCatalog(
              currentProject: null,
              projects: const <ProjectSummary>[
                ProjectSummary(
                  id: 'design',
                  directory: '/workspace/design-system',
                  worktree: '/workspace/design-system',
                  name: 'Design system',
                  vcs: 'git',
                  updatedAt: null,
                ),
                ProjectSummary(
                  id: 'api',
                  directory: '/workspace/api',
                  worktree: '/workspace/api',
                  name: 'API',
                  vcs: 'git',
                  updatedAt: null,
                ),
              ],
              pathInfo: const PathInfo(
                home: '/home/tester',
                state: '/state',
                config: '/config',
                worktree: '/workspace/design-system',
                directory: '/workspace/design-system',
              ),
              vcsInfo: const VcsInfo(branch: 'main'),
            ),
          ),
          projectStore: _FakeProjectStore(
            recentProjects: const <ProjectTarget>[
              ProjectTarget(
                directory: '/workspace/archive',
                label: 'Archive workspace',
                source: 'recent',
              ),
            ],
          ),
          cacheStore: StaleCacheStore(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('project-filter-field')),
      'design',
    );
    await tester.pumpAndSettle();

    expect(find.text('Design system'), findsOneWidget);
    expect(find.text('API'), findsNothing);
    expect(find.text('Archive workspace'), findsNothing);
  });

  testWidgets('connection screen no longer acts as a project chooser', (
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
    await StaleCacheStore().save(
      'probe::${profile.storageKey}',
      _readyReport(),
    );

    await tester.pumpWidget(
      _TestApp(
        child: ConnectionHomeScreen(
          flavor: AppFlavor.release,
          localeController: localeController,
          initialProfile: profile,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Server check'), findsOneWidget);
    expect(find.text('Ready for connection'), findsWidgets);
    expect(find.text('Choose a project'), findsNothing);
    expect(find.text('Project preview'), findsNothing);
    expect(find.text('Open project'), findsNothing);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });
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
  _FakeProjectCatalogService({this.catalog, this.error});

  final ProjectCatalog? catalog;
  final Object? error;

  @override
  Future<ProjectCatalog> fetchCatalog(ServerProfile profile) async {
    if (error != null) {
      throw error!;
    }
    return catalog!;
  }

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

class _FakeProjectStore extends ProjectStore {
  _FakeProjectStore({
    List<ProjectTarget> recentProjects = const <ProjectTarget>[],
    Set<String> pinnedProjects = const <String>{},
  }) : _recentProjects = List<ProjectTarget>.from(recentProjects),
       _pinnedProjects = Set<String>.from(pinnedProjects);

  List<ProjectTarget> _recentProjects;
  final Set<String> _pinnedProjects;

  @override
  Future<List<ProjectTarget>> loadRecentProjects() async {
    return List<ProjectTarget>.unmodifiable(_recentProjects);
  }

  @override
  Future<List<ProjectTarget>> recordRecentProject(ProjectTarget target) async {
    _recentProjects = <ProjectTarget>[
      target,
      ..._recentProjects.where((item) => item.directory != target.directory),
    ];
    return List<ProjectTarget>.unmodifiable(_recentProjects);
  }

  @override
  Future<Set<String>> loadPinnedProjects() async {
    return Set<String>.unmodifiable(_pinnedProjects);
  }

  @override
  Future<Set<String>> togglePinnedProject(String directory) async {
    if (!_pinnedProjects.add(directory)) {
      _pinnedProjects.remove(directory);
    }
    return Set<String>.unmodifiable(_pinnedProjects);
  }

  @override
  Future<void> saveLastWorkspace({
    required String serverStorageKey,
    required ProjectTarget target,
  }) async {}
}

ProjectCatalog _catalogWithServerProject() {
  return ProjectCatalog(
    currentProject: null,
    projects: const <ProjectSummary>[
      ProjectSummary(
        id: 'demo',
        directory: '/workspace/demo',
        worktree: '/workspace/demo',
        name: 'Demo workspace',
        vcs: 'git',
        updatedAt: null,
      ),
    ],
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

void _setLargeSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 2200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
