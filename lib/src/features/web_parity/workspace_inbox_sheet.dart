import 'package:flutter/material.dart';

import '../../design_system/app_spacing.dart';
import '../../design_system/app_theme.dart';
import '../../i18n/web_parity_localizations.dart';
import '../chat/chat_models.dart';
import '../requests/request_models.dart';
import 'workspace_controller.dart';

class WorkspaceInboxSheet extends StatelessWidget {
  const WorkspaceInboxSheet({
    required this.sessions,
    required this.statuses,
    required this.pendingRequests,
    required this.notifications,
    required this.onOpenSession,
    required this.onAllowPermission,
    required this.onRejectPermission,
    super.key,
  });

  final List<SessionSummary> sessions;
  final Map<String, SessionStatusSummary> statuses;
  final PendingRequestBundle pendingRequests;
  final List<WorkspaceNotificationEntry> notifications;
  final Future<void> Function(String sessionId) onOpenSession;
  final Future<void> Function(String requestId) onAllowPermission;
  final Future<void> Function(String requestId) onRejectPermission;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final unseenNotifications = notifications
        .where((notification) => !notification.viewed)
        .toList(growable: false)
      ..sort((left, right) => right.timeMs.compareTo(left.timeMs));
    return SafeArea(
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: surfaces.panel,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: surfaces.lineSoft),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            context.wp('Inbox'),
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            context.wp(
                              'Triage open questions, permissions, and unread session activity from one mobile-friendly queue.',
                            ),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: surfaces.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: <Widget>[
                    _InboxSummaryChip(
                      label: context.wp(
                        pendingRequests.questions.length == 1
                            ? '1 question'
                            : '{count} questions',
                        args: <String, Object?>{
                          'count': pendingRequests.questions.length,
                        },
                      ),
                    ),
                    _InboxSummaryChip(
                      label: context.wp(
                        pendingRequests.permissions.length == 1
                            ? '1 approval'
                            : '{count} approvals',
                        args: <String, Object?>{
                          'count': pendingRequests.permissions.length,
                        },
                      ),
                    ),
                    _InboxSummaryChip(
                      label: context.wp(
                        unseenNotifications.length == 1
                            ? '1 unread event'
                            : '{count} unread events',
                        args: <String, Object?>{
                          'count': unseenNotifications.length,
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Expanded(
                  child: ListView(
                    children: <Widget>[
                      _InboxSection(
                        title: context.wp('Questions'),
                        emptyLabel: context.wp('No pending questions right now.'),
                        children: pendingRequests.questions
                            .map(
                              (request) => _QuestionInboxTile(
                                request: request,
                                sessionLabel: _sessionLabel(request.sessionId),
                                onTap: () async {
                                  Navigator.of(context).pop();
                                  await onOpenSession(request.sessionId);
                                },
                              ),
                            )
                            .toList(growable: false),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _InboxSection(
                        title: context.wp('Approvals'),
                        emptyLabel: context.wp('No permission requests right now.'),
                        children: pendingRequests.permissions
                            .map(
                              (request) => _PermissionInboxTile(
                                request: request,
                                sessionLabel: _sessionLabel(request.sessionId),
                                onOpen: () async {
                                  Navigator.of(context).pop();
                                  await onOpenSession(request.sessionId);
                                },
                                onAllow: () => onAllowPermission(request.id),
                                onReject: () => onRejectPermission(request.id),
                              ),
                            )
                            .toList(growable: false),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _InboxSection(
                        title: context.wp('Unread Activity'),
                        emptyLabel: context.wp('All workspace activity is caught up.'),
                        children: unseenNotifications
                            .map(
                              (notification) => _NotificationInboxTile(
                                notification: notification,
                                sessionLabel: _sessionLabel(notification.sessionId),
                                statusLabel: statuses[notification.sessionId]?.type,
                                onTap: () async {
                                  Navigator.of(context).pop();
                                  await onOpenSession(notification.sessionId);
                                },
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _sessionLabel(String sessionId) {
    for (final session in sessions) {
      if (session.id == sessionId) {
        final title = session.title.trim();
        return title.isEmpty ? session.id : title;
      }
    }
    return sessionId;
  }
}

class _InboxSection extends StatelessWidget {
  const _InboxSection({
    required this.title,
    required this.emptyLabel,
    required this.children,
  });

  final String title;
  final String emptyLabel;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (children.isEmpty)
          Text(
            emptyLabel,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: surfaces.muted,
                ),
          )
        else
          ...children.map(
            (child) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: child,
            ),
          ),
      ],
    );
  }
}

class _InboxSummaryChip extends StatelessWidget {
  const _InboxSummaryChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: surfaces.panelRaised,
        borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
        border: Border.all(color: surfaces.lineSoft),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _InboxTileFrame extends StatelessWidget {
  const _InboxTileFrame({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
    this.tint,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final accent = tint ?? theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: surfaces.panelRaised,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: surfaces.lineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent, size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                            color: surfaces.muted,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ...children,
        ],
      ),
    );
  }
}

class _QuestionInboxTile extends StatelessWidget {
  const _QuestionInboxTile({
    required this.request,
    required this.sessionLabel,
    required this.onTap,
  });

  final QuestionRequestSummary request;
  final String sessionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final firstPrompt = request.questions.firstOrNull;
    final title = firstPrompt?.header.trim().isNotEmpty == true
        ? firstPrompt!.header.trim()
        : firstPrompt?.question.trim().isNotEmpty == true
        ? firstPrompt!.question.trim()
        : context.wp('Pending question');
    final count = request.questions.length;
    return _InboxTileFrame(
      icon: Icons.help_outline_rounded,
      title: title,
      subtitle: '$sessionLabel  •  ${context.wp(
        count == 1 ? '1 prompt needs an answer' : '{count} prompts need answers',
        args: <String, Object?>{'count': count},
      )}',
      children: <Widget>[
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.tonalIcon(
            onPressed: onTap,
            icon: const Icon(Icons.open_in_new_rounded),
            label: Text(context.wp('Open Session')),
          ),
        ),
      ],
    );
  }
}

class _PermissionInboxTile extends StatelessWidget {
  const _PermissionInboxTile({
    required this.request,
    required this.sessionLabel,
    required this.onOpen,
    required this.onAllow,
    required this.onReject,
  });

  final PermissionRequestSummary request;
  final String sessionLabel;
  final Future<void> Function() onOpen;
  final Future<void> Function() onAllow;
  final Future<void> Function() onReject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    return _InboxTileFrame(
      icon: Icons.policy_outlined,
      tint: surfaces.warning,
      title: request.permission.trim().isEmpty
          ? context.wp('Permission request')
          : request.permission.trim(),
      subtitle: sessionLabel,
      children: <Widget>[
        if (request.patterns.isNotEmpty)
          Text(
            request.patterns.join('\n'),
            style: theme.textTheme.bodySmall?.copyWith(color: surfaces.muted),
          ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          alignment: WrapAlignment.end,
          children: <Widget>[
            OutlinedButton(
              onPressed: () => onOpen(),
              child: Text(context.wp('Open')),
            ),
            OutlinedButton(
              onPressed: () => onReject(),
              child: Text(context.wp('Reject')),
            ),
            FilledButton(
              onPressed: () => onAllow(),
              child: Text(context.wp('Allow')),
            ),
          ],
        ),
      ],
    );
  }
}

class _NotificationInboxTile extends StatelessWidget {
  const _NotificationInboxTile({
    required this.notification,
    required this.sessionLabel,
    required this.statusLabel,
    required this.onTap,
  });

  final WorkspaceNotificationEntry notification;
  final String sessionLabel;
  final String? statusLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final error = notification.type == WorkspaceNotificationType.error;
    final time = DateTime.fromMillisecondsSinceEpoch(notification.timeMs);
    final localizations = MaterialLocalizations.of(context);
    final timeLabel = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(time),
      alwaysUse24HourFormat: MediaQuery.of(context).alwaysUse24HourFormat,
    );
    return _InboxTileFrame(
      icon: error ? Icons.error_outline_rounded : Icons.notifications_none_rounded,
      tint: error ? theme.colorScheme.error : theme.colorScheme.primary,
      title: sessionLabel,
      subtitle:
          '$timeLabel  •  ${statusLabel?.trim().isNotEmpty == true ? statusLabel!.trim() : context.wp('Activity')}',
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                notification.directory,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: surfaces.muted,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            FilledButton.tonal(
              onPressed: onTap,
              child: Text(context.wp('Open')),
            ),
          ],
        ),
      ],
    );
  }
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
