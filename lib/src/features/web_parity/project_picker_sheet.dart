import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/connection/connection_models.dart';
import '../../design_system/app_snack_bar.dart';
import '../../design_system/app_spacing.dart';
import '../../design_system/app_surface_decor.dart';
import '../../design_system/app_theme.dart';
import '../projects/project_catalog_service.dart';
import '../projects/project_models.dart';
import '../projects/project_store.dart';
import '../projects/server_directory_autocomplete_field.dart';

class ProjectPickerSheet extends StatefulWidget {
  const ProjectPickerSheet({
    required this.profile,
    this.projectCatalogService,
    this.projectStore,
    super.key,
  });

  final ServerProfile profile;
  final ProjectCatalogService? projectCatalogService;
  final ProjectStore? projectStore;

  @override
  State<ProjectPickerSheet> createState() => _ProjectPickerSheetState();
}

class _ProjectPickerSheetState extends State<ProjectPickerSheet> {
  late final ProjectCatalogService _catalogService =
      widget.projectCatalogService ?? ProjectCatalogService();
  late final ProjectStore _projectStore = widget.projectStore ?? ProjectStore();
  final TextEditingController _manualPathController = TextEditingController();

  bool _loading = true;
  bool _inspecting = false;
  String? _error;
  List<ProjectTarget> _targets = const <ProjectTarget>[];

  @override
  void initState() {
    super.initState();
    unawaited(_loadProjects());
  }

  @override
  void dispose() {
    if (widget.projectCatalogService == null) {
      _catalogService.dispose();
    }
    _manualPathController.dispose();
    super.dispose();
  }

  Future<void> _loadProjects() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final catalog = await _catalogService.fetchCatalog(widget.profile);
      final recent = await _projectStore.loadRecentProjects();
      final hidden = await _projectStore.loadHiddenProjects();
      final next = _mergeTargets(catalog, recent, hidden);
      if (!mounted) {
        return;
      }
      setState(() {
        _targets = next;
        _loading = false;
      });
    } catch (error) {
      final recent = await _projectStore.loadRecentProjects();
      if (!mounted) {
        return;
      }
      setState(() {
        _targets = recent;
        _error = error.toString();
        _loading = false;
      });
    }
  }

  List<ProjectTarget> _mergeTargets(
    ProjectCatalog catalog,
    List<ProjectTarget> recent,
    Set<String> hidden,
  ) {
    final byDirectory = <String, ProjectTarget>{};

    void add(ProjectTarget target) {
      if (hidden.contains(target.directory)) {
        return;
      }
      byDirectory[target.directory] = target;
    }

    ProjectTarget toTarget(ProjectSummary summary, {required String source}) {
      return ProjectTarget(
        id: summary.id,
        directory: summary.directory,
        label: summary.title,
        name: summary.name,
        source: source,
        vcs: summary.vcs,
        branch: catalog.vcsInfo?.branch,
        icon: summary.icon,
        commands: summary.commands,
      );
    }

    if (catalog.currentProject != null) {
      add(toTarget(catalog.currentProject!, source: 'current'));
    }
    for (final item in catalog.projects) {
      add(toTarget(item, source: 'server'));
    }
    for (final item in recent) {
      add(item);
    }

    final values = byDirectory.values.toList(growable: false);
    values.sort(
      (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
    );
    return values;
  }

  Future<void> _inspectManualPath() async {
    final path = _manualPathController.text.trim();
    if (path.isEmpty) {
      return;
    }
    setState(() {
      _inspecting = true;
    });
    try {
      final target = await _catalogService.inspectDirectory(
        profile: widget.profile,
        directory: path,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(target);
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAppSnackBar(
        context,
        message: 'Failed to inspect "$path": $error',
        tone: AppSnackBarTone.danger,
      );
    } finally {
      if (mounted) {
        setState(() {
          _inspecting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.lg,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: AppGlassPanel(
              radius: AppSpacing.dialogRadius,
              blur: 14,
              backgroundOpacity: theme.brightness == Brightness.dark
                  ? 0.9
                  : 0.95,
              borderOpacity: 0.08,
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Open Project',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'Choose a worktree from ${widget.profile.effectiveLabel} or inspect a manual path.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: surfaces.muted,
                                height: 1.45,
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
                  const SizedBox(height: AppSpacing.lg),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: appSoftCardDecoration(
                      context,
                      radius: 22,
                      muted: true,
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final compact = constraints.maxWidth < 480;
                        final field = ServerDirectoryAutocompleteField(
                          fieldKey: const ValueKey<String>(
                            'project-picker-manual-path-field',
                          ),
                          profile: widget.profile,
                          catalogService: _catalogService,
                          controller: _manualPathController,
                          labelText: 'Directory path',
                          hintText: '/workspace/my-project',
                          loadingText: 'Searching server folders...',
                          emptyText: 'No matching folders found on the server.',
                          enabled: !_inspecting,
                          onSubmitted: (_) => _inspectManualPath(),
                          onSuggestionSelected: (_) {
                            unawaited(_inspectManualPath());
                          },
                        );
                        final button = FilledButton(
                          onPressed: _inspecting ? null : _inspectManualPath,
                          child: Text(
                            _inspecting ? 'Inspecting...' : 'Inspect',
                          ),
                        );
                        if (compact) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              field,
                              const SizedBox(height: AppSpacing.sm),
                              button,
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(child: field),
                            const SizedBox(width: AppSpacing.sm),
                            button,
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (_error != null)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: surfaces.warning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: surfaces.warning.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        'Project catalog unavailable. Showing recent items only.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: surfaces.warning,
                        ),
                      ),
                    ),
                  Flexible(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : _targets.isEmpty
                        ? Center(
                            child: Text(
                              'No projects are available yet.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: surfaces.muted,
                              ),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: _targets.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: AppSpacing.xs),
                            itemBuilder: (context, index) {
                              final target = _targets[index];
                              return _ProjectTargetTile(
                                target: target,
                                onTap: () => Navigator.of(context).pop(target),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProjectTargetTile extends StatelessWidget {
  const _ProjectTargetTile({required this.target, required this.onTap});

  final ProjectTarget target;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            color: surfaces.panelMuted.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: surfaces.lineSoft),
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: surfaces.panelMuted.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.folder_open_rounded,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      target.label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      target.directory,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: surfaces.muted,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: <Widget>[
                        if ((target.branch ?? '').isNotEmpty)
                          _ProjectTargetBadge(
                            icon: Icons.account_tree_rounded,
                            label: target.branch!,
                            tint: theme.colorScheme.primary,
                          ),
                        if ((target.source ?? '').isNotEmpty)
                          _ProjectTargetBadge(
                            icon: Icons.history_toggle_off_rounded,
                            label: target.source!,
                            tint: surfaces.muted,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(Icons.chevron_right_rounded, color: surfaces.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectTargetBadge extends StatelessWidget {
  const _ProjectTargetBadge({
    required this.icon,
    required this.label,
    required this.tint,
  });

  final IconData icon;
  final String label;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
        border: Border.all(color: tint.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: tint),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: tint,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
