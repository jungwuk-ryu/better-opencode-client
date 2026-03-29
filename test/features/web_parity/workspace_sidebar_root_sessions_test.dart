import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:opencode_mobile_remote/src/app/app_controller.dart';
import 'package:opencode_mobile_remote/src/app/app_routes.dart';
import 'package:opencode_mobile_remote/src/app/app_scope.dart';
import 'package:opencode_mobile_remote/src/core/connection/connection_models.dart';
import 'package:opencode_mobile_remote/src/core/network/opencode_server_probe.dart';
import 'package:opencode_mobile_remote/src/core/spec/capability_registry.dart';
import 'package:opencode_mobile_remote/src/core/spec/probe_snapshot.dart';
import 'package:opencode_mobile_remote/src/design_system/app_theme.dart';
import 'package:opencode_mobile_remote/src/features/chat/chat_models.dart';
import 'package:opencode_mobile_remote/src/features/projects/project_catalog_service.dart';
import 'package:opencode_mobile_remote/src/features/projects/project_models.dart';
import 'package:opencode_mobile_remote/src/features/requests/request_models.dart';
import 'package:opencode_mobile_remote/src/features/terminal/pty_models.dart';
import 'package:opencode_mobile_remote/src/features/terminal/pty_service.dart';
import 'package:opencode_mobile_remote/src/features/tools/todo_models.dart';
import 'package:opencode_mobile_remote/src/features/web_parity/workspace_controller.dart';
import 'package:opencode_mobile_remote/src/features/web_parity/workspace_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('sidebar hides nested sessions by default', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final profile = ServerProfile(
      id: 'server',
      label: 'Mock',
      baseUrl: 'http://localhost:3000',
    );
    final appController = _StaticAppController(
      profile: profile,
      workspaceControllerFactory:
          ({required profile, required directory, initialSessionId}) {
            return _SidebarWorkspaceController(
              profile: profile,
              directory: directory,
              initialSessionId: initialSessionId,
            );
          },
    );
    addTearDown(appController.dispose);

    await tester.pumpWidget(
      _WorkspaceRouteHarness(
        controller: appController,
        initialRoute: buildWorkspaceRoute(
          '/workspace/demo',
          sessionId: 'ses_1',
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Demo'), findsOneWidget);
    expect(find.text('/workspace/demo'), findsAtLeastNWidgets(1));
    expect(find.text('New session'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey<String>('workspace-sidebar-project-menu-button'),
      ),
      findsOneWidget,
    );
    expect(find.text('Root session'), findsAtLeastNWidgets(1));
    expect(find.text('Another root session'), findsAtLeastNWidgets(1));
    expect(
      find.byKey(const ValueKey<String>('workspace-session-entry-ses_child-1')),
      findsNothing,
    );
    expect(
      find.byKey(
        const ValueKey<String>('workspace-toggle-sessions-panel-button'),
      ),
      findsOneWidget,
    );
    expect(find.text('idle'), findsNothing);
    expect(find.text('busy'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('sidebar-session-shimmer-ses_1')),
      findsOneWidget,
    );
  });

  testWidgets('sidebar shows a hover preview for recent session prompts', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final profile = ServerProfile(
      id: 'server',
      label: 'Mock',
      baseUrl: 'http://localhost:3000',
    );
    late _SidebarHoverPreviewWorkspaceController controllerInstance;
    final appController = _StaticAppController(
      profile: profile,
      workspaceControllerFactory:
          ({required profile, required directory, initialSessionId}) {
            controllerInstance = _SidebarHoverPreviewWorkspaceController(
              profile: profile,
              directory: directory,
              initialSessionId: initialSessionId,
            );
            return controllerInstance;
          },
    );
    addTearDown(appController.dispose);

    await tester.pumpWidget(
      _WorkspaceRouteHarness(
        controller: appController,
        initialRoute: buildWorkspaceRoute(
          '/workspace/demo',
          sessionId: 'ses_1',
        ),
        platform: TargetPlatform.macOS,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    final targetRow = find.byKey(
      const ValueKey<String>('workspace-session-entry-ses_2-0'),
    );
    expect(targetRow, findsOneWidget);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer();
    await mouse.moveTo(tester.getCenter(targetRow));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    expect(controllerInstance.hoverPrefetchCalls, 1);
    expect(
      find.byKey(const ValueKey<String>('sidebar-session-hover-preview-ses_2')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>(
          'sidebar-session-hover-message-ses_2-msg_hover_newer',
        ),
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(
        const ValueKey<String>(
          'sidebar-session-hover-message-ses_2-msg_hover_newer',
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    expect(controllerInstance.selectSessionCalls, contains('ses_2'));
    expect(find.text('Another root session'), findsAtLeastNWidgets(1));
  });

  testWidgets('sidebar shows project and session notification badges', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final profile = ServerProfile(
      id: 'server',
      label: 'Mock',
      baseUrl: 'http://localhost:3000',
    );
    final appController = _StaticAppController(
      profile: profile,
      workspaceControllerFactory:
          ({required profile, required directory, initialSessionId}) {
            return _SidebarNotificationWorkspaceController(
              profile: profile,
              directory: directory,
              initialSessionId: initialSessionId,
            );
          },
    );
    addTearDown(appController.dispose);

    await tester.pumpWidget(
      _WorkspaceRouteHarness(
        controller: appController,
        initialRoute: buildWorkspaceRoute(
          '/workspace/demo',
          sessionId: 'ses_1',
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      find.byKey(
        const ValueKey<String>(
          'workspace-project-notification-badge-/workspace/demo',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('workspace-session-notification-badge-ses_2'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('workspace-session-notification-badge-ses_1'),
      ),
      findsNothing,
    );
  });

  testWidgets('sidebar settings opens a real workspace settings sheet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final profile = ServerProfile(
      id: 'server',
      label: 'Mock',
      baseUrl: 'http://localhost:3000',
    );
    final appController = _StaticAppController(
      profile: profile,
      shellToolPartsExpandedValue: true,
      timelineProgressDetailsVisibleValue: false,
      sidebarChildSessionsVisibleValue: false,
      chatCodeBlockHighlightingEnabledValue: true,
      report: _readyReport,
      workspaceControllerFactory:
          ({required profile, required directory, initialSessionId}) {
            return _SidebarWorkspaceController(
              profile: profile,
              directory: directory,
              initialSessionId: initialSessionId,
            );
          },
    );
    addTearDown(appController.dispose);

    await tester.pumpWidget(
      _WorkspaceRouteHarness(
        controller: appController,
        initialRoute: buildWorkspaceRoute(
          '/workspace/demo',
          sessionId: 'ses_1',
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byIcon(Icons.help_outline_rounded), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey<String>('workspace-sidebar-settings-button')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 240));

    expect(
      find.byKey(const ValueKey<String>('workspace-settings-sheet')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('workspace-settings-sheet-blur')),
      findsOneWidget,
    );
    expect(find.text('Workspace Settings'), findsOneWidget);
    expect(find.text('Manage Servers'), findsOneWidget);
    expect(find.text('Ready'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('workspace-session-entry-ses_child-1')),
      findsNothing,
    );

    final shellDisplaySegments = find.descendant(
      of: find.byKey(const ValueKey<String>('workspace-settings-shell-toggle')),
      matching: find.byKey(
        const ValueKey<String>('workspace-settings-shell-display-mode-segments'),
      ),
    );
    await tester.tap(find.descendant(of: shellDisplaySegments, matching: find.text('Off')));
    await tester.pump();

    expect(appController.shellToolDisplayMode, ShellToolDisplayMode.collapsed);

    final highlightToggle = find.descendant(
      of: find.byKey(
        const ValueKey<String>('workspace-settings-code-highlight-toggle'),
      ),
      matching: find.byType(Switch),
    );
    tester.widget<Switch>(highlightToggle).onChanged!(false);
    await tester.pump();

    expect(appController.chatCodeBlockHighlightingEnabled, isFalse);

    expect(appController.busyFollowupMode, WorkspaceFollowupMode.queue);
    expect(appController.themePreset, AppThemePreset.remote);
    expect(appController.colorSchemeMode, AppColorSchemeMode.system);
    final initialSidebarWidth = tester
        .getSize(
          find.byKey(const ValueKey<String>('workspace-desktop-sidebar-pane')),
        )
        .width;

    final settingsListView = find
        .descendant(
          of: find.byKey(const ValueKey<String>('workspace-settings-sheet')),
          matching: find.byType(ListView),
        )
        .first;

    await tester.dragUntilVisible(
      find.byKey(
        const ValueKey<String>('workspace-settings-followup-mode-row'),
      ),
      settingsListView,
      const Offset(0, -160),
    );
    await tester.pump();

    await tester.tap(find.text('Steer'));
    await tester.pump();

    expect(appController.busyFollowupMode, WorkspaceFollowupMode.steer);

    await tester.dragUntilVisible(
      find.byKey(
        const ValueKey<String>(
          'workspace-settings-multi-pane-composer-mode-row',
        ),
      ),
      settingsListView,
      const Offset(0, -160),
    );
    await tester.pump();

    await tester.tap(
      find.descendant(
        of: find.byKey(
          const ValueKey<String>(
            'workspace-settings-multi-pane-composer-mode-row',
          ),
        ),
        matching: find.text('Per Pane'),
      ),
    );
    await tester.pump();

    expect(
      appController.multiPaneComposerMode,
      WorkspaceMultiPaneComposerMode.perPane,
    );

    await tester.dragUntilVisible(
      find.byKey(const ValueKey<String>('workspace-settings-color-mode-row')),
      settingsListView,
      const Offset(0, -160),
    );
    await tester.pump();

    final colorModeRow = find.byKey(
      const ValueKey<String>('workspace-settings-color-mode-row'),
    );
    expect(colorModeRow, findsOneWidget);

    await tester.tap(
      find.descendant(of: colorModeRow, matching: find.text('Light')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    expect(appController.colorSchemeMode, AppColorSchemeMode.light);

    await tester.tap(
      find.byKey(
        const ValueKey<String>('workspace-settings-color-mode-cycle-button'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    expect(appController.colorSchemeMode, AppColorSchemeMode.dark);

    await tester.dragUntilVisible(
      find.byKey(
        const ValueKey<String>('workspace-settings-layout-density-row'),
      ),
      settingsListView,
      const Offset(0, -160),
    );
    await tester.pump();

    await tester.tap(
      find.descendant(
        of: find.byKey(
          const ValueKey<String>('workspace-settings-layout-density-row'),
        ),
        matching: find.text('Compact'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 280));

    expect(appController.layoutDensity, WorkspaceLayoutDensity.compact);
    expect(
      tester
          .getSize(
            find.byKey(
              const ValueKey<String>('workspace-desktop-sidebar-pane'),
            ),
          )
          .width,
      lessThan(initialSidebarWidth),
    );

    await tester.dragUntilVisible(
      find.byKey(const ValueKey<String>('workspace-settings-text-scale-row')),
      settingsListView,
      const Offset(0, -160),
    );
    await tester.pump();

    final textScaleSlider = tester.widget<Slider>(
      find.byKey(
        const ValueKey<String>('workspace-settings-text-scale-slider'),
      ),
    );
    textScaleSlider.onChanged?.call(1.15);
    await tester.pump();

    expect(appController.textScaleFactor, 1.15);
    expect(find.text('115%'), findsOneWidget);

    await tester.dragUntilVisible(
      find.byKey(
        const ValueKey<String>('workspace-settings-release-notes-toggle'),
      ),
      settingsListView,
      const Offset(0, -160),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));

    final releaseNotesToggle = find.descendant(
      of: find.byKey(
        const ValueKey<String>('workspace-settings-release-notes-toggle'),
      ),
      matching: find.byType(Switch),
    );
    await tester.tap(releaseNotesToggle);
    await tester.pump();

    expect(appController.releaseNotesEnabled, isFalse);

    await tester.tap(
      find.byKey(
        const ValueKey<String>('workspace-settings-open-whats-new-button'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));

    expect(
      find.byKey(const ValueKey<String>('release-notes-dialog')),
      findsOneWidget,
    );
    expect(find.text('Workspace parity got a major upgrade.'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('release-notes-close-button')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    await tester.dragUntilVisible(
      find.byKey(
        const ValueKey<String>(
          'workspace-settings-sidebar-child-sessions-toggle',
        ),
      ),
      settingsListView,
      const Offset(0, -200),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));

    final sidebarToggle = find.descendant(
      of: find.byKey(
        const ValueKey<String>(
          'workspace-settings-sidebar-child-sessions-toggle',
        ),
      ),
      matching: find.byType(Switch),
    );
    await tester.tap(sidebarToggle);
    await tester.pump();

    expect(appController.sidebarChildSessionsVisible, isTrue);
    expect(find.text('Nested subagent session'), findsAtLeastNWidgets(1));

    await tester.dragUntilVisible(
      find.byKey(const ValueKey<String>('workspace-settings-theme-row')),
      settingsListView,
      const Offset(0, 220),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('workspace-settings-theme-row')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(
        const ValueKey<String>('workspace-settings-theme-option-opencode'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    expect(appController.themePreset, AppThemePreset.opencode);

    await tester.tap(
      find.byKey(
        const ValueKey<String>('workspace-settings-theme-cycle-button'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    expect(appController.themePreset, AppThemePreset.amoled);
  });

  testWidgets(
    'sidebar add project button opens the home project picker sheet',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final profile = ServerProfile(
        id: 'server',
        label: 'Mock',
        baseUrl: 'http://localhost:3000',
      );
      final appController = _StaticAppController(
        profile: profile,
        workspaceControllerFactory:
            ({required profile, required directory, initialSessionId}) {
              return _SidebarWorkspaceController(
                profile: profile,
                directory: directory,
                initialSessionId: initialSessionId,
              );
            },
      );
      addTearDown(appController.dispose);

      await tester.pumpWidget(
        _WorkspaceRouteHarness(
          controller: appController,
          initialRoute: buildWorkspaceRoute(
            '/workspace/demo',
            sessionId: 'ses_1',
          ),
          projectCatalogService: _FakeProjectCatalogService(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 220));

      expect(
        find.byKey(
          const ValueKey<String>('workspace-sidebar-add-project-button'),
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(
          const ValueKey<String>('workspace-sidebar-add-project-button'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 240));

      expect(find.text('Open Project'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('project-picker-manual-path-field')),
        findsOneWidget,
      );
      expect(find.text('Design System'), findsOneWidget);
    },
  );

  testWidgets('project tile context menu edits and removes projects', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final profile = ServerProfile(
      id: 'server',
      label: 'Mock',
      baseUrl: 'http://localhost:3000',
    );
    late _EditableSidebarWorkspaceController controllerInstance;
    final appController = _StaticAppController(
      profile: profile,
      workspaceControllerFactory:
          ({required profile, required directory, initialSessionId}) {
            controllerInstance = _EditableSidebarWorkspaceController(
              profile: profile,
              directory: directory,
              initialSessionId: initialSessionId,
            );
            return controllerInstance;
          },
    );
    addTearDown(appController.dispose);

    await tester.pumpWidget(
      _WorkspaceRouteHarness(
        controller: appController,
        initialRoute: buildWorkspaceRoute(
          '/workspace/demo',
          sessionId: 'ses_1',
        ),
        projectCatalogService: _FakeProjectCatalogService(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    final labTile = find.byKey(
      const ValueKey<String>('workspace-project-/workspace/lab'),
    );
    expect(labTile, findsOneWidget);

    await tester.longPress(labTile);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));

    expect(find.text('Edit project'), findsOneWidget);
    expect(find.text('Delete project'), findsOneWidget);

    await tester.tap(find.text('Edit project'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    expect(find.text('Edit project'), findsAtLeastNWidgets(1));
    final nameField = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == 'Name',
    );
    final startupField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.labelText == 'Workspace startup script',
    );
    await tester.enterText(nameField, 'Lab Renamed');
    await tester.enterText(startupField, 'bun install');
    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    final updatedProject = controllerInstance.availableProjects.firstWhere(
      (project) => project.directory == '/workspace/lab',
    );
    expect(updatedProject.name, 'Lab Renamed');
    expect(updatedProject.commands?.start, 'bun install');

    await tester.longPress(labTile);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));
    await tester.tap(find.text('Delete project'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    expect(
      find.byKey(const ValueKey<String>('workspace-project-/workspace/lab')),
      findsNothing,
    );
  });

  testWidgets('project avatars update when thumbnails are added and removed', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const demoIconDataUrl =
        'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO7Z9QAAAABJRU5ErkJggg==';

    final profile = ServerProfile(
      id: 'server',
      label: 'Mock',
      baseUrl: 'http://localhost:3000',
    );
    late _EditableSidebarWorkspaceController controllerInstance;
    final appController = _StaticAppController(
      profile: profile,
      workspaceControllerFactory:
          ({required profile, required directory, initialSessionId}) {
            controllerInstance = _EditableSidebarWorkspaceController(
              profile: profile,
              directory: directory,
              initialSessionId: initialSessionId,
            );
            return controllerInstance;
          },
    );
    addTearDown(appController.dispose);

    await tester.pumpWidget(
      _WorkspaceRouteHarness(
        controller: appController,
        initialRoute: buildWorkspaceRoute(
          '/workspace/demo',
          sessionId: 'ses_1',
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    final demoTile = find.byKey(
      const ValueKey<String>('workspace-project-/workspace/demo'),
    );
    Finder demoImage() =>
        find.descendant(of: demoTile, matching: find.byType(Image));

    expect(demoImage(), findsNothing);

    final demoProject = controllerInstance.availableProjects.firstWhere(
      (project) => project.directory == '/workspace/demo',
    );
    controllerInstance.applyProjectTargetUpdate(
      demoProject.copyWith(
        icon: const ProjectIconInfo(
          url: demoIconDataUrl,
          override: demoIconDataUrl,
          color: 'mint',
        ),
      ),
    );
    await tester.pump();

    expect(demoImage(), findsOneWidget);

    final initialProvider = tester.widget<Image>(demoImage()).image;

    controllerInstance.applyProjectTargetUpdate(
      demoProject.copyWith(
        branch: 'release',
        icon: const ProjectIconInfo(
          url: demoIconDataUrl,
          override: demoIconDataUrl,
          color: 'mint',
        ),
      ),
    );
    await tester.pump();

    expect(demoImage(), findsOneWidget);
    expect(tester.widget<Image>(demoImage()).image, same(initialProvider));

    controllerInstance.applyProjectTargetUpdate(
      demoProject.copyWith(icon: const ProjectIconInfo(color: 'mint')),
    );
    await tester.pump();

    expect(demoImage(), findsNothing);
  });

  testWidgets('project tiles expose the project name as a tooltip', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final profile = ServerProfile(
      id: 'server',
      label: 'Mock',
      baseUrl: 'http://localhost:3000',
    );
    final appController = _StaticAppController(
      profile: profile,
      workspaceControllerFactory:
          ({required profile, required directory, initialSessionId}) {
            return _EditableSidebarWorkspaceController(
              profile: profile,
              directory: directory,
              initialSessionId: initialSessionId,
            );
          },
    );
    addTearDown(appController.dispose);

    await tester.pumpWidget(
      _WorkspaceRouteHarness(
        controller: appController,
        initialRoute: buildWorkspaceRoute(
          '/workspace/demo',
          sessionId: 'ses_1',
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    expect(find.byTooltip('Demo'), findsOneWidget);
    expect(find.byTooltip('Lab'), findsOneWidget);
  });

  testWidgets('project rail icons can be dragged to reorder', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final profile = ServerProfile(
      id: 'server',
      label: 'Mock',
      baseUrl: 'http://localhost:3000',
    );
    late _EditableSidebarWorkspaceController controllerInstance;
    final appController = _StaticAppController(
      profile: profile,
      workspaceControllerFactory:
          ({required profile, required directory, initialSessionId}) {
            controllerInstance = _EditableSidebarWorkspaceController(
              profile: profile,
              directory: directory,
              initialSessionId: initialSessionId,
            );
            return controllerInstance;
          },
    );
    addTearDown(appController.dispose);

    await tester.pumpWidget(
      _WorkspaceRouteHarness(
        controller: appController,
        initialRoute: buildWorkspaceRoute(
          '/workspace/demo',
          sessionId: 'ses_1',
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    final demoTile = find.byKey(
      const ValueKey<String>('workspace-project-/workspace/demo'),
    );
    final labTile = find.byKey(
      const ValueKey<String>('workspace-project-/workspace/lab'),
    );
    expect(
      tester.getTopLeft(demoTile).dy,
      lessThan(tester.getTopLeft(labTile).dy),
    );

    expect(
      find.byKey(
        const ValueKey<String>(
          'workspace-project-reorder-handle-/workspace/demo',
        ),
      ),
      findsNothing,
    );
    expect(find.byIcon(Icons.drag_indicator_rounded), findsNothing);

    await tester.drag(demoTile, const Offset(0, 140));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 420));

    expect(
      controllerInstance.availableProjects
          .map((project) => project.directory)
          .toList(growable: false),
      const <String>['/workspace/lab', '/workspace/demo'],
    );
    expect(
      tester.getTopLeft(demoTile).dy,
      greaterThan(tester.getTopLeft(labTile).dy),
    );
  });
}

class _WorkspaceRouteHarness extends StatelessWidget {
  const _WorkspaceRouteHarness({
    required this.controller,
    required this.initialRoute,
    this.projectCatalogService,
    this.platform = TargetPlatform.macOS,
  });

  final WebParityAppController controller;
  final String initialRoute;
  final ProjectCatalogService? projectCatalogService;
  final TargetPlatform platform;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      controller: controller,
      child: MaterialApp(
        theme: controller.themeData.copyWith(platform: platform),
        initialRoute: initialRoute,
        onGenerateRoute: (settings) {
          final route = AppRouteData.parse(settings.name);
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (context) {
              return switch (route) {
                HomeRouteData() => const SizedBox.shrink(),
                WorkspaceRouteData(:final directory, :final sessionId) =>
                  WebParityWorkspaceScreen(
                    key: ValueKey<String>('workspace-$directory'),
                    directory: directory,
                    sessionId: sessionId,
                    ptyServiceFactory: _FakePtyService.new,
                    projectCatalogService: projectCatalogService,
                  ),
              };
            },
          );
        },
      ),
    );
  }
}

class _StaticAppController extends WebParityAppController {
  _StaticAppController({
    required this.profile,
    this.report,
    this.shellToolPartsExpandedValue = true,
    this.timelineProgressDetailsVisibleValue = false,
    this.sidebarChildSessionsVisibleValue = false,
    this.chatCodeBlockHighlightingEnabledValue = true,
    required WorkspaceControllerFactory workspaceControllerFactory,
  }) : shellToolDisplayModeValue = shellToolPartsExpandedValue
           ? ShellToolDisplayMode.alwaysExpanded
           : ShellToolDisplayMode.collapsed,
       busyFollowupModeValue = WorkspaceFollowupMode.queue,
       textScaleFactorValue = WebParityAppController.defaultTextScaleFactor,
       super(workspaceControllerFactory: workspaceControllerFactory);

  final ServerProfile profile;
  final ServerProbeReport? report;
  bool shellToolPartsExpandedValue;
  ShellToolDisplayMode shellToolDisplayModeValue;
  bool timelineProgressDetailsVisibleValue;
  bool sidebarChildSessionsVisibleValue;
  bool chatCodeBlockHighlightingEnabledValue;
  WorkspaceFollowupMode busyFollowupModeValue;
  double textScaleFactorValue;

  @override
  ServerProfile? get selectedProfile => profile;

  @override
  ServerProbeReport? get selectedReport => report;

  @override
  ShellToolDisplayMode get shellToolDisplayMode => shellToolDisplayModeValue;

  @override
  bool get shellToolPartsExpanded =>
      shellToolDisplayModeValue == ShellToolDisplayMode.alwaysExpanded;

  @override
  bool get timelineProgressDetailsVisible =>
      timelineProgressDetailsVisibleValue;

  @override
  bool get sidebarChildSessionsVisible => sidebarChildSessionsVisibleValue;

  @override
  bool get chatCodeBlockHighlightingEnabled =>
      chatCodeBlockHighlightingEnabledValue;

  @override
  WorkspaceFollowupMode get busyFollowupMode => busyFollowupModeValue;

  @override
  double get textScaleFactor => textScaleFactorValue;

  @override
  Future<void> setShellToolDisplayMode(ShellToolDisplayMode value) async {
    shellToolDisplayModeValue = value;
    shellToolPartsExpandedValue = value == ShellToolDisplayMode.alwaysExpanded;
    notifyListeners();
  }

  @override
  Future<void> setTimelineProgressDetailsVisible(bool value) async {
    timelineProgressDetailsVisibleValue = value;
    notifyListeners();
  }

  @override
  Future<void> setSidebarChildSessionsVisible(bool value) async {
    sidebarChildSessionsVisibleValue = value;
    notifyListeners();
  }

  @override
  Future<void> setChatCodeBlockHighlightingEnabled(bool value) async {
    chatCodeBlockHighlightingEnabledValue = value;
    notifyListeners();
  }

  @override
  Future<void> setBusyFollowupMode(WorkspaceFollowupMode value) async {
    busyFollowupModeValue = value;
    notifyListeners();
  }

  @override
  Future<void> setTextScaleFactor(double value) async {
    textScaleFactorValue = value;
    notifyListeners();
  }
}

final ProbeSnapshot _readySnapshot = ProbeSnapshot(
  name: 'OpenCode',
  version: '1.0.0',
  paths: <String>{'/global/health', '/config', '/agent'},
  endpoints: <String, ProbeEndpointResult>{},
  config: const <String, Object?>{},
  providerConfig: const <String, Object?>{},
);

final ServerProbeReport _readyReport = ServerProbeReport(
  snapshot: _readySnapshot,
  capabilityRegistry: CapabilityRegistry.fromSnapshot(_readySnapshot),
  classification: ConnectionProbeClassification.ready,
  summary: 'Server is ready for web parity features.',
  checkedAt: DateTime.fromMillisecondsSinceEpoch(1710000000000),
  missingCapabilities: const <String>[],
  discoveredExperimentalPaths: const <String>[],
  sseReady: true,
);

class _SidebarWorkspaceController extends WorkspaceController {
  _SidebarWorkspaceController({
    required super.profile,
    required super.directory,
    super.initialSessionId,
  });

  static const ProjectTarget _projectTarget = ProjectTarget(
    directory: '/workspace/demo',
    label: 'Demo',
    source: 'server',
    vcs: 'git',
    branch: 'main',
  );

  static final List<SessionSummary> _sessions = <SessionSummary>[
    SessionSummary(
      id: 'ses_1',
      directory: '/workspace/demo',
      title: 'Root session',
      version: '1',
      updatedAt: DateTime.fromMillisecondsSinceEpoch(1710000001000),
    ),
    SessionSummary(
      id: 'ses_child',
      directory: '/workspace/demo',
      title: 'Nested subagent session',
      version: '1',
      updatedAt: DateTime.fromMillisecondsSinceEpoch(1710000001500),
      parentId: 'ses_1',
    ),
    SessionSummary(
      id: 'ses_2',
      directory: '/workspace/demo',
      title: 'Another root session',
      version: '1',
      updatedAt: DateTime.fromMillisecondsSinceEpoch(1710000002000),
    ),
  ];

  static const Map<String, SessionStatusSummary> _statuses =
      <String, SessionStatusSummary>{
        'ses_1': SessionStatusSummary(type: 'idle'),
        'ses_2': SessionStatusSummary(type: 'idle'),
        'ses_child': SessionStatusSummary(type: 'running'),
      };

  bool _loading = true;
  String? _selectedSessionId;

  @override
  bool get loading => _loading;

  @override
  ProjectTarget? get project => _projectTarget;

  @override
  List<ProjectTarget> get availableProjects => const <ProjectTarget>[
    _projectTarget,
  ];

  @override
  List<SessionSummary> get sessions => _sessions;

  @override
  String? get selectedSessionId => _selectedSessionId;

  @override
  SessionSummary? get selectedSession => _sessions.first;

  @override
  List<ChatMessage> get messages => const <ChatMessage>[];

  @override
  Map<String, SessionStatusSummary> get statuses => _statuses;

  @override
  List<TodoItem> get todos => const <TodoItem>[];

  @override
  PendingRequestBundle get pendingRequests => const PendingRequestBundle(
    questions: <QuestionRequestSummary>[],
    permissions: <PermissionRequestSummary>[],
  );

  @override
  Future<void> load() async {
    _loading = false;
    _selectedSessionId = initialSessionId ?? 'ses_1';
    notifyListeners();
  }
}

class _SidebarHoverPreviewWorkspaceController
    extends _SidebarWorkspaceController {
  _SidebarHoverPreviewWorkspaceController({
    required super.profile,
    required super.directory,
    super.initialSessionId,
  });

  int hoverPrefetchCalls = 0;
  final List<String> selectSessionCalls = <String>[];
  Map<String, WorkspaceSessionHoverPreviewState> _previewBySessionId =
      const <String, WorkspaceSessionHoverPreviewState>{};

  @override
  bool get loading => _loading;

  @override
  String? get selectedSessionId => _selectedSessionId;

  @override
  SessionSummary? get selectedSession {
    final selectedSessionId = _selectedSessionId;
    if (selectedSessionId == null) {
      return null;
    }
    return sessions.firstWhere((session) => session.id == selectedSessionId);
  }

  @override
  Future<void> load() async {
    _loading = false;
    _selectedSessionId = initialSessionId ?? 'ses_1';
    notifyListeners();
  }

  @override
  Future<void> selectSession(String? sessionId) async {
    final normalized = sessionId?.trim();
    if (normalized == null || normalized.isEmpty) {
      return;
    }
    selectSessionCalls.add(normalized);
    _selectedSessionId = normalized;
    notifyListeners();
  }

  @override
  WorkspaceSessionHoverPreviewState sessionHoverPreviewForSession(
    String? sessionId,
  ) {
    return _previewBySessionId[sessionId] ??
        const WorkspaceSessionHoverPreviewState();
  }

  @override
  Future<void> prefetchSessionHoverPreview(String? sessionId) async {
    final normalized = sessionId?.trim();
    if (normalized == null || normalized.isEmpty) {
      return;
    }
    hoverPrefetchCalls += 1;
    if (normalized != 'ses_2') {
      return;
    }
    _previewBySessionId = <String, WorkspaceSessionHoverPreviewState>{
      ..._previewBySessionId,
      normalized: const WorkspaceSessionHoverPreviewState(
        summary: 'Review diff is ready',
        messages: <WorkspaceSessionHoverPreviewMessage>[
          WorkspaceSessionHoverPreviewMessage(
            messageId: 'msg_hover_newer',
            label: 'Fix the flaky iOS snapshot test',
          ),
          WorkspaceSessionHoverPreviewMessage(
            messageId: 'msg_hover_older',
            label: 'Audit sidebar hover parity',
          ),
        ],
      ),
    };
    notifyListeners();
  }
}

class _SidebarNotificationWorkspaceController
    extends _SidebarWorkspaceController {
  _SidebarNotificationWorkspaceController({
    required super.profile,
    required super.directory,
    super.initialSessionId,
  });

  @override
  WorkspaceSidebarNotificationState sessionNotificationForSession(
    String? sessionId,
  ) {
    return switch (sessionId) {
      'ses_2' => const WorkspaceSidebarNotificationState(unseenCount: 2),
      _ => const WorkspaceSidebarNotificationState(),
    };
  }

  @override
  WorkspaceSidebarNotificationState projectNotificationForDirectory(
    String? directory,
  ) {
    return switch (directory) {
      '/workspace/demo' => const WorkspaceSidebarNotificationState(
        unseenCount: 2,
        hasError: true,
      ),
      _ => const WorkspaceSidebarNotificationState(),
    };
  }
}

class _EditableSidebarWorkspaceController extends _SidebarWorkspaceController {
  _EditableSidebarWorkspaceController({
    required super.profile,
    required super.directory,
    super.initialSessionId,
  });

  List<ProjectTarget> _projects = const <ProjectTarget>[
    ProjectTarget(
      id: 'project-demo',
      directory: '/workspace/demo',
      label: 'Demo',
      name: 'Demo',
      source: 'server',
      vcs: 'git',
      branch: 'main',
    ),
    ProjectTarget(
      id: 'project-lab',
      directory: '/workspace/lab',
      label: 'Lab',
      name: 'Lab',
      source: 'server',
      vcs: 'git',
      branch: 'develop',
    ),
  ];

  @override
  ProjectTarget? get project => _projects.first;

  @override
  List<ProjectTarget> get availableProjects => _projects;

  @override
  void applyProjectTargetUpdate(ProjectTarget target, {bool notify = true}) {
    _projects = _projects
        .map(
          (project) => project.directory == target.directory ? target : project,
        )
        .toList(growable: false);
    if (notify) {
      notifyListeners();
    }
  }

  @override
  void applyProjectRemoval(String directory, {bool notify = true}) {
    _projects = _projects
        .where((project) => project.directory != directory)
        .toList(growable: false);
    if (notify) {
      notifyListeners();
    }
  }

  @override
  void applyProjectOrder(
    List<ProjectTarget> orderedProjects, {
    bool notify = true,
  }) {
    final rankByDirectory = <String, int>{
      for (var index = 0; index < orderedProjects.length; index += 1)
        orderedProjects[index].directory: index,
    };
    final originalIndexByDirectory = <String, int>{
      for (var index = 0; index < _projects.length; index += 1)
        _projects[index].directory: index,
    };
    final next = List<ProjectTarget>.of(_projects);
    next.sort((left, right) {
      final leftRank = rankByDirectory[left.directory];
      final rightRank = rankByDirectory[right.directory];
      if (leftRank != null && rightRank != null) {
        return leftRank.compareTo(rightRank);
      }
      if (leftRank != null) {
        return -1;
      }
      if (rightRank != null) {
        return 1;
      }
      return (originalIndexByDirectory[left.directory] ?? 0).compareTo(
        originalIndexByDirectory[right.directory] ?? 0,
      );
    });
    _projects = List<ProjectTarget>.unmodifiable(next);
    if (notify) {
      notifyListeners();
    }
  }
}

class _FakeProjectCatalogService extends ProjectCatalogService {
  @override
  Future<ProjectCatalog> fetchCatalog(ServerProfile profile) async {
    return const ProjectCatalog(
      currentProject: ProjectSummary(
        id: 'demo',
        directory: '/workspace/demo',
        worktree: '/workspace/demo',
        name: 'Demo',
        vcs: 'git',
        updatedAt: null,
      ),
      projects: <ProjectSummary>[
        ProjectSummary(
          id: 'demo',
          directory: '/workspace/demo',
          worktree: '/workspace/demo',
          name: 'Demo',
          vcs: 'git',
          updatedAt: null,
        ),
        ProjectSummary(
          id: 'design-system',
          directory: '/workspace/design-system',
          worktree: '/workspace/design-system',
          name: 'Design System',
          vcs: 'git',
          updatedAt: null,
        ),
      ],
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

  @override
  Future<ProjectTarget> inspectDirectory({
    required ServerProfile profile,
    required String directory,
  }) async {
    final normalized = directory.trim().isEmpty ? '/workspace/demo' : directory;
    return ProjectTarget(
      id: normalized,
      directory: normalized,
      label: projectDisplayLabel(normalized),
      source: 'manual',
      vcs: 'git',
      branch: 'main',
    );
  }

  @override
  Future<ProjectTarget> updateProject({
    required ServerProfile profile,
    required ProjectTarget project,
    String? name,
    ProjectIconInfo? icon,
    ProjectCommandsInfo? commands,
  }) async {
    return project.copyWith(
      label: projectDisplayLabel(project.directory, name: name),
      name: name,
      icon: icon,
      commands: commands,
      clearName: name == null,
      clearIcon: icon == null,
      clearCommands: commands == null,
    );
  }
}

class _FakePtyService extends PtyService {
  _FakePtyService()
    : super(client: MockClient((request) async => http.Response('[]', 200)));

  @override
  Future<List<PtySessionInfo>> listSessions({
    required ServerProfile profile,
    required String directory,
  }) async {
    return const <PtySessionInfo>[];
  }
}
