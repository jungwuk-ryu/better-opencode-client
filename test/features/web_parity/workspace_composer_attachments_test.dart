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
import 'package:opencode_mobile_remote/src/features/projects/project_models.dart';
import 'package:opencode_mobile_remote/src/features/terminal/pty_models.dart';
import 'package:opencode_mobile_remote/src/features/terminal/pty_service.dart';
import 'package:opencode_mobile_remote/src/features/web_parity/workspace_controller.dart';
import 'package:opencode_mobile_remote/src/features/web_parity/workspace_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('composer attaches files and submits them with the prompt', (
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
    final workspaceController = _AttachmentWorkspaceController(
      profile: profile,
      directory: '/workspace/demo',
    );
    final appController = _StaticAppController(
      profile: profile,
      workspaceController: workspaceController,
    );
    addTearDown(appController.dispose);
    const clipboardChannel = SystemChannels.platform;
    var clipboardText = 'paste fallback text';
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      clipboardChannel,
      (call) async {
        switch (call.method) {
          case 'Clipboard.getData':
            return <String, dynamic>{'text': clipboardText};
          case 'Clipboard.setData':
            final arguments = call.arguments;
            if (arguments is Map<Object?, Object?>) {
              clipboardText = (arguments['text'] as String?) ?? clipboardText;
            }
            return null;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        clipboardChannel,
        null,
      ),
    );

    await tester.pumpWidget(
      _WorkspaceRouteHarness(
        controller: appController,
        initialRoute: buildWorkspaceRoute(
          '/workspace/demo',
          sessionId: 'ses_1',
        ),
        attachmentPicker: () async => const <PromptAttachment>[
          PromptAttachment(
            id: 'att_1',
            filename: 'notes.txt',
            mime: 'text/plain',
            url: 'data:text/plain;base64,SGVsbG8=',
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    await tester.tap(
      find.byKey(const ValueKey<String>('composer-attach-button')),
    );
    await tester.pump();

    expect(find.text('notes.txt'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey<String>('composer-text-field')),
      'Review this note',
    );
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey<String>('composer-submit-button')),
    );
    await tester.pump();

    expect(workspaceController.submitPromptCalls, 1);
    expect(workspaceController.lastSubmittedPrompt, 'Review this note');
    expect(workspaceController.lastSubmittedAttachments, hasLength(1));
    expect(
      workspaceController.lastSubmittedAttachments.single.filename,
      'notes.txt',
    );
    expect(find.text('notes.txt'), findsNothing);
  });

  testWidgets('attachment-only drafts can be submitted', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final profile = ServerProfile(
      id: 'server',
      label: 'Mock',
      baseUrl: 'http://localhost:3000',
    );
    final workspaceController = _AttachmentWorkspaceController(
      profile: profile,
      directory: '/workspace/demo',
    );
    final appController = _StaticAppController(
      profile: profile,
      workspaceController: workspaceController,
    );
    addTearDown(appController.dispose);

    await tester.pumpWidget(
      _WorkspaceRouteHarness(
        controller: appController,
        initialRoute: buildWorkspaceRoute(
          '/workspace/demo',
          sessionId: 'ses_1',
        ),
        attachmentPicker: () async => const <PromptAttachment>[
          PromptAttachment(
            id: 'att_2',
            filename: 'diagram.png',
            mime: 'image/png',
            url:
                'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO7Z9QAAAABJRU5ErkJggg==',
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    await tester.tap(
      find.byKey(const ValueKey<String>('composer-attach-button')),
    );
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey<String>('composer-submit-button')),
    );
    await tester.pump();

    expect(workspaceController.submitPromptCalls, 1);
    expect(workspaceController.lastSubmittedPrompt, isEmpty);
    expect(workspaceController.lastSubmittedAttachments, hasLength(1));
    expect(
      workspaceController.lastSubmittedAttachments.single.filename,
      'diagram.png',
    );
  });

  testWidgets('pasting an image into the composer attaches it', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final profile = ServerProfile(
      id: 'server',
      label: 'Mock',
      baseUrl: 'http://localhost:3000',
    );
    final workspaceController = _AttachmentWorkspaceController(
      profile: profile,
      directory: '/workspace/demo',
    );
    final appController = _StaticAppController(
      profile: profile,
      workspaceController: workspaceController,
    );
    addTearDown(appController.dispose);

    await tester.pumpWidget(
      _WorkspaceRouteHarness(
        controller: appController,
        initialRoute: buildWorkspaceRoute(
          '/workspace/demo',
          sessionId: 'ses_1',
        ),
        attachmentPicker: () async => const <PromptAttachment>[],
        clipboardImageAttachmentLoader: () async => const PromptAttachment(
          id: 'att_pasted',
          filename: 'pasted-image.png',
          mime: 'image/png',
          url:
              'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO7Z9QAAAABJRU5ErkJggg==',
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    await tester.tap(find.byKey(const ValueKey<String>('composer-text-field')));
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(find.text('pasted-image.png'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('composer-submit-button')),
    );
    await tester.pump();

    expect(workspaceController.submitPromptCalls, 1);
    expect(workspaceController.lastSubmittedPrompt, isEmpty);
    expect(workspaceController.lastSubmittedAttachments, hasLength(1));
    expect(
      workspaceController.lastSubmittedAttachments.single.filename,
      'pasted-image.png',
    );
  });
}

class _WorkspaceRouteHarness extends StatelessWidget {
  const _WorkspaceRouteHarness({
    required this.controller,
    required this.initialRoute,
    required this.attachmentPicker,
    this.clipboardImageAttachmentLoader,
  });

  final WebParityAppController controller;
  final String initialRoute;
  final Future<List<PromptAttachment>> Function() attachmentPicker;
  final Future<PromptAttachment?> Function()? clipboardImageAttachmentLoader;

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
                    attachmentPicker: attachmentPicker,
                    clipboardImageAttachmentLoader:
                        clipboardImageAttachmentLoader,
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
    required this.workspaceController,
  }) : super(
         workspaceControllerFactory:
             ({required profile, required directory, initialSessionId}) {
               return workspaceController;
             },
       );

  final ServerProfile profile;
  final WorkspaceController workspaceController;

  @override
  ServerProfile? get selectedProfile => profile;
}

class _AttachmentWorkspaceController extends WorkspaceController {
  _AttachmentWorkspaceController({
    required super.profile,
    required super.directory,
  });

  static const ProjectTarget _project = ProjectTarget(
    directory: '/workspace/demo',
    label: 'Demo',
    source: 'server',
    vcs: 'git',
    branch: 'main',
  );

  static final SessionSummary _session = SessionSummary(
    id: 'ses_1',
    directory: '/workspace/demo',
    title: 'Attachment test',
    version: '1',
    updatedAt: DateTime.fromMillisecondsSinceEpoch(1710000001000),
  );

  bool _loading = true;
  int submitPromptCalls = 0;
  String lastSubmittedPrompt = '';
  List<PromptAttachment> lastSubmittedAttachments = const <PromptAttachment>[];

  @override
  bool get loading => _loading;

  @override
  ProjectTarget? get project => _project;

  @override
  List<ProjectTarget> get availableProjects => const <ProjectTarget>[_project];

  @override
  List<SessionSummary> get sessions => <SessionSummary>[_session];

  @override
  String? get selectedSessionId => _session.id;

  @override
  SessionSummary? get selectedSession => _session;

  @override
  List<ChatMessage> get messages => const <ChatMessage>[
    ChatMessage(
      info: ChatMessageInfo(id: 'msg_1', role: 'assistant', sessionId: 'ses_1'),
      parts: <ChatPart>[
        ChatPart(id: 'prt_1', type: 'text', text: 'Ready for attachments.'),
      ],
    ),
  ];

  @override
  Future<void> load() async {
    _loading = false;
    notifyListeners();
  }

  @override
  Future<String?> submitPrompt(
    String prompt, {
    List<PromptAttachment> attachments = const <PromptAttachment>[],
    WorkspacePromptDispatchMode? mode,
  }) async {
    submitPromptCalls += 1;
    lastSubmittedPrompt = prompt;
    lastSubmittedAttachments = attachments;
    return selectedSessionId;
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
