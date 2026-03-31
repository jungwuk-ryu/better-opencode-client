import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:better_opencode_client/src/core/connection/connection_models.dart';
import 'package:better_opencode_client/src/design_system/app_theme.dart';
import 'package:better_opencode_client/src/features/terminal/pty_models.dart';
import 'package:better_opencode_client/src/features/terminal/pty_service.dart';
import 'package:better_opencode_client/src/features/terminal/pty_terminal_panel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  const profile = ServerProfile(
    id: 'server',
    label: 'Mock',
    baseUrl: 'http://localhost:3000',
  );
  const sessions = <PtySessionInfo>[
    PtySessionInfo(
      id: 'pty_1',
      title: 'Terminal 1',
      command: '/bin/zsh',
      args: <String>['-l'],
      cwd: '/workspace/demo',
      status: PtySessionStatus.running,
      pid: 1001,
    ),
    PtySessionInfo(
      id: 'pty_2',
      title: 'Terminal 2',
      command: '/bin/zsh',
      args: <String>['-l'],
      cwd: '/workspace/demo',
      status: PtySessionStatus.running,
      pid: 1002,
    ),
  ];

  testWidgets('keeps PTY connections alive when switching terminal tabs', (
    tester,
  ) async {
    final service = _FakePtyService();
    addTearDown(service.dispose);

    await tester.pumpWidget(
      _PtyPanelHarness(
        profile: profile,
        service: service,
        sessions: sessions,
        initialActiveSessionId: 'pty_1',
      ),
    );
    await tester.pump();

    expect(service.connectCount('pty_1'), 1);
    expect(service.connectCount('pty_2'), 0);

    await tester.tap(find.text('Terminal 2'));
    await tester.pump();

    expect(service.connectCount('pty_1'), 1);
    expect(service.connectCount('pty_2'), 1);

    await tester.tap(find.text('Terminal 1'));
    await tester.pump();

    expect(service.connectCount('pty_1'), 1);
    expect(service.connectCount('pty_2'), 1);
  });

  testWidgets('shows connection and live chips without overlapping', (
    tester,
  ) async {
    final service = _FakePtyService(
      readyById: <String, Future<void>>{'pty_1': Completer<void>().future},
    );
    addTearDown(service.dispose);

    await tester.pumpWidget(
      _PtyPanelHarness(
        profile: profile,
        service: service,
        sessions: sessions.take(1).toList(growable: false),
        initialActiveSessionId: 'pty_1',
      ),
    );
    await tester.pump();

    final connectingFinder = find.text('Connecting…');
    final liveFinder = find.text('live');

    expect(connectingFinder, findsOneWidget);
    expect(liveFinder, findsOneWidget);

    final connectingRect = tester.getRect(connectingFinder);
    final liveRect = tester.getRect(liveFinder);
    expect(connectingRect.overlaps(liveRect), isFalse);
  });

  testWidgets('can expand to fill the available height', (tester) async {
    final service = _FakePtyService();
    addTearDown(service.dispose);

    await tester.pumpWidget(
      _PtyPanelHarness(
        profile: profile,
        service: service,
        sessions: sessions,
        initialActiveSessionId: 'pty_1',
        width: 390,
        height: 520,
        expandToFill: true,
      ),
    );
    await tester.pump();

    expect(
      tester
          .getSize(
            find.byKey(const ValueKey<String>('pty-terminal-panel-frame')),
          )
          .height,
      greaterThan(440),
    );
  });
}

class _PtyPanelHarness extends StatefulWidget {
  const _PtyPanelHarness({
    required this.profile,
    required this.service,
    required this.sessions,
    required this.initialActiveSessionId,
    this.width = 1100,
    this.height = 420,
    this.expandToFill = false,
  });

  final ServerProfile profile;
  final PtyService service;
  final List<PtySessionInfo> sessions;
  final String initialActiveSessionId;
  final double width;
  final double height;
  final bool expandToFill;

  @override
  State<_PtyPanelHarness> createState() => _PtyPanelHarnessState();
}

class _PtyPanelHarnessState extends State<_PtyPanelHarness> {
  late String _activeSessionId;

  @override
  void initState() {
    super.initState();
    _activeSessionId = widget.initialActiveSessionId;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: widget.width,
            height: widget.height,
            child: PtyTerminalPanel(
              profile: widget.profile,
              directory: '/workspace/demo',
              service: widget.service,
              sessions: widget.sessions,
              activeSessionId: _activeSessionId,
              loading: false,
              creating: false,
              error: null,
              onSelectSession: (ptyId) {
                setState(() {
                  _activeSessionId = ptyId;
                });
              },
              onCreateSession: () {},
              onCloseSession: (_) {},
              onRetry: () {},
              onTitleChanged: (id, title) {},
              onSessionMissing: (_) {},
              expandToFill: widget.expandToFill,
            ),
          ),
        ),
      ),
    );
  }
}

class _FakePtyService extends PtyService {
  _FakePtyService({Map<String, Future<void>>? readyById})
    : _readyById = readyById ?? const <String, Future<void>>{};

  final Map<String, Future<void>> _readyById;
  final Map<String, int> _connectCounts = <String, int>{};
  final List<_FakeWebSocketChannel> _channels = <_FakeWebSocketChannel>[];

  int connectCount(String ptyId) => _connectCounts[ptyId] ?? 0;

  @override
  Future<PtySessionInfo?> getSession({
    required ServerProfile profile,
    required String directory,
    required String ptyId,
  }) async {
    return PtySessionInfo(
      id: ptyId,
      title: 'Terminal',
      command: '/bin/zsh',
      args: const <String>['-l'],
      cwd: directory,
      status: PtySessionStatus.running,
      pid: 1000,
    );
  }

  @override
  Future<PtySessionInfo> updateSession({
    required ServerProfile profile,
    required String directory,
    required String ptyId,
    String? title,
    PtySessionSize? size,
  }) async {
    return PtySessionInfo(
      id: ptyId,
      title: title ?? 'Terminal',
      command: '/bin/zsh',
      args: const <String>['-l'],
      cwd: directory,
      status: PtySessionStatus.running,
      pid: 1000,
    );
  }

  @override
  WebSocketChannel connectSession({
    required ServerProfile profile,
    required String directory,
    required String ptyId,
    int? cursor,
  }) {
    _connectCounts.update(ptyId, (count) => count + 1, ifAbsent: () => 1);
    final channel = _FakeWebSocketChannel(
      ready: _readyById[ptyId] ?? Future<void>.value(),
    );
    _channels.add(channel);
    return channel;
  }

  @override
  void dispose() {
    for (final channel in _channels) {
      channel.close();
    }
    super.dispose();
  }
}

class _FakeWebSocketChannel implements WebSocketChannel {
  _FakeWebSocketChannel({required Future<void> ready}) : _ready = ready;

  final StreamController<dynamic> _controller = StreamController<dynamic>();
  late final _FakeWebSocketSink _sink = _FakeWebSocketSink(_controller);
  final Future<void> _ready;

  @override
  Stream<dynamic> get stream => _controller.stream;

  @override
  WebSocketSink get sink => _sink;

  @override
  Future<void> get ready => _ready;

  @override
  String? get protocol => null;

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

  Future<void> close() => _sink.close();

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return super.noSuchMethod(invocation);
  }
}

class _FakeWebSocketSink implements WebSocketSink {
  _FakeWebSocketSink(this._controller);

  final StreamController<dynamic> _controller;
  final Completer<void> _done = Completer<void>();

  @override
  void add(dynamic data) {}

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream<dynamic> stream) async {
    await for (final _ in stream) {}
  }

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    if (!_controller.isClosed) {
      await _controller.close();
    }
    if (!_done.isCompleted) {
      _done.complete();
    }
  }

  @override
  Future<void> get done => _done.future;
}
