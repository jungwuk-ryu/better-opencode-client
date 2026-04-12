import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:better_opencode_client/src/app/app_controller.dart';
import 'package:better_opencode_client/src/app/app_routes.dart';
import 'package:better_opencode_client/src/app/app_scope.dart';
import 'package:better_opencode_client/src/core/connection/connection_models.dart';
import 'package:better_opencode_client/src/core/spec/raw_json_document.dart';
import 'package:better_opencode_client/src/design_system/app_spacing.dart';
import 'package:better_opencode_client/src/design_system/app_theme.dart';
import 'package:better_opencode_client/src/features/chat/chat_models.dart';
import 'package:better_opencode_client/src/features/projects/project_models.dart';
import 'package:better_opencode_client/src/features/settings/config_service.dart';
import 'package:better_opencode_client/src/features/terminal/pty_models.dart';
import 'package:better_opencode_client/src/features/terminal/pty_service.dart';
import 'package:better_opencode_client/src/features/web_parity/workspace_controller.dart';
import 'package:better_opencode_client/src/features/web_parity/workspace_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('reasoning stays collapsed while shell output is shown live', (
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
      initialShellToolPartsExpanded: true,
      initialTimelineProgressDetailsVisible: false,
      workspaceControllerFactory:
          ({required profile, required directory, initialSessionId}) {
            return _TimelineWorkspaceController(
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
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      find.textContaining('Thinking Reviewing git workflow'),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('timeline-activity-shimmer-part_reasoning'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('timeline-shell-shimmer-part_tool')),
      findsOneWidget,
    );
    expect(find.text('Which environment should I target?'), findsNothing);
    expect(
      find.text('Detailed internal reasoning stays hidden.'),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('timeline-activity-part_step_start')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('timeline-activity-part_step_finish')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('timeline-activity-part_todo')),
      findsNothing,
    );
    expect(find.text('Verify bot runtime module'), findsNothing);
    expect(
      find.textContaining(r'$ git diff --staged && git diff'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('timeline-shell-copy-part_tool')),
      findsOneWidget,
    );
    expect(find.textContaining('release-checklist'), findsOneWidget);
    expect(find.text('Explored 4 reads'), findsOneWidget);
    expect(find.textContaining('daily-job.spec.ts'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey<String>('timeline-activity-part_reasoning')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      find.text('Detailed internal reasoning stays hidden.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'reasoning fallback does not expose transport ids while streaming starts',
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
        initialTimelineProgressDetailsVisible: false,
        workspaceControllerFactory:
            ({required profile, required directory, initialSessionId}) {
              return _OptimisticTimelineWorkspaceController(
                profile: profile,
                directory: directory,
                initialSessionId: initialSessionId,
                messages: <ChatMessage>[
                  ChatMessage(
                    info: ChatMessageInfo(
                      id: 'msg_reasoning_stream',
                      role: 'assistant',
                      sessionId: 'ses_1',
                      createdAt: DateTime.fromMillisecondsSinceEpoch(
                        1711421101000,
                      ),
                    ),
                    parts: const <ChatPart>[
                      ChatPart(
                        id: 'prtd_streaming_reasoning',
                        type: 'reasoning',
                        text: '',
                        messageId: 'msg_reasoning_stream',
                        sessionId: 'ses_1',
                        metadata: <String, Object?>{
                          'id': 'prtd_streaming_reasoning',
                          'messageID': 'msg_reasoning_stream',
                          'sessionID': 'ses_1',
                          'type': 'reasoning',
                          '_streaming': true,
                        },
                      ),
                    ],
                  ),
                ],
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
      await tester.pump(const Duration(milliseconds: 250));

      expect(
        find.byKey(
          const ValueKey<String>('timeline-activity-prtd_streaming_reasoning'),
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('Thinking', findRichText: true),
        findsOneWidget,
      );
      expect(find.textContaining('id: prtd', findRichText: true), findsNothing);
      expect(
        find.textContaining(
          'messageID: msg_reasoning_stream',
          findRichText: true,
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'shell output and activity detail share the same leading margin',
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
        initialShellToolPartsExpanded: true,
        initialTimelineProgressDetailsVisible: false,
        workspaceControllerFactory:
            ({required profile, required directory, initialSessionId}) {
              return _TimelineWorkspaceController(
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
      await tester.pump(const Duration(milliseconds: 250));

      await tester.tap(
        find.byKey(const ValueKey<String>('timeline-activity-part_reasoning')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final shellOutput = find.textContaining(
        r'$ git diff --staged && git diff',
      );
      final reasoningDetail = find.text(
        'Detailed internal reasoning stays hidden.',
      );

      expect(shellOutput, findsOneWidget);
      expect(reasoningDetail, findsOneWidget);
      expect(
        tester.getTopLeft(shellOutput).dx,
        tester.getTopLeft(reasoningDetail).dx,
      );
    },
  );

  testWidgets('read tool calls are grouped into an explored summary', (
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
      initialShellToolPartsExpanded: true,
      initialTimelineProgressDetailsVisible: false,
      workspaceControllerFactory:
          ({required profile, required directory, initialSessionId}) {
            return _TimelineWorkspaceController(
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
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Explored 4 reads'), findsOneWidget);
    expect(find.textContaining('daily-job.spec.ts'), findsNothing);

    final exploredHeader = find.byKey(
      const ValueKey<String>('timeline-explored-context-header-part_read_1'),
    );
    tester.widget<InkWell>(exploredHeader).onTap!.call();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      find.textContaining('daily-job.spec.ts  offset=261'),
      findsOneWidget,
    );
    expect(
      find.textContaining('runtime-state.spec.ts  offset=1  limit=220'),
      findsOneWidget,
    );
    expect(
      find.textContaining('bot-once.ts  offset=261  limit=80'),
      findsOneWidget,
    );
  });

  testWidgets('grep tool calls are counted as searches in explored summaries', (
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
      initialShellToolPartsExpanded: true,
      initialTimelineProgressDetailsVisible: false,
      workspaceControllerFactory:
          ({required profile, required directory, initialSessionId}) {
            return _MixedContextWorkspaceController(
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
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Explored 1 read, 1 search'), findsOneWidget);

    final exploredHeader = find.byKey(
      const ValueKey<String>('timeline-explored-context-header-part_read_1'),
    );
    tester.widget<InkWell>(exploredHeader).onTap!.call();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      find.textContaining('Read  daily-job.spec.ts  offset=261  limit=260'),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Search  /workspace/demo  pattern=DISCORD_MESSAGE_ID  include=*.ts',
      ),
      findsOneWidget,
    );
  });

  testWidgets('assistant code blocks expose a copy button', (tester) async {
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
      initialShellToolPartsExpanded: true,
      initialTimelineProgressDetailsVisible: false,
      workspaceControllerFactory:
          ({required profile, required directory, initialSessionId}) {
            return _CodeBlockWorkspaceController(
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
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('DART'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('timeline-code-copy-dart')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('timeline-code-content-highlighted-dart'),
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('timeline-code-copy-dart')),
    );
    await tester.pump();

    expect(find.text('Code block copied.'), findsOneWidget);
  });

  testWidgets('desktop hover on a user message reveals metadata and actions', (
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
    late _UserMessageActionWorkspaceController controllerInstance;
    final appController = _StaticAppController(
      profile: profile,
      initialShellToolPartsExpanded: true,
      initialTimelineProgressDetailsVisible: false,
      workspaceControllerFactory:
          ({required profile, required directory, initialSessionId}) {
            controllerInstance = _UserMessageActionWorkspaceController(
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
    await tester.pump(const Duration(milliseconds: 250));

    final bubble = find.byKey(
      const ValueKey<String>('timeline-user-message-msg_user_hover'),
    );
    expect(bubble, findsOneWidget);
    expect(
      find.byKey(
        const ValueKey<String>('timeline-user-actions-msg_user_hover'),
      ),
      findsNothing,
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer();
    await mouse.moveTo(tester.getCenter(bubble));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    expect(
      find.byKey(
        const ValueKey<String>('timeline-user-actions-msg_user_hover'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('GPT-5.4'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey<String>('timeline-user-action-fork-msg_user_hover'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('timeline-user-action-revert-msg_user_hover'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('timeline-user-action-copy-msg_user_hover'),
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(
        const ValueKey<String>('timeline-user-action-copy-msg_user_hover'),
      ),
    );
    await tester.pump();

    await tester.tap(
      find.byKey(
        const ValueKey<String>('timeline-user-action-fork-msg_user_hover'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(controllerInstance.forkCount, 1);
    expect(controllerInstance.lastForkMessageId, 'msg_user_hover');

    await tester.tap(
      find.byKey(
        const ValueKey<String>('timeline-user-action-revert-msg_user_hover'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(controllerInstance.revertCount, 1);
    expect(controllerInstance.lastRevertMessageId, 'msg_user_hover');
  });

  testWidgets('touch long press opens user message actions', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
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
      initialShellToolPartsExpanded: true,
      initialTimelineProgressDetailsVisible: false,
      workspaceControllerFactory:
          ({required profile, required directory, initialSessionId}) {
            return _UserMessageActionWorkspaceController(
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
        platform: TargetPlatform.android,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    await tester.longPress(
      find.byKey(
        const ValueKey<String>('timeline-user-message-msg_user_hover'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    expect(
      find.byKey(
        const ValueKey<String>(
          'timeline-user-action-sheet-fork-msg_user_hover',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>(
          'timeline-user-action-sheet-revert-msg_user_hover',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>(
          'timeline-user-action-sheet-copy-msg_user_hover',
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('processed prompt hides the optimistic raw user bubble', (
    tester,
  ) async {
    final profile = ServerProfile(
      id: 'server',
      label: 'Mock',
      baseUrl: 'http://localhost:3000',
    );
    final appController = _StaticAppController(
      profile: profile,
      initialShellToolPartsExpanded: true,
      initialTimelineProgressDetailsVisible: false,
      workspaceControllerFactory:
          ({required profile, required directory, initialSessionId}) {
            return _OptimisticTimelineWorkspaceController(
              profile: profile,
              directory: directory,
              initialSessionId: initialSessionId,
              messages: _processedPromptMessages,
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
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      find.byKey(
        const ValueKey<String>('timeline-user-message-msg_local_prompt'),
      ),
      findsNothing,
    );
    expect(find.textContaining('[search-mode]'), findsOneWidget);
  });

  testWidgets(
    'ordinary assistant replies keep the optimistic raw user bubble visible',
    (tester) async {
      final profile = ServerProfile(
        id: 'server',
        label: 'Mock',
        baseUrl: 'http://localhost:3000',
      );
      final appController = _StaticAppController(
        profile: profile,
        initialShellToolPartsExpanded: true,
        initialTimelineProgressDetailsVisible: false,
        workspaceControllerFactory:
            ({required profile, required directory, initialSessionId}) {
              return _OptimisticTimelineWorkspaceController(
                profile: profile,
                directory: directory,
                initialSessionId: initialSessionId,
                messages: _ordinaryAssistantReplyMessages,
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
      await tester.pump(const Duration(milliseconds: 250));

      expect(
        find.byKey(
          const ValueKey<String>('timeline-user-message-msg_local_plain'),
        ),
        findsOneWidget,
      );
      expect(find.text('I can check the branch list next.'), findsOneWidget);
    },
  );

  testWidgets('assistant text replies are selectable', (tester) async {
    final profile = ServerProfile(
      id: 'server',
      label: 'Mock',
      baseUrl: 'http://localhost:3000',
    );
    final appController = _StaticAppController(
      profile: profile,
      initialShellToolPartsExpanded: true,
      initialTimelineProgressDetailsVisible: false,
      workspaceControllerFactory:
          ({required profile, required directory, initialSessionId}) {
            return _OptimisticTimelineWorkspaceController(
              profile: profile,
              directory: directory,
              initialSessionId: initialSessionId,
              messages: _ordinaryAssistantReplyMessages,
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
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      find.byKey(
        const ValueKey<String>('timeline-selectable-text-part_assistant_plain'),
      ),
      findsOneWidget,
    );
    expect(
      find.ancestor(
        of: find.text('I can check the branch list next.'),
        matching: find.byType(SelectionArea),
      ),
      findsWidgets,
    );
  });

  testWidgets(
    'desktop user message actions survive rapid hover toggles without duplicate keys',
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
        initialShellToolPartsExpanded: true,
        initialTimelineProgressDetailsVisible: false,
        workspaceControllerFactory:
            ({required profile, required directory, initialSessionId}) {
              return _UserMessageActionWorkspaceController(
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
          platform: TargetPlatform.macOS,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final bubble = find.byKey(
        const ValueKey<String>('timeline-user-message-msg_user_hover'),
      );
      expect(bubble, findsOneWidget);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer();

      await mouse.moveTo(tester.getCenter(bubble));
      await tester.pump(const Duration(milliseconds: 60));
      await mouse.moveTo(const Offset(8, 8));
      await tester.pump(const Duration(milliseconds: 60));
      await mouse.moveTo(tester.getCenter(bubble));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 220));

      expect(tester.takeException(), isNull);
      expect(
        find.byKey(
          const ValueKey<String>('timeline-user-actions-msg_user_hover'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('chat code block highlighting can be disabled', (tester) async {
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
      initialShellToolPartsExpanded: true,
      initialTimelineProgressDetailsVisible: false,
      initialChatCodeBlockHighlightingEnabled: false,
      workspaceControllerFactory:
          ({required profile, required directory, initialSessionId}) {
            return _CodeBlockWorkspaceController(
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
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      find.byKey(
        const ValueKey<String>('timeline-code-content-highlighted-dart'),
      ),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('timeline-code-content-plain-dart')),
      findsOneWidget,
    );
  });

  testWidgets(
    'messages stay in chronological turn order even when an earlier assistant turn is still active',
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
        initialShellToolPartsExpanded: true,
        initialTimelineProgressDetailsVisible: false,
        workspaceControllerFactory:
            ({required profile, required directory, initialSessionId}) {
              return _ConversationOrderingWorkspaceController(
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
      await tester.pump(const Duration(milliseconds: 250));

      final firstUserTop = tester.getTopLeft(find.text('테스트 메시지입니다.')).dy;
      final firstAssistantTop = tester
          .getTopLeft(find.text('테스트 메시지 확인했습니다. 필요한 작업을 보내주시면 바로 도와드릴게요.'))
          .dy;
      final secondUserTop = tester.getTopLeft(find.text('테스트2 입니다.')).dy;
      final secondAssistantTop = tester
          .getTopLeft(find.text('확인했습니다. 이어서 원하는 작업 말씀해 주세요.'))
          .dy;

      expect(firstUserTop, lessThan(firstAssistantTop));
      expect(firstAssistantTop, lessThan(secondUserTop));
      expect(secondUserTop, lessThan(secondAssistantTop));
    },
  );

  testWidgets(
    'assistant text stays left-aligned regardless of message length',
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
        initialShellToolPartsExpanded: true,
        initialTimelineProgressDetailsVisible: false,
        workspaceControllerFactory:
            ({required profile, required directory, initialSessionId}) {
              return _ConversationOrderingWorkspaceController(
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
      await tester.pump(const Duration(milliseconds: 250));

      final firstAssistantLeft = tester
          .getTopLeft(find.text('테스트 메시지 확인했습니다. 필요한 작업을 보내주시면 바로 도와드릴게요.'))
          .dx;
      final secondAssistantLeft = tester
          .getTopLeft(find.text('확인했습니다. 이어서 원하는 작업 말씀해 주세요.'))
          .dx;

      expect((firstAssistantLeft - secondAssistantLeft).abs(), lessThan(8));
    },
  );

  testWidgets('shell output can be collapsed from the workspace setting', (
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
      initialShellToolPartsExpanded: true,
      initialTimelineProgressDetailsVisible: false,
      workspaceControllerFactory:
          ({required profile, required directory, initialSessionId}) {
            return _TimelineWorkspaceController(
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
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      find.textContaining(r'$ git diff --staged && git diff'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('timeline-shell-expanded-part_tool')),
      findsOneWidget,
    );
    expect(find.textContaining('M README.md'), findsOneWidget);

    await appController.setShellToolDisplayMode(ShellToolDisplayMode.collapsed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      find.textContaining(r'$ git diff --staged && git diff'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('timeline-shell-expanded-part_tool')),
      findsNothing,
    );
    expect(find.textContaining('M README.md'), findsNothing);
  });

  testWidgets('shell auto mode releases expansion after completion', (
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
    late _MutableShellWorkspaceController controllerInstance;
    final appController = _StaticAppController(
      profile: profile,
      initialShellToolDisplayMode: ShellToolDisplayMode.autoCollapse,
      initialTimelineProgressDetailsVisible: false,
      workspaceControllerFactory:
          ({required profile, required directory, initialSessionId}) {
            controllerInstance = _MutableShellWorkspaceController(
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
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      find.byKey(const ValueKey<String>('timeline-shell-expanded-part_tool')),
      findsOneWidget,
    );

    controllerInstance.completeShell(
      output: List<String>.generate(
        8,
        (index) => 'line ${index + 1}',
      ).join('\n'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      find.byKey(const ValueKey<String>('timeline-shell-expanded-part_tool')),
      findsNothing,
    );
    expect(find.textContaining('line 8'), findsNothing);
    expect(find.textContaining('line 1'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey<String>('timeline-shell-header-part_tool')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      find.byKey(const ValueKey<String>('timeline-shell-expanded-part_tool')),
      findsOneWidget,
    );
    expect(find.textContaining('line 8'), findsOneWidget);
    expect(find.textContaining('line 1'), findsOneWidget);
  });

  testWidgets('shell auto mode keeps in-progress output expanded live', (
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
    late _MutableShellWorkspaceController controllerInstance;
    final appController = _StaticAppController(
      profile: profile,
      initialShellToolDisplayMode: ShellToolDisplayMode.autoCollapse,
      initialTimelineProgressDetailsVisible: false,
      workspaceControllerFactory:
          ({required profile, required directory, initialSessionId}) {
            controllerInstance = _MutableShellWorkspaceController(
              profile: profile,
              directory: directory,
              initialSessionId: initialSessionId,
              initialStatus: 'in_progress',
              initialOutput: 'line 1',
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
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      find.byKey(const ValueKey<String>('timeline-shell-expanded-part_tool')),
      findsOneWidget,
    );
    expect(find.textContaining('line 1'), findsOneWidget);

    controllerInstance.updateShell(
      status: 'in_progress',
      output: 'line 1\nline 2\nline 3',
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      find.byKey(const ValueKey<String>('timeline-shell-expanded-part_tool')),
      findsOneWidget,
    );
    expect(find.textContaining('line 3'), findsOneWidget);

    controllerInstance.completeShell(output: 'line 1\nline 2\nline 3\nline 4');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      find.byKey(const ValueKey<String>('timeline-shell-expanded-part_tool')),
      findsNothing,
    );
    expect(find.textContaining('line 4'), findsNothing);
  });

  testWidgets(
    'shell output viewport shows five lines and follows latest output',
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
      late _MutableShellWorkspaceController controllerInstance;
      final appController = _StaticAppController(
        profile: profile,
        initialShellToolDisplayMode: ShellToolDisplayMode.alwaysExpanded,
        initialTimelineProgressDetailsVisible: false,
        workspaceControllerFactory:
            ({required profile, required directory, initialSessionId}) {
              controllerInstance = _MutableShellWorkspaceController(
                profile: profile,
                directory: directory,
                initialSessionId: initialSessionId,
                initialStatus: 'running',
                initialOutput: List<String>.generate(
                  3,
                  (index) => 'line ${index + 1}',
                ).join('\n'),
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
      await tester.pump(const Duration(milliseconds: 250));

      final viewportFinder = find.byKey(
        const ValueKey<String>('timeline-shell-log-viewport-part_tool'),
      );
      expect(viewportFinder, findsOneWidget);
      expect(tester.getSize(viewportFinder).height, inInclusiveRange(115, 130));
      expect(
        find.byKey(
          const ValueKey<String>('timeline-shell-output-selection-part_tool'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('timeline-shell-log-top-fade-part_tool'),
        ),
        findsOneWidget,
      );

      final outputContainer = tester.widget<Container>(
        find.byKey(const ValueKey<String>('timeline-shell-expanded-part_tool')),
      );
      expect(outputContainer.margin, isA<EdgeInsets>());
      expect((outputContainer.margin! as EdgeInsets).top, AppSpacing.xs);

      AnimatedOpacity fadeOpacity() {
        return tester.widget<AnimatedOpacity>(
          find
              .ancestor(
                of: find.byKey(
                  const ValueKey<String>(
                    'timeline-shell-log-top-fade-part_tool',
                  ),
                ),
                matching: find.byType(AnimatedOpacity),
              )
              .first,
        );
      }

      expect(fadeOpacity().opacity, 0);

      controllerInstance.updateShell(
        status: 'running',
        output: List<String>.generate(
          12,
          (index) => 'line ${index + 1}',
        ).join('\n'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final firstScrollView = tester.widget<SingleChildScrollView>(
        find.byKey(
          const ValueKey<String>('timeline-shell-log-scroll-part_tool'),
        ),
      );
      final firstController = firstScrollView.controller!;
      expect(firstController.position.maxScrollExtent, greaterThan(0));
      expect(
        firstController.offset,
        closeTo(firstController.position.maxScrollExtent, 0.1),
      );
      expect(fadeOpacity().opacity, 1);

      controllerInstance.updateShell(
        status: 'running',
        output: List<String>.generate(
          16,
          (index) => 'line ${index + 1}',
        ).join('\n'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final secondScrollView = tester.widget<SingleChildScrollView>(
        find.byKey(
          const ValueKey<String>('timeline-shell-log-scroll-part_tool'),
        ),
      );
      final secondController = secondScrollView.controller!;
      expect(
        secondController.offset,
        closeTo(secondController.position.maxScrollExtent, 0.1),
      );
    },
  );

  testWidgets('shell reads upstream live metadata output while running', (
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
    late _MutableShellWorkspaceController controllerInstance;
    final appController = _StaticAppController(
      profile: profile,
      initialShellToolDisplayMode: ShellToolDisplayMode.autoCollapse,
      initialTimelineProgressDetailsVisible: false,
      workspaceControllerFactory:
          ({required profile, required directory, initialSessionId}) {
            controllerInstance = _MutableShellWorkspaceController(
              profile: profile,
              directory: directory,
              initialSessionId: initialSessionId,
              initialStatus: 'running',
              initialOutput: '',
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
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Waiting for shell output…'), findsOneWidget);
    expect(find.textContaining('live line 1'), findsNothing);

    controllerInstance.updateShell(
      status: 'running',
      output: '',
      metadataOutput: 'live line 1\nlive line 2',
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Waiting for shell output…'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('timeline-shell-expanded-part_tool')),
      findsOneWidget,
    );
    expect(find.textContaining('live line 2'), findsOneWidget);
  });

  testWidgets('shell supports stdout fallback and completed output priority', (
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
    late _MutableShellWorkspaceController controllerInstance;
    final appController = _StaticAppController(
      profile: profile,
      initialShellToolDisplayMode: ShellToolDisplayMode.alwaysExpanded,
      initialTimelineProgressDetailsVisible: false,
      workspaceControllerFactory:
          ({required profile, required directory, initialSessionId}) {
            controllerInstance = _MutableShellWorkspaceController(
              profile: profile,
              directory: directory,
              initialSessionId: initialSessionId,
              initialStatus: 'running',
              initialOutput: '',
              initialMetadataStdout: 'stdout live 1',
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
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.textContaining('stdout live 1'), findsOneWidget);

    controllerInstance.updateShell(
      status: 'completed',
      output: 'final output line',
      metadataOutput: 'stale preview line',
      metadataStdout: 'stale stdout line',
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.textContaining('final output line'), findsOneWidget);
    expect(find.textContaining('stale preview line'), findsNothing);
    expect(find.textContaining('stale stdout line'), findsNothing);
  });

  testWidgets('collapsed mobile shell summary limits commands to two lines', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
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
      initialShellToolDisplayMode: ShellToolDisplayMode.collapsed,
      initialTimelineProgressDetailsVisible: false,
      workspaceControllerFactory:
          ({required profile, required directory, initialSessionId}) {
            return _MutableShellWorkspaceController(
              profile: profile,
              directory: directory,
              initialSessionId: initialSessionId,
              initialCommand: List<String>.generate(
                4,
                (index) => 'command step ${index + 1}',
              ).join('\n'),
              initialOutput: 'output row 1\noutput row 2',
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
    await tester.pump(const Duration(milliseconds: 250));

    final commandText = tester.widget<Text>(
      find.byKey(const ValueKey<String>('timeline-shell-command-part_tool')),
    );

    expect(commandText.maxLines, 2);
    expect(commandText.overflow, TextOverflow.ellipsis);
    expect(find.textContaining('output row 1'), findsNothing);
  });

  testWidgets('compaction renders as a divider instead of an activity card', (
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
      initialShellToolPartsExpanded: true,
      initialTimelineProgressDetailsVisible: false,
      workspaceControllerFactory:
          ({required profile, required directory, initialSessionId}) {
            return _TimelineWorkspaceController(
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
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      find.byKey(const ValueKey<String>('timeline-compaction-part_compaction')),
      findsOneWidget,
    );
    expect(find.text('Session compacted'), findsOneWidget);
    expect(find.text('Goal'), findsOneWidget);
    expect(find.textContaining('id: prt_compaction_1'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('timeline-activity-part_compaction')),
      findsNothing,
    );
  });

  testWidgets(
    'step details stay hidden and only to-do details can be shown from settings',
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
        initialShellToolPartsExpanded: true,
        initialTimelineProgressDetailsVisible: false,
        workspaceControllerFactory:
            ({required profile, required directory, initialSessionId}) {
              return _TimelineWorkspaceController(
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
      await tester.pump(const Duration(milliseconds: 250));

      expect(
        find.byKey(const ValueKey<String>('timeline-activity-part_step_start')),
        findsNothing,
      );
      expect(
        find.byKey(
          const ValueKey<String>('timeline-activity-part_step_finish'),
        ),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('timeline-activity-part_todo')),
        findsNothing,
      );

      await appController.setTimelineProgressDetailsVisible(true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(
        find.byKey(const ValueKey<String>('timeline-activity-part_step_start')),
        findsNothing,
      );
      expect(
        find.byKey(
          const ValueKey<String>('timeline-activity-part_step_finish'),
        ),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('timeline-activity-part_todo')),
        findsOneWidget,
      );
    },
  );
}

class _WorkspaceRouteHarness extends StatelessWidget {
  const _WorkspaceRouteHarness({
    required this.controller,
    required this.initialRoute,
    this.platform,
  });

  final WebParityAppController controller;
  final String initialRoute;
  final TargetPlatform? platform;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      controller: controller,
      child: MaterialApp(
        theme: AppTheme.dark().copyWith(platform: platform),
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
    bool initialShellToolPartsExpanded = false,
    ShellToolDisplayMode? initialShellToolDisplayMode,
    required bool initialTimelineProgressDetailsVisible,
    this.initialChatCodeBlockHighlightingEnabled = true,
    required WorkspaceControllerFactory workspaceControllerFactory,
  }) : _shellToolDisplayMode =
           initialShellToolDisplayMode ??
           (initialShellToolPartsExpanded
               ? ShellToolDisplayMode.alwaysExpanded
               : ShellToolDisplayMode.collapsed),
       _timelineProgressDetailsVisible = initialTimelineProgressDetailsVisible,
       _chatCodeBlockHighlightingEnabled =
           initialChatCodeBlockHighlightingEnabled,
       super(workspaceControllerFactory: workspaceControllerFactory);

  final ServerProfile profile;
  final bool initialChatCodeBlockHighlightingEnabled;
  ShellToolDisplayMode _shellToolDisplayMode;
  bool _timelineProgressDetailsVisible;
  bool _chatCodeBlockHighlightingEnabled;

  @override
  ServerProfile? get selectedProfile => profile;

  @override
  ShellToolDisplayMode get shellToolDisplayMode => _shellToolDisplayMode;

  @override
  bool get shellToolPartsExpanded =>
      _shellToolDisplayMode == ShellToolDisplayMode.alwaysExpanded;

  @override
  bool get timelineProgressDetailsVisible => _timelineProgressDetailsVisible;

  @override
  bool get chatCodeBlockHighlightingEnabled =>
      _chatCodeBlockHighlightingEnabled;

  @override
  Future<void> setShellToolDisplayMode(ShellToolDisplayMode value) async {
    _shellToolDisplayMode = value;
    notifyListeners();
  }

  @override
  Future<void> setTimelineProgressDetailsVisible(bool value) async {
    _timelineProgressDetailsVisible = value;
    notifyListeners();
  }

  @override
  Future<void> setChatCodeBlockHighlightingEnabled(bool value) async {
    _chatCodeBlockHighlightingEnabled = value;
    notifyListeners();
  }
}

class _MutableShellWorkspaceController extends WorkspaceController {
  _MutableShellWorkspaceController({
    required super.profile,
    required super.directory,
    super.initialSessionId,
    String initialStatus = 'running',
    String initialCommand = 'git diff --staged && git diff',
    String initialOutput = 'line 1\nline 2',
    String? initialMetadataOutput,
    String? initialMetadataStdout,
  }) : _command = initialCommand,
       _messages = <ChatMessage>[
         _buildShellMessage(
           status: initialStatus,
           command: initialCommand,
           output: initialOutput,
           metadataOutput: initialMetadataOutput,
           metadataStdout: initialMetadataStdout,
         ),
       ];

  static const ProjectTarget _projectTarget = ProjectTarget(
    directory: '/workspace/demo',
    label: 'Demo',
  );

  static final DateTime _timestamp = DateTime.fromMillisecondsSinceEpoch(
    1711421100000,
  );

  static final SessionSummary _session = SessionSummary(
    id: 'ses_1',
    directory: '/workspace/demo',
    title: 'Shell session',
    version: '1',
    updatedAt: _timestamp,
    createdAt: _timestamp,
  );

  bool _loading = true;
  final String _command;
  List<ChatMessage> _messages;

  static ChatMessage _buildShellMessage({
    String status = 'running',
    String command = 'git diff --staged && git diff',
    String output = 'line 1\nline 2',
    String? metadataOutput,
    String? metadataStdout,
  }) {
    final metadata = <String, Object?>{};
    if (metadataOutput != null) {
      metadata['output'] = metadataOutput;
    }
    if (metadataStdout != null) {
      metadata['stdout'] = metadataStdout;
    }
    if (metadata.isNotEmpty) {
      metadata['description'] = 'Run repository checks';
    }
    final state = <String, Object?>{
      'status': status,
      'title': 'Shell output',
      'input': <String, Object?>{
        'description': 'Run repository checks',
        'command': command,
      },
      if (output.isNotEmpty) 'output': output,
      if (metadata.isNotEmpty) 'metadata': metadata,
    };
    return ChatMessage(
      info: ChatMessageInfo(
        id: 'msg_shell',
        role: 'assistant',
        sessionId: 'ses_1',
        createdAt: _timestamp,
      ),
      parts: <ChatPart>[
        ChatPart(
          id: 'part_tool',
          type: 'tool',
          tool: 'bash',
          metadata: <String, Object?>{'state': state},
        ),
      ],
    );
  }

  @override
  bool get loading => _loading;

  @override
  ProjectTarget? get project => _projectTarget;

  @override
  List<ProjectTarget> get availableProjects => const <ProjectTarget>[
    _projectTarget,
  ];

  @override
  List<SessionSummary> get sessions => <SessionSummary>[_session];

  @override
  String? get selectedSessionId => _session.id;

  @override
  SessionSummary? get selectedSession => _session;

  @override
  List<ChatMessage> get messages => _messages;

  @override
  Future<void> load() async {
    _loading = false;
    notifyListeners();
  }

  void completeShell({required String output}) {
    updateShell(status: 'completed', output: output);
  }

  void updateShell({
    required String status,
    required String output,
    String? metadataOutput,
    String? metadataStdout,
  }) {
    _messages = <ChatMessage>[
      _buildShellMessage(
        status: status,
        command: _command,
        output: output,
        metadataOutput: metadataOutput,
        metadataStdout: metadataStdout,
      ),
    ];
    notifyListeners();
  }
}

class _TimelineWorkspaceController extends WorkspaceController {
  _TimelineWorkspaceController({
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

  static final SessionSummary _session = SessionSummary(
    id: 'ses_1',
    directory: '/workspace/demo',
    title: 'Investigate branch cleanup',
    version: '1',
    updatedAt: DateTime.fromMillisecondsSinceEpoch(1710000001000),
  );

  static final List<ChatMessage> _messages = <ChatMessage>[
    ChatMessage(
      info: const ChatMessageInfo(
        id: 'msg_user_1',
        role: 'user',
        sessionId: 'ses_1',
      ),
      parts: const <ChatPart>[
        ChatPart(
          id: 'part_user_1',
          type: 'text',
          text: 'Please verify the current git workflow.',
        ),
      ],
    ),
    ChatMessage(
      info: const ChatMessageInfo(
        id: 'msg_assistant_1',
        role: 'assistant',
        sessionId: 'ses_1',
      ),
      parts: <ChatPart>[
        const ChatPart(
          id: 'part_read_1',
          type: 'tool',
          tool: 'read',
          metadata: <String, Object?>{
            'state': <String, Object?>{
              'status': 'completed',
              'input': <String, Object?>{
                'filePath': 'test/unit/job/daily-job.spec.ts',
                'offset': 261,
                'limit': 260,
              },
            },
          },
        ),
        const ChatPart(
          id: 'part_read_2',
          type: 'tool',
          tool: 'read',
          metadata: <String, Object?>{
            'state': <String, Object?>{
              'status': 'completed',
              'input': <String, Object?>{
                'filePath': 'test/unit/shared/runtime-state.spec.ts',
                'offset': 1,
                'limit': 220,
              },
            },
          },
        ),
        const ChatPart(
          id: 'part_read_3',
          type: 'tool',
          tool: 'read',
          metadata: <String, Object?>{
            'state': <String, Object?>{
              'status': 'completed',
              'input': <String, Object?>{
                'filePath': 'test/integration/bot-once.ts',
                'offset': 1,
                'limit': 260,
              },
            },
          },
        ),
        const ChatPart(
          id: 'part_read_4',
          type: 'tool',
          tool: 'read',
          metadata: <String, Object?>{
            'state': <String, Object?>{
              'status': 'completed',
              'input': <String, Object?>{
                'filePath': 'test/integration/bot-once.ts',
                'offset': 261,
                'limit': 80,
              },
            },
          },
        ),
        const ChatPart(
          id: 'part_reasoning',
          type: 'reasoning',
          text:
              '## Reviewing git workflow\n\nDetailed internal reasoning stays hidden.',
        ),
        const ChatPart(
          id: 'part_question_pending',
          type: 'tool',
          tool: 'question',
          metadata: <String, Object?>{
            'state': <String, Object?>{
              'status': 'pending',
              'input': <String, Object?>{
                'questions': <Object?>[
                  <String, Object?>{
                    'question': 'Which environment should I target?',
                    'header': 'Environment',
                    'multiple': false,
                    'options': <Object?>[
                      <String, Object?>{
                        'label': 'Production',
                        'description': 'Use the production runner.',
                      },
                    ],
                  },
                ],
              },
            },
          },
        ),
        ChatPart(
          id: 'part_tool',
          type: 'tool',
          tool: 'bash',
          metadata: const <String, Object?>{
            'state': <String, Object?>{
              'status': 'running',
              'title': 'Shows staged and unstaged diff',
              'input': <String, Object?>{
                'description': 'Verify bot runtime module',
                'command': 'git diff --staged && git diff',
              },
              'output': 'M README.md\n M lib/main.dart',
            },
          },
        ),
        const ChatPart(
          id: 'part_skill',
          type: 'tool',
          tool: 'skill',
          metadata: <String, Object?>{
            'state': <String, Object?>{
              'status': 'completed',
              'input': <String, Object?>{
                'name': 'release-checklist',
                'description': 'Review the release safety checklist',
              },
            },
          },
        ),
        const ChatPart(
          id: 'part_step_start',
          type: 'step-start',
          metadata: <String, Object?>{
            'title': 'Planning implementation steps',
            'description': 'Draft the next sequence of changes.',
          },
        ),
        const ChatPart(
          id: 'part_step_finish',
          type: 'step-finish',
          metadata: <String, Object?>{
            'reason': 'Completed milestone checkpoint',
            'message': 'Ready to move on to the next task.',
          },
        ),
        const ChatPart(
          id: 'part_todo',
          type: 'tool',
          tool: 'todowrite',
          metadata: <String, Object?>{
            'todos': <Object?>[
              <String, Object?>{
                'id': 'todo_1',
                'content': 'Ship the timeline update',
                'status': 'in_progress',
                'priority': 'high',
              },
            ],
          },
        ),
      ],
    ),
    const ChatMessage(
      info: ChatMessageInfo(
        id: 'msg_assistant_2',
        role: 'assistant',
        sessionId: 'ses_1',
      ),
      parts: <ChatPart>[
        ChatPart(
          id: 'part_compaction',
          type: 'compaction',
          metadata: <String, Object?>{
            'id': 'prt_compaction_1',
            'sessionID': 'ses_1',
            'messageID': 'msg_assistant_2',
            'type': 'compaction',
          },
        ),
        ChatPart(
          id: 'part_compaction_text',
          type: 'text',
          text:
              'Goal\n\nCreate and implement the planned architecture for the repo workflow.',
        ),
      ],
    ),
  ];

  bool _loading = true;

  @override
  bool get loading => _loading;

  @override
  ProjectTarget? get project => _projectTarget;

  @override
  List<ProjectTarget> get availableProjects => const <ProjectTarget>[
    _projectTarget,
  ];

  @override
  List<SessionSummary> get sessions => <SessionSummary>[_session];

  @override
  String? get selectedSessionId => _session.id;

  @override
  SessionSummary? get selectedSession => _session;

  @override
  List<ChatMessage> get messages => _messages;

  @override
  Future<void> load() async {
    _loading = false;
    notifyListeners();
  }
}

class _ConversationOrderingWorkspaceController extends WorkspaceController {
  _ConversationOrderingWorkspaceController({
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

  static final SessionSummary _session = SessionSummary(
    id: 'ses_1',
    directory: '/workspace/demo',
    title: 'Conversation ordering',
    version: '1',
    updatedAt: DateTime.fromMillisecondsSinceEpoch(1710000004000),
  );

  static final List<ChatMessage> _messages = <ChatMessage>[
    ChatMessage(
      info: ChatMessageInfo(
        id: 'msg_user_1',
        role: 'user',
        sessionId: 'ses_1',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1710000001000),
        completedAt: DateTime.fromMillisecondsSinceEpoch(1710000001000),
      ),
      parts: const <ChatPart>[
        ChatPart(id: 'part_user_1', type: 'text', text: '테스트 메시지입니다.'),
      ],
    ),
    ChatMessage(
      info: ChatMessageInfo(
        id: 'msg_assistant_1',
        role: 'assistant',
        sessionId: 'ses_1',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1710000002000),
      ),
      parts: const <ChatPart>[
        ChatPart(
          id: 'part_reasoning_1',
          type: 'reasoning',
          text: 'Acknowledging needs',
        ),
        ChatPart(
          id: 'part_assistant_1',
          type: 'text',
          text: '테스트 메시지 확인했습니다. 필요한 작업을 보내주시면 바로 도와드릴게요.',
        ),
      ],
    ),
    ChatMessage(
      info: ChatMessageInfo(
        id: 'msg_user_2',
        role: 'user',
        sessionId: 'ses_1',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1710000003000),
        completedAt: DateTime.fromMillisecondsSinceEpoch(1710000003000),
      ),
      parts: const <ChatPart>[
        ChatPart(id: 'part_user_2', type: 'text', text: '테스트2 입니다.'),
      ],
    ),
    ChatMessage(
      info: ChatMessageInfo(
        id: 'msg_assistant_2',
        role: 'assistant',
        sessionId: 'ses_1',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1710000004000),
      ),
      parts: const <ChatPart>[
        ChatPart(
          id: 'part_assistant_2',
          type: 'text',
          text: '확인했습니다. 이어서 원하는 작업 말씀해 주세요.',
        ),
      ],
    ),
  ];

  bool _loading = true;

  @override
  bool get loading => _loading;

  @override
  ProjectTarget? get project => _projectTarget;

  @override
  List<ProjectTarget> get availableProjects => const <ProjectTarget>[
    _projectTarget,
  ];

  @override
  List<SessionSummary> get sessions => <SessionSummary>[_session];

  @override
  String? get selectedSessionId => _session.id;

  @override
  SessionSummary? get selectedSession => _session;

  @override
  List<ChatMessage> get messages => _messages;

  @override
  Future<void> load() async {
    _loading = false;
    notifyListeners();
  }
}

class _MixedContextWorkspaceController extends WorkspaceController {
  _MixedContextWorkspaceController({
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

  static final SessionSummary _session = SessionSummary(
    id: 'ses_1',
    directory: '/workspace/demo',
    title: 'Mixed context tools',
    version: '1',
    updatedAt: DateTime.fromMillisecondsSinceEpoch(1710000004000),
  );

  static final List<ChatMessage> _messages = <ChatMessage>[
    ChatMessage(
      info: ChatMessageInfo(
        id: 'msg_assistant_1',
        role: 'assistant',
        sessionId: 'ses_1',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1710000002000),
      ),
      parts: const <ChatPart>[
        ChatPart(
          id: 'part_read_1',
          type: 'tool',
          tool: 'read',
          metadata: <String, Object?>{
            'state': <String, Object?>{
              'status': 'completed',
              'input': <String, Object?>{
                'filePath': 'test/unit/job/daily-job.spec.ts',
                'offset': 261,
                'limit': 260,
              },
            },
          },
        ),
        ChatPart(
          id: 'part_grep_1',
          type: 'tool',
          tool: 'grep',
          metadata: <String, Object?>{
            'state': <String, Object?>{
              'status': 'completed',
              'input': <String, Object?>{
                'path': '/workspace/demo/src',
                'pattern': 'DISCORD_MESSAGE_ID',
                'include': '*.ts',
              },
            },
          },
        ),
      ],
    ),
  ];

  bool _loading = true;

  @override
  bool get loading => _loading;

  @override
  ProjectTarget? get project => _projectTarget;

  @override
  List<ProjectTarget> get availableProjects => const <ProjectTarget>[
    _projectTarget,
  ];

  @override
  List<SessionSummary> get sessions => <SessionSummary>[_session];

  @override
  String? get selectedSessionId => _session.id;

  @override
  SessionSummary? get selectedSession => _session;

  @override
  List<ChatMessage> get messages => _messages;

  @override
  Future<void> load() async {
    _loading = false;
    notifyListeners();
  }
}

class _CodeBlockWorkspaceController extends WorkspaceController {
  _CodeBlockWorkspaceController({
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

  static final SessionSummary _session = SessionSummary(
    id: 'ses_1',
    directory: '/workspace/demo',
    title: 'Code block copy',
    version: '1',
    updatedAt: DateTime.fromMillisecondsSinceEpoch(1710000004000),
  );

  static final List<ChatMessage> _messages = <ChatMessage>[
    ChatMessage(
      info: ChatMessageInfo(
        id: 'msg_assistant_code',
        role: 'assistant',
        sessionId: 'ses_1',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1710000002000),
      ),
      parts: const <ChatPart>[
        ChatPart(
          id: 'part_assistant_code',
          type: 'text',
          text:
              "Here is the sample:\n\n```dart\nvoid main() {\n  print('hello');\n}\n```",
        ),
      ],
    ),
  ];

  bool _loading = true;

  @override
  bool get loading => _loading;

  @override
  ProjectTarget? get project => _projectTarget;

  @override
  List<ProjectTarget> get availableProjects => const <ProjectTarget>[
    _projectTarget,
  ];

  @override
  List<SessionSummary> get sessions => <SessionSummary>[_session];

  @override
  String? get selectedSessionId => _session.id;

  @override
  SessionSummary? get selectedSession => _session;

  @override
  List<ChatMessage> get messages => _messages;

  @override
  Future<void> load() async {
    _loading = false;
    notifyListeners();
  }
}

class _UserMessageActionWorkspaceController extends WorkspaceController {
  _UserMessageActionWorkspaceController({
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

  static final ConfigSnapshot _configSnapshot = ConfigSnapshot(
    config: RawJsonDocument(<String, Object?>{}),
    providerConfig: RawJsonDocument(<String, Object?>{
      'providers': <Object?>[
        <String, Object?>{
          'id': 'openai',
          'name': 'OpenAI',
          'source': 'remote',
          'models': <String, Object?>{
            'openai/gpt-5.4': <String, Object?>{
              'id': 'gpt-5.4',
              'providerID': 'openai',
              'name': 'GPT-5.4',
            },
          },
        },
      ],
    }),
  );

  static final DateTime _timestamp = DateTime.fromMillisecondsSinceEpoch(
    1711421100000,
  );

  SessionSummary _session = SessionSummary(
    id: 'ses_1',
    directory: '/workspace/demo',
    title: 'User message actions',
    version: '1',
    updatedAt: _timestamp,
    createdAt: _timestamp,
  );

  static final List<ChatMessage> _messages = <ChatMessage>[
    ChatMessage(
      info: ChatMessageInfo(
        id: 'msg_user_hover',
        role: 'user',
        sessionId: 'ses_1',
        agent: 'Sisyphus',
        providerId: 'openai',
        modelId: 'gpt-5.4',
        createdAt: _timestamp,
        completedAt: _timestamp,
      ),
      parts: const <ChatPart>[
        ChatPart(
          id: 'part_user_hover',
          type: 'text',
          text: 'Please check the current progress.',
        ),
      ],
    ),
  ];

  bool _loading = true;
  int forkCount = 0;
  int revertCount = 0;
  String? lastForkMessageId;
  String? lastRevertMessageId;

  @override
  bool get loading => _loading;

  @override
  ProjectTarget? get project => _projectTarget;

  @override
  List<ProjectTarget> get availableProjects => const <ProjectTarget>[
    _projectTarget,
  ];

  @override
  List<SessionSummary> get sessions => <SessionSummary>[_session];

  @override
  String? get selectedSessionId => _session.id;

  @override
  SessionSummary? get selectedSession => _session;

  @override
  ConfigSnapshot? get configSnapshot => _configSnapshot;

  @override
  List<ChatMessage> get messages => _messages;

  @override
  Future<void> load() async {
    _loading = false;
    notifyListeners();
  }

  @override
  Future<SessionSummary?> forkSelectedSession({String? messageId}) async {
    forkCount += 1;
    lastForkMessageId = messageId;
    return _session;
  }

  @override
  Future<SessionSummary?> revertSelectedSession({
    required String messageId,
    String? partId,
  }) async {
    revertCount += 1;
    lastRevertMessageId = messageId;
    _session = SessionSummary(
      id: _session.id,
      directory: _session.directory,
      title: _session.title,
      version: _session.version,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(1711421160000),
      createdAt: _session.createdAt,
      revertMessageId: messageId,
    );
    notifyListeners();
    return _session;
  }
}

final List<ChatMessage> _processedPromptMessages = <ChatMessage>[
  ChatMessage(
    info: ChatMessageInfo(
      id: 'msg_local_prompt',
      role: 'user',
      sessionId: 'ses_1',
      createdAt: DateTime.fromMillisecondsSinceEpoch(1711421100000),
      completedAt: DateTime.fromMillisecondsSinceEpoch(1711421100000),
      metadata: const <String, Object?>{'_optimistic': true},
    ),
    parts: const <ChatPart>[
      ChatPart(
        id: 'part_local_prompt',
        type: 'text',
        text: 'Show me the branch list.',
      ),
    ],
  ),
  ChatMessage(
    info: ChatMessageInfo(
      id: 'msg_assistant_prompt',
      role: 'assistant',
      sessionId: 'ses_1',
      createdAt: DateTime.fromMillisecondsSinceEpoch(1711421101000),
    ),
    parts: const <ChatPart>[
      ChatPart(
        id: 'part_assistant_prompt',
        type: 'text',
        text:
            '[search-mode]\nMAXIMIZE SEARCH EFFORT.\n\nCollect the active branch names before responding.\n\nShow me the branch list.',
      ),
    ],
  ),
];

final List<ChatMessage> _ordinaryAssistantReplyMessages = <ChatMessage>[
  ChatMessage(
    info: ChatMessageInfo(
      id: 'msg_local_plain',
      role: 'user',
      sessionId: 'ses_1',
      createdAt: DateTime.fromMillisecondsSinceEpoch(1711421100000),
      completedAt: DateTime.fromMillisecondsSinceEpoch(1711421100000),
      metadata: const <String, Object?>{'_optimistic': true},
    ),
    parts: const <ChatPart>[
      ChatPart(
        id: 'part_local_plain',
        type: 'text',
        text: 'Show me the branch list.',
      ),
    ],
  ),
  ChatMessage(
    info: ChatMessageInfo(
      id: 'msg_assistant_plain',
      role: 'assistant',
      sessionId: 'ses_1',
      createdAt: DateTime.fromMillisecondsSinceEpoch(1711421101000),
    ),
    parts: const <ChatPart>[
      ChatPart(
        id: 'part_assistant_plain',
        type: 'text',
        text: 'I can check the branch list next.',
      ),
    ],
  ),
];

class _OptimisticTimelineWorkspaceController extends WorkspaceController {
  _OptimisticTimelineWorkspaceController({
    required super.profile,
    required super.directory,
    super.initialSessionId,
    required List<ChatMessage> messages,
  }) : _messages = messages;

  static const ProjectTarget _projectTarget = ProjectTarget(
    directory: '/workspace/demo',
    label: 'Demo',
    source: 'server',
    vcs: 'git',
    branch: 'main',
  );

  static final SessionSummary _session = SessionSummary(
    id: 'ses_1',
    directory: '/workspace/demo',
    title: 'Optimistic prompt visibility',
    version: '1',
    updatedAt: DateTime.fromMillisecondsSinceEpoch(1711421100000),
  );

  final List<ChatMessage> _messages;
  bool _loading = true;

  @override
  bool get loading => _loading;

  @override
  ProjectTarget? get project => _projectTarget;

  @override
  List<ProjectTarget> get availableProjects => const <ProjectTarget>[
    _projectTarget,
  ];

  @override
  List<SessionSummary> get sessions => <SessionSummary>[_session];

  @override
  String? get selectedSessionId => _session.id;

  @override
  SessionSummary? get selectedSession => _session;

  @override
  List<ChatMessage> get messages => _messages;

  @override
  Future<void> load() async {
    _loading = false;
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
