import 'dart:convert';

import '../../core/connection/connection_models.dart';
import '../chat/chat_models.dart';
import '../chat/chat_service.dart';
import 'project_git_models.dart';
import 'project_models.dart';
import '../terminal/terminal_service.dart';

const String _repoShellExitMarker = '__BOC_EXIT__=';

class ProjectGitService {
  ProjectGitService({
    TerminalService? terminalService,
    ChatService? chatService,
  }) : _terminalService = terminalService ?? TerminalService(),
       _chatService = chatService ?? ChatService();

  final TerminalService _terminalService;
  final ChatService _chatService;

  Future<RepoStatusSnapshot> loadStatus({
    required ServerProfile profile,
    required ProjectTarget project,
    required String sessionId,
  }) async {
    final statusResult = await runCommand(
      profile: profile,
      project: project,
      sessionId: sessionId,
      script: 'git status --short --branch',
    );
    final snapshot = parseRepoStatusOutput(statusResult.output).copyWith(
      generatedAt: DateTime.now(),
      errorMessage: statusResult.success ? null : statusResult.output.trim(),
      clearErrorMessage: statusResult.success,
    );
    if (!snapshot.hasGit || !statusResult.success) {
      return snapshot;
    }

    final prResult = await runCommand(
      profile: profile,
      project: project,
      sessionId: sessionId,
      script:
          'if command -v gh >/dev/null 2>&1; then '
          'gh pr view --json number,title,url,state,reviewDecision,baseRefName,headRefName,statusCheckRollup 2>/dev/null; '
          'fi',
    );
    final pullRequest = parseRepoPullRequestSummaryOutput(prResult.output);
    return snapshot.copyWith(
      pullRequest: pullRequest,
      clearPullRequest: pullRequest == null,
    );
  }

  Future<List<RepoBranchOption>> loadBranches({
    required ServerProfile profile,
    required ProjectTarget project,
    required String sessionId,
  }) async {
    final result = await runCommand(
      profile: profile,
      project: project,
      sessionId: sessionId,
      script:
          "git branch --format='%(HEAD)|%(refname:short)|%(upstream:short)|%(upstream:track)'",
    );
    if (!result.success) {
      return const <RepoBranchOption>[];
    }
    return parseRepoBranchOptionsOutput(result.output);
  }

  Future<RepoActionResult> stageFile({
    required ServerProfile profile,
    required ProjectTarget project,
    required String sessionId,
    required String path,
  }) {
    return runCommand(
      profile: profile,
      project: project,
      sessionId: sessionId,
      script: 'git add -- ${_shellQuote(path)}',
    );
  }

  Future<RepoActionResult> unstageFile({
    required ServerProfile profile,
    required ProjectTarget project,
    required String sessionId,
    required String path,
  }) {
    return runCommand(
      profile: profile,
      project: project,
      sessionId: sessionId,
      script: 'git restore --staged -- ${_shellQuote(path)}',
    );
  }

  Future<RepoActionResult> stageAll({
    required ServerProfile profile,
    required ProjectTarget project,
    required String sessionId,
  }) {
    return runCommand(
      profile: profile,
      project: project,
      sessionId: sessionId,
      script: 'git add -A',
    );
  }

  Future<RepoActionResult> commit({
    required ServerProfile profile,
    required ProjectTarget project,
    required String sessionId,
    required String title,
    String body = '',
  }) {
    final normalizedTitle = title.trim();
    final normalizedBody = body.trim();
    final script = normalizedBody.isEmpty
        ? 'git commit -m ${_shellQuote(normalizedTitle)}'
        : 'git commit -m ${_shellQuote(normalizedTitle)} -m ${_shellQuote(normalizedBody)}';
    return runCommand(
      profile: profile,
      project: project,
      sessionId: sessionId,
      script: script,
    );
  }

  Future<RepoActionResult> pull({
    required ServerProfile profile,
    required ProjectTarget project,
    required String sessionId,
  }) {
    return runCommand(
      profile: profile,
      project: project,
      sessionId: sessionId,
      script: 'git pull --ff-only',
    );
  }

  Future<RepoActionResult> push({
    required ServerProfile profile,
    required ProjectTarget project,
    required String sessionId,
  }) {
    return runCommand(
      profile: profile,
      project: project,
      sessionId: sessionId,
      script: 'git push',
    );
  }

  Future<RepoActionResult> switchBranch({
    required ServerProfile profile,
    required ProjectTarget project,
    required String sessionId,
    required String branchName,
  }) {
    return runCommand(
      profile: profile,
      project: project,
      sessionId: sessionId,
      script: 'git switch ${_shellQuote(branchName.trim())}',
    );
  }

  Future<RepoActionResult> createBranch({
    required ServerProfile profile,
    required ProjectTarget project,
    required String sessionId,
    required String branchName,
  }) {
    return runCommand(
      profile: profile,
      project: project,
      sessionId: sessionId,
      script: 'git switch -c ${_shellQuote(branchName.trim())}',
    );
  }

  Future<RepoActionResult> runCommand({
    required ServerProfile profile,
    required ProjectTarget project,
    required String sessionId,
    required String script,
  }) async {
    final originalScript = script.trim();
    final result = await _terminalService.runShellCommand(
      profile: profile,
      project: project,
      sessionId: sessionId,
      command: _wrapShellScript(originalScript),
    );
    final page = await _chatService.fetchMessagesPage(
      profile: profile,
      project: project,
      sessionId: sessionId,
      limit: ChatService.defaultSessionHistoryPageSize,
    );
    final rawOutput = _findShellOutputForMessage(page.messages, result.messageId);
    final capture = parseRepoShellCapture(rawOutput);
    return RepoActionResult(
      command: originalScript,
      output: capture.output.trim(),
      exitCode: capture.exitCode,
    );
  }

  void dispose() {
    _terminalService.dispose();
  }
}

({String output, int exitCode}) parseRepoShellCapture(String rawOutput) {
  final normalized = rawOutput.replaceAll('\r\n', '\n').trimRight();
  final markerIndex = normalized.lastIndexOf(_repoShellExitMarker);
  if (markerIndex == -1) {
    return (output: normalized, exitCode: normalized.isEmpty ? 0 : 1);
  }
  final output = normalized.substring(0, markerIndex).trimRight();
  final markerValue = normalized.substring(
    markerIndex + _repoShellExitMarker.length,
  );
  final exitCode = int.tryParse(markerValue.trim()) ?? 1;
  return (output: output, exitCode: exitCode);
}

RepoStatusSnapshot parseRepoStatusOutput(String output) {
  final normalized = output.replaceAll('\r\n', '\n').trim();
  if (normalized.isEmpty) {
    return RepoStatusSnapshot.empty();
  }

  final lower = normalized.toLowerCase();
  if (lower.contains('not a git repository')) {
    return RepoStatusSnapshot.empty(errorMessage: normalized);
  }

  final lines = normalized
      .split('\n')
      .map((line) => line.trimRight())
      .where((line) => line.isNotEmpty)
      .toList(growable: false);
  if (lines.isEmpty) {
    return RepoStatusSnapshot.empty();
  }

  final headerLine = lines.first.startsWith('## ') ? lines.first : '';
  final parsedHeader = _parseRepoStatusHeader(headerLine);
  final files = lines
      .skip(headerLine.isEmpty ? 0 : 1)
      .map(_parseRepoChangedFileLine)
      .whereType<RepoChangedFile>()
      .toList(growable: false);
  return RepoStatusSnapshot(
    hasGit: true,
    currentBranch: parsedHeader.branch,
    rawHeader: headerLine,
    upstreamBranch: parsedHeader.upstream,
    ahead: parsedHeader.ahead,
    behind: parsedHeader.behind,
    changedFiles: List<RepoChangedFile>.unmodifiable(files),
    generatedAt: DateTime.now(),
  );
}

List<RepoBranchOption> parseRepoBranchOptionsOutput(String output) {
  final normalized = output.replaceAll('\r\n', '\n').trim();
  if (normalized.isEmpty) {
    return const <RepoBranchOption>[];
  }
  return normalized
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .map((line) {
        final parts = line.split('|');
        final name = parts.length > 1 ? parts[1].trim() : '';
        if (name.isEmpty) {
          return null;
        }
        return RepoBranchOption(
          name: name,
          current: (parts.firstOrNull?.trim() ?? '') == '*',
          upstream: _normalizedOptional(parts.length > 2 ? parts[2] : null),
          tracking: _normalizedOptional(parts.length > 3 ? parts[3] : null),
        );
      })
      .whereType<RepoBranchOption>()
      .toList(growable: false);
}

RepoPullRequestSummary? parseRepoPullRequestSummaryOutput(String output) {
  final normalized = output.trim();
  if (normalized.isEmpty) {
    return null;
  }
  final decoded = _tryDecodeJsonMap(normalized);
  if (decoded == null) {
    return null;
  }
  final json = decoded;
  final rollup = (json['statusCheckRollup'] as List?) ?? const <Object?>[];
  var success = 0;
  var pending = 0;
  var failing = 0;
  for (final entry in rollup.whereType<Map>()) {
    final item = entry.cast<String, Object?>();
    final status = item['status']?.toString().trim().toLowerCase();
    final conclusion = item['conclusion']?.toString().trim().toLowerCase();
    if (status == 'pending' || status == 'queued' || status == 'in_progress') {
      pending += 1;
      continue;
    }
    if (conclusion == 'failure' ||
        conclusion == 'timed_out' ||
        conclusion == 'cancelled' ||
        conclusion == 'action_required' ||
        conclusion == 'startup_failure') {
      failing += 1;
      continue;
    }
    if (conclusion != null && conclusion.isNotEmpty) {
      success += 1;
    }
  }
  return RepoPullRequestSummary(
    available: true,
    number: (json['number'] as num?)?.toInt(),
    title: _normalizedOptional(json['title']?.toString()),
    url: _normalizedOptional(json['url']?.toString()),
    state: _normalizedOptional(json['state']?.toString()),
    reviewDecision: _normalizedOptional(json['reviewDecision']?.toString()),
    headBranch: _normalizedOptional(json['headRefName']?.toString()),
    baseBranch: _normalizedOptional(json['baseRefName']?.toString()),
    successfulChecks: success,
    pendingChecks: pending,
    failingChecks: failing,
  );
}

Map<String, Object?>? _tryDecodeJsonMap(String source) {
  try {
    final decoded = jsonDecode(source);
    if (decoded is! Map) {
      return null;
    }
    return decoded.cast<String, Object?>();
  } catch (_) {
    return null;
  }
}

String _wrapShellScript(String script) {
  final wrappedScript = '''
$script
code=\$?
printf '\\n$_repoShellExitMarker%s\\n' "\$code"
exit 0
''';
  return 'sh -lc ${_shellQuote(wrappedScript)}';
}

String _findShellOutputForMessage(List<ChatMessage> messages, String messageId) {
  for (final message in messages) {
    if (message.info.id != messageId) {
      continue;
    }
    for (final part in message.parts) {
      if (_isShellToolPart(part)) {
        return _shellToolOutput(part);
      }
    }
  }
  for (final message in messages) {
    for (final part in message.parts) {
      if (_isShellToolPart(part)) {
        return _shellToolOutput(part);
      }
    }
  }
  return '';
}

bool _isShellToolPart(ChatPart part) {
  return part.type == 'tool' && (part.tool?.trim().toLowerCase() ?? '') == 'bash';
}

String _shellToolOutput(ChatPart part) {
  final value =
      _nestedValue(part.metadata, const <String>['state', 'output']) ??
      _nestedValue(part.metadata, const <String>['output']) ??
      part.text;
  return _stringifyShellOutput(value);
}

Object? _nestedValue(Map<String, Object?> source, List<String> path) {
  Object? current = source;
  for (final segment in path) {
    if (current is! Map) {
      return null;
    }
    current = current[segment];
  }
  return current;
}

String _stringifyShellOutput(Object? value) {
  if (value == null) {
    return '';
  }
  final text = switch (value) {
    final String text => text,
    final Map value => const JsonEncoder.withIndent(
      '  ',
    ).convert(value.cast<Object?, Object?>()),
    final List value => const JsonEncoder.withIndent('  ').convert(value),
    _ => value.toString(),
  };
  return text.replaceAll(_ansiEscapePattern, '');
}

({String branch, String? upstream, int ahead, int behind}) _parseRepoStatusHeader(
  String headerLine,
) {
  var branch = '';
  String? upstream;
  var ahead = 0;
  var behind = 0;
  final body = headerLine.startsWith('## ')
      ? headerLine.substring(3).trim()
      : headerLine.trim();
  if (body.isEmpty) {
    return (branch: branch, upstream: upstream, ahead: ahead, behind: behind);
  }
  final noCommitsPrefix = 'No commits yet on ';
  if (body.startsWith(noCommitsPrefix)) {
    branch = body.substring(noCommitsPrefix.length).trim();
    return (branch: branch, upstream: upstream, ahead: ahead, behind: behind);
  }
  final statusIndex = body.indexOf(' [');
  final branchPart = statusIndex == -1 ? body : body.substring(0, statusIndex);
  final statusPart = statusIndex == -1 ? '' : body.substring(statusIndex + 2);
  if (branchPart.contains('...')) {
    final parts = branchPart.split('...');
    branch = parts.first.trim();
    upstream = _normalizedOptional(parts.length > 1 ? parts[1] : null);
  } else {
    branch = branchPart.trim();
  }
  final aheadMatch = RegExp(r'ahead (\d+)').firstMatch(statusPart);
  final behindMatch = RegExp(r'behind (\d+)').firstMatch(statusPart);
  ahead = int.tryParse(aheadMatch?.group(1) ?? '') ?? 0;
  behind = int.tryParse(behindMatch?.group(1) ?? '') ?? 0;
  return (branch: branch, upstream: upstream, ahead: ahead, behind: behind);
}

RepoChangedFile? _parseRepoChangedFileLine(String line) {
  if (line.length < 3) {
    return null;
  }
  final statusCode = line.substring(0, 2);
  final rawPath = line.substring(3).trim();
  if (rawPath.isEmpty) {
    return null;
  }
  final path = rawPath.contains(' -> ')
      ? rawPath.split(' -> ').last.trim()
      : rawPath;
  final x = statusCode[0];
  final y = statusCode[1];
  final conflictedCodes = <String>{'U', 'A', 'D'};
  final conflicted =
      statusCode == 'AA' ||
      statusCode == 'DD' ||
      statusCode == 'UU' ||
      conflictedCodes.contains(x) && conflictedCodes.contains(y);
  return RepoChangedFile(
    path: path,
    statusCode: statusCode,
    staged: x != ' ' && x != '?',
    unstaged: y != ' ',
    conflicted: conflicted,
    untracked: statusCode == '??',
  );
}

String _shellQuote(String value) {
  return "'${value.replaceAll("'", "'\"'\"'")}'";
}

String? _normalizedOptional(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}

final RegExp _ansiEscapePattern = RegExp(
  r'\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])',
);

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
