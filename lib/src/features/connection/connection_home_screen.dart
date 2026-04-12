import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/flavor.dart';
import '../../core/connection/connection_models.dart';
import '../../core/network/live_event_reducer.dart';
import '../../core/network/opencode_server_probe.dart';
import '../../core/network/sse_parser.dart';
import '../../core/persistence/server_profile_store.dart';
import '../../core/persistence/stale_cache_store.dart';
import '../../core/spec/capability_registry.dart';
import '../../core/spec/probe_snapshot.dart';
import '../../core/spec/raw_json_document.dart';
import '../../design_system/app_modal.dart';
import '../../design_system/app_spacing.dart';
import '../../design_system/app_theme.dart';
import '../../i18n/locale_controller.dart';
import '../settings/cache_settings_sheet.dart';

const _contentMaxWidth = 1480.0;
const _sideColumnWidth = 420.0;
const _motionFast = Duration(milliseconds: 220);
const _motionMedium = Duration(milliseconds: 320);
const _probeEndpointOrder = <String>[
  '/global/health',
  '/doc',
  '/config',
  '/config/providers',
  '/provider',
  '/provider/auth',
  '/agent',
  '/experimental/tool/ids',
];

Widget _fadeSlideTransition(
  Widget child,
  Animation<double> animation, {
  Offset begin = const Offset(0, 0.04),
}) {
  final curved = CurvedAnimation(
    parent: animation,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  return FadeTransition(
    opacity: curved,
    child: SlideTransition(
      position: Tween<Offset>(begin: begin, end: Offset.zero).animate(curved),
      child: child,
    ),
  );
}

class ConnectionHomeScreen extends StatefulWidget {
  const ConnectionHomeScreen({
    required this.flavor,
    required this.localeController,
    this.initialProfile,
    this.startInAddMode = false,
    super.key,
  });

  final AppFlavor flavor;
  final LocaleController localeController;
  final ServerProfile? initialProfile;
  final bool startInAddMode;

  @override
  State<ConnectionHomeScreen> createState() => _ConnectionHomeScreenState();
}

class _ConnectionHomeScreenState extends State<ConnectionHomeScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ServerProfileStore _profileStore = ServerProfileStore();
  final StaleCacheStore _cacheStore = StaleCacheStore();
  final OpenCodeServerProbe _probeService = OpenCodeServerProbe();
  final TextEditingController _labelController = TextEditingController();
  final TextEditingController _baseUrlController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  late final Future<_FixtureDebugData> _fixtureData = _loadFixtureData();

  List<ServerProfile> _savedProfiles = const <ServerProfile>[];
  List<RecentConnection> _recentConnections = const <RecentConnection>[];
  Set<String> _pinnedProfileKeys = const <String>{};
  ServerProbeReport? _latestProbe;
  String? _activeProfileId;
  bool _isSaving = false;
  bool _isProbing = false;
  bool _showPassword = false;
  bool _restoredDraft = false;
  String _probeSignature = 'probe-empty';

  @override
  void initState() {
    super.initState();
    for (final controller in <TextEditingController>[
      _labelController,
      _baseUrlController,
      _usernameController,
      _passwordController,
    ]) {
      controller.addListener(_persistDraft);
    }
    _loadStoredConnections();
  }

  @override
  void dispose() {
    _labelController.dispose();
    _baseUrlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _probeService.dispose();
    super.dispose();
  }

  Future<void> _loadStoredConnections() async {
    final profiles = await _profileStore.load();
    final recents = await _profileStore.loadRecentConnections();
    final pinned = await _profileStore.loadPinnedProfiles();
    final draft = await _profileStore.loadDraftProfile();
    final hasDraft = draft != null && _hasMeaningfulProfileData(draft);
    if (!mounted) {
      return;
    }
    setState(() {
      _savedProfiles = profiles;
      _recentConnections = recents;
      _pinnedProfileKeys = pinned;
      _restoredDraft = widget.initialProfile == null && hasDraft;
    });
    final explicitProfile = widget.initialProfile;
    if (explicitProfile != null) {
      ServerProfile? matchedProfile;
      for (final profile in profiles) {
        if (profile.id == explicitProfile.id ||
            profile.storageKey == explicitProfile.storageKey) {
          matchedProfile = profile;
          break;
        }
      }
      _applyProfile(
        matchedProfile ?? explicitProfile,
        preferSavedSelection: true,
      );
      return;
    }
    if (hasDraft) {
      _applyProfile(draft, preferSavedSelection: true);
      return;
    }
    if (widget.startInAddMode) {
      return;
    }
    if (profiles.isNotEmpty) {
      _applyProfile(profiles.first, preferSavedSelection: true);
    }
  }

  void _applyProfile(
    ServerProfile profile, {
    required bool preferSavedSelection,
  }) {
    _labelController.text = profile.label;
    _baseUrlController.text = profile.normalizedBaseUrl;
    _usernameController.text = profile.username ?? '';
    _passwordController.text = profile.password ?? '';
    final matchedSavedProfile = _matchSavedProfile(profile);
    setState(() {
      _activeProfileId = preferSavedSelection ? matchedSavedProfile?.id : null;
    });
    unawaited(_loadCachedProbe(profile));
  }

  String _probeCacheKey(ServerProfile profile) =>
      'probe::${profile.storageKey}';

  Future<void> _loadCachedProbe(ServerProfile profile) async {
    final entry = await _cacheStore.load(_probeCacheKey(profile));
    if (entry == null || !mounted) {
      return;
    }
    ServerProbeReport report;
    try {
      report = ServerProbeReport.fromJson(
        (jsonDecode(entry.payloadJson) as Map).cast<String, Object?>(),
      );
    } catch (_) {
      await _cacheStore.remove(_probeCacheKey(profile));
      return;
    }
    setState(() {
      _latestProbe = report;
      _probeSignature = entry.signature;
    });
    final ttl = await _cacheStore.loadTtl();
    if (!entry.isFresh(ttl, DateTime.now())) {
      unawaited(_runProbe(useLoadingState: false));
    }
  }

  ServerProfile? _matchSavedProfile(ServerProfile profile) {
    for (final savedProfile in _savedProfiles) {
      if (savedProfile.id == profile.id ||
          savedProfile.storageKey == profile.storageKey) {
        return savedProfile;
      }
    }
    return null;
  }

  ServerProfile _currentDraftProfile() {
    final candidate = ServerProfile(
      id: _activeProfileId ?? _newProfileId(),
      label: _labelController.text.trim(),
      baseUrl: _baseUrlController.text.trim(),
      username: _normalizedOptional(_usernameController.text),
      password: _normalizedOptional(_passwordController.text),
    );
    final matchedSavedProfile = _matchSavedProfile(candidate);
    if (matchedSavedProfile == null) {
      return candidate;
    }
    return candidate.copyWith(id: matchedSavedProfile.id);
  }

  String _newProfileId() => DateTime.now().microsecondsSinceEpoch.toString();

  bool _hasMeaningfulProfileData(ServerProfile profile) {
    return profile.label.trim().isNotEmpty ||
        profile.baseUrl.trim().isNotEmpty ||
        (profile.username?.trim().isNotEmpty ?? false) ||
        (profile.password?.isNotEmpty ?? false);
  }

  Future<void> _persistDraft() async {
    final draft = _currentDraftProfile();
    if (!_hasMeaningfulProfileData(draft)) {
      await _profileStore.clearDraftProfile();
      if (mounted && _restoredDraft) {
        setState(() {
          _restoredDraft = false;
        });
      }
      return;
    }
    await _profileStore.saveDraftProfile(draft);
  }

  String? _normalizedOptional(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final draft = _currentDraftProfile();
    setState(() {
      _isSaving = true;
    });
    final savedProfiles = await _profileStore.upsertProfile(draft);
    if (!mounted) {
      return;
    }
    setState(() {
      _savedProfiles = savedProfiles;
      _activeProfileId = draft.id;
      _isSaving = false;
    });
  }

  Future<void> _deleteProfile(ServerProfile profile) async {
    final savedProfiles = await _profileStore.deleteProfile(profile.id);
    final pinned = await _profileStore.loadPinnedProfiles();
    if (!mounted) {
      return;
    }
    setState(() {
      _savedProfiles = savedProfiles;
      _pinnedProfileKeys = pinned;
      if (_activeProfileId == profile.id) {
        _activeProfileId = null;
      }
    });
  }

  Future<void> _togglePinnedProfile(ServerProfile profile) async {
    final pinned = await _profileStore.togglePinnedProfile(profile.storageKey);
    if (!mounted) {
      return;
    }
    setState(() {
      _pinnedProfileKeys = pinned;
    });
  }

  Future<void> _runProbe({bool useLoadingState = true}) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    final draft = _currentDraftProfile();
    setState(() {
      if (useLoadingState) {
        _isProbing = true;
      }
    });
    final report = await _probeService.probe(draft);
    await _cacheStore.save(_probeCacheKey(draft), report.toJson());
    final recents = await _profileStore.recordRecentConnection(
      RecentConnection(
        id: draft.id,
        label: draft.effectiveLabel,
        baseUrl: draft.normalizedBaseUrl,
        username: draft.username,
        attemptedAt: report.checkedAt,
        classification: report.classification,
        summary: report.summary,
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _latestProbe = report;
      _recentConnections = recents;
      _probeSignature = jsonEncode(report.toJson());
      _isProbing = false;
    });
  }

  Future<void> _openCacheSettings() async {
    await showAppModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => CacheSettingsSheet(
        onChanged: () {
          final draft = _currentDraftProfile();
          if (_hasMeaningfulProfileData(draft)) {
            unawaited(_loadCachedProbe(draft));
          }
        },
      ),
    );
  }

  String? _validateAddress(String? value) {
    final draft = ServerProfile(id: 'draft', label: '', baseUrl: value ?? '');
    final uri = draft.uriOrNull;
    if (uri == null || uri.host.isEmpty) {
      return AppLocalizations.of(context)!.connectionAddressValidation;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
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
                ).colorScheme.primary.withValues(alpha: 0.18),
                size: 300,
              ),
            ),
            Positioned(
              right: -120,
              top: 120,
              child: _GlowOrb(
                color: surfaces.accentSoft.withValues(alpha: 0.12),
                size: 260,
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: const <Color>[
                        Color(0x11000000),
                        Color(0x00000000),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: _contentMaxWidth,
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide =
                            constraints.maxWidth >=
                            AppSpacing.wideLayoutBreakpoint;
                        final primary = _buildPrimaryColumn(context);
                        final side = _buildSideColumn(context);
                        if (isWide) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Expanded(child: primary),
                              const SizedBox(width: AppSpacing.md),
                              SizedBox(width: _sideColumnWidth, child: side),
                            ],
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            primary,
                            const SizedBox(height: AppSpacing.md),
                            side,
                          ],
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

  Widget _buildPrimaryColumn(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _buildHeader(context),
        const SizedBox(height: AppSpacing.md),
        _buildHeroCard(context),
        const SizedBox(height: AppSpacing.md),
        _buildProbeResultCard(context),
      ],
    );
  }

  Widget _buildSideColumn(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _buildSavedProfilesCard(context),
        const SizedBox(height: AppSpacing.md),
        _buildRecentConnectionsCard(context),
        if (widget.flavor.enablesFixtureTools) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          FutureBuilder<_FixtureDebugData>(
            future: _fixtureData,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return _PanelShell(
                  title: AppLocalizations.of(context)!.fixtureDiagnosticsTitle,
                  subtitle: AppLocalizations.of(
                    context,
                  )!.fixtureDiagnosticsSubtitle,
                  child: const Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                );
              }
              return _FixtureDiagnosticsCard(data: snapshot.data!);
            },
          ),
        ],
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          l10n.connectionHeaderEyebrow,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          l10n.connectionHeaderTitle,
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.connectionHeaderSubtitle,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: surfaces.muted),
        ),
      ],
    );
    final actions = Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      alignment: WrapAlignment.end,
      children: <Widget>[
        if (Navigator.canPop(context))
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.home_outlined),
            label: Text(l10n.connectionBackHomeAction),
          ),
        _TagChip(
          icon: Icons.tune,
          label: '${l10n.currentFlavor}: ${widget.flavor.label}',
        ),
        _TagChip(
          icon: Icons.language,
          label:
              '${l10n.currentLocale}: ${widget.localeController.locale.languageCode}',
        ),
        OutlinedButton.icon(
          onPressed: _openCacheSettings,
          icon: const Icon(Icons.cleaning_services_outlined),
          label: Text(l10n.cacheSettingsAction),
        ),
        OutlinedButton.icon(
          onPressed: widget.localeController.toggle,
          icon: const Icon(Icons.translate),
          label: Text(l10n.switchLocale),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 1120) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              copy,
              const SizedBox(height: AppSpacing.md),
              actions,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: copy),
            const SizedBox(width: AppSpacing.md),
            Flexible(child: actions),
          ],
        );
      },
    );
  }

  Widget _buildHeroCard(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final l10n = AppLocalizations.of(context)!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                theme.colorScheme.primary.withValues(alpha: 0.18),
                surfaces.panelRaised.withValues(alpha: 0.92),
                surfaces.panel.withValues(alpha: 0.96),
              ],
            ),
            border: Border.all(color: surfaces.line),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 780;
                final intro = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _StatusBadge(
                      icon: _latestProbe == null
                          ? Icons.route_outlined
                          : _classificationIcon(_latestProbe!.classification),
                      label: _latestProbe == null
                          ? l10n.connectionStatusAwaiting
                          : _classificationLabel(
                              l10n,
                              _latestProbe!.classification,
                            ),
                      color: _latestProbe == null
                          ? surfaces.accentSoft
                          : _classificationColor(
                              surfaces,
                              _latestProbe!.classification,
                            ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      l10n.connectionFormTitle,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      l10n.connectionFormSubtitle,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: surfaces.muted,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: <Widget>[
                        _TagChip(
                          icon: Icons.storage_rounded,
                          label:
                              '${_savedProfiles.length} ${l10n.savedProfilesCountLabel}',
                        ),
                        _TagChip(
                          icon: Icons.history_toggle_off,
                          label:
                              '${_recentConnections.length} ${l10n.recentConnectionsCountLabel}',
                        ),
                        _TagChip(
                          icon: Icons.stream,
                          label: _latestProbe?.sseReady == true
                              ? l10n.sseReadyLabel
                              : l10n.ssePendingLabel,
                        ),
                      ],
                    ),
                  ],
                );
                final form = _buildConnectionForm(context);
                if (stacked) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      intro,
                      const SizedBox(height: AppSpacing.md),
                      form,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(child: intro),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: form),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionForm(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (_restoredDraft) ...<Widget>[
            _TagChip(
              icon: Icons.restore_rounded,
              label: l10n.connectionDraftRestoredLabel,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          TextFormField(
            controller: _labelController,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: l10n.connectionProfileLabel,
              hintText: l10n.connectionProfileLabelHint,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _baseUrlController,
            textInputAction: TextInputAction.next,
            keyboardType: TextInputType.url,
            autofillHints: const <String>[AutofillHints.url],
            decoration: InputDecoration(
              labelText: l10n.connectionAddressLabel,
              hintText: l10n.connectionAddressHint,
            ),
            validator: _validateAddress,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _usernameController,
            textInputAction: TextInputAction.next,
            autofillHints: const <String>[AutofillHints.username],
            decoration: InputDecoration(
              labelText: l10n.connectionUsernameLabel,
              hintText: l10n.connectionUsernameHint,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _passwordController,
            textInputAction: TextInputAction.done,
            obscureText: !_showPassword,
            autofillHints: const <String>[AutofillHints.password],
            decoration: InputDecoration(
              labelText: l10n.connectionPasswordLabel,
              hintText: l10n.connectionPasswordHint,
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
            onFieldSubmitted: (_) {
              _runProbe();
            },
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              ElevatedButton.icon(
                onPressed: _isProbing ? null : _runProbe,
                icon: _isProbing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.podcasts),
                label: Text(l10n.connectionProbeAction),
              ),
              OutlinedButton.icon(
                onPressed: _isSaving ? null : _saveProfile,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.bookmark_add_outlined),
                label: Text(l10n.connectionSaveAction),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProbeResultCard(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final l10n = AppLocalizations.of(context)!;

    return _PanelShell(
      title: l10n.connectionProbeResultTitle,
      subtitle: l10n.connectionProbeResultSubtitle,
      child: AnimatedSwitcher(
        duration: _motionMedium,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) =>
            _fadeSlideTransition(child, animation),
        child: _latestProbe == null
            ? Padding(
                key: const ValueKey<String>('empty-probe'),
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l10n.connectionProbeEmptyTitle,
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      l10n.connectionProbeEmptySubtitle,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: surfaces.muted,
                      ),
                    ),
                  ],
                ),
              )
            : Padding(
                key: ValueKey<String>(_probeSignature),
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
                              _StatusBadge(
                                icon: _classificationIcon(
                                  _latestProbe!.classification,
                                ),
                                label: _classificationLabel(
                                  l10n,
                                  _latestProbe!.classification,
                                ),
                                color: _classificationColor(
                                  surfaces,
                                  _latestProbe!.classification,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                _latestProbe!.snapshot.name,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                _classificationDetail(l10n, _latestProbe!),
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: surfaces.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        _MetricBlock(
                          label: l10n.connectionVersionLabel,
                          value: _latestProbe!.snapshot.version,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.md,
                      children: <Widget>[
                        _MetricBlock(
                          label: l10n.connectionCheckedAtLabel,
                          value: _formatTimestamp(
                            context,
                            _latestProbe!.checkedAt,
                          ),
                        ),
                        _MetricBlock(
                          label: l10n.connectionCapabilitiesLabel,
                          value:
                              '${_enabledCapabilities(_latestProbe!.capabilityRegistry)}',
                        ),
                        _MetricBlock(
                          label: l10n.connectionReadinessLabel,
                          value: _latestProbe!.sseReady
                              ? l10n.sseReadyLabel
                              : l10n.ssePendingLabel,
                        ),
                      ],
                    ),
                    if (_latestProbe!
                        .missingCapabilities
                        .isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        l10n.connectionMissingCapabilitiesLabel,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: _latestProbe!.missingCapabilities
                            .map(
                              (path) => _TagChip(
                                icon: Icons.warning_amber_rounded,
                                label: path,
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ],
                    if (_latestProbe!
                        .discoveredExperimentalPaths
                        .isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        l10n.connectionExperimentalPathsLabel,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: _latestProbe!.discoveredExperimentalPaths
                            .map(
                              (path) => _TagChip(
                                icon: Icons.construction_outlined,
                                label: path,
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    _SectionTitle(label: l10n.connectionEndpointSectionTitle),
                    const SizedBox(height: AppSpacing.sm),
                    Column(
                      children: _probeEndpointOrder
                          .where(
                            (path) => _latestProbe!.snapshot.endpoints
                                .containsKey(path),
                          )
                          .map(
                            (path) => Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.sm,
                              ),
                              child: _EndpointRow(
                                path: path,
                                result: _latestProbe!.snapshot.endpoints[path]!,
                                statusLabel: _endpointStatusLabel(
                                  l10n,
                                  _latestProbe!
                                      .snapshot
                                      .endpoints[path]!
                                      .status,
                                ),
                              ),
                            ),
                          )
                          .toList(growable: false),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _SectionTitle(label: l10n.connectionCapabilitySectionTitle),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: _latestProbe!.capabilityRegistry
                          .asMap()
                          .entries
                          .map(
                            (entry) => _CapabilityChip(
                              label: _capabilityLabel(l10n, entry.key),
                              enabled: entry.value,
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSavedProfilesCard(BuildContext context) {
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

    return _PanelShell(
      title: l10n.savedProfilesTitle,
      subtitle: l10n.savedProfilesSubtitle,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: _savedProfiles.isEmpty
            ? _EmptyPanelState(
                title: l10n.savedProfilesEmptyTitle,
                subtitle: l10n.savedProfilesEmptySubtitle,
              )
            : Column(
                children: sortedProfiles
                    .map(
                      (profile) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _ProfileTile(
                          label: profile.effectiveLabel,
                          subtitle: profile.normalizedBaseUrl,
                          isSelected: profile.id == _activeProfileId,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              IconButton(
                                tooltip:
                                    _pinnedProfileKeys.contains(
                                      profile.storageKey,
                                    )
                                    ? l10n.connectionUnpinProfileAction
                                    : l10n.connectionPinProfileAction,
                                onPressed: () => _togglePinnedProfile(profile),
                                icon: Icon(
                                  _pinnedProfileKeys.contains(
                                        profile.storageKey,
                                      )
                                      ? Icons.push_pin_rounded
                                      : Icons.push_pin_outlined,
                                ),
                              ),
                              IconButton(
                                onPressed: () => _deleteProfile(profile),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                          onTap: () => _applyProfile(
                            profile,
                            preferSavedSelection: true,
                          ),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
      ),
    );
  }

  Widget _buildRecentConnectionsCard(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;

    return _PanelShell(
      title: l10n.recentConnectionsTitle,
      subtitle: l10n.recentConnectionsSubtitle,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: _recentConnections.isEmpty
            ? _EmptyPanelState(
                title: l10n.recentConnectionsEmptyTitle,
                subtitle: l10n.recentConnectionsEmptySubtitle,
              )
            : Column(
                children: _recentConnections
                    .map(
                      (connection) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _RecentConnectionTile(
                          connection: connection,
                          statusLabel: _classificationLabel(
                            l10n,
                            connection.classification,
                          ),
                          statusColor: _classificationColor(
                            surfaces,
                            connection.classification,
                          ),
                          timestamp: _formatTimestamp(
                            context,
                            connection.attemptedAt,
                          ),
                          onTap: () => _applyProfile(
                            connection.toProfile(),
                            preferSavedSelection: false,
                          ),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
      ),
    );
  }

  String _classificationLabel(
    AppLocalizations l10n,
    ConnectionProbeClassification classification,
  ) {
    return switch (classification) {
      ConnectionProbeClassification.ready => l10n.connectionOutcomeReady,
      ConnectionProbeClassification.authFailure =>
        l10n.connectionOutcomeAuthFailure,
      ConnectionProbeClassification.specFetchFailure =>
        l10n.connectionOutcomeSpecFailure,
      ConnectionProbeClassification.unsupportedCapabilities =>
        l10n.connectionOutcomeUnsupported,
      ConnectionProbeClassification.connectivityFailure =>
        l10n.connectionOutcomeConnectivityFailure,
    };
  }

  String _classificationDetail(
    AppLocalizations l10n,
    ServerProbeReport report,
  ) {
    if (report.classification == ConnectionProbeClassification.authFailure &&
        report.requiresBasicAuth) {
      return l10n.connectionDetailBasicAuthFailure;
    }
    return switch (report.classification) {
      ConnectionProbeClassification.ready => l10n.connectionDetailReady,
      ConnectionProbeClassification.authFailure =>
        l10n.connectionDetailAuthFailure,
      ConnectionProbeClassification.specFetchFailure =>
        l10n.connectionDetailSpecFailure,
      ConnectionProbeClassification.unsupportedCapabilities =>
        l10n.connectionDetailUnsupported,
      ConnectionProbeClassification.connectivityFailure =>
        l10n.connectionDetailConnectivityFailure,
    };
  }

  Color _classificationColor(
    AppSurfaces surfaces,
    ConnectionProbeClassification classification,
  ) {
    return switch (classification) {
      ConnectionProbeClassification.ready => surfaces.success,
      ConnectionProbeClassification.authFailure => surfaces.warning,
      ConnectionProbeClassification.specFetchFailure => surfaces.danger,
      ConnectionProbeClassification.unsupportedCapabilities => surfaces.warning,
      ConnectionProbeClassification.connectivityFailure => surfaces.danger,
    };
  }

  IconData _classificationIcon(ConnectionProbeClassification classification) {
    return switch (classification) {
      ConnectionProbeClassification.ready => Icons.verified,
      ConnectionProbeClassification.authFailure => Icons.lock_outline,
      ConnectionProbeClassification.specFetchFailure =>
        Icons.description_outlined,
      ConnectionProbeClassification.unsupportedCapabilities =>
        Icons.report_gmailerrorred,
      ConnectionProbeClassification.connectivityFailure =>
        Icons.wifi_tethering_error_rounded,
    };
  }

  String _endpointStatusLabel(AppLocalizations l10n, ProbeStatus status) {
    return switch (status) {
      ProbeStatus.success => l10n.endpointReadyStatus,
      ProbeStatus.unauthorized => l10n.endpointAuthStatus,
      ProbeStatus.unsupported => l10n.endpointUnsupportedStatus,
      ProbeStatus.failure => l10n.endpointFailureStatus,
      ProbeStatus.unknown => l10n.endpointUnknownStatus,
    };
  }

  String _capabilityLabel(AppLocalizations l10n, String key) {
    return switch (key) {
      'canShareSession' => l10n.capabilityCanShareSession,
      'canForkSession' => l10n.capabilityCanForkSession,
      'canSummarizeSession' => l10n.capabilityCanSummarizeSession,
      'canRevertSession' => l10n.capabilityCanRevertSession,
      'hasQuestions' => l10n.capabilityHasQuestions,
      'hasPermissions' => l10n.capabilityHasPermissions,
      'hasExperimentalTools' => l10n.capabilityHasExperimentalTools,
      'hasProviderOAuth' => l10n.capabilityHasProviderOAuth,
      'hasMcpAuth' => l10n.capabilityHasMcpAuth,
      'hasTuiControl' => l10n.capabilityHasTuiControl,
      _ => key,
    };
  }

  int _enabledCapabilities(CapabilityRegistry registry) {
    return registry.asMap().values.where((enabled) => enabled).length;
  }

  String _formatTimestamp(BuildContext context, DateTime value) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    return DateFormat.yMMMd(locale).add_Hm().format(value.toLocal());
  }

  static Future<_FixtureDebugData> _loadFixtureData() async {
    final bundle = rootBundle;
    final fullProbe = ProbeSnapshot.fromJsonString(
      await bundle.loadString(
        'assets/fixtures/probes/full_capability_snapshot.json',
      ),
    );
    final legacyProbe = ProbeSnapshot.fromJsonString(
      await bundle.loadString(
        'assets/fixtures/probes/legacy_server_snapshot.json',
      ),
    );
    final errorProbe = ProbeSnapshot.fromJsonString(
      await bundle.loadString(
        'assets/fixtures/probes/probe_error_snapshot.json',
      ),
    );

    final streamFrames = <String, int>{
      'healthy': await _frameCount(
        bundle,
        'assets/fixtures/events/healthy_stream.txt',
      ),
      'stale': await _frameCount(
        bundle,
        'assets/fixtures/events/missed_heartbeat_stream.txt',
      ),
      'duplicate': await _frameCount(
        bundle,
        'assets/fixtures/events/duplicate_delivery_stream.txt',
      ),
      'resync': await _frameCount(
        bundle,
        'assets/fixtures/events/resync_required_stream.txt',
      ),
    };

    final config = RawJsonDocument(
      _decodeMap(
        await bundle.loadString(
          'assets/fixtures/config/config_with_unknown_fields.json',
        ),
      ),
    );
    final merged = config.merge(<String, Object?>{
      'model': 'openai/gpt-5',
      'provider': <String, Object?>{'default': 'openai'},
    });

    return _FixtureDebugData(
      fullProbe: CapabilityRegistry.fromSnapshot(fullProbe),
      legacyProbe: CapabilityRegistry.fromSnapshot(legacyProbe),
      errorProbe: CapabilityRegistry.fromSnapshot(errorProbe),
      streamFrames: streamFrames,
      unknownFieldCount: _countUnknownFields(merged.toJson()),
    );
  }

  static Future<int> _frameCount(AssetBundle bundle, String path) async {
    final source = await bundle.loadString(path);
    final frames = await const SseParser()
        .bind(Stream<List<int>>.value(utf8.encode(source)))
        .toList();
    final reducer = LiveEventReducer();
    for (final frame in frames) {
      reducer.apply(frame.event ?? 'message', frame.data);
    }
    return frames.length + reducer.state.connectionCount;
  }

  static Map<String, Object?> _decodeMap(String source) {
    return (jsonDecode(source) as Map).cast<String, Object?>();
  }

  static int _countUnknownFields(Map<String, Object?> json) {
    var total = 0;

    void visit(Object? value) {
      if (value is Map<String, Object?>) {
        total += value.keys.where((key) => key.startsWith('x-')).length;
        for (final nested in value.values) {
          visit(nested);
        }
        return;
      }
      if (value is List<Object?>) {
        for (final nested in value) {
          visit(nested);
        }
      }
    }

    visit(json);
    return total;
  }
}

class _PanelShell extends StatelessWidget {
  const _PanelShell({
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
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: Theme.of(context).textTheme.titleLarge),
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    return AnimatedContainer(
      duration: _motionFast,
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: AnimatedSwitcher(
          duration: _motionFast,
          transitionBuilder: (child, animation) =>
              _fadeSlideTransition(child, animation),
          child: Row(
            key: ValueKey<String>(
              '${icon.codePoint}-$label-${color.toARGB32()}',
            ),
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 16, color: color),
              const SizedBox(width: AppSpacing.xs),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: surfaces.onColor(color),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 16, color: surfaces.accentSoft),
            const SizedBox(width: AppSpacing.xs),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _MetricBlock extends StatelessWidget {
  const _MetricBlock({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: surfaces.panelRaised.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppSpacing.md),
        border: Border.all(color: surfaces.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: surfaces.muted),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(value, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}

class _EndpointRow extends StatelessWidget {
  const _EndpointRow({
    required this.path,
    required this.result,
    required this.statusLabel,
  });

  final String path;
  final ProbeEndpointResult result;
  final String statusLabel;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final statusColor = switch (result.status) {
      ProbeStatus.success => surfaces.success,
      ProbeStatus.unauthorized => surfaces.warning,
      ProbeStatus.unsupported => surfaces.warning,
      ProbeStatus.failure => surfaces.danger,
      ProbeStatus.unknown => surfaces.accentSoft,
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: surfaces.panelRaised.withValues(alpha: 0.56),
        borderRadius: BorderRadius.circular(AppSpacing.md),
        border: Border.all(color: surfaces.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(path, style: Theme.of(context).textTheme.titleSmall),
                  if (result.statusCode != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'HTTP ${result.statusCode}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: surfaces.muted),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            _StatusBadge(
              icon: Icons.circle,
              label: statusLabel,
              color: statusColor,
            ),
          ],
        ),
      ),
    );
  }
}

class _CapabilityChip extends StatelessWidget {
  const _CapabilityChip({required this.label, required this.enabled});

  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final color = enabled ? surfaces.success : surfaces.danger;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              enabled ? Icons.check_circle : Icons.remove_circle,
              size: 16,
              color: color,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _EmptyPanelState extends StatelessWidget {
  const _EmptyPanelState({required this.title, required this.subtitle});

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

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.label,
    required this.subtitle,
    required this.isSelected,
    required this.trailing,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final bool isSelected;
  final Widget trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    return InkWell(
      borderRadius: BorderRadius.circular(AppSpacing.md),
      onTap: onTap,
      child: AnimatedContainer(
        duration: _motionFast,
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12)
              : surfaces.panelRaised.withValues(alpha: 0.54),
          borderRadius: BorderRadius.circular(AppSpacing.md),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.42)
                : surfaces.line,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(label, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      subtitle,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: surfaces.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentConnectionTile extends StatelessWidget {
  const _RecentConnectionTile({
    required this.connection,
    required this.statusLabel,
    required this.statusColor,
    required this.timestamp,
    required this.onTap,
  });

  final RecentConnection connection;
  final String statusLabel;
  final Color statusColor;
  final String timestamp;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    return InkWell(
      borderRadius: BorderRadius.circular(AppSpacing.md),
      onTap: onTap,
      child: AnimatedContainer(
        duration: _motionFast,
        curve: Curves.easeOutCubic,
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
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: surfaces.muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _StatusBadge(
                    icon: Icons.history,
                    label: statusLabel,
                    color: statusColor,
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
      ),
    );
  }
}

class _FixtureDiagnosticsCard extends StatelessWidget {
  const _FixtureDiagnosticsCard({required this.data});

  final _FixtureDebugData data;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _PanelShell(
      title: l10n.fixtureDiagnosticsTitle,
      subtitle: l10n.fixtureDiagnosticsSubtitle,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                _MetricBlock(
                  label: l10n.unknownFields,
                  value: '${data.unknownFieldCount}',
                ),
                _MetricBlock(
                  label: l10n.streamFrames,
                  value:
                      '${data.streamFrames.values.fold<int>(0, (total, value) => total + value)}',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _FixtureCapabilityCard(
              title: l10n.fullCapabilityProbe,
              capabilities: data.fullProbe,
            ),
            const SizedBox(height: AppSpacing.md),
            _FixtureCapabilityCard(
              title: l10n.legacyCapabilityProbe,
              capabilities: data.legacyProbe,
            ),
            const SizedBox(height: AppSpacing.md),
            _FixtureCapabilityCard(
              title: l10n.probeErrorCapability,
              capabilities: data.errorProbe,
            ),
            const SizedBox(height: AppSpacing.md),
            _FixtureStreamsCard(streamFrames: data.streamFrames),
          ],
        ),
      ),
    );
  }
}

class _FixtureCapabilityCard extends StatelessWidget {
  const _FixtureCapabilityCard({
    required this.title,
    required this.capabilities,
  });

  final String title;
  final CapabilityRegistry capabilities;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.md),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: capabilities
                  .asMap()
                  .entries
                  .map(
                    (entry) =>
                        _CapabilityChip(label: entry.key, enabled: entry.value),
                  )
                  .toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }
}

class _FixtureStreamsCard extends StatelessWidget {
  const _FixtureStreamsCard({required this.streamFrames});

  final Map<String, int> streamFrames;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.md),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              AppLocalizations.of(context)!.streamFrames,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final entry in streamFrames.entries) ...<Widget>[
              Row(
                children: <Widget>[
                  Expanded(child: Text(entry.key)),
                  Text(
                    '${entry.value}',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: surfaces.accentSoft,
                    ),
                  ),
                ],
              ),
              if (entry.key != streamFrames.keys.last)
                const SizedBox(height: AppSpacing.xs),
            ],
          ],
        ),
      ),
    );
  }
}

class _FixtureDebugData {
  const _FixtureDebugData({
    required this.fullProbe,
    required this.legacyProbe,
    required this.errorProbe,
    required this.streamFrames,
    required this.unknownFieldCount,
  });

  final CapabilityRegistry fullProbe;
  final CapabilityRegistry legacyProbe;
  final CapabilityRegistry errorProbe;
  final Map<String, int> streamFrames;
  final int unknownFieldCount;
}

extension on AppSurfaces {
  Color onColor(Color color) {
    final brightness = ThemeData.estimateBrightnessForColor(color);
    return brightness == Brightness.dark ? Colors.white : background;
  }
}
