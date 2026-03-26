import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/connection/connection_models.dart';
import '../../design_system/app_snack_bar.dart';
import '../../design_system/app_spacing.dart';
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
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Open Project', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Choose a worktree from your server or inspect a manual path.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: surfaces.muted),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: ServerDirectoryAutocompleteField(
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
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton(
                  onPressed: _inspecting ? null : _inspectManualPath,
                  child: Text(_inspecting ? 'Inspecting...' : 'Inspect'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  'Project catalog unavailable. Showing recent items only.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: surfaces.warning),
                ),
              ),
            Flexible(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _targets.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xl,
                      ),
                      child: Text(
                        'No projects are available yet.',
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: surfaces.muted),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: _targets.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.xs),
                      itemBuilder: (context, index) {
                        final target = _targets[index];
                        return ListTile(
                          title: Text(target.label),
                          subtitle: Text(target.directory),
                          trailing: target.branch == null
                              ? null
                              : Text(
                                  target.branch!,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                          onTap: () => Navigator.of(context).pop(target),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
