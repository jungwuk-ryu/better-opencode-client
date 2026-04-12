import 'package:flutter_test/flutter_test.dart';
import 'package:better_opencode_client/src/features/projects/project_git_service.dart';

void main() {
  test('parses git status porcelain output into repo snapshot', () {
    final snapshot = parseRepoStatusOutput('''
## feature/mobile...origin/feature/mobile [ahead 2, behind 1]
M  lib/src/app/app.dart
 M README.md
?? docs/quickstart-first-connection.md
UU lib/src/features/web_parity/workspace_screen.dart
''');

    expect(snapshot.hasGit, isTrue);
    expect(snapshot.currentBranch, 'feature/mobile');
    expect(snapshot.upstreamBranch, 'origin/feature/mobile');
    expect(snapshot.ahead, 2);
    expect(snapshot.behind, 1);
    expect(snapshot.changedFiles, hasLength(4));
    expect(snapshot.stagedCount, 1);
    expect(snapshot.unstagedCount, 3);
    expect(snapshot.untrackedCount, 1);
    expect(snapshot.conflictedCount, 1);
  });

  test('parses branch options from git branch format output', () {
    final branches = parseRepoBranchOptionsOutput('''
*|main|origin/main|[ahead 1]
 |feature/mobile|origin/feature/mobile|
''');

    expect(branches, hasLength(2));
    expect(branches.first.current, isTrue);
    expect(branches.first.name, 'main');
    expect(branches.last.name, 'feature/mobile');
    expect(branches.last.upstream, 'origin/feature/mobile');
  });

  test('parses pull request summary from gh json output', () {
    final summary = parseRepoPullRequestSummaryOutput('''
{"number":42,"title":"Mobile triage loop","url":"https://example.com/pr/42","state":"OPEN","reviewDecision":"REVIEW_REQUIRED","baseRefName":"main","headRefName":"feature/mobile","statusCheckRollup":[{"status":"COMPLETED","conclusion":"SUCCESS"},{"status":"PENDING","conclusion":null},{"status":"COMPLETED","conclusion":"FAILURE"}]}
''');

    expect(summary, isNotNull);
    expect(summary!.available, isTrue);
    expect(summary.number, 42);
    expect(summary.successfulChecks, 1);
    expect(summary.pendingChecks, 1);
    expect(summary.failingChecks, 1);
  });

  test('extracts shell exit marker from wrapped git output', () {
    final capture = parseRepoShellCapture('''
branch up to date
__BOC_EXIT__=0
''');

    expect(capture.output, 'branch up to date');
    expect(capture.exitCode, 0);
  });
}
