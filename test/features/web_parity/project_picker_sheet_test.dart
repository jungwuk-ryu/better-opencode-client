import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile_remote/src/core/connection/connection_models.dart';
import 'package:opencode_mobile_remote/src/design_system/app_theme.dart';
import 'package:opencode_mobile_remote/src/features/projects/project_catalog_service.dart';
import 'package:opencode_mobile_remote/src/features/projects/project_models.dart';
import 'package:opencode_mobile_remote/src/features/projects/project_store.dart';
import 'package:opencode_mobile_remote/src/features/web_parity/project_picker_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('open project sheet shows server path suggestions', (
    tester,
  ) async {
    _setLargeSurface(tester);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: ProjectPickerSheet(
            profile: const ServerProfile(
              id: 'studio',
              label: 'Studio',
              baseUrl: 'https://studio.example.com',
            ),
            projectCatalogService: _FakeProjectCatalogService(),
            projectStore: _FakeProjectStore(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Browse'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey<String>('project-picker-manual-path-field')),
      '/workspace/de',
    );
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('server-directory-suggestion-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('server-directory-suggestion-1')),
      findsOneWidget,
    );
  });
}

class _FakeProjectCatalogService extends ProjectCatalogService {
  @override
  Future<ProjectCatalog> fetchCatalog(ServerProfile profile) async {
    return ProjectCatalog(
      currentProject: null,
      projects: const <ProjectSummary>[
        ProjectSummary(
          id: 'demo',
          directory: '/workspace/demo',
          worktree: '/workspace/demo',
          name: 'Demo',
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

  @override
  Future<List<String>> suggestDirectories({
    required ServerProfile profile,
    required String input,
    PathInfo? pathInfo,
    int limit = 8,
  }) async {
    return const <String>['/workspace/design-system', '/workspace/demo'];
  }
}

class _FakeProjectStore extends ProjectStore {
  @override
  Future<List<ProjectTarget>> loadRecentProjects() async {
    return const <ProjectTarget>[];
  }

  @override
  Future<Set<String>> loadHiddenProjects() async {
    return const <String>{};
  }
}

void _setLargeSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 2200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
