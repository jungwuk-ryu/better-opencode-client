import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile_remote/src/core/connection/connection_models.dart';
import 'package:opencode_mobile_remote/src/features/files/file_models.dart';
import 'package:opencode_mobile_remote/src/features/files/review_diff_service.dart';
import 'package:opencode_mobile_remote/src/features/projects/project_models.dart';
import 'package:opencode_mobile_remote/src/features/terminal/pty_models.dart';
import 'package:opencode_mobile_remote/src/features/terminal/pty_service.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  test('builds a safe review diff command', () {
    final command = buildReviewDiffCommand(
      const FileStatusSummary(
        path: "docs/it's here.md",
        status: 'modified',
        added: 2,
        removed: 1,
      ),
    );

    expect(command, contains('git -c color.ui=never --no-pager diff'));
    expect(command, contains("'docs/it'\"'\"'s here.md'"));
    expect(command, contains('diff --cached --'));
    expect(command, contains('diff --no-index -- /dev/null'));
  });

  test('fetches diff output through an ephemeral PTY session', () async {
    final ptyService = _FakePtyService(
      events: <dynamic>[
        'diff --git a/README.md b/README.md\n',
        utf8.encode('@@ -1 +1 @@\n-Old\n+New\n'),
        <int>[0, ...utf8.encode('{"cursor":42}')],
      ],
    );
    final service = ReviewDiffService(
      ptyService: ptyService,
      timeout: const Duration(seconds: 1),
    );

    final diff = await service.fetchDiff(
      profile: const ServerProfile(
        id: 'server',
        label: 'Mock',
        baseUrl: 'http://localhost:4096',
      ),
      project: const ProjectTarget(directory: '/workspace/demo', label: 'Demo'),
      status: const FileStatusSummary(
        path: 'README.md',
        status: 'modified',
        added: 1,
        removed: 1,
      ),
    );

    expect(diff.path, 'README.md');
    expect(diff.content, contains('diff --git a/README.md b/README.md'));
    expect(diff.content, contains('+New'));
    expect(ptyService.createdCommand, '/usr/bin/env');
    expect(ptyService.createdArgs?.take(2).toList(), <String>['sh', '-lc']);
    expect(ptyService.removedIds, <String>['pty_review']);
  });
}

class _FakePtyService extends PtyService {
  _FakePtyService({required this.events});

  final List<dynamic> events;
  String? createdCommand;
  List<String>? createdArgs;
  final List<String> removedIds = <String>[];

  @override
  Future<PtySessionInfo> createSession({
    required ServerProfile profile,
    required String directory,
    String? title,
    String? cwd,
    String? command,
    List<String>? args,
    Map<String, String>? env,
  }) async {
    createdCommand = command;
    createdArgs = args;
    return const PtySessionInfo(
      id: 'pty_review',
      title: 'Review Diff',
      command: '/usr/bin/env',
      args: <String>['sh', '-lc', 'echo diff'],
      cwd: '/workspace/demo',
      status: PtySessionStatus.running,
      pid: 4242,
    );
  }

  @override
  WebSocketChannel connectSession({
    required ServerProfile profile,
    required String directory,
    required String ptyId,
    int? cursor,
  }) {
    return _FakeWebSocketChannel(events);
  }

  @override
  Future<void> removeSession({
    required ServerProfile profile,
    required String directory,
    required String ptyId,
  }) async {
    removedIds.add(ptyId);
  }
}

class _FakeWebSocketChannel implements WebSocketChannel {
  _FakeWebSocketChannel(this.events) {
    scheduleMicrotask(() async {
      for (final event in events) {
        _controller.add(event);
      }
      await _controller.close();
    });
  }

  final List<dynamic> events;
  final StreamController<dynamic> _controller = StreamController<dynamic>();
  final _FakeWebSocketSink _sink = _FakeWebSocketSink();

  @override
  Stream<dynamic> get stream => _controller.stream;

  @override
  WebSocketSink get sink => _sink;

  @override
  Future<void> get ready => Future<void>.value();

  @override
  String? get protocol => null;

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return super.noSuchMethod(invocation);
  }
}

class _FakeWebSocketSink implements WebSocketSink {
  final Completer<void> _done = Completer<void>();

  @override
  Future<void> addStream(Stream<dynamic> stream) async {
    await for (final _ in stream) {}
  }

  @override
  Future<void> close([int? closeCode, String? closeReason]) {
    if (!_done.isCompleted) {
      _done.complete();
    }
    return Future<void>.value();
  }

  @override
  Future<void> get done => _done.future;

  @override
  void add(dynamic data) {}

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  int? get closeCode => null;

  String? get closeReason => null;
}
