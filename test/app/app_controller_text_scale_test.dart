import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile_remote/src/app/app_controller.dart';
import 'package:opencode_mobile_remote/src/core/connection/connection_models.dart';
import 'package:opencode_mobile_remote/src/core/persistence/server_profile_store.dart';
import 'package:opencode_mobile_remote/src/features/projects/project_models.dart';
import 'package:opencode_mobile_remote/src/features/projects/project_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('text scale persists across controller loads', () async {
    final controller = WebParityAppController(
      profileStore: _FakeProfileStore(),
      projectStore: _FakeProjectStore(),
    );
    addTearDown(controller.dispose);

    await controller.load();

    expect(
      controller.textScaleFactor,
      WebParityAppController.defaultTextScaleFactor,
    );

    await controller.setTextScaleFactor(1.15);

    expect(controller.textScaleFactor, 1.15);

    final restored = WebParityAppController(
      profileStore: _FakeProfileStore(),
      projectStore: _FakeProjectStore(),
    );
    addTearDown(restored.dispose);

    await restored.load();

    expect(restored.textScaleFactor, 1.15);
  });

  test('text scale values are snapped and clamped', () async {
    final controller = WebParityAppController(
      profileStore: _FakeProfileStore(),
      projectStore: _FakeProjectStore(),
    );
    addTearDown(controller.dispose);

    await controller.load();
    await controller.setTextScaleFactor(3.0);

    expect(
      controller.textScaleFactor,
      WebParityAppController.maxTextScaleFactor,
    );

    await controller.setTextScaleFactor(1.18);

    expect(controller.textScaleFactor, 1.20);
  });
}

class _FakeProfileStore extends ServerProfileStore {
  _FakeProfileStore();

  @override
  Future<List<ServerProfile>> load() async => const <ServerProfile>[];
}

class _FakeProjectStore extends ProjectStore {
  @override
  Future<List<ProjectTarget>> loadRecentProjects() async =>
      const <ProjectTarget>[];
}
