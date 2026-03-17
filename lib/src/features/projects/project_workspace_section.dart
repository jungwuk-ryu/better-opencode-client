import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/connection/connection_models.dart';
import '../../design_system/app_spacing.dart';
import '../../design_system/app_theme.dart';
import 'project_catalog_service.dart';
import 'project_models.dart';
import 'project_store.dart';

class ProjectWorkspaceSection extends StatefulWidget {
  const ProjectWorkspaceSection({
    required this.profile,
    required this.onOpenProject,
    super.key,
  });

  final ServerProfile profile;
  final ValueChanged<ProjectTarget> onOpenProject;

  @override
  State<ProjectWorkspaceSection> createState() =>
      _ProjectWorkspaceSectionState();
}

class _ProjectWorkspaceSectionState extends State<ProjectWorkspaceSection> {
  final ProjectCatalogService _catalogService = ProjectCatalogService();
  final ProjectStore _projectStore = ProjectStore();
  final TextEditingController _manualPathController = TextEditingController();

  ProjectCatalog? _catalog;
  List<ProjectTarget> _recentProjects = const <ProjectTarget>[];
  ProjectTarget? _selectedTarget;
  String? _error;
  bool _loading = true;
  bool _inspecting = false;

  @override
  void initState() {
    super.initState();
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
    _catalogService.dispose();
    _manualPathController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final catalog = await _catalogService.fetchCatalog(widget.profile);
      final recentProjects = await _projectStore.loadRecentProjects();
      final selected = catalog.currentProject == null
          ? null
          : _toTarget(
              catalog.currentProject!,
              source: 'current',
              branch: catalog.vcsInfo?.branch,
            );
      if (!mounted) {
        return;
      }
      setState(() {
        _catalog = catalog;
        _recentProjects = recentProjects;
        _selectedTarget = selected;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  ProjectTarget _toTarget(
    ProjectSummary project, {
    required String source,
    String? branch,
  }) {
    return ProjectTarget(
      directory: project.directory,
      label: project.title,
      source: source,
      vcs: project.vcs,
      branch: branch,
    );
  }

  Future<void> _selectTarget(ProjectTarget target) async {
    final recentProjects = await _projectStore.recordRecentProject(target);
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedTarget = target;
      _recentProjects = recentProjects;
    });
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

  Future<void> _browseDirectory() async {
    final path = await getDirectoryPath();
    if (path == null || path.isEmpty) {
      return;
    }
    _manualPathController.text = path;
    await _inspectManualPath();
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
            const SizedBox(height: AppSpacing.lg),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Text(_error!, style: TextStyle(color: surfaces.danger))
            else
              LayoutBuilder(
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
          ],
        ),
      ),
    );
  }

  Widget _buildChooser(BuildContext context, AppLocalizations l10n) {
    final catalog = _catalog;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (catalog?.currentProject != null) ...<Widget>[
          _Section(
            title: l10n.currentProjectTitle,
            subtitle: l10n.currentProjectSubtitle,
            child: _ProjectChoiceTile(
              target: _toTarget(
                catalog!.currentProject!,
                source: 'current',
                branch: catalog.vcsInfo?.branch,
              ),
              selected:
                  _selectedTarget?.directory ==
                  catalog.currentProject!.directory,
              onTap: () => _selectTarget(
                _toTarget(
                  catalog.currentProject!,
                  source: 'current',
                  branch: catalog.vcsInfo?.branch,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        _Section(
          title: l10n.serverProjectsTitle,
          subtitle: l10n.serverProjectsSubtitle,
          child: (catalog?.projects.isEmpty ?? true)
              ? Text(l10n.serverProjectsEmpty)
              : Column(
                  children: catalog!.projects
                      .map(
                        (project) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                          child: _ProjectChoiceTile(
                            target: _toTarget(
                              project,
                              source: 'server',
                              branch: catalog.vcsInfo?.branch,
                            ),
                            selected:
                                _selectedTarget?.directory == project.directory,
                            onTap: () => _selectTarget(
                              _toTarget(
                                project,
                                source: 'server',
                                branch: catalog.vcsInfo?.branch,
                              ),
                            ),
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
              TextField(
                controller: _manualPathController,
                decoration: InputDecoration(
                  labelText: l10n.manualProjectPathLabel,
                  hintText: l10n.manualProjectPathHint,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  ElevatedButton(
                    onPressed: _inspecting ? null : _inspectManualPath,
                    child: Text(
                      _inspecting
                          ? l10n.projectInspectingAction
                          : l10n.projectInspectAction,
                    ),
                  ),
                  OutlinedButton(
                    onPressed: _browseDirectory,
                    child: Text(l10n.projectBrowseAction),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _Section(
          title: l10n.recentProjectsTitle,
          subtitle: l10n.recentProjectsSubtitle,
          child: _recentProjects.isEmpty
              ? Text(l10n.recentProjectsEmpty)
              : Column(
                  children: _recentProjects
                      .map(
                        (project) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                          child: _ProjectChoiceTile(
                            target: project,
                            selected:
                                _selectedTarget?.directory == project.directory,
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
                Text(
                  target.label,
                  style: Theme.of(context).textTheme.titleLarge,
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
                  onPressed: () => widget.onOpenProject(target),
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: Text(l10n.projectOpenAction),
                ),
              ],
            ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: surfaces.panelRaised.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppSpacing.md),
        border: Border.all(color: surfaces.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: surfaces.muted),
            ),
            const SizedBox(height: AppSpacing.md),
            child,
          ],
        ),
      ),
    );
  }
}

class _ProjectChoiceTile extends StatelessWidget {
  const _ProjectChoiceTile({
    required this.target,
    required this.selected,
    required this.onTap,
  });

  final ProjectTarget target;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    return ListTile(
      tileColor: selected ? surfaces.accentSoft.withValues(alpha: 0.12) : null,
      title: Text(target.label),
      subtitle: Text(target.directory),
      trailing: Text(target.source ?? '-'),
      onTap: onTap,
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(width: 120, child: Text(label)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
