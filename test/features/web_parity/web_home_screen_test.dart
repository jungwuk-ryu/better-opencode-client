import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:better_opencode_client/l10n/app_localizations.dart';
import 'package:better_opencode_client/src/app/app_controller.dart';
import 'package:better_opencode_client/src/app/app_routes.dart';
import 'package:better_opencode_client/src/app/app_scope.dart';
import 'package:better_opencode_client/src/app/flavor.dart';
import 'package:better_opencode_client/src/core/connection/connection_models.dart';
import 'package:better_opencode_client/src/core/network/opencode_server_probe.dart';
import 'package:better_opencode_client/src/core/spec/capability_registry.dart';
import 'package:better_opencode_client/src/core/spec/probe_snapshot.dart';
import 'package:better_opencode_client/src/design_system/app_theme.dart';
import 'package:better_opencode_client/src/features/chat/chat_models.dart';
import 'package:better_opencode_client/src/features/projects/project_models.dart';
import 'package:better_opencode_client/src/features/projects/project_store.dart';
import 'package:better_opencode_client/src/features/tools/todo_models.dart';
import 'package:better_opencode_client/src/features/web_parity/web_home_screen.dart';
import 'package:better_opencode_client/src/features/web_parity/workspace_controller.dart';
import 'package:better_opencode_client/src/features/web_parity/workspace_layout_store.dart';
import 'package:better_opencode_client/src/i18n/locale_controller.dart';
import 'package:better_opencode_client/src/i18n/web_parity_localizations_ja.dart';
import 'package:better_opencode_client/src/i18n/web_parity_localizations_zh.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../test_helpers/responsive_viewports.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('web home renders across the responsive viewport matrix', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final viewport in kResponsiveLayoutViewports) {
      await applyResponsiveTestViewport(tester, viewport.size);

      final profile = ServerProfile(
        id: 'server',
        label: 'Mock',
        baseUrl: 'http://localhost:3000',
      );
      final controller = _MutableHomeAppController(
        profiles: <ServerProfile>[profile],
        selected: profile,
        reports: <String, ServerProbeReport>{
          profile.storageKey: _probeReport(profile, version: '1.0.0'),
        },
        recentProjects: const <ProjectTarget>[
          ProjectTarget(
            directory: '/workspace/demo',
            label: 'Demo',
            source: 'server',
          ),
        ],
      );
      final localeController = LocaleController();

      await tester.pumpWidget(
        AppScope(
          controller: controller,
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: WebParityHomeScreen(
              flavor: AppFlavor.debug,
              localeController: localeController,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final exception = tester.takeException();
      expect(
        exception,
        isNull,
        reason: 'web home layout failed on ${viewport.name}',
      );
      expect(
        find.byType(WebParityHomeScreen),
        findsOneWidget,
        reason: viewport.name,
      );
      expect(
        find.byKey(const ValueKey<String>('home-server-card-server')),
        findsOneWidget,
        reason: viewport.name,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      localeController.dispose();
      await tester.pump();
    }
  });

  testWidgets(
    'opening a recent project from home restores the remembered session route',
    (tester) async {
      _setLargeSurface(tester);
      final profile = ServerProfile(
        id: 'server',
        label: 'Mock',
        baseUrl: 'http://localhost:3000',
      );
      final store = _FakeProjectStore(
        lastWorkspace: const ProjectTarget(
          directory: '/workspace/demo',
          label: 'Demo',
          source: 'server',
          lastSession: ProjectSessionHint(
            id: 'ses_saved',
            title: 'Saved session',
          ),
        ),
      );
      final controller = _MutableHomeAppController(
        profiles: <ServerProfile>[profile],
        selected: profile,
        reports: <String, ServerProbeReport>{
          profile.storageKey: _probeReport(profile, version: '1.0.0'),
        },
        recentProjects: const <ProjectTarget>[
          ProjectTarget(
            directory: '/workspace/demo',
            label: 'Demo',
            source: 'server',
          ),
        ],
      );
      addTearDown(controller.dispose);

      final observer = _RecordingNavigatorObserver();

      await tester.pumpWidget(
        AppScope(
          controller: controller,
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: WebParityHomeScreen(
              flavor: AppFlavor.debug,
              localeController: LocaleController(),
              projectStore: store,
            ),
            navigatorObservers: <NavigatorObserver>[observer],
            onGenerateRoute: (settings) => MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const SizedBox.shrink(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('home-server-card-server')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('home-server-resume-button-server')),
      );
      await tester.pumpAndSettle();

      expect(
        observer.lastRouteName,
        buildWorkspaceRoute('/workspace/demo', sessionId: 'ses_saved'),
      );
      expect(store.savedTarget?.lastSession?.id, 'ses_saved');
    },
  );

  testWidgets(
    'home shows saved servers immediately and the sheet still works',
    (tester) async {
      _setLargeSurface(tester);
      final alpha = ServerProfile(
        id: 'alpha',
        label: 'Alpha',
        baseUrl: 'https://alpha.example.com',
        username: 'ci-bot',
      );
      final beta = ServerProfile(
        id: 'beta',
        label: 'Beta',
        baseUrl: 'https://beta.example.com',
      );
      final controller = _MutableHomeAppController(
        profiles: <ServerProfile>[alpha, beta],
        selected: alpha,
        reports: <String, ServerProbeReport>{
          alpha.storageKey: _probeReport(
            alpha,
            version: '1.2.3',
            classification: ConnectionProbeClassification.ready,
          ),
          beta.storageKey: _probeReport(
            beta,
            version: '0.9.0',
            classification: ConnectionProbeClassification.authFailure,
          ),
        },
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        AppScope(
          controller: controller,
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: WebParityHomeScreen(
              flavor: AppFlavor.debug,
              localeController: LocaleController(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('home-server-card-alpha')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('home-server-card-beta')),
        findsOneWidget,
      );
      expect(find.text('https://alpha.example.com'), findsWidgets);
      expect(find.text('https://beta.example.com'), findsWidgets);
      expect(find.text('Ready'), findsWidgets);
      expect(find.text('Sign In'), findsWidgets);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Manage'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('servers-sheet-add-button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('servers-sheet-card-alpha')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('servers-sheet-card-beta')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('servers-sheet-card-alpha')),
          matching: find.text('v9.9.9'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('servers-sheet-card-alpha')),
          matching: find.text('ci-bot'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('servers-sheet-card-alpha')),
          matching: find.text('Selected'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'compact home keeps server management inline without duplicate sheet shortcuts',
    (tester) async {
      _setCompactSurface(tester);
      final alpha = ServerProfile(
        id: 'alpha',
        label: 'Alpha',
        baseUrl: 'https://alpha.example.com',
      );
      final beta = ServerProfile(
        id: 'beta',
        label: 'Beta',
        baseUrl: 'https://beta.example.com',
      );
      final controller = _MutableHomeAppController(
        profiles: <ServerProfile>[alpha, beta],
        selected: alpha,
        reports: <String, ServerProbeReport>{
          alpha.storageKey: _probeReport(alpha, version: '1.2.3'),
          beta.storageKey: _probeReport(
            beta,
            version: '0.9.0',
            classification: ConnectionProbeClassification.authFailure,
          ),
        },
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        AppScope(
          controller: controller,
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: WebParityHomeScreen(
              flavor: AppFlavor.debug,
              localeController: LocaleController(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(OutlinedButton, 'See Servers'), findsNothing);
      expect(find.byTooltip('Manage'), findsOneWidget);
      expect(find.byType(ListView), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('home-server-card-alpha')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('home-server-card-beta')),
        findsOneWidget,
      );

      final connectButton = find.byKey(
        const ValueKey<String>('home-server-resume-button-alpha'),
      );
      final detailsButton = find.byKey(
        const ValueKey<String>('home-server-details-button-alpha'),
      );
      final moreButton = find.byKey(
        const ValueKey<String>('home-server-more-button-alpha'),
      );

      expect(connectButton, findsOneWidget);
      expect(detailsButton, findsOneWidget);
      expect(moreButton, findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Connect'), findsOneWidget);

      final connectRect = tester.getRect(connectButton);
      final detailsRect = tester.getRect(detailsButton);
      final moreRect = tester.getRect(moreButton);

      expect(detailsRect.top, moreOrLessEquals(connectRect.top));
      expect(moreRect.top, moreOrLessEquals(connectRect.top));
      expect(detailsRect.height, moreOrLessEquals(connectRect.height));
      expect(moreRect.height, moreOrLessEquals(connectRect.height));
    },
  );

  testWidgets('very compact home stacks actions without misaligning the menu', (
    tester,
  ) async {
    await applyResponsiveTestViewport(tester, const Size(319, 568));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final profile = ServerProfile(
      id: 'alpha',
      label: 'Alpha',
      baseUrl: 'https://alpha.example.com',
    );
    final controller = _MutableHomeAppController(
      profiles: <ServerProfile>[profile],
      selected: profile,
      reports: <String, ServerProbeReport>{
        profile.storageKey: _probeReport(profile, version: '1.2.3'),
      },
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      AppScope(
        controller: controller,
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: WebParityHomeScreen(
            flavor: AppFlavor.debug,
            localeController: LocaleController(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final connectButton = find.byKey(
      const ValueKey<String>('home-server-resume-button-alpha'),
    );
    final detailsButton = find.byKey(
      const ValueKey<String>('home-server-details-button-alpha'),
    );
    final moreButton = find.byKey(
      const ValueKey<String>('home-server-more-button-alpha'),
    );

    expect(connectButton, findsOneWidget);
    expect(detailsButton, findsOneWidget);
    expect(moreButton, findsOneWidget);

    final connectRect = tester.getRect(connectButton);
    final detailsRect = tester.getRect(detailsButton);
    final moreRect = tester.getRect(moreButton);

    expect(detailsRect.top, greaterThan(connectRect.top));
    expect(moreRect.top, moreOrLessEquals(detailsRect.top));
    expect(moreRect.height, moreOrLessEquals(detailsRect.height));
    expect(connectRect.width, greaterThan(detailsRect.width));
    expect(tester.takeException(), isNull);
  });

  testWidgets('home localizes server actions for japanese and chinese', (
    tester,
  ) async {
    _setLargeSurface(tester);

    final cases = <({AppLocaleMode mode, Map<String, String> copy})>[
      (mode: AppLocaleMode.japanese, copy: jaWebParityText),
      (mode: AppLocaleMode.chinese, copy: zhWebParityText),
    ];

    for (final testCase in cases) {
      final profile = ServerProfile(
        id: 'server-${testCase.mode.name}',
        label: 'Mock',
        baseUrl: 'https://example.com',
      );
      final controller = _MutableHomeAppController(
        profiles: <ServerProfile>[profile],
        selected: profile,
        reports: <String, ServerProbeReport>{
          profile.storageKey: _probeReport(profile, version: '1.0.0'),
        },
      );
      final localeController = LocaleController();
      await localeController.setMode(testCase.mode);

      await tester.pumpWidget(
        AppScope(
          controller: controller,
          child: MaterialApp(
            theme: AppTheme.dark(),
            locale: localeController.locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: WebParityHomeScreen(
              flavor: AppFlavor.debug,
              localeController: localeController,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(testCase.copy['Ready']!),
        findsWidgets,
        reason: testCase.mode.name,
      );

      expect(
        find.byKey(const ValueKey<String>('home-add-server-button')),
        findsOneWidget,
        reason: testCase.mode.name,
      );
      expect(
        find.text(testCase.copy['Add Server']!),
        findsWidgets,
        reason: testCase.mode.name,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      localeController.dispose();
      await tester.pump();
    }
  });

  testWidgets('see servers sheet can add delete and reorder servers', (
    tester,
  ) async {
    _setLargeSurface(tester);
    final alpha = ServerProfile(
      id: 'alpha',
      label: 'Alpha',
      baseUrl: 'https://alpha.example.com',
    );
    final beta = ServerProfile(
      id: 'beta',
      label: 'Beta',
      baseUrl: 'https://beta.example.com',
    );
    final controller = _MutableHomeAppController(
      profiles: <ServerProfile>[alpha, beta],
      selected: alpha,
      reports: <String, ServerProbeReport>{
        alpha.storageKey: _probeReport(alpha, version: '1.0.0'),
        beta.storageKey: _probeReport(beta, version: '1.0.1'),
      },
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      AppScope(
        controller: controller,
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: WebParityHomeScreen(
            flavor: AppFlavor.debug,
            localeController: LocaleController(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Manage'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('servers-sheet-select-beta')),
    );
    await tester.pumpAndSettle();
    expect(controller.selectedProfile?.id, 'beta');

    await tester.tap(
      find.byKey(const ValueKey<String>('servers-sheet-add-button')),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('servers-editor-label-field')),
      'Gamma',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('servers-editor-url-field')),
      'https://gamma.example.com',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('servers-editor-save-button')),
    );
    await tester.pumpAndSettle();

    final gammaId = controller.selectedProfile?.id;
    expect(gammaId, isNotNull);
    expect(
      find.byKey(ValueKey<String>('servers-sheet-card-$gammaId')),
      findsOneWidget,
    );
    expect(controller.profiles.first.id, gammaId);

    await tester.tap(
      find.byKey(ValueKey<String>('servers-sheet-move-down-$gammaId')),
    );
    await tester.pumpAndSettle();
    expect(controller.profiles[1].id, gammaId);

    await tester.tap(
      find.byKey(const ValueKey<String>('servers-sheet-delete-beta')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(controller.profiles.any((profile) => profile.id == 'beta'), isFalse);
  });

  testWidgets(
    'home detail shows remembered panes, running sessions, todo progress, and project add tile',
    (tester) async {
      _setLargeSurface(tester);
      final profile = ServerProfile(
        id: 'alpha',
        label: 'Alpha',
        baseUrl: 'https://alpha.example.com',
      );
      final controller = _MutableHomeAppController(
        profiles: <ServerProfile>[profile],
        selected: profile,
        reports: <String, ServerProbeReport>{
          profile.storageKey: _probeReport(profile, version: '1.2.3'),
        },
        recentProjects: const <ProjectTarget>[
          ProjectTarget(
            directory: '/workspace/demo',
            label: 'Demo',
            source: 'server',
          ),
          ProjectTarget(
            directory: '/workspace/review',
            label: 'Review',
            source: 'server',
          ),
        ],
        workspacePaneLayouts: <String, WorkspacePaneLayoutSnapshot>{
          profile.storageKey: const WorkspacePaneLayoutSnapshot(
            activePaneId: 'pane_main',
            panes: <WorkspacePaneLayoutPane>[
              WorkspacePaneLayoutPane(
                id: 'pane_main',
                directory: '/workspace/demo',
                sessionId: 'ses_live',
              ),
              WorkspacePaneLayoutPane(
                id: 'pane_review',
                directory: '/workspace/review',
                sessionId: 'ses_idle',
              ),
            ],
          ),
        },
        workspaceControllers: <String, WorkspaceController>{
          '${profile.storageKey}::/workspace/demo':
              _FakeHomeWorkspaceController(
                profile: profile,
                directory: '/workspace/demo',
                projectTarget: const ProjectTarget(
                  directory: '/workspace/demo',
                  label: 'Demo',
                  source: 'server',
                ),
                availableProjects: const <ProjectTarget>[
                  ProjectTarget(
                    directory: '/workspace/demo',
                    label: 'Demo',
                    source: 'server',
                  ),
                  ProjectTarget(
                    directory: '/workspace/review',
                    label: 'Review',
                    source: 'server',
                  ),
                  ProjectTarget(
                    directory: '/workspace/ops',
                    label: 'Ops',
                    source: 'server',
                  ),
                ],
                sessionItems: <SessionSummary>[
                  SessionSummary(
                    id: 'ses_live',
                    directory: '/workspace/demo',
                    title: 'Live deploy',
                    version: '1',
                    updatedAt: DateTime(2026, 3, 27, 1, 30),
                  ),
                  SessionSummary(
                    id: 'ses_done',
                    directory: '/workspace/demo',
                    title: 'Done session',
                    version: '1',
                    updatedAt: DateTime(2026, 3, 27, 1, 0),
                  ),
                ],
                statusItems: <String, SessionStatusSummary>{
                  'ses_live': const SessionStatusSummary(type: 'running'),
                  'ses_done': const SessionStatusSummary(type: 'idle'),
                },
                todosBySession: <String, List<TodoItem>>{
                  'ses_live': const <TodoItem>[
                    TodoItem(
                      id: 'todo_1',
                      content: 'Ship dashboard',
                      status: 'completed',
                      priority: 'high',
                    ),
                    TodoItem(
                      id: 'todo_2',
                      content: 'Polish cards',
                      status: 'in_progress',
                      priority: 'medium',
                    ),
                  ],
                },
              ),
          '${profile.storageKey}::/workspace/review':
              _FakeHomeWorkspaceController(
                profile: profile,
                directory: '/workspace/review',
                projectTarget: const ProjectTarget(
                  directory: '/workspace/review',
                  label: 'Review',
                  source: 'server',
                ),
                sessionItems: <SessionSummary>[
                  SessionSummary(
                    id: 'ses_idle',
                    directory: '/workspace/review',
                    title: 'Review queue',
                    version: '1',
                    updatedAt: DateTime(2026, 3, 27, 1, 10),
                  ),
                ],
                statusItems: <String, SessionStatusSummary>{
                  'ses_idle': const SessionStatusSummary(type: 'idle'),
                },
              ),
        },
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        AppScope(
          controller: controller,
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: WebParityHomeScreen(
              flavor: AppFlavor.debug,
              localeController: LocaleController(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Details'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('home-pane-card-pane_main')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('home-pane-card-pane_review')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('home-running-session-ses_live')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey<String>('home-running-session-ses_live'),
          ),
          matching: find.text('Live deploy'),
        ),
        findsOneWidget,
      );
      expect(find.text('1/2 todos complete'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('home-server-project-add-button')),
        findsOneWidget,
      );
      expect(find.widgetWithText(ActionChip, 'Ops'), findsOneWidget);
    },
  );

  testWidgets(
    'compact home detail gives server actions a stable full-width row',
    (tester) async {
      _setCompactSurface(tester);
      final profile = ServerProfile(
        id: 'alpha',
        label: 'Alpha',
        baseUrl: 'https://alpha.example.com',
      );
      final controller = _MutableHomeAppController(
        profiles: <ServerProfile>[profile],
        selected: profile,
        reports: <String, ServerProbeReport>{
          profile.storageKey: _probeReport(profile, version: '1.2.3'),
        },
        workspacePaneLayouts: <String, WorkspacePaneLayoutSnapshot>{
          profile.storageKey: const WorkspacePaneLayoutSnapshot(
            activePaneId: 'pane_main',
            panes: <WorkspacePaneLayoutPane>[
              WorkspacePaneLayoutPane(
                id: 'pane_main',
                directory: '/workspace/demo',
              ),
            ],
          ),
        },
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        AppScope(
          controller: controller,
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: WebParityHomeScreen(
              flavor: AppFlavor.debug,
              localeController: LocaleController(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('home-server-details-button-alpha')),
      );
      await tester.pumpAndSettle();

      final resumeButton = find.byKey(
        const ValueKey<String>('home-server-detail-resume-button-alpha'),
      );
      final editButton = find.byKey(
        const ValueKey<String>('home-server-detail-edit-button-alpha'),
      );
      final copyButton = find.byKey(
        const ValueKey<String>('home-server-detail-copy-link-button-alpha'),
      );

      expect(resumeButton, findsOneWidget);
      expect(editButton, findsOneWidget);
      expect(copyButton, findsOneWidget);

      final resumeRect = tester.getRect(resumeButton);
      final editRect = tester.getRect(editButton);
      final copyRect = tester.getRect(copyButton);

      expect(resumeRect.width, greaterThan(300));
      expect(editRect.top, greaterThan(resumeRect.bottom));
      expect(copyRect.top, moreOrLessEquals(editRect.top));
      expect(editRect.left, moreOrLessEquals(resumeRect.left));
      expect(copyRect.right, moreOrLessEquals(resumeRect.right));
      expect(copyRect.left, greaterThan(editRect.right));
      expect(editRect.width, moreOrLessEquals(copyRect.width));
      expect(resumeRect.width, greaterThan(editRect.width));
    },
  );

  testWidgets('wide home detail keeps server actions aligned', (tester) async {
    _setLargeSurface(tester);
    final profile = ServerProfile(
      id: 'alpha',
      label: 'Alpha',
      baseUrl: 'https://alpha.example.com',
    );
    final controller = _MutableHomeAppController(
      profiles: <ServerProfile>[profile],
      selected: profile,
      reports: <String, ServerProbeReport>{
        profile.storageKey: _probeReport(profile, version: '1.2.3'),
      },
      workspacePaneLayouts: <String, WorkspacePaneLayoutSnapshot>{
        profile.storageKey: const WorkspacePaneLayoutSnapshot(
          activePaneId: 'pane_main',
          panes: <WorkspacePaneLayoutPane>[
            WorkspacePaneLayoutPane(
              id: 'pane_main',
              directory: '/workspace/demo',
            ),
          ],
        ),
      },
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      AppScope(
        controller: controller,
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: WebParityHomeScreen(
            flavor: AppFlavor.debug,
            localeController: LocaleController(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('home-server-details-button-alpha')),
    );
    await tester.pumpAndSettle();

    final resumeButton = find.byKey(
      const ValueKey<String>('home-server-detail-resume-button-alpha'),
    );
    final editButton = find.byKey(
      const ValueKey<String>('home-server-detail-edit-button-alpha'),
    );
    final copyButton = find.byKey(
      const ValueKey<String>('home-server-detail-copy-link-button-alpha'),
    );

    expect(resumeButton, findsOneWidget);
    expect(editButton, findsOneWidget);
    expect(copyButton, findsOneWidget);

    final resumeRect = tester.getRect(resumeButton);
    final editRect = tester.getRect(editButton);
    final copyRect = tester.getRect(copyButton);

    expect(editRect.top, greaterThan(resumeRect.bottom));
    expect(copyRect.top, moreOrLessEquals(editRect.top));
    expect(copyRect.left, greaterThan(editRect.right));
    if (resumeRect.width > 320) {
      expect(editRect.left, moreOrLessEquals(resumeRect.left));
      expect(copyRect.right, moreOrLessEquals(resumeRect.right));
      expect(editRect.width, moreOrLessEquals(copyRect.width));
    } else {
      expect(resumeRect.right, moreOrLessEquals(copyRect.right));
    }
  });

  testWidgets(
    'resume workspace restores the active pane for the selected server',
    (tester) async {
      _setLargeSurface(tester);
      final profile = ServerProfile(
        id: 'alpha',
        label: 'Alpha',
        baseUrl: 'https://alpha.example.com',
      );
      final store = _FakeProjectStore(
        lastWorkspace: const ProjectTarget(
          directory: '/workspace/demo',
          label: 'Demo',
          source: 'server',
          lastSession: ProjectSessionHint(
            id: 'ses_saved',
            title: 'Saved session',
          ),
        ),
      );
      final controller = _MutableHomeAppController(
        profiles: <ServerProfile>[profile],
        selected: profile,
        reports: <String, ServerProbeReport>{
          profile.storageKey: _probeReport(profile, version: '1.2.3'),
        },
        workspacePaneLayouts: <String, WorkspacePaneLayoutSnapshot>{
          profile.storageKey: const WorkspacePaneLayoutSnapshot(
            activePaneId: 'pane_focus',
            panes: <WorkspacePaneLayoutPane>[
              WorkspacePaneLayoutPane(
                id: 'pane_focus',
                directory: '/workspace/review',
                sessionId: 'ses_focus',
              ),
              WorkspacePaneLayoutPane(
                id: 'pane_other',
                directory: '/workspace/demo',
                sessionId: 'ses_saved',
              ),
            ],
          ),
        },
      );
      addTearDown(controller.dispose);

      final observer = _RecordingNavigatorObserver();

      await tester.pumpWidget(
        AppScope(
          controller: controller,
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: WebParityHomeScreen(
              flavor: AppFlavor.debug,
              localeController: LocaleController(),
              projectStore: store,
            ),
            navigatorObservers: <NavigatorObserver>[observer],
            onGenerateRoute: (settings) => MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const SizedBox.shrink(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('home-server-resume-button-alpha')),
      );
      await tester.pumpAndSettle();

      expect(
        observer.lastRouteName,
        buildWorkspaceRoute('/workspace/review', sessionId: 'ses_focus'),
      );
    },
  );
}

class _MutableHomeAppController extends WebParityAppController {
  _MutableHomeAppController({
    required List<ServerProfile> profiles,
    required ServerProfile selected,
    required Map<String, ServerProbeReport> reports,
    List<ProjectTarget> recentProjects = const <ProjectTarget>[],
    Map<String, WorkspacePaneLayoutSnapshot> workspacePaneLayouts =
        const <String, WorkspacePaneLayoutSnapshot>{},
    Map<String, WorkspaceController> workspaceControllers =
        const <String, WorkspaceController>{},
  }) : _profiles = List<ServerProfile>.from(profiles),
       _selectedProfile = selected,
       _reports = Map<String, ServerProbeReport>.from(reports),
       _recentProjects = List<ProjectTarget>.from(recentProjects),
       _workspacePaneLayouts = Map<String, WorkspacePaneLayoutSnapshot>.from(
         workspacePaneLayouts,
       ),
       _workspaceControllers = Map<String, WorkspaceController>.from(
         workspaceControllers,
       );

  List<ServerProfile> _profiles;
  ServerProfile? _selectedProfile;
  Map<String, ServerProbeReport> _reports;
  final List<ProjectTarget> _recentProjects;
  final Map<String, WorkspacePaneLayoutSnapshot> _workspacePaneLayouts;
  final Map<String, WorkspaceController> _workspaceControllers;

  @override
  bool get loading => false;

  @override
  List<ServerProfile> get profiles =>
      List<ServerProfile>.unmodifiable(_profiles);

  @override
  Map<String, ServerProbeReport> get reports =>
      Map<String, ServerProbeReport>.unmodifiable(_reports);

  @override
  ServerProfile? get selectedProfile => _selectedProfile;

  @override
  List<ProjectTarget> get recentProjects =>
      List<ProjectTarget>.unmodifiable(_recentProjects);

  @override
  ServerProbeReport? get selectedReport {
    final selectedProfile = _selectedProfile;
    if (selectedProfile == null) {
      return null;
    }
    return _reports[selectedProfile.storageKey];
  }

  @override
  WorkspacePaneLayoutSnapshot? workspacePaneLayoutFor(ServerProfile? profile) {
    if (profile == null) {
      return null;
    }
    return _workspacePaneLayouts[profile.storageKey];
  }

  @override
  Future<WorkspacePaneLayoutSnapshot?> ensureWorkspacePaneLayout(
    ServerProfile profile,
  ) async {
    return workspacePaneLayoutFor(profile);
  }

  @override
  WorkspaceController obtainWorkspaceController({
    required ServerProfile profile,
    required String directory,
    String? initialSessionId,
  }) {
    return _workspaceControllers['${profile.storageKey}::$directory'] ??
        _FakeHomeWorkspaceController(profile: profile, directory: directory);
  }

  @override
  Future<void> selectProfile(ServerProfile profile) async {
    for (final candidate in _profiles) {
      if (candidate.id == profile.id) {
        _selectedProfile = candidate;
        notifyListeners();
        return;
      }
    }
  }

  @override
  Future<ServerProfile> saveProfile(ServerProfile profile) async {
    final existingIndex = _profiles.indexWhere(
      (candidate) => candidate.id == profile.id,
    );
    if (existingIndex >= 0) {
      _profiles[existingIndex] = profile;
    } else {
      _profiles.insert(0, profile);
    }
    _selectedProfile = profile;
    _reports = <String, ServerProbeReport>{
      ..._reports,
      profile.storageKey: _probeReport(profile, version: '2.0.0'),
    };
    notifyListeners();
    return profile;
  }

  @override
  Future<void> deleteServerProfile(ServerProfile profile) async {
    _profiles = _profiles
        .where((candidate) => candidate.id != profile.id)
        .toList(growable: false);
    _reports.remove(profile.storageKey);
    if (_selectedProfile?.id == profile.id) {
      _selectedProfile = _profiles.isEmpty ? null : _profiles.first;
    }
    notifyListeners();
  }

  @override
  Future<void> moveProfile(String profileId, int offset) async {
    final currentIndex = _profiles.indexWhere(
      (candidate) => candidate.id == profileId,
    );
    if (currentIndex < 0) {
      return;
    }
    final nextIndex = (currentIndex + offset).clamp(0, _profiles.length - 1);
    if (nextIndex == currentIndex) {
      return;
    }
    final item = _profiles.removeAt(currentIndex);
    _profiles.insert(nextIndex, item);
    notifyListeners();
  }

  @override
  Future<void> refreshProbe(ServerProfile profile) async {
    final previousClassification =
        _reports[profile.storageKey]?.classification ??
        ConnectionProbeClassification.ready;
    _reports = <String, ServerProbeReport>{
      ..._reports,
      profile.storageKey: _probeReport(
        profile,
        version: '9.9.9',
        classification: previousClassification,
      ),
    };
    notifyListeners();
  }
}

class _FakeProjectStore extends ProjectStore {
  _FakeProjectStore({this.lastWorkspace});

  final ProjectTarget? lastWorkspace;
  ProjectTarget? savedTarget;

  @override
  Future<ProjectTarget?> loadLastWorkspace(String serverStorageKey) async {
    return lastWorkspace;
  }

  @override
  Future<List<ProjectTarget>> recordRecentProject(ProjectTarget target) async {
    return <ProjectTarget>[target];
  }

  @override
  Future<void> saveLastWorkspace({
    required String serverStorageKey,
    required ProjectTarget target,
  }) async {
    savedTarget = target;
  }
}

class _FakeHomeWorkspaceController extends WorkspaceController {
  _FakeHomeWorkspaceController({
    required super.profile,
    required super.directory,
    this.projectTarget,
    this.availableProjects = const <ProjectTarget>[],
    this.sessionItems = const <SessionSummary>[],
    this.statusItems = const <String, SessionStatusSummary>{},
    this.todosBySession = const <String, List<TodoItem>>{},
  });

  final ProjectTarget? projectTarget;
  @override
  final List<ProjectTarget> availableProjects;
  final List<SessionSummary> sessionItems;
  final Map<String, SessionStatusSummary> statusItems;
  final Map<String, List<TodoItem>> todosBySession;

  @override
  bool get loading => false;

  @override
  ProjectTarget? get project => projectTarget;

  @override
  List<SessionSummary> get sessions =>
      List<SessionSummary>.unmodifiable(sessionItems);

  @override
  Map<String, SessionStatusSummary> get statuses =>
      Map<String, SessionStatusSummary>.unmodifiable(statusItems);

  @override
  List<TodoItem> todosForSession(String? sessionId) {
    return List<TodoItem>.unmodifiable(
      todosBySession[sessionId?.trim()] ?? const <TodoItem>[],
    );
  }
}

ServerProbeReport _probeReport(
  ServerProfile profile, {
  required String version,
  ConnectionProbeClassification classification =
      ConnectionProbeClassification.ready,
}) {
  final snapshot = ProbeSnapshot(
    name: '${profile.effectiveLabel} server',
    version: version,
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
    },
  );
  return ServerProbeReport(
    snapshot: snapshot,
    capabilityRegistry: CapabilityRegistry.fromSnapshot(snapshot),
    classification: classification,
    summary: 'unused',
    checkedAt: DateTime(2026, 3, 26, 16, 9),
    missingCapabilities: const <String>[],
    discoveredExperimentalPaths: const <String>[],
    sseReady: classification == ConnectionProbeClassification.ready,
    authScheme: classification == ConnectionProbeClassification.authFailure
        ? 'basic'
        : null,
  );
}

class _RecordingNavigatorObserver extends NavigatorObserver {
  String? lastRouteName;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    lastRouteName = route.settings.name;
    super.didPush(route, previousRoute);
  }
}

void _setLargeSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 2200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void _setCompactSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
