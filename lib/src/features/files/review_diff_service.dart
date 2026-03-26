import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/connection/connection_models.dart';
import '../../core/network/request_headers.dart';
import '../projects/project_models.dart';
import 'file_models.dart';

class ReviewDiffService {
  ReviewDiffService({http.Client? client})
    : _client = client ?? http.Client(),
      _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;

  Future<FileDiffSummary> fetchDiff({
    required ServerProfile profile,
    required ProjectTarget project,
    required String sessionId,
    required FileStatusSummary status,
  }) async {
    final uri = _buildUri(
      profile: profile,
      project: project,
      sessionId: sessionId,
    );
    final response = await _client.get(
      uri,
      headers: buildRequestHeaders(profile, accept: 'application/json'),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Request failed for $uri with status ${response.statusCode}.',
      );
    }

    final decoded = response.body.trim().isEmpty
        ? null
        : jsonDecode(response.body);
    final diffs = decoded is List
        ? decoded
              .whereType<Map>()
              .map(
                (item) =>
                    _ReviewSnapshotDiff.fromJson(item.cast<String, Object?>()),
              )
              .toList(growable: false)
        : const <_ReviewSnapshotDiff>[];

    final match = _findMatchingDiff(diffs, status.path);
    if (match == null) {
      return FileDiffSummary(path: status.path, content: '');
    }

    return FileDiffSummary(
      path: status.path,
      content: buildReviewUnifiedDiff(
        path: match.file,
        status: match.status ?? status.status,
        before: match.before,
        after: match.after,
      ),
    );
  }

  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }
}

Uri _buildUri({
  required ServerProfile profile,
  required ProjectTarget project,
  required String sessionId,
}) {
  final baseUri = profile.uriOrNull;
  if (baseUri == null) {
    throw const FormatException('Invalid server profile URL.');
  }

  final basePath = switch (baseUri.path) {
    '' => '/',
    final value when value.endsWith('/') => value,
    final value => '$value/',
  };

  return baseUri
      .replace(path: basePath)
      .resolve('session/$sessionId/diff')
      .replace(
        queryParameters: <String, String>{'directory': project.directory},
      );
}

String buildReviewUnifiedDiff({
  required String path,
  required String status,
  required String before,
  required String after,
}) {
  final normalizedPath = path.trim();
  final normalizedStatus = status.trim().toLowerCase();
  final beforeLines = _splitDiffLines(before);
  final afterLines = _splitDiffLines(after);

  final lines = <String>[
    'diff --git a/$normalizedPath b/$normalizedPath',
    if (normalizedStatus == 'added') 'new file mode 100644',
    if (normalizedStatus == 'deleted') 'deleted file mode 100644',
    '--- ${normalizedStatus == 'added' ? '/dev/null' : 'a/$normalizedPath'}',
    '+++ ${normalizedStatus == 'deleted' ? '/dev/null' : 'b/$normalizedPath'}',
    ..._buildUnifiedHunks(beforeLines, afterLines),
  ];

  return lines.join('\n').trimRight();
}

_ReviewSnapshotDiff? _findMatchingDiff(
  List<_ReviewSnapshotDiff> diffs,
  String path,
) {
  final normalizedTarget = _normalizeDiffPath(path);
  for (final diff in diffs) {
    final normalized = _normalizeDiffPath(diff.file);
    if (normalized == normalizedTarget ||
        normalized.endsWith('/$normalizedTarget') ||
        normalizedTarget.endsWith('/$normalized')) {
      return diff;
    }
  }
  return null;
}

String _normalizeDiffPath(String value) {
  var normalized = value.trim().replaceAll('\\', '/');
  while (normalized.startsWith('./')) {
    normalized = normalized.substring(2);
  }
  if (normalized.startsWith('/')) {
    normalized = normalized.substring(1);
  }
  return normalized;
}

List<String> _splitDiffLines(String value) {
  if (value.isEmpty) {
    return const <String>[];
  }
  final normalized = value.replaceAll('\r\n', '\n');
  final lines = normalized.split('\n');
  if (lines.isNotEmpty && lines.last.isEmpty) {
    return lines.sublist(0, lines.length - 1);
  }
  return lines;
}

List<String> _buildUnifiedHunks(
  List<String> beforeLines,
  List<String> afterLines,
) {
  final ops = _buildDiffOps(beforeLines, afterLines);
  final changedIndexes = <int>[];
  for (var index = 0; index < ops.length; index += 1) {
    if (ops[index].kind != _ReviewDiffOpKind.equal) {
      changedIndexes.add(index);
    }
  }
  if (changedIndexes.isEmpty) {
    return const <String>[];
  }

  final ranges = <_ReviewDiffRange>[];
  var start = _rangeStart(changedIndexes.first, ops.length);
  var end = _rangeEnd(changedIndexes.first, ops.length);
  for (final changedIndex in changedIndexes.skip(1)) {
    final nextStart = _rangeStart(changedIndex, ops.length);
    final nextEnd = _rangeEnd(changedIndex, ops.length);
    if (nextStart <= end + 1) {
      end = nextEnd;
      continue;
    }
    ranges.add(_ReviewDiffRange(start: start, end: end));
    start = nextStart;
    end = nextEnd;
  }
  ranges.add(_ReviewDiffRange(start: start, end: end));

  final lines = <String>[];
  for (final range in ranges) {
    final hunk = ops.sublist(range.start, range.end + 1);
    var beforeStart = hunk.first.beforeCursor;
    var afterStart = hunk.first.afterCursor;
    var beforeCount = 0;
    var afterCount = 0;
    for (final op in hunk) {
      if (op.kind != _ReviewDiffOpKind.insert) {
        beforeCount += 1;
      }
      if (op.kind != _ReviewDiffOpKind.delete) {
        afterCount += 1;
      }
    }
    if (beforeCount == 0) {
      beforeStart = beforeStart > 0 ? beforeStart - 1 : 0;
    }
    if (afterCount == 0) {
      afterStart = afterStart > 0 ? afterStart - 1 : 0;
    }
    lines.add(
      '@@ -${_formatUnifiedRange(beforeStart, beforeCount)} '
      '+${_formatUnifiedRange(afterStart, afterCount)} @@',
    );
    for (final op in hunk) {
      final prefix = switch (op.kind) {
        _ReviewDiffOpKind.equal => ' ',
        _ReviewDiffOpKind.delete => '-',
        _ReviewDiffOpKind.insert => '+',
      };
      lines.add('$prefix${op.line}');
    }
  }
  return lines;
}

List<_ReviewDiffOp> _buildDiffOps(
  List<String> beforeLines,
  List<String> afterLines,
) {
  final ops = <_ReviewDiffOp>[];
  var beforeCursor = 1;
  var afterCursor = 1;

  void append(_ReviewDiffOpKind kind, String line) {
    ops.add(
      _ReviewDiffOp(
        kind: kind,
        line: line,
        beforeCursor: beforeCursor,
        afterCursor: afterCursor,
      ),
    );
    if (kind != _ReviewDiffOpKind.insert) {
      beforeCursor += 1;
    }
    if (kind != _ReviewDiffOpKind.delete) {
      afterCursor += 1;
    }
  }

  var prefix = 0;
  while (prefix < beforeLines.length &&
      prefix < afterLines.length &&
      beforeLines[prefix] == afterLines[prefix]) {
    append(_ReviewDiffOpKind.equal, beforeLines[prefix]);
    prefix += 1;
  }

  var beforeSuffix = beforeLines.length;
  var afterSuffix = afterLines.length;
  while (beforeSuffix > prefix &&
      afterSuffix > prefix &&
      beforeLines[beforeSuffix - 1] == afterLines[afterSuffix - 1]) {
    beforeSuffix -= 1;
    afterSuffix -= 1;
  }

  final middleBefore = beforeLines.sublist(prefix, beforeSuffix);
  final middleAfter = afterLines.sublist(prefix, afterSuffix);
  for (final op in _buildMiddleOps(middleBefore, middleAfter)) {
    append(op.kind, op.line);
  }
  for (var index = beforeSuffix; index < beforeLines.length; index += 1) {
    append(_ReviewDiffOpKind.equal, beforeLines[index]);
  }

  return ops;
}

List<_ReviewMiddleOp> _buildMiddleOps(
  List<String> beforeLines,
  List<String> afterLines,
) {
  final beforeCount = beforeLines.length;
  final afterCount = afterLines.length;
  if (beforeCount == 0 && afterCount == 0) {
    return const <_ReviewMiddleOp>[];
  }

  const maxMatrixSize = 120000;
  if (beforeCount * afterCount > maxMatrixSize) {
    return <_ReviewMiddleOp>[
      ...beforeLines.map(
        (line) => _ReviewMiddleOp(kind: _ReviewDiffOpKind.delete, line: line),
      ),
      ...afterLines.map(
        (line) => _ReviewMiddleOp(kind: _ReviewDiffOpKind.insert, line: line),
      ),
    ];
  }

  final matrix = List<List<int>>.generate(
    beforeCount + 1,
    (_) => List<int>.filled(afterCount + 1, 0),
    growable: false,
  );
  for (var i = beforeCount - 1; i >= 0; i -= 1) {
    for (var j = afterCount - 1; j >= 0; j -= 1) {
      if (beforeLines[i] == afterLines[j]) {
        matrix[i][j] = matrix[i + 1][j + 1] + 1;
      } else {
        matrix[i][j] = matrix[i + 1][j] >= matrix[i][j + 1]
            ? matrix[i + 1][j]
            : matrix[i][j + 1];
      }
    }
  }

  final ops = <_ReviewMiddleOp>[];
  var beforeIndex = 0;
  var afterIndex = 0;
  while (beforeIndex < beforeCount && afterIndex < afterCount) {
    if (beforeLines[beforeIndex] == afterLines[afterIndex]) {
      ops.add(
        _ReviewMiddleOp(
          kind: _ReviewDiffOpKind.equal,
          line: beforeLines[beforeIndex],
        ),
      );
      beforeIndex += 1;
      afterIndex += 1;
      continue;
    }
    if (matrix[beforeIndex + 1][afterIndex] >=
        matrix[beforeIndex][afterIndex + 1]) {
      ops.add(
        _ReviewMiddleOp(
          kind: _ReviewDiffOpKind.delete,
          line: beforeLines[beforeIndex],
        ),
      );
      beforeIndex += 1;
      continue;
    }
    ops.add(
      _ReviewMiddleOp(
        kind: _ReviewDiffOpKind.insert,
        line: afterLines[afterIndex],
      ),
    );
    afterIndex += 1;
  }
  while (beforeIndex < beforeCount) {
    ops.add(
      _ReviewMiddleOp(
        kind: _ReviewDiffOpKind.delete,
        line: beforeLines[beforeIndex],
      ),
    );
    beforeIndex += 1;
  }
  while (afterIndex < afterCount) {
    ops.add(
      _ReviewMiddleOp(
        kind: _ReviewDiffOpKind.insert,
        line: afterLines[afterIndex],
      ),
    );
    afterIndex += 1;
  }
  return ops;
}

int _rangeStart(int changedIndex, int length) {
  final candidate = changedIndex - 3;
  return candidate < 0 ? 0 : candidate;
}

int _rangeEnd(int changedIndex, int length) {
  final candidate = changedIndex + 3;
  final maxIndex = length - 1;
  return candidate > maxIndex ? maxIndex : candidate;
}

String _formatUnifiedRange(int start, int count) {
  if (count == 1) {
    return '$start';
  }
  return '$start,$count';
}

class _ReviewSnapshotDiff {
  const _ReviewSnapshotDiff({
    required this.file,
    required this.before,
    required this.after,
    required this.additions,
    required this.deletions,
    required this.status,
  });

  final String file;
  final String before;
  final String after;
  final int additions;
  final int deletions;
  final String? status;

  factory _ReviewSnapshotDiff.fromJson(Map<String, Object?> json) {
    return _ReviewSnapshotDiff(
      file: (json['file'] as String?) ?? '',
      before: (json['before'] as String?) ?? '',
      after: (json['after'] as String?) ?? '',
      additions: (json['additions'] as num?)?.toInt() ?? 0,
      deletions: (json['deletions'] as num?)?.toInt() ?? 0,
      status: json['status'] as String?,
    );
  }
}

enum _ReviewDiffOpKind { equal, delete, insert }

class _ReviewMiddleOp {
  const _ReviewMiddleOp({required this.kind, required this.line});

  final _ReviewDiffOpKind kind;
  final String line;
}

class _ReviewDiffOp {
  const _ReviewDiffOp({
    required this.kind,
    required this.line,
    required this.beforeCursor,
    required this.afterCursor,
  });

  final _ReviewDiffOpKind kind;
  final String line;
  final int beforeCursor;
  final int afterCursor;
}

class _ReviewDiffRange {
  const _ReviewDiffRange({required this.start, required this.end});

  final int start;
  final int end;
}
