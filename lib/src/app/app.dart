import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../../l10n/app_localizations.dart';
import '../core/network/live_event_reducer.dart';
import '../core/network/sse_parser.dart';
import '../core/spec/capability_registry.dart';
import '../core/spec/probe_snapshot.dart';
import '../core/spec/raw_json_document.dart';
import '../design_system/app_theme.dart';
import '../i18n/locale_controller.dart';
import 'flavor.dart';

class OpenCodeRemoteApp extends StatefulWidget {
  const OpenCodeRemoteApp({super.key});

  @override
  State<OpenCodeRemoteApp> createState() => _OpenCodeRemoteAppState();
}

class _OpenCodeRemoteAppState extends State<OpenCodeRemoteApp> {
  final LocaleController _localeController = LocaleController();
  late final AppFlavor _flavor = currentFlavor();

  @override
  void dispose() {
    _localeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _localeController,
      builder: (context, child) {
        return MaterialApp(
          title: 'OpenCode Remote',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark(),
          locale: _localeController.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          home: _FoundationDebugScreen(
            flavor: _flavor,
            localeController: _localeController,
          ),
        );
      },
    );
  }
}

class _FoundationDebugScreen extends StatefulWidget {
  const _FoundationDebugScreen({
    required this.flavor,
    required this.localeController,
  });

  final AppFlavor flavor;
  final LocaleController localeController;

  @override
  State<_FoundationDebugScreen> createState() => _FoundationDebugScreenState();
}

class _FoundationDebugScreenState extends State<_FoundationDebugScreen> {
  late final Future<_FoundationDebugData> _data = _loadData();

  Future<_FoundationDebugData> _loadData() async {
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
      _decodeMap(
        await bundle.loadString(
          'assets/fixtures/config/config_with_unknown_fields.json',
        ),
      ),
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

  static Map<String, Object?> _decodeMap(String source) {
    return (jsonDecode(source) as Map).cast<String, Object?>();
  }

  static int _countUnknownFields(Map<String, Object?> json) {
    int total = 0;

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
          child: FutureBuilder<_FoundationDebugData>(
            future: _data,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final data = snapshot.data!;
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.foundationTitle,
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                l10n.foundationSubtitle,
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(color: surfaces.muted),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: widget.localeController.toggle,
                          child: Text(l10n.switchLocale),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        _MetaCard(
                          label: l10n.currentFlavor,
                          value: widget.flavor.label,
                        ),
                        _MetaCard(
                          label: l10n.currentLocale,
                          value: widget.localeController.locale.languageCode,
                        ),
                        _MetaCard(
                          label: l10n.unknownFields,
                          value: '${data.unknownFieldCount}',
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final wide = constraints.maxWidth > 1000;
                          final children = [
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
                          ];
                          if (wide) {
                            return GridView.count(
                              crossAxisCount: 2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 1.35,
                              children: children,
                            );
                          }
                          return ListView.separated(
                            itemBuilder: (context, index) => children[index],
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 16),
                            itemCount: children.length,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
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

class _MetaCard extends StatelessWidget {
  const _MetaCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 12),
              Text(value, style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
        ),
      ),
    );
  }
}

class _CapabilityCard extends StatelessWidget {
  const _CapabilityCard({required this.title, required this.capabilityMap});

  final String title;
  final Map<String, bool> capabilityMap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            for (final entry in capabilityMap.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
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
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            for (final entry in streamFrames.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
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
