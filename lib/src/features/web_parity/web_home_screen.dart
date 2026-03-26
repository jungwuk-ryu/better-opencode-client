import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../app/app_routes.dart';
import '../../app/app_scope.dart';
import '../../app/flavor.dart';
import '../../core/connection/connection_models.dart';
import '../../core/network/opencode_server_probe.dart';
import '../../design_system/app_snack_bar.dart';
import '../../design_system/app_spacing.dart';
import '../../design_system/app_theme.dart';
import '../../i18n/locale_controller.dart';
import '../projects/project_models.dart';
import '../projects/project_store.dart';
import 'project_picker_sheet.dart';

class WebParityHomeScreen extends StatefulWidget {
  const WebParityHomeScreen({
    required this.flavor,
    required this.localeController,
    this.projectStore,
    super.key,
  });

  final AppFlavor flavor;
  final LocaleController localeController;
  final ProjectStore? projectStore;

  @override
  State<WebParityHomeScreen> createState() => _WebParityHomeScreenState();
}

class _WebParityHomeScreenState extends State<WebParityHomeScreen> {
  late final ProjectStore _projectStore = widget.projectStore ?? ProjectStore();

  Future<ProjectTarget> _resolveNavigationTarget(
    WebParityAppController controller,
    ProjectTarget target,
  ) async {
    final selectedProfile = controller.selectedProfile;
    if (selectedProfile == null) {
      return target;
    }

    ProjectSessionHint? remembered = target.lastSession;
    if (remembered?.id == null || remembered!.id!.trim().isEmpty) {
      final lastWorkspace = await _projectStore.loadLastWorkspace(
        selectedProfile.storageKey,
      );
      if (lastWorkspace?.directory == target.directory &&
          lastWorkspace?.lastSession != null) {
        remembered = lastWorkspace!.lastSession;
      }
    }

    if (remembered?.id == null || remembered!.id!.trim().isEmpty) {
      for (final item in controller.recentProjects) {
        if (item.directory == target.directory && item.lastSession != null) {
          remembered = item.lastSession;
          break;
        }
      }
    }

    if (remembered == null) {
      return target;
    }
    return target.copyWith(lastSession: remembered);
  }

  Future<void> _openResolvedProject(
    WebParityAppController controller,
    ProjectTarget target,
  ) async {
    final selectedProfile = controller.selectedProfile;
    if (selectedProfile == null) {
      await _openServers(controller);
      return;
    }

    final resolvedTarget = await _resolveNavigationTarget(controller, target);
    await _projectStore.recordRecentProject(resolvedTarget);
    await _projectStore.saveLastWorkspace(
      serverStorageKey: selectedProfile.storageKey,
      target: resolvedTarget,
    );
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushNamed(
      buildWorkspaceRoute(
        resolvedTarget.directory,
        sessionId: _preferredSessionId(resolvedTarget),
      ),
    );
  }

  Future<void> _openProjectPicker(WebParityAppController controller) async {
    final selectedProfile = controller.selectedProfile;
    if (selectedProfile == null) {
      await _openServers(controller);
      return;
    }

    final target = await showModalBottomSheet<ProjectTarget>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.82,
        child: ProjectPickerSheet(profile: selectedProfile),
      ),
    );
    if (target == null || !mounted) {
      return;
    }
    await _openResolvedProject(controller, target);
  }

  Future<void> _openServers(WebParityAppController controller) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.84,
        child: _ServersSheet(controller: controller),
      ),
    );
  }

  Future<void> _openRecentProject(
    WebParityAppController controller,
    ProjectTarget target,
  ) async {
    await _openResolvedProject(controller, target);
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final selectedProfile = controller.selectedProfile;
        final selectedReport = controller.selectedReport;
        return Scaffold(
          body: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  surfaces.background,
                  Color.alphaBlend(
                    Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.05),
                    surfaces.panel,
                  ),
                ],
              ),
            ),
            child: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: controller.loading
                        ? const Center(child: CircularProgressIndicator())
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Align(
                                alignment: Alignment.topRight,
                                child: Wrap(
                                  spacing: AppSpacing.sm,
                                  runSpacing: AppSpacing.sm,
                                  children: <Widget>[
                                    _ServerPill(
                                      profile: selectedProfile,
                                      report: selectedReport,
                                      onTap: () => _openServers(controller),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: () => _openServers(controller),
                                      icon: const Icon(Icons.storage_rounded),
                                      label: const Text('See Servers'),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              Center(
                                child: Column(
                                  children: <Widget>[
                                    Text(
                                      'OpenCode',
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    const SizedBox(height: AppSpacing.sm),
                                    Text(
                                      'Open a recent project or pick a new directory to start a session.',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.copyWith(color: surfaces.muted),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: AppSpacing.lg),
                                    FilledButton.icon(
                                      onPressed: () =>
                                          _openProjectPicker(controller),
                                      icon: const Icon(
                                        Icons.folder_open_rounded,
                                      ),
                                      label: const Text('Open Project'),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xxl),
                              _RecentProjectsSection(
                                recentProjects: controller.recentProjects,
                                selectedProfile: selectedProfile,
                                onOpenProject: (target) =>
                                    _openRecentProject(controller, target),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

String? _preferredSessionId(ProjectTarget target) {
  final sessionId = target.lastSession?.id?.trim();
  if (sessionId == null || sessionId.isEmpty) {
    return null;
  }
  return sessionId;
}

class _RecentProjectsSection extends StatelessWidget {
  const _RecentProjectsSection({
    required this.recentProjects,
    required this.selectedProfile,
    required this.onOpenProject,
  });

  final List<ProjectTarget> recentProjects;
  final ServerProfile? selectedProfile;
  final ValueChanged<ProjectTarget> onOpenProject;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;

    return Container(
      decoration: BoxDecoration(
        color: surfaces.panelRaised.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: surfaces.lineSoft),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Recent Projects',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (selectedProfile == null)
                Text(
                  'Choose a server to open one.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: surfaces.muted),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (recentProjects.isEmpty)
            Text(
              'No recent projects yet.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: surfaces.muted),
            )
          else
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: recentProjects
                  .take(8)
                  .map(
                    (target) => ActionChip(
                      label: Text(target.label),
                      avatar: const Icon(Icons.folder_outlined, size: 18),
                      onPressed: selectedProfile == null
                          ? null
                          : () => onOpenProject(target),
                    ),
                  )
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }
}

class _ServerPill extends StatelessWidget {
  const _ServerPill({
    required this.profile,
    required this.report,
    required this.onTap,
  });

  final ServerProfile? profile;
  final ServerProbeReport? report;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final color = switch (report?.classification) {
      ConnectionProbeClassification.ready => surfaces.success,
      ConnectionProbeClassification.authFailure => Theme.of(
        context,
      ).colorScheme.secondary,
      ConnectionProbeClassification.unsupportedCapabilities => surfaces.warning,
      ConnectionProbeClassification.specFetchFailure => surfaces.warning,
      ConnectionProbeClassification.connectivityFailure => surfaces.danger,
      null => surfaces.muted,
    };
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: surfaces.panelRaised.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
          border: Border.all(color: surfaces.lineSoft),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(profile?.effectiveLabel ?? 'Select Server'),
          ],
        ),
      ),
    );
  }
}

class _ServersSheet extends StatefulWidget {
  const _ServersSheet({required this.controller});

  final WebParityAppController controller;

  @override
  State<_ServersSheet> createState() => _ServersSheetState();
}

class _ServersSheetState extends State<_ServersSheet> {
  WebParityAppController get controller => widget.controller;

  Future<void> _openServerEditor({ServerProfile? profile}) async {
    final draft = await showModalBottomSheet<ServerProfile>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.72,
        child: _ServerEditorSheet(initialProfile: profile),
      ),
    );
    if (draft == null) {
      return;
    }
    final savedProfile = await controller.saveProfile(draft);
    if (!mounted) {
      return;
    }
    showAppSnackBar(
      context,
      message: 'Saved "${savedProfile.effectiveLabel}" and refreshed status.',
      tone: AppSnackBarTone.success,
    );
  }

  Future<void> _confirmDelete(ServerProfile profile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete server?'),
        content: Text(
          'Remove "${profile.effectiveLabel}" from saved servers? This keeps the rest of your home screen intact.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await controller.deleteServerProfile(profile);
    if (!mounted) {
      return;
    }
    showAppSnackBar(
      context,
      message: 'Removed "${profile.effectiveLabel}".',
      tone: AppSnackBarTone.warning,
    );
  }

  Future<void> _moveProfile(ServerProfile profile, int offset) async {
    await controller.moveProfile(profile.id, offset);
  }

  Future<void> _refreshAll() async {
    for (final profile in controller.profiles) {
      await controller.refreshProbe(profile);
    }
    if (!mounted) {
      return;
    }
    showAppSnackBar(
      context,
      message: 'Refreshed saved server status.',
      tone: AppSnackBarTone.info,
    );
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final profiles = controller.profiles;
        return Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'See Servers',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                  IconButton(
                    tooltip: 'Refresh all statuses',
                    onPressed: profiles.isEmpty ? null : _refreshAll,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  FilledButton.icon(
                    key: const ValueKey<String>('servers-sheet-add-button'),
                    onPressed: _openServerEditor,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add Server'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Choose the active server, edit saved entries, reorder them, and keep connection status visible here.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: surfaces.muted),
              ),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: profiles.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              Icons.storage_rounded,
                              size: 34,
                              color: surfaces.muted,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'No saved servers yet.',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'Add your first OpenCode server here and it will immediately be ready for project browsing.',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: surfaces.muted),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: profiles.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) {
                          final profile = profiles[index];
                          final report = controller.reports[profile.storageKey];
                          final selected =
                              controller.selectedProfile?.id == profile.id;
                          return _ServerManagementCard(
                            key: ValueKey<String>(
                              'servers-sheet-card-${profile.id}',
                            ),
                            profile: profile,
                            report: report,
                            selected: selected,
                            isRefreshing: controller.isRefreshingProfile(
                              profile,
                            ),
                            canMoveUp: index > 0,
                            canMoveDown: index < profiles.length - 1,
                            onSelect: () => controller.selectProfile(profile),
                            onRefresh: () => controller.refreshProbe(profile),
                            onEdit: () => _openServerEditor(profile: profile),
                            onDelete: () => _confirmDelete(profile),
                            onMoveUp: index > 0
                                ? () => _moveProfile(profile, -1)
                                : null,
                            onMoveDown: index < profiles.length - 1
                                ? () => _moveProfile(profile, 1)
                                : null,
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ServerManagementCard extends StatelessWidget {
  const _ServerManagementCard({
    required this.profile,
    required this.report,
    required this.selected,
    required this.isRefreshing,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onSelect,
    required this.onRefresh,
    required this.onEdit,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
    super.key,
  });

  final ServerProfile profile;
  final ServerProbeReport? report;
  final bool selected;
  final bool isRefreshing;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onSelect;
  final VoidCallback onRefresh;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final meta = _serverMetaItems(context, profile, report);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(AppSpacing.lg),
        child: Ink(
          decoration: BoxDecoration(
            color: selected
                ? Color.alphaBlend(
                    Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.09),
                    surfaces.panelRaised,
                  )
                : surfaces.panelRaised.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(AppSpacing.lg),
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)
                  : surfaces.lineSoft,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: _StatusDot(report: report, busy: isRefreshing),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  profile.effectiveLabel,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                              _ServerStatusBadge(report: report),
                              if (selected) ...<Widget>[
                                const SizedBox(width: AppSpacing.xs),
                                _ServerMetaBadge(
                                  icon: Icons.check_circle_rounded,
                                  label: 'Active',
                                  tint: Theme.of(context).colorScheme.primary,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            profile.normalizedBaseUrl,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: surfaces.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: meta
                      .map(
                        (item) => _ServerMetaBadge(
                          icon: item.icon,
                          label: item.label,
                          tint: item.tint,
                        ),
                      )
                      .toList(growable: false),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: <Widget>[
                    TextButton.icon(
                      key: ValueKey<String>(
                        'servers-sheet-select-${profile.id}',
                      ),
                      onPressed: onSelect,
                      icon: Icon(
                        selected
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                      ),
                      label: Text(selected ? 'Selected' : 'Use This Server'),
                    ),
                    const Spacer(),
                    IconButton(
                      key: ValueKey<String>(
                        'servers-sheet-refresh-${profile.id}',
                      ),
                      tooltip: 'Refresh status',
                      onPressed: isRefreshing ? null : onRefresh,
                      icon: isRefreshing
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh_rounded),
                    ),
                    IconButton(
                      key: ValueKey<String>(
                        'servers-sheet-move-up-${profile.id}',
                      ),
                      tooltip: 'Move up',
                      onPressed: onMoveUp,
                      icon: const Icon(Icons.arrow_upward_rounded),
                    ),
                    IconButton(
                      key: ValueKey<String>(
                        'servers-sheet-move-down-${profile.id}',
                      ),
                      tooltip: 'Move down',
                      onPressed: onMoveDown,
                      icon: const Icon(Icons.arrow_downward_rounded),
                    ),
                    IconButton(
                      key: ValueKey<String>('servers-sheet-edit-${profile.id}'),
                      tooltip: 'Edit server',
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      key: ValueKey<String>(
                        'servers-sheet-delete-${profile.id}',
                      ),
                      tooltip: 'Delete server',
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ServerEditorSheet extends StatefulWidget {
  const _ServerEditorSheet({this.initialProfile});

  final ServerProfile? initialProfile;

  @override
  State<_ServerEditorSheet> createState() => _ServerEditorSheetState();
}

class _ServerEditorSheetState extends State<_ServerEditorSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _labelController;
  late final TextEditingController _baseUrlController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    final profile = widget.initialProfile;
    _labelController = TextEditingController(text: profile?.label ?? '');
    _baseUrlController = TextEditingController(
      text: profile?.normalizedBaseUrl ?? '',
    );
    _usernameController = TextEditingController(text: profile?.username ?? '');
    _passwordController = TextEditingController(text: profile?.password ?? '');
  }

  @override
  void dispose() {
    _labelController.dispose();
    _baseUrlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final existing = widget.initialProfile;
    final profile = ServerProfile(
      id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      label: _labelController.text.trim(),
      baseUrl: _baseUrlController.text.trim(),
      username: _optionalValue(_usernameController.text),
      password: _optionalValue(_passwordController.text),
    );
    Navigator.of(context).pop(profile);
  }

  String? _optionalValue(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String? _validateAddress(String? value) {
    final draft = ServerProfile(id: 'draft', label: '', baseUrl: value ?? '');
    final uri = draft.uriOrNull;
    if (uri == null || uri.host.isEmpty) {
      return 'Enter a valid server address.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final editingExisting = widget.initialProfile != null;
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: AppSpacing.lg + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Form(
        key: _formKey,
        child: ListView(
          children: <Widget>[
            Text(
              editingExisting ? 'Edit Server' : 'Add Server',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Save the server here and its status will be checked immediately.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: surfaces.muted),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              key: const ValueKey<String>('servers-editor-label-field'),
              controller: _labelController,
              decoration: const InputDecoration(
                labelText: 'Label',
                hintText: 'Studio',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              key: const ValueKey<String>('servers-editor-url-field'),
              controller: _baseUrlController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Server URL',
                hintText: 'https://studio.example.com',
              ),
              validator: _validateAddress,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              key: const ValueKey<String>('servers-editor-username-field'),
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Username',
                hintText: 'Optional',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              key: const ValueKey<String>('servers-editor-password-field'),
              controller: _passwordController,
              obscureText: !_showPassword,
              decoration: InputDecoration(
                labelText: 'Password',
                hintText: 'Optional',
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() {
                      _showPassword = !_showPassword;
                    });
                  },
                  icon: Icon(
                    _showPassword ? Icons.visibility_off : Icons.visibility,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton.icon(
                    key: const ValueKey<String>('servers-editor-save-button'),
                    onPressed: _submit,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(
                      editingExisting ? 'Save Changes' : 'Save Server',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ServerMetaItem {
  const _ServerMetaItem({required this.icon, required this.label, this.tint});

  final IconData icon;
  final String label;
  final Color? tint;
}

class _ServerMetaBadge extends StatelessWidget {
  const _ServerMetaBadge({required this.icon, required this.label, this.tint});

  final IconData icon;
  final String label;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final accent = tint ?? surfaces.panelMuted;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: accent),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: accent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ServerStatusBadge extends StatelessWidget {
  const _ServerStatusBadge({required this.report});

  final ServerProbeReport? report;

  @override
  Widget build(BuildContext context) {
    return _ServerMetaBadge(
      icon: _statusIconData(report),
      label: _statusLabel(report),
      tint: _statusColor(context, report),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.report, this.busy = false});

  final ServerProbeReport? report;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(context, report);
    if (busy) {
      return SizedBox.square(
        dimension: 14,
        child: CircularProgressIndicator(
          strokeWidth: 2.2,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      );
    }
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

List<_ServerMetaItem> _serverMetaItems(
  BuildContext context,
  ServerProfile profile,
  ServerProbeReport? report,
) {
  final surfaces = Theme.of(context).extension<AppSurfaces>()!;
  final items = <_ServerMetaItem>[];
  final snapshotName = report?.snapshot.name.trim() ?? '';
  if (snapshotName.isNotEmpty &&
      snapshotName.toLowerCase() != profile.effectiveLabel.toLowerCase()) {
    items.add(
      _ServerMetaItem(
        icon: Icons.memory_rounded,
        label: snapshotName,
        tint: surfaces.accentSoft,
      ),
    );
  }
  final version = report?.snapshot.version.trim() ?? '';
  if (version.isNotEmpty && version.toLowerCase() != 'unknown') {
    items.add(
      _ServerMetaItem(
        icon: Icons.tag_rounded,
        label: 'v$version',
        tint: Theme.of(context).colorScheme.primary,
      ),
    );
  }
  final username = profile.username?.trim();
  if (username != null && username.isNotEmpty) {
    items.add(
      _ServerMetaItem(
        icon: Icons.person_outline_rounded,
        label: username,
        tint: surfaces.muted,
      ),
    );
  } else if (report?.requiresBasicAuth == true) {
    items.add(
      _ServerMetaItem(
        icon: Icons.lock_outline_rounded,
        label: 'Basic Auth',
        tint: Theme.of(context).colorScheme.secondary,
      ),
    );
  }
  if (report != null) {
    items.add(
      _ServerMetaItem(
        icon: Icons.schedule_rounded,
        label: _checkedAtLabel(context, report.checkedAt),
        tint: surfaces.muted,
      ),
    );
  } else {
    items.add(
      _ServerMetaItem(
        icon: Icons.schedule_rounded,
        label: 'Not checked yet',
        tint: surfaces.muted,
      ),
    );
  }
  return items;
}

String _statusLabel(ServerProbeReport? report) {
  return switch (report?.classification) {
    ConnectionProbeClassification.ready => 'Ready',
    ConnectionProbeClassification.authFailure => 'Sign In',
    ConnectionProbeClassification.unsupportedCapabilities => 'Needs Update',
    ConnectionProbeClassification.specFetchFailure => 'Unavailable',
    ConnectionProbeClassification.connectivityFailure => 'Offline',
    null => 'Unknown',
  };
}

IconData _statusIconData(ServerProbeReport? report) {
  return switch (report?.classification) {
    ConnectionProbeClassification.ready => Icons.check_circle_rounded,
    ConnectionProbeClassification.authFailure => Icons.lock_outline_rounded,
    ConnectionProbeClassification.unsupportedCapabilities =>
      Icons.warning_amber_rounded,
    ConnectionProbeClassification.specFetchFailure =>
      Icons.error_outline_rounded,
    ConnectionProbeClassification.connectivityFailure => Icons.wifi_off_rounded,
    null => Icons.help_outline_rounded,
  };
}

Color _statusColor(BuildContext context, ServerProbeReport? report) {
  final surfaces = Theme.of(context).extension<AppSurfaces>()!;
  return switch (report?.classification) {
    ConnectionProbeClassification.ready => surfaces.success,
    ConnectionProbeClassification.authFailure => Theme.of(
      context,
    ).colorScheme.secondary,
    ConnectionProbeClassification.unsupportedCapabilities => surfaces.warning,
    ConnectionProbeClassification.specFetchFailure => surfaces.warning,
    ConnectionProbeClassification.connectivityFailure => surfaces.danger,
    null => surfaces.muted,
  };
}

String _checkedAtLabel(BuildContext context, DateTime checkedAt) {
  final localizations = MaterialLocalizations.of(context);
  final time = TimeOfDay.fromDateTime(checkedAt);
  return 'Checked ${localizations.formatTimeOfDay(time)}';
}
