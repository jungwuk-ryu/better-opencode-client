import 'package:flutter/material.dart' show Brightness, ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:better_opencode_client/src/app/app_controller.dart';
import 'package:better_opencode_client/src/app/app_release_notes.dart';
import 'package:better_opencode_client/src/core/connection/connection_models.dart';
import 'package:better_opencode_client/src/core/persistence/server_profile_store.dart';
import 'package:better_opencode_client/src/design_system/app_theme.dart';
import 'package:better_opencode_client/src/features/projects/project_models.dart';
import 'package:better_opencode_client/src/features/projects/project_store.dart';
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

  test('effective text scale uses a reduced baseline', () async {
    final controller = WebParityAppController(
      profileStore: _FakeProfileStore(),
      projectStore: _FakeProjectStore(),
    );
    addTearDown(controller.dispose);

    await controller.load();

    expect(
      controller.effectiveTextScaleFactor,
      WebParityAppController.defaultTextScaleFactor *
          WebParityAppController.textScaleBaselineMultiplier,
    );

    await controller.setTextScaleFactor(1.15);

    expect(
      controller.effectiveTextScaleFactor,
      1.15 * WebParityAppController.textScaleBaselineMultiplier,
    );
  });

  test('layout density persists across controller loads', () async {
    final controller = WebParityAppController(
      profileStore: _FakeProfileStore(),
      projectStore: _FakeProjectStore(),
    );
    addTearDown(controller.dispose);

    await controller.load();

    expect(controller.layoutDensity, WorkspaceLayoutDensity.normal);

    await controller.setLayoutDensity(WorkspaceLayoutDensity.compact);

    expect(controller.layoutDensity, WorkspaceLayoutDensity.compact);

    final restored = WebParityAppController(
      profileStore: _FakeProfileStore(),
      projectStore: _FakeProjectStore(),
    );
    addTearDown(restored.dispose);

    await restored.load();

    expect(restored.layoutDensity, WorkspaceLayoutDensity.compact);
  });

  test('multi pane composer mode persists across controller loads', () async {
    final controller = WebParityAppController(
      profileStore: _FakeProfileStore(),
      projectStore: _FakeProjectStore(),
    );
    addTearDown(controller.dispose);

    await controller.load();

    expect(
      controller.multiPaneComposerMode,
      WorkspaceMultiPaneComposerMode.shared,
    );

    await controller.setMultiPaneComposerMode(
      WorkspaceMultiPaneComposerMode.perPane,
    );

    expect(
      controller.multiPaneComposerMode,
      WorkspaceMultiPaneComposerMode.perPane,
    );

    final restored = WebParityAppController(
      profileStore: _FakeProfileStore(),
      projectStore: _FakeProjectStore(),
    );
    addTearDown(restored.dispose);

    await restored.load();

    expect(
      restored.multiPaneComposerMode,
      WorkspaceMultiPaneComposerMode.perPane,
    );
  });

  test('theme preset persists across controller loads', () async {
    final controller = WebParityAppController(
      profileStore: _FakeProfileStore(),
      projectStore: _FakeProjectStore(),
    );
    addTearDown(controller.dispose);

    await controller.load();

    expect(controller.themePreset, AppThemePreset.remote);

    await controller.setThemePreset(AppThemePreset.github);

    expect(controller.themePreset, AppThemePreset.github);

    final restored = WebParityAppController(
      profileStore: _FakeProfileStore(),
      projectStore: _FakeProjectStore(),
    );
    addTearDown(restored.dispose);

    await restored.load();

    expect(restored.themePreset, AppThemePreset.github);
  });

  test('theme cycling advances through the preset list', () async {
    final controller = WebParityAppController(
      profileStore: _FakeProfileStore(),
      projectStore: _FakeProjectStore(),
    );
    addTearDown(controller.dispose);

    await controller.load();

    expect(controller.themePreset, AppThemePreset.remote);

    await controller.cycleThemePreset();
    expect(controller.themePreset, AppThemePreset.opencode);

    await controller.cycleThemePreset(-1);
    expect(controller.themePreset, AppThemePreset.remote);
  });

  test(
    'color scheme mode persists and maps to light and dark themes',
    () async {
      final controller = WebParityAppController(
        profileStore: _FakeProfileStore(),
        projectStore: _FakeProjectStore(),
      );
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.colorSchemeMode, AppColorSchemeMode.system);
      expect(controller.themeMode, ThemeMode.system);
      expect(
        AppTheme.colorsFor(AppThemePreset.remote, Brightness.light).background,
        isNot(
          AppTheme.colorsFor(AppThemePreset.remote, Brightness.dark).background,
        ),
      );

      await controller.setColorSchemeMode(AppColorSchemeMode.dark);

      expect(controller.colorSchemeMode, AppColorSchemeMode.dark);
      expect(controller.themeMode, ThemeMode.dark);

      final restored = WebParityAppController(
        profileStore: _FakeProfileStore(),
        projectStore: _FakeProjectStore(),
      );
      addTearDown(restored.dispose);

      await restored.load();

      expect(restored.colorSchemeMode, AppColorSchemeMode.dark);
      expect(restored.themeMode, ThemeMode.dark);
    },
  );

  test('color scheme cycling advances through the mode list', () async {
    final controller = WebParityAppController(
      profileStore: _FakeProfileStore(),
      projectStore: _FakeProjectStore(),
    );
    addTearDown(controller.dispose);

    await controller.load();

    expect(controller.colorSchemeMode, AppColorSchemeMode.system);

    await controller.cycleColorSchemeMode();
    expect(controller.colorSchemeMode, AppColorSchemeMode.light);

    await controller.cycleColorSchemeMode();
    expect(controller.colorSchemeMode, AppColorSchemeMode.dark);

    await controller.cycleColorSchemeMode(-1);
    expect(controller.colorSchemeMode, AppColorSchemeMode.light);
  });

  test('first launch marks the current release notes as seen', () async {
    final controller = WebParityAppController(
      profileStore: _FakeProfileStore(),
      projectStore: _FakeProjectStore(),
    );
    addTearDown(controller.dispose);

    await controller.load();

    expect(controller.currentReleaseNotes, isNotNull);
    expect(
      controller.seenReleaseNotesVersion,
      controller.currentReleaseNotes?.currentVersion,
    );
    expect(controller.pendingReleaseNotes, isNull);
  });

  test('older seen versions queue a What\'s New dialog', () async {
    final currentReleaseNotes = latestAppReleaseNotesPresentation();
    SharedPreferences.setMockInitialValues(<String, Object>{
      'web_parity.release_notes_seen_version':
          currentReleaseNotes == null ? '0.0.0' : '0.9.0',
    });

    final controller = WebParityAppController(
      profileStore: _FakeProfileStore(),
      projectStore: _FakeProjectStore(),
    );
    addTearDown(controller.dispose);

    await controller.load();

    expect(controller.pendingReleaseNotes, isNotNull);
    expect(
      controller.pendingReleaseNotes?.currentVersion,
      currentReleaseNotes?.currentVersion,
    );

    await controller.markReleaseNotesSeen();

    expect(controller.pendingReleaseNotes, isNull);
    expect(
      controller.seenReleaseNotesVersion,
      currentReleaseNotes?.currentVersion,
    );
  });

  test('disabling release notes clears pending updates and persists the choice', () async {
    final currentReleaseNotes = latestAppReleaseNotesPresentation();
    SharedPreferences.setMockInitialValues(<String, Object>{
      'web_parity.release_notes_seen_version':
          currentReleaseNotes == null ? '0.0.0' : '0.9.0',
    });

    final controller = WebParityAppController(
      profileStore: _FakeProfileStore(),
      projectStore: _FakeProjectStore(),
    );
    addTearDown(controller.dispose);

    await controller.load();
    expect(controller.pendingReleaseNotes, isNotNull);

    await controller.setReleaseNotesEnabled(false);

    expect(controller.releaseNotesEnabled, isFalse);
    expect(controller.pendingReleaseNotes, isNull);
    expect(
      controller.seenReleaseNotesVersion,
      currentReleaseNotes?.currentVersion,
    );

    final restored = WebParityAppController(
      profileStore: _FakeProfileStore(),
      projectStore: _FakeProjectStore(),
    );
    addTearDown(restored.dispose);

    await restored.load();

    expect(restored.releaseNotesEnabled, isFalse);
    expect(restored.pendingReleaseNotes, isNull);
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
