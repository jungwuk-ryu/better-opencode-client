import 'package:flutter_test/flutter_test.dart';
import 'package:better_opencode_client/src/features/projects/project_models.dart';
import 'package:better_opencode_client/src/features/projects/project_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('records recent projects without duplicating directories', () async {
    final store = ProjectStore();
    const target = ProjectTarget(
      directory: '/workspace/demo',
      label: 'Demo',
      source: 'server',
    );

    await store.recordRecentProject(target);
    final recent = await store.recordRecentProject(target);

    expect(recent, hasLength(1));
    expect(recent.single.directory, '/workspace/demo');
  });

  test('pinned projects toggle on and off by directory', () async {
    final store = ProjectStore();

    final pinned = await store.togglePinnedProject('/workspace/demo');
    final unpinned = await store.togglePinnedProject('/workspace/demo');

    expect(pinned.contains('/workspace/demo'), isTrue);
    expect(unpinned.contains('/workspace/demo'), isFalse);
  });

  test(
    'hidden projects are excluded from recent projects until restored',
    () async {
      final store = ProjectStore();
      const target = ProjectTarget(
        directory: '/workspace/demo',
        label: 'Demo',
        source: 'server',
      );

      await store.recordRecentProject(target);
      await store.hideProject('/workspace/demo');

      expect(await store.loadRecentProjects(), isEmpty);

      await store.recordRecentProject(target);
      final recent = await store.loadRecentProjects();

      expect(recent, hasLength(1));
      expect(recent.single.directory, '/workspace/demo');
    },
  );

  test('last workspace preserves the last session id hint', () async {
    final store = ProjectStore();
    const target = ProjectTarget(
      directory: '/workspace/demo',
      label: 'Demo',
      source: 'server',
      lastSession: ProjectSessionHint(
        id: 'ses_saved',
        title: 'Saved session',
        status: 'busy',
      ),
    );

    await store.saveLastWorkspace(
      serverStorageKey: 'server::demo',
      target: target,
    );
    final restored = await store.loadLastWorkspace('server::demo');

    expect(restored?.lastSession?.id, 'ses_saved');
    expect(restored?.lastSession?.title, 'Saved session');
    expect(restored?.lastSession?.status, 'busy');
  });

  test('malformed recent project entries are skipped and cleaned up', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'recent_projects': <String>[
        '{bad json',
        '{"directory":"/workspace/demo","label":"Demo","source":"server"}',
      ],
    });
    final store = ProjectStore();

    final recent = await store.loadRecentProjects();
    final prefs = await SharedPreferences.getInstance();

    expect(recent, hasLength(1));
    expect(recent.single.directory, '/workspace/demo');
    expect(prefs.getStringList('recent_projects'), hasLength(1));
  });

  test(
    'reorders recent projects and keeps unspecified entries after them',
    () async {
      final store = ProjectStore();
      const demo = ProjectTarget(
        directory: '/workspace/demo',
        label: 'Demo',
        source: 'server',
      );
      const lab = ProjectTarget(
        directory: '/workspace/lab',
        label: 'Lab',
        source: 'server',
      );
      const docs = ProjectTarget(
        directory: '/workspace/docs',
        label: 'Docs',
        source: 'server',
      );

      await store.recordRecentProject(docs);
      await store.recordRecentProject(lab);
      await store.recordRecentProject(demo);

      final reordered = await store.reorderRecentProjects(const <ProjectTarget>[
        lab,
        demo,
      ]);

      expect(
        reordered.map((project) => project.directory).toList(growable: false),
        const <String>['/workspace/lab', '/workspace/demo', '/workspace/docs'],
      );
    },
  );
}
