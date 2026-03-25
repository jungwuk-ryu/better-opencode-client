import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../app/app_routes.dart';
import '../../app/app_scope.dart';
import '../../app/flavor.dart';
import '../../core/connection/connection_models.dart';
import '../../core/network/opencode_server_probe.dart';
import '../../design_system/app_spacing.dart';
import '../../design_system/app_theme.dart';
import '../../i18n/locale_controller.dart';
import '../connection/connection_home_screen.dart';
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
        child: _ServersSheet(
          controller: controller,
          flavor: widget.flavor,
          localeController: widget.localeController,
        ),
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

class _ServersSheet extends StatelessWidget {
  const _ServersSheet({
    required this.controller,
    required this.flavor,
    required this.localeController,
  });

  final WebParityAppController controller;
  final AppFlavor flavor;
  final LocaleController localeController;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
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
                    onPressed: () => controller.reload(),
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Switch the active server or open the full connection manager.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: surfaces.muted),
              ),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: controller.profiles.isEmpty
                    ? Center(
                        child: Text(
                          'No saved servers yet.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: surfaces.muted),
                        ),
                      )
                    : ListView.separated(
                        itemCount: controller.profiles.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpacing.xs),
                        itemBuilder: (context, index) {
                          final profile = controller.profiles[index];
                          final report = controller.reports[profile.storageKey];
                          final selected =
                              controller.selectedProfile?.id == profile.id;
                          return ListTile(
                            leading: _StatusDot(report: report),
                            title: Text(profile.effectiveLabel),
                            subtitle: Text(report?.summary ?? profile.baseUrl),
                            trailing: selected
                                ? const Icon(Icons.check_rounded)
                                : null,
                            selected: selected,
                            onTap: () async {
                              await controller.selectProfile(profile);
                              if (context.mounted) {
                                Navigator.of(context).pop();
                              }
                            },
                          );
                        },
                      ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context)
                            .push(
                              MaterialPageRoute<void>(
                                builder: (context) => ConnectionHomeScreen(
                                  flavor: flavor,
                                  localeController: localeController,
                                ),
                              ),
                            )
                            .then((_) => controller.reload());
                      },
                      icon: const Icon(Icons.settings_input_antenna_rounded),
                      label: const Text('Manage Servers'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.report});

  final ServerProbeReport? report;

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
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
