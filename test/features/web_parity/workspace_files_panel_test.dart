import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:better_opencode_client/src/app/app_controller.dart';
import 'package:better_opencode_client/src/app/app_routes.dart';
import 'package:better_opencode_client/src/app/app_scope.dart';
import 'package:better_opencode_client/src/core/connection/connection_models.dart';
import 'package:better_opencode_client/src/core/spec/raw_json_document.dart';
import 'package:better_opencode_client/src/design_system/app_theme.dart';
import 'package:better_opencode_client/src/features/chat/chat_models.dart';
import 'package:better_opencode_client/src/features/files/file_models.dart';
import 'package:better_opencode_client/src/features/projects/project_models.dart';
import 'package:better_opencode_client/src/features/requests/request_models.dart';
import 'package:better_opencode_client/src/features/settings/config_service.dart';
import 'package:better_opencode_client/src/features/terminal/pty_models.dart';
import 'package:better_opencode_client/src/features/terminal/pty_service.dart';
import 'package:better_opencode_client/src/features/tools/todo_models.dart';
import 'package:better_opencode_client/src/features/web_parity/workspace_controller.dart';
import 'package:better_opencode_client/src/features/web_parity/workspace_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('files panel selects a file and updates the preview', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final createdControllers = <_FilesWorkspaceController>[];
    final profile = ServerProfile(
      id: 'server',
      label: 'Mock',
      baseUrl: 'http://localhost:3000',
    );
    final appController = _StaticAppController(
      profile: profile,
      workspaceControllerFactory:
          ({required profile, required directory, initialSessionId}) {
            final controller = _FilesWorkspaceController(
              profile: profile,
              directory: directory,
              initialSessionId: initialSessionId,
            );
            createdControllers.add(controller);
            return controller;
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
    await tester.pumpAndSettle();

    expect(createdControllers, hasLength(1));
    expect(createdControllers.single.fileBundle?.selectedPath, isNull);
    expect(
      find.byKey(const ValueKey<String>('files-preview-panel')),
      findsNothing,
    );

    await tester.tap(find.text('pubspec.yaml').first);
    await tester.pumpAndSettle();

    expect(createdControllers.single.selectFileCalls, <String>['pubspec.yaml']);
    expect(createdControllers.single.fileBundle?.selectedPath, 'pubspec.yaml');
    expect(find.text('name: demo_workspace'), findsOneWidget);

    final previewWidget = tester.widget<SelectableText>(
      find.byKey(const ValueKey<String>('files-preview-content')),
    );
    final previewSpans = _flattenTextSpans(previewWidget.textSpan!);
    final themedApp = AppTheme.dark();
    expect(
      previewSpans.firstWhere((span) => span.text == 'name').style?.color,
      themedApp.colorScheme.primary.withValues(alpha: 0.96),
    );
  });

  testWidgets('files panel expands folders and reveals nested files', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final createdControllers = <_FilesWorkspaceController>[];
    final profile = ServerProfile(
      id: 'server',
      label: 'Mock',
      baseUrl: 'http://localhost:3000',
    );
    final appController = _StaticAppController(
      profile: profile,
      workspaceControllerFactory:
          ({required profile, required directory, initialSessionId}) {
            final controller = _FilesWorkspaceController(
              profile: profile,
              directory: directory,
              initialSessionId: initialSessionId,
            );
            createdControllers.add(controller);
            return controller;
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
    await tester.pumpAndSettle();

    expect(find.text('main.dart'), findsNothing);

    await tester.tap(find.text('lib').first);
    await tester.pumpAndSettle();

    expect(createdControllers.single.toggleDirectoryCalls, <String>['lib']);
    expect(find.text('main.dart'), findsOneWidget);

    await tester.tap(find.text('main.dart').first);
    await tester.pumpAndSettle();

    expect(createdControllers.single.selectFileCalls, <String>[
      'lib/main.dart',
    ]);
    expect(createdControllers.single.fileBundle?.selectedPath, 'lib/main.dart');
    expect(find.text('// lib/main.dart preview'), findsOneWidget);

    await tester.tap(find.text('lib').first);
    await tester.pumpAndSettle();

    expect(createdControllers.single.toggleDirectoryCalls, <String>[
      'lib',
      'lib',
    ]);
    expect(find.text('main.dart'), findsNothing);
  });

  testWidgets(
    'markdown previews can switch between source and rendered modes',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final createdControllers = <_FilesWorkspaceController>[];
      final profile = ServerProfile(
        id: 'server',
        label: 'Mock',
        baseUrl: 'http://localhost:3000',
      );
      final appController = _StaticAppController(
        profile: profile,
        workspaceControllerFactory:
            ({required profile, required directory, initialSessionId}) {
              final controller = _FilesWorkspaceController(
                profile: profile,
                directory: directory,
                initialSessionId: initialSessionId,
              );
              createdControllers.add(controller);
              return controller;
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
      await tester.pumpAndSettle();

      await tester.tap(find.text('README.md').first);
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey<String>('files-preview-markdown-mode-toggle'),
        ),
        findsOneWidget,
      );
      expect(find.text('# README preview'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('files-preview-markdown-content')),
        findsNothing,
      );

      await tester.tap(find.text('Rendered'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('files-preview-markdown-content')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('files-preview-content')),
        findsNothing,
      );
      expect(find.text('# README preview'), findsNothing);
      expect(find.text('README preview'), findsOneWidget);

      await tester.tap(find.text('Source'));
      await tester.pumpAndSettle();

      expect(find.text('# README preview'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('files-preview-markdown-content')),
        findsNothing,
      );
    },
  );

  testWidgets('files panel preview can be resized by dragging the handle', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final createdControllers = <_FilesWorkspaceController>[];
    final profile = ServerProfile(
      id: 'server',
      label: 'Mock',
      baseUrl: 'http://localhost:3000',
    );
    final appController = _StaticAppController(
      profile: profile,
      workspaceControllerFactory:
          ({required profile, required directory, initialSessionId}) {
            final controller = _FilesWorkspaceController(
              profile: profile,
              directory: directory,
              initialSessionId: initialSessionId,
            );
            createdControllers.add(controller);
            return controller;
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
    await tester.pumpAndSettle();
    await createdControllers.single.selectFile('README.md');
    await tester.pumpAndSettle();

    final panelFinder = find.byKey(
      const ValueKey<String>('files-preview-panel'),
    );
    final handleFinder = find.byKey(
      const ValueKey<String>('files-preview-resize-handle'),
    );

    final initialHeight = tester.getSize(panelFinder).height;
    await tester.drag(handleFinder, const Offset(0, -120));
    await tester.pump();

    final resizedHeight = tester.getSize(panelFinder).height;
    expect(resizedHeight, greaterThan(initialHeight));
  });

  testWidgets('review panel uses diff-style colors for file status text', (
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
            return _FilesWorkspaceController(
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
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('workspace-side-tab-review-button')),
    );
    await tester.pumpAndSettle();

    final statusText = tester.widget<Text>(
      find.byKey(const ValueKey<String>('review-status-README.md')),
    );
    final statusSpans = (statusText.textSpan! as TextSpan).children!
        .whereType<TextSpan>()
        .toList(growable: false);
    final surfaces = AppTheme.dark().extension<AppSurfaces>()!;

    expect(
      statusSpans.firstWhere((span) => span.text == 'modified').style?.color,
      surfaces.warning,
    );
    expect(
      statusSpans.firstWhere((span) => span.text == '+4').style?.color,
      surfaces.success,
    );
    expect(
      statusSpans.firstWhere((span) => span.text == '-1').style?.color,
      surfaces.danger,
    );
  });

  testWidgets(
    'review panel renders session diff entries instead of generic file status entries',
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
              return _FilesWorkspaceController(
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
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('workspace-side-tab-review-button')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('review-status-README.md')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('review-status-lib/main.dart')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('review-status-pubspec.yaml')),
        findsNothing,
      );
    },
  );

  testWidgets('side panel renders the redesigned tab switcher controls', (
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
            return _FilesWorkspaceController(
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
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('workspace-side-tab-switcher')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('workspace-side-tab-review-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('workspace-side-tab-files-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('workspace-side-tab-context-button')),
      findsOneWidget,
    );
  });

  testWidgets('review panel loads diff preview for the selected file', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final createdControllers = <_FilesWorkspaceController>[];
    final profile = ServerProfile(
      id: 'server',
      label: 'Mock',
      baseUrl: 'http://localhost:3000',
    );
    final appController = _StaticAppController(
      profile: profile,
      workspaceControllerFactory:
          ({required profile, required directory, initialSessionId}) {
            final controller = _FilesWorkspaceController(
              profile: profile,
              directory: directory,
              initialSessionId: initialSessionId,
            );
            createdControllers.add(controller);
            return controller;
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
    await tester.pumpAndSettle();

    createdControllers.single.setSideTab(WorkspaceSideTab.review);
    await tester.pumpAndSettle();

    await createdControllers.single.selectReviewFile('lib/main.dart');
    await tester.pumpAndSettle();

    expect(createdControllers.single.selectReviewFileCalls, <String>[
      'lib/main.dart',
    ]);
    expect(find.textContaining('diff --git a/lib/main.dart'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('review-diff-blur')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('review-diff-unified-view')),
      findsOneWidget,
    );

    await tester.tap(find.byIcon(Icons.view_week_rounded));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('review-diff-split-view')),
      findsOneWidget,
    );

    await tester.tap(find.byIcon(Icons.view_stream_rounded));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('review-diff-unified-view')),
      findsOneWidget,
    );

    final diffSurface = tester.widget<Container>(
      find.byKey(const ValueKey<String>('review-diff-surface')),
    );
    final decoration = diffSurface.decoration! as BoxDecoration;
    expect(decoration.gradient, isNull);
    expect(decoration.color, isNotNull);
    expect(decoration.color!.a, lessThan(1));
  });

  testWidgets('review panel shows a Git init CTA for projects without VCS', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final createdControllers = <_NoVcsWorkspaceController>[];
    final profile = ServerProfile(
      id: 'server',
      label: 'Mock',
      baseUrl: 'http://localhost:3000',
    );
    final appController = _StaticAppController(
      profile: profile,
      workspaceControllerFactory:
          ({required profile, required directory, initialSessionId}) {
            final controller = _NoVcsWorkspaceController(
              profile: profile,
              directory: directory,
              initialSessionId: initialSessionId,
            );
            createdControllers.add(controller);
            return controller;
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
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('workspace-side-tab-review-button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('review-no-vcs-title')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('review-init-git-button')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('review-init-git-button')),
    );
    await tester.pumpAndSettle();

    expect(createdControllers.single.initializeGitCallCount, 1);
    expect(createdControllers.single.project?.vcs, 'git');
    expect(find.text('No file changes yet.'), findsOneWidget);
  });

  testWidgets(
    'review panel shows a snapshot-disabled empty state when tracking is off',
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
              return _NoSnapshotWorkspaceController(
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
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('workspace-side-tab-review-button')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('review-no-snapshot-title')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('review-no-snapshot-message')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('review-init-git-button')),
        findsNothing,
      );
      expect(find.text('No file changes yet.'), findsNothing);
    },
  );

  testWidgets('review diff line comments can be added to composer context', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final createdControllers = <_FilesWorkspaceController>[];
    final profile = ServerProfile(
      id: 'server',
      label: 'Mock',
      baseUrl: 'http://localhost:3000',
    );
    final appController = _StaticAppController(
      profile: profile,
      workspaceControllerFactory:
          ({required profile, required directory, initialSessionId}) {
            final controller = _FilesWorkspaceController(
              profile: profile,
              directory: directory,
              initialSessionId: initialSessionId,
            );
            createdControllers.add(controller);
            return controller;
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
    await tester.pumpAndSettle();

    createdControllers.single.setSideTab(WorkspaceSideTab.review);
    await tester.pumpAndSettle();
    await createdControllers.single.selectReviewFile('README.md');
    await tester.pumpAndSettle();

    final lineCommentButton = find.byKey(
      const ValueKey<String>(
        'review-line-comment-button-README.md-old-none-new-1',
      ),
      skipOffstage: false,
    );
    await tester.dragUntilVisible(
      lineCommentButton,
      find.byType(Scrollable).last,
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    await tester.tap(lineCommentButton);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('review-line-comment-editor')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey<String>('review-line-comment-field')),
      'Focus on whether the new heading and extra docs belong together.',
    );
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey<String>('review-line-comment-submit')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('review-line-comment-editor')),
      findsNothing,
    );
    expect(find.text('Review · README.md · new line 1.txt'), findsOneWidget);
  });

  testWidgets('review panel preview can be resized by dragging the handle', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final createdControllers = <_FilesWorkspaceController>[];
    final profile = ServerProfile(
      id: 'server',
      label: 'Mock',
      baseUrl: 'http://localhost:3000',
    );
    final appController = _StaticAppController(
      profile: profile,
      workspaceControllerFactory:
          ({required profile, required directory, initialSessionId}) {
            final controller = _FilesWorkspaceController(
              profile: profile,
              directory: directory,
              initialSessionId: initialSessionId,
            );
            createdControllers.add(controller);
            return controller;
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
    await tester.pumpAndSettle();

    createdControllers.single.setSideTab(WorkspaceSideTab.review);
    await tester.pumpAndSettle();
    await createdControllers.single.selectReviewFile('README.md');
    await tester.pumpAndSettle();

    final panelFinder = find.byKey(
      const ValueKey<String>('review-preview-panel'),
    );
    final handleFinder = find.byKey(
      const ValueKey<String>('review-preview-resize-handle'),
    );

    final initialHeight = tester.getSize(panelFinder).height;
    await tester.drag(handleFinder, const Offset(0, -120));
    await tester.pump();

    final resizedHeight = tester.getSize(panelFinder).height;
    expect(resizedHeight, greaterThan(initialHeight));
  });
}

class _WorkspaceRouteHarness extends StatelessWidget {
  const _WorkspaceRouteHarness({
    required this.controller,
    required this.initialRoute,
  });

  final WebParityAppController controller;
  final String initialRoute;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      controller: controller,
      child: MaterialApp(
        theme: AppTheme.dark(),
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
    required WorkspaceControllerFactory workspaceControllerFactory,
  }) : super(workspaceControllerFactory: workspaceControllerFactory);

  final ServerProfile profile;

  @override
  ServerProfile? get selectedProfile => profile;
}

class _FilesWorkspaceController extends WorkspaceController {
  _FilesWorkspaceController({
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
      title: 'Session One',
      version: '1',
      updatedAt: DateTime.fromMillisecondsSinceEpoch(1710000001000),
    ),
  ];

  static final Map<String, String> _previewByPath = <String, String>{
    'README.md': '# README preview',
    'pubspec.yaml': 'name: demo_workspace',
    'lib/main.dart': '// lib/main.dart preview',
  };

  static final Map<String, String> _diffByPath = <String, String>{
    'README.md':
        'diff --git a/README.md b/README.md\n@@ -1 +1,2 @@\n-Old title\n+README preview\n+More docs',
    'lib/main.dart':
        'diff --git a/lib/main.dart b/lib/main.dart\n@@ -0,0 +1,3 @@\n+void main() {\n+  print("demo");\n+}',
  };

  final List<String> selectFileCalls = <String>[];
  final List<String> toggleDirectoryCalls = <String>[];
  final List<String> selectReviewFileCalls = <String>[];

  bool _loading = true;
  WorkspaceSideTab _sideTab = WorkspaceSideTab.files;
  String? _selectedSessionId;
  FileBrowserBundle? _fileBundle;
  Set<String> _expandedDirectories = <String>{};
  String? _selectedReviewPath;
  FileDiffSummary? _reviewDiff;
  List<FileStatusSummary> _reviewStatuses = const <FileStatusSummary>[];

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
  WorkspaceSideTab get sideTab => _sideTab;

  @override
  FileBrowserBundle? get fileBundle => _fileBundle;

  @override
  bool get loadingFilePreview => false;

  @override
  Set<String> get expandedFileDirectories => _expandedDirectories;

  @override
  String? get loadingFileDirectoryPath => null;

  @override
  String? get selectedReviewPath => _selectedReviewPath;

  @override
  FileDiffSummary? get reviewDiff => _reviewDiff;

  @override
  List<FileStatusSummary> get reviewStatuses => _reviewStatuses;

  @override
  bool get loadingReviewDiff => false;

  @override
  String? get reviewDiffError => null;

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
    _fileBundle = FileBrowserBundle(
      nodes: const <FileNodeSummary>[
        FileNodeSummary(
          name: 'README.md',
          path: 'README.md',
          type: 'file',
          ignored: false,
        ),
        FileNodeSummary(
          name: 'pubspec.yaml',
          path: 'pubspec.yaml',
          type: 'file',
          ignored: false,
        ),
        FileNodeSummary(
          name: 'lib',
          path: 'lib',
          type: 'directory',
          ignored: false,
        ),
      ],
      searchResults: const <String>[],
      textMatches: const <TextMatchSummary>[],
      symbols: const <SymbolSummary>[],
      statuses: const <FileStatusSummary>[
        FileStatusSummary(
          path: 'README.md',
          status: 'modified',
          added: 4,
          removed: 1,
        ),
        FileStatusSummary(
          path: 'lib/main.dart',
          status: 'added',
          added: 22,
          removed: 0,
        ),
        FileStatusSummary(
          path: 'pubspec.yaml',
          status: 'modified',
          added: 1,
          removed: 1,
        ),
      ],
      preview: null,
      selectedPath: null,
    );
    _reviewStatuses = const <FileStatusSummary>[
      FileStatusSummary(
        path: 'README.md',
        status: 'modified',
        added: 4,
        removed: 1,
      ),
      FileStatusSummary(
        path: 'lib/main.dart',
        status: 'added',
        added: 22,
        removed: 0,
      ),
    ];
    _selectedReviewPath = null;
    _reviewDiff = null;
    notifyListeners();
  }

  @override
  void setSideTab(WorkspaceSideTab value) {
    _sideTab = value;
    notifyListeners();
  }

  @override
  Future<void> selectFile(String path) async {
    selectFileCalls.add(path);
    _fileBundle = _fileBundle?.copyWith(
      selectedPath: path,
      preview: FileContentSummary(
        type: 'text',
        content: _previewByPath[path] ?? '',
      ),
    );
    notifyListeners();
  }

  @override
  Future<void> toggleFileDirectory(String path) async {
    toggleDirectoryCalls.add(path);
    if (_expandedDirectories.contains(path)) {
      _expandedDirectories = <String>{..._expandedDirectories}..remove(path);
    } else {
      _expandedDirectories = <String>{..._expandedDirectories, path};
      if (path == 'lib' &&
          !(_fileBundle?.nodes.any((node) => node.path == 'lib/main.dart') ??
              false)) {
        _fileBundle = _fileBundle?.copyWith(
          nodes: <FileNodeSummary>[
            ...?_fileBundle?.nodes,
            const FileNodeSummary(
              name: 'main.dart',
              path: 'lib/main.dart',
              type: 'file',
              ignored: false,
            ),
          ],
        );
      }
    }
    notifyListeners();
  }

  @override
  Future<void> selectReviewFile(String path) async {
    selectReviewFileCalls.add(path);
    _selectedReviewPath = path;
    _reviewDiff = FileDiffSummary(path: path, content: _diffByPath[path] ?? '');
    notifyListeners();
  }
}

class _NoVcsWorkspaceController extends WorkspaceController {
  _NoVcsWorkspaceController({
    required super.profile,
    required super.directory,
    super.initialSessionId,
  });

  static final List<SessionSummary> _sessions = <SessionSummary>[
    SessionSummary(
      id: 'ses_1',
      directory: '/workspace/demo',
      title: 'Session One',
      version: '1',
      updatedAt: DateTime.fromMillisecondsSinceEpoch(1710000001000),
    ),
  ];

  int initializeGitCallCount = 0;
  bool _loading = true;
  WorkspaceSideTab _sideTab = WorkspaceSideTab.review;
  ProjectTarget? _project = const ProjectTarget(
    directory: '/workspace/demo',
    label: 'Demo',
    source: 'server',
  );
  String? _selectedSessionId;

  @override
  bool get loading => _loading;

  @override
  WorkspaceSideTab get sideTab => _sideTab;

  @override
  ProjectTarget? get project => _project;

  @override
  List<ProjectTarget> get availableProjects =>
      _project == null ? const <ProjectTarget>[] : <ProjectTarget>[_project!];

  @override
  List<SessionSummary> get sessions => _sessions;

  @override
  String? get selectedSessionId => _selectedSessionId;

  @override
  SessionSummary? get selectedSession => _sessions.first;

  @override
  List<ChatMessage> get messages => const <ChatMessage>[];

  @override
  List<FileStatusSummary> get reviewStatuses => const <FileStatusSummary>[];

  @override
  bool get loadingReviewDiff => false;

  @override
  String? get reviewDiffError => null;

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

  @override
  void setSideTab(WorkspaceSideTab value) {
    _sideTab = value;
    notifyListeners();
  }

  @override
  Future<void> initializeGitRepository() async {
    initializeGitCallCount += 1;
    _project = _project?.copyWith(vcs: 'git', branch: 'main');
    notifyListeners();
  }
}

class _NoSnapshotWorkspaceController extends WorkspaceController {
  _NoSnapshotWorkspaceController({
    required super.profile,
    required super.directory,
    super.initialSessionId,
  });

  static final List<SessionSummary> _sessions = <SessionSummary>[
    SessionSummary(
      id: 'ses_1',
      directory: '/workspace/demo',
      title: 'Session One',
      version: '1',
      updatedAt: DateTime.fromMillisecondsSinceEpoch(1710000001000),
    ),
  ];

  static final ConfigSnapshot _configSnapshot = ConfigSnapshot(
    config: RawJsonDocument(<String, Object?>{'snapshot': false}),
    providerConfig: RawJsonDocument(<String, Object?>{}),
  );

  bool _loading = true;
  WorkspaceSideTab _sideTab = WorkspaceSideTab.review;
  String? _selectedSessionId;

  @override
  bool get loading => _loading;

  @override
  WorkspaceSideTab get sideTab => _sideTab;

  @override
  ProjectTarget? get project => const ProjectTarget(
    directory: '/workspace/demo',
    label: 'Demo',
    source: 'server',
    vcs: 'git',
    branch: 'main',
  );

  @override
  List<ProjectTarget> get availableProjects => <ProjectTarget>[project!];

  @override
  ConfigSnapshot? get configSnapshot => _configSnapshot;

  @override
  List<SessionSummary> get sessions => _sessions;

  @override
  String? get selectedSessionId => _selectedSessionId;

  @override
  SessionSummary? get selectedSession => _sessions.first;

  @override
  List<ChatMessage> get messages => const <ChatMessage>[];

  @override
  List<FileStatusSummary> get reviewStatuses => const <FileStatusSummary>[];

  @override
  bool get loadingReviewDiff => false;

  @override
  String? get reviewDiffError => null;

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

  @override
  void setSideTab(WorkspaceSideTab value) {
    _sideTab = value;
    notifyListeners();
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

List<TextSpan> _flattenTextSpans(InlineSpan span) {
  final flattened = <TextSpan>[];
  void visit(InlineSpan current) {
    if (current is TextSpan) {
      if ((current.text ?? '').isNotEmpty) {
        flattened.add(current);
      }
      final children = current.children;
      if (children != null) {
        for (final child in children) {
          visit(child);
        }
      }
    }
  }

  visit(span);
  return flattened;
}
