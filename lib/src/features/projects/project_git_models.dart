class RepoChangedFile {
  const RepoChangedFile({
    required this.path,
    required this.statusCode,
    required this.staged,
    required this.unstaged,
    required this.conflicted,
    required this.untracked,
  });

  final String path;
  final String statusCode;
  final bool staged;
  final bool unstaged;
  final bool conflicted;
  final bool untracked;

  String get statusLabel {
    if (conflicted) {
      return 'Conflict';
    }
    if (untracked) {
      return 'Untracked';
    }
    final code = statusCode.trim();
    return switch (code) {
      'A' || 'A ' || ' A' => 'Added',
      'D' || 'D ' || ' D' => 'Deleted',
      'R' || 'R ' || ' R' => 'Renamed',
      'C' || 'C ' || ' C' => 'Copied',
      'M' || 'M ' || ' M' || 'MM' => 'Modified',
      _ when staged && unstaged => 'Mixed',
      _ when staged => 'Staged',
      _ when unstaged => 'Modified',
      _ => 'Changed',
    };
  }
}

class RepoBranchOption {
  const RepoBranchOption({
    required this.name,
    required this.current,
    this.upstream,
    this.tracking,
  });

  final String name;
  final bool current;
  final String? upstream;
  final String? tracking;
}

class RepoPullRequestSummary {
  const RepoPullRequestSummary({
    required this.available,
    this.number,
    this.title,
    this.url,
    this.state,
    this.reviewDecision,
    this.headBranch,
    this.baseBranch,
    this.successfulChecks = 0,
    this.pendingChecks = 0,
    this.failingChecks = 0,
    this.unavailableReason,
  });

  final bool available;
  final int? number;
  final String? title;
  final String? url;
  final String? state;
  final String? reviewDecision;
  final String? headBranch;
  final String? baseBranch;
  final int successfulChecks;
  final int pendingChecks;
  final int failingChecks;
  final String? unavailableReason;

  int get totalChecks => successfulChecks + pendingChecks + failingChecks;
}

class RepoStatusSnapshot {
  const RepoStatusSnapshot({
    required this.hasGit,
    required this.currentBranch,
    required this.changedFiles,
    required this.generatedAt,
    this.rawHeader,
    this.upstreamBranch,
    this.ahead = 0,
    this.behind = 0,
    this.errorMessage,
    this.pullRequest,
  });

  final bool hasGit;
  final String currentBranch;
  final String? rawHeader;
  final String? upstreamBranch;
  final int ahead;
  final int behind;
  final List<RepoChangedFile> changedFiles;
  final DateTime generatedAt;
  final String? errorMessage;
  final RepoPullRequestSummary? pullRequest;

  bool get clean => changedFiles.isEmpty;
  int get stagedCount =>
      changedFiles.where((file) => file.staged && !file.conflicted).length;
  int get unstagedCount =>
      changedFiles
          .where((file) => file.unstaged || file.untracked)
          .length;
  int get conflictedCount =>
      changedFiles.where((file) => file.conflicted).length;
  int get untrackedCount =>
      changedFiles.where((file) => file.untracked).length;

  RepoStatusSnapshot copyWith({
    bool? hasGit,
    String? currentBranch,
    String? rawHeader,
    String? upstreamBranch,
    int? ahead,
    int? behind,
    List<RepoChangedFile>? changedFiles,
    DateTime? generatedAt,
    String? errorMessage,
    bool clearErrorMessage = false,
    RepoPullRequestSummary? pullRequest,
    bool clearPullRequest = false,
  }) {
    return RepoStatusSnapshot(
      hasGit: hasGit ?? this.hasGit,
      currentBranch: currentBranch ?? this.currentBranch,
      rawHeader: rawHeader ?? this.rawHeader,
      upstreamBranch: upstreamBranch ?? this.upstreamBranch,
      ahead: ahead ?? this.ahead,
      behind: behind ?? this.behind,
      changedFiles: changedFiles ?? this.changedFiles,
      generatedAt: generatedAt ?? this.generatedAt,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      pullRequest: clearPullRequest ? null : (pullRequest ?? this.pullRequest),
    );
  }

  factory RepoStatusSnapshot.empty({String? errorMessage}) {
    return RepoStatusSnapshot(
      hasGit: false,
      currentBranch: '',
      changedFiles: const <RepoChangedFile>[],
      generatedAt: DateTime.now(),
      errorMessage: errorMessage,
    );
  }
}

class RepoActionResult {
  const RepoActionResult({
    required this.command,
    required this.output,
    required this.exitCode,
  });

  final String command;
  final String output;
  final int exitCode;

  bool get success => exitCode == 0;
}
