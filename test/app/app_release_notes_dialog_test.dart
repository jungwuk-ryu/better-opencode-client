import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile_remote/src/app/app.dart';
import 'package:opencode_mobile_remote/src/app/app_controller.dart';
import 'package:opencode_mobile_remote/src/core/connection/connection_models.dart';
import 'package:opencode_mobile_remote/src/core/persistence/server_profile_store.dart';
import 'package:opencode_mobile_remote/src/features/projects/project_models.dart';
import 'package:opencode_mobile_remote/src/features/projects/project_store.dart';
import 'package:opencode_mobile_remote/src/i18n/locale_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'web_parity.release_notes_seen_version': '0.9.0',
    });
  });

  testWidgets('app shows the What\'s New dialog after an update', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = WebParityAppController(
      profileStore: _FakeProfileStore(),
      projectStore: _FakeProjectStore(),
    );
    final localeController = LocaleController();
    addTearDown(controller.dispose);
    addTearDown(localeController.dispose);

    await controller.load();

    await tester.pumpWidget(
      OpenCodeRemoteApp(
        appController: controller,
        localeController: localeController,
        autoLoadAppController: false,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(
      find.byKey(const ValueKey<String>('release-notes-dialog')),
      findsOneWidget,
    );
    expect(find.text('Workspace parity got a major upgrade.'), findsOneWidget);
    expect(find.text('Customize the whole workspace look'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('release-notes-close-button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('release-notes-dialog')),
      findsNothing,
    );
    expect(controller.pendingReleaseNotes, isNull);
  });
}

class _FakeProfileStore extends ServerProfileStore {
  @override
  Future<List<ServerProfile>> load() async => const <ServerProfile>[];
}

class _FakeProjectStore extends ProjectStore {
  @override
  Future<List<ProjectTarget>> loadRecentProjects() async =>
      const <ProjectTarget>[];
}
