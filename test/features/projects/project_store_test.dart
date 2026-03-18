import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile_remote/src/features/projects/project_models.dart';
import 'package:opencode_mobile_remote/src/features/projects/project_store.dart';
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
}
