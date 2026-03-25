import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/flavor.dart';
import '../../core/connection/connection_models.dart';
import '../../core/network/opencode_server_probe.dart';
import '../../core/persistence/server_profile_store.dart';
import '../../core/persistence/stale_cache_store.dart';
import '../../design_system/app_spacing.dart';
import '../../design_system/app_theme.dart';
import '../../i18n/locale_controller.dart';
import '../connection/connection_home_screen.dart';
import '../connection/connection_status_mapper.dart';
import '../launch/launch_state_model.dart';
import '../projects/project_catalog_service.dart';
import '../projects/project_models.dart';
import '../projects/project_store.dart';
import '../projects/project_workspace_section.dart';
import '../shell/opencode_shell_screen.dart';
import '../shell/server_workspace_shell_screen.dart';

const _contentMaxWidth = 1480.0;
// ignore: unused_element
const _sideColumnWidth = 420.0;
const _motionFast = Duration(milliseconds: 220);
const _motionMedium = Duration(milliseconds: 320);

typedef WorkspaceSectionBuilder =
    Widget Function(
      BuildContext context,
      ServerProfile profile,
      ValueChanged<ProjectTarget> onOpenProject,
    );

class WorkspaceHomeSnapshot {
  const WorkspaceHomeSnapshot({
    this.savedProfiles = const <ServerProfile>[],
    this.recentConnections = const <RecentConnection>[],
    this.pinnedProfileKeys = const <String>{},
    this.cachedReports = const <String, ServerProbeReport>{},
    this.selectedProfile,
    this.recentWorkspace,
  });

  final List<ServerProfile> savedProfiles;
  final List<RecentConnection> recentConnections;
  final Set<String> pinnedProfileKeys;
  final Map<String, ServerProbeReport> cachedReports;
  final ServerProfile? selectedProfile;
  final ProjectTarget? recentWorkspace;
}

class WorkspaceHomeScreen extends StatefulWidget {
  const WorkspaceHomeScreen({
    required this.flavor,
    required this.localeController,
    this.profileStore,
    this.cacheStore,
    this.probeService,
    this.projectStore,
    this.projectCatalogService,
    this.snapshot,
    this.workspaceSectionBuilder,
    super.key,
  });

  final AppFlavor flavor;
  final LocaleController localeController;
  final ServerProfileStore? profileStore;
  final StaleCacheStore? cacheStore;
  final OpenCodeServerProbe? probeService;
  final ProjectStore? projectStore;
  final ProjectCatalogService? projectCatalogService;
  final WorkspaceHomeSnapshot? snapshot;
  final WorkspaceSectionBuilder? workspaceSectionBuilder;

  @override
  State<WorkspaceHomeScreen> createState() => _WorkspaceHomeScreenState();
}

class _WorkspaceHomeScreenState extends State<WorkspaceHomeScreen> {
  late final ServerProfileStore _profileStore;
  late final StaleCacheStore _cacheStore;
  late final OpenCodeServerProbe _probeService;
  late final bool _ownsProbeService;
  late final ProjectStore _projectStore;
  late final ProjectCatalogService _projectCatalogService;
  late final bool _ownsProjectCatalogService;
  final GlobalKey<FormState> _serverFormKey = GlobalKey<FormState>();
  final TextEditingController _labelController = TextEditingController();
  final TextEditingController _baseUrlController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  List<ServerProfile> _savedProfiles = const <ServerProfile>[];
  List<RecentConnection> _recentConnections = const <RecentConnection>[];
  Set<String> _pinnedProfileKeys = const <String>{};
  Map<String, ServerProbeReport> _cachedReports =
      const <String, ServerProbeReport>{};
  ServerProfile? _selectedProfile;
  ProjectTarget? _recentWorkspace;
  ProjectTarget? _openedProject;
  bool _workspaceShellOpen = false;
  String? _editingProfileId;
  bool _loading = true;
  bool _isSaving = false;
  bool _showPassword = false;
  String? _connectingProfileKey;
  String? _workspaceNotice;
  bool _resumingWorkspace = false;
  bool _evaluatedStartupAutoResume = false;
  int _resumeWorkspaceRequestToken = 0;

  @override
  void initState() {
    super.initState();
    _profileStore = widget.profileStore ?? ServerProfileStore();
    _cacheStore = widget.cacheStore ?? StaleCacheStore();
    _probeService = widget.probeService ?? OpenCodeServerProbe();
    _ownsProbeService = widget.probeService == null;
    _projectStore = widget.projectStore ?? ProjectStore();
    _projectCatalogService =
        widget.projectCatalogService ?? ProjectCatalogService();
    _ownsProjectCatalogService = widget.projectCatalogService == null;
    final snapshot = widget.snapshot;
    if (snapshot != null) {
      _applySnapshot(snapshot);
      return;
    }
    unawaited(_loadHomeData());
  }

  @override
  void dispose() {
    if (_ownsProbeService) {
      _probeService.dispose();
    }
    if (_ownsProjectCatalogService) {
      _projectCatalogService.dispose();
    }
    _labelController.dispose();
    _baseUrlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  ServerProbeReport? get _selectedReport {
    final selectedProfile = _selectedProfile;
    if (selectedProfile == null) {
      return null;
    }
    return _cachedReports[selectedProfile.storageKey];
  }

  bool _canProceedToProjectSelection(ServerProfile? profile) {
    if (profile == null) {
      return false;
    }
    final report = _cachedReports[profile.storageKey];
    if (report == null) {
      return false;
    }
    return switch (report.classification) {
      ConnectionProbeClassification.ready => true,
      ConnectionProbeClassification.unsupportedCapabilities => true,
      ConnectionProbeClassification.authFailure => false,
      ConnectionProbeClassification.specFetchFailure => false,
      ConnectionProbeClassification.connectivityFailure => false,
    };
  }

  LaunchConnectionStatus _statusFor(ServerProfile? profile) {
    if (profile == null) {
      return LaunchConnectionStatus.unknown;
    }
    return mapLaunchConnectionStatus(_cachedReports[profile.storageKey]);
  }

  LaunchHomeState get _launchState {
    return LaunchHomeState.fromContext(
      savedServers: _savedProfiles,
      selectedServer: _selectedProfile,
      connectionStatus: _statusFor(_selectedProfile),
      project: _recentWorkspace,
    );
  }

  Future<void> _loadHomeData() async {
    final savedProfiles = await _profileStore.load();
    final recentConnections = await _profileStore.loadRecentConnections();
    final pinnedProfileKeys = await _profileStore.loadPinnedProfiles();
    final cachedReports = await _loadCachedReports(savedProfiles);

    if (!mounted) {
      return;
    }

    final selectedProfile = _pickInitialProfile(
      savedProfiles: savedProfiles,
      pinnedProfileKeys: pinnedProfileKeys,
      currentSelection: _selectedProfile,
    );
    final recentWorkspace = selectedProfile == null
        ? null
        : await _projectStore.loadLastWorkspace(selectedProfile.storageKey);

    if (!mounted) {
      return;
    }

    setState(() {
      _savedProfiles = savedProfiles;
      _recentConnections = recentConnections;
      _pinnedProfileKeys = pinnedProfileKeys;
      _cachedReports = cachedReports;
      _selectedProfile = selectedProfile;
      _recentWorkspace = recentWorkspace;
      _loading = false;
    });
    _loadEditorFromProfile(selectedProfile);
    _attemptStartupAutoResume();
  }

  Future<Map<String, ServerProbeReport>> _loadCachedReports(
    List<ServerProfile> profiles,
  ) async {
    final entries = await Future.wait(
      profiles.map((profile) async {
        final report = await _loadCachedReport(profile);
        return MapEntry<String, ServerProbeReport?>(profile.storageKey, report);
      }),
    );

    return <String, ServerProbeReport>{
      for (final entry in entries)
        if (entry.value != null) entry.key: entry.value!,
    };
  }

  Future<ServerProbeReport?> _loadCachedReport(ServerProfile profile) async {
    final entry = await _cacheStore.load('probe::${profile.storageKey}');
    if (entry == null) {
      return null;
    }

    try {
      return ServerProbeReport.fromJson(
        (jsonDecode(entry.payloadJson) as Map).cast<String, Object?>(),
      );
    } catch (_) {
      return null;
    }
  }

  void _applySnapshot(WorkspaceHomeSnapshot snapshot) {
    _savedProfiles = List<ServerProfile>.unmodifiable(snapshot.savedProfiles);
    _recentConnections = List<RecentConnection>.unmodifiable(
      snapshot.recentConnections,
    );
    _pinnedProfileKeys = Set<String>.unmodifiable(snapshot.pinnedProfileKeys);
    _cachedReports = Map<String, ServerProbeReport>.unmodifiable(
      snapshot.cachedReports,
    );
    _selectedProfile = _pickInitialProfile(
      savedProfiles: snapshot.savedProfiles,
      pinnedProfileKeys: snapshot.pinnedProfileKeys,
      currentSelection: snapshot.selectedProfile,
    );
    _recentWorkspace = snapshot.recentWorkspace;
    _loading = false;
    _loadEditorFromProfile(_selectedProfile);
  }

  void _attemptStartupAutoResume() {
    if (_evaluatedStartupAutoResume) {
      return;
    }
    _evaluatedStartupAutoResume = true;
    if (widget.workspaceSectionBuilder != null) {
      return;
    }
    final selectedProfile = _selectedProfile;
    final recentWorkspace = _recentWorkspace;
    if (selectedProfile == null ||
        recentWorkspace == null ||
        recentWorkspace.lastSession == null ||
        !_canProceedToProjectSelection(selectedProfile)) {
      return;
    }
    setState(() {
      _openedProject = recentWorkspace;
      _workspaceShellOpen = true;
    });
  }

  ServerProfile? _pickInitialProfile({
    required List<ServerProfile> savedProfiles,
    required Set<String> pinnedProfileKeys,
    required ServerProfile? currentSelection,
  }) {
    if (savedProfiles.isEmpty) {
      return null;
    }

    if (currentSelection != null) {
      for (final profile in savedProfiles) {
        if (profile.id == currentSelection.id ||
            profile.storageKey == currentSelection.storageKey) {
          return profile;
        }
      }
    }

    for (final profile in savedProfiles) {
      if (pinnedProfileKeys.contains(profile.storageKey)) {
        return profile;
      }
    }

    return savedProfiles.first;
  }

  Future<void> _openServerEditor({
    ServerProfile? profile,
    bool startInAddMode = false,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ConnectionHomeScreen(
          flavor: widget.flavor,
          localeController: widget.localeController,
          initialProfile: profile,
          startInAddMode: startInAddMode,
        ),
      ),
    );
    if (!mounted || widget.snapshot != null) {
      return;
    }
    await _loadHomeData();
  }

  Future<void> _openAddServerEditor() {
    return _openServerEditor(startInAddMode: true);
  }

  RecentConnection? _recentConnectionFor(ServerProfile profile) {
    for (final connection in _recentConnections) {
      if (connection.storageKey == profile.storageKey) {
        return connection;
      }
    }
    return null;
  }

  String _probeCacheKey(ServerProfile profile) =>
      'probe::${profile.storageKey}';

  bool _isConnectingProfile(ServerProfile? profile) {
    return profile != null && _connectingProfileKey == profile.storageKey;
  }

  ServerProfile _resolveSelectedProfile(ServerProfile profile) {
    for (final savedProfile in _savedProfiles) {
      if (savedProfile.id == profile.id ||
          savedProfile.storageKey == profile.storageKey) {
        return savedProfile;
      }
    }
    return profile;
  }

  Future<void> _connectSelectedProfile() async {
    final selectedProfile = _selectedProfile;
    if (selectedProfile == null) {
      await _openAddServerEditor();
      return;
    }
    await _connectProfile(selectedProfile);
  }

  Future<void> _connectProfile(ServerProfile profile) async {
    if (_isConnectingProfile(profile)) {
      return;
    }

    final selectedProfile = _resolveSelectedProfile(profile);
    setState(() {
      _selectedProfile = selectedProfile;
      _workspaceNotice = null;
      _openedProject = null;
      _workspaceShellOpen = false;
      _connectingProfileKey = selectedProfile.storageKey;
    });

    try {
      final report = await _probeService.probe(selectedProfile);
      await _cacheStore.save(_probeCacheKey(selectedProfile), report.toJson());
      final recents = await _profileStore.recordRecentConnection(
        RecentConnection(
          id: selectedProfile.id,
          label: selectedProfile.effectiveLabel,
          baseUrl: selectedProfile.normalizedBaseUrl,
          username: selectedProfile.username,
          attemptedAt: report.checkedAt,
          classification: report.classification,
          summary: report.summary,
        ),
      );

      if (!mounted) {
        return;
      }

      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _cachedReports = Map<String, ServerProbeReport>.unmodifiable(
          <String, ServerProbeReport>{
            ..._cachedReports,
            selectedProfile.storageKey: report,
          },
        );
        _recentConnections = recents;
        _workspaceNotice = _connectionNoticeForReport(
          report,
          l10n,
          selectedProfile.effectiveLabel,
        );
        if (widget.workspaceSectionBuilder == null &&
            (report.classification == ConnectionProbeClassification.ready ||
                report.classification ==
                    ConnectionProbeClassification.unsupportedCapabilities)) {
          _workspaceShellOpen = true;
        }
        if (_connectingProfileKey == selectedProfile.storageKey) {
          _connectingProfileKey = null;
        }
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        if (_connectingProfileKey == selectedProfile.storageKey) {
          _connectingProfileKey = null;
        }
      });
    }
  }

  String? _connectionNoticeForReport(
    ServerProbeReport report,
    AppLocalizations l10n,
    String serverLabel,
  ) {
    return switch (report.classification) {
      ConnectionProbeClassification.ready => null,
      ConnectionProbeClassification.unsupportedCapabilities => null,
      ConnectionProbeClassification.authFailure =>
        report.requiresBasicAuth
            ? l10n.homeConnectionNeedsCredentialsNotice
            : l10n.homeConnectionFailedNotice(serverLabel),
      ConnectionProbeClassification.specFetchFailure =>
        l10n.homeConnectionFailedNotice(serverLabel),
      ConnectionProbeClassification.connectivityFailure =>
        l10n.homeConnectionFailedNotice(serverLabel),
    };
  }

  void _selectProfile(ServerProfile profile) {
    setState(() {
      _resumeWorkspaceRequestToken += 1;
      _selectedProfile = profile;
      _recentWorkspace = null;
      _openedProject = null;
      _workspaceShellOpen = false;
      _resumingWorkspace = false;
      _workspaceNotice = null;
    });
    _loadEditorFromProfile(profile);
    if (widget.snapshot == null) {
      unawaited(_loadRecentWorkspace(profile));
    }
  }

  void _returnToServerSelection() {
    setState(() {
      _resumeWorkspaceRequestToken += 1;
      _selectedProfile = null;
      _recentWorkspace = null;
      _openedProject = null;
      _workspaceShellOpen = false;
      _resumingWorkspace = false;
      _connectingProfileKey = null;
      _workspaceNotice = null;
    });
    _clearEditor();
  }

  void _loadEditorFromProfile(ServerProfile? profile) {
    if (profile == null) {
      _clearEditor();
      return;
    }
    _editingProfileId = profile.id;
    _labelController.text = profile.label;
    _baseUrlController.text = profile.normalizedBaseUrl;
    _usernameController.text = profile.username ?? '';
    _passwordController.text = profile.password ?? '';
  }

  void _clearEditor() {
    _editingProfileId = null;
    _labelController.clear();
    _baseUrlController.clear();
    _usernameController.clear();
    _passwordController.clear();
  }

  ServerProfile _currentEditorProfile() {
    return ServerProfile(
      id: _editingProfileId ?? DateTime.now().microsecondsSinceEpoch.toString(),
      label: _labelController.text.trim(),
      baseUrl: _baseUrlController.text.trim(),
      username: _normalizedOptional(_usernameController.text),
      password: _normalizedOptional(_passwordController.text),
    );
  }

  String? _normalizedOptional(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String? _validateAddress(String? value) {
    final draft = ServerProfile(id: 'draft', label: '', baseUrl: value ?? '');
    final uri = draft.uriOrNull;
    if (uri == null || uri.host.isEmpty) {
      return AppLocalizations.of(context)!.connectionAddressValidation;
    }
    return null;
  }

  Future<void> _saveEditedProfile() async {
    if (!_serverFormKey.currentState!.validate()) {
      return;
    }
    final draft = _currentEditorProfile();
    setState(() {
      _isSaving = true;
      _workspaceNotice = null;
    });
    final savedProfiles = await _profileStore.upsertProfile(draft);
    final selectedProfile = savedProfiles.firstWhere(
      (profile) => profile.id == draft.id,
      orElse: () => draft,
    );
    final recentWorkspace = widget.snapshot == null
        ? await _projectStore.loadLastWorkspace(selectedProfile.storageKey)
        : _recentWorkspace;
    if (!mounted) {
      return;
    }
    setState(() {
      _savedProfiles = savedProfiles;
      _selectedProfile = selectedProfile;
      _editingProfileId = selectedProfile.id;
      _recentWorkspace = recentWorkspace;
      _isSaving = false;
    });
    _loadEditorFromProfile(selectedProfile);
  }

  Future<void> _deleteProfile(ServerProfile profile) async {
    final savedProfiles = await _profileStore.deleteProfile(profile.id);
    if (!mounted) {
      return;
    }
    final nextSelected = _selectedProfile?.id == profile.id
        ? (savedProfiles.isEmpty ? null : savedProfiles.first)
        : _selectedProfile;
    setState(() {
      _savedProfiles = savedProfiles;
      _selectedProfile = nextSelected;
      _recentWorkspace = null;
      _workspaceNotice = null;
      _workspaceShellOpen = false;
    });
    _loadEditorFromProfile(nextSelected);
  }

  void _openProject(ProjectTarget project) {
    setState(() {
      _workspaceNotice = null;
      _recentWorkspace = project;
      _openedProject = project;
      _workspaceShellOpen = widget.workspaceSectionBuilder == null;
    });
  }

  void _openWorkspaceShell() {
    setState(() {
      _workspaceNotice = null;
      _workspaceShellOpen = true;
    });
  }

  Future<void> _loadRecentWorkspace(ServerProfile? profile) async {
    final recentWorkspace = profile == null
        ? null
        : await _projectStore.loadLastWorkspace(profile.storageKey);
    if (!mounted) {
      return;
    }
    if (_selectedProfile?.storageKey != profile?.storageKey) {
      return;
    }
    setState(() {
      _recentWorkspace = recentWorkspace;
    });
  }

  bool _isActiveResumeWorkspace(int requestToken, ServerProfile profile) {
    return mounted &&
        requestToken == _resumeWorkspaceRequestToken &&
        _selectedProfile?.storageKey == profile.storageKey;
  }

  ProjectTarget? _resolvedProjectTarget(
    ProjectCatalog catalog,
    ProjectTarget target,
  ) {
    final currentProject = catalog.currentProject;
    if (currentProject != null &&
        currentProject.directory == target.directory) {
      return ProjectTarget(
        directory: currentProject.directory,
        label: currentProject.title,
        source: 'current',
        vcs: currentProject.vcs,
        branch: catalog.vcsInfo?.branch,
        lastSession: target.lastSession,
      );
    }

    for (final project in catalog.projects) {
      if (project.directory != target.directory) {
        continue;
      }
      return ProjectTarget(
        directory: project.directory,
        label: project.title,
        source: 'server',
        vcs: project.vcs,
        branch: catalog.vcsInfo?.branch,
        lastSession: target.lastSession,
      );
    }

    return null;
  }

  Future<void> _resumeWorkspaceFromHome() async {
    final l10n = AppLocalizations.of(context)!;
    final selectedProfile = _selectedProfile;
    final recentWorkspace = _launchState.routingState.project;
    if (selectedProfile == null ||
        recentWorkspace == null ||
        _resumingWorkspace) {
      return;
    }
    final requestToken = ++_resumeWorkspaceRequestToken;

    setState(() {
      _resumingWorkspace = true;
      _workspaceNotice = null;
    });

    try {
      final catalog = await _projectCatalogService.fetchCatalog(
        selectedProfile,
      );
      if (!_isActiveResumeWorkspace(requestToken, selectedProfile)) {
        return;
      }
      final resolvedTarget = _resolvedProjectTarget(catalog, recentWorkspace);
      if (resolvedTarget == null) {
        await _projectStore.clearLastWorkspace(selectedProfile.storageKey);
        if (!_isActiveResumeWorkspace(requestToken, selectedProfile)) {
          return;
        }
        setState(() {
          _recentWorkspace = null;
          _workspaceNotice = l10n.homeNoticeWorkspaceUnavailable;
        });
        return;
      }

      await _projectStore.saveLastWorkspace(
        serverStorageKey: selectedProfile.storageKey,
        target: resolvedTarget,
      );
      if (!_isActiveResumeWorkspace(requestToken, selectedProfile)) {
        return;
      }
      _openProject(resolvedTarget);
    } catch (_) {
      if (!_isActiveResumeWorkspace(requestToken, selectedProfile)) {
        return;
      }
      setState(() {
        _workspaceNotice = l10n.homeNoticeWorkspaceResumeFailed;
      });
    } finally {
      if (_isActiveResumeWorkspace(requestToken, selectedProfile)) {
        setState(() {
          _resumingWorkspace = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedReport = _selectedReport;
    if (_workspaceShellOpen &&
        widget.workspaceSectionBuilder == null &&
        _selectedProfile != null &&
        selectedReport != null) {
      return ServerWorkspaceShellScreen(
        profile: _selectedProfile!,
        capabilities: selectedReport.capabilityRegistry,
        initialProject: _openedProject,
        projectCatalogService: _projectCatalogService,
        projectStore: _projectStore,
        onExit: () {
          setState(() {
            _workspaceShellOpen = false;
            _openedProject = null;
          });
        },
      );
    }
    if (_openedProject != null &&
        _selectedProfile != null &&
        selectedReport != null) {
      return OpenCodeShellScreen(
        profile: _selectedProfile!,
        project: _openedProject!,
        capabilities: selectedReport.capabilityRegistry,
        onExit: () {
          setState(() {
            _openedProject = null;
          });
        },
      );
    }

    final surfaces = Theme.of(context).extension<AppSurfaces>()!;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              surfaces.background,
              surfaces.panel,
              surfaces.background.withValues(alpha: 0.94),
            ],
          ),
        ),
        child: Stack(
          children: <Widget>[
            Positioned(
              top: -120,
              left: -80,
              child: _GlowOrb(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.16),
                size: 300,
              ),
            ),
            Positioned(
              right: -100,
              top: 160,
              child: _GlowOrb(
                color: surfaces.accentSoft.withValues(alpha: 0.1),
                size: 260,
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: _contentMaxWidth,
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return _buildSimpleHomeContent(
                          context,
                          isWide:
                              constraints.maxWidth >=
                              AppSpacing.wideLayoutBreakpoint,
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleHomeContent(BuildContext context, {required bool isWide}) {
    final serverManager = _buildServerManagerCard(context);
    final workspacePane = _buildSimpleWorkspacePane(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _buildHeader(context),
        const SizedBox(height: AppSpacing.lg),
        if (isWide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(width: 440, child: serverManager),
              const SizedBox(width: AppSpacing.lg),
              Expanded(child: workspacePane),
            ],
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              serverManager,
              const SizedBox(height: AppSpacing.lg),
              workspacePane,
            ],
          ),
      ],
    );
  }

  Widget _buildServerManagerCard(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return _SectionCard(
      title: l10n.homeSavedServersTitle,
      subtitle: l10n.homeServerPanelSubtitle,
      action: TextButton.icon(
        onPressed: _returnToServerSelection,
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.homeAddServerAction),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildServerForm(context),
            const SizedBox(height: AppSpacing.lg),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.lg),
            _buildSavedServerList(context),
          ],
        ),
      ),
    );
  }

  Widget _buildServerForm(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final editingExisting = _editingProfileId != null;

    return Form(
      key: _serverFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            editingExisting
                ? l10n.homeEditServerAction
                : l10n.homeAddServerAction,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _labelController,
            decoration: InputDecoration(
              labelText: l10n.connectionProfileLabel,
              hintText: l10n.connectionProfileLabelHint,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _baseUrlController,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(labelText: l10n.connectionAddressLabel),
            validator: _validateAddress,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _usernameController,
            decoration: InputDecoration(
              labelText: l10n.connectionUsernameLabel,
            ),
            autofillHints: const <String>[AutofillHints.username],
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _passwordController,
            obscureText: !_showPassword,
            decoration: InputDecoration(
              labelText: l10n.connectionPasswordLabel,
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
            autofillHints: const <String>[AutofillHints.password],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveEditedProfile,
                icon: const Icon(Icons.save_outlined),
                label: Text(l10n.saveProfile),
              ),
              OutlinedButton.icon(
                onPressed: _returnToServerSelection,
                icon: const Icon(Icons.add_link_rounded),
                label: Text(l10n.homeAddServerAction),
              ),
              if (editingExisting && _selectedProfile != null)
                OutlinedButton.icon(
                  onPressed: () => _deleteProfile(_selectedProfile!),
                  icon: const Icon(Icons.delete_outline),
                  label: Text(l10n.deleteProfile),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSavedServerList(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_savedProfiles.isEmpty) {
      return _EmptyStateBlock(
        title: l10n.homeSavedServersEmptyTitle,
        subtitle: l10n.homeSavedServersEmptySubtitle,
      );
    }

    final sortedProfiles = _savedProfiles.toList()
      ..sort(
        (a, b) => a.effectiveLabel.toLowerCase().compareTo(
          b.effectiveLabel.toLowerCase(),
        ),
      );

    return Column(
      children: sortedProfiles
          .map(
            (profile) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _SimpleServerRow(
                profile: profile,
                selected: _selectedProfile?.id == profile.id,
                connecting: _isConnectingProfile(profile),
                connectLabel: l10n.homeConnectServerAction,
                editLabel: l10n.homeEditServerAction,
                deleteLabel: l10n.deleteProfile,
                onSelect: () => _selectProfile(profile),
                onConnect: () => _connectProfile(profile),
                onEdit: () {
                  _selectProfile(profile);
                  _loadEditorFromProfile(profile);
                },
                onDelete: () => _deleteProfile(profile),
              ),
            ),
          )
          .toList(growable: false),
    );
  }

  Widget _buildSimpleWorkspacePane(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final selectedProfile = _selectedProfile;

    if (_loading) {
      return _SectionCard(
        title: l10n.homeWorkspaceSectionTitle,
        subtitle: l10n.homeWorkspaceLoadingSubtitle,
        child: const Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (selectedProfile == null) {
      return _wrapWorkspaceSurface(
        _SectionCard(
          title: l10n.homeChooseServerLabel,
          subtitle: l10n.homeWorkspaceSelectionHint,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: _EmptyStateBlock(
              title: l10n.homeChooseServerLabel,
              subtitle: l10n.homeWorkspaceSelectionHint,
            ),
          ),
        ),
      );
    }

    if (_isConnectingProfile(selectedProfile)) {
      return _wrapWorkspaceSurface(
        _SectionCard(
          title: selectedProfile.effectiveLabel,
          subtitle: l10n.homeActionCheckingServer,
          child: const Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      );
    }

    if (_canProceedToProjectSelection(selectedProfile)) {
      if (widget.workspaceSectionBuilder == null) {
        final resumePanel = _buildResumePanel(context, _launchState);
        return _wrapWorkspaceSurface(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (resumePanel != null) ...<Widget>[
                resumePanel,
                const SizedBox(height: AppSpacing.lg),
              ],
              _SectionCard(
                title: selectedProfile.effectiveLabel,
                subtitle: l10n.homeWorkspaceTitleContinueFromHome,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _EmptyStateBlock(
                        title: l10n.shellChatHeaderTitle,
                        subtitle: l10n.homeWorkspaceSubtitleReady,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Semantics(
                        button: true,
                        label: l10n.homeActionContinue,
                        child: ElevatedButton.icon(
                          onPressed: _openWorkspaceShell,
                          icon: const Icon(Icons.chat_bubble_outline_rounded),
                          label: Text(l10n.homeActionContinue),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }
      final resumePanel = _buildResumePanel(context, _launchState);
      final builder =
          widget.workspaceSectionBuilder ??
          (
            BuildContext context,
            ServerProfile profile,
            ValueChanged<ProjectTarget> onOpenProject,
          ) {
            return ProjectWorkspaceSection(
              profile: profile,
              projectCatalogService: _projectCatalogService,
              projectStore: _projectStore,
              cacheStore: _cacheStore,
              onOpenProject: onOpenProject,
            );
          };
      return _wrapWorkspaceSurface(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (resumePanel != null) ...<Widget>[
              resumePanel,
              const SizedBox(height: AppSpacing.lg),
            ],
            builder(context, selectedProfile, _openProject),
          ],
        ),
      );
    }

    return _wrapWorkspaceSurface(
      _SectionCard(
        title: selectedProfile.effectiveLabel,
        subtitle: l10n.homeWorkspaceConnectHint,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _EmptyStateBlock(
                title: l10n.homeWorkspaceSectionTitle,
                subtitle: l10n.homeWorkspaceConnectHint,
              ),
              const SizedBox(height: AppSpacing.md),
              Semantics(
                container: true,
                label: l10n.homeA11yWorkspacePrimaryAction,
                button: true,
                child: ElevatedButton.icon(
                  onPressed: () => _connectProfile(selectedProfile),
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: Text(l10n.homeConnectServerAction),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildPrimaryColumn(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _buildHeader(context),
        const SizedBox(height: AppSpacing.lg),
        _buildHeroCard(context),
        const SizedBox(height: AppSpacing.lg),
        AnimatedSwitcher(
          duration: _motionMedium,
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.04),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: KeyedSubtree(
            key: ValueKey<String>(
              '${_selectedProfile?.storageKey ?? 'no-profile'}-${_statusFor(_selectedProfile).name}',
            ),
            child: _buildWorkspaceSurface(context),
          ),
        ),
      ],
    );
  }

  // ignore: unused_element
  Widget _buildSideColumn(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _buildSavedServersCard(context),
        const SizedBox(height: AppSpacing.lg),
        _buildRecentActivityCard(context),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final l10n = AppLocalizations.of(context)!;
    final selectedProfile = _selectedProfile;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                l10n.homeHeaderEyebrow,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: surfaces.accentSoft),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.appTitle,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.homeHeaderSubtitle,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: surfaces.muted),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          alignment: WrapAlignment.end,
          children: <Widget>[
            if (selectedProfile != null)
              Semantics(
                container: true,
                label: l10n.homeA11yBackToServersAction,
                button: true,
                child: OutlinedButton.icon(
                  onPressed: _returnToServerSelection,
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: Text(l10n.homeBackToServersAction),
                ),
              ),
            Semantics(
              container: true,
              label: l10n.homeA11yAddServerAction,
              button: true,
              child: TextButton.icon(
                onPressed: _returnToServerSelection,
                icon: const Icon(Icons.add_link_rounded),
                label: Text(l10n.homeAddServerAction),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeroCard(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final launchState = _launchState;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                theme.colorScheme.primary.withValues(alpha: 0.18),
                surfaces.panelRaised.withValues(alpha: 0.96),
                surfaces.panel.withValues(alpha: 0.96),
              ],
            ),
            border: Border.all(color: surfaces.line),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 780;
                final intro = _buildHeroIntro(context, launchState);
                final actions = _buildHeroActions(context, launchState);
                if (stacked) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      intro,
                      const SizedBox(height: AppSpacing.lg),
                      actions,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(child: intro),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(child: actions),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroIntro(BuildContext context, LaunchHomeState launchState) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final l10n = AppLocalizations.of(context)!;
    final selectedProfile = _selectedProfile;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _StatusPill(
          icon: _statusIcon(_statusFor(selectedProfile)),
          label: _heroStatusLabel(launchState, l10n),
          color: _statusColor(context, _statusFor(selectedProfile)),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: AppSpacing.xxl + AppSpacing.md,
              height: AppSpacing.xxl + AppSpacing.md,
              decoration: BoxDecoration(
                color: surfaces.panelEmphasis.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(AppSpacing.lg),
                border: Border.all(color: surfaces.line),
              ),
              child: Icon(
                Icons.terminal_rounded,
                size: AppSpacing.lg,
                color: surfaces.accentSoft,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _heroTitle(launchState, l10n),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _heroSubtitle(launchState, l10n),
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(color: surfaces.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            _MetricChip(
              icon: Icons.storage_rounded,
              label: l10n.homeMetricSavedServers,
              value: '${_savedProfiles.length}',
            ),
            _MetricChip(
              icon: Icons.history_toggle_off_rounded,
              label: l10n.homeMetricRecentActivity,
              value: '${_recentConnections.length}',
            ),
            _MetricChip(
              icon: Icons.folder_open_rounded,
              label: l10n.homeMetricCurrentFocus,
              value:
                  selectedProfile?.effectiveLabel ?? l10n.homeChooseServerLabel,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeroActions(BuildContext context, LaunchHomeState launchState) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final l10n = AppLocalizations.of(context)!;
    final selectedProfile = _selectedProfile;
    final resumePanel = _buildResumePanel(context, launchState);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (resumePanel != null) ...<Widget>[
          resumePanel,
          const SizedBox(height: AppSpacing.lg),
        ],
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            Semantics(
              container: true,
              label: l10n.homeA11yAddServerAction,
              button: true,
              child: ElevatedButton.icon(
                onPressed: () => _openAddServerEditor(),
                icon: const Icon(Icons.add_link_rounded),
                label: Text(l10n.homeAddServerAction),
              ),
            ),
            if (selectedProfile != null)
              Semantics(
                container: true,
                label: l10n.homeA11yEditSelectedServerAction,
                button: true,
                child: OutlinedButton.icon(
                  onPressed: () => _openServerEditor(profile: selectedProfile),
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(l10n.homeEditSelectedServerAction),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        DecoratedBox(
          decoration: BoxDecoration(
            color: surfaces.panelMuted.withValues(alpha: 0.58),
            borderRadius: BorderRadius.circular(AppSpacing.lg),
            border: Border.all(color: surfaces.lineSoft),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l10n.homeNextStepsTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                _FeatureLine(
                  icon: Icons.bookmark_added_outlined,
                  label: l10n.homeNextStepsPinnedServers,
                ),
                const SizedBox(height: AppSpacing.sm),
                _FeatureLine(
                  icon: Icons.folder_copy_outlined,
                  label: l10n.homeNextStepsProjects,
                ),
                const SizedBox(height: AppSpacing.sm),
                _FeatureLine(
                  icon: Icons.route_outlined,
                  label: l10n.homeNextStepsRetryEdit,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget? _buildResumePanel(BuildContext context, LaunchHomeState launchState) {
    final l10n = AppLocalizations.of(context)!;
    final routingState = launchState.routingState;
    final project = routingState.project;
    if (project == null ||
        _statusFor(_selectedProfile) != LaunchConnectionStatus.ready) {
      return null;
    }

    final title = switch (routingState.status) {
      LaunchRoutingStatus.readyToResume => l10n.homeResumeLastWorkspaceTitle,
      LaunchRoutingStatus.sessionMissing => l10n.homeOpenLastProjectTitle,
      LaunchRoutingStatus.projectMissing => '',
    };
    if (title.isEmpty) {
      return null;
    }

    final body = switch (routingState.status) {
      LaunchRoutingStatus.readyToResume => l10n.homeResumeLastWorkspaceBody(
        project.label,
      ),
      LaunchRoutingStatus.sessionMissing => l10n.homeOpenLastProjectBody(
        project.label,
      ),
      LaunchRoutingStatus.projectMissing => '',
    };
    final actionLabel = switch (routingState.status) {
      LaunchRoutingStatus.readyToResume => l10n.homeResumeLastWorkspaceAction,
      LaunchRoutingStatus.sessionMissing => l10n.homeOpenLastProjectAction,
      LaunchRoutingStatus.projectMissing => '',
    };

    return _ResumeWorkspacePanel(
      title: title,
      body: body,
      projectLabel: project.label,
      sessionTitle: (routingState.session?.title?.trim().isEmpty ?? true)
          ? null
          : routingState.session?.title,
      sessionStatus: routingState.session?.status,
      busy: _resumingWorkspace,
      actionLabel: actionLabel,
      onPressed: _resumeWorkspaceFromHome,
    );
  }

  Widget _buildWorkspaceSurface(BuildContext context) {
    final launchState = _launchState;
    final l10n = AppLocalizations.of(context)!;
    final selectedProfile = _selectedProfile;
    final selectedStatus = _statusFor(selectedProfile);
    final isConnecting = _isConnectingProfile(selectedProfile);

    if (_loading) {
      return _wrapWorkspaceSurface(
        _SectionCard(
          title: l10n.homeWorkspaceSectionTitle,
          subtitle: l10n.homeWorkspaceLoadingSubtitle,
          child: const Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      );
    }

    if (launchState.serverState.inventory == LaunchServerInventory.noServers) {
      return _wrapWorkspaceSurface(
        _SectionCard(
          title: l10n.homeWorkspaceSectionTitle,
          subtitle: l10n.homeWorkspaceEmptySubtitle,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 720;
                final blocks = <Widget>[
                  _FeatureBlock(
                    icon: Icons.storage_rounded,
                    title: l10n.homeWorkspaceFeatureSaveTitle,
                    subtitle: l10n.homeWorkspaceFeatureSaveBody,
                  ),
                  _FeatureBlock(
                    icon: Icons.folder_open_rounded,
                    title: l10n.homeWorkspaceFeatureChooseTitle,
                    subtitle: l10n.homeWorkspaceFeatureChooseBody,
                  ),
                  _FeatureBlock(
                    icon: Icons.history_rounded,
                    title: l10n.homeWorkspaceFeatureRecentTitle,
                    subtitle: l10n.homeWorkspaceFeatureRecentBody,
                  ),
                ];
                if (stacked) {
                  final children = <Widget>[];
                  for (var index = 0; index < blocks.length; index += 1) {
                    if (index > 0) {
                      children.add(const SizedBox(height: AppSpacing.sm));
                    }
                    children.add(blocks[index]);
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: children,
                  );
                }
                final children = <Widget>[];
                for (var index = 0; index < blocks.length; index += 1) {
                  if (index > 0) {
                    children.add(const SizedBox(width: AppSpacing.sm));
                  }
                  children.add(Expanded(child: blocks[index]));
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: children,
                );
              },
            ),
          ),
        ),
      );
    }

    if (selectedProfile != null &&
        _canProceedToProjectSelection(selectedProfile) &&
        !isConnecting) {
      if (widget.workspaceSectionBuilder == null) {
        final resumePanel = _buildResumePanel(context, _launchState);
        return _wrapWorkspaceSurface(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (resumePanel != null) ...<Widget>[
                resumePanel,
                const SizedBox(height: AppSpacing.lg),
              ],
              _SectionCard(
                title: selectedProfile.effectiveLabel,
                subtitle: l10n.homeWorkspaceTitleContinueFromHome,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _EmptyStateBlock(
                        title: l10n.shellChatHeaderTitle,
                        subtitle: l10n.homeWorkspaceSubtitleReady,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Semantics(
                        button: true,
                        label: l10n.homeActionContinue,
                        child: ElevatedButton.icon(
                          onPressed: _openWorkspaceShell,
                          icon: const Icon(Icons.chat_bubble_outline_rounded),
                          label: Text(l10n.homeActionContinue),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }
      final builder =
          widget.workspaceSectionBuilder ??
          (
            BuildContext context,
            ServerProfile profile,
            ValueChanged<ProjectTarget> onOpenProject,
          ) {
            return ProjectWorkspaceSection(
              profile: profile,
              projectCatalogService: _projectCatalogService,
              projectStore: _projectStore,
              cacheStore: _cacheStore,
              onOpenProject: onOpenProject,
            );
          };
      return _wrapWorkspaceSurface(
        builder(context, selectedProfile, _openProject),
      );
    }

    return _wrapWorkspaceSurface(
      _SectionCard(
        title: l10n.homeWorkspaceSectionTitle,
        subtitle: _workspaceSubtitle(selectedStatus, l10n),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (selectedProfile != null)
                _ServerStatusBanner(
                  key: const Key('server-status-banner'),
                  title: _workspaceTitle(
                    selectedProfile,
                    selectedStatus,
                    l10n,
                    isConnecting: isConnecting,
                  ),
                  subtitle: _workspaceBody(
                    selectedProfile,
                    selectedStatus,
                    l10n,
                    report: _selectedReport,
                    isConnecting: isConnecting,
                  ),
                  icon: isConnecting
                      ? Icons.sync_rounded
                      : _statusIcon(selectedStatus),
                  color: isConnecting
                      ? Theme.of(context).colorScheme.primary
                      : _statusColor(context, selectedStatus),
                  busy: isConnecting,
                  primaryActionLabel: _workspacePrimaryActionLabel(
                    selectedStatus,
                    l10n,
                    isConnecting: isConnecting,
                  ),
                  onPrimaryAction: isConnecting
                      ? null
                      : _connectSelectedProfile,
                  onSecondaryAction: () =>
                      _openServerEditor(profile: selectedProfile),
                )
              else
                _EmptyStateBlock(
                  title: _workspaceTitle(selectedProfile, selectedStatus, l10n),
                  subtitle: _workspaceBody(
                    selectedProfile,
                    selectedStatus,
                    l10n,
                    report: _selectedReport,
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  Semantics(
                    container: true,
                    label: l10n.homeA11yWorkspacePrimaryAction,
                    button: true,
                    child: ElevatedButton.icon(
                      onPressed: selectedProfile == null
                          ? () => _openAddServerEditor()
                          : isConnecting
                          ? null
                          : _connectSelectedProfile,
                      icon: Icon(
                        selectedProfile == null
                            ? Icons.add_link_rounded
                            : isConnecting
                            ? Icons.sync_rounded
                            : Icons.arrow_forward_rounded,
                      ),
                      label: Text(
                        selectedProfile == null
                            ? l10n.homeAddServerAction
                            : _workspacePrimaryActionLabel(
                                selectedStatus,
                                l10n,
                                isConnecting: isConnecting,
                              ),
                      ),
                    ),
                  ),
                  if (selectedProfile != null)
                    Semantics(
                      container: true,
                      label: l10n.homeA11yEditServerAction,
                      button: true,
                      child: OutlinedButton.icon(
                        onPressed: isConnecting
                            ? null
                            : () => _openServerEditor(profile: selectedProfile),
                        icon: const Icon(Icons.edit_outlined),
                        label: Text(l10n.homeEditServerAction),
                      ),
                    ),
                  if (_savedProfiles.length > 1)
                    Semantics(
                      container: true,
                      label: l10n.homeA11ySwitchServerAction,
                      button: true,
                      child: OutlinedButton.icon(
                        onPressed: isConnecting
                            ? null
                            : () {
                                final nextProfile = _nextProfileAfter(
                                  selectedProfile,
                                );
                                if (nextProfile != null) {
                                  _selectProfile(nextProfile);
                                }
                              },
                        icon: const Icon(Icons.swap_horiz_rounded),
                        label: Text(l10n.homeSwitchServerAction),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _wrapWorkspaceSurface(Widget child) {
    final notice = _workspaceNotice;
    if (notice == null) {
      return child;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _WorkspaceNoticeBanner(message: notice),
        const SizedBox(height: AppSpacing.md),
        child,
      ],
    );
  }

  ServerProfile? _nextProfileAfter(ServerProfile? profile) {
    if (_savedProfiles.length < 2) {
      return null;
    }

    final currentIndex = _savedProfiles.indexWhere(
      (candidate) =>
          candidate.id == profile?.id ||
          candidate.storageKey == profile?.storageKey,
    );
    if (currentIndex < 0) {
      return _savedProfiles.first;
    }
    final nextIndex = (currentIndex + 1) % _savedProfiles.length;
    return _savedProfiles[nextIndex];
  }

  Widget _buildSavedServersCard(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sortedProfiles = _savedProfiles.toList()
      ..sort((a, b) {
        final aPinned = _pinnedProfileKeys.contains(a.storageKey);
        final bPinned = _pinnedProfileKeys.contains(b.storageKey);
        if (aPinned != bPinned) {
          return aPinned ? -1 : 1;
        }
        return a.effectiveLabel.toLowerCase().compareTo(
          b.effectiveLabel.toLowerCase(),
        );
      });

    return _SectionCard(
      title: l10n.homeSavedServersTitle,
      subtitle: l10n.homeSavedServersSubtitle,
      action: Semantics(
        container: true,
        label: l10n.homeA11yAddServerAction,
        button: true,
        child: TextButton.icon(
          onPressed: () => _openAddServerEditor(),
          icon: const Icon(Icons.add_rounded),
          label: Text(l10n.homeAddServerAction),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: sortedProfiles.isEmpty
            ? _EmptyStateBlock(
                title: l10n.homeSavedServersEmptyTitle,
                subtitle: l10n.homeSavedServersEmptySubtitle,
              )
            : Column(
                children: sortedProfiles
                    .map((profile) {
                      final status = _statusFor(profile);
                      final isSelected =
                          _selectedProfile?.id == profile.id ||
                          _selectedProfile?.storageKey == profile.storageKey;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _ServerCard(
                          label: profile.effectiveLabel,
                          address: profile.normalizedBaseUrl,
                          selected: isSelected,
                          pinned: _pinnedProfileKeys.contains(
                            profile.storageKey,
                          ),
                          statusLabel: _serverStatusLabel(status, l10n),
                          statusSummary: _serverCardSummary(
                            profile,
                            status,
                            l10n,
                            report: _cachedReports[profile.storageKey],
                          ),
                          statusIcon: _statusIcon(status),
                          statusColor: _statusColor(context, status),
                          activityLabel: _recentActivityLabel(
                            context,
                            _recentConnectionFor(profile),
                          ),
                          credentialsLabel: _credentialsLabel(profile, l10n),
                          primaryActionLabel: _primaryActionLabel(
                            status,
                            l10n,
                            profile: profile,
                          ),
                          primaryActionBusy: _isConnectingProfile(profile),
                          onTap: () => _selectProfile(profile),
                          onPrimaryAction:
                              _canProceedToProjectSelection(profile)
                              ? () => _selectProfile(profile)
                              : () => _connectProfile(profile),
                          onEdit: () => _openServerEditor(profile: profile),
                        ),
                      );
                    })
                    .toList(growable: false),
              ),
      ),
    );
  }

  Widget _buildRecentActivityCard(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _SectionCard(
      title: l10n.homeRecentActivityTitle,
      subtitle: l10n.homeRecentActivitySubtitle,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: _recentConnections.isEmpty
            ? _EmptyStateBlock(
                title: l10n.homeRecentActivityEmptyTitle,
                subtitle: l10n.homeRecentActivityEmptySubtitle,
              )
            : Column(
                children: _recentConnections
                    .map(
                      (connection) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _RecentActivityTile(connection: connection),
                      ),
                    )
                    .toList(growable: false),
              ),
      ),
    );
  }

  String _heroStatusLabel(LaunchHomeState launchState, AppLocalizations l10n) {
    final selectedProfile = _selectedProfile;
    if (launchState.serverState.inventory == LaunchServerInventory.noServers) {
      return l10n.homeStatusNewHome;
    }
    if (selectedProfile == null) {
      return l10n.homeStatusChooseServer;
    }
    if (_isConnectingProfile(selectedProfile)) {
      return l10n.homeStatusCheckingServer;
    }
    return switch (_statusFor(selectedProfile)) {
      LaunchConnectionStatus.ready => l10n.homeStatusReadyForProjects,
      LaunchConnectionStatus.signInRequired => l10n.homeStatusSignInRequired,
      LaunchConnectionStatus.offline => l10n.homeStatusServerOffline,
      LaunchConnectionStatus.incompatible => l10n.homeStatusNeedsAttention,
      LaunchConnectionStatus.unknown => l10n.homeStatusAwaitingSetup,
    };
  }

  String _heroTitle(LaunchHomeState launchState, AppLocalizations l10n) {
    return switch (launchState.serverState.inventory) {
      LaunchServerInventory.noServers => l10n.homeHeroTitleNoServers,
      LaunchServerInventory.oneServer => l10n.homeHeroTitleOneServer,
      LaunchServerInventory.multipleServers => l10n.homeHeroTitleManyServers,
    };
  }

  String _heroSubtitle(LaunchHomeState launchState, AppLocalizations l10n) {
    return switch (launchState.serverState.inventory) {
      LaunchServerInventory.noServers => l10n.homeHeroBodyNoServers,
      LaunchServerInventory.oneServer => l10n.homeHeroBodyOneServer,
      LaunchServerInventory.multipleServers => l10n.homeHeroBodyManyServers,
    };
  }

  String _workspaceSubtitle(
    LaunchConnectionStatus status,
    AppLocalizations l10n,
  ) {
    return switch (status) {
      LaunchConnectionStatus.ready => l10n.homeWorkspaceSubtitleReady,
      LaunchConnectionStatus.signInRequired => l10n.homeWorkspaceSubtitleSignIn,
      LaunchConnectionStatus.offline => l10n.homeWorkspaceSubtitleOffline,
      LaunchConnectionStatus.incompatible => l10n.homeWorkspaceSubtitleUpdate,
      LaunchConnectionStatus.unknown => l10n.homeWorkspaceSubtitleUnknown,
    };
  }

  String _workspaceTitle(
    ServerProfile? profile,
    LaunchConnectionStatus status,
    AppLocalizations l10n, {
    bool isConnecting = false,
  }) {
    if (profile == null) {
      return l10n.homeWorkspaceTitleChooseServer;
    }
    if (isConnecting) {
      return l10n.homeWorkspaceTitleChecking(profile.effectiveLabel);
    }
    return switch (status) {
      LaunchConnectionStatus.ready => l10n.homeWorkspaceTitleReady,
      LaunchConnectionStatus.signInRequired =>
        l10n.homeWorkspaceTitleSignInRequired,
      LaunchConnectionStatus.offline => l10n.homeWorkspaceTitleOffline,
      LaunchConnectionStatus.incompatible => l10n.homeWorkspaceTitleUpdate,
      LaunchConnectionStatus.unknown => l10n.homeWorkspaceTitleContinueFromHome,
    };
  }

  String _workspaceBody(
    ServerProfile? profile,
    LaunchConnectionStatus status,
    AppLocalizations l10n, {
    ServerProbeReport? report,
    bool isConnecting = false,
  }) {
    final label = profile?.effectiveLabel ?? l10n.homeThisServerLabel;
    if (isConnecting) {
      return l10n.homeWorkspaceBodyChecking;
    }
    if (status == LaunchConnectionStatus.signInRequired &&
        report?.requiresBasicAuth == true) {
      return l10n.homeWorkspaceBodyBasicAuthRequired(label);
    }
    return switch (status) {
      LaunchConnectionStatus.ready => l10n.homeWorkspaceBodyReady(label),
      LaunchConnectionStatus.signInRequired =>
        l10n.homeWorkspaceBodySignInRequired(label),
      LaunchConnectionStatus.offline => l10n.homeWorkspaceBodyOffline(label),
      LaunchConnectionStatus.incompatible =>
        l10n.homeWorkspaceBodyUpdateRequired(label),
      LaunchConnectionStatus.unknown => l10n.homeWorkspaceBodyUnknown,
    };
  }

  String _serverStatusLabel(
    LaunchConnectionStatus status,
    AppLocalizations l10n,
  ) {
    return switch (status) {
      LaunchConnectionStatus.ready => l10n.homeStatusReadyForProjects,
      LaunchConnectionStatus.signInRequired => l10n.homeStatusSignInRequired,
      LaunchConnectionStatus.offline => l10n.homeStatusServerOffline,
      LaunchConnectionStatus.incompatible => l10n.homeStatusNeedsAttention,
      LaunchConnectionStatus.unknown => l10n.homeStatusAwaitingSetup,
    };
  }

  String _serverCardSummary(
    ServerProfile profile,
    LaunchConnectionStatus status,
    AppLocalizations l10n, {
    ServerProbeReport? report,
  }) {
    if (status == LaunchConnectionStatus.signInRequired &&
        report?.requiresBasicAuth == true) {
      return l10n.homeServerCardBodyBasicAuthRequired;
    }
    return switch (status) {
      LaunchConnectionStatus.ready => l10n.homeServerCardBodyReady,
      LaunchConnectionStatus.signInRequired => l10n.homeServerCardBodySignIn,
      LaunchConnectionStatus.offline => l10n.homeServerCardBodyOffline,
      LaunchConnectionStatus.incompatible => l10n.homeServerCardBodyUpdate,
      LaunchConnectionStatus.unknown =>
        profile.hasBasicAuth
            ? l10n.homeServerCardBodyUnknownWithAuth
            : l10n.homeServerCardBodyUnknown,
    };
  }

  String _recentActivityLabel(
    BuildContext context,
    RecentConnection? connection,
  ) {
    final l10n = AppLocalizations.of(context)!;
    if (connection == null) {
      return l10n.homeRecentActivityNotUsed;
    }
    final locale = Localizations.localeOf(context).toLanguageTag();
    final timestamp = DateFormat.yMMMd(
      locale,
    ).add_Hm().format(connection.attemptedAt.toLocal());
    return l10n.homeRecentActivityLastUsed(timestamp);
  }

  String _credentialsLabel(ServerProfile profile, AppLocalizations l10n) {
    return profile.hasBasicAuth
        ? l10n.homeCredentialsSaved
        : l10n.homeCredentialsMissing;
  }

  String _primaryActionLabel(
    LaunchConnectionStatus status,
    AppLocalizations l10n, {
    ServerProfile? profile,
  }) {
    if (_canProceedToProjectSelection(profile)) {
      return l10n.homeActionContinue;
    }
    return switch (status) {
      LaunchConnectionStatus.ready => l10n.homeActionContinue,
      LaunchConnectionStatus.signInRequired => l10n.homeActionRetry,
      LaunchConnectionStatus.offline => l10n.homeActionRetry,
      LaunchConnectionStatus.incompatible => l10n.homeActionRetry,
      LaunchConnectionStatus.unknown => l10n.homeActionContinue,
    };
  }

  String _workspacePrimaryActionLabel(
    LaunchConnectionStatus status,
    AppLocalizations l10n, {
    required bool isConnecting,
  }) {
    if (isConnecting) {
      return l10n.homeActionCheckingServer;
    }
    return _primaryActionLabel(status, l10n);
  }

  Color _statusColor(BuildContext context, LaunchConnectionStatus status) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    return switch (status) {
      LaunchConnectionStatus.ready => surfaces.success,
      LaunchConnectionStatus.signInRequired => surfaces.warning,
      LaunchConnectionStatus.offline => surfaces.danger,
      LaunchConnectionStatus.incompatible => surfaces.warning,
      LaunchConnectionStatus.unknown => surfaces.accentSoft,
    };
  }

  IconData _statusIcon(LaunchConnectionStatus status) {
    return switch (status) {
      LaunchConnectionStatus.ready => Icons.verified_rounded,
      LaunchConnectionStatus.signInRequired => Icons.lock_outline_rounded,
      LaunchConnectionStatus.offline => Icons.wifi_tethering_error_rounded,
      LaunchConnectionStatus.incompatible => Icons.report_gmailerrorred_rounded,
      LaunchConnectionStatus.unknown => Icons.route_outlined,
    };
  }
}

class _ResumeWorkspacePanel extends StatelessWidget {
  const _ResumeWorkspacePanel({
    required this.title,
    required this.body,
    required this.projectLabel,
    required this.actionLabel,
    required this.busy,
    required this.onPressed,
    this.sessionTitle,
    this.sessionStatus,
  });

  final String title;
  final String body;
  final String projectLabel;
  final String actionLabel;
  final bool busy;
  final VoidCallback onPressed;
  final String? sessionTitle;
  final String? sessionStatus;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final l10n = AppLocalizations.of(context)!;
    final sessionTitle = this.sessionTitle?.trim();
    final sessionStatus = this.sessionStatus?.trim();

    return DecoratedBox(
      key: const Key('resume-workspace-panel'),
      decoration: BoxDecoration(
        color: surfaces.panelMuted.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppSpacing.lg),
        border: Border.all(color: surfaces.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: AppSpacing.xl,
                  height: AppSpacing.xl,
                  decoration: BoxDecoration(
                    color: surfaces.accentSoft.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppSpacing.md),
                  ),
                  child: Icon(
                    Icons.history_toggle_off_rounded,
                    color: surfaces.accentSoft,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        body,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: surfaces.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                _MetricChip(
                  icon: Icons.folder_open_rounded,
                  label: l10n.homeResumeMetricProject,
                  value: projectLabel,
                ),
                if (sessionTitle != null && sessionTitle.isNotEmpty)
                  _MetricChip(
                    icon: Icons.forum_outlined,
                    label: l10n.homeResumeMetricLastSession,
                    value: sessionTitle,
                  ),
                if (sessionStatus != null && sessionStatus.isNotEmpty)
                  _MetricChip(
                    icon: Icons.bolt_rounded,
                    label: l10n.homeResumeMetricStatus,
                    value: sessionStatus,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Semantics(
              container: true,
              label: l10n.homeA11yResumeWorkspaceAction,
              button: true,
              child: ElevatedButton.icon(
                onPressed: busy ? null : onPressed,
                icon: Icon(
                  busy ? Icons.sync_rounded : Icons.play_circle_outline_rounded,
                ),
                label: Text(
                  busy ? l10n.homeActionCheckingWorkspace : actionLabel,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceNoticeBanner extends StatelessWidget {
  const _WorkspaceNoticeBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: surfaces.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.md),
        border: Border.all(color: surfaces.warning.withValues(alpha: 0.28)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(Icons.info_outline_rounded, color: surfaces.warning),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SimpleServerRow extends StatelessWidget {
  const _SimpleServerRow({
    required this.profile,
    required this.selected,
    required this.connecting,
    required this.connectLabel,
    required this.editLabel,
    required this.deleteLabel,
    required this.onSelect,
    required this.onConnect,
    required this.onEdit,
    required this.onDelete,
  });

  final ServerProfile profile;
  final bool selected;
  final bool connecting;
  final String connectLabel;
  final String editLabel;
  final String deleteLabel;
  final VoidCallback onSelect;
  final VoidCallback onConnect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final l10n = AppLocalizations.of(context)!;

    return InkWell(
      borderRadius: BorderRadius.circular(AppSpacing.lg),
      onTap: onSelect,
      child: AnimatedContainer(
        duration: _motionFast,
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primary.withValues(alpha: 0.12)
              : surfaces.panelRaised.withValues(alpha: 0.84),
          borderRadius: BorderRadius.circular(AppSpacing.lg),
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary.withValues(alpha: 0.32)
                : surfaces.line,
          ),
        ),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              profile.effectiveLabel,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              profile.normalizedBaseUrl,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: surfaces.muted,
              ),
            ),
            if (profile.hasBasicAuth) ...<Widget>[
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.homeCredentialsSaved,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: surfaces.accentSoft,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                ElevatedButton.icon(
                  onPressed: connecting ? null : onConnect,
                  icon: connecting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.arrow_forward_rounded),
                  label: Text(connectLabel),
                ),
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(editLabel),
                ),
                OutlinedButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  label: Text(deleteLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.action,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        subtitle,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: surfaces.muted),
                      ),
                    ],
                  ),
                ),
                if (action != null) ...<Widget>[
                  const SizedBox(width: AppSpacing.md),
                  action!,
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          child,
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: color,
              blurRadius: size / 2,
              spreadRadius: size / 6,
            ),
          ],
        ),
        child: SizedBox(width: size, height: size),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : Theme.of(context).extension<AppSurfaces>()!.background;

    return AnimatedContainer(
      duration: _motionFast,
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: AppSpacing.md, color: color),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: surfaces.panelRaised.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
        border: Border.all(color: surfaces.line),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: AppSpacing.md, color: surfaces.accentSoft),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  '$label: $value',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureLine extends StatelessWidget {
  const _FeatureLine({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xxs),
          child: Icon(icon, size: AppSpacing.md, color: surfaces.accentSoft),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: surfaces.muted),
          ),
        ),
      ],
    );
  }
}

class _FeatureBlock extends StatelessWidget {
  const _FeatureBlock({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: surfaces.panelRaised.withValues(alpha: 0.56),
        borderRadius: BorderRadius.circular(AppSpacing.md),
        border: Border.all(color: surfaces.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, color: surfaces.accentSoft, size: AppSpacing.lg),
            const SizedBox(height: AppSpacing.sm),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: surfaces.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyStateBlock extends StatelessWidget {
  const _EmptyStateBlock({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          subtitle,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: surfaces.muted),
        ),
      ],
    );
  }
}

class _ServerStatusBanner extends StatelessWidget {
  const _ServerStatusBanner({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.primaryActionLabel,
    required this.onSecondaryAction,
    this.busy = false,
    this.onPrimaryAction,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String primaryActionLabel;
  final bool busy;
  final VoidCallback? onPrimaryAction;
  final VoidCallback onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final l10n = AppLocalizations.of(context)!;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.lg),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(icon, color: color),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: surfaces.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                ElevatedButton.icon(
                  key: const Key('server-status-primary-action'),
                  onPressed: onPrimaryAction,
                  icon: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                  label: Text(primaryActionLabel),
                ),
                OutlinedButton.icon(
                  key: const Key('server-status-secondary-action'),
                  onPressed: onSecondaryAction,
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(l10n.homeEditServerAction),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ServerCard extends StatelessWidget {
  const _ServerCard({
    required this.label,
    required this.address,
    required this.selected,
    required this.pinned,
    required this.statusLabel,
    required this.statusSummary,
    required this.statusIcon,
    required this.statusColor,
    required this.activityLabel,
    required this.credentialsLabel,
    required this.primaryActionLabel,
    required this.primaryActionBusy,
    required this.onTap,
    required this.onPrimaryAction,
    required this.onEdit,
  });

  final String label;
  final String address;
  final bool selected;
  final bool pinned;
  final String statusLabel;
  final String statusSummary;
  final IconData statusIcon;
  final Color statusColor;
  final String activityLabel;
  final String credentialsLabel;
  final String primaryActionLabel;
  final bool primaryActionBusy;
  final VoidCallback onTap;
  final VoidCallback onPrimaryAction;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final l10n = AppLocalizations.of(context)!;
    return InkWell(
      borderRadius: BorderRadius.circular(AppSpacing.lg),
      onTap: onTap,
      child: AnimatedContainer(
        duration: _motionFast,
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              selected
                  ? theme.colorScheme.primary.withValues(alpha: 0.18)
                  : surfaces.panelRaised.withValues(alpha: 0.9),
              selected
                  ? surfaces.panelRaised.withValues(alpha: 0.98)
                  : surfaces.panel.withValues(alpha: 0.92),
            ],
          ),
          borderRadius: BorderRadius.circular(AppSpacing.lg),
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary.withValues(alpha: 0.38)
                : surfaces.line,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: (selected ? theme.colorScheme.primary : Colors.black)
                  .withValues(alpha: selected ? 0.16 : 0.12),
              blurRadius: selected ? AppSpacing.xxl : AppSpacing.lg,
              offset: const Offset(0, AppSpacing.md),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: AppSpacing.xxl + AppSpacing.xs,
                    height: AppSpacing.xxl + AppSpacing.xs,
                    decoration: BoxDecoration(
                      color: selected
                          ? theme.colorScheme.primary.withValues(alpha: 0.16)
                          : surfaces.panelEmphasis.withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(AppSpacing.md),
                      border: Border.all(
                        color: selected
                            ? theme.colorScheme.primary.withValues(alpha: 0.28)
                            : surfaces.line,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        _monogram(label),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: selected
                              ? theme.colorScheme.primary
                              : surfaces.accentSoft,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(label, style: theme.textTheme.titleMedium),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          address,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: surfaces.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Icon(
                    pinned
                        ? Icons.push_pin_rounded
                        : Icons.radio_button_unchecked,
                    color: pinned ? surfaces.accentSoft : surfaces.line,
                    size: AppSpacing.md,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: <Widget>[
                  _StatusPill(
                    icon: statusIcon,
                    label: statusLabel,
                    color: statusColor,
                  ),
                  if (selected)
                    _ContextChip(
                      icon: Icons.adjust_rounded,
                      label: l10n.homeMetricCurrentFocus,
                      emphasis: true,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                statusSummary,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: surfaces.muted,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: <Widget>[
                  _ContextChip(
                    icon: Icons.history_toggle_off_rounded,
                    label: activityLabel,
                  ),
                  _ContextChip(
                    icon: Icons.key_outlined,
                    label: credentialsLabel,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  ElevatedButton.icon(
                    onPressed: primaryActionBusy ? null : onPrimaryAction,
                    icon: primaryActionBusy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.arrow_forward_rounded),
                    label: Text(primaryActionLabel),
                  ),
                  OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(l10n.homeEditServerAction),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _monogram(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^A-Za-z0-9]+'), ' ').trim();
    if (cleaned.isEmpty) {
      return 'SR';
    }
    final parts = cleaned.split(RegExp(r'\s+'));
    if (parts.length > 1) {
      return '${parts.first.substring(0, 1)}${parts[1].substring(0, 1)}'
          .toUpperCase();
    }
    final compact = parts.first;
    if (compact.length == 1) {
      return compact.toUpperCase();
    }
    return compact.substring(0, 2).toUpperCase();
  }
}

class _ContextChip extends StatelessWidget {
  const _ContextChip({
    required this.icon,
    required this.label,
    this.emphasis = false,
  });

  final IconData icon;
  final String label;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: emphasis
            ? theme.colorScheme.primary.withValues(alpha: 0.12)
            : surfaces.panelMuted.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
        border: Border.all(
          color: emphasis
              ? theme.colorScheme.primary.withValues(alpha: 0.2)
              : surfaces.lineSoft,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpacing.xxl * 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                icon,
                size: AppSpacing.md,
                color: emphasis
                    ? theme.colorScheme.primary
                    : surfaces.accentSoft,
              ),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: emphasis
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentActivityTile extends StatelessWidget {
  const _RecentActivityTile({required this.connection});

  final RecentConnection connection;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final timestamp = DateFormat.yMMMd(
      locale,
    ).add_Hm().format(connection.attemptedAt.toLocal());

    return DecoratedBox(
      decoration: BoxDecoration(
        color: surfaces.panelRaised.withValues(alpha: 0.54),
        borderRadius: BorderRadius.circular(AppSpacing.md),
        border: Border.all(color: surfaces.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
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
                        connection.label,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        connection.baseUrl,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: surfaces.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                _StatusPill(
                  icon: _statusIcon(
                    _statusFromClassification(connection.classification),
                  ),
                  label: _statusLabel(
                    _statusFromClassification(connection.classification),
                    l10n,
                  ),
                  color: _statusColor(
                    context,
                    _statusFromClassification(connection.classification),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              timestamp,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: surfaces.muted),
            ),
          ],
        ),
      ),
    );
  }

  LaunchConnectionStatus _statusFromClassification(
    ConnectionProbeClassification classification,
  ) {
    return switch (classification) {
      ConnectionProbeClassification.ready => LaunchConnectionStatus.ready,
      ConnectionProbeClassification.authFailure =>
        LaunchConnectionStatus.signInRequired,
      ConnectionProbeClassification.connectivityFailure =>
        LaunchConnectionStatus.offline,
      ConnectionProbeClassification.specFetchFailure ||
      ConnectionProbeClassification.unsupportedCapabilities =>
        LaunchConnectionStatus.incompatible,
    };
  }

  Color _statusColor(BuildContext context, LaunchConnectionStatus status) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    return switch (status) {
      LaunchConnectionStatus.ready => surfaces.success,
      LaunchConnectionStatus.signInRequired => surfaces.warning,
      LaunchConnectionStatus.offline => surfaces.danger,
      LaunchConnectionStatus.incompatible => surfaces.warning,
      LaunchConnectionStatus.unknown => surfaces.accentSoft,
    };
  }

  IconData _statusIcon(LaunchConnectionStatus status) {
    return switch (status) {
      LaunchConnectionStatus.ready => Icons.verified_rounded,
      LaunchConnectionStatus.signInRequired => Icons.lock_outline_rounded,
      LaunchConnectionStatus.offline => Icons.wifi_off_rounded,
      LaunchConnectionStatus.incompatible => Icons.report_gmailerrorred_rounded,
      LaunchConnectionStatus.unknown => Icons.schedule_rounded,
    };
  }

  String _statusLabel(LaunchConnectionStatus status, AppLocalizations l10n) {
    return switch (status) {
      LaunchConnectionStatus.ready => l10n.homeStatusShortReady,
      LaunchConnectionStatus.signInRequired =>
        l10n.homeStatusShortSignInRequired,
      LaunchConnectionStatus.offline => l10n.homeStatusShortOffline,
      LaunchConnectionStatus.incompatible => l10n.homeStatusShortNeedsAttention,
      LaunchConnectionStatus.unknown => l10n.homeStatusShortNotCheckedYet,
    };
  }
}
