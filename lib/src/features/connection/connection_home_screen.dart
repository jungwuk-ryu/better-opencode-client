import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/flavor.dart';
import '../../core/connection/connection_models.dart';
import '../../core/network/live_event_reducer.dart';
import '../../core/network/opencode_server_probe.dart';
import '../../core/network/sse_parser.dart';
import '../../core/persistence/server_profile_store.dart';
import '../../core/spec/capability_registry.dart';
import '../../core/spec/probe_snapshot.dart';
import '../../core/spec/raw_json_document.dart';
import '../../design_system/app_spacing.dart';
import '../../design_system/app_theme.dart';
import '../../i18n/locale_controller.dart';

class ConnectionHomeScreen extends StatefulWidget {
  const ConnectionHomeScreen({
    required this.flavor,
    required this.localeController,
    super.key,
  });

  final AppFlavor flavor;
  final LocaleController localeController;

  @override
  State<ConnectionHomeScreen> createState() => _ConnectionHomeScreenState();
}

class _ConnectionHomeScreenState extends State<ConnectionHomeScreen> {
  final _labelController = TextEditingController();
  final _baseUrlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final ServerProfileStore _profileStore = ServerProfileStore();
  final OpenCodeServerProbe _probe = OpenCodeServerProbe();

  late final Future<_FoundationDebugData> _foundationData =
      _loadFoundationData();

  List<ServerProfile> _profiles = const <ServerProfile>[];
  List<RecentConnection> _recentConnections = const <RecentConnection>[];
  ServerProbeReport? _report;
  String? _selectedProfileId;
  bool _loadingProfiles = true;
  bool _probing = false;

  @override
  void initState() {
    super.initState();
    _loadSavedState();
  }

  @override
  void dispose() {
    _labelController.dispose();
    _baseUrlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _probe.dispose();
    super.dispose();
  }

  Future<void> _loadSavedState() async {
    final profiles = await _profileStore.load();
    final recents = await _profileStore.loadRecentConnections();
    if (!mounted) {
      return;
    }
    setState(() {
      _profiles = profiles;
      _recentConnections = recents;
      _loadingProfiles = false;
    });
    if (profiles.isNotEmpty) {
      _applyProfile(profiles.first);
    }
  }

  ServerProfile _draftProfile() {
    return ServerProfile(
      id:
          _selectedProfileId ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      label: _labelController.text,
      baseUrl: _baseUrlController.text,
      username: _usernameController.text.trim().isEmpty
          ? null
          : _usernameController.text.trim(),
      password: _passwordController.text.isEmpty
          ? null
          : _passwordController.text,
    );
  }

  void _applyProfile(ServerProfile profile) {
    setState(() {
      _selectedProfileId = profile.id;
      _labelController.text = profile.label;
      _baseUrlController.text = profile.baseUrl;
      _usernameController.text = profile.username ?? '';
      _passwordController.text = profile.password ?? '';
    });
  }

  Future<void> _saveProfile() async {
    final profile = _draftProfile();
    final profiles = await _profileStore.upsertProfile(profile);
    if (!mounted) {
      return;
    }
    setState(() {
      _profiles = profiles;
      _selectedProfileId = profile.id;
    });
  }

  Future<void> _deleteSelectedProfile() async {
    final selectedId = _selectedProfileId;
    if (selectedId == null) {
      return;
    }
    final profiles = await _profileStore.deleteProfile(selectedId);
    if (!mounted) {
      return;
    }
    setState(() {
      _profiles = profiles;
      _selectedProfileId = null;
      _labelController.clear();
      _baseUrlController.clear();
      _usernameController.clear();
      _passwordController.clear();
    });
  }

  Future<void> _probeCurrentProfile() async {
    setState(() {
      _probing = true;
    });
    final profile = _draftProfile();
    final report = await _probe.probe(profile);
    final recents = await _profileStore.recordRecentConnection(
      RecentConnection(
        id: profile.id,
        label: profile.effectiveLabel,
        baseUrl: profile.baseUrl,
        username: profile.username,
        attemptedAt: report.checkedAt,
        classification: report.classification,
        summary: report.summary,
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _report = report;
      _recentConnections = recents;
      _probing = false;
    });
  }

  Future<_FoundationDebugData> _loadFoundationData() async {
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

    final streamFrames = {
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
      (jsonDecode(
                await bundle.loadString(
                  'assets/fixtures/config/config_with_unknown_fields.json',
                ),
              )
              as Map)
          .cast<String, Object?>(),
    );
    final merged = config.merge({
      'model': 'openai/gpt-5',
      'provider': {'default': 'openai'},
    });

    return _FoundationDebugData(
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

  static int _countUnknownFields(Map<String, Object?> json) {
    int total = 0;

    void visit(Object? value) {
      if (value is Map<String, Object?>) {
        total += value.keys.where((key) => key.startsWith('x-')).length;
        for (final nested in value.values) {
          visit(nested);
        }
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              surfaces.background,
              surfaces.panel,
              const Color(0xFF0D2137),
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide =
                  constraints.maxWidth >= AppSpacing.wideLayoutBreakpoint;
              final content = [
                _buildHeader(context, l10n),
                const SizedBox(height: AppSpacing.lg),
                if (wide)
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 380,
                          child: _buildControlColumn(context, l10n),
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(child: _buildDiagnosticsColumn(context, l10n)),
                      ],
                    ),
                  )
                else
                  Expanded(
                    child: ListView(
                      children: [
                        _buildControlColumn(context, l10n),
                        const SizedBox(height: AppSpacing.lg),
                        _buildDiagnosticsColumn(context, l10n),
                      ],
                    ),
                  ),
              ];

              return Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: content,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppLocalizations l10n) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.connectionTitle,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.connectionSubtitle,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: surfaces.muted),
              ),
            ],
          ),
        ),
        ElevatedButton(
          onPressed: widget.localeController.toggle,
          child: Text(l10n.switchLocale),
        ),
      ],
    );
  }

  Widget _buildControlColumn(BuildContext context, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildProfileForm(context, l10n),
        const SizedBox(height: AppSpacing.lg),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildProfileList(context, l10n)),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: _buildRecentList(context, l10n)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileForm(BuildContext context, AppLocalizations l10n) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.serverProfileManager,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.connectionProfileHint,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: surfaces.muted),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _labelController,
              decoration: InputDecoration(labelText: l10n.profileLabel),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _baseUrlController,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(labelText: l10n.serverAddress),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(labelText: l10n.username),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(labelText: l10n.password),
            ),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                ElevatedButton(
                  onPressed: _probing ? null : _probeCurrentProfile,
                  child: Text(
                    _probing ? l10n.testingConnection : l10n.testConnection,
                  ),
                ),
                OutlinedButton(
                  onPressed: _saveProfile,
                  child: Text(l10n.saveProfile),
                ),
                OutlinedButton(
                  onPressed: _selectedProfileId == null
                      ? null
                      : _deleteSelectedProfile,
                  child: Text(l10n.deleteProfile),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.connectionGuidance,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: surfaces.muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileList(BuildContext context, AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.savedServers,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: _loadingProfiles
                  ? const Center(child: CircularProgressIndicator())
                  : _profiles.isEmpty
                  ? Center(child: Text(l10n.noSavedServers))
                  : ListView.separated(
                      itemBuilder: (context, index) {
                        final profile = _profiles[index];
                        return ListTile(
                          selected: profile.id == _selectedProfileId,
                          title: Text(profile.effectiveLabel),
                          subtitle: Text(profile.normalizedBaseUrl),
                          onTap: () => _applyProfile(profile),
                        );
                      },
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.xs),
                      itemCount: _profiles.length,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentList(BuildContext context, AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.recentConnections,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: _recentConnections.isEmpty
                  ? Center(child: Text(l10n.noRecentConnections))
                  : ListView.separated(
                      itemBuilder: (context, index) {
                        final connection = _recentConnections[index];
                        return ListTile(
                          title: Text(connection.label),
                          subtitle: Text(connection.summary),
                          trailing: _ClassificationPill(
                            classification: connection.classification,
                          ),
                          onTap: () => _applyProfile(connection.toProfile()),
                        );
                      },
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.xs),
                      itemCount: _recentConnections.length,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiagnosticsColumn(BuildContext context, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildProbeResultCard(context, l10n),
        const SizedBox(height: AppSpacing.lg),
        Expanded(
          child: FutureBuilder<_FoundationDebugData>(
            future: _foundationData,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final data = snapshot.data!;
              return GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: AppSpacing.md,
                mainAxisSpacing: AppSpacing.md,
                childAspectRatio: 1.3,
                children: [
                  _CapabilityCard(
                    title: l10n.fullCapabilityProbe,
                    capabilityMap: data.fullProbe.asMap(),
                  ),
                  _CapabilityCard(
                    title: l10n.legacyCapabilityProbe,
                    capabilityMap: data.legacyProbe.asMap(),
                  ),
                  _CapabilityCard(
                    title: l10n.probeErrorCapability,
                    capabilityMap: data.errorProbe.asMap(),
                  ),
                  _StreamCard(
                    title: l10n.streamFrames,
                    streamFrames: data.streamFrames,
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProbeResultCard(BuildContext context, AppLocalizations l10n) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final report = _report;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.connectionDiagnostics,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                _MetaChip(
                  label: l10n.currentFlavor,
                  value: widget.flavor.label,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              report?.summary ?? l10n.connectionDiagnosticsHint,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: surfaces.muted),
            ),
            const SizedBox(height: AppSpacing.md),
            if (report != null) ...[
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  _ClassificationPill(classification: report.classification),
                  _MetaChip(
                    label: l10n.serverVersion,
                    value: report.snapshot.version,
                  ),
                  _MetaChip(
                    label: l10n.sseStatus,
                    value: report.sseReady
                        ? l10n.readyStatus
                        : l10n.needsAttentionStatus,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: report.capabilityRegistry
                    .asMap()
                    .entries
                    .map((entry) => _BooleanCapabilityChip(entry: entry))
                    .toList(growable: false),
              ),
            ] else ...[
              Text(
                l10n.connectionEmptyState,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FoundationDebugData {
  const _FoundationDebugData({
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

class _CapabilityCard extends StatelessWidget {
  const _CapabilityCard({required this.title, required this.capabilityMap});

  final String title;
  final Map<String, bool> capabilityMap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            for (final entry in capabilityMap.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  children: [
                    Expanded(child: Text(entry.key)),
                    Icon(
                      entry.value ? Icons.check_circle : Icons.remove_circle,
                      color: entry.value
                          ? const Color(0xFF8BE39B)
                          : const Color(0xFFFF9B9B),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StreamCard extends StatelessWidget {
  const _StreamCard({required this.title, required this.streamFrames});

  final String title;
  final Map<String, int> streamFrames;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            for (final entry in streamFrames.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  children: [
                    Expanded(child: Text(entry.key)),
                    Text('${entry.value}'),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text('$label: $value'));
  }
}

class _ClassificationPill extends StatelessWidget {
  const _ClassificationPill({required this.classification});

  final ConnectionProbeClassification classification;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final (label, color) = switch (classification) {
      ConnectionProbeClassification.ready => ('ready', surfaces.success),
      ConnectionProbeClassification.authFailure => ('auth', surfaces.warning),
      ConnectionProbeClassification.specFetchFailure => (
        'spec',
        surfaces.warning,
      ),
      ConnectionProbeClassification.unsupportedCapabilities => (
        'unsupported',
        surfaces.danger,
      ),
      ConnectionProbeClassification.connectivityFailure => (
        'offline',
        surfaces.danger,
      ),
    };
    return Chip(
      backgroundColor: color.withValues(alpha: 0.16),
      side: BorderSide(color: color.withValues(alpha: 0.5)),
      label: Text(label),
    );
  }
}

class _BooleanCapabilityChip extends StatelessWidget {
  const _BooleanCapabilityChip({required this.entry});

  final MapEntry<String, bool> entry;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    return Chip(
      backgroundColor: (entry.value ? surfaces.success : surfaces.danger)
          .withValues(alpha: 0.14),
      side: BorderSide(
        color: (entry.value ? surfaces.success : surfaces.danger).withValues(
          alpha: 0.4,
        ),
      ),
      label: Text(entry.key),
    );
  }
}
