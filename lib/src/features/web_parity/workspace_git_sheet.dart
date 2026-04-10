import 'package:flutter/material.dart';

import '../../core/connection/connection_models.dart';
import '../../design_system/app_spacing.dart';
import '../../design_system/app_surface_decor.dart';
import '../../design_system/app_theme.dart';
import '../../i18n/web_parity_localizations.dart';
import '../projects/project_git_models.dart';
import '../projects/project_git_service.dart';
import '../projects/project_models.dart';

class WorkspaceGitSheet extends StatefulWidget {
  const WorkspaceGitSheet({
    required this.profile,
    required this.project,
    required this.sessionId,
    required this.service,
    required this.onOpenTerminalFallback,
    super.key,
  });

  final ServerProfile profile;
  final ProjectTarget project;
  final String? sessionId;
  final ProjectGitService service;
  final Future<void> Function() onOpenTerminalFallback;

  @override
  State<WorkspaceGitSheet> createState() => _WorkspaceGitSheetState();
}

class _WorkspaceGitSheetState extends State<WorkspaceGitSheet> {
  RepoStatusSnapshot? _snapshot;
  List<RepoBranchOption> _branches = const <RepoBranchOption>[];
  bool _loading = true;
  bool _runningAction = false;
  String? _error;

  String? get _sessionId {
    final value = widget.sessionId?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sessionId = _sessionId;
    if (sessionId == null) {
      setState(() {
        _loading = false;
        _error = 'Select a session before using Git workflow actions.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snapshot = await widget.service.loadStatus(
        profile: widget.profile,
        project: widget.project,
        sessionId: sessionId,
      );
      final branches = await widget.service.loadBranches(
        profile: widget.profile,
        project: widget.project,
        sessionId: sessionId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _snapshot = snapshot;
        _branches = branches;
        _loading = false;
        _error =
            snapshot.errorMessage?.trim().isNotEmpty == true && snapshot.hasGit
            ? snapshot.errorMessage
            : null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _runAction(
    Future<RepoActionResult> Function(String sessionId) action, {
    required String successMessage,
  }) async {
    final sessionId = _sessionId;
    if (sessionId == null || _runningAction) {
      return;
    }
    setState(() {
      _runningAction = true;
    });
    try {
      final result = await action(sessionId);
      if (!mounted) {
        return;
      }
      _showMessage(
        result.success
            ? successMessage
            : result.output.trim().isEmpty
            ? context.wp('The Git command did not finish successfully.')
            : result.output.trim(),
        error: !result.success,
      );
      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(error.toString(), error: true);
    } finally {
      if (mounted) {
        setState(() {
          _runningAction = false;
        });
      }
    }
  }

  Future<void> _showCommitComposer() async {
    final successMessage = context.wp(
      'Commit created and repository state refreshed.',
    );
    final request = await showDialog<_CommitRequest>(
      context: context,
      builder: (context) => const _CommitComposerDialog(),
    );
    if (!mounted) {
      return;
    }
    if (request == null || request.title.trim().isEmpty) {
      return;
    }
    await _runAction(
      (sessionId) => widget.service.commit(
        profile: widget.profile,
        project: widget.project,
        sessionId: sessionId,
        title: request.title,
        body: request.body,
      ),
      successMessage: successMessage,
    );
  }

  Future<void> _showBranchSheet() async {
    final sessionId = _sessionId;
    if (sessionId == null) {
      return;
    }
    final selection = await showModalBottomSheet<_BranchAction>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _BranchPickerSheet(branches: _branches),
    );
    if (!mounted) {
      return;
    }
    if (selection == null) {
      return;
    }
    final createMessage = context.wp(
      'Created and switched to "{branch}".',
      args: <String, Object?>{'branch': selection.name},
    );
    final switchMessage = context.wp(
      'Switched to "{branch}".',
      args: <String, Object?>{'branch': selection.name},
    );
    if (selection.createNew) {
      await _runAction(
        (sessionId) => widget.service.createBranch(
          profile: widget.profile,
          project: widget.project,
          sessionId: sessionId,
          branchName: selection.name,
        ),
        successMessage: createMessage,
      );
      return;
    }
    await _runAction(
      (sessionId) => widget.service.switchBranch(
        profile: widget.profile,
        project: widget.project,
        sessionId: sessionId,
        branchName: selection.name,
      ),
      successMessage: switchMessage,
    );
  }

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? Theme.of(context).colorScheme.error : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final snapshot = _snapshot;
    final viewInsets = MediaQuery.viewInsetsOf(context);
    return SafeArea(
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: EdgeInsets.only(bottom: viewInsets.bottom),
          child: AppGlassPanel(
            radius: AppSpacing.sheetRadius,
            tone: AppSurfaceTone.accent,
            blur: 24,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: surfaces.muted.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(
                        AppSpacing.pillRadius,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            context.wp('Git Workflow'),
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            context.wp(
                              'Review changes, stage files, commit, sync, and fall back to the terminal without leaving the app.',
                            ),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: surfaces.muted,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    IconButton(
                      onPressed: _runningAction || _loading ? null : _load,
                      style: IconButton.styleFrom(
                        backgroundColor: surfaces.panelRaised.withValues(
                          alpha: 0.72,
                        ),
                      ),
                      icon: const Icon(Icons.refresh_rounded),
                      tooltip: context.wp('Refresh'),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: IconButton.styleFrom(
                        backgroundColor: surfaces.panelRaised.withValues(
                          alpha: 0.72,
                        ),
                      ),
                      icon: const Icon(Icons.close_rounded),
                      tooltip: context.wp('Close'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                if (_loading)
                  const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_error != null && snapshot == null)
                  Expanded(
                    child: _GitEmptyState(
                      message: _error!,
                      onOpenTerminalFallback: widget.onOpenTerminalFallback,
                    ),
                  )
                else if (snapshot == null || !snapshot.hasGit)
                  Expanded(
                    child: _GitEmptyState(
                      message: snapshot?.errorMessage?.trim().isNotEmpty == true
                          ? snapshot!.errorMessage!
                          : context.wp(
                              'No Git repository was detected for this project yet.',
                            ),
                      onOpenTerminalFallback: widget.onOpenTerminalFallback,
                    ),
                  )
                else
                  Expanded(
                    child: ListView(
                      children: <Widget>[
                        _RepoSummaryCard(snapshot: snapshot),
                        if (snapshot.pullRequest != null) ...<Widget>[
                          const SizedBox(height: AppSpacing.md),
                          _RepoPullRequestCard(summary: snapshot.pullRequest!),
                        ],
                        const SizedBox(height: AppSpacing.md),
                        _GitActionRow(
                          running: _runningAction,
                          onStageAll: snapshot.clean
                              ? null
                              : () => _runAction(
                                  (sessionId) => widget.service.stageAll(
                                    profile: widget.profile,
                                    project: widget.project,
                                    sessionId: sessionId,
                                  ),
                                  successMessage: context.wp(
                                    'All changes were staged.',
                                  ),
                                ),
                          onCommit: snapshot.stagedCount == 0
                              ? null
                              : _showCommitComposer,
                          onPull: () => _runAction(
                            (sessionId) => widget.service.pull(
                              profile: widget.profile,
                              project: widget.project,
                              sessionId: sessionId,
                            ),
                            successMessage: context.wp(
                              'Pulled the latest remote changes.',
                            ),
                          ),
                          onPush: () => _runAction(
                            (sessionId) => widget.service.push(
                              profile: widget.profile,
                              project: widget.project,
                              sessionId: sessionId,
                            ),
                            successMessage: context.wp(
                              'Pushed the active branch.',
                            ),
                          ),
                          onBranches: _showBranchSheet,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                context.wp('Changed Files'),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            _RepoMeta(
                              label: context.wp(
                                '{count} total',
                                args: <String, Object?>{
                                  'count': snapshot.changedFiles.length,
                                },
                              ),
                              emphasized: snapshot.changedFiles.isNotEmpty,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        if (snapshot.changedFiles.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            decoration: appSoftCardDecoration(
                              context,
                              radius: 20,
                              muted: true,
                            ),
                            child: Text(
                              context.wp('The working tree is clean.'),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: surfaces.muted,
                              ),
                            ),
                          )
                        else
                          ...snapshot.changedFiles.map(
                            (file) => Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.sm,
                              ),
                              child: _RepoChangedFileTile(
                                file: file,
                                busy: _runningAction,
                                onToggleStage: () => _runAction(
                                  (sessionId) => file.staged
                                      ? widget.service.unstageFile(
                                          profile: widget.profile,
                                          project: widget.project,
                                          sessionId: sessionId,
                                          path: file.path,
                                        )
                                      : widget.service.stageFile(
                                          profile: widget.profile,
                                          project: widget.project,
                                          sessionId: sessionId,
                                          path: file.path,
                                        ),
                                  successMessage: file.staged
                                      ? context.wp(
                                          'Moved "{path}" back to unstaged changes.',
                                          args: <String, Object?>{
                                            'path': file.path,
                                          },
                                        )
                                      : context.wp(
                                          'Staged "{path}".',
                                          args: <String, Object?>{
                                            'path': file.path,
                                          },
                                        ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                if (!_loading) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: appSoftCardDecoration(
                      context,
                      radius: 20,
                      muted: true,
                    ),
                    child: OutlinedButton.icon(
                      onPressed: _runningAction
                          ? null
                          : () async {
                              Navigator.of(context).pop();
                              await widget.onOpenTerminalFallback();
                            },
                      icon: const Icon(Icons.terminal_rounded),
                      label: Text(context.wp('Open Terminal Fallback')),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RepoSummaryCard extends StatelessWidget {
  const _RepoSummaryCard({required this.snapshot});

  final RepoStatusSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: appSoftCardDecoration(
        context,
        radius: 24,
        tone: snapshot.conflictedCount > 0
            ? AppSurfaceTone.danger
            : snapshot.clean
            ? AppSurfaceTone.success
            : AppSurfaceTone.accent,
        emphasized: true,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  snapshot.currentBranch.isEmpty
                      ? context.wp('Detached or unknown branch')
                      : snapshot.currentBranch,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (snapshot.clean)
                _RepoBadge(label: context.wp('Clean'), success: true)
              else if (snapshot.conflictedCount > 0)
                _RepoBadge(
                  label: context.wp(
                    '{count} conflicts',
                    args: <String, Object?>{'count': snapshot.conflictedCount},
                  ),
                  danger: true,
                )
              else
                _RepoBadge(
                  label: context.wp(
                    '{count} changed',
                    args: <String, Object?>{
                      'count': snapshot.changedFiles.length,
                    },
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            snapshot.clean
                ? context.wp(
                    'Everything is aligned and ready for the next change.',
                  )
                : context.wp(
                    '{staged} staged • {unstaged} unstaged • {untracked} untracked',
                    args: <String, Object?>{
                      'staged': snapshot.stagedCount,
                      'unstaged': snapshot.unstagedCount,
                      'untracked': snapshot.untrackedCount,
                    },
                  ),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).extension<AppSurfaces>()!.muted,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              if ((snapshot.upstreamBranch ?? '').isNotEmpty)
                _RepoMeta(
                  label: context.wp(
                    'Upstream: {name}',
                    args: <String, Object?>{'name': snapshot.upstreamBranch!},
                  ),
                ),
              if (snapshot.ahead > 0)
                _RepoMeta(
                  label: context.wp(
                    'Ahead {count}',
                    args: <String, Object?>{'count': snapshot.ahead},
                  ),
                ),
              if (snapshot.behind > 0)
                _RepoMeta(
                  label: context.wp(
                    'Behind {count}',
                    args: <String, Object?>{'count': snapshot.behind},
                  ),
                ),
              _RepoMeta(
                label: context.wp(
                  'Staged {count}',
                  args: <String, Object?>{'count': snapshot.stagedCount},
                ),
              ),
              _RepoMeta(
                label: context.wp(
                  'Unstaged {count}',
                  args: <String, Object?>{'count': snapshot.unstagedCount},
                ),
              ),
              if (snapshot.untrackedCount > 0)
                _RepoMeta(
                  label: context.wp(
                    'Untracked {count}',
                    args: <String, Object?>{'count': snapshot.untrackedCount},
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RepoPullRequestCard extends StatelessWidget {
  const _RepoPullRequestCard({required this.summary});

  final RepoPullRequestSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: appSoftCardDecoration(
        context,
        radius: 24,
        tone: AppSurfaceTone.neutral,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            summary.available
                ? context.wp(
                    'Pull Request #{number}',
                    args: <String, Object?>{'number': summary.number ?? 0},
                  )
                : context.wp('Pull Request'),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            summary.title?.trim().isNotEmpty == true
                ? summary.title!
                : summary.unavailableReason?.trim().isNotEmpty == true
                ? summary.unavailableReason!
                : context.wp('No PR details are available yet.'),
            style: theme.textTheme.bodyMedium?.copyWith(color: surfaces.muted),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              if ((summary.state ?? '').isNotEmpty)
                _RepoMeta(label: summary.state!),
              if ((summary.reviewDecision ?? '').isNotEmpty)
                _RepoMeta(label: summary.reviewDecision!),
              if (summary.totalChecks > 0)
                _RepoMeta(
                  label: context.wp(
                    '{ok} ok • {pending} pending • {failed} failed',
                    args: <String, Object?>{
                      'ok': summary.successfulChecks,
                      'pending': summary.pendingChecks,
                      'failed': summary.failingChecks,
                    },
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RepoChangedFileTile extends StatelessWidget {
  const _RepoChangedFileTile({
    required this.file,
    required this.busy,
    required this.onToggleStage,
  });

  final RepoChangedFile file;
  final bool busy;
  final VoidCallback onToggleStage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final tone = file.conflicted
        ? AppSurfaceTone.danger
        : file.staged
        ? AppSurfaceTone.success
        : AppSurfaceTone.warning;
    final accent = file.conflicted
        ? theme.colorScheme.error
        : file.staged
        ? theme.colorScheme.primary
        : surfaces.warning;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: appSoftCardDecoration(
        context,
        radius: 20,
        tone: tone,
        selected: file.staged,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 420;
          final button = OutlinedButton.icon(
            onPressed: busy || file.conflicted ? null : onToggleStage,
            icon: Icon(
              file.staged ? Icons.undo_rounded : Icons.add_task_rounded,
            ),
            label: Text(
              file.staged ? context.wp('Unstage') : context.wp('Stage'),
            ),
          );
          final content = <Widget>[
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                file.conflicted
                    ? Icons.error_outline_rounded
                    : file.staged
                    ? Icons.task_alt_rounded
                    : Icons.edit_note_rounded,
                color: accent,
                size: 22,
              ),
            ),
            if (!stacked) const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (stacked) const SizedBox(height: AppSpacing.sm),
                  Text(
                    file.path,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    file.statusLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: surfaces.muted,
                    ),
                  ),
                ],
              ),
            ),
          ];
          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: content,
                ),
                const SizedBox(height: AppSpacing.sm),
                Align(alignment: Alignment.centerRight, child: button),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ...content,
              const SizedBox(width: AppSpacing.sm),
              button,
            ],
          );
        },
      ),
    );
  }
}

class _GitActionRow extends StatelessWidget {
  const _GitActionRow({
    required this.running,
    required this.onStageAll,
    required this.onCommit,
    required this.onPull,
    required this.onPush,
    required this.onBranches,
  });

  final bool running;
  final VoidCallback? onStageAll;
  final VoidCallback? onCommit;
  final VoidCallback? onPull;
  final VoidCallback? onPush;
  final VoidCallback? onBranches;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: appSoftCardDecoration(
        context,
        radius: 22,
        tone: AppSurfaceTone.accent,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            context.wp('Quick actions'),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            context.wp(
              'Stage, commit, sync, or move between branches without leaving the sheet.',
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: surfaces.muted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              FilledButton.tonalIcon(
                onPressed: running ? null : onStageAll,
                icon: const Icon(Icons.playlist_add_check_rounded),
                label: Text(context.wp('Stage All')),
              ),
              FilledButton.icon(
                onPressed: running ? null : onCommit,
                icon: const Icon(Icons.commit_rounded),
                label: Text(context.wp('Commit')),
              ),
              OutlinedButton.icon(
                onPressed: running ? null : onPull,
                icon: const Icon(Icons.download_rounded),
                label: Text(context.wp('Pull')),
              ),
              OutlinedButton.icon(
                onPressed: running ? null : onPush,
                icon: const Icon(Icons.upload_rounded),
                label: Text(context.wp('Push')),
              ),
              FilledButton.tonalIcon(
                onPressed: running ? null : onBranches,
                icon: const Icon(Icons.alt_route_rounded),
                label: Text(context.wp('Branches')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GitEmptyState extends StatelessWidget {
  const _GitEmptyState({
    required this.message,
    required this.onOpenTerminalFallback,
  });

  final String message;
  final Future<void> Function() onOpenTerminalFallback;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: appSoftCardDecoration(context, radius: 24, muted: true),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                Icons.commit_rounded,
                size: 28,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: surfaces.muted,
                height: 1.45,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.tonalIcon(
              onPressed: onOpenTerminalFallback,
              icon: const Icon(Icons.terminal_rounded),
              label: Text(context.wp('Use Terminal Instead')),
            ),
          ],
        ),
      ),
    );
  }
}

class _RepoBadge extends StatelessWidget {
  const _RepoBadge({
    required this.label,
    this.danger = false,
    this.success = false,
  });

  final String label;
  final bool danger;
  final bool success;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final color = danger
        ? theme.colorScheme.error
        : success
        ? surfaces.success
        : theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _RepoMeta extends StatelessWidget {
  const _RepoMeta({required this.label, this.emphasized = false});

  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: emphasized
            ? surfaces.panelRaised.withValues(alpha: 0.92)
            : surfaces.panel.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
        border: Border.all(color: surfaces.lineSoft),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          fontWeight: emphasized ? FontWeight.w700 : FontWeight.w600,
        ),
      ),
    );
  }
}

class _CommitRequest {
  const _CommitRequest({required this.title, required this.body});

  final String title;
  final String body;
}

class _CommitComposerDialog extends StatefulWidget {
  const _CommitComposerDialog();

  @override
  State<_CommitComposerDialog> createState() => _CommitComposerDialogState();
}

class _CommitComposerDialogState extends State<_CommitComposerDialog> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        context.wp('Create Commit'),
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: context.wp('Title'),
                hintText: context.wp('Summarize the change'),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _bodyController,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: context.wp('Body'),
                hintText: context.wp('Optional details for the commit body'),
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.wp('Cancel')),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop(
              _CommitRequest(
                title: _titleController.text,
                body: _bodyController.text,
              ),
            );
          },
          child: Text(context.wp('Commit')),
        ),
      ],
    );
  }
}

class _BranchAction {
  const _BranchAction({required this.name, this.createNew = false});

  final String name;
  final bool createNew;
}

class _BranchPickerSheet extends StatefulWidget {
  const _BranchPickerSheet({required this.branches});

  final List<RepoBranchOption> branches;

  @override
  State<_BranchPickerSheet> createState() => _BranchPickerSheetState();
}

class _BranchPickerSheetState extends State<_BranchPickerSheet> {
  final TextEditingController _branchController = TextEditingController();

  @override
  void dispose() {
    _branchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    return SafeArea(
      child: AppGlassPanel(
        radius: AppSpacing.sheetRadius,
        tone: AppSurfaceTone.accent,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: surfaces.muted.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              context.wp('Branches'),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              context.wp(
                'Switch quickly or start a fresh branch for the current session.',
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: surfaces.muted,
                height: 1.45,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: ListView(
                children: <Widget>[
                  ...widget.branches.map(
                    (branch) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: appSoftCardDecoration(
                          context,
                          radius: 18,
                          tone: branch.current
                              ? AppSurfaceTone.accent
                              : AppSurfaceTone.neutral,
                          selected: branch.current,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color:
                                    (branch.current
                                            ? theme.colorScheme.primary
                                            : surfaces.muted)
                                        .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                branch.current
                                    ? Icons.radio_button_checked_rounded
                                    : Icons.alt_route_rounded,
                                color: branch.current
                                    ? theme.colorScheme.primary
                                    : surfaces.muted,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    branch.name,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (branch.upstream?.trim().isNotEmpty ==
                                      true) ...<Widget>[
                                    const SizedBox(height: AppSpacing.xxs),
                                    Text(
                                      branch.upstream!,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(color: surfaces.muted),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            branch.current
                                ? _RepoBadge(
                                    label: context.wp('Current'),
                                    success: true,
                                  )
                                : FilledButton.tonal(
                                    onPressed: () {
                                      Navigator.of(
                                        context,
                                      ).pop(_BranchAction(name: branch.name));
                                    },
                                    child: Text(context.wp('Switch')),
                                  ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: appSoftCardDecoration(
                      context,
                      radius: 20,
                      muted: true,
                    ),
                    child: TextField(
                      controller: _branchController,
                      decoration: InputDecoration(
                        labelText: context.wp('New branch'),
                        hintText: context.wp('feature/mobile-triage'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  final name = _branchController.text.trim();
                  if (name.isEmpty) {
                    return;
                  }
                  Navigator.of(
                    context,
                  ).pop(_BranchAction(name: name, createNew: true));
                },
                icon: const Icon(Icons.add_rounded),
                label: Text(context.wp('Create and Switch')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
