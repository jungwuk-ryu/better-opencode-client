import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:better_opencode_client/l10n/app_localizations.dart';
import 'package:better_opencode_client/src/core/connection/connection_models.dart';
import 'package:better_opencode_client/src/core/network/event_stream_service.dart';
import 'package:better_opencode_client/src/core/spec/capability_registry.dart';
import 'package:better_opencode_client/src/core/spec/raw_json_document.dart';
import 'package:better_opencode_client/src/design_system/app_theme.dart';
import 'package:better_opencode_client/src/features/chat/chat_models.dart';
import 'package:better_opencode_client/src/features/chat/prompt_attachment_models.dart';
import 'package:better_opencode_client/src/features/chat/chat_service.dart';
import 'package:better_opencode_client/src/features/chat/session_action_service.dart';
import 'package:better_opencode_client/src/core/spec/probe_snapshot.dart';
import 'package:better_opencode_client/src/features/files/file_browser_service.dart';
import 'package:better_opencode_client/src/features/files/file_models.dart';
import 'package:better_opencode_client/src/features/projects/project_models.dart';
import 'package:better_opencode_client/src/features/requests/pending_request_notification_service.dart';
import 'package:better_opencode_client/src/features/requests/pending_request_sound_service.dart';
import 'package:better_opencode_client/src/features/requests/request_models.dart';
import 'package:better_opencode_client/src/features/requests/request_service.dart';
import 'package:better_opencode_client/src/features/shell/opencode_shell_screen.dart';
import 'package:better_opencode_client/src/features/settings/config_service.dart';
import 'package:better_opencode_client/src/features/settings/integration_status_service.dart';
import 'package:better_opencode_client/src/features/terminal/terminal_service.dart';
import 'package:better_opencode_client/src/features/tools/todo_models.dart';
import 'package:better_opencode_client/src/features/tools/todo_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../test_helpers/responsive_viewports.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  const profile = ServerProfile(
    id: 'server-1',
    label: 'Mock server',
    baseUrl: 'http://127.0.0.1:8787',
  );
  const project = ProjectTarget(
    directory: '/workspace/demo',
    label: 'Demo',
    source: 'server',
    vcs: 'git',
    branch: 'main',
  );
  final capabilities = CapabilityRegistry.fromSnapshot(
    ProbeSnapshot(
      name: 'test',
      version: '1.0.0',
      paths: const <String>{
        '/project',
        '/project/current',
        '/session',
        '/session/status',
        '/session/{sessionID}/todo',
        '/file',
        '/file/content',
        '/file/status',
        '/find/file',
        '/find/symbol',
        '/session/{sessionID}/shell',
        '/config',
        '/config/providers',
        '/question',
        '/permission',
        '/session/{sessionID}/share',
        '/session/{sessionID}/fork',
        '/session/{sessionID}/summarize',
        '/session/{sessionID}/revert',
        '/session/{sessionID}/init',
        '/provider/{providerID}/oauth/authorize',
        '/mcp/{name}/auth',
      },
      endpoints: const <String, ProbeEndpointResult>{},
    ),
  );
  final eventCapabilities = CapabilityRegistry.fromSnapshot(
    ProbeSnapshot(
      name: 'test-events',
      version: '1.0.0',
      paths: const <String>{
        '/project',
        '/project/current',
        '/session',
        '/session/status',
        '/session/{sessionID}/todo',
        '/file',
        '/file/content',
        '/file/status',
        '/find/file',
        '/find/symbol',
        '/session/{sessionID}/shell',
        '/config',
        '/config/providers',
        '/question',
        '/permission',
        '/session/{sessionID}/share',
        '/session/{sessionID}/fork',
        '/session/{sessionID}/summarize',
        '/session/{sessionID}/revert',
        '/session/{sessionID}/init',
        '/provider/{providerID}/oauth/authorize',
        '/mcp/{name}/auth',
        '/event',
      },
      endpoints: const <String, ProbeEndpointResult>{},
    ),
  );
  final minimalCapabilities = CapabilityRegistry.fromSnapshot(
    ProbeSnapshot(
      name: 'minimal',
      version: '1.0.0',
      paths: const <String>{'/project', '/project/current'},
      endpoints: const <String, ProbeEndpointResult>{},
    ),
  );
  final sessionCapabilitiesWithoutTodos = CapabilityRegistry.fromSnapshot(
    ProbeSnapshot(
      name: 'sessions-no-todos',
      version: '1.0.0',
      paths: const <String>{
        '/project',
        '/project/current',
        '/session',
        '/session/status',
      },
      endpoints: const <String, ProbeEndpointResult>{},
    ),
  );

  Future<void> pumpShellWithCapabilities(
    WidgetTester tester, {
    required Size size,
    required CapabilityRegistry capabilitiesToUse,
    ServerProfile profileToUse = profile,
    ProjectTarget projectToUse = project,
    List<ProjectTarget> availableProjects = const <ProjectTarget>[],
    ValueChanged<ProjectTarget>? onSelectProject,
    ChatService? chatService,
    TodoService? todoService,
    FileBrowserService? fileBrowserService,
    RequestService? requestService,
    ConfigService? configService,
    IntegrationStatusService? integrationStatusService,
    EventStreamService? eventStreamService,
    TerminalService? terminalService,
    SessionActionService? sessionActionService,
    PendingRequestNotificationService? pendingRequestNotificationService,
    PendingRequestSoundService? pendingRequestSoundService,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _buildShell(
        capabilitiesToUse: capabilitiesToUse,
        profileToUse: profileToUse,
        projectToUse: projectToUse,
        availableProjects: availableProjects,
        onSelectProject: onSelectProject,
        chatService: chatService,
        todoService: todoService,
        fileBrowserService: fileBrowserService,
        requestService: requestService,
        configService: configService,
        integrationStatusService: integrationStatusService,
        eventStreamService: eventStreamService,
        terminalService: terminalService,
        sessionActionService: sessionActionService,
        pendingRequestNotificationService: pendingRequestNotificationService,
        pendingRequestSoundService: pendingRequestSoundService,
      ),
    );
    await _pumpShellFrames(tester);
  }

  Future<void> pumpShell(WidgetTester tester, {required Size size}) async {
    await pumpShellWithCapabilities(
      tester,
      size: size,
      capabilitiesToUse: capabilities,
    );
  }

  testWidgets('shell renders across the responsive viewport matrix', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final viewport in kResponsiveShellViewports) {
      await pumpShell(tester, size: viewport.size);

      final exception = tester.takeException();
      expect(
        exception,
        isNull,
        reason: 'shell layout failed on ${viewport.name}',
      );
      expect(
        find.byType(OpenCodeShellScreen),
        findsOneWidget,
        reason: viewport.name,
      );
      expect(find.text('Chat'), findsAtLeastNWidgets(1), reason: viewport.name);
      expect(
        find.text('Settings'),
        findsAtLeastNWidgets(1),
        reason: viewport.name,
      );
    }
  });

  testWidgets('desktop shell exposes stable primary destinations', (
    tester,
  ) async {
    await pumpShell(tester, size: const Size(1440, 1000));

    expect(find.text('Sessions'), findsAtLeastNWidgets(1));
    expect(find.text('Chat'), findsAtLeastNWidgets(1));
    expect(find.text('Context'), findsAtLeastNWidgets(1));
    expect(find.text('Settings'), findsAtLeastNWidgets(1));
  });

  testWidgets('tablet portrait shell exposes stable primary destinations', (
    tester,
  ) async {
    await pumpShell(tester, size: const Size(820, 1180));

    expect(find.text('Sessions'), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('Context'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('mobile shell keeps chat canvas visible', (tester) async {
    await pumpShell(tester, size: const Size(430, 932));

    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('Conversation'), findsOneWidget);
    expect(find.text('Back to servers'), findsOneWidget);
  });

  testWidgets(
    'shell summarize action sends compact requests for empty sessions',
    (tester) async {
      final sessionActionService = _RecordingSessionActionService();
      final chatService = _ControlledChatService(
        bundlesByScopeKey: <String, ChatSessionBundle>{
          _scopeKeyFor(profile, project): ChatSessionBundle(
            sessions: <SessionSummary>[
              _testSession(
                'session-1',
                'First session',
                directory: project.directory,
              ),
            ],
            statuses: const <String, SessionStatusSummary>{
              'session-1': SessionStatusSummary(type: 'idle'),
            },
            messages: const <ChatMessage>[],
            selectedSessionId: 'session-1',
          ),
        },
      );

      await pumpShellWithCapabilities(
        tester,
        size: const Size(1440, 1600),
        capabilitiesToUse: capabilities,
        chatService: chatService,
        todoService: _RecordingTodoService(),
        fileBrowserService: _ControlledFileBrowserService.empty(),
        requestService: _ControlledRequestService.empty(),
        configService: _ControlledConfigService.empty(),
        integrationStatusService: _ControlledIntegrationStatusService.empty(),
        sessionActionService: sessionActionService,
      );

      await tester.tap(find.text('Sessions').first);
      await _pumpShellFrames(tester);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Summarize').first);
      await _pumpShellFrames(tester);

      expect(sessionActionService.summarizeCalls, 1);
      expect(sessionActionService.lastSummarizedSessionId, 'session-1');
      expect(sessionActionService.lastSummarizedProviderId, isNull);
      expect(sessionActionService.lastSummarizedModelId, isNull);
    },
  );

  testWidgets(
    'shell composer routes exact /compact prompts through session compaction',
    (tester) async {
      final sessionActionService = _RecordingSessionActionService();
      final configService = _ControlledConfigService(
        snapshotsByScopeKey: <String, ConfigSnapshot>{
          _scopeKeyFor(profile, project): _configSnapshotWithModelChoices(),
        },
      );
      final chatService = _ControlledChatService(
        bundlesByScopeKey: <String, ChatSessionBundle>{
          _scopeKeyFor(profile, project): ChatSessionBundle(
            sessions: <SessionSummary>[
              _testSession(
                'session-1',
                'First session',
                directory: project.directory,
              ),
            ],
            statuses: const <String, SessionStatusSummary>{
              'session-1': SessionStatusSummary(type: 'idle'),
            },
            messages: const <ChatMessage>[],
            selectedSessionId: 'session-1',
          ),
        },
      );

      await pumpShellWithCapabilities(
        tester,
        size: const Size(1440, 1600),
        capabilitiesToUse: capabilities,
        chatService: chatService,
        todoService: _RecordingTodoService(),
        fileBrowserService: _ControlledFileBrowserService.empty(),
        requestService: _ControlledRequestService.empty(),
        configService: configService,
        integrationStatusService: _ControlledIntegrationStatusService.empty(),
        sessionActionService: sessionActionService,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('composer-model-select')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('anthropic / claude-sonnet-4.5').last);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '/compact');
      await tester.tap(find.text('Send'));
      await _pumpShellFrames(tester);

      expect(sessionActionService.summarizeCalls, 1);
      expect(sessionActionService.lastSummarizedSessionId, 'session-1');
      expect(sessionActionService.lastSummarizedProviderId, 'anthropic');
      expect(sessionActionService.lastSummarizedModelId, 'claude-sonnet-4.5');
      expect(chatService.sentPrompts, isEmpty);
    },
  );

  testWidgets('shell renders compaction parts as timeline dividers', (
    tester,
  ) async {
    final chatService = _ControlledChatService(
      bundlesByScopeKey: <String, ChatSessionBundle>{
        _scopeKeyFor(profile, project): ChatSessionBundle(
          sessions: <SessionSummary>[
            _testSession(
              'session-1',
              'First session',
              directory: project.directory,
            ),
          ],
          statuses: const <String, SessionStatusSummary>{
            'session-1': SessionStatusSummary(type: 'idle'),
          },
          messages: const <ChatMessage>[
            ChatMessage(
              info: ChatMessageInfo(
                id: 'assistant-compaction-message',
                role: 'assistant',
                sessionId: 'session-1',
              ),
              parts: <ChatPart>[
                ChatPart(id: 'compaction-part', type: 'compaction'),
              ],
            ),
          ],
          selectedSessionId: 'session-1',
        ),
      },
    );

    await pumpShellWithCapabilities(
      tester,
      size: const Size(1440, 1600),
      capabilitiesToUse: capabilities,
      chatService: chatService,
      todoService: _RecordingTodoService(),
      fileBrowserService: _ControlledFileBrowserService.empty(),
      requestService: _ControlledRequestService.empty(),
      configService: _ControlledConfigService.empty(),
      integrationStatusService: _ControlledIntegrationStatusService.empty(),
    );

    expect(
      find.byKey(
        const ValueKey<String>('chat-part-compaction-compaction-part'),
      ),
      findsOneWidget,
    );
    expect(find.text('Session compacted'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('chat-part-activity-compaction-part')),
      findsNothing,
    );
    expect(
      find.byKey(
        const ValueKey<String>('chat-part-bubble-assistant-compaction-message'),
      ),
      findsNothing,
    );
  });

  testWidgets(
    'shell composer refuses exact /compact prompts without an existing session',
    (tester) async {
      final sessionActionService = _RecordingSessionActionService();
      final chatService = _ControlledChatService(
        bundlesByScopeKey: <String, ChatSessionBundle>{
          _scopeKeyFor(profile, project): const ChatSessionBundle(
            sessions: <SessionSummary>[],
            statuses: <String, SessionStatusSummary>{},
            messages: <ChatMessage>[],
            selectedSessionId: null,
          ),
        },
      );

      await pumpShellWithCapabilities(
        tester,
        size: const Size(1440, 1600),
        capabilitiesToUse: capabilities,
        chatService: chatService,
        todoService: _RecordingTodoService(),
        fileBrowserService: _ControlledFileBrowserService.empty(),
        requestService: _ControlledRequestService.empty(),
        configService: _ControlledConfigService.empty(),
        integrationStatusService: _ControlledIntegrationStatusService.empty(),
        sessionActionService: sessionActionService,
      );

      await tester.enterText(find.byType(TextField).first, '/compact');
      await tester.tap(find.widgetWithIcon(ElevatedButton, Icons.send_rounded));
      await _pumpShellFrames(tester);

      expect(chatService.createSessionCalls, 0);
      expect(sessionActionService.summarizeCalls, 0);
      expect(find.text('Select a session before compacting.'), findsOneWidget);
    },
  );

  testWidgets(
    'shell summarize action ignores stale transcript models during session switches',
    (tester) async {
      final secondSessionGate = Completer<void>();
      addTearDown(() {
        if (!secondSessionGate.isCompleted) {
          secondSessionGate.complete();
        }
      });
      final sessionActionService = _RecordingSessionActionService();
      final chatService = _ControlledChatService(
        bundlesByScopeKey: <String, ChatSessionBundle>{
          _scopeKeyFor(profile, project): ChatSessionBundle(
            sessions: <SessionSummary>[
              _testSession(
                'session-1',
                'First session',
                directory: project.directory,
              ),
              _testSession(
                'session-2',
                'Second session',
                directory: project.directory,
              ),
            ],
            statuses: const <String, SessionStatusSummary>{
              'session-1': SessionStatusSummary(type: 'idle'),
              'session-2': SessionStatusSummary(type: 'idle'),
            },
            messages: <ChatMessage>[
              ChatMessage(
                info: ChatMessageInfo(
                  id: 'msg-session-1',
                  role: 'assistant',
                  sessionId: 'session-1',
                  providerId: 'openai',
                  modelId: 'gpt-5',
                ),
                parts: <ChatPart>[
                  ChatPart(
                    id: 'part-session-1',
                    type: 'text',
                    text: 'Existing summary',
                  ),
                ],
              ),
            ],
            selectedSessionId: 'session-1',
          ),
        },
        messagesBySessionId: const <String, List<ChatMessage>>{
          'session-2': <ChatMessage>[],
        },
        messageGateBySessionId: <String, Completer<void>>{
          'session-2': secondSessionGate,
        },
      );

      await pumpShellWithCapabilities(
        tester,
        size: const Size(1440, 1600),
        capabilitiesToUse: capabilities,
        chatService: chatService,
        todoService: _RecordingTodoService(),
        fileBrowserService: _ControlledFileBrowserService.empty(),
        requestService: _ControlledRequestService.empty(),
        configService: _ControlledConfigService.empty(),
        integrationStatusService: _ControlledIntegrationStatusService.empty(),
        sessionActionService: sessionActionService,
      );

      await tester.tap(find.text('Sessions').first);
      await _pumpShellFrames(tester);
      await tester.tap(find.text('Second session').first);
      await tester.pump();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Summarize').first);
      await _pumpShellFrames(tester);

      expect(sessionActionService.summarizeCalls, 1);
      expect(sessionActionService.lastSummarizedSessionId, 'session-2');
      expect(sessionActionService.lastSummarizedProviderId, isNull);
      expect(sessionActionService.lastSummarizedModelId, isNull);

      secondSessionGate.complete();
      await _pumpShellFrames(tester);
    },
  );

  testWidgets(
    'shell summarize action preserves loaded session model metadata for compatibility',
    (tester) async {
      final sessionActionService = _RecordingSessionActionService();
      final chatService = _ControlledChatService(
        bundlesByScopeKey: <String, ChatSessionBundle>{
          _scopeKeyFor(profile, project): ChatSessionBundle(
            sessions: <SessionSummary>[
              _testSession(
                'session-1',
                'First session',
                directory: project.directory,
              ),
            ],
            statuses: const <String, SessionStatusSummary>{
              'session-1': SessionStatusSummary(type: 'idle'),
            },
            messages: <ChatMessage>[
              ChatMessage(
                info: ChatMessageInfo(
                  id: 'msg-session-1',
                  role: 'assistant',
                  sessionId: 'session-1',
                  providerId: 'openai',
                  modelId: 'gpt-5',
                ),
                parts: <ChatPart>[
                  ChatPart(
                    id: 'part-session-1',
                    type: 'text',
                    text: 'Existing summary',
                  ),
                ],
              ),
            ],
            selectedSessionId: 'session-1',
          ),
        },
      );

      await pumpShellWithCapabilities(
        tester,
        size: const Size(1440, 1600),
        capabilitiesToUse: capabilities,
        chatService: chatService,
        todoService: _RecordingTodoService(),
        fileBrowserService: _ControlledFileBrowserService.empty(),
        requestService: _ControlledRequestService.empty(),
        configService: _ControlledConfigService.empty(),
        integrationStatusService: _ControlledIntegrationStatusService.empty(),
        sessionActionService: sessionActionService,
      );

      await tester.tap(find.text('Sessions').first);
      await _pumpShellFrames(tester);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Summarize').first);
      await _pumpShellFrames(tester);

      expect(sessionActionService.summarizeCalls, 1);
      expect(sessionActionService.lastSummarizedSessionId, 'session-1');
      expect(sessionActionService.lastSummarizedProviderId, 'openai');
      expect(sessionActionService.lastSummarizedModelId, 'gpt-5');
    },
  );

  testWidgets(
    'shell sends an OS notification when a question request arrives',
    (tester) async {
      final eventStreamService = _ControlledEventStreamService();
      final notificationService = _FakePendingRequestNotificationService();
      final chatService = _ControlledChatService(
        bundlesByScopeKey: <String, ChatSessionBundle>{
          _scopeKeyFor(profile, project): ChatSessionBundle(
            sessions: <SessionSummary>[
              _testSession(
                'session-1',
                'First session',
                directory: project.directory,
              ),
            ],
            statuses: const <String, SessionStatusSummary>{
              'session-1': SessionStatusSummary(type: 'idle'),
            },
            messages: const <ChatMessage>[],
            selectedSessionId: 'session-1',
          ),
        },
      );

      await pumpShellWithCapabilities(
        tester,
        size: const Size(1440, 1600),
        capabilitiesToUse: eventCapabilities,
        chatService: chatService,
        todoService: _RecordingTodoService(),
        fileBrowserService: _ControlledFileBrowserService.empty(),
        requestService: _ControlledRequestService.empty(),
        configService: _ControlledConfigService.empty(),
        integrationStatusService: _ControlledIntegrationStatusService.empty(),
        terminalService: _ControlledTerminalService(),
        eventStreamService: eventStreamService,
        pendingRequestNotificationService: notificationService,
      );
      expect(
        eventStreamService.connectedScopeKeys,
        contains(_scopeKeyFor(profile, project)),
      );

      eventStreamService.emitToScope(
        profile,
        project,
        const EventEnvelope(
          type: 'question.asked',
          properties: <String, Object?>{
            'id': 'req_1',
            'sessionID': 'session-1',
            'questions': <Object?>[
              <String, Object?>{
                'header': 'Execution',
                'question': 'Which execution path should I use?',
                'multiple': false,
                'options': <Object?>[],
              },
            ],
          },
        ),
      );
      await _pumpShellFrames(tester);

      expect(notificationService.notifications, hasLength(1));
      expect(
        notificationService.notifications.single.title,
        'Question requested',
      );
      expect(
        notificationService.notifications.single.body,
        contains('Execution'),
      );
    },
  );

  testWidgets('shell plays a sound when a permission request arrives', (
    tester,
  ) async {
    final eventStreamService = _ControlledEventStreamService();
    final notificationService = _FakePendingRequestNotificationService();
    final soundService = _FakePendingRequestSoundService();
    final chatService = _ControlledChatService(
      bundlesByScopeKey: <String, ChatSessionBundle>{
        _scopeKeyFor(profile, project): ChatSessionBundle(
          sessions: <SessionSummary>[
            _testSession(
              'session-1',
              'First session',
              directory: project.directory,
            ),
          ],
          statuses: const <String, SessionStatusSummary>{
            'session-1': SessionStatusSummary(type: 'idle'),
          },
          messages: const <ChatMessage>[],
          selectedSessionId: 'session-1',
        ),
      },
    );

    await pumpShellWithCapabilities(
      tester,
      size: const Size(1440, 1600),
      capabilitiesToUse: eventCapabilities,
      chatService: chatService,
      todoService: _RecordingTodoService(),
      fileBrowserService: _ControlledFileBrowserService.empty(),
      requestService: _ControlledRequestService.empty(),
      configService: _ControlledConfigService.empty(),
      integrationStatusService: _ControlledIntegrationStatusService.empty(),
      terminalService: _ControlledTerminalService(),
      eventStreamService: eventStreamService,
      pendingRequestNotificationService: notificationService,
      pendingRequestSoundService: soundService,
    );

    eventStreamService.emitToScope(
      profile,
      project,
      const EventEnvelope(
        type: 'permission.asked',
        properties: <String, Object?>{
          'id': 'per_1',
          'sessionID': 'session-1',
          'permission': 'bash',
          'patterns': <Object?>['npm test'],
        },
      ),
    );
    await _pumpShellFrames(tester);

    expect(soundService.playedKeys, hasLength(1));
    expect(soundService.playedKeys.single, contains('permission:per_1'));
  });

  testWidgets('idle event streams do not trigger periodic session reloads', (
    tester,
  ) async {
    final eventStreamService = _ControlledEventStreamService();
    final chatService = _ControlledChatService(
      bundlesByScopeKey: <String, ChatSessionBundle>{
        _scopeKeyFor(profile, project): ChatSessionBundle(
          sessions: <SessionSummary>[
            _testSession(
              'demo-session',
              'Demo session',
              directory: project.directory,
            ),
          ],
          statuses: const <String, SessionStatusSummary>{
            'demo-session': SessionStatusSummary(type: 'idle'),
          },
          messages: <ChatMessage>[
            _testMessage('demo-session', text: 'Demo message'),
          ],
          selectedSessionId: 'demo-session',
        ),
      },
    );

    await pumpShellWithCapabilities(
      tester,
      size: const Size(1440, 1600),
      capabilitiesToUse: eventCapabilities,
      chatService: chatService,
      todoService: _RecordingTodoService(),
      fileBrowserService: _ControlledFileBrowserService.empty(),
      requestService: _ControlledRequestService.empty(),
      configService: _ControlledConfigService.empty(),
      integrationStatusService: _ControlledIntegrationStatusService.empty(),
      terminalService: _ControlledTerminalService(),
      eventStreamService: eventStreamService,
    );

    expect(
      eventStreamService.connectedScopeKeys,
      contains(_scopeKeyFor(profile, project)),
    );
    expect(
      chatService.fetchBundleCountByScopeKey[_scopeKeyFor(profile, project)],
      1,
    );
    expect(find.text('Demo message'), findsAtLeastNWidgets(1));

    await tester.pump(const Duration(seconds: 12));
    await tester.pump();

    expect(eventStreamService.disconnectCount, 0);
    expect(
      chatService.fetchBundleCountByScopeKey[_scopeKeyFor(profile, project)],
      1,
    );
    expect(find.text('Demo message'), findsAtLeastNWidgets(1));
    expect(
      find.byKey(const ValueKey<String>('chat-loading-demo-session')),
      findsNothing,
    );
  });

  testWidgets('mobile shell opens a drawer with project and session picks', (
    tester,
  ) async {
    ProjectTarget? selectedProject;

    await pumpShellWithCapabilities(
      tester,
      size: const Size(430, 932),
      capabilitiesToUse: capabilities,
      availableProjects: const <ProjectTarget>[
        project,
        ProjectTarget(
          directory: '/workspace/sidequest',
          label: 'Sidequest',
          source: 'server',
          vcs: 'git',
          branch: 'develop',
        ),
      ],
      onSelectProject: (project) {
        selectedProject = project;
      },
    );

    await tester.tap(find.byIcon(Icons.menu_open_rounded));
    await _pumpShellFrames(tester);

    expect(find.text('Project and sessions'), findsOneWidget);
    expect(find.text('Sidequest'), findsOneWidget);

    await tester.tap(find.text('Sidequest'));
    await _pumpShellFrames(tester);

    expect(selectedProject?.directory, '/workspace/sidequest');
  });

  testWidgets('chat timeline opens scrolled to the newest message', (
    tester,
  ) async {
    final chatService = _ControlledChatService(
      bundlesByScopeKey: <String, ChatSessionBundle>{
        _scopeKeyFor(profile, project): ChatSessionBundle(
          sessions: <SessionSummary>[
            _testSession(
              'session-1',
              'First session',
              directory: project.directory,
            ),
          ],
          statuses: const <String, SessionStatusSummary>{},
          messages: _manyMessages('session-1', 40),
          selectedSessionId: 'session-1',
        ),
      },
    );

    await pumpShellWithCapabilities(
      tester,
      size: const Size(430, 932),
      capabilitiesToUse: capabilities,
      chatService: chatService,
      todoService: _RecordingTodoService(),
    );

    final position = tester
        .widget<ListView>(
          find.byKey(const ValueKey<String>('chat-message-list')),
        )
        .controller!
        .position;

    expect(position.maxScrollExtent, greaterThan(0));
    expect(position.pixels, closeTo(position.maxScrollExtent, 96));
  });

  testWidgets('chat timeline auto-scrolls when new messages arrive at bottom', (
    tester,
  ) async {
    final initialService = _ControlledChatService(
      bundlesByScopeKey: <String, ChatSessionBundle>{
        _scopeKeyFor(profile, project): ChatSessionBundle(
          sessions: <SessionSummary>[
            _testSession(
              'session-1',
              'First session',
              directory: project.directory,
            ),
          ],
          statuses: const <String, SessionStatusSummary>{},
          messages: _manyMessages('session-1', 24),
          selectedSessionId: 'session-1',
        ),
      },
    );
    final updatedService = _ControlledChatService(
      bundlesByScopeKey: <String, ChatSessionBundle>{
        _scopeKeyFor(profile, project): ChatSessionBundle(
          sessions: <SessionSummary>[
            _testSession(
              'session-1',
              'First session',
              directory: project.directory,
            ),
          ],
          statuses: const <String, SessionStatusSummary>{},
          messages: _manyMessages('session-1', 36),
          selectedSessionId: 'session-1',
        ),
      },
    );

    await pumpShellWithCapabilities(
      tester,
      size: const Size(430, 932),
      capabilitiesToUse: capabilities,
      chatService: initialService,
      todoService: _RecordingTodoService(),
    );

    final initialPosition = tester
        .widget<ListView>(
          find.byKey(const ValueKey<String>('chat-message-list')),
        )
        .controller!
        .position;
    final initialExtent = initialPosition.maxScrollExtent;

    await tester.pumpWidget(
      _buildShell(
        capabilitiesToUse: capabilities,
        profileToUse: profile,
        projectToUse: project,
        chatService: updatedService,
        todoService: _RecordingTodoService(),
      ),
    );
    await _pumpShellFrames(tester);

    final updatedPosition = tester
        .widget<ListView>(
          find.byKey(const ValueKey<String>('chat-message-list')),
        )
        .controller!
        .position;

    expect(updatedPosition.maxScrollExtent, greaterThan(initialExtent));
    expect(
      updatedPosition.pixels,
      closeTo(updatedPosition.maxScrollExtent, 96),
    );
  });

  testWidgets(
    'chat timeline does not fight an active manual scroll when messages update',
    (tester) async {
      final initialService = _ControlledChatService(
        bundlesByScopeKey: <String, ChatSessionBundle>{
          _scopeKeyFor(profile, project): ChatSessionBundle(
            sessions: <SessionSummary>[
              _testSession(
                'session-1',
                'First session',
                directory: project.directory,
              ),
            ],
            statuses: const <String, SessionStatusSummary>{},
            messages: _manyMessages('session-1', 24),
            selectedSessionId: 'session-1',
          ),
        },
      );
      final updatedService = _ControlledChatService(
        bundlesByScopeKey: <String, ChatSessionBundle>{
          _scopeKeyFor(profile, project): ChatSessionBundle(
            sessions: <SessionSummary>[
              _testSession(
                'session-1',
                'First session',
                directory: project.directory,
              ),
            ],
            statuses: const <String, SessionStatusSummary>{},
            messages: _manyMessages('session-1', 36),
            selectedSessionId: 'session-1',
          ),
        },
      );

      await pumpShellWithCapabilities(
        tester,
        size: const Size(430, 932),
        capabilitiesToUse: capabilities,
        chatService: initialService,
        todoService: _RecordingTodoService(),
      );

      final listFinder = find.byKey(
        const ValueKey<String>('chat-message-list'),
      );
      final gesture = await tester.startGesture(tester.getCenter(listFinder));
      await gesture.moveBy(const Offset(0, 220));
      await tester.pump();

      final scrolledPosition = tester
          .widget<ListView>(listFinder)
          .controller!
          .position;
      final scrolledPixels = scrolledPosition.pixels;

      await tester.pumpWidget(
        _buildShell(
          capabilitiesToUse: capabilities,
          profileToUse: profile,
          projectToUse: project,
          chatService: updatedService,
          todoService: _RecordingTodoService(),
        ),
      );
      await _pumpShellFrames(tester);

      final updatedPosition = tester
          .widget<ListView>(listFinder)
          .controller!
          .position;

      expect(updatedPosition.maxScrollExtent, greaterThan(scrolledPixels));
      expect(
        updatedPosition.pixels,
        lessThan(updatedPosition.maxScrollExtent - 72),
      );
      expect(updatedPosition.pixels, closeTo(scrolledPixels, 24));

      await gesture.up();
      await _pumpShellFrames(tester);
    },
  );

  testWidgets(
    'chat timeline does not auto-scroll when the user is reading older messages',
    (tester) async {
      final initialService = _ControlledChatService(
        bundlesByScopeKey: <String, ChatSessionBundle>{
          _scopeKeyFor(profile, project): ChatSessionBundle(
            sessions: <SessionSummary>[
              _testSession(
                'session-1',
                'First session',
                directory: project.directory,
              ),
            ],
            statuses: const <String, SessionStatusSummary>{},
            messages: _manyMessages('session-1', 24),
            selectedSessionId: 'session-1',
          ),
        },
      );
      final updatedService = _ControlledChatService(
        bundlesByScopeKey: <String, ChatSessionBundle>{
          _scopeKeyFor(profile, project): ChatSessionBundle(
            sessions: <SessionSummary>[
              _testSession(
                'session-1',
                'First session',
                directory: project.directory,
              ),
            ],
            statuses: const <String, SessionStatusSummary>{},
            messages: _manyMessages('session-1', 36),
            selectedSessionId: 'session-1',
          ),
        },
      );

      await pumpShellWithCapabilities(
        tester,
        size: const Size(430, 932),
        capabilitiesToUse: capabilities,
        chatService: initialService,
        todoService: _RecordingTodoService(),
      );

      final listFinder = find.byKey(
        const ValueKey<String>('chat-message-list'),
      );
      await tester.drag(listFinder, const Offset(0, 240));
      await _pumpShellFrames(tester);

      final scrolledPosition = tester
          .widget<ListView>(listFinder)
          .controller!
          .position;
      final scrolledPixels = scrolledPosition.pixels;

      await tester.pumpWidget(
        _buildShell(
          capabilitiesToUse: capabilities,
          profileToUse: profile,
          projectToUse: project,
          chatService: updatedService,
          todoService: _RecordingTodoService(),
        ),
      );
      await _pumpShellFrames(tester);

      final updatedPosition = tester
          .widget<ListView>(listFinder)
          .controller!
          .position;

      expect(updatedPosition.maxScrollExtent, greaterThan(scrolledPixels));
      expect(
        updatedPosition.pixels,
        lessThan(updatedPosition.maxScrollExtent - 72),
      );
      expect(updatedPosition.pixels, closeTo(scrolledPixels, 24));
    },
  );

  testWidgets('minimal capabilities hide unsupported shell controls', (
    tester,
  ) async {
    await pumpShellWithCapabilities(
      tester,
      size: const Size(1440, 1000),
      capabilitiesToUse: minimalCapabilities,
    );

    expect(find.text('Fork'), findsNothing);
    expect(find.text('Share'), findsNothing);
    expect(find.text('Terminal'), findsNothing);
    expect(find.text('Config'), findsNothing);
  });

  testWidgets(
    'selecting a session skips todo fetch when todos are unsupported',
    (tester) async {
      final chatService = _FakeChatService();
      final todoService = _RecordingTodoService();

      await pumpShellWithCapabilities(
        tester,
        size: const Size(1440, 1600),
        capabilitiesToUse: sessionCapabilitiesWithoutTodos,
        chatService: chatService,
        todoService: todoService,
      );

      expect(todoService.fetchCount, 0);
      final secondSessionLabel = find.text('Second session').last;
      await tester.ensureVisible(secondSessionLabel);
      await tester.tap(secondSessionLabel);
      await _pumpShellFrames(tester);

      expect(chatService.selectedMessagesSessionIds, contains('session-2'));
      expect(todoService.fetchCount, 0);
    },
  );

  testWidgets(
    'selecting a new session does not reuse previous todos when todo cache is missing',
    (tester) async {
      final chatService = _FakeChatService();
      final todoService = _RecordingTodoService(
        todosBySessionId: <String, List<TodoItem>>{
          'session-1': <TodoItem>[
            const TodoItem(
              id: 'todo-1',
              content: 'First',
              status: 'open',
              priority: 'medium',
            ),
          ],
          'session-2': const <TodoItem>[],
        },
      );

      await pumpShellWithCapabilities(
        tester,
        size: const Size(1440, 1600),
        capabilitiesToUse: capabilities,
        chatService: chatService,
        todoService: todoService,
      );
      expect(todoService.fetchCountBySessionId['session-1'] ?? 0, 1);

      final secondSessionLabel = find.text('Second session').last;
      await tester.ensureVisible(secondSessionLabel);
      await tester.tap(secondSessionLabel);
      await tester.pump();
      expect(todoService.fetchCountBySessionId['session-2'] ?? 0, 1);
    },
  );

  testWidgets(
    'selecting a session keeps the chat visible when todo loading fails',
    (tester) async {
      final chatService = _FakeChatService();
      final todoService = _RecordingTodoService(
        errorsBySessionId: <String, Object>{
          'session-2': StateError('Null check operator used on a null value'),
        },
      );

      await pumpShellWithCapabilities(
        tester,
        size: const Size(1440, 1600),
        capabilitiesToUse: capabilities,
        chatService: chatService,
        todoService: todoService,
      );

      final secondSessionLabel = find.text('Second session').last;
      await tester.ensureVisible(secondSessionLabel);
      await tester.tap(secondSessionLabel);
      await _pumpShellFrames(tester);

      expect(find.text('Connection issue'), findsNothing);
      expect(find.text('hello'), findsAtLeastNWidgets(1));
      expect(todoService.fetchCountBySessionId['session-2'] ?? 0, 1);
    },
  );

  testWidgets('shell disposes only internally-owned services', (tester) async {
    final injectedChat = _DisposableChatService();
    final injectedTodo = _DisposableTodoService();

    await pumpShellWithCapabilities(
      tester,
      size: const Size(390, 1000),
      capabilitiesToUse: capabilities,
      chatService: injectedChat,
      todoService: injectedTodo,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(injectedChat.disposed, isFalse);
    expect(injectedTodo.disposed, isFalse);
  });

  testWidgets('shell updates service references when parent swaps them', (
    tester,
  ) async {
    var useFirst = true;
    final firstChat = _PumpingChatService(() {
      if (!useFirst) {
        fail('first chat service used after swap');
      }
    });
    final secondChat = _PumpingChatService(() {});

    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Widget build(ChatService chat) {
      return MaterialApp(
        theme: AppTheme.dark(),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: OpenCodeShellScreen(
          profile: profile,
          project: project,
          capabilities: capabilities,
          onExit: _noop,
          chatService: chat,
        ),
      );
    }

    await tester.pumpWidget(build(firstChat));
    await tester.pump();
    useFirst = false;
    await tester.pumpWidget(build(secondChat));
    await _pumpShellFrames(tester);
  });

  testWidgets(
    'same-scope chat service swaps ignore stale bundle results and reload',
    (tester) async {
      final firstBundleGate = Completer<void>();
      final firstChatService = _ControlledChatService(
        bundlesByScopeKey: <String, ChatSessionBundle>{
          _scopeKeyFor(profile, project): ChatSessionBundle(
            sessions: <SessionSummary>[
              _testSession(
                'first-session',
                'First session',
                directory: project.directory,
              ),
            ],
            statuses: const <String, SessionStatusSummary>{},
            messages: <ChatMessage>[
              _testMessage('first-session', text: 'First message'),
            ],
            selectedSessionId: 'first-session',
          ),
        },
        bundleGateByScopeKey: <String, Completer<void>>{
          _scopeKeyFor(profile, project): firstBundleGate,
        },
      );
      final secondChatService = _ControlledChatService(
        bundlesByScopeKey: <String, ChatSessionBundle>{
          _scopeKeyFor(profile, project): ChatSessionBundle(
            sessions: <SessionSummary>[
              _testSession(
                'second-session',
                'Second session',
                directory: project.directory,
              ),
            ],
            statuses: const <String, SessionStatusSummary>{},
            messages: <ChatMessage>[
              _testMessage('second-session', text: 'Second message'),
            ],
            selectedSessionId: 'second-session',
          ),
        },
      );

      tester.view.physicalSize = const Size(1440, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Widget build(ChatService chatService) {
        return MaterialApp(
          theme: AppTheme.dark(),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: OpenCodeShellScreen(
            profile: profile,
            project: project,
            capabilities: capabilities,
            onExit: _noop,
            chatService: chatService,
            todoService: _RecordingTodoService(),
            fileBrowserService: _ControlledFileBrowserService.empty(),
            requestService: _ControlledRequestService.empty(),
            configService: _ControlledConfigService.empty(),
            integrationStatusService:
                _ControlledIntegrationStatusService.empty(),
          ),
        );
      }

      await tester.pumpWidget(build(firstChatService));
      await tester.pump();

      await tester.pumpWidget(build(secondChatService));
      await _pumpShellFrames(tester);

      expect(find.text('Second message'), findsAtLeastNWidgets(1));
      expect(find.text('First message'), findsNothing);
      expect(
        secondChatService.fetchBundleCountByScopeKey[_scopeKeyFor(
          profile,
          project,
        )],
        1,
      );

      firstBundleGate.complete();
      await _pumpShellFrames(tester);

      expect(find.text('Second message'), findsAtLeastNWidgets(1));
      expect(find.text('First message'), findsNothing);
    },
  );

  testWidgets('same-scope event stream service swaps reconnect live updates', (
    tester,
  ) async {
    final chatService = _ControlledChatService(
      bundlesByScopeKey: <String, ChatSessionBundle>{
        _scopeKeyFor(profile, project): ChatSessionBundle(
          sessions: <SessionSummary>[
            _testSession(
              'demo-session',
              'Demo session',
              directory: project.directory,
            ),
          ],
          statuses: const <String, SessionStatusSummary>{},
          messages: <ChatMessage>[
            _testMessage('demo-session', text: 'Demo message'),
          ],
          selectedSessionId: 'demo-session',
        ),
      },
    );
    final firstEventStreamService = _ControlledEventStreamService();
    final secondEventStreamService = _ControlledEventStreamService();

    tester.view.physicalSize = const Size(1440, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Widget build(EventStreamService eventStreamService) {
      return _buildShell(
        capabilitiesToUse: eventCapabilities,
        profileToUse: profile,
        projectToUse: project,
        chatService: chatService,
        todoService: _RecordingTodoService(),
        fileBrowserService: _ControlledFileBrowserService.empty(),
        requestService: _ControlledRequestService.empty(),
        configService: _ControlledConfigService.empty(),
        integrationStatusService: _ControlledIntegrationStatusService.empty(),
        eventStreamService: eventStreamService,
      );
    }

    await tester.pumpWidget(build(firstEventStreamService));
    await _pumpShellFrames(tester);

    expect(
      firstEventStreamService.connectedScopeKeys,
      contains(_scopeKeyFor(profile, project)),
    );

    firstEventStreamService.emitToScope(
      profile,
      project,
      const EventEnvelope(
        type: 'server.connected',
        properties: <String, Object?>{},
      ),
    );
    await _pumpShellFrames(tester);

    await tester.tap(find.text('Settings').first);
    await _pumpShellFrames(tester);
    await tester.tap(
      find.byKey(const ValueKey<String>('settings-open-advanced')),
    );
    await _pumpShellFrames(tester);
    await tester.scrollUntilVisible(
      find.text('Stream health'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await _pumpShellFrames(tester);

    expect(find.text('Connected'), findsAtLeastNWidgets(1));

    await tester.pumpWidget(build(secondEventStreamService));
    await _pumpShellFrames(tester);

    expect(firstEventStreamService.disconnectCount, 1);
    expect(
      secondEventStreamService.connectedScopeKeys,
      contains(_scopeKeyFor(profile, project)),
    );
    expect(find.text('Connected'), findsAtLeastNWidgets(1));
    expect(find.text('Stale'), findsNothing);

    firstEventStreamService.emitToScope(
      profile,
      project,
      const EventEnvelope(
        type: 'message.part.updated',
        properties: <String, Object?>{
          'part': <String, Object?>{
            'id': 'stale-part',
            'messageID': 'stale-message',
            'sessionID': 'demo-session',
            'type': 'text',
            'text': 'Stale after swap',
          },
        },
      ),
    );
    await _pumpShellFrames(tester);

    expect(find.text('Stale after swap'), findsNothing);

    secondEventStreamService.emitToScope(
      profile,
      project,
      const EventEnvelope(
        type: 'message.part.updated',
        properties: <String, Object?>{
          'part': <String, Object?>{
            'id': 'live-part',
            'messageID': 'live-message',
            'sessionID': 'demo-session',
            'type': 'text',
            'text': 'Live after swap',
          },
        },
      ),
    );
    await _pumpShellFrames(tester);

    expect(find.text('Live after swap'), findsAtLeastNWidgets(1));
  });

  testWidgets(
    'didUpdateWidget reuse ignores stale bundle results from the previous project',
    (tester) async {
      const otherProject = ProjectTarget(
        directory: '/workspace/other',
        label: 'Other',
        source: 'server',
        vcs: 'git',
        branch: 'main',
      );
      final demoBundleGate = Completer<void>();
      final chatService = _ControlledChatService(
        bundlesByScopeKey: <String, ChatSessionBundle>{
          _scopeKeyFor(profile, project): ChatSessionBundle(
            sessions: <SessionSummary>[
              _testSession(
                'demo-session',
                'Demo session',
                directory: project.directory,
              ),
            ],
            statuses: const <String, SessionStatusSummary>{},
            messages: <ChatMessage>[
              _testMessage('demo-session', text: 'Demo message'),
            ],
            selectedSessionId: 'demo-session',
          ),
          _scopeKeyFor(profile, otherProject): ChatSessionBundle(
            sessions: <SessionSummary>[
              _testSession(
                'other-session',
                'Other session',
                directory: otherProject.directory,
              ),
            ],
            statuses: const <String, SessionStatusSummary>{},
            messages: <ChatMessage>[
              _testMessage('other-session', text: 'Other message'),
            ],
            selectedSessionId: 'other-session',
          ),
        },
        bundleGateByScopeKey: <String, Completer<void>>{
          _scopeKeyFor(profile, project): demoBundleGate,
        },
      );
      final todoService = _RecordingTodoService(
        todosByScopeSessionKey: <String, List<TodoItem>>{
          _scopeSessionKey(profile, project, 'demo-session'): <TodoItem>[
            const TodoItem(
              id: 'todo-demo',
              content: 'Demo todo',
              status: 'open',
              priority: 'medium',
            ),
          ],
          _scopeSessionKey(profile, otherProject, 'other-session'): <TodoItem>[
            const TodoItem(
              id: 'todo-other',
              content: 'Other todo',
              status: 'open',
              priority: 'medium',
            ),
          ],
        },
      );

      tester.view.physicalSize = const Size(1440, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Widget build(ProjectTarget projectTarget) {
        return MaterialApp(
          theme: AppTheme.dark(),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: OpenCodeShellScreen(
            profile: profile,
            project: projectTarget,
            capabilities: capabilities,
            onExit: _noop,
            chatService: chatService,
            todoService: todoService,
          ),
        );
      }

      await tester.pumpWidget(build(project));
      await tester.pump();

      await tester.pumpWidget(build(otherProject));
      await _pumpShellFrames(tester);

      expect(find.text('Other message'), findsAtLeastNWidgets(1));
      expect(find.text('Other todo'), findsAtLeastNWidgets(1));
      expect(find.text('Demo message'), findsNothing);
      expect(find.text('Demo todo'), findsNothing);

      demoBundleGate.complete();
      await _pumpShellFrames(tester);

      expect(find.text('Other message'), findsAtLeastNWidgets(1));
      expect(find.text('Other todo'), findsAtLeastNWidgets(1));
      expect(find.text('Demo message'), findsNothing);
      expect(find.text('Demo todo'), findsNothing);
    },
  );

  testWidgets(
    'didUpdateWidget reuse ignores stale todo results from the previous project',
    (tester) async {
      const otherProject = ProjectTarget(
        directory: '/workspace/other',
        label: 'Other',
        source: 'server',
        vcs: 'git',
        branch: 'main',
      );
      final demoTodoGate = Completer<void>();
      final chatService = _ControlledChatService(
        bundlesByScopeKey: <String, ChatSessionBundle>{
          _scopeKeyFor(profile, project): ChatSessionBundle(
            sessions: <SessionSummary>[
              _testSession(
                'demo-session',
                'Demo session',
                directory: project.directory,
              ),
            ],
            statuses: const <String, SessionStatusSummary>{},
            messages: <ChatMessage>[
              _testMessage('demo-session', text: 'Demo message'),
            ],
            selectedSessionId: 'demo-session',
          ),
          _scopeKeyFor(profile, otherProject): ChatSessionBundle(
            sessions: <SessionSummary>[
              _testSession(
                'other-session',
                'Other session',
                directory: otherProject.directory,
              ),
            ],
            statuses: const <String, SessionStatusSummary>{},
            messages: <ChatMessage>[
              _testMessage('other-session', text: 'Other message'),
            ],
            selectedSessionId: 'other-session',
          ),
        },
      );
      final todoService = _RecordingTodoService(
        todosByScopeSessionKey: <String, List<TodoItem>>{
          _scopeSessionKey(profile, project, 'demo-session'): <TodoItem>[
            const TodoItem(
              id: 'todo-1',
              content: 'Demo todo',
              status: 'open',
              priority: 'medium',
            ),
          ],
          _scopeSessionKey(profile, otherProject, 'other-session'): <TodoItem>[
            const TodoItem(
              id: 'todo-2',
              content: 'Other todo',
              status: 'open',
              priority: 'medium',
            ),
          ],
        },
        gateByScopeSessionKey: <String, Completer<void>>{
          _scopeSessionKey(profile, project, 'demo-session'): demoTodoGate,
        },
      );

      tester.view.physicalSize = const Size(1440, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Widget build(ProjectTarget projectTarget) {
        return MaterialApp(
          theme: AppTheme.dark(),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: OpenCodeShellScreen(
            profile: profile,
            project: projectTarget,
            capabilities: capabilities,
            onExit: _noop,
            chatService: chatService,
            todoService: todoService,
          ),
        );
      }

      await tester.pumpWidget(build(project));
      await tester.pump();

      await tester.pumpWidget(build(otherProject));
      await _pumpShellFrames(tester);

      expect(find.text('Other message'), findsAtLeastNWidgets(1));
      expect(find.text('Other todo'), findsAtLeastNWidgets(1));
      expect(find.text('Demo todo'), findsNothing);

      demoTodoGate.complete();
      await _pumpShellFrames(tester);

      expect(find.text('Other message'), findsAtLeastNWidgets(1));
      expect(find.text('Other todo'), findsAtLeastNWidgets(1));
      expect(find.text('Demo todo'), findsNothing);
    },
  );

  testWidgets(
    'didUpdateWidget reuse ignores stale SSE events from the previous project scope',
    (tester) async {
      const otherProject = ProjectTarget(
        directory: '/workspace/other',
        label: 'Other',
        source: 'server',
        vcs: 'git',
        branch: 'main',
      );
      final otherBundleGate = Completer<void>();
      final chatService = _ControlledChatService(
        bundlesByScopeKey: <String, ChatSessionBundle>{
          _scopeKeyFor(profile, project): ChatSessionBundle(
            sessions: <SessionSummary>[
              _testSession(
                'demo-session',
                'Demo session',
                directory: project.directory,
              ),
            ],
            statuses: const <String, SessionStatusSummary>{},
            messages: <ChatMessage>[
              _testMessage('demo-session', text: 'Demo message'),
            ],
            selectedSessionId: 'demo-session',
          ),
          _scopeKeyFor(profile, otherProject): ChatSessionBundle(
            sessions: <SessionSummary>[
              _testSession(
                'other-session',
                'Other session',
                directory: otherProject.directory,
              ),
            ],
            statuses: const <String, SessionStatusSummary>{},
            messages: <ChatMessage>[
              _testMessage('other-session', text: 'Other message'),
            ],
            selectedSessionId: 'other-session',
          ),
        },
        bundleGateByScopeKey: <String, Completer<void>>{
          _scopeKeyFor(profile, otherProject): otherBundleGate,
        },
      );
      final eventStreamService = _ControlledEventStreamService();
      final todoService = _RecordingTodoService();
      final fileBrowserService = _ControlledFileBrowserService.empty();
      final requestService = _ControlledRequestService.empty();
      final configService = _ControlledConfigService.empty();
      final integrationStatusService =
          _ControlledIntegrationStatusService.empty();

      await pumpShellWithCapabilities(
        tester,
        size: const Size(1440, 1400),
        capabilitiesToUse: eventCapabilities,
        chatService: chatService,
        todoService: todoService,
        fileBrowserService: fileBrowserService,
        requestService: requestService,
        configService: configService,
        integrationStatusService: integrationStatusService,
        eventStreamService: eventStreamService,
      );

      expect(
        eventStreamService.connectedScopeKeys,
        contains(_scopeKeyFor(profile, project)),
      );

      await tester.pumpWidget(
        _buildShell(
          capabilitiesToUse: eventCapabilities,
          profileToUse: profile,
          projectToUse: otherProject,
          chatService: chatService,
          todoService: todoService,
          fileBrowserService: fileBrowserService,
          requestService: requestService,
          configService: configService,
          integrationStatusService: integrationStatusService,
          eventStreamService: eventStreamService,
        ),
      );
      await tester.pump();

      expect(eventStreamService.disconnectCount, 1);

      eventStreamService.emitToScope(
        profile,
        project,
        EventEnvelope(
          type: 'message.part.updated',
          properties: <String, Object?>{
            'part': <String, Object?>{
              'id': 'stale-part',
              'messageID': 'stale-message',
              'sessionID': 'demo-session',
              'type': 'text',
              'text': 'Stale SSE message',
            },
          },
        ),
      );
      await _pumpShellFrames(tester);

      expect(find.text('Stale SSE message'), findsNothing);

      otherBundleGate.complete();
      await _pumpShellFrames(tester);

      expect(find.text('Other message'), findsAtLeastNWidgets(1));
      expect(find.text('Stale SSE message'), findsNothing);
    },
  );

  testWidgets(
    'stale event recovery cannot reload or write logs after project reuse',
    (tester) async {
      const otherProject = ProjectTarget(
        directory: '/workspace/other',
        label: 'Other',
        source: 'server',
        vcs: 'git',
        branch: 'main',
      );
      final disconnectStarted = Completer<void>();
      final disconnectGate = Completer<void>();
      final chatService = _ControlledChatService(
        bundlesByScopeKey: <String, ChatSessionBundle>{
          _scopeKeyFor(profile, project): ChatSessionBundle(
            sessions: <SessionSummary>[
              _testSession(
                'demo-session',
                'Demo session',
                directory: project.directory,
              ),
            ],
            statuses: const <String, SessionStatusSummary>{},
            messages: <ChatMessage>[
              _testMessage('demo-session', text: 'Demo message'),
            ],
            selectedSessionId: 'demo-session',
          ),
          _scopeKeyFor(profile, otherProject): ChatSessionBundle(
            sessions: <SessionSummary>[
              _testSession(
                'other-session',
                'Other session',
                directory: otherProject.directory,
              ),
            ],
            statuses: const <String, SessionStatusSummary>{},
            messages: <ChatMessage>[
              _testMessage('other-session', text: 'Other message'),
            ],
            selectedSessionId: 'other-session',
          ),
        },
      );
      final eventStreamService = _ControlledEventStreamService(
        disconnectStarted: disconnectStarted,
        disconnectGate: disconnectGate,
      );

      await pumpShellWithCapabilities(
        tester,
        size: const Size(1440, 1400),
        capabilitiesToUse: eventCapabilities,
        chatService: chatService,
        todoService: _RecordingTodoService(),
        fileBrowserService: _ControlledFileBrowserService.empty(),
        requestService: _ControlledRequestService.empty(),
        configService: _ControlledConfigService.empty(),
        integrationStatusService: _ControlledIntegrationStatusService.empty(),
        eventStreamService: eventStreamService,
      );

      expect(
        chatService.fetchBundleCountByScopeKey[_scopeKeyFor(profile, project)],
        1,
      );

      eventStreamService.emitDoneToScope(profile, project);
      await tester.pump();
      await disconnectStarted.future;

      await tester.pumpWidget(
        _buildShell(
          capabilitiesToUse: eventCapabilities,
          profileToUse: profile,
          projectToUse: otherProject,
          chatService: chatService,
          todoService: _RecordingTodoService(),
          fileBrowserService: _ControlledFileBrowserService.empty(),
          requestService: _ControlledRequestService.empty(),
          configService: _ControlledConfigService.empty(),
          integrationStatusService: _ControlledIntegrationStatusService.empty(),
          eventStreamService: eventStreamService,
        ),
      );
      await _pumpShellFrames(tester);

      expect(find.text('Other message'), findsAtLeastNWidgets(1));
      expect(
        chatService.fetchBundleCountByScopeKey[_scopeKeyFor(
          profile,
          otherProject,
        )],
        1,
      );

      disconnectGate.complete();
      await _pumpShellFrames(tester);

      expect(find.text('Other message'), findsAtLeastNWidgets(1));
      expect(
        chatService.fetchBundleCountByScopeKey[_scopeKeyFor(
          profile,
          otherProject,
        )],
        1,
      );

      await tester.tap(find.text('Settings').first);
      await _pumpShellFrames(tester);
      await tester.tap(
        find.byKey(const ValueKey<String>('settings-open-advanced')),
      );
      await _pumpShellFrames(tester);

      expect(find.text('Reconnect completed'), findsNothing);
    },
  );

  testWidgets('shell command completion ignores stale project-swap results', (
    tester,
  ) async {
    const otherProject = ProjectTarget(
      directory: '/workspace/other',
      label: 'Other',
      source: 'server',
      vcs: 'git',
      branch: 'main',
    );
    final demoCommandStarted = Completer<void>();
    final demoCommandGate = Completer<void>();
    final chatService = _ControlledChatService(
      bundlesByScopeKey: <String, ChatSessionBundle>{
        _scopeKeyFor(profile, project): ChatSessionBundle(
          sessions: <SessionSummary>[
            _testSession(
              'demo-session',
              'Demo session',
              directory: project.directory,
            ),
          ],
          statuses: const <String, SessionStatusSummary>{},
          messages: <ChatMessage>[
            _testMessage('demo-session', text: 'Demo message'),
          ],
          selectedSessionId: 'demo-session',
        ),
        _scopeKeyFor(profile, otherProject): ChatSessionBundle(
          sessions: <SessionSummary>[
            _testSession(
              'other-session',
              'Other session',
              directory: otherProject.directory,
            ),
          ],
          statuses: const <String, SessionStatusSummary>{},
          messages: <ChatMessage>[
            _testMessage('other-session', text: 'Other message'),
          ],
          selectedSessionId: 'other-session',
        ),
      },
      messagesBySessionId: <String, List<ChatMessage>>{
        'demo-session': <ChatMessage>[
          _testMessage('demo-session', text: 'Refreshed demo message'),
        ],
        'other-session': <ChatMessage>[
          _testMessage('other-session', text: 'Other message'),
        ],
      },
    );
    final terminalService = _ControlledTerminalService(
      resultsByScopeSessionKey: <String, ShellCommandResult>{
        _scopeSessionKey(
          profile,
          project,
          'demo-session',
        ): const ShellCommandResult(
          messageId: 'message-demo-shell',
          sessionId: 'demo-session',
          modelId: 'demo-model',
          providerId: 'demo-provider',
        ),
      },
      gateByScopeSessionKey: <String, Completer<void>>{
        _scopeSessionKey(profile, project, 'demo-session'): demoCommandGate,
      },
      startedByScopeSessionKey: <String, Completer<void>>{
        _scopeSessionKey(profile, project, 'demo-session'): demoCommandStarted,
      },
    );
    final todoService = _RecordingTodoService();
    final fileBrowserService = _ControlledFileBrowserService.empty();
    final requestService = _ControlledRequestService.empty();
    final configService = _ControlledConfigService.empty();
    final integrationStatusService =
        _ControlledIntegrationStatusService.empty();

    await pumpShellWithCapabilities(
      tester,
      size: const Size(1440, 1400),
      capabilitiesToUse: capabilities,
      chatService: chatService,
      todoService: todoService,
      fileBrowserService: fileBrowserService,
      requestService: requestService,
      configService: configService,
      integrationStatusService: integrationStatusService,
      terminalService: terminalService,
    );

    await tester.tap(find.text('Settings').first);
    await _pumpShellFrames(tester);
    await tester.tap(
      find.byKey(const ValueKey<String>('settings-open-advanced')),
    );
    await _pumpShellFrames(tester);
    await tester.enterText(find.byType(TextField).first, 'pwd');
    await tester.tap(find.text('Run command'));
    await tester.pump();
    await demoCommandStarted.future;

    await tester.pumpWidget(
      _buildShell(
        capabilitiesToUse: capabilities,
        profileToUse: profile,
        projectToUse: otherProject,
        chatService: chatService,
        todoService: todoService,
        fileBrowserService: fileBrowserService,
        requestService: requestService,
        configService: configService,
        integrationStatusService: integrationStatusService,
        terminalService: terminalService,
      ),
    );
    await _pumpShellFrames(tester);

    expect(find.text('Other message'), findsAtLeastNWidgets(1));
    expect(find.text('Demo message'), findsNothing);

    demoCommandGate.complete();
    await _pumpShellFrames(tester);

    expect(find.text('Other message'), findsAtLeastNWidgets(1));
    expect(find.text('Last command result'), findsNothing);
    expect(
      chatService.selectedMessagesSessionIds,
      isNot(contains('demo-session')),
    );
  });

  testWidgets('prompt submission ignores stale session-swap results', (
    tester,
  ) async {
    final stalePromptStarted = Completer<void>();
    final stalePromptGate = Completer<void>();
    final chatService = _ControlledChatService(
      bundlesByScopeKey: <String, ChatSessionBundle>{
        _scopeKeyFor(profile, project): ChatSessionBundle(
          sessions: <SessionSummary>[
            _testSession(
              'session-1',
              'First session',
              directory: project.directory,
            ),
            _testSession(
              'session-2',
              'Second session',
              directory: project.directory,
            ),
          ],
          statuses: const <String, SessionStatusSummary>{},
          messages: const <ChatMessage>[],
          selectedSessionId: 'session-1',
        ),
      },
      messagesBySessionId: <String, List<ChatMessage>>{
        'session-1': <ChatMessage>[
          _testMessage('session-1', text: 'First message'),
        ],
        'session-2': <ChatMessage>[
          _testMessage('session-2', text: 'Second message'),
        ],
      },
      replyByScopeSessionKey: <String, ChatMessage>{
        _scopeSessionKey(profile, project, 'session-1'): _testMessage(
          'session-1',
          text: 'Stale reply',
        ),
      },
      sendMessageGateByScopeSessionKey: <String, Completer<void>>{
        _scopeSessionKey(profile, project, 'session-1'): stalePromptGate,
      },
      sendMessageStartedByScopeSessionKey: <String, Completer<void>>{
        _scopeSessionKey(profile, project, 'session-1'): stalePromptStarted,
      },
    );

    await pumpShellWithCapabilities(
      tester,
      size: const Size(1440, 1600),
      capabilitiesToUse: capabilities,
      chatService: chatService,
      todoService: _RecordingTodoService(),
      fileBrowserService: _ControlledFileBrowserService.empty(),
      requestService: _ControlledRequestService.empty(),
      configService: _ControlledConfigService.empty(),
      integrationStatusService: _ControlledIntegrationStatusService.empty(),
    );

    await tester.enterText(find.byType(TextField).first, 'ship it');
    await tester.tap(find.text('Send'));
    await tester.pump();
    await stalePromptStarted.future;

    final secondSessionLabel = find.text('Second session').last;
    await tester.ensureVisible(secondSessionLabel);
    await tester.tap(secondSessionLabel);
    await _pumpShellFrames(tester);

    expect(find.text('Second message'), findsAtLeastNWidgets(1));

    stalePromptGate.complete();
    await _pumpShellFrames(tester);

    expect(find.text('Second message'), findsAtLeastNWidgets(1));
    expect(find.text('Stale reply'), findsNothing);
    expect(
      chatService.selectedMessagesSessionIds
          .where((sessionId) => sessionId == 'session-1')
          .length,
      1,
    );
    expect(chatService.selectedMessagesSessionIds.last, 'session-2');
  });

  testWidgets('composer forwards the selected model and thinking mode', (
    tester,
  ) async {
    final chatService = _ControlledChatService(
      bundlesByScopeKey: <String, ChatSessionBundle>{
        _scopeKeyFor(profile, project): ChatSessionBundle(
          sessions: <SessionSummary>[
            _testSession(
              'session-1',
              'First session',
              directory: project.directory,
            ),
          ],
          statuses: const <String, SessionStatusSummary>{},
          messages: <ChatMessage>[
            _testMessage('session-1', text: 'First message'),
          ],
          selectedSessionId: 'session-1',
        ),
      },
      messagesBySessionId: <String, List<ChatMessage>>{
        'session-1': <ChatMessage>[
          _testMessage('session-1', text: 'Updated message'),
        ],
      },
    );
    final configService = _ControlledConfigService(
      snapshotsByScopeKey: <String, ConfigSnapshot>{
        _scopeKeyFor(profile, project): _configSnapshotWithModelChoices(),
      },
    );

    await pumpShellWithCapabilities(
      tester,
      size: const Size(1440, 1400),
      capabilitiesToUse: capabilities,
      chatService: chatService,
      todoService: _RecordingTodoService(),
      fileBrowserService: _ControlledFileBrowserService.empty(),
      requestService: _ControlledRequestService.empty(),
      configService: configService,
      integrationStatusService: _ControlledIntegrationStatusService.empty(),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('composer-model-select')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('anthropic / claude-sonnet-4.5').last);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('composer-reasoning-select')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Max').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'ship it');
    await tester.tap(find.text('Send'));
    await _pumpShellFrames(tester);

    expect(chatService.sentPrompts, hasLength(1));
    expect(chatService.sentPrompts.single.prompt, 'ship it');
    expect(chatService.sentPrompts.single.providerId, 'anthropic');
    expect(chatService.sentPrompts.single.modelId, 'claude-sonnet-4.5');
    expect(chatService.sentPrompts.single.reasoning, 'max');
  });

  testWidgets(
    'new session action resets the draft and creates a fresh session',
    (tester) async {
      final chatService = _ControlledChatService(
        bundlesByScopeKey: <String, ChatSessionBundle>{
          _scopeKeyFor(profile, project): ChatSessionBundle(
            sessions: <SessionSummary>[
              _testSession(
                'session-1',
                'First session',
                directory: project.directory,
              ),
            ],
            statuses: const <String, SessionStatusSummary>{},
            messages: <ChatMessage>[
              _testMessage('session-1', text: 'First message'),
            ],
            selectedSessionId: 'session-1',
          ),
        },
        createdSessionByScopeKey: <String, SessionSummary>{
          _scopeKeyFor(profile, project): _testSession(
            'session-new',
            'Created session',
            directory: project.directory,
          ),
        },
        messagesBySessionId: <String, List<ChatMessage>>{
          'session-new': <ChatMessage>[
            _testMessage('session-new', text: 'Fresh reply'),
          ],
        },
        replyByScopeSessionKey: <String, ChatMessage>{
          _scopeSessionKey(profile, project, 'session-new'): _testMessage(
            'session-new',
            text: 'Fresh reply',
          ),
        },
      );

      await pumpShellWithCapabilities(
        tester,
        size: const Size(1440, 1400),
        capabilitiesToUse: capabilities,
        chatService: chatService,
        todoService: _RecordingTodoService(),
        fileBrowserService: _ControlledFileBrowserService.empty(),
        requestService: _ControlledRequestService.empty(),
        configService: _ControlledConfigService.empty(),
        integrationStatusService: _ControlledIntegrationStatusService.empty(),
      );

      expect(find.text('First message'), findsAtLeastNWidgets(1));

      final newSessionButton = find.byKey(
        const ValueKey<String>('new-session-button'),
      );
      final button = tester.widget<OutlinedButton>(newSessionButton);
      button.onPressed!.call();
      await tester.pump();
      await _pumpShellFrames(tester);

      expect(find.text('First message'), findsNothing);
      expect(find.text('Create session and send'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'start fresh');
      await tester.tap(find.text('Create session and send'));
      await _pumpShellFrames(tester);

      expect(find.text('Fresh reply'), findsAtLeastNWidgets(1));
      expect(chatService.sentPrompts, hasLength(1));
      expect(
        chatService.sentPrompts.single.scopeSessionKey,
        _scopeSessionKey(profile, project, 'session-new'),
      );
    },
  );

  testWidgets('composer thinking options come from the selected server model', (
    tester,
  ) async {
    final configService = _ControlledConfigService(
      snapshotsByScopeKey: <String, ConfigSnapshot>{
        _scopeKeyFor(profile, project): _configSnapshotWithModelChoices(),
      },
    );

    await pumpShellWithCapabilities(
      tester,
      size: const Size(1440, 1400),
      capabilitiesToUse: capabilities,
      chatService: _ControlledChatService(
        bundlesByScopeKey: <String, ChatSessionBundle>{
          _scopeKeyFor(profile, project): ChatSessionBundle(
            sessions: <SessionSummary>[
              _testSession(
                'session-1',
                'First session',
                directory: project.directory,
              ),
            ],
            statuses: const <String, SessionStatusSummary>{},
            messages: <ChatMessage>[
              _testMessage('session-1', text: 'First message'),
            ],
            selectedSessionId: 'session-1',
          ),
        },
      ),
      todoService: _RecordingTodoService(),
      fileBrowserService: _ControlledFileBrowserService.empty(),
      requestService: _ControlledRequestService.empty(),
      configService: configService,
      integrationStatusService: _ControlledIntegrationStatusService.empty(),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('composer-model-select')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('openai / gpt-5-mini').last);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('composer-reasoning-select')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Minimal').last, findsOneWidget);
    expect(find.text('Balanced'), findsNothing);
  });

  testWidgets('uncached project swap clears stale shell state immediately', (
    tester,
  ) async {
    const otherProject = ProjectTarget(
      directory: '/workspace/other',
      label: 'Other',
      source: 'server',
      vcs: 'git',
      branch: 'main',
    );
    final otherBundleGate = Completer<void>();
    final chatService = _ControlledChatService(
      bundlesByScopeKey: <String, ChatSessionBundle>{
        _scopeKeyFor(profile, project): ChatSessionBundle(
          sessions: <SessionSummary>[
            _testSession(
              'demo-session',
              'Demo session',
              directory: project.directory,
            ),
          ],
          statuses: const <String, SessionStatusSummary>{},
          messages: <ChatMessage>[
            _testMessage('demo-session', text: 'Demo message'),
          ],
          selectedSessionId: 'demo-session',
        ),
        _scopeKeyFor(profile, otherProject): ChatSessionBundle(
          sessions: <SessionSummary>[
            _testSession(
              'other-session',
              'Other session',
              directory: otherProject.directory,
            ),
          ],
          statuses: const <String, SessionStatusSummary>{},
          messages: <ChatMessage>[
            _testMessage('other-session', text: 'Other message'),
          ],
          selectedSessionId: 'other-session',
        ),
      },
      bundleGateByScopeKey: <String, Completer<void>>{
        _scopeKeyFor(profile, otherProject): otherBundleGate,
      },
    );
    final todoService = _RecordingTodoService(
      todosByScopeSessionKey: <String, List<TodoItem>>{
        _scopeSessionKey(profile, project, 'demo-session'): <TodoItem>[
          const TodoItem(
            id: 'todo-demo',
            content: 'Demo todo',
            status: 'open',
            priority: 'medium',
          ),
        ],
        _scopeSessionKey(profile, otherProject, 'other-session'): <TodoItem>[
          const TodoItem(
            id: 'todo-other',
            content: 'Other todo',
            status: 'open',
            priority: 'medium',
          ),
        ],
      },
    );
    final fileBrowserService = _ControlledFileBrowserService(
      bundlesByScopeKey: <String, FileBrowserBundle>{
        _scopeKeyFor(profile, project): _fileBrowserBundle(
          path: 'lib/demo.dart',
          preview: 'demo preview',
        ),
        _scopeKeyFor(profile, otherProject): _fileBrowserBundle(
          path: 'lib/other.dart',
          preview: 'other preview',
        ),
      },
    );
    final requestService = _ControlledRequestService(
      bundlesByScopeKey: <String, PendingRequestBundle>{
        _scopeKeyFor(profile, project): _pendingRequests(
          permission: 'demo.permission',
        ),
        _scopeKeyFor(profile, otherProject): _pendingRequests(
          permission: 'other.permission',
        ),
      },
    );
    final configService = _ControlledConfigService(
      snapshotsByScopeKey: <String, ConfigSnapshot>{
        _scopeKeyFor(profile, project): _configSnapshot('demo-mode'),
        _scopeKeyFor(profile, otherProject): _configSnapshot('other-mode'),
      },
    );
    final integrationStatusService = _ControlledIntegrationStatusService(
      snapshotsByScopeKey: <String, IntegrationStatusSnapshot>{
        _scopeKeyFor(profile, project): _integrationSnapshot('demo-provider'),
        _scopeKeyFor(profile, otherProject): _integrationSnapshot(
          'other-provider',
        ),
      },
    );

    await pumpShellWithCapabilities(
      tester,
      size: const Size(1440, 1400),
      capabilitiesToUse: capabilities,
      chatService: chatService,
      todoService: todoService,
      fileBrowserService: fileBrowserService,
      requestService: requestService,
      configService: configService,
      integrationStatusService: integrationStatusService,
    );

    await tester.tap(find.text('Sessions').first);
    await _pumpShellFrames(tester);

    expect(find.text('Demo message'), findsAtLeastNWidgets(1));
    expect(find.text('Demo todo'), findsAtLeastNWidgets(1));
    expect(find.text('lib/demo.dart'), findsAtLeastNWidgets(1));
    expect(find.text('demo.permission'), findsOneWidget);

    await tester.pumpWidget(
      _buildShell(
        capabilitiesToUse: capabilities,
        profileToUse: profile,
        projectToUse: otherProject,
        chatService: chatService,
        todoService: todoService,
        fileBrowserService: fileBrowserService,
        requestService: requestService,
        configService: configService,
        integrationStatusService: integrationStatusService,
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Chat').first);
    await _pumpShellFrames(tester);

    expect(find.text('Demo message'), findsNothing);
    expect(find.text('Demo todo'), findsNothing);
    expect(find.text('lib/demo.dart'), findsNothing);
    expect(find.text('demo.permission'), findsNothing);
    expect(find.text('other.permission'), findsNothing);

    otherBundleGate.complete();
    await _pumpShellFrames(tester);

    await tester.tap(find.text('Sessions').first);
    await _pumpShellFrames(tester);

    expect(find.text('Other message'), findsAtLeastNWidgets(1));
    expect(find.text('Other todo'), findsAtLeastNWidgets(1));
    expect(find.text('lib/other.dart'), findsAtLeastNWidgets(1));
    expect(find.text('demo.permission'), findsNothing);
    expect(find.text('other.permission'), findsOneWidget);
    expect(find.text('Demo message'), findsNothing);
  });

  testWidgets('didUpdateWidget reuse ignores stale file loader results', (
    tester,
  ) async {
    const otherProject = ProjectTarget(
      directory: '/workspace/other',
      label: 'Other',
      source: 'server',
      vcs: 'git',
      branch: 'main',
    );
    final demoFilesStarted = Completer<void>();
    final demoFilesGate = Completer<void>();
    final chatService = _ControlledChatService(
      bundlesByScopeKey: <String, ChatSessionBundle>{
        _scopeKeyFor(profile, project): ChatSessionBundle(
          sessions: <SessionSummary>[
            _testSession(
              'demo-session',
              'Demo session',
              directory: project.directory,
            ),
          ],
          statuses: const <String, SessionStatusSummary>{},
          messages: <ChatMessage>[
            _testMessage('demo-session', text: 'Demo message'),
          ],
          selectedSessionId: 'demo-session',
        ),
        _scopeKeyFor(profile, otherProject): ChatSessionBundle(
          sessions: <SessionSummary>[
            _testSession(
              'other-session',
              'Other session',
              directory: otherProject.directory,
            ),
          ],
          statuses: const <String, SessionStatusSummary>{},
          messages: <ChatMessage>[
            _testMessage('other-session', text: 'Other message'),
          ],
          selectedSessionId: 'other-session',
        ),
      },
    );
    final fileBrowserService = _ControlledFileBrowserService(
      bundlesByScopeKey: <String, FileBrowserBundle>{
        _scopeKeyFor(profile, project): _fileBrowserBundle(
          path: 'lib/demo.dart',
          preview: 'demo preview',
        ),
        _scopeKeyFor(profile, otherProject): _fileBrowserBundle(
          path: 'lib/other.dart',
          preview: 'other preview',
        ),
      },
      gateByScopeKey: <String, Completer<void>>{
        _scopeKeyFor(profile, project): demoFilesGate,
      },
      startedByScopeKey: <String, Completer<void>>{
        _scopeKeyFor(profile, project): demoFilesStarted,
      },
    );

    await pumpShellWithCapabilities(
      tester,
      size: const Size(1440, 1400),
      capabilitiesToUse: capabilities,
      chatService: chatService,
      fileBrowserService: fileBrowserService,
      requestService: _ControlledRequestService.empty(),
      configService: _ControlledConfigService.empty(),
      integrationStatusService: _ControlledIntegrationStatusService.empty(),
    );
    await demoFilesStarted.future;

    await tester.pumpWidget(
      _buildShell(
        capabilitiesToUse: capabilities,
        profileToUse: profile,
        projectToUse: otherProject,
        chatService: chatService,
        fileBrowserService: fileBrowserService,
        requestService: _ControlledRequestService.empty(),
        configService: _ControlledConfigService.empty(),
        integrationStatusService: _ControlledIntegrationStatusService.empty(),
      ),
    );
    await _pumpShellFrames(tester);

    expect(find.text('Other message'), findsAtLeastNWidgets(1));
    expect(find.text('lib/other.dart'), findsAtLeastNWidgets(1));
    expect(find.text('lib/demo.dart'), findsNothing);

    demoFilesGate.complete();
    await _pumpShellFrames(tester);

    expect(find.text('Other message'), findsAtLeastNWidgets(1));
    expect(find.text('lib/other.dart'), findsAtLeastNWidgets(1));
    expect(find.text('lib/demo.dart'), findsNothing);
  });

  testWidgets('didUpdateWidget reuse ignores stale pending-request results', (
    tester,
  ) async {
    const otherProject = ProjectTarget(
      directory: '/workspace/other',
      label: 'Other',
      source: 'server',
      vcs: 'git',
      branch: 'main',
    );
    final demoPendingStarted = Completer<void>();
    final demoPendingGate = Completer<void>();
    final chatService = _ControlledChatService(
      bundlesByScopeKey: <String, ChatSessionBundle>{
        _scopeKeyFor(profile, project): ChatSessionBundle(
          sessions: <SessionSummary>[
            _testSession(
              'demo-session',
              'Demo session',
              directory: project.directory,
            ),
          ],
          statuses: const <String, SessionStatusSummary>{},
          messages: <ChatMessage>[
            _testMessage('demo-session', text: 'Demo message'),
          ],
          selectedSessionId: 'demo-session',
        ),
        _scopeKeyFor(profile, otherProject): ChatSessionBundle(
          sessions: <SessionSummary>[
            _testSession(
              'other-session',
              'Other session',
              directory: otherProject.directory,
            ),
          ],
          statuses: const <String, SessionStatusSummary>{},
          messages: <ChatMessage>[
            _testMessage('other-session', text: 'Other message'),
          ],
          selectedSessionId: 'other-session',
        ),
      },
    );
    final requestService = _ControlledRequestService(
      bundlesByScopeKey: <String, PendingRequestBundle>{
        _scopeKeyFor(profile, project): _pendingRequests(
          permission: 'demo.permission',
        ),
        _scopeKeyFor(profile, otherProject): _pendingRequests(
          permission: 'other.permission',
        ),
      },
      gateByScopeKey: <String, Completer<void>>{
        _scopeKeyFor(profile, project): demoPendingGate,
      },
      startedByScopeKey: <String, Completer<void>>{
        _scopeKeyFor(profile, project): demoPendingStarted,
      },
    );

    await pumpShellWithCapabilities(
      tester,
      size: const Size(1440, 1400),
      capabilitiesToUse: capabilities,
      chatService: chatService,
      fileBrowserService: _ControlledFileBrowserService.empty(),
      requestService: requestService,
      configService: _ControlledConfigService.empty(),
      integrationStatusService: _ControlledIntegrationStatusService.empty(),
    );
    await demoPendingStarted.future;

    await tester.pumpWidget(
      _buildShell(
        capabilitiesToUse: capabilities,
        profileToUse: profile,
        projectToUse: otherProject,
        chatService: chatService,
        fileBrowserService: _ControlledFileBrowserService.empty(),
        requestService: requestService,
        configService: _ControlledConfigService.empty(),
        integrationStatusService: _ControlledIntegrationStatusService.empty(),
      ),
    );
    await _pumpShellFrames(tester);

    await tester.tap(find.text('Sessions').first);
    await _pumpShellFrames(tester);
    expect(find.text('demo.permission'), findsNothing);

    demoPendingGate.complete();
    await _pumpShellFrames(tester);

    expect(find.text('demo.permission'), findsNothing);
  });

  testWidgets('didUpdateWidget reuse ignores stale config snapshot results', (
    tester,
  ) async {
    const otherProject = ProjectTarget(
      directory: '/workspace/other',
      label: 'Other',
      source: 'server',
      vcs: 'git',
      branch: 'main',
    );
    final demoConfigStarted = Completer<void>();
    final demoConfigGate = Completer<void>();
    final chatService = _ControlledChatService(
      bundlesByScopeKey: <String, ChatSessionBundle>{
        _scopeKeyFor(profile, project): ChatSessionBundle(
          sessions: <SessionSummary>[
            _testSession(
              'demo-session',
              'Demo session',
              directory: project.directory,
            ),
          ],
          statuses: const <String, SessionStatusSummary>{},
          messages: <ChatMessage>[
            _testMessage('demo-session', text: 'Demo message'),
          ],
          selectedSessionId: 'demo-session',
        ),
        _scopeKeyFor(profile, otherProject): ChatSessionBundle(
          sessions: <SessionSummary>[
            _testSession(
              'other-session',
              'Other session',
              directory: otherProject.directory,
            ),
          ],
          statuses: const <String, SessionStatusSummary>{},
          messages: <ChatMessage>[
            _testMessage('other-session', text: 'Other message'),
          ],
          selectedSessionId: 'other-session',
        ),
      },
    );
    final configService = _ControlledConfigService(
      snapshotsByScopeKey: <String, ConfigSnapshot>{
        _scopeKeyFor(profile, project): _configSnapshot('demo-mode'),
        _scopeKeyFor(profile, otherProject): _configSnapshot('other-mode'),
      },
      gateByScopeKey: <String, Completer<void>>{
        _scopeKeyFor(profile, project): demoConfigGate,
      },
      startedByScopeKey: <String, Completer<void>>{
        _scopeKeyFor(profile, project): demoConfigStarted,
      },
    );

    await pumpShellWithCapabilities(
      tester,
      size: const Size(1440, 1400),
      capabilitiesToUse: capabilities,
      chatService: chatService,
      fileBrowserService: _ControlledFileBrowserService.empty(),
      requestService: _ControlledRequestService.empty(),
      configService: configService,
      integrationStatusService: _ControlledIntegrationStatusService.empty(),
    );
    await demoConfigStarted.future;

    await tester.pumpWidget(
      _buildShell(
        capabilitiesToUse: capabilities,
        profileToUse: profile,
        projectToUse: otherProject,
        chatService: chatService,
        fileBrowserService: _ControlledFileBrowserService.empty(),
        requestService: _ControlledRequestService.empty(),
        configService: configService,
        integrationStatusService: _ControlledIntegrationStatusService.empty(),
      ),
    );
    await _pumpShellFrames(tester);
    await tester.tap(find.text('Settings').first);
    await _pumpShellFrames(tester);
    await tester.tap(
      find.byKey(const ValueKey<String>('settings-open-advanced')),
    );
    await _pumpShellFrames(tester);

    expect(find.textContaining('other-mode'), findsAtLeastNWidgets(1));
    expect(find.textContaining('demo-mode'), findsNothing);

    demoConfigGate.complete();
    await _pumpShellFrames(tester);

    expect(find.textContaining('other-mode'), findsAtLeastNWidgets(1));
    expect(find.textContaining('demo-mode'), findsNothing);
  });

  testWidgets('didUpdateWidget reuse ignores stale integration results', (
    tester,
  ) async {
    const otherProject = ProjectTarget(
      directory: '/workspace/other',
      label: 'Other',
      source: 'server',
      vcs: 'git',
      branch: 'main',
    );
    final demoIntegrationStarted = Completer<void>();
    final demoIntegrationGate = Completer<void>();
    final chatService = _ControlledChatService(
      bundlesByScopeKey: <String, ChatSessionBundle>{
        _scopeKeyFor(profile, project): ChatSessionBundle(
          sessions: <SessionSummary>[
            _testSession(
              'demo-session',
              'Demo session',
              directory: project.directory,
            ),
          ],
          statuses: const <String, SessionStatusSummary>{},
          messages: <ChatMessage>[
            _testMessage('demo-session', text: 'Demo message'),
          ],
          selectedSessionId: 'demo-session',
        ),
        _scopeKeyFor(profile, otherProject): ChatSessionBundle(
          sessions: <SessionSummary>[
            _testSession(
              'other-session',
              'Other session',
              directory: otherProject.directory,
            ),
          ],
          statuses: const <String, SessionStatusSummary>{},
          messages: <ChatMessage>[
            _testMessage('other-session', text: 'Other message'),
          ],
          selectedSessionId: 'other-session',
        ),
      },
    );
    final integrationStatusService = _ControlledIntegrationStatusService(
      snapshotsByScopeKey: <String, IntegrationStatusSnapshot>{
        _scopeKeyFor(profile, project): _integrationSnapshot('demo-provider'),
        _scopeKeyFor(profile, otherProject): _integrationSnapshot(
          'other-provider',
        ),
      },
      gateByScopeKey: <String, Completer<void>>{
        _scopeKeyFor(profile, project): demoIntegrationGate,
      },
      startedByScopeKey: <String, Completer<void>>{
        _scopeKeyFor(profile, project): demoIntegrationStarted,
      },
    );

    await pumpShellWithCapabilities(
      tester,
      size: const Size(1440, 1400),
      capabilitiesToUse: capabilities,
      chatService: chatService,
      fileBrowserService: _ControlledFileBrowserService.empty(),
      requestService: _ControlledRequestService.empty(),
      configService: _ControlledConfigService.empty(),
      integrationStatusService: integrationStatusService,
    );
    await demoIntegrationStarted.future;

    await tester.pumpWidget(
      _buildShell(
        capabilitiesToUse: capabilities,
        profileToUse: profile,
        projectToUse: otherProject,
        chatService: chatService,
        fileBrowserService: _ControlledFileBrowserService.empty(),
        requestService: _ControlledRequestService.empty(),
        configService: _ControlledConfigService.empty(),
        integrationStatusService: integrationStatusService,
      ),
    );
    await _pumpShellFrames(tester);
    await tester.tap(find.text('Settings').first);
    await _pumpShellFrames(tester);
    await tester.tap(
      find.byKey(const ValueKey<String>('settings-open-advanced')),
    );
    await _pumpShellFrames(tester);

    expect(find.text('other-provider'), findsAtLeastNWidgets(1));
    expect(find.text('demo-provider'), findsNothing);

    demoIntegrationGate.complete();
    await _pumpShellFrames(tester);

    expect(find.text('other-provider'), findsAtLeastNWidgets(1));
    expect(find.text('demo-provider'), findsNothing);
  });

  testWidgets('project swaps ignore stale session selection completions', (
    tester,
  ) async {
    const otherProject = ProjectTarget(
      directory: '/workspace/other',
      label: 'Other',
      source: 'server',
      vcs: 'git',
      branch: 'main',
    );
    final secondSessionMessagesGate = Completer<void>();
    final chatService = _ControlledChatService(
      bundlesByScopeKey: <String, ChatSessionBundle>{
        _scopeKeyFor(profile, project): ChatSessionBundle(
          sessions: <SessionSummary>[
            _testSession(
              'session-1',
              'First session',
              directory: project.directory,
            ),
            _testSession(
              'session-2',
              'Second session',
              directory: project.directory,
            ),
          ],
          statuses: const <String, SessionStatusSummary>{},
          messages: <ChatMessage>[
            _testMessage('session-1', text: 'First message'),
          ],
          selectedSessionId: 'session-1',
        ),
        _scopeKeyFor(profile, otherProject): ChatSessionBundle(
          sessions: <SessionSummary>[
            _testSession(
              'other-session',
              'Other session',
              directory: otherProject.directory,
            ),
          ],
          statuses: const <String, SessionStatusSummary>{},
          messages: <ChatMessage>[
            _testMessage('other-session', text: 'Other message'),
          ],
          selectedSessionId: 'other-session',
        ),
      },
      messagesBySessionId: <String, List<ChatMessage>>{
        'session-1': <ChatMessage>[
          _testMessage('session-1', text: 'First message'),
        ],
        'session-2': <ChatMessage>[
          _testMessage('session-2', text: 'Second message'),
        ],
      },
      messageGateBySessionId: <String, Completer<void>>{
        'session-2': secondSessionMessagesGate,
      },
    );
    final todoService = _RecordingTodoService(
      todosBySessionId: <String, List<TodoItem>>{
        'session-1': <TodoItem>[
          const TodoItem(
            id: 'todo-1',
            content: 'First todo',
            status: 'open',
            priority: 'medium',
          ),
        ],
        'session-2': <TodoItem>[
          const TodoItem(
            id: 'todo-2',
            content: 'Second todo',
            status: 'open',
            priority: 'medium',
          ),
        ],
      },
    );

    tester.view.physicalSize = const Size(1440, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Widget build(ProjectTarget projectTarget) {
      return MaterialApp(
        theme: AppTheme.dark(),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: OpenCodeShellScreen(
          profile: profile,
          project: projectTarget,
          capabilities: capabilities,
          onExit: _noop,
          chatService: chatService,
          todoService: todoService,
        ),
      );
    }

    await tester.pumpWidget(build(project));
    await tester.pump();

    await tester.pumpWidget(build(otherProject));
    await _pumpShellFrames(tester);

    expect(find.text('Other message'), findsAtLeastNWidgets(1));
    expect(find.text('Second message'), findsNothing);

    secondSessionMessagesGate.complete();
    await _pumpShellFrames(tester);

    expect(
      chatService.selectedMessagesSessionIds,
      isNot(contains('session-2')),
    );
    expect(todoService.fetchCountBySessionId['session-2'] ?? 0, 0);
    expect(find.text('Other message'), findsAtLeastNWidgets(1));
    expect(find.text('Second message'), findsNothing);
  });
}

void _noop() {}

Widget _buildShell({
  required CapabilityRegistry capabilitiesToUse,
  required ServerProfile profileToUse,
  required ProjectTarget projectToUse,
  List<ProjectTarget> availableProjects = const <ProjectTarget>[],
  ValueChanged<ProjectTarget>? onSelectProject,
  ChatService? chatService,
  TodoService? todoService,
  FileBrowserService? fileBrowserService,
  RequestService? requestService,
  ConfigService? configService,
  IntegrationStatusService? integrationStatusService,
  EventStreamService? eventStreamService,
  TerminalService? terminalService,
  SessionActionService? sessionActionService,
  PendingRequestNotificationService? pendingRequestNotificationService,
  PendingRequestSoundService? pendingRequestSoundService,
}) {
  return MaterialApp(
    theme: AppTheme.dark(),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: OpenCodeShellScreen(
      profile: profileToUse,
      project: projectToUse,
      capabilities: capabilitiesToUse,
      onExit: _noop,
      availableProjects: availableProjects,
      onSelectProject: onSelectProject,
      chatService: chatService,
      todoService: todoService,
      fileBrowserService: fileBrowserService,
      requestService: requestService,
      configService: configService,
      integrationStatusService: integrationStatusService,
      eventStreamService: eventStreamService,
      terminalService: terminalService,
      sessionActionService: sessionActionService,
      pendingRequestNotificationService: pendingRequestNotificationService,
      pendingRequestSoundService: pendingRequestSoundService,
    ),
  );
}

class _NotificationRecord {
  const _NotificationRecord({
    required this.dedupeKey,
    required this.title,
    required this.body,
  });

  final String dedupeKey;
  final String title;
  final String body;
}

class _FakePendingRequestNotificationService
    implements PendingRequestNotificationService {
  final List<_NotificationRecord> notifications = <_NotificationRecord>[];

  @override
  Future<void> showPendingRequestNotification({
    required String dedupeKey,
    required String title,
    required String body,
  }) async {
    notifications.add(
      _NotificationRecord(dedupeKey: dedupeKey, title: title, body: body),
    );
  }
}

class _FakePendingRequestSoundService implements PendingRequestSoundService {
  final List<String> playedKeys = <String>[];

  @override
  Future<void> playPermissionRequestSound({required String dedupeKey}) async {
    playedKeys.add(dedupeKey);
  }
}

String _scopeKeyFor(ServerProfile profile, ProjectTarget project) {
  return '${profile.storageKey}::${project.directory}';
}

String _scopeSessionKey(
  ServerProfile profile,
  ProjectTarget project,
  String sessionId,
) {
  return '${_scopeKeyFor(profile, project)}::$sessionId';
}

String _scopePathKey(
  ServerProfile profile,
  ProjectTarget project,
  String path,
) {
  return '${_scopeKeyFor(profile, project)}::$path';
}

SessionSummary _testSession(
  String id,
  String title, {
  required String directory,
}) {
  return SessionSummary(
    id: id,
    directory: directory,
    title: title,
    version: '1',
    updatedAt: DateTime.utc(2026, 3, 17),
  );
}

ChatMessage _testMessage(String sessionId, {required String text}) {
  return ChatMessage(
    info: ChatMessageInfo(
      id: 'msg-$sessionId-$text',
      role: 'assistant',
      sessionId: sessionId,
    ),
    parts: <ChatPart>[
      ChatPart(id: 'part-$sessionId', type: 'text', text: text),
    ],
  );
}

List<ChatMessage> _manyMessages(String sessionId, int count) {
  return List<ChatMessage>.generate(
    count,
    (index) =>
        _testMessage(sessionId, text: 'message ${index + 1} ${'detail ' * 12}'),
    growable: false,
  );
}

Future<void> _pumpShellFrames(WidgetTester tester) async {
  await tester.pump();
  for (var index = 0; index < 5; index += 1) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

FileBrowserBundle _fileBrowserBundle({
  required String path,
  required String preview,
}) {
  return FileBrowserBundle(
    nodes: <FileNodeSummary>[
      FileNodeSummary(
        name: path.split('/').last,
        path: path,
        type: 'file',
        ignored: false,
      ),
    ],
    searchResults: <String>[path],
    textMatches: const <TextMatchSummary>[],
    symbols: const <SymbolSummary>[],
    statuses: <FileStatusSummary>[
      FileStatusSummary(path: path, status: 'modified', added: 1, removed: 0),
    ],
    preview: FileContentSummary(type: 'file', content: preview),
    selectedPath: path,
  );
}

PendingRequestBundle _pendingRequests({required String permission}) {
  return PendingRequestBundle(
    questions: const <QuestionRequestSummary>[],
    permissions: <PermissionRequestSummary>[
      PermissionRequestSummary(
        id: 'permission-$permission',
        sessionId: 'session-1',
        permission: permission,
        patterns: const <String>['**'],
      ),
    ],
  );
}

ConfigSnapshot _configSnapshot(String mode) {
  return ConfigSnapshot(
    config: RawJsonDocument(<String, Object?>{'mode': mode}),
    providerConfig: RawJsonDocument(<String, Object?>{'provider': mode}),
  );
}

ConfigSnapshot _configSnapshotWithModelChoices() {
  return ConfigSnapshot(
    config: RawJsonDocument(<String, Object?>{
      'mode': 'demo-mode',
      'model': 'openai/gpt-5',
    }),
    providerConfig: RawJsonDocument(<String, Object?>{
      'providers': <Object?>[
        <String, Object?>{
          'id': 'openai',
          'name': 'OpenAI',
          'source': 'custom',
          'env': <String>['OPENAI_API_KEY'],
          'options': <String, Object?>{},
          'models': <String, Object?>{
            'gpt-5': <String, Object?>{
              'id': 'gpt-5',
              'providerID': 'openai',
              'name': 'GPT-5',
              'status': 'active',
              'variants': <String, Object?>{
                'low': <String, Object?>{},
                'medium': <String, Object?>{},
                'high': <String, Object?>{},
              },
            },
            'gpt-5-mini': <String, Object?>{
              'id': 'gpt-5-mini',
              'providerID': 'openai',
              'name': 'GPT-5 Mini',
              'status': 'active',
              'variants': <String, Object?>{
                'minimal': <String, Object?>{},
                'low': <String, Object?>{},
              },
            },
          },
        },
        <String, Object?>{
          'id': 'anthropic',
          'name': 'Anthropic',
          'source': 'custom',
          'env': <String>['ANTHROPIC_API_KEY'],
          'options': <String, Object?>{},
          'models': <String, Object?>{
            'claude-sonnet-4.5': <String, Object?>{
              'id': 'claude-sonnet-4.5',
              'providerID': 'anthropic',
              'name': 'Claude Sonnet 4.5',
              'status': 'active',
              'variants': <String, Object?>{
                'high': <String, Object?>{},
                'max': <String, Object?>{},
              },
            },
          },
        },
      ],
      'default': <String, Object?>{
        'openai': 'gpt-5',
        'anthropic': 'claude-sonnet-4.5',
      },
    }),
  );
}

ConfigSnapshot _emptyConfigSnapshot() {
  return ConfigSnapshot(
    config: RawJsonDocument(<String, Object?>{}),
    providerConfig: RawJsonDocument(<String, Object?>{}),
  );
}

IntegrationStatusSnapshot _integrationSnapshot(String providerId) {
  return IntegrationStatusSnapshot(
    providerAuth: <String, List<String>>{
      providerId: const <String>['oauth'],
    },
    mcpDetails: const <String, McpIntegrationStatus>{
      'demo-mcp': McpIntegrationStatus(status: 'connected'),
    },
    lspStatus: const <String, String>{'dart': 'ready'},
    formatterStatus: const <String, bool>{'dart': true},
  );
}

IntegrationStatusSnapshot _emptyIntegrationSnapshot() {
  return const IntegrationStatusSnapshot(
    providerAuth: <String, List<String>>{},
    mcpDetails: <String, McpIntegrationStatus>{},
    lspStatus: <String, String>{},
    formatterStatus: <String, bool>{},
  );
}

void _completeIfPending(Completer<void>? completer) {
  if (completer != null && !completer.isCompleted) {
    completer.complete();
  }
}

class _ControlledFileBrowserService extends FileBrowserService {
  _ControlledFileBrowserService({
    required this.bundlesByScopeKey,
    Map<String, Completer<void>>? gateByScopeKey,
    Map<String, Completer<void>>? startedByScopeKey,
    Map<String, FileContentSummary?>? previewsByScopePathKey,
  }) : gateByScopeKey = gateByScopeKey ?? const <String, Completer<void>>{},
       startedByScopeKey =
           startedByScopeKey ?? const <String, Completer<void>>{},
       previewsByScopePathKey =
           previewsByScopePathKey ?? const <String, FileContentSummary?>{};

  factory _ControlledFileBrowserService.empty() {
    return _ControlledFileBrowserService(
      bundlesByScopeKey: const <String, FileBrowserBundle>{},
    );
  }

  final Map<String, FileBrowserBundle> bundlesByScopeKey;
  final Map<String, Completer<void>> gateByScopeKey;
  final Map<String, Completer<void>> startedByScopeKey;
  final Map<String, FileContentSummary?> previewsByScopePathKey;

  @override
  Future<FileBrowserBundle> fetchBundle({
    required ServerProfile profile,
    required ProjectTarget project,
    String searchQuery = '',
  }) async {
    final scopeKey = _scopeKeyFor(profile, project);
    _completeIfPending(startedByScopeKey[scopeKey]);
    final gate = gateByScopeKey[scopeKey];
    if (gate != null) {
      await gate.future;
    }
    return bundlesByScopeKey[scopeKey] ??
        const FileBrowserBundle(
          nodes: <FileNodeSummary>[],
          searchResults: <String>[],
          textMatches: <TextMatchSummary>[],
          symbols: <SymbolSummary>[],
          statuses: <FileStatusSummary>[],
          preview: null,
          selectedPath: null,
        );
  }

  @override
  Future<FileContentSummary?> fetchFileContent({
    required ServerProfile profile,
    required ProjectTarget project,
    required String path,
  }) async {
    return previewsByScopePathKey[_scopePathKey(profile, project, path)];
  }

  @override
  void dispose() {}
}

class _ControlledRequestService extends RequestService {
  _ControlledRequestService({
    required this.bundlesByScopeKey,
    Map<String, Completer<void>>? gateByScopeKey,
    Map<String, Completer<void>>? startedByScopeKey,
  }) : gateByScopeKey = gateByScopeKey ?? const <String, Completer<void>>{},
       startedByScopeKey =
           startedByScopeKey ?? const <String, Completer<void>>{};

  factory _ControlledRequestService.empty() {
    return _ControlledRequestService(
      bundlesByScopeKey: const <String, PendingRequestBundle>{},
    );
  }

  final Map<String, PendingRequestBundle> bundlesByScopeKey;
  final Map<String, Completer<void>> gateByScopeKey;
  final Map<String, Completer<void>> startedByScopeKey;

  @override
  Future<PendingRequestBundle> fetchPending({
    required ServerProfile profile,
    required ProjectTarget project,
    bool supportsQuestions = true,
    bool supportsPermissions = true,
  }) async {
    final scopeKey = _scopeKeyFor(profile, project);
    _completeIfPending(startedByScopeKey[scopeKey]);
    final gate = gateByScopeKey[scopeKey];
    if (gate != null) {
      await gate.future;
    }
    return bundlesByScopeKey[scopeKey] ??
        const PendingRequestBundle(
          questions: <QuestionRequestSummary>[],
          permissions: <PermissionRequestSummary>[],
        );
  }

  @override
  void dispose() {}
}

class _ControlledConfigService extends ConfigService {
  _ControlledConfigService({
    required this.snapshotsByScopeKey,
    Map<String, Completer<void>>? gateByScopeKey,
    Map<String, Completer<void>>? startedByScopeKey,
  }) : gateByScopeKey = gateByScopeKey ?? const <String, Completer<void>>{},
       startedByScopeKey =
           startedByScopeKey ?? const <String, Completer<void>>{};

  factory _ControlledConfigService.empty() {
    return _ControlledConfigService(
      snapshotsByScopeKey: const <String, ConfigSnapshot>{},
    );
  }

  final Map<String, ConfigSnapshot> snapshotsByScopeKey;
  final Map<String, Completer<void>> gateByScopeKey;
  final Map<String, Completer<void>> startedByScopeKey;

  @override
  Future<ConfigSnapshot> fetch({
    required ServerProfile profile,
    required ProjectTarget project,
  }) async {
    final scopeKey = _scopeKeyFor(profile, project);
    _completeIfPending(startedByScopeKey[scopeKey]);
    final gate = gateByScopeKey[scopeKey];
    if (gate != null) {
      await gate.future;
    }
    return snapshotsByScopeKey[scopeKey] ?? _emptyConfigSnapshot();
  }

  @override
  void dispose() {}
}

class _ControlledIntegrationStatusService extends IntegrationStatusService {
  _ControlledIntegrationStatusService({
    required this.snapshotsByScopeKey,
    Map<String, Completer<void>>? gateByScopeKey,
    Map<String, Completer<void>>? startedByScopeKey,
    Map<String, String>? providerAuthUrlByScopeKey,
    Map<String, Completer<void>>? providerAuthGateByScopeKey,
    Map<String, Completer<void>>? providerAuthStartedByScopeKey,
    Map<String, String>? mcpAuthUrlByScopeKey,
    Map<String, Completer<void>>? mcpAuthGateByScopeKey,
    Map<String, Completer<void>>? mcpAuthStartedByScopeKey,
  }) : gateByScopeKey = gateByScopeKey ?? const <String, Completer<void>>{},
       startedByScopeKey =
           startedByScopeKey ?? const <String, Completer<void>>{},
       providerAuthUrlByScopeKey =
           providerAuthUrlByScopeKey ?? const <String, String>{},
       providerAuthGateByScopeKey =
           providerAuthGateByScopeKey ?? const <String, Completer<void>>{},
       providerAuthStartedByScopeKey =
           providerAuthStartedByScopeKey ?? const <String, Completer<void>>{},
       mcpAuthUrlByScopeKey = mcpAuthUrlByScopeKey ?? const <String, String>{},
       mcpAuthGateByScopeKey =
           mcpAuthGateByScopeKey ?? const <String, Completer<void>>{},
       mcpAuthStartedByScopeKey =
           mcpAuthStartedByScopeKey ?? const <String, Completer<void>>{};

  factory _ControlledIntegrationStatusService.empty() {
    return _ControlledIntegrationStatusService(
      snapshotsByScopeKey: const <String, IntegrationStatusSnapshot>{},
    );
  }

  final Map<String, IntegrationStatusSnapshot> snapshotsByScopeKey;
  final Map<String, Completer<void>> gateByScopeKey;
  final Map<String, Completer<void>> startedByScopeKey;
  final Map<String, String> providerAuthUrlByScopeKey;
  final Map<String, Completer<void>> providerAuthGateByScopeKey;
  final Map<String, Completer<void>> providerAuthStartedByScopeKey;
  final Map<String, String> mcpAuthUrlByScopeKey;
  final Map<String, Completer<void>> mcpAuthGateByScopeKey;
  final Map<String, Completer<void>> mcpAuthStartedByScopeKey;

  @override
  Future<IntegrationStatusSnapshot> fetch({
    required ServerProfile profile,
    required ProjectTarget project,
  }) async {
    final scopeKey = _scopeKeyFor(profile, project);
    _completeIfPending(startedByScopeKey[scopeKey]);
    final gate = gateByScopeKey[scopeKey];
    if (gate != null) {
      await gate.future;
    }
    return snapshotsByScopeKey[scopeKey] ?? _emptyIntegrationSnapshot();
  }

  @override
  Future<String?> startProviderAuth({
    int method = 0,
    required ServerProfile profile,
    required ProjectTarget project,
    required String providerId,
  }) async {
    final scopeKey = _scopeKeyFor(profile, project);
    _completeIfPending(providerAuthStartedByScopeKey[scopeKey]);
    final gate = providerAuthGateByScopeKey[scopeKey];
    if (gate != null) {
      await gate.future;
    }
    return providerAuthUrlByScopeKey[scopeKey] ?? 'https://example.com/oauth';
  }

  @override
  Future<String?> startMcpAuth({
    int method = 0,
    required ServerProfile profile,
    required ProjectTarget project,
    required String name,
    String? redirectUri,
  }) async {
    final scopeKey = _scopeKeyFor(profile, project);
    _completeIfPending(mcpAuthStartedByScopeKey[scopeKey]);
    final gate = mcpAuthGateByScopeKey[scopeKey];
    if (gate != null) {
      await gate.future;
    }
    return mcpAuthUrlByScopeKey[scopeKey] ?? 'https://example.com/mcp';
  }

  @override
  void dispose() {}
}

class _FakeChatService extends ChatService {
  _FakeChatService();

  final List<String> selectedMessagesSessionIds = <String>[];
  final Map<String, ChatSessionBundle> _bundleCache =
      <String, ChatSessionBundle>{};

  @override
  Future<ChatSessionBundle> fetchBundle({
    required ServerProfile profile,
    required ProjectTarget project,
    bool includeSelectedSessionMessages = true,
  }) async {
    final key = '${profile.storageKey}::${project.directory}';
    return _bundleCache.putIfAbsent(key, () {
      return ChatSessionBundle(
        sessions: <SessionSummary>[
          _testSession(
            'session-1',
            'First session',
            directory: project.directory,
          ),
          _testSession(
            'session-2',
            'Second session',
            directory: project.directory,
          ),
        ],
        statuses: const <String, SessionStatusSummary>{},
        messages: <ChatMessage>[_testMessage('session-1', text: 'hello')],
        selectedSessionId: 'session-1',
      );
    });
  }

  @override
  Future<List<ChatMessage>> fetchMessages({
    required ServerProfile profile,
    required ProjectTarget project,
    required String sessionId,
  }) async {
    selectedMessagesSessionIds.add(sessionId);
    return <ChatMessage>[_testMessage(sessionId, text: 'hello')];
  }

  @override
  void dispose() {
    disposed = true;
  }

  bool disposed = false;
}

class _RecordingTodoService extends TodoService {
  _RecordingTodoService({
    Map<String, List<TodoItem>>? todosBySessionId,
    Map<String, List<TodoItem>>? todosByScopeSessionKey,
    Map<String, Object>? errorsBySessionId,
    Map<String, Object>? errorsByScopeSessionKey,
    Map<String, Completer<void>>? gateBySessionId,
    Map<String, Completer<void>>? gateByScopeSessionKey,
  }) : todosBySessionId = todosBySessionId ?? const <String, List<TodoItem>>{},
       todosByScopeSessionKey =
           todosByScopeSessionKey ?? const <String, List<TodoItem>>{},
       errorsBySessionId = errorsBySessionId ?? const <String, Object>{},
       errorsByScopeSessionKey =
           errorsByScopeSessionKey ?? const <String, Object>{},
       gateBySessionId = gateBySessionId ?? const <String, Completer<void>>{},
       gateByScopeSessionKey =
           gateByScopeSessionKey ?? const <String, Completer<void>>{};

  int fetchCount = 0;
  final Map<String, int> fetchCountBySessionId = <String, int>{};
  final Map<String, List<TodoItem>> todosBySessionId;
  final Map<String, List<TodoItem>> todosByScopeSessionKey;
  final Map<String, Object> errorsBySessionId;
  final Map<String, Object> errorsByScopeSessionKey;
  final Map<String, Completer<void>> gateBySessionId;
  final Map<String, Completer<void>> gateByScopeSessionKey;

  @override
  Future<List<TodoItem>> fetchTodos({
    required ServerProfile profile,
    required ProjectTarget project,
    required String sessionId,
  }) async {
    final scopeSessionKey = _scopeSessionKey(profile, project, sessionId);
    fetchCount += 1;
    fetchCountBySessionId[sessionId] =
        (fetchCountBySessionId[sessionId] ?? 0) + 1;
    final gate =
        gateByScopeSessionKey[scopeSessionKey] ?? gateBySessionId[sessionId];
    if (gate != null) {
      await gate.future;
    }
    final error =
        errorsByScopeSessionKey[scopeSessionKey] ??
        errorsBySessionId[sessionId];
    if (error != null) {
      throw error;
    }
    return todosByScopeSessionKey[scopeSessionKey] ??
        todosBySessionId[sessionId] ??
        const <TodoItem>[];
  }

  @override
  void dispose() {
    disposed = true;
  }

  bool disposed = false;
}

class _ControlledChatService extends ChatService {
  _ControlledChatService({
    required this.bundlesByScopeKey,
    Map<String, Completer<void>>? bundleGateByScopeKey,
    Map<String, List<ChatMessage>>? messagesBySessionId,
    Map<String, Completer<void>>? messageGateBySessionId,
    Map<String, SessionSummary>? createdSessionByScopeKey,
    Map<String, Completer<void>>? createSessionGateByScopeKey,
    Map<String, ChatMessage>? replyByScopeSessionKey,
    Map<String, Completer<void>>? sendMessageGateByScopeSessionKey,
    Map<String, Completer<void>>? sendMessageStartedByScopeSessionKey,
  }) : bundleGateByScopeKey =
           bundleGateByScopeKey ?? const <String, Completer<void>>{},
       messagesBySessionId =
           messagesBySessionId ?? const <String, List<ChatMessage>>{},
       messageGateBySessionId =
           messageGateBySessionId ?? const <String, Completer<void>>{},
       createdSessionByScopeKey =
           createdSessionByScopeKey ?? const <String, SessionSummary>{},
       createSessionGateByScopeKey =
           createSessionGateByScopeKey ?? const <String, Completer<void>>{},
       replyByScopeSessionKey =
           replyByScopeSessionKey ?? const <String, ChatMessage>{},
       sendMessageGateByScopeSessionKey =
           sendMessageGateByScopeSessionKey ??
           const <String, Completer<void>>{},
       sendMessageStartedByScopeSessionKey =
           sendMessageStartedByScopeSessionKey ??
           const <String, Completer<void>>{};

  final Map<String, ChatSessionBundle> bundlesByScopeKey;
  final Map<String, Completer<void>> bundleGateByScopeKey;
  final Map<String, List<ChatMessage>> messagesBySessionId;
  final Map<String, Completer<void>> messageGateBySessionId;
  final Map<String, SessionSummary> createdSessionByScopeKey;
  final Map<String, Completer<void>> createSessionGateByScopeKey;
  final Map<String, ChatMessage> replyByScopeSessionKey;
  final Map<String, Completer<void>> sendMessageGateByScopeSessionKey;
  final Map<String, Completer<void>> sendMessageStartedByScopeSessionKey;
  final List<String> selectedMessagesSessionIds = <String>[];
  final List<
    ({
      String? agent,
      String prompt,
      String? providerId,
      String? modelId,
      String? variant,
      String? reasoning,
      String scopeSessionKey,
    })
  >
  sentPrompts =
      <
        ({
          String? agent,
          String prompt,
          String? providerId,
          String? modelId,
          String? variant,
          String? reasoning,
          String scopeSessionKey,
        })
      >[];
  final Map<String, int> fetchBundleCountByScopeKey = <String, int>{};
  int createSessionCalls = 0;

  @override
  Future<SessionSummary> createSession({
    required ServerProfile profile,
    required ProjectTarget project,
    String? title,
  }) async {
    createSessionCalls += 1;
    final scopeKey = _scopeKeyFor(profile, project);
    final gate = createSessionGateByScopeKey[scopeKey];
    if (gate != null) {
      await gate.future;
    }
    return createdSessionByScopeKey[scopeKey] ??
        _testSession(
          'created-${project.directory.hashCode}',
          title ?? 'Created session',
          directory: project.directory,
        );
  }

  @override
  Future<ChatSessionBundle> fetchBundle({
    required ServerProfile profile,
    required ProjectTarget project,
    bool includeSelectedSessionMessages = true,
  }) async {
    final scopeKey = _scopeKeyFor(profile, project);
    fetchBundleCountByScopeKey[scopeKey] =
        (fetchBundleCountByScopeKey[scopeKey] ?? 0) + 1;
    final gate = bundleGateByScopeKey[scopeKey];
    if (gate != null) {
      await gate.future;
    }
    final bundle = bundlesByScopeKey[scopeKey];
    if (bundle == null) {
      throw StateError('Missing bundle for $scopeKey');
    }
    return bundle;
  }

  @override
  Future<List<ChatMessage>> fetchMessages({
    required ServerProfile profile,
    required ProjectTarget project,
    required String sessionId,
  }) async {
    selectedMessagesSessionIds.add(sessionId);
    final gate = messageGateBySessionId[sessionId];
    if (gate != null) {
      await gate.future;
    }
    final scopedMessages = messagesBySessionId[sessionId];
    if (scopedMessages != null) {
      return scopedMessages;
    }
    final bundle = bundlesByScopeKey[_scopeKeyFor(profile, project)];
    if (bundle != null &&
        bundle.selectedSessionId == sessionId &&
        bundle.messages.isNotEmpty) {
      return bundle.messages;
    }
    return const <ChatMessage>[];
  }

  @override
  Future<ChatMessage> sendMessage({
    required ServerProfile profile,
    required ProjectTarget project,
    required String sessionId,
    required String prompt,
    List<PromptAttachment> attachments = const <PromptAttachment>[],
    String? agent,
    String? providerId,
    String? modelId,
    String? variant,
    String? reasoning,
  }) async {
    final scopeSessionKey = _scopeSessionKey(profile, project, sessionId);
    sentPrompts.add((
      agent: agent,
      prompt: prompt,
      providerId: providerId,
      modelId: modelId,
      variant: variant,
      reasoning: reasoning,
      scopeSessionKey: scopeSessionKey,
    ));
    _completeIfPending(sendMessageStartedByScopeSessionKey[scopeSessionKey]);
    final gate = sendMessageGateByScopeSessionKey[scopeSessionKey];
    if (gate != null) {
      await gate.future;
    }
    return replyByScopeSessionKey[scopeSessionKey] ??
        _testMessage(sessionId, text: prompt);
  }
}

class _RecordingSessionActionService extends SessionActionService {
  int summarizeCalls = 0;
  String? lastSummarizedSessionId;
  String? lastSummarizedProviderId;
  String? lastSummarizedModelId;

  @override
  Future<bool> summarizeSession({
    required ServerProfile profile,
    required ProjectTarget project,
    required String sessionId,
    String? providerId,
    String? modelId,
    bool auto = false,
  }) async {
    summarizeCalls += 1;
    lastSummarizedSessionId = sessionId;
    lastSummarizedProviderId = providerId;
    lastSummarizedModelId = modelId;
    return true;
  }
}

class _ControlledEventStreamService extends EventStreamService {
  _ControlledEventStreamService({this.disconnectStarted, this.disconnectGate});

  final Map<String, void Function(EventEnvelope event)> _onEventByScopeKey =
      <String, void Function(EventEnvelope event)>{};
  final Map<String, void Function()> _onDoneByScopeKey =
      <String, void Function()>{};
  final Completer<void>? disconnectStarted;
  final Completer<void>? disconnectGate;
  final List<String> connectedScopeKeys = <String>[];
  int disconnectCount = 0;

  @override
  Future<void> connect({
    required ServerProfile profile,
    required ProjectTarget project,
    required void Function(EventEnvelope event) onEvent,
    void Function()? onDone,
    void Function(Object error, StackTrace stackTrace)? onError,
  }) async {
    final scopeKey = _scopeKeyFor(profile, project);
    connectedScopeKeys.add(scopeKey);
    _onEventByScopeKey[scopeKey] = onEvent;
    if (onDone != null) {
      _onDoneByScopeKey[scopeKey] = onDone;
    }
  }

  @override
  Future<void> disconnect() async {
    disconnectCount += 1;
    _completeIfPending(disconnectStarted);
    final gate = disconnectGate;
    if (gate != null) {
      await gate.future;
    }
  }

  void emitToScope(
    ServerProfile profile,
    ProjectTarget project,
    EventEnvelope event,
  ) {
    _onEventByScopeKey[_scopeKeyFor(profile, project)]?.call(event);
  }

  void emitDoneToScope(ServerProfile profile, ProjectTarget project) {
    _onDoneByScopeKey[_scopeKeyFor(profile, project)]?.call();
  }

  @override
  void dispose() {}
}

class _ControlledTerminalService extends TerminalService {
  _ControlledTerminalService({
    Map<String, ShellCommandResult>? resultsByScopeSessionKey,
    Map<String, Completer<void>>? gateByScopeSessionKey,
    Map<String, Completer<void>>? startedByScopeSessionKey,
  }) : resultsByScopeSessionKey =
           resultsByScopeSessionKey ?? const <String, ShellCommandResult>{},
       gateByScopeSessionKey =
           gateByScopeSessionKey ?? const <String, Completer<void>>{},
       startedByScopeSessionKey =
           startedByScopeSessionKey ?? const <String, Completer<void>>{};

  final Map<String, ShellCommandResult> resultsByScopeSessionKey;
  final Map<String, Completer<void>> gateByScopeSessionKey;
  final Map<String, Completer<void>> startedByScopeSessionKey;

  @override
  Future<ShellCommandResult> runShellCommand({
    required ServerProfile profile,
    required ProjectTarget project,
    required String sessionId,
    required String command,
    String agent = 'build',
  }) async {
    final scopeSessionKey = _scopeSessionKey(profile, project, sessionId);
    _completeIfPending(startedByScopeSessionKey[scopeSessionKey]);
    final gate = gateByScopeSessionKey[scopeSessionKey];
    if (gate != null) {
      await gate.future;
    }
    return resultsByScopeSessionKey[scopeSessionKey] ??
        ShellCommandResult(
          messageId: 'message-$command',
          sessionId: sessionId,
          modelId: 'demo-model',
          providerId: 'demo-provider',
        );
  }

  @override
  void dispose() {}
}

class _DisposableChatService extends ChatService {
  bool disposed = false;

  @override
  void dispose() {
    disposed = true;
  }
}

class _DisposableTodoService extends TodoService {
  bool disposed = false;

  @override
  void dispose() {
    disposed = true;
  }
}

class _PumpingChatService extends ChatService {
  _PumpingChatService(this.onFetchBundle);

  final void Function() onFetchBundle;

  @override
  Future<ChatSessionBundle> fetchBundle({
    required ServerProfile profile,
    required ProjectTarget project,
    bool includeSelectedSessionMessages = true,
  }) async {
    onFetchBundle();
    return const ChatSessionBundle(
      sessions: <SessionSummary>[],
      statuses: <String, SessionStatusSummary>{},
      messages: <ChatMessage>[],
    );
  }
}
