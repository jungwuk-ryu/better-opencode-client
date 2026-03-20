import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/connection/connection_models.dart';
import '../../core/spec/capability_registry.dart';
import '../../design_system/app_spacing.dart';
import '../../design_system/app_theme.dart';
import '../projects/project_catalog_service.dart';
import '../projects/project_models.dart';
import '../projects/project_store.dart';
import 'opencode_shell_screen.dart';

class ServerWorkspaceShellScreen extends StatefulWidget {
  const ServerWorkspaceShellScreen({
    required this.profile,
    required this.capabilities,
    required this.onExit,
    this.initialProject,
    this.projectCatalogService,
    this.projectStore,
    super.key,
  });

  final ServerProfile profile;
  final CapabilityRegistry capabilities;
  final VoidCallback onExit;
  final ProjectTarget? initialProject;
  final ProjectCatalogService? projectCatalogService;
  final ProjectStore? projectStore;

  @override
  State<ServerWorkspaceShellScreen> createState() =>
      _ServerWorkspaceShellScreenState();
}

class _ServerWorkspaceShellScreenState
    extends State<ServerWorkspaceShellScreen> {
  late final ProjectCatalogService _projectCatalogService;
  late final bool _ownsProjectCatalogService;
  late final ProjectStore _projectStore;

  List<ProjectTarget> _availableProjects = const <ProjectTarget>[];
  ProjectTarget? _selectedProject;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _projectCatalogService =
        widget.projectCatalogService ?? ProjectCatalogService();
    _ownsProjectCatalogService = widget.projectCatalogService == null;
    _projectStore = widget.projectStore ?? ProjectStore();
    _loadProjects();
  }

  @override
  void dispose() {
    if (_ownsProjectCatalogService) {
      _projectCatalogService.dispose();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ServerWorkspaceShellScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.storageKey != widget.profile.storageKey ||
        oldWidget.initialProject?.directory !=
            widget.initialProject?.directory) {
      unawaited(_loadProjects());
    }
  }

  Future<void> _loadProjects() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final catalog = await _projectCatalogService.fetchCatalog(widget.profile);
      final recentProjects = await _projectStore.loadRecentProjects();
      final lastWorkspace = await _projectStore.loadLastWorkspace(
        widget.profile.storageKey,
      );
      final availableProjects = _mergeProjects(catalog, <ProjectTarget>[
        ...recentProjects,
        ?lastWorkspace,
      ]);
      final selectedProject = _pickInitialProject(
        availableProjects,
        lastWorkspace: lastWorkspace,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _availableProjects = availableProjects;
        _selectedProject = selectedProject;
        _loading = false;
      });
      if (selectedProject != null) {
        unawaited(_persistProjectSelection(selectedProject));
      }
    } catch (_) {
      final recentProjects = await _projectStore.loadRecentProjects();
      final lastWorkspace = await _projectStore.loadLastWorkspace(
        widget.profile.storageKey,
      );
      final selectedProject = _pickInitialProject(
        _mergeProjects(
          const ProjectCatalog(
            currentProject: null,
            projects: <ProjectSummary>[],
            pathInfo: null,
            vcsInfo: null,
          ),
          <ProjectTarget>[...recentProjects, ?lastWorkspace],
        ),
        lastWorkspace: lastWorkspace,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _availableProjects = _mergeProjects(
          const ProjectCatalog(
            currentProject: null,
            projects: <ProjectSummary>[],
            pathInfo: null,
            vcsInfo: null,
          ),
          <ProjectTarget>[...recentProjects, ?lastWorkspace],
        );
        _selectedProject = selectedProject;
        _loading = false;
        _error = 'catalog-unavailable';
      });
      if (selectedProject != null) {
        unawaited(_persistProjectSelection(selectedProject));
      }
    }
  }

  List<ProjectTarget> _mergeProjects(
    ProjectCatalog catalog,
    List<ProjectTarget> recentProjects,
  ) {
    final byDirectory = <String, ProjectTarget>{};

    void add(ProjectTarget target) {
      final existing = byDirectory[target.directory];
      byDirectory[target.directory] = existing == null
          ? target
          : ProjectTarget(
              directory: target.directory,
              label: existing.label.isNotEmpty ? existing.label : target.label,
              source: target.source ?? existing.source,
              vcs: target.vcs ?? existing.vcs,
              branch: target.branch ?? existing.branch,
              lastSession: existing.lastSession ?? target.lastSession,
            );
    }

    ProjectTarget toTarget(ProjectSummary project, {required String source}) {
      return ProjectTarget(
        directory: project.directory,
        label: project.title,
        source: source,
        vcs: project.vcs,
        branch: catalog.vcsInfo?.branch,
      );
    }

    if (catalog.currentProject != null) {
      add(toTarget(catalog.currentProject!, source: 'current'));
    }
    for (final project in catalog.projects) {
      add(toTarget(project, source: 'server'));
    }
    for (final recentProject in recentProjects) {
      add(recentProject);
    }

    return byDirectory.values.toList(growable: false);
  }

  ProjectTarget? _pickInitialProject(
    List<ProjectTarget> availableProjects, {
    required ProjectTarget? lastWorkspace,
  }) {
    ProjectTarget? match(ProjectTarget? target) {
      if (target == null) {
        return null;
      }
      for (final candidate in availableProjects) {
        if (candidate.directory == target.directory) {
          return candidate;
        }
      }
      return null;
    }

    return match(widget.initialProject) ??
        match(lastWorkspace) ??
        (availableProjects.isEmpty ? null : availableProjects.first);
  }

  Future<void> _persistProjectSelection(ProjectTarget project) async {
    await _projectStore.recordRecentProject(project);
    await _projectStore.saveLastWorkspace(
      serverStorageKey: widget.profile.storageKey,
      target: project,
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedProject = _selectedProject;
    if (_loading) {
      return _WorkspaceShellPlaceholder(
        title: widget.profile.effectiveLabel,
        subtitle: AppLocalizations.of(context)!.homeActionCheckingWorkspace,
        onExit: widget.onExit,
      );
    }

    if (selectedProject == null) {
      return _WorkspaceShellPlaceholder(
        title: widget.profile.effectiveLabel,
        subtitle: AppLocalizations.of(context)!.projectCatalogUnavailableBody,
        onExit: widget.onExit,
        onRetry: _loadProjects,
      );
    }

    return OpenCodeShellScreen(
      profile: widget.profile,
      project: selectedProject,
      capabilities: widget.capabilities,
      onExit: widget.onExit,
      availableProjects: _availableProjects,
      projectPanelError: _error,
      onSelectProject: (project) {
        if (_selectedProject?.directory == project.directory) {
          return;
        }
        setState(() {
          _selectedProject = project;
        });
        unawaited(_persistProjectSelection(project));
      },
      onReloadProjects: _loadProjects,
    );
  }
}

class _WorkspaceShellPlaceholder extends StatelessWidget {
  const _WorkspaceShellPlaceholder({
    required this.title,
    required this.subtitle,
    required this.onExit,
    this.onRetry,
  });

  final String title;
  final String subtitle;
  final VoidCallback onExit;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              surfaces.background,
              surfaces.panel,
              surfaces.background.withValues(alpha: 0.95),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          title,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(color: surfaces.muted),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: <Widget>[
                            OutlinedButton.icon(
                              onPressed: onExit,
                              icon: const Icon(Icons.arrow_back_rounded),
                              label: Text(l10n.homeBackToServersAction),
                            ),
                            if (onRetry != null)
                              ElevatedButton.icon(
                                onPressed: () => onRetry!(),
                                icon: const Icon(Icons.refresh_rounded),
                                label: Text(l10n.homeActionRetry),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
