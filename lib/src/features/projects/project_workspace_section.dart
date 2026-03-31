import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/connection/connection_models.dart';
import '../../core/persistence/stale_cache_store.dart';
import '../../design_system/app_spacing.dart';
import '../../design_system/app_theme.dart';
import 'project_catalog_service.dart';
import 'project_models.dart';
import 'project_store.dart';
import 'server_directory_autocomplete_field.dart';

part 'project_workspace_section_components.dart';

class ProjectWorkspaceSection extends StatefulWidget {
  const ProjectWorkspaceSection({
    required this.profile,
    required this.onOpenProject,
    this.projectCatalogService,
    this.projectStore,
    this.cacheStore,
    super.key,
  });

  final ServerProfile profile;
  final ValueChanged<ProjectTarget> onOpenProject;
  final ProjectCatalogService? projectCatalogService;
  final ProjectStore? projectStore;
  final StaleCacheStore? cacheStore;

  @override
  State<ProjectWorkspaceSection> createState() =>
      _ProjectWorkspaceSectionState();
}

class _ProjectWorkspaceSectionState extends State<ProjectWorkspaceSection> {
  late final ProjectCatalogService _catalogService;
  late final bool _ownsCatalogService;
  late final ProjectStore _projectStore;
  late final StaleCacheStore _cacheStore;
  final TextEditingController _manualPathController = TextEditingController();
  final TextEditingController _projectFilterController =
      TextEditingController();

  ProjectCatalog? _catalog;
  List<ProjectTarget> _recentProjects = const <ProjectTarget>[];
  Set<String> _pinnedProjectDirectories = const <String>{};
  Set<String> _hiddenProjectDirectories = const <String>{};
  ProjectTarget? _selectedTarget;
  String? _error;
  bool _loading = true;
  bool _inspecting = false;
  String _catalogSignature = 'catalog-empty';
  String _projectQuery = '';
  int _refreshRequestToken = 0;

  @override
  void initState() {
    super.initState();
    _catalogService = widget.projectCatalogService ?? ProjectCatalogService();
    _ownsCatalogService = widget.projectCatalogService == null;
    _projectStore = widget.projectStore ?? ProjectStore();
    _cacheStore = widget.cacheStore ?? StaleCacheStore();
    _refresh();
  }

  @override
  void didUpdateWidget(covariant ProjectWorkspaceSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.storageKey != widget.profile.storageKey) {
      _refresh();
    }
  }

  @override
  void dispose() {
    if (_ownsCatalogService) {
      _catalogService.dispose();
    }
    _manualPathController.dispose();
    _projectFilterController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final requestToken = ++_refreshRequestToken;
    final profile = widget.profile;
    final profileStorageKey = profile.storageKey;
    final cacheKey = 'projectCatalog::${widget.profile.storageKey}';
    final recentProjects = await _projectStore.loadRecentProjects();
    final pinnedProjects = await _projectStore.loadPinnedProjects();
    final hiddenProjects = await _projectStore.loadHiddenProjects();
    final cached = await _cacheStore.load(cacheKey);
    if (cached != null) {
      try {
        final catalog = ProjectCatalog.fromJson(
          (jsonDecode(cached.payloadJson) as Map).cast<String, Object?>(),
        );
        final selected = catalog.currentProject == null
            ? null
            : _toTarget(
                catalog.currentProject!,
                source: 'current',
                branch: catalog.vcsInfo?.branch,
              );
        if (!_isActiveRefresh(requestToken, profileStorageKey)) {
          return;
        }
        setState(() {
          _catalog = catalog;
          _recentProjects = recentProjects;
          _pinnedProjectDirectories = pinnedProjects;
          _hiddenProjectDirectories = hiddenProjects;
          _selectedTarget = selected;
          _catalogSignature = cached.signature;
          _loading = false;
          _error = null;
        });
        final ttl = await _cacheStore.loadTtl();
        if (cached.isFresh(ttl, DateTime.now())) {
          return;
        }
      } catch (_) {
        await _cacheStore.remove(cacheKey);
        if (!_isActiveRefresh(requestToken, profileStorageKey)) {
          return;
        }
        setState(() {
          _catalog = null;
          _recentProjects = recentProjects;
          _pinnedProjectDirectories = pinnedProjects;
          _hiddenProjectDirectories = hiddenProjects;
          _selectedTarget = null;
          _catalogSignature = 'catalog-empty';
          _loading = true;
          _error = null;
        });
      }
    } else {
      if (!_isActiveRefresh(requestToken, profileStorageKey)) {
        return;
      }
      setState(() {
        _recentProjects = recentProjects;
        _pinnedProjectDirectories = pinnedProjects;
        _hiddenProjectDirectories = hiddenProjects;
        _loading = true;
        _error = null;
      });
    }
    try {
      final catalog = await _catalogService.fetchCatalog(profile);
      await _cacheStore.save(cacheKey, catalog.toJson());
      final recentProjects = await _projectStore.loadRecentProjects();
      final pinnedProjects = await _projectStore.loadPinnedProjects();
      final hiddenProjects = await _projectStore.loadHiddenProjects();
      final selected = catalog.currentProject == null
          ? null
          : _toTarget(
              catalog.currentProject!,
              source: 'current',
              branch: catalog.vcsInfo?.branch,
            );
      if (!_isActiveRefresh(requestToken, profileStorageKey)) {
        return;
      }
      setState(() {
        _catalog = catalog;
        _recentProjects = recentProjects;
        _pinnedProjectDirectories = pinnedProjects;
        _hiddenProjectDirectories = hiddenProjects;
        _selectedTarget = selected;
        _catalogSignature = jsonEncode(catalog.toJson());
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!_isActiveRefresh(requestToken, profileStorageKey)) {
        return;
      }
      setState(() {
        _recentProjects = recentProjects;
        _pinnedProjectDirectories = pinnedProjects;
        _hiddenProjectDirectories = hiddenProjects;
        _error = 'catalog-unavailable';
        _loading = false;
      });
    }
  }

  bool _isActiveRefresh(int requestToken, String profileStorageKey) {
    return mounted &&
        requestToken == _refreshRequestToken &&
        widget.profile.storageKey == profileStorageKey;
  }

  ProjectTarget _toTarget(
    ProjectSummary project, {
    required String source,
    String? branch,
  }) {
    return ProjectTarget(
      id: project.id,
      directory: project.directory,
      label: project.title,
      name: project.name,
      source: source,
      vcs: project.vcs,
      branch: branch,
      icon: project.icon,
      commands: project.commands,
    );
  }

  ProjectTarget _mergeSavedSessionHint(ProjectTarget target) {
    if (target.lastSession != null) {
      return target;
    }
    for (final recentProject in _recentProjects) {
      if (recentProject.directory != target.directory) {
        continue;
      }
      return ProjectTarget(
        directory: target.directory,
        label: target.label,
        id: target.id,
        name: target.name,
        source: target.source,
        vcs: target.vcs,
        branch: target.branch,
        icon: target.icon,
        commands: target.commands,
        lastSession: recentProject.lastSession,
      );
    }
    return target;
  }

  Future<void> _selectTarget(ProjectTarget target) async {
    final resolvedTarget = _mergeSavedSessionHint(target);
    final recentProjects = await _projectStore.recordRecentProject(
      resolvedTarget,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedTarget = resolvedTarget;
      _recentProjects = recentProjects;
    });
  }

  Future<void> _openTarget(ProjectTarget target) async {
    final resolvedTarget = _mergeSavedSessionHint(target);
    final recentProjects = await _projectStore.recordRecentProject(
      resolvedTarget,
    );
    await _projectStore.saveLastWorkspace(
      serverStorageKey: widget.profile.storageKey,
      target: resolvedTarget,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedTarget = resolvedTarget;
      _recentProjects = recentProjects;
    });
    widget.onOpenProject(resolvedTarget);
  }

  Future<void> _togglePinnedProject(ProjectTarget target) async {
    final pinnedProjects = await _projectStore.togglePinnedProject(
      target.directory,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _pinnedProjectDirectories = pinnedProjects;
    });
  }

  List<ProjectTarget> _pinnedProjects(ProjectCatalog? catalog) {
    final allTargets = <ProjectTarget>[
      if (catalog?.currentProject != null)
        _toTarget(
          catalog!.currentProject!,
          source: 'current',
          branch: catalog.vcsInfo?.branch,
        ),
      if (catalog != null)
        ...catalog.projects.map(
          (project) => _toTarget(
            project,
            source: 'server',
            branch: catalog.vcsInfo?.branch,
          ),
        ),
      ..._recentProjects,
      ...?_selectedTarget == null ? null : <ProjectTarget>[_selectedTarget!],
    ];
    final byDirectory = <String, ProjectTarget>{};
    for (final target in allTargets) {
      if (_hiddenProjectDirectories.contains(target.directory) &&
          _selectedTarget?.directory != target.directory) {
        continue;
      }
      byDirectory.putIfAbsent(target.directory, () => target);
    }
    final pinned = byDirectory.values
        .where((target) => _pinnedProjectDirectories.contains(target.directory))
        .toList(growable: false);
    pinned.sort(
      (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
    );
    return pinned;
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
      await _selectTarget(target);
    } finally {
      if (mounted) {
        setState(() {
          _inspecting = false;
        });
      }
    }
  }

  bool _matchesProject(ProjectTarget target) {
    final query = _projectQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return true;
    }
    return <String?>[
      target.label,
      target.name,
      target.directory,
      target.source,
      target.vcs,
      target.branch,
      target.lastSession?.title,
      target.lastSession?.status,
    ].any((value) => value?.toLowerCase().contains(query) ?? false);
  }

  List<ProjectTarget> _filterTargets(Iterable<ProjectTarget> targets) {
    return targets.where(_matchesProject).toList(growable: false);
  }

  String _sectionTitle(String title, int count) {
    return title;
  }

  Widget _buildChooserOverview(BuildContext context, AppLocalizations l10n) {
    final catalog = _catalog;
    final pinnedCount = _pinnedProjects(catalog).length;
    final serverCount = catalog?.projects.length ?? 0;
    final recentCount = _recentProjects.length;
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: <Widget>[
        _ProjectOverviewChip(
          icon: Icons.push_pin_rounded,
          label: l10n.pinnedProjectsTitle,
          value: '$pinnedCount',
        ),
        _ProjectOverviewChip(
          icon: Icons.dns_rounded,
          label: l10n.serverProjectsTitle,
          value: '$serverCount',
        ),
        _ProjectOverviewChip(
          icon: Icons.history_rounded,
          label: l10n.recentProjectsTitle,
          value: '$recentCount',
        ),
        if (_selectedTarget != null)
          _ProjectOverviewChip(
            icon: Icons.adjust_rounded,
            label: l10n.projectPreviewTitle,
            value: _selectedTarget!.label,
            accentColor: surfaces.accentSoft,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              l10n.projectSelectionTitle,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.projectSelectionSubtitle,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: surfaces.muted),
            ),
            if (!_loading) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              _buildChooserOverview(context, l10n),
            ],
            const SizedBox(height: AppSpacing.lg),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (_error != null) ...<Widget>[
                    _CatalogNoticeBanner(
                      title: l10n.projectCatalogUnavailableTitle,
                      body: l10n.projectCatalogUnavailableBody,
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    transitionBuilder: (child, animation) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                    child: LayoutBuilder(
                      key: ValueKey<String>(_catalogSignature),
                      builder: (context, constraints) {
                        final stacked = constraints.maxWidth < 900;
                        final chooser = _buildChooser(context, l10n);
                        final preview = _buildPreview(context, l10n);
                        if (stacked) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              chooser,
                              const SizedBox(height: AppSpacing.lg),
                              preview,
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(flex: 6, child: chooser),
                            const SizedBox(width: AppSpacing.lg),
                            Expanded(flex: 4, child: preview),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildChooser(BuildContext context, AppLocalizations l10n) {
    final catalog = _catalog;
    final pinnedProjects = _filterTargets(_pinnedProjects(catalog));
    final currentProjectTarget = catalog?.currentProject == null
        ? null
        : _toTarget(
            catalog!.currentProject!,
            source: 'current',
            branch: catalog.vcsInfo?.branch,
          );
    final showCurrentProject =
        currentProjectTarget != null && _matchesProject(currentProjectTarget);
    final serverProjects = _filterTargets(
      catalog?.projects.map(
            (project) => _toTarget(
              project,
              source: 'server',
              branch: catalog.vcsInfo?.branch,
            ),
          ) ??
          const Iterable<ProjectTarget>.empty(),
    );
    final recentProjects = _filterTargets(_recentProjects);
    final hasFilter = _projectQuery.trim().isNotEmpty;
    final hasMatches =
        pinnedProjects.isNotEmpty ||
        showCurrentProject ||
        serverProjects.isNotEmpty ||
        recentProjects.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TextField(
          key: const ValueKey<String>('project-filter-field'),
          controller: _projectFilterController,
          onChanged: (value) {
            setState(() {
              _projectQuery = value;
            });
          },
          decoration: InputDecoration(
            labelText: l10n.projectFilterLabel,
            hintText: l10n.projectFilterHint,
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _projectQuery.trim().isEmpty
                ? null
                : IconButton(
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).deleteButtonTooltip,
                    onPressed: () {
                      _projectFilterController.clear();
                      setState(() {
                        _projectQuery = '';
                      });
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (hasFilter && !hasMatches) ...<Widget>[
          _Section(
            title: l10n.projectFilterLabel,
            subtitle: l10n.projectFilterHint,
            child: Text(l10n.projectFilterEmpty),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (pinnedProjects.isNotEmpty) ...<Widget>[
          _Section(
            title: _sectionTitle(
              l10n.pinnedProjectsTitle,
              pinnedProjects.length,
            ),
            subtitle: l10n.pinnedProjectsSubtitle,
            child: Column(
              children: pinnedProjects
                  .map(
                    (project) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: _ProjectChoiceTile(
                        target: project,
                        selected:
                            _selectedTarget?.directory == project.directory,
                        pinned: true,
                        pinTooltip: l10n.projectUnpinAction,
                        onPinToggle: () => _togglePinnedProject(project),
                        onTap: () => _selectTarget(project),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (showCurrentProject) ...<Widget>[
          _Section(
            title: l10n.currentProjectTitle,
            subtitle: l10n.currentProjectSubtitle,
            child: _ProjectChoiceTile(
              target: currentProjectTarget,
              selected:
                  _selectedTarget?.directory == currentProjectTarget.directory,
              pinned: _pinnedProjectDirectories.contains(
                currentProjectTarget.directory,
              ),
              pinTooltip:
                  _pinnedProjectDirectories.contains(
                    currentProjectTarget.directory,
                  )
                  ? l10n.projectUnpinAction
                  : l10n.projectPinAction,
              onPinToggle: () => _togglePinnedProject(currentProjectTarget),
              onTap: () => _selectTarget(currentProjectTarget),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        _Section(
          title: _sectionTitle(l10n.serverProjectsTitle, serverProjects.length),
          subtitle: l10n.serverProjectsSubtitle,
          child: serverProjects.isEmpty
              ? Text(
                  hasFilter
                      ? l10n.projectFilterEmpty
                      : l10n.serverProjectsEmpty,
                )
              : Column(
                  children: serverProjects
                      .map(
                        (target) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                          child: _ProjectChoiceTile(
                            target: target,
                            selected:
                                _selectedTarget?.directory == target.directory,
                            pinned: _pinnedProjectDirectories.contains(
                              target.directory,
                            ),
                            pinTooltip:
                                _pinnedProjectDirectories.contains(
                                  target.directory,
                                )
                                ? l10n.projectUnpinAction
                                : l10n.projectPinAction,
                            onPinToggle: () => _togglePinnedProject(target),
                            onTap: () => _selectTarget(target),
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
        ),
        const SizedBox(height: AppSpacing.md),
        _Section(
          title: l10n.manualProjectTitle,
          subtitle: l10n.manualProjectSubtitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ServerDirectoryAutocompleteField(
                fieldKey: const ValueKey<String>('project-manual-path-field'),
                profile: widget.profile,
                catalogService: _catalogService,
                controller: _manualPathController,
                pathInfo: _catalog?.pathInfo,
                labelText: l10n.manualProjectPathLabel,
                hintText: l10n.manualProjectPathHint,
                loadingText: l10n.projectPathSuggestionsLoading,
                emptyText: l10n.projectPathSuggestionsEmpty,
                enabled: !_inspecting,
                onSubmitted: (_) => _inspectManualPath(),
                onSuggestionSelected: (_) {
                  unawaited(_inspectManualPath());
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              ElevatedButton(
                onPressed: _inspecting ? null : _inspectManualPath,
                child: Text(
                  _inspecting
                      ? l10n.projectInspectingAction
                      : l10n.projectInspectAction,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _Section(
          title: _sectionTitle(l10n.recentProjectsTitle, recentProjects.length),
          subtitle: l10n.recentProjectsSubtitle,
          child: recentProjects.isEmpty
              ? Text(
                  hasFilter
                      ? l10n.projectFilterEmpty
                      : l10n.recentProjectsEmpty,
                )
              : Column(
                  children: recentProjects
                      .map(
                        (project) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                          child: _ProjectChoiceTile(
                            target: project,
                            selected:
                                _selectedTarget?.directory == project.directory,
                            pinned: _pinnedProjectDirectories.contains(
                              project.directory,
                            ),
                            pinTooltip:
                                _pinnedProjectDirectories.contains(
                                  project.directory,
                                )
                                ? l10n.projectUnpinAction
                                : l10n.projectPinAction,
                            onPinToggle: () => _togglePinnedProject(project),
                            onTap: () => _selectTarget(project),
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
        ),
      ],
    );
  }

  Widget _buildPreview(BuildContext context, AppLocalizations l10n) {
    final target = _selectedTarget;
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    return _Section(
      title: l10n.projectPreviewTitle,
      subtitle: l10n.projectPreviewSubtitle,
      child: target == null
          ? Text(l10n.projectPreviewEmpty)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: surfaces.panelMuted.withValues(alpha: 0.68),
                    borderRadius: BorderRadius.circular(AppSpacing.lg),
                    border: Border.all(color: surfaces.line),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _ProjectAvatar(target: target, large: true),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                target.label,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                target.directory,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: surfaces.muted),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Wrap(
                                spacing: AppSpacing.xs,
                                runSpacing: AppSpacing.xs,
                                children: <Widget>[
                                  _ProjectMetaChip(
                                    icon: Icons.hub_rounded,
                                    label: target.source ?? '-',
                                  ),
                                  if ((target.vcs ?? '').isNotEmpty)
                                    _ProjectMetaChip(
                                      icon: Icons.account_tree_outlined,
                                      label: target.vcs!,
                                    ),
                                  if ((target.branch ?? '').isNotEmpty)
                                    _ProjectMetaChip(
                                      icon: Icons.commit_rounded,
                                      label: target.branch!,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                _PreviewRow(
                  label: l10n.projectDirectoryLabel,
                  value: target.directory,
                ),
                _PreviewRow(
                  label: l10n.projectSourceLabel,
                  value: target.source ?? '-',
                ),
                _PreviewRow(
                  label: l10n.projectVcsLabel,
                  value: target.vcs ?? '-',
                ),
                _PreviewRow(
                  label: l10n.projectBranchLabel,
                  value: target.branch ?? '-',
                ),
                _PreviewRow(
                  label: l10n.projectLastSessionLabel,
                  value:
                      target.lastSession?.title ??
                      l10n.projectLastSessionUnknown,
                ),
                _PreviewRow(
                  label: l10n.projectLastStatusLabel,
                  value:
                      target.lastSession?.status ??
                      l10n.projectLastStatusUnknown,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  l10n.projectSelectionReadyHint,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: surfaces.muted),
                ),
                const SizedBox(height: AppSpacing.md),
                ElevatedButton.icon(
                  onPressed: () => _openTarget(target),
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: Text(l10n.projectOpenAction),
                ),
              ],
            ),
    );
  }
}
