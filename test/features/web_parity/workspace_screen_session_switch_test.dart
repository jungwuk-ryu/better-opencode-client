import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:opencode_mobile_remote/src/app/app_controller.dart';
import 'package:opencode_mobile_remote/src/app/app_routes.dart';
import 'package:opencode_mobile_remote/src/app/app_scope.dart';
import 'package:opencode_mobile_remote/src/core/connection/connection_models.dart';
import 'package:opencode_mobile_remote/src/design_system/app_theme.dart';
import 'package:opencode_mobile_remote/src/features/chat/chat_models.dart';
import 'package:opencode_mobile_remote/src/features/chat/prompt_attachment_models.dart';
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

  testWidgets(
    'switching sessions keeps the same page and reuses the directory controller',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final createdControllers = <_RecordingWorkspaceController>[];
      final profile = ServerProfile(
        id: 'server',
        label: 'Mock',
        baseUrl: 'http://localhost:3000',
      );
      final appController = _StaticAppController(
        profile: profile,
        workspaceControllerFactory:
            ({required profile, required directory, initialSessionId}) {
              final controller = _RecordingWorkspaceController(
                profile: profile,
                directory: directory,
                initialSessionId: initialSessionId,
              );
              createdControllers.add(controller);
              return controller;
            },
      );
      addTearDown(appController.dispose);

      final navigatorKey = GlobalKey<NavigatorState>();
      final observer = _RecordingNavigatorObserver();

      await tester.pumpWidget(
        _WorkspaceRouteHarness(
          controller: appController,
          navigatorKey: navigatorKey,
          navigatorObservers: <NavigatorObserver>[observer],
          initialRoute: '/',
        ),
      );
      navigatorKey.currentState!.pushNamed(
        buildWorkspaceRoute('/workspace/demo', sessionId: 'ses_1'),
      );
      await tester.pumpAndSettle();

      expect(createdControllers, hasLength(1));
      expect(createdControllers.single.loadCount, 1);
      expect(createdControllers.single.selectSessionCalls, isEmpty);
      expect(createdControllers.single.selectedSessionId, 'ses_1');
      expect(find.byType(WebParityWorkspaceScreen), findsOneWidget);
      expect(find.text('Ask anything...'), findsOneWidget);
      expect(find.text('hello from one'), findsOneWidget);

      final initialRouteName = observer.lastRouteName;

      await tester.tap(find.text('Session Two'));
      await tester.pumpAndSettle();

      expect(createdControllers, hasLength(1));
      expect(createdControllers.single.loadCount, 1);
      expect(createdControllers.single.selectSessionCalls, <String?>['ses_2']);
      expect(createdControllers.single.selectedSessionId, 'ses_2');
      expect(find.text('hello from two'), findsOneWidget);
      expect(observer.lastRouteName, initialRouteName);
      expect(find.byType(WebParityWorkspaceScreen), findsOneWidget);
    },
  );

  testWidgets('switching sessions clears composer focus on compact layouts', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final createdControllers = <_RecordingWorkspaceController>[];
    final profile = ServerProfile(
      id: 'server',
      label: 'Mock',
      baseUrl: 'http://localhost:3000',
    );
    final appController = _StaticAppController(
      profile: profile,
      workspaceControllerFactory:
          ({required profile, required directory, initialSessionId}) {
            final controller = _RecordingWorkspaceController(
              profile: profile,
              directory: directory,
              initialSessionId: initialSessionId,
            );
            createdControllers.add(controller);
            return controller;
          },
    );
    addTearDown(appController.dispose);

    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      _WorkspaceRouteHarness(
        controller: appController,
        navigatorKey: navigatorKey,
        initialRoute: '/',
      ),
    );
    navigatorKey.currentState!.pushNamed(
      buildWorkspaceRoute('/workspace/demo', sessionId: 'ses_1'),
    );
    await tester.pumpAndSettle();

    final composerFinder = find.byKey(
      const ValueKey<String>('composer-text-field'),
    );
    await tester.tap(composerFinder);
    await tester.pump();

    EditableText editableText() =>
        tester.widget<EditableText>(find.byType(EditableText));

    expect(editableText().focusNode.hasFocus, isTrue);
    expect(tester.testTextInput.hasAnyClients, isTrue);

    await createdControllers.single.selectSession('ses_2');
    await tester.pumpAndSettle();

    expect(find.text('hello from two'), findsOneWidget);
    expect(editableText().focusNode.hasFocus, isFalse);
    expect(tester.testTextInput.hasAnyClients, isFalse);
  });

  testWidgets(
    'desktop layout does not show selected pane chrome when only one pane exists',
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
              return _RecordingWorkspaceController(
                profile: profile,
                directory: directory,
                initialSessionId: initialSessionId,
              );
            },
      );
      addTearDown(appController.dispose);

      final navigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        _WorkspaceRouteHarness(
          controller: appController,
          navigatorKey: navigatorKey,
          initialRoute: '/',
        ),
      );
      navigatorKey.currentState!.pushNamed(
        buildWorkspaceRoute('/workspace/demo', sessionId: 'ses_1'),
      );
      await tester.pumpAndSettle();

      final paneContainer = find.byWidgetPredicate(
        (widget) =>
            widget is AnimatedContainer &&
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              'workspace-session-pane-container-',
            ),
      );

      expect(paneContainer, findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget.key is ValueKey<String> &&
              (widget.key! as ValueKey<String>).value.startsWith(
                'workspace-session-pane-selected-badge-',
              ),
        ),
        findsNothing,
      );

      final decoration =
          tester.widget<AnimatedContainer>(paneContainer).decoration
              as BoxDecoration;
      final border = decoration.border! as Border;
      expect(border.top.width, 1);
    },
  );

  testWidgets(
    'new session button creates a fresh session without replacing the page',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final createdControllers = <_RecordingWorkspaceController>[];
      final profile = ServerProfile(
        id: 'server',
        label: 'Mock',
        baseUrl: 'http://localhost:3000',
      );
      final appController = _StaticAppController(
        profile: profile,
        workspaceControllerFactory:
            ({required profile, required directory, initialSessionId}) {
              final controller = _RecordingWorkspaceController(
                profile: profile,
                directory: directory,
                initialSessionId: initialSessionId,
              );
              createdControllers.add(controller);
              return controller;
            },
      );
      addTearDown(appController.dispose);

      final navigatorKey = GlobalKey<NavigatorState>();
      final observer = _RecordingNavigatorObserver();

      await tester.pumpWidget(
        _WorkspaceRouteHarness(
          controller: appController,
          navigatorKey: navigatorKey,
          navigatorObservers: <NavigatorObserver>[observer],
          initialRoute: '/',
        ),
      );
      navigatorKey.currentState!.pushNamed(
        buildWorkspaceRoute('/workspace/demo', sessionId: 'ses_1'),
      );
      await tester.pumpAndSettle();
      final initialRouteName = observer.lastRouteName;

      expect(createdControllers, hasLength(1));
      await tester.tap(
        find.byKey(
          const ValueKey<String>('workspace-sidebar-new-session-button'),
        ),
      );
      await tester.pumpAndSettle();

      expect(createdControllers.single.createEmptySessionCalls, 1);
      expect(createdControllers.single.selectedSessionId, 'ses_new');
      expect(observer.lastRouteName, initialRouteName);
      expect(find.text('Fresh session'), findsAtLeastNWidgets(1));
    },
  );

  testWidgets(
    'desktop layout lets users collapse and reopen both side panels',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final createdControllers = <_RecordingWorkspaceController>[];
      final profile = ServerProfile(
        id: 'server',
        label: 'Mock',
        baseUrl: 'http://localhost:3000',
      );
      final appController = _StaticAppController(
        profile: profile,
        workspaceControllerFactory:
            ({required profile, required directory, initialSessionId}) {
              final controller = _RecordingWorkspaceController(
                profile: profile,
                directory: directory,
                initialSessionId: initialSessionId,
              );
              createdControllers.add(controller);
              return controller;
            },
      );
      addTearDown(appController.dispose);

      final navigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        _WorkspaceRouteHarness(
          controller: appController,
          navigatorKey: navigatorKey,
          initialRoute: '/',
        ),
      );
      navigatorKey.currentState!.pushNamed(
        buildWorkspaceRoute('/workspace/demo', sessionId: 'ses_1'),
      );
      await tester.pumpAndSettle();

      final sidebarReveal = find.byKey(
        const ValueKey<String>('workspace-desktop-sidebar-reveal'),
      );
      final sidePanelReveal = find.byKey(
        const ValueKey<String>('workspace-desktop-side-panel-reveal'),
      );

      expect(tester.getSize(sidebarReveal).width, greaterThan(300));
      expect(tester.getSize(sidePanelReveal).width, greaterThan(300));

      await tester.tap(
        find.byKey(
          const ValueKey<String>('workspace-toggle-sessions-panel-button'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 260));

      expect(tester.getSize(sidebarReveal).width, closeTo(0, 0.1));

      await tester.tap(
        find.byKey(
          const ValueKey<String>('workspace-toggle-side-panel-button'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 260));

      expect(tester.getSize(sidePanelReveal).width, closeTo(0, 0.1));

      await tester.tap(
        find.byKey(
          const ValueKey<String>('workspace-toggle-side-panel-button'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 260));

      expect(tester.getSize(sidePanelReveal).width, greaterThan(300));

      await tester.tap(
        find.byKey(
          const ValueKey<String>('workspace-toggle-sessions-panel-button'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 260));

      expect(tester.getSize(sidebarReveal).width, greaterThan(300));
    },
  );

  testWidgets(
    'desktop layout lets users resize side panels and restores widths across launches',
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
      final firstAppController = _StaticAppController(
        profile: profile,
        workspaceControllerFactory:
            ({required profile, required directory, initialSessionId}) {
              return _RecordingWorkspaceController(
                profile: profile,
                directory: directory,
                initialSessionId: initialSessionId,
              );
            },
      );
      addTearDown(firstAppController.dispose);

      final firstNavigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        _WorkspaceRouteHarness(
          controller: firstAppController,
          navigatorKey: firstNavigatorKey,
          initialRoute: '/',
        ),
      );
      firstNavigatorKey.currentState!.pushNamed(
        buildWorkspaceRoute('/workspace/demo', sessionId: 'ses_1'),
      );
      await tester.pumpAndSettle();

      final sidebarPane = find.byKey(
        const ValueKey<String>('workspace-desktop-sidebar-pane'),
      );
      final sidePanel = find.byKey(
        const ValueKey<String>('workspace-desktop-side-panel'),
      );
      final sessionDeck = find.byKey(
        const ValueKey<String>('workspace-session-pane-deck'),
      );

      final initialSidebarWidth = tester.getSize(sidebarPane).width;
      final initialSidePanelWidth = tester.getSize(sidePanel).width;
      final initialSessionDeckWidth = tester.getSize(sessionDeck).width;

      await tester.drag(
        find.byKey(
          const ValueKey<String>('workspace-desktop-sidebar-resize-handle'),
        ),
        const Offset(96, 0),
      );
      await tester.pumpAndSettle();

      final resizedSidebarWidth = tester.getSize(sidebarPane).width;
      final resizedSessionDeckWidth = tester.getSize(sessionDeck).width;
      expect(resizedSidebarWidth, greaterThan(initialSidebarWidth + 40));
      expect(resizedSessionDeckWidth, lessThan(initialSessionDeckWidth - 40));

      await tester.drag(
        find.byKey(
          const ValueKey<String>('workspace-desktop-side-panel-resize-handle'),
        ),
        const Offset(-72, 0),
      );
      await tester.pumpAndSettle();

      final resizedSidePanelWidth = tester.getSize(sidePanel).width;
      expect(resizedSidePanelWidth, greaterThan(initialSidePanelWidth + 30));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));

      final restoredAppController = _StaticAppController(
        profile: profile,
        workspaceControllerFactory:
            ({required profile, required directory, initialSessionId}) {
              return _RecordingWorkspaceController(
                profile: profile,
                directory: directory,
                initialSessionId: initialSessionId,
              );
            },
      );
      addTearDown(restoredAppController.dispose);

      final restoredNavigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        _WorkspaceRouteHarness(
          controller: restoredAppController,
          navigatorKey: restoredNavigatorKey,
          initialRoute: '/',
        ),
      );
      restoredNavigatorKey.currentState!.pushNamed(
        buildWorkspaceRoute('/workspace/demo', sessionId: 'ses_1'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(
        tester.getSize(sidebarPane).width,
        closeTo(resizedSidebarWidth, 1),
      );
      expect(
        tester.getSize(sidePanel).width,
        closeTo(resizedSidePanelWidth, 1),
      );
    },
  );

  testWidgets(
    'desktop keyboard shortcuts toggle panels and focus the composer',
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
              return _RecordingWorkspaceController(
                profile: profile,
                directory: directory,
                initialSessionId: initialSessionId,
              );
            },
      );
      addTearDown(appController.dispose);

      final navigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        _WorkspaceRouteHarness(
          controller: appController,
          navigatorKey: navigatorKey,
          initialRoute: '/',
        ),
      );
      navigatorKey.currentState!.pushNamed(
        buildWorkspaceRoute('/workspace/demo', sessionId: 'ses_1'),
      );
      await tester.pumpAndSettle();

      final sidebarReveal = find.byKey(
        const ValueKey<String>('workspace-desktop-sidebar-reveal'),
      );
      final sidePanelReveal = find.byKey(
        const ValueKey<String>('workspace-desktop-side-panel-reveal'),
      );

      await _sendShortcut(tester, <LogicalKeyboardKey>[
        LogicalKeyboardKey.controlLeft,
        LogicalKeyboardKey.keyB,
      ]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 260));
      expect(tester.getSize(sidebarReveal).width, closeTo(0, 0.1));

      await _sendShortcut(tester, <LogicalKeyboardKey>[
        LogicalKeyboardKey.controlLeft,
        LogicalKeyboardKey.shiftLeft,
        LogicalKeyboardKey.keyR,
      ]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 260));
      expect(tester.getSize(sidePanelReveal).width, closeTo(0, 0.1));

      await _sendShortcut(tester, <LogicalKeyboardKey>[
        LogicalKeyboardKey.controlLeft,
        LogicalKeyboardKey.backslash,
      ]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 260));
      expect(tester.getSize(sidePanelReveal).width, greaterThan(300));

      await _sendShortcut(tester, <LogicalKeyboardKey>[
        LogicalKeyboardKey.controlLeft,
        LogicalKeyboardKey.keyL,
      ]);
      await tester.pump();

      final editable = tester.widget<EditableText>(find.byType(EditableText));
      expect(editable.focusNode.hasFocus, isTrue);
    },
  );

  testWidgets(
    'desktop composer submits on enter and keeps shift enter for new lines',
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
      late _SubmittingRecordingWorkspaceController controllerInstance;
      final appController = _StaticAppController(
        profile: profile,
        workspaceControllerFactory:
            ({required profile, required directory, initialSessionId}) {
              controllerInstance = _SubmittingRecordingWorkspaceController(
                profile: profile,
                directory: directory,
                initialSessionId: initialSessionId,
              );
              return controllerInstance;
            },
      );
      addTearDown(appController.dispose);

      final navigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        _WorkspaceRouteHarness(
          controller: appController,
          navigatorKey: navigatorKey,
          initialRoute: '/',
          platform: TargetPlatform.macOS,
        ),
      );
      navigatorKey.currentState!.pushNamed(
        buildWorkspaceRoute('/workspace/demo', sessionId: 'ses_1'),
      );
      await tester.pumpAndSettle();

      final textField = find.byKey(
        const ValueKey<String>('composer-text-field'),
      );
      await tester.tap(textField);
      await tester.pump();
      await tester.enterText(textField, 'first line');
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();

      expect(_composerText(tester), 'first line\n');
      expect(controllerInstance.submittedPrompts, isEmpty);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(controllerInstance.submittedPrompts, <String>['first line']);
      expect(_composerText(tester), isEmpty);
    },
  );

  testWidgets(
    'timeline shows thinking placeholder immediately after desktop prompt submit',
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
      late _ThinkingPlaceholderWorkspaceController controllerInstance;
      final appController = _StaticAppController(
        profile: profile,
        workspaceControllerFactory:
            ({required profile, required directory, initialSessionId}) {
              controllerInstance = _ThinkingPlaceholderWorkspaceController(
                profile: profile,
                directory: directory,
                initialSessionId: initialSessionId,
              );
              return controllerInstance;
            },
      );
      addTearDown(appController.dispose);

      final navigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        _WorkspaceRouteHarness(
          controller: appController,
          navigatorKey: navigatorKey,
          initialRoute: '/',
          platform: TargetPlatform.macOS,
        ),
      );
      navigatorKey.currentState!.pushNamed(
        buildWorkspaceRoute('/workspace/demo', sessionId: 'ses_1'),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('timeline-thinking-placeholder')),
        findsNothing,
      );

      final textField = find.byKey(
        const ValueKey<String>('composer-text-field'),
      );
      await tester.tap(textField);
      await tester.pump();
      await tester.enterText(textField, 'Tell me what is next');
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(controllerInstance.submittedPrompts, <String>[
        'Tell me what is next',
      ]);
      expect(
        find.byKey(const ValueKey<String>('timeline-thinking-placeholder')),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget.key is ValueKey<String> &&
              (widget.key! as ValueKey<String>).value.startsWith(
                'workspace-session-pane-busy-indicator-',
              ),
        ),
        findsOneWidget,
      );

      controllerInstance.beginAssistantResponse();
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('timeline-thinking-placeholder')),
        findsNothing,
      );
      expect(
        find.textContaining('Thinking through the task', findRichText: true),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'desktop composer recalls submitted prompt history per session and across launches',
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
      late _SubmittingRecordingWorkspaceController controllerInstance;
      final firstAppController = _StaticAppController(
        profile: profile,
        workspaceControllerFactory:
            ({required profile, required directory, initialSessionId}) {
              controllerInstance = _SubmittingRecordingWorkspaceController(
                profile: profile,
                directory: directory,
                initialSessionId: initialSessionId,
              );
              return controllerInstance;
            },
      );
      addTearDown(firstAppController.dispose);

      final firstNavigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        _WorkspaceRouteHarness(
          controller: firstAppController,
          navigatorKey: firstNavigatorKey,
          initialRoute: '/',
          platform: TargetPlatform.macOS,
        ),
      );
      firstNavigatorKey.currentState!.pushNamed(
        buildWorkspaceRoute('/workspace/demo', sessionId: 'ses_1'),
      );
      await tester.pumpAndSettle();

      final textField = find.byKey(
        const ValueKey<String>('composer-text-field'),
      );

      await tester.tap(textField);
      await tester.pump();
      await tester.enterText(textField, 'history one');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.text('Session Two'));
      await tester.pumpAndSettle();

      await tester.tap(textField);
      await tester.pump();
      await tester.enterText(textField, 'history two');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(controllerInstance.submittedPrompts, <String>[
        'history one',
        'history two',
      ]);

      await tester.tap(find.text('Session One'));
      await tester.pumpAndSettle();

      await tester.tap(textField);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(_composerText(tester), 'history one');

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(_composerText(tester), isEmpty);

      await tester.tap(find.text('Session Two'));
      await tester.pumpAndSettle();

      await tester.tap(textField);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(_composerText(tester), 'history two');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 300));

      final restoredAppController = _StaticAppController(
        profile: profile,
        workspaceControllerFactory:
            ({required profile, required directory, initialSessionId}) {
              return _SubmittingRecordingWorkspaceController(
                profile: profile,
                directory: directory,
                initialSessionId: initialSessionId,
              );
            },
      );
      addTearDown(restoredAppController.dispose);

      final restoredNavigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        _WorkspaceRouteHarness(
          controller: restoredAppController,
          navigatorKey: restoredNavigatorKey,
          initialRoute: '/',
          platform: TargetPlatform.macOS,
        ),
      );
      restoredNavigatorKey.currentState!.pushNamed(
        buildWorkspaceRoute('/workspace/demo', sessionId: 'ses_1'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      await tester.tap(textField);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(_composerText(tester), 'history one');

      await tester.tap(find.text('Session Two'));
      await tester.pumpAndSettle();

      await tester.tap(textField);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(_composerText(tester), 'history two');
    },
  );

  testWidgets('keyboard shortcut opens workspace settings', (tester) async {
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
            return _RecordingWorkspaceController(
              profile: profile,
              directory: directory,
              initialSessionId: initialSessionId,
            );
          },
    );
    addTearDown(appController.dispose);

    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      _WorkspaceRouteHarness(
        controller: appController,
        navigatorKey: navigatorKey,
        initialRoute: '/',
      ),
    );
    navigatorKey.currentState!.pushNamed(
      buildWorkspaceRoute('/workspace/demo', sessionId: 'ses_1'),
    );
    await tester.pumpAndSettle();

    await _sendShortcut(tester, <LogicalKeyboardKey>[
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.comma,
    ]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 260));

    expect(
      find.byKey(const ValueKey<String>('workspace-settings-sheet')),
      findsOneWidget,
    );
    final settingsListView = find.descendant(
      of: find.byKey(const ValueKey<String>('workspace-settings-sheet')),
      matching: find.byType(ListView),
    );
    await tester.dragUntilVisible(
      find.byKey(const ValueKey<String>('workspace-settings-shortcuts-card')),
      settingsListView,
      const Offset(0, -180),
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey<String>('workspace-settings-shortcuts-card')),
      findsOneWidget,
    );
    expect(find.text('OpenCode-style desktop shortcuts'), findsOneWidget);
  });

  testWidgets(
    'command palette opens from the keyboard shortcut and runs commands',
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
              return _RecordingWorkspaceController(
                profile: profile,
                directory: directory,
                initialSessionId: initialSessionId,
              );
            },
      );
      addTearDown(appController.dispose);

      final navigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        _WorkspaceRouteHarness(
          controller: appController,
          navigatorKey: navigatorKey,
          initialRoute: '/',
        ),
      );
      navigatorKey.currentState!.pushNamed(
        buildWorkspaceRoute('/workspace/demo', sessionId: 'ses_1'),
      );
      await tester.pumpAndSettle();

      await _sendShortcut(tester, <LogicalKeyboardKey>[
        LogicalKeyboardKey.controlLeft,
        LogicalKeyboardKey.keyK,
      ]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 220));

      expect(
        find.byKey(const ValueKey<String>('workspace-command-palette-sheet')),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const ValueKey<String>('workspace-command-palette-field')),
        'settings',
      );
      await tester.pump();

      await tester.tap(
        find.byKey(
          const ValueKey<String>(
            'workspace-command-palette-option-settings.open',
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 260));

      expect(
        find.byKey(const ValueKey<String>('workspace-command-palette-sheet')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('workspace-settings-sheet')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'command palette button exposes dynamic theme and session commands',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final createdControllers = <_RecordingWorkspaceController>[];
      final profile = ServerProfile(
        id: 'server',
        label: 'Mock',
        baseUrl: 'http://localhost:3000',
      );
      final appController = _StaticAppController(
        profile: profile,
        workspaceControllerFactory:
            ({required profile, required directory, initialSessionId}) {
              final controller = _RecordingWorkspaceController(
                profile: profile,
                directory: directory,
                initialSessionId: initialSessionId,
              );
              createdControllers.add(controller);
              return controller;
            },
      );
      addTearDown(appController.dispose);

      final navigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        _WorkspaceRouteHarness(
          controller: appController,
          navigatorKey: navigatorKey,
          initialRoute: '/',
        ),
      );
      navigatorKey.currentState!.pushNamed(
        buildWorkspaceRoute('/workspace/demo', sessionId: 'ses_1'),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('workspace-command-palette-button')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 220));

      await tester.enterText(
        find.byKey(const ValueKey<String>('workspace-command-palette-field')),
        'github',
      );
      await tester.pump();

      await tester.tap(
        find.byKey(
          const ValueKey<String>(
            'workspace-command-palette-option-theme.set.github',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(appController.themePreset, AppThemePreset.github);

      await tester.tap(
        find.byKey(const ValueKey<String>('workspace-command-palette-button')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 220));

      await tester.enterText(
        find.byKey(const ValueKey<String>('workspace-command-palette-field')),
        'session two',
      );
      await tester.pump();

      await tester.tap(
        find.byKey(
          const ValueKey<String>(
            'workspace-command-palette-option-session.open.ses_2',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(createdControllers.single.selectedSessionId, 'ses_2');
      expect(find.text('hello from two'), findsOneWidget);
    },
  );

  testWidgets('keyboard shortcut opens the project picker sheet', (
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
            return _RecordingWorkspaceController(
              profile: profile,
              directory: directory,
              initialSessionId: initialSessionId,
            );
          },
    );
    addTearDown(appController.dispose);

    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      _WorkspaceRouteHarness(
        controller: appController,
        navigatorKey: navigatorKey,
        initialRoute: '/',
        projectCatalogService: _ShortcutProjectCatalogService(),
      ),
    );
    navigatorKey.currentState!.pushNamed(
      buildWorkspaceRoute('/workspace/demo', sessionId: 'ses_1'),
    );
    await tester.pumpAndSettle();

    await _sendShortcut(tester, <LogicalKeyboardKey>[
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.keyO,
    ]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 320));

    expect(find.text('Open Project'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('project-picker-manual-path-field')),
      findsOneWidget,
    );
  });

  testWidgets('keyboard shortcut navigates to the next session in place', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final createdControllers = <_RecordingWorkspaceController>[];
    final profile = ServerProfile(
      id: 'server',
      label: 'Mock',
      baseUrl: 'http://localhost:3000',
    );
    final appController = _StaticAppController(
      profile: profile,
      workspaceControllerFactory:
          ({required profile, required directory, initialSessionId}) {
            final controller = _RecordingWorkspaceController(
              profile: profile,
              directory: directory,
              initialSessionId: initialSessionId,
            );
            createdControllers.add(controller);
            return controller;
          },
    );
    addTearDown(appController.dispose);

    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      _WorkspaceRouteHarness(
        controller: appController,
        navigatorKey: navigatorKey,
        initialRoute: '/',
      ),
    );
    navigatorKey.currentState!.pushNamed(
      buildWorkspaceRoute('/workspace/demo', sessionId: 'ses_1'),
    );
    await tester.pumpAndSettle();

    expect(createdControllers.single.selectedSessionId, 'ses_1');
    expect(find.text('hello from one'), findsOneWidget);

    await _sendShortcut(tester, <LogicalKeyboardKey>[
      LogicalKeyboardKey.altLeft,
      LogicalKeyboardKey.arrowDown,
    ]);
    await tester.pumpAndSettle();

    expect(createdControllers.single.selectedSessionId, 'ses_2');
    expect(find.text('hello from two'), findsOneWidget);
  });

  testWidgets('keyboard shortcut triggers attachment picking', (tester) async {
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
            return _RecordingWorkspaceController(
              profile: profile,
              directory: directory,
              initialSessionId: initialSessionId,
            );
          },
    );
    addTearDown(appController.dispose);

    final navigatorKey = GlobalKey<NavigatorState>();
    var pickerCalls = 0;

    await tester.pumpWidget(
      _WorkspaceRouteHarness(
        controller: appController,
        navigatorKey: navigatorKey,
        initialRoute: '/',
        attachmentPicker: () async {
          pickerCalls += 1;
          return const <PromptAttachment>[];
        },
      ),
    );
    navigatorKey.currentState!.pushNamed(
      buildWorkspaceRoute('/workspace/demo', sessionId: 'ses_1'),
    );
    await tester.pumpAndSettle();

    await _sendShortcut(tester, <LogicalKeyboardKey>[
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.keyU,
    ]);
    await tester.pumpAndSettle();

    expect(pickerCalls, 1);
  });

  testWidgets(
    'desktop layout can split session panes and keep non-active sessions visible',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final createdControllers = <_RecordingWorkspaceController>[];
      final profile = ServerProfile(
        id: 'server',
        label: 'Mock',
        baseUrl: 'http://localhost:3000',
      );
      final appController = _StaticAppController(
        profile: profile,
        workspaceControllerFactory:
            ({required profile, required directory, initialSessionId}) {
              final controller = _RecordingWorkspaceController(
                profile: profile,
                directory: directory,
                initialSessionId: initialSessionId,
              );
              createdControllers.add(controller);
              return controller;
            },
      );
      addTearDown(appController.dispose);

      final navigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        _WorkspaceRouteHarness(
          controller: appController,
          navigatorKey: navigatorKey,
          initialRoute: '/',
        ),
      );
      navigatorKey.currentState!.pushNamed(
        buildWorkspaceRoute('/workspace/demo', sessionId: 'ses_1'),
      );
      await tester.pumpAndSettle();

      final controller = createdControllers.single;
      expect(find.text('hello from one'), findsOneWidget);

      await tester.tap(
        find.byKey(
          const ValueKey<String>('workspace-split-session-pane-button'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('hello from one'), findsNWidgets(2));
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is InkWell &&
              widget.key is ValueKey<String> &&
              (widget.key! as ValueKey<String>).value.startsWith(
                'workspace-session-pane-',
              ),
        ),
        findsNWidgets(2),
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget.key is ValueKey<String> &&
              (widget.key! as ValueKey<String>).value.startsWith(
                'workspace-session-pane-selected-badge-',
              ),
        ),
        findsOneWidget,
      );
      expect(controller.selectedSessionId, 'ses_1');

      await tester.tap(find.text('Session Two'));
      await tester.pumpAndSettle();

      expect(controller.selectedSessionId, 'ses_2');
      expect(find.text('hello from one'), findsOneWidget);
      expect(find.text('hello from two'), findsOneWidget);

      await tester.tap(find.text('hello from one'));
      await tester.pumpAndSettle();

      expect(controller.selectedSessionId, 'ses_1');
      expect(find.text('hello from one'), findsOneWidget);
      expect(find.text('hello from two'), findsOneWidget);

      await tester.tap(find.byTooltip('Close pane').first);
      await tester.pumpAndSettle();

      expect(controller.selectedSessionId, 'ses_2');
      expect(find.text('hello from one'), findsNothing);
      expect(find.text('hello from two'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is InkWell &&
              widget.key is ValueKey<String> &&
              (widget.key! as ValueKey<String>).value.startsWith(
                'workspace-session-pane-',
              ),
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget.key is ValueKey<String> &&
              (widget.key! as ValueKey<String>).value.startsWith(
                'workspace-session-pane-selected-badge-',
              ),
        ),
        findsNothing,
      );

      final paneContainer = find.byWidgetPredicate(
        (widget) =>
            widget is AnimatedContainer &&
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              'workspace-session-pane-container-',
            ),
      );
      final decoration =
          tester.widget<AnimatedContainer>(paneContainer).decoration
              as BoxDecoration;
      final border = decoration.border! as Border;
      expect(border.top.width, 1);
    },
  );

  testWidgets(
    'session pane activity indicator only shows for responding sessions',
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
              return _BusyPaneIndicatorWorkspaceController(
                profile: profile,
                directory: directory,
                initialSessionId: initialSessionId,
              );
            },
      );
      addTearDown(appController.dispose);

      final navigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        _WorkspaceRouteHarness(
          controller: appController,
          navigatorKey: navigatorKey,
          initialRoute: '/',
        ),
      );
      navigatorKey.currentState!.pushNamed(
        buildWorkspaceRoute('/workspace/demo', sessionId: 'ses_1'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      await tester.tap(
        find.byKey(
          const ValueKey<String>('workspace-split-session-pane-button'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      await tester.tap(find.text('Session Two'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final paneFinder = find.byWidgetPredicate(
        (widget) =>
            widget is InkWell &&
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              'workspace-session-pane-',
            ),
      );
      final busyIndicatorFinder = find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              'workspace-session-pane-busy-indicator-',
            ),
      );
      final sessionOnePane = find.ancestor(
        of: find.text('Session One'),
        matching: paneFinder,
      );
      final sessionTwoPane = find.ancestor(
        of: find.text('Session Two'),
        matching: paneFinder,
      );

      expect(
        find.descendant(of: sessionOnePane, matching: busyIndicatorFinder),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sessionTwoPane, matching: busyIndicatorFinder),
        findsNothing,
      );
    },
  );

  testWidgets('desktop layout allows up to eight split session panes', (
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
            return _RecordingWorkspaceController(
              profile: profile,
              directory: directory,
              initialSessionId: initialSessionId,
            );
          },
    );
    addTearDown(appController.dispose);

    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      _WorkspaceRouteHarness(
        controller: appController,
        navigatorKey: navigatorKey,
        initialRoute: '/',
      ),
    );
    navigatorKey.currentState!.pushNamed(
      buildWorkspaceRoute('/workspace/demo', sessionId: 'ses_1'),
    );
    await tester.pumpAndSettle();

    final splitButton = find.byKey(
      const ValueKey<String>('workspace-split-session-pane-button'),
    );
    final paneCards = find.byWidgetPredicate(
      (widget) =>
          widget is InkWell &&
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith(
            'workspace-session-pane-',
          ),
    );

    for (var index = 0; index < 7; index += 1) {
      await tester.tap(splitButton);
      await tester.pumpAndSettle();
    }

    expect(paneCards, findsNWidgets(8));
    expect(find.text('Split (8)'), findsOneWidget);

    await tester.tap(splitButton);
    await tester.pumpAndSettle();

    expect(paneCards, findsNWidgets(8));
  });

  testWidgets('composer draft follows the active pane session and project', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final createdControllers = <_RecordingWorkspaceController>[];
    final profile = ServerProfile(
      id: 'server',
      label: 'Mock',
      baseUrl: 'http://localhost:3000',
    );
    final appController = _StaticAppController(
      profile: profile,
      workspaceControllerFactory:
          ({required profile, required directory, initialSessionId}) {
            final controller = _RecordingWorkspaceController(
              profile: profile,
              directory: directory,
              initialSessionId: initialSessionId,
            );
            createdControllers.add(controller);
            return controller;
          },
    );
    addTearDown(appController.dispose);

    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      _WorkspaceRouteHarness(
        controller: appController,
        navigatorKey: navigatorKey,
        initialRoute: '/',
      ),
    );
    navigatorKey.currentState!.pushNamed(
      buildWorkspaceRoute('/workspace/demo', sessionId: 'ses_1'),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('workspace-split-session-pane-button')),
    );
    await tester.pumpAndSettle();

    final composerFinder = find.byKey(
      const ValueKey<String>('composer-text-field'),
    );

    await tester.tap(find.text('Session Two'));
    await tester.pumpAndSettle();
    await tester.enterText(composerFinder, 'draft for two');
    await tester.pump();

    await tester.tap(find.text('hello from one'));
    await tester.pumpAndSettle();
    expect(_composerText(tester), isEmpty);

    await tester.enterText(composerFinder, 'draft for one');
    await tester.pump();

    await tester.tap(find.text('hello from two'));
    await tester.pumpAndSettle();
    expect(_composerText(tester), 'draft for two');

    await tester.tap(
      find.byKey(const ValueKey<String>('workspace-project-/workspace/lab')),
    );
    await tester.pumpAndSettle();

    expect(createdControllers, hasLength(2));
    expect(_composerText(tester), isEmpty);

    await tester.enterText(composerFinder, 'draft for lab');
    await tester.pump();

    await tester.tap(find.text('hello from one'));
    await tester.pumpAndSettle();
    expect(_composerText(tester), 'draft for one');

    await tester.tap(find.text('hello from lab'));
    await tester.pumpAndSettle();
    expect(_composerText(tester), 'draft for lab');
  });

  testWidgets(
    'per-pane composer mode renders a composer inside each split pane',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final createdControllers = <_RecordingWorkspaceController>[];
      final profile = ServerProfile(
        id: 'server',
        label: 'Mock',
        baseUrl: 'http://localhost:3000',
      );
      final appController = _StaticAppController(
        profile: profile,
        workspaceControllerFactory:
            ({required profile, required directory, initialSessionId}) {
              final controller = _RecordingWorkspaceController(
                profile: profile,
                directory: directory,
                initialSessionId: initialSessionId,
              );
              createdControllers.add(controller);
              return controller;
            },
      );
      addTearDown(appController.dispose);

      await appController.setMultiPaneComposerMode(
        WorkspaceMultiPaneComposerMode.perPane,
      );

      final navigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        _WorkspaceRouteHarness(
          controller: appController,
          navigatorKey: navigatorKey,
          initialRoute: '/',
        ),
      );
      navigatorKey.currentState!.pushNamed(
        buildWorkspaceRoute('/workspace/demo', sessionId: 'ses_1'),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(
          const ValueKey<String>('workspace-split-session-pane-button'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Session Two'));
      await tester.pumpAndSettle();

      final paneComposerFields = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              'composer-text-field-pane_',
            ),
      );

      expect(
        find.byKey(const ValueKey<String>('composer-text-field')),
        findsNothing,
      );
      expect(paneComposerFields, findsNWidgets(2));

      await tester.enterText(paneComposerFields.at(0), 'draft one');
      await tester.pump();
      await tester.enterText(paneComposerFields.at(1), 'draft two');
      await tester.pump();

      TextField composerField(int index) =>
          tester.widget<TextField>(paneComposerFields.at(index));

      expect(composerField(0).controller!.text, 'draft one');
      expect(composerField(1).controller!.text, 'draft two');

      await tester.tap(find.text('hello from one'));
      await tester.pumpAndSettle();

      expect(createdControllers.single.selectedSessionId, 'ses_1');
      expect(composerField(0).controller!.text, 'draft one');
      expect(composerField(1).controller!.text, 'draft two');
    },
  );

  testWidgets('composer drafts restore per session across app launches', (
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

    final firstAppController = _StaticAppController(
      profile: profile,
      workspaceControllerFactory:
          ({required profile, required directory, initialSessionId}) {
            return _RecordingWorkspaceController(
              profile: profile,
              directory: directory,
              initialSessionId: initialSessionId,
            );
          },
    );
    addTearDown(firstAppController.dispose);

    final firstNavigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      _WorkspaceRouteHarness(
        controller: firstAppController,
        navigatorKey: firstNavigatorKey,
        initialRoute: '/',
      ),
    );
    firstNavigatorKey.currentState!.pushNamed(
      buildWorkspaceRoute('/workspace/demo', sessionId: 'ses_1'),
    );
    await tester.pumpAndSettle();

    final composerFinder = find.byKey(
      const ValueKey<String>('composer-text-field'),
    );

    await tester.enterText(composerFinder, 'persisted draft for one');
    await tester.pump();

    await tester.tap(find.text('Session Two'));
    await tester.pumpAndSettle();

    await tester.enterText(composerFinder, 'persisted draft for two');
    await tester.pump();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 300));

    final restoredAppController = _StaticAppController(
      profile: profile,
      workspaceControllerFactory:
          ({required profile, required directory, initialSessionId}) {
            return _RecordingWorkspaceController(
              profile: profile,
              directory: directory,
              initialSessionId: initialSessionId,
            );
          },
    );
    addTearDown(restoredAppController.dispose);

    final restoredNavigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      _WorkspaceRouteHarness(
        controller: restoredAppController,
        navigatorKey: restoredNavigatorKey,
        initialRoute: '/',
      ),
    );
    restoredNavigatorKey.currentState!.pushNamed(
      buildWorkspaceRoute('/workspace/demo', sessionId: 'ses_1'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(_composerText(tester), 'persisted draft for one');

    await tester.tap(find.text('Session Two'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(_composerText(tester), 'persisted draft for two');
  });

  testWidgets(
    'split panes keep each session todo and sub-agent panels visible without focus',
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
              return _PaneMetadataWorkspaceController(
                profile: profile,
                directory: directory,
                initialSessionId: initialSessionId,
              );
            },
      );
      addTearDown(appController.dispose);

      final navigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        _WorkspaceRouteHarness(
          controller: appController,
          navigatorKey: navigatorKey,
          initialRoute: '/',
        ),
      );
      navigatorKey.currentState!.pushNamed(
        buildWorkspaceRoute('/workspace/demo', sessionId: 'ses_1'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(
        find.byKey(
          const ValueKey<String>('workspace-split-session-pane-button'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('Session Two'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.text('Plan anomaly feature (@plan subagent)'),
        findsOneWidget,
      );
      expect(
        find.text('Find validation hook (@explore subagent)'),
        findsOneWidget,
      );
      expect(find.text('todo for one'), findsOneWidget);
      expect(find.text('todo for two'), findsOneWidget);
    },
  );

  testWidgets(
    'split panes keep each session question panel visible without focus',
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
              return _PaneQuestionWorkspaceController(
                profile: profile,
                directory: directory,
                initialSessionId: initialSessionId,
              );
            },
      );
      addTearDown(appController.dispose);

      final navigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        _WorkspaceRouteHarness(
          controller: appController,
          navigatorKey: navigatorKey,
          initialRoute: '/',
        ),
      );
      navigatorKey.currentState!.pushNamed(
        buildWorkspaceRoute('/workspace/demo', sessionId: 'ses_1'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(
        find.byKey(
          const ValueKey<String>('workspace-split-session-pane-button'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('Session Two'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.text('Which deployment target should I use?'),
        findsOneWidget,
      );
      expect(
        find.text('What should I do with this flaky test?'),
        findsOneWidget,
      );
      expect(
        find.text('Question pending in the active session'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('composer-text-field')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'split panes keep each session permission panel visible without focus',
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
              return _PanePermissionWorkspaceController(
                profile: profile,
                directory: directory,
                initialSessionId: initialSessionId,
              );
            },
      );
      addTearDown(appController.dispose);

      final navigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        _WorkspaceRouteHarness(
          controller: appController,
          navigatorKey: navigatorKey,
          initialRoute: '/',
        ),
      );
      navigatorKey.currentState!.pushNamed(
        buildWorkspaceRoute('/workspace/demo', sessionId: 'ses_1'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(
        find.byKey(
          const ValueKey<String>('workspace-split-session-pane-button'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('Session Two'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('bash'), findsOneWidget);
      expect(find.text('edit'), findsOneWidget);
      expect(find.text('npm test'), findsOneWidget);
      expect(find.text('lib/**'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('composer-text-field')),
        findsNothing,
      );
    },
  );

  testWidgets('desktop split panes restore across app launches', (
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

    final firstAppController = _StaticAppController(
      profile: profile,
      workspaceControllerFactory:
          ({required profile, required directory, initialSessionId}) {
            return _RecordingWorkspaceController(
              profile: profile,
              directory: directory,
              initialSessionId: initialSessionId,
            );
          },
    );
    addTearDown(firstAppController.dispose);

    final firstNavigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      _WorkspaceRouteHarness(
        controller: firstAppController,
        navigatorKey: firstNavigatorKey,
        initialRoute: '/',
      ),
    );
    firstNavigatorKey.currentState!.pushNamed(
      buildWorkspaceRoute('/workspace/demo', sessionId: 'ses_1'),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('workspace-split-session-pane-button')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Session Two'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('workspace-project-/workspace/lab')),
    );
    await tester.pumpAndSettle();

    expect(find.text('hello from one'), findsOneWidget);
    expect(find.text('hello from lab'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    final restoredAppController = _StaticAppController(
      profile: profile,
      workspaceControllerFactory:
          ({required profile, required directory, initialSessionId}) {
            return _RecordingWorkspaceController(
              profile: profile,
              directory: directory,
              initialSessionId: initialSessionId,
            );
          },
    );
    addTearDown(restoredAppController.dispose);

    final restoredNavigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      _WorkspaceRouteHarness(
        controller: restoredAppController,
        navigatorKey: restoredNavigatorKey,
        initialRoute: '/',
      ),
    );
    restoredNavigatorKey.currentState!.pushNamed(
      buildWorkspaceRoute('/workspace/lab', sessionId: 'ses_lab_1'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(find.text('hello from one'), findsOneWidget);
    expect(find.text('hello from lab'), findsOneWidget);
  });

  testWidgets(
    'completed todo dock stays hidden after unchanged workspace updates',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      late _CompletedTodoWorkspaceController controller;
      final profile = ServerProfile(
        id: 'server',
        label: 'Mock',
        baseUrl: 'http://localhost:3000',
      );
      final appController = _StaticAppController(
        profile: profile,
        workspaceControllerFactory:
            ({required profile, required directory, initialSessionId}) {
              controller = _CompletedTodoWorkspaceController(
                profile: profile,
                directory: directory,
                initialSessionId: initialSessionId,
              );
              return controller;
            },
      );
      addTearDown(appController.dispose);

      final navigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        _WorkspaceRouteHarness(
          controller: appController,
          navigatorKey: navigatorKey,
          initialRoute: '/',
        ),
      );
      navigatorKey.currentState!.pushNamed(
        buildWorkspaceRoute('/workspace/demo', sessionId: 'ses_1'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('completed todo alpha'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('completed todo alpha'), findsNothing);

      controller.emitUnchangedUpdate();
      await tester.pump();
      expect(find.text('completed todo alpha'), findsNothing);

      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('completed todo alpha'), findsNothing);
    },
  );

  testWidgets(
    'switching projects stays on the same page and reuses cached workspace controllers',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final createdControllers = <_RecordingWorkspaceController>[];
      final profile = ServerProfile(
        id: 'server',
        label: 'Mock',
        baseUrl: 'http://localhost:3000',
      );
      final appController = _StaticAppController(
        profile: profile,
        workspaceControllerFactory:
            ({required profile, required directory, initialSessionId}) {
              final controller = _RecordingWorkspaceController(
                profile: profile,
                directory: directory,
                initialSessionId: initialSessionId,
              );
              createdControllers.add(controller);
              return controller;
            },
      );
      addTearDown(appController.dispose);

      final navigatorKey = GlobalKey<NavigatorState>();
      final observer = _RecordingNavigatorObserver();

      await tester.pumpWidget(
        _WorkspaceRouteHarness(
          controller: appController,
          navigatorKey: navigatorKey,
          navigatorObservers: <NavigatorObserver>[observer],
          initialRoute: '/',
        ),
      );
      navigatorKey.currentState!.pushNamed(
        buildWorkspaceRoute('/workspace/demo', sessionId: 'ses_1'),
      );
      await tester.pumpAndSettle();

      expect(createdControllers, hasLength(1));
      expect(createdControllers.single.loadCount, 1);
      expect(find.text('hello from one'), findsOneWidget);
      final initialRouteName = observer.lastRouteName;

      await tester.tap(
        find.byKey(const ValueKey<String>('workspace-project-/workspace/lab')),
      );
      await tester.pumpAndSettle();

      expect(createdControllers, hasLength(2));
      expect(createdControllers.first.loadCount, 1);
      expect(createdControllers.last.directory, '/workspace/lab');
      expect(createdControllers.last.loadCount, 1);
      expect(find.byType(WebParityWorkspaceScreen), findsOneWidget);
      expect(observer.lastRouteName, initialRouteName);
      expect(find.text('hello from lab'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('workspace-project-/workspace/demo')),
      );
      await tester.pumpAndSettle();

      expect(createdControllers, hasLength(2));
      expect(createdControllers.first.loadCount, 1);
      expect(createdControllers.last.loadCount, 1);
      expect(find.byType(WebParityWorkspaceScreen), findsOneWidget);
      expect(observer.lastRouteName, initialRouteName);
      expect(find.text('hello from one'), findsOneWidget);
    },
  );

  testWidgets(
    'switching to an uncached project keeps the shell mounted and loads project data in place',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final createdControllers = <_RecordingWorkspaceController>[];
      final labLoadCompleter = Completer<void>();
      final profile = ServerProfile(
        id: 'server',
        label: 'Mock',
        baseUrl: 'http://localhost:3000',
      );
      final appController = _StaticAppController(
        profile: profile,
        workspaceControllerFactory:
            ({required profile, required directory, initialSessionId}) {
              final controller = directory == '/workspace/lab'
                  ? _DelayedRecordingWorkspaceController(
                      profile: profile,
                      directory: directory,
                      initialSessionId: initialSessionId,
                      loadCompleter: labLoadCompleter,
                    )
                  : _RecordingWorkspaceController(
                      profile: profile,
                      directory: directory,
                      initialSessionId: initialSessionId,
                    );
              createdControllers.add(controller);
              return controller;
            },
      );
      addTearDown(appController.dispose);

      final navigatorKey = GlobalKey<NavigatorState>();
      final observer = _RecordingNavigatorObserver();

      await tester.pumpWidget(
        _WorkspaceRouteHarness(
          controller: appController,
          navigatorKey: navigatorKey,
          navigatorObservers: <NavigatorObserver>[observer],
          initialRoute: '/',
        ),
      );
      navigatorKey.currentState!.pushNamed(
        buildWorkspaceRoute('/workspace/demo', sessionId: 'ses_1'),
      );
      await tester.pumpAndSettle();

      final initialRouteName = observer.lastRouteName;
      expect(find.text('hello from one'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('workspace-project-/workspace/lab')),
      );
      await tester.pump();

      expect(createdControllers, hasLength(2));
      expect(observer.lastRouteName, initialRouteName);
      expect(find.byType(WebParityWorkspaceScreen), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey<String>('workspace-project-loading-/workspace/lab'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('workspace-sidebar-session-loading-state'),
        ),
        findsOneWidget,
      );
      expect(find.text('Lab'), findsAtLeastNWidgets(1));
      expect(find.text('hello from one'), findsNothing);

      labLoadCompleter.complete();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(observer.lastRouteName, initialRouteName);
      expect(find.text('hello from lab'), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey<String>('workspace-project-loading-/workspace/lab'),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'desktop layout keeps existing pane state when switching the active pane to another project',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final createdControllers = <_RecordingWorkspaceController>[];
      final profile = ServerProfile(
        id: 'server',
        label: 'Mock',
        baseUrl: 'http://localhost:3000',
      );
      final appController = _StaticAppController(
        profile: profile,
        workspaceControllerFactory:
            ({required profile, required directory, initialSessionId}) {
              final controller = _RecordingWorkspaceController(
                profile: profile,
                directory: directory,
                initialSessionId: initialSessionId,
              );
              createdControllers.add(controller);
              return controller;
            },
      );
      addTearDown(appController.dispose);

      final navigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        _WorkspaceRouteHarness(
          controller: appController,
          navigatorKey: navigatorKey,
          initialRoute: '/',
        ),
      );
      navigatorKey.currentState!.pushNamed(
        buildWorkspaceRoute('/workspace/demo', sessionId: 'ses_1'),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(
          const ValueKey<String>('workspace-split-session-pane-button'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Session Two'));
      await tester.pumpAndSettle();

      expect(find.text('hello from one'), findsOneWidget);
      expect(find.text('hello from two'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('workspace-project-/workspace/lab')),
      );
      await tester.pumpAndSettle();

      expect(createdControllers, hasLength(2));
      expect(find.text('hello from one'), findsOneWidget);
      expect(find.text('hello from lab'), findsOneWidget);
      expect(find.text('hello from two'), findsNothing);

      await tester.tap(find.text('hello from one'));
      await tester.pumpAndSettle();

      expect(createdControllers.first.selectedSessionId, 'ses_1');
      expect(find.text('hello from one'), findsOneWidget);
      expect(find.text('hello from lab'), findsOneWidget);
    },
  );

  testWidgets(
    'switching to an uncached project with split panes keeps other panes visible while the new project loads',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final createdControllers = <_RecordingWorkspaceController>[];
      final labLoadCompleter = Completer<void>();
      final profile = ServerProfile(
        id: 'server',
        label: 'Mock',
        baseUrl: 'http://localhost:3000',
      );
      final appController = _StaticAppController(
        profile: profile,
        workspaceControllerFactory:
            ({required profile, required directory, initialSessionId}) {
              final controller = directory == '/workspace/lab'
                  ? _DelayedRecordingWorkspaceController(
                      profile: profile,
                      directory: directory,
                      initialSessionId: initialSessionId,
                      loadCompleter: labLoadCompleter,
                    )
                  : _RecordingWorkspaceController(
                      profile: profile,
                      directory: directory,
                      initialSessionId: initialSessionId,
                    );
              createdControllers.add(controller);
              return controller;
            },
      );
      addTearDown(appController.dispose);

      final navigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        _WorkspaceRouteHarness(
          controller: appController,
          navigatorKey: navigatorKey,
          initialRoute: '/',
        ),
      );
      navigatorKey.currentState!.pushNamed(
        buildWorkspaceRoute('/workspace/demo', sessionId: 'ses_1'),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(
          const ValueKey<String>('workspace-split-session-pane-button'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Session Two'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('workspace-project-/workspace/lab')),
      );
      await tester.pump();

      expect(createdControllers, hasLength(2));
      expect(find.text('hello from one'), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey<String>('workspace-project-loading-/workspace/lab'),
        ),
        findsNothing,
      );
      expect(_paneLoadingFinder(), findsOneWidget);

      labLoadCompleter.complete();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('hello from one'), findsOneWidget);
      expect(find.text('hello from lab'), findsOneWidget);
      expect(_paneLoadingFinder(), findsNothing);
    },
  );

  testWidgets(
    'timeline stays pinned to bottom when streamed content extends the last message',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final createdControllers = <_StreamingWorkspaceController>[];
      final profile = ServerProfile(
        id: 'server',
        label: 'Mock',
        baseUrl: 'http://localhost:3000',
      );
      final appController = _StaticAppController(
        profile: profile,
        workspaceControllerFactory:
            ({required profile, required directory, initialSessionId}) {
              final controller = _StreamingWorkspaceController(
                profile: profile,
                directory: directory,
                initialSessionId: initialSessionId,
              );
              createdControllers.add(controller);
              return controller;
            },
      );
      addTearDown(appController.dispose);

      final navigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        _WorkspaceRouteHarness(
          controller: appController,
          navigatorKey: navigatorKey,
          initialRoute: '/',
        ),
      );
      navigatorKey.currentState!.pushNamed(
        buildWorkspaceRoute('/workspace/demo', sessionId: 'ses_1'),
      );
      await tester.pumpAndSettle();

      final controller = createdControllers.single;
      final listFinder = _messageTimelineListFinder();
      final initialPosition = tester
          .widget<ListView>(listFinder)
          .controller!
          .position;
      final initialMaxExtent = initialPosition.maxScrollExtent;

      expect(initialMaxExtent, greaterThan(0));
      expect(initialPosition.pixels, closeTo(initialMaxExtent, 96));

      controller.extendLastAssistantMessage(
        '\n${List<String>.filled(120, 'streamed output line').join('\n')}',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      final updatedPosition = tester
          .widget<ListView>(listFinder)
          .controller!
          .position;
      expect(updatedPosition.maxScrollExtent, greaterThan(initialMaxExtent));
      expect(
        updatedPosition.pixels,
        closeTo(updatedPosition.maxScrollExtent, 96),
      );
    },
  );

  testWidgets(
    'timeline lands at the bottom when opening a long existing session',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final createdControllers = <_LongSessionWorkspaceController>[];
      final profile = ServerProfile(
        id: 'server',
        label: 'Mock',
        baseUrl: 'http://localhost:3000',
      );
      final appController = _StaticAppController(
        profile: profile,
        workspaceControllerFactory:
            ({required profile, required directory, initialSessionId}) {
              final controller = _LongSessionWorkspaceController(
                profile: profile,
                directory: directory,
                initialSessionId: initialSessionId,
              );
              createdControllers.add(controller);
              return controller;
            },
      );
      addTearDown(appController.dispose);

      final navigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        _WorkspaceRouteHarness(
          controller: appController,
          navigatorKey: navigatorKey,
          initialRoute: '/',
        ),
      );
      navigatorKey.currentState!.pushNamed(
        buildWorkspaceRoute('/workspace/demo', sessionId: 'ses_long'),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pumpAndSettle();

      final controller = createdControllers.single;
      expect(controller.selectedSessionId, 'ses_long');

      final listFinder = _messageTimelineListFinder();
      final position = tester.widget<ListView>(listFinder).controller!.position;

      expect(position.maxScrollExtent, greaterThan(0));
      expect(position.pixels, closeTo(position.maxScrollExtent, 96));
    },
  );

  testWidgets(
    'scrolling to the top loads older timeline messages without resetting the viewport',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final createdControllers = <_LongSessionWorkspaceController>[];
      final profile = ServerProfile(
        id: 'server',
        label: 'Mock',
        baseUrl: 'http://localhost:3000',
      );
      final appController = _StaticAppController(
        profile: profile,
        workspaceControllerFactory:
            ({required profile, required directory, initialSessionId}) {
              final controller = _LongSessionWorkspaceController(
                profile: profile,
                directory: directory,
                initialSessionId: initialSessionId,
              );
              createdControllers.add(controller);
              return controller;
            },
      );
      addTearDown(appController.dispose);

      final navigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        _WorkspaceRouteHarness(
          controller: appController,
          navigatorKey: navigatorKey,
          initialRoute: '/',
        ),
      );
      navigatorKey.currentState!.pushNamed(
        buildWorkspaceRoute('/workspace/demo', sessionId: 'ses_long'),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      expect(find.text('user long session message 0'), findsNothing);
      expect(
        find.textContaining('assistant long session message 119'),
        findsOneWidget,
      );

      final listFinder = _messageTimelineListFinder();
      final scrollView = tester.widget<ListView>(listFinder);
      final initialPosition = scrollView.controller!.position;
      final initialMaxExtent = initialPosition.maxScrollExtent;

      scrollView.controller!.jumpTo(0);
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      final updatedPosition = scrollView.controller!.position;
      expect(updatedPosition.maxScrollExtent, greaterThan(initialMaxExtent));
      expect(updatedPosition.pixels, lessThan(updatedPosition.maxScrollExtent));
      expect(find.text('user long session message 0'), findsNothing);
    },
  );
}

Future<void> _sendShortcut(
  WidgetTester tester,
  List<LogicalKeyboardKey> keys,
) async {
  for (final key in keys) {
    await tester.sendKeyDownEvent(key);
  }
  for (final key in keys.reversed) {
    await tester.sendKeyUpEvent(key);
  }
}

Finder _messageTimelineListFinder() {
  return find.byWidgetPredicate(
    (widget) =>
        widget is ListView &&
        widget.key is PageStorageKey<String> &&
        (widget.key! as PageStorageKey<String>).value.startsWith(
          'web-parity-message-timeline',
        ),
  );
}

Finder _paneLoadingFinder() {
  return find.byWidgetPredicate(
    (widget) =>
        widget.key is ValueKey<String> &&
        (widget.key! as ValueKey<String>).value.startsWith(
          'workspace-session-pane-loading-',
        ),
  );
}

String _composerText(WidgetTester tester) {
  return tester
          .widget<TextField>(
            find.byKey(const ValueKey<String>('composer-text-field')),
          )
          .controller
          ?.text ??
      '';
}

class _WorkspaceRouteHarness extends StatelessWidget {
  const _WorkspaceRouteHarness({
    required this.controller,
    required this.navigatorKey,
    required this.initialRoute,
    this.navigatorObservers = const <NavigatorObserver>[],
    this.projectCatalogService,
    this.attachmentPicker,
    this.platform,
  });

  final WebParityAppController controller;
  final GlobalKey<NavigatorState> navigatorKey;
  final String initialRoute;
  final List<NavigatorObserver> navigatorObservers;
  final ProjectCatalogService? projectCatalogService;
  final Future<List<PromptAttachment>> Function()? attachmentPicker;
  final TargetPlatform? platform;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      controller: controller,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          return MaterialApp(
            navigatorKey: navigatorKey,
            navigatorObservers: navigatorObservers,
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
                        attachmentPicker: attachmentPicker,
                        projectCatalogService: projectCatalogService,
                      ),
                  };
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _ShortcutProjectCatalogService extends ProjectCatalogService {
  @override
  Future<ProjectCatalog> fetchCatalog(ServerProfile profile) async {
    return ProjectCatalog(
      currentProject: const ProjectSummary(
        id: 'demo',
        directory: '/workspace/demo',
        worktree: '/workspace/demo',
        name: 'Demo',
        vcs: 'git',
        updatedAt: null,
      ),
      projects: const <ProjectSummary>[
        ProjectSummary(
          id: 'demo',
          directory: '/workspace/demo',
          worktree: '/workspace/demo',
          name: 'Demo',
          vcs: 'git',
          updatedAt: null,
        ),
        ProjectSummary(
          id: 'lab',
          directory: '/workspace/lab',
          worktree: '/workspace/lab',
          name: 'Lab',
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

class _RecordingWorkspaceController extends WorkspaceController {
  _RecordingWorkspaceController({
    required super.profile,
    required super.directory,
    super.initialSessionId,
  }) : _sessions = List<SessionSummary>.from(_seedSessionsFor(directory));

  static const ProjectTarget _demoProject = ProjectTarget(
    directory: '/workspace/demo',
    label: 'Demo',
    source: 'server',
    vcs: 'git',
    branch: 'main',
  );
  static const ProjectTarget _labProject = ProjectTarget(
    directory: '/workspace/lab',
    label: 'Lab',
    source: 'server',
    vcs: 'git',
    branch: 'develop',
  );
  static const List<ProjectTarget> _availableProjects = <ProjectTarget>[
    _demoProject,
    _labProject,
  ];
  static final Map<String, SessionStatusSummary> _sessionStatuses =
      <String, SessionStatusSummary>{
        'ses_1': const SessionStatusSummary(type: 'idle'),
        'ses_2': const SessionStatusSummary(type: 'idle'),
        'ses_new': const SessionStatusSummary(type: 'idle'),
        'ses_lab_1': const SessionStatusSummary(type: 'idle'),
      };

  int loadCount = 0;
  int createEmptySessionCalls = 0;
  final List<String?> selectSessionCalls = <String?>[];

  bool _loading = true;
  String? _selectedSessionId;
  List<ChatMessage> _messages = const <ChatMessage>[];
  List<SessionSummary> _sessions;

  @override
  bool get loading => _loading;

  @override
  ProjectTarget? get project => switch (directory) {
    '/workspace/lab' => _labProject,
    _ => _demoProject,
  };

  @override
  List<ProjectTarget> get availableProjects => _availableProjects;

  @override
  List<SessionSummary> get sessions => _sessions;

  @override
  Map<String, SessionStatusSummary> get statuses => _sessionStatuses;

  @override
  String? get selectedSessionId => _selectedSessionId;

  @override
  SessionSummary? get selectedSession {
    final selectedSessionId = _selectedSessionId;
    if (selectedSessionId == null) {
      return null;
    }
    for (final session in _sessions) {
      if (session.id == selectedSessionId) {
        return session;
      }
    }
    return null;
  }

  @override
  SessionStatusSummary? get selectedStatus {
    final selectedSessionId = _selectedSessionId;
    if (selectedSessionId == null) {
      return null;
    }
    return statuses[selectedSessionId];
  }

  @override
  List<ChatMessage> get messages => _messages;

  @override
  WorkspaceSessionTimelineState timelineStateForSession(String? sessionId) {
    final normalized = sessionId?.trim();
    if (normalized == null || normalized.isEmpty) {
      return const WorkspaceSessionTimelineState.empty();
    }
    final messages = _messageListFor(normalized);
    return WorkspaceSessionTimelineState(
      sessionId: normalized,
      messages: messages,
      orderedMessages: messages,
      loading: _loading && normalized == _selectedSessionId,
      showingCachedMessages: false,
    );
  }

  @override
  void updateWatchedSessionIds(Iterable<String?> sessionIds) {}

  @override
  Future<void> refreshTimelineSession(String? sessionId) async {}

  @override
  List<TodoItem> get todos => const <TodoItem>[];

  @override
  PendingRequestBundle get pendingRequests => const PendingRequestBundle(
    questions: <QuestionRequestSummary>[],
    permissions: <PermissionRequestSummary>[],
  );

  @override
  Future<void> load() async {
    loadCount += 1;
    _loading = false;
    _selectedSessionId = initialSessionId ?? _sessions.first.id;
    _messages = _messageListFor(_selectedSessionId);
    notifyListeners();
  }

  @override
  Future<void> selectSession(String? sessionId) async {
    selectSessionCalls.add(sessionId);
    _selectedSessionId = sessionId;
    _messages = _messageListFor(sessionId);
    notifyListeners();
  }

  @override
  Future<SessionSummary?> createEmptySession({String? title}) async {
    createEmptySessionCalls += 1;
    final created = SessionSummary(
      id: directory == '/workspace/lab' ? 'ses_lab_new' : 'ses_new',
      directory: directory,
      title: 'Fresh session',
      version: '1',
      updatedAt: DateTime.fromMillisecondsSinceEpoch(1710000003000),
    );
    _sessions = <SessionSummary>[created, ..._sessions];
    _selectedSessionId = created.id;
    _messages = const <ChatMessage>[];
    notifyListeners();
    return created;
  }

  List<ChatMessage> _messageListFor(String? sessionId) {
    if (sessionId == null) {
      return const <ChatMessage>[];
    }
    final text = switch ((directory, sessionId)) {
      ('/workspace/demo', 'ses_2') => 'hello from two',
      ('/workspace/lab', _) => 'hello from lab',
      _ => 'hello from one',
    };
    return <ChatMessage>[
      ChatMessage(
        info: ChatMessageInfo(
          id: 'msg_$sessionId',
          role: 'assistant',
          sessionId: sessionId,
        ),
        parts: <ChatPart>[
          ChatPart(id: 'part_$sessionId', type: 'text', text: text),
        ],
      ),
    ];
  }

  static List<SessionSummary> _seedSessionsFor(String directory) {
    return switch (directory) {
      '/workspace/lab' => <SessionSummary>[
        SessionSummary(
          id: 'ses_lab_1',
          directory: '/workspace/lab',
          title: 'Lab Session',
          version: '1',
          updatedAt: DateTime.fromMillisecondsSinceEpoch(1710000004000),
        ),
      ],
      _ => <SessionSummary>[
        SessionSummary(
          id: 'ses_1',
          directory: '/workspace/demo',
          title: 'Session One',
          version: '1',
          updatedAt: DateTime.fromMillisecondsSinceEpoch(1710000001000),
        ),
        SessionSummary(
          id: 'ses_2',
          directory: '/workspace/demo',
          title: 'Session Two',
          version: '1',
          updatedAt: DateTime.fromMillisecondsSinceEpoch(1710000002000),
        ),
      ],
    };
  }
}

class _PaneMetadataWorkspaceController extends _RecordingWorkspaceController {
  _PaneMetadataWorkspaceController({
    required super.profile,
    required super.directory,
    super.initialSessionId,
  }) {
    if (directory == '/workspace/demo') {
      _sessions = <SessionSummary>[
        SessionSummary(
          id: 'ses_1',
          directory: '/workspace/demo',
          title: 'Session One',
          version: '1',
          updatedAt: DateTime.fromMillisecondsSinceEpoch(1710000001000),
        ),
        SessionSummary(
          id: 'ses_1_child',
          directory: '/workspace/demo',
          title: 'Plan anomaly feature (@plan subagent)',
          version: '1',
          parentId: 'ses_1',
          updatedAt: DateTime.fromMillisecondsSinceEpoch(1710000001500),
        ),
        SessionSummary(
          id: 'ses_2',
          directory: '/workspace/demo',
          title: 'Session Two',
          version: '1',
          updatedAt: DateTime.fromMillisecondsSinceEpoch(1710000002000),
        ),
        SessionSummary(
          id: 'ses_2_child',
          directory: '/workspace/demo',
          title: 'Find validation hook (@explore subagent)',
          version: '1',
          parentId: 'ses_2',
          updatedAt: DateTime.fromMillisecondsSinceEpoch(1710000002500),
        ),
      ];
    }
  }

  static final Map<String, SessionStatusSummary> _paneStatuses =
      <String, SessionStatusSummary>{
        ..._RecordingWorkspaceController._sessionStatuses,
        'ses_1_child': const SessionStatusSummary(type: 'running'),
        'ses_2_child': const SessionStatusSummary(type: 'running'),
      };
  final Map<String, List<TodoItem>> _todosBySession = <String, List<TodoItem>>{
    'ses_1': const <TodoItem>[
      TodoItem(
        id: 'todo_ses_1',
        content: 'todo for one',
        status: 'pending',
        priority: 'medium',
      ),
    ],
    'ses_2': const <TodoItem>[
      TodoItem(
        id: 'todo_ses_2',
        content: 'todo for two',
        status: 'in_progress',
        priority: 'high',
      ),
    ],
  };

  @override
  Map<String, SessionStatusSummary> get statuses => _paneStatuses;

  @override
  List<TodoItem> get todos => todosForSession(selectedSessionId);

  @override
  List<TodoItem> todosForSession(String? sessionId) {
    final normalizedSessionId = sessionId?.trim();
    if (normalizedSessionId == null || normalizedSessionId.isEmpty) {
      return const <TodoItem>[];
    }
    return _todosBySession[normalizedSessionId] ?? const <TodoItem>[];
  }

  @override
  Map<String, String> activeChildSessionPreviewByIdForSession(
    String? sessionId,
  ) {
    return switch (sessionId) {
      'ses_1' => const <String, String>{'ses_1_child': 'tool-calls'},
      'ses_2' => const <String, String>{
        'ses_2_child': 'Thinking through the task',
      },
      _ => const <String, String>{},
    };
  }

  @override
  void clearTodosForSession(String? sessionId) {
    final normalizedSessionId = sessionId?.trim();
    if (normalizedSessionId == null || normalizedSessionId.isEmpty) {
      return;
    }
    _todosBySession.remove(normalizedSessionId);
    notifyListeners();
  }
}

class _SubmittingRecordingWorkspaceController
    extends _RecordingWorkspaceController {
  _SubmittingRecordingWorkspaceController({
    required super.profile,
    required super.directory,
    super.initialSessionId,
  });

  final List<String> submittedPrompts = <String>[];

  @override
  Future<String?> submitPrompt(
    String prompt, {
    List<PromptAttachment> attachments = const <PromptAttachment>[],
    WorkspacePromptDispatchMode? mode,
  }) async {
    submittedPrompts.add(prompt.trim());
    return selectedSessionId;
  }
}

class _ThinkingPlaceholderWorkspaceController
    extends _SubmittingRecordingWorkspaceController {
  _ThinkingPlaceholderWorkspaceController({
    required super.profile,
    required super.directory,
    super.initialSessionId,
  }) {
    final sessionId = initialSessionId ?? 'ses_1';
    _timelineMessages = _messageListFor(sessionId)
        .map(
          (message) => message.info.role == 'assistant'
              ? message.copyWith(
                  info: message.info.copyWith(
                    completedAt: DateTime.fromMillisecondsSinceEpoch(
                      1710000001000,
                    ),
                  ),
                )
              : message,
        )
        .toList(growable: false);
  }

  late List<ChatMessage> _timelineMessages;
  bool _busy = false;

  @override
  List<ChatMessage> get messages => _timelineMessages;

  @override
  WorkspaceSessionTimelineState timelineStateForSession(String? sessionId) {
    final normalized = sessionId?.trim();
    if (normalized == null || normalized.isEmpty) {
      return const WorkspaceSessionTimelineState.empty();
    }
    final messages = normalized == selectedSessionId
        ? _timelineMessages
        : _messageListFor(normalized);
    return WorkspaceSessionTimelineState(
      sessionId: normalized,
      messages: messages,
      orderedMessages: messages,
      loading: false,
      showingCachedMessages: false,
    );
  }

  @override
  bool sessionBusyForSession(String? sessionId) {
    return _busy && sessionId?.trim() == selectedSessionId;
  }

  @override
  Future<String?> submitPrompt(
    String prompt, {
    List<PromptAttachment> attachments = const <PromptAttachment>[],
    WorkspacePromptDispatchMode? mode,
  }) async {
    final sessionId = await super.submitPrompt(
      prompt,
      attachments: attachments,
      mode: mode,
    );
    _busy = true;
    notifyListeners();
    return sessionId;
  }

  void beginAssistantResponse() {
    final sessionId = selectedSessionId;
    if (sessionId == null || sessionId.isEmpty) {
      return;
    }
    _timelineMessages = <ChatMessage>[
      ..._timelineMessages,
      ChatMessage(
        info: ChatMessageInfo(
          id: 'msg_reasoning_$sessionId',
          role: 'assistant',
          sessionId: sessionId,
        ),
        parts: const <ChatPart>[
          ChatPart(
            id: 'part_reasoning',
            type: 'reasoning',
            text: 'Thinking through the task',
          ),
        ],
      ),
    ];
    notifyListeners();
  }
}

class _PaneQuestionWorkspaceController extends _RecordingWorkspaceController {
  _PaneQuestionWorkspaceController({
    required super.profile,
    required super.directory,
    super.initialSessionId,
  });

  final Map<String, QuestionRequestSummary> _questionsBySession =
      <String, QuestionRequestSummary>{
        'ses_1': const QuestionRequestSummary(
          id: 'que_ses_1',
          sessionId: 'ses_1',
          questions: <QuestionPromptSummary>[
            QuestionPromptSummary(
              question: 'Which deployment target should I use?',
              header: 'Deployment',
              multiple: false,
              options: <QuestionOptionSummary>[
                QuestionOptionSummary(
                  label: 'Production',
                  description: 'Use the stable production stack.',
                ),
                QuestionOptionSummary(
                  label: 'Staging',
                  description: 'Verify the rollout before production.',
                ),
              ],
            ),
          ],
        ),
        'ses_2': const QuestionRequestSummary(
          id: 'que_ses_2',
          sessionId: 'ses_2',
          questions: <QuestionPromptSummary>[
            QuestionPromptSummary(
              question: 'What should I do with this flaky test?',
              header: 'Flaky test',
              multiple: false,
              custom: false,
              options: <QuestionOptionSummary>[
                QuestionOptionSummary(
                  label: 'Fix it now',
                  description: 'Pause and patch the failure immediately.',
                ),
                QuestionOptionSummary(
                  label: 'Quarantine it',
                  description:
                      'Keep moving and isolate the test for follow-up.',
                ),
              ],
            ),
          ],
        ),
      };

  @override
  PendingRequestBundle get pendingRequests => PendingRequestBundle(
    questions: _questionsBySession.values.toList(growable: false),
    permissions: const <PermissionRequestSummary>[],
  );
}

class _PanePermissionWorkspaceController extends _RecordingWorkspaceController {
  _PanePermissionWorkspaceController({
    required super.profile,
    required super.directory,
    super.initialSessionId,
  });

  final Map<String, PermissionRequestSummary> _permissionsBySession =
      <String, PermissionRequestSummary>{
        'ses_1': const PermissionRequestSummary(
          id: 'per_ses_1',
          sessionId: 'ses_1',
          permission: 'bash',
          patterns: <String>['npm test'],
        ),
        'ses_2': const PermissionRequestSummary(
          id: 'per_ses_2',
          sessionId: 'ses_2',
          permission: 'edit',
          patterns: <String>['lib/**'],
        ),
      };

  @override
  PendingRequestBundle get pendingRequests => PendingRequestBundle(
    questions: const <QuestionRequestSummary>[],
    permissions: _permissionsBySession.values.toList(growable: false),
  );
}

class _BusyPaneIndicatorWorkspaceController
    extends _RecordingWorkspaceController {
  _BusyPaneIndicatorWorkspaceController({
    required super.profile,
    required super.directory,
    super.initialSessionId,
  });

  final Map<String, SessionStatusSummary> _busyStatuses =
      <String, SessionStatusSummary>{
        ..._RecordingWorkspaceController._sessionStatuses,
        'ses_1': const SessionStatusSummary(type: 'running'),
      };

  @override
  Map<String, SessionStatusSummary> get statuses => _busyStatuses;
}

class _CompletedTodoWorkspaceController extends _RecordingWorkspaceController {
  _CompletedTodoWorkspaceController({
    required super.profile,
    required super.directory,
    super.initialSessionId,
  });

  static const List<TodoItem> _completedTodos = <TodoItem>[
    TodoItem(
      id: 'todo_completed_alpha',
      content: 'completed todo alpha',
      status: 'completed',
      priority: 'medium',
    ),
    TodoItem(
      id: 'todo_completed_beta',
      content: 'completed todo beta',
      status: 'completed',
      priority: 'low',
    ),
  ];

  @override
  List<TodoItem> get todos => todosForSession(selectedSessionId);

  @override
  List<TodoItem> todosForSession(String? sessionId) {
    return switch (sessionId?.trim()) {
      'ses_1' => _completedTodos,
      _ => const <TodoItem>[],
    };
  }

  void emitUnchangedUpdate() {
    notifyListeners();
  }
}

class _DelayedRecordingWorkspaceController
    extends _RecordingWorkspaceController {
  _DelayedRecordingWorkspaceController({
    required super.profile,
    required super.directory,
    required this.loadCompleter,
    super.initialSessionId,
  });

  final Completer<void> loadCompleter;

  @override
  Future<void> load() async {
    loadCount += 1;
    await loadCompleter.future;
    _loading = false;
    _selectedSessionId = initialSessionId ?? _sessions.first.id;
    _messages = _messageListFor(_selectedSessionId);
    notifyListeners();
  }
}

class _StreamingWorkspaceController extends WorkspaceController {
  _StreamingWorkspaceController({
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

  bool _loading = true;
  String? _selectedSessionId;
  late List<ChatMessage> _messages = _buildMessages();

  @override
  bool get loading => _loading;

  @override
  ProjectTarget? get project => _projectTarget;

  @override
  List<ProjectTarget> get availableProjects => const <ProjectTarget>[
    _projectTarget,
  ];

  @override
  List<SessionSummary> get sessions => <SessionSummary>[
    SessionSummary(
      id: 'ses_1',
      directory: '/workspace/demo',
      title: 'Streaming session',
      version: '1',
      updatedAt: DateTime.fromMillisecondsSinceEpoch(1710000001000),
    ),
  ];

  @override
  String? get selectedSessionId => _selectedSessionId;

  @override
  SessionSummary? get selectedSession => sessions.first;

  @override
  List<ChatMessage> get messages => _messages;

  @override
  WorkspaceSessionTimelineState timelineStateForSession(String? sessionId) {
    final normalized = sessionId?.trim();
    if (normalized == null || normalized.isEmpty) {
      return const WorkspaceSessionTimelineState.empty();
    }
    return WorkspaceSessionTimelineState(
      sessionId: normalized,
      messages: _messages,
      orderedMessages: _messages,
      loading: _loading,
      showingCachedMessages: false,
    );
  }

  @override
  void updateWatchedSessionIds(Iterable<String?> sessionIds) {}

  @override
  Future<void> refreshTimelineSession(String? sessionId) async {}

  @override
  Future<void> load() async {
    _loading = false;
    _selectedSessionId = initialSessionId ?? 'ses_1';
    notifyListeners();
  }

  void extendLastAssistantMessage(String extra) {
    final next = List<ChatMessage>.from(_messages);
    final last = next.removeLast();
    final updatedParts = List<ChatPart>.from(last.parts);
    final lastPart = updatedParts.removeLast();
    updatedParts.add(lastPart.copyWith(text: '${lastPart.text ?? ''}$extra'));
    next.add(last.copyWith(parts: updatedParts));
    _messages = next;
    notifyListeners();
  }

  List<ChatMessage> _buildMessages() {
    return List<ChatMessage>.generate(28, (index) {
      final role = index.isEven ? 'user' : 'assistant';
      final text = List<String>.filled(
        8,
        '$role message $index with enough content to wrap across lines.',
      ).join(' ');
      return ChatMessage(
        info: ChatMessageInfo(id: 'msg_$index', role: role, sessionId: 'ses_1'),
        parts: <ChatPart>[
          ChatPart(id: 'part_$index', type: 'text', text: text),
        ],
      );
    });
  }
}

class _LongSessionWorkspaceController extends WorkspaceController {
  _LongSessionWorkspaceController({
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

  bool _loading = true;
  String? _selectedSessionId;
  List<ChatMessage> _messages = const <ChatMessage>[];

  @override
  bool get loading => _loading;

  @override
  ProjectTarget? get project => _projectTarget;

  @override
  List<ProjectTarget> get availableProjects => const <ProjectTarget>[
    _projectTarget,
  ];

  @override
  List<SessionSummary> get sessions => <SessionSummary>[
    SessionSummary(
      id: 'ses_long',
      directory: '/workspace/demo',
      title: 'Long session',
      version: '1',
      updatedAt: DateTime.fromMillisecondsSinceEpoch(1710000001000),
    ),
  ];

  @override
  String? get selectedSessionId => _selectedSessionId;

  @override
  SessionSummary? get selectedSession => sessions.first;

  @override
  List<ChatMessage> get messages => _messages;

  @override
  WorkspaceSessionTimelineState timelineStateForSession(String? sessionId) {
    final normalized = sessionId?.trim();
    if (normalized == null || normalized.isEmpty) {
      return const WorkspaceSessionTimelineState.empty();
    }
    return WorkspaceSessionTimelineState(
      sessionId: normalized,
      messages: _messages,
      orderedMessages: _messages,
      loading: _loading,
      showingCachedMessages: false,
    );
  }

  @override
  void updateWatchedSessionIds(Iterable<String?> sessionIds) {}

  @override
  Future<void> refreshTimelineSession(String? sessionId) async {}

  @override
  Future<void> load() async {
    _selectedSessionId = initialSessionId ?? 'ses_long';
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    _messages = List<ChatMessage>.generate(120, (index) {
      final role = index.isEven ? 'user' : 'assistant';
      final text = List<String>.filled(
        10,
        '$role long session message $index with enough content to wrap repeatedly across multiple lines.',
      ).join(' ');
      return ChatMessage(
        info: ChatMessageInfo(
          id: 'msg_long_$index',
          role: role,
          sessionId: 'ses_long',
        ),
        parts: <ChatPart>[
          ChatPart(id: 'part_long_$index', type: 'text', text: text),
        ],
      );
    });
    _loading = false;
    notifyListeners();
  }
}

class _RecordingNavigatorObserver extends NavigatorObserver {
  String? lastRouteName;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    lastRouteName = route.settings.name;
    super.didPush(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    lastRouteName = newRoute?.settings.name;
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
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
