import 'dart:async';
import 'dart:convert';

import '../../core/connection/connection_models.dart';
import '../projects/project_models.dart';
import '../terminal/pty_service.dart';
import 'file_models.dart';

class ReviewDiffService {
  ReviewDiffService({PtyService? ptyService, Duration? timeout})
    : _ptyService = ptyService ?? PtyService(),
      _timeout = timeout ?? const Duration(seconds: 8),
      _ownsPtyService = ptyService == null;

  final PtyService _ptyService;
  final Duration _timeout;
  final bool _ownsPtyService;

  Future<FileDiffSummary> fetchDiff({
    required ServerProfile profile,
    required ProjectTarget project,
    required FileStatusSummary status,
  }) async {
    final session = await _ptyService.createSession(
      profile: profile,
      directory: project.directory,
      title: 'Review Diff',
      cwd: project.directory,
      command: '/usr/bin/env',
      args: <String>['sh', '-lc', buildReviewDiffCommand(status)],
    );

    final channel = _ptyService.connectSession(
      profile: profile,
      directory: project.directory,
      ptyId: session.id,
    );

    final buffer = StringBuffer();
    final done = Completer<void>();
    StreamSubscription<dynamic>? subscription;
    Timer? timer;

    void finish() {
      if (!done.isCompleted) {
        done.complete();
      }
    }

    subscription = channel.stream.listen(
      (event) {
        if (event is String) {
          buffer.write(event);
          return;
        }
        if (event is List<int>) {
          if (event.isNotEmpty && event.first == 0) {
            return;
          }
          buffer.write(utf8.decode(event, allowMalformed: true));
        }
      },
      onDone: finish,
      onError: (Object error, StackTrace stackTrace) {
        if (!done.isCompleted) {
          done.completeError(error, stackTrace);
        }
      },
      cancelOnError: true,
    );

    timer = Timer(_timeout, finish);

    try {
      await channel.ready.timeout(_timeout);
      await done.future.timeout(_timeout, onTimeout: () {});
    } finally {
      timer.cancel();
      await subscription.cancel();
      await channel.sink.close();
      await _safeRemoveSession(
        profile: profile,
        directory: project.directory,
        ptyId: session.id,
      );
    }

    return FileDiffSummary(
      path: status.path,
      content: _normalizeDiffOutput(buffer.toString()),
    );
  }

  Future<void> _safeRemoveSession({
    required ServerProfile profile,
    required String directory,
    required String ptyId,
  }) async {
    try {
      await _ptyService.removeSession(
        profile: profile,
        directory: directory,
        ptyId: ptyId,
      );
    } catch (_) {}
  }

  void dispose() {
    if (_ownsPtyService) {
      _ptyService.dispose();
    }
  }
}

String buildReviewDiffCommand(FileStatusSummary status) {
  final path = _shellSingleQuote(status.path);
  return <String>[
    'git -c color.ui=never --no-pager diff --no-ext-diff --submodule=diff --cached -- $path || true',
    'git -c color.ui=never --no-pager diff --no-ext-diff --submodule=diff -- $path || true',
    'if [ -f $path ] && ! git ls-files --error-unmatch -- $path >/dev/null 2>&1; then git -c color.ui=never --no-pager diff --no-index -- /dev/null $path || true; fi',
  ].join('; ');
}

String _normalizeDiffOutput(String value) {
  return value.replaceAll('\r\n', '\n').trimRight();
}

String _shellSingleQuote(String value) {
  return "'${value.replaceAll("'", "'\"'\"'")}'";
}
