import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:better_opencode_client/l10n/app_localizations.dart';
import 'package:better_opencode_client/src/app/flavor.dart';
import 'package:better_opencode_client/src/core/connection/connection_models.dart';
import 'package:better_opencode_client/src/core/network/opencode_server_probe.dart';
import 'package:better_opencode_client/src/core/persistence/server_profile_store.dart';
import 'package:better_opencode_client/src/core/persistence/stale_cache_store.dart';
import 'package:better_opencode_client/src/core/spec/capability_registry.dart';
import 'package:better_opencode_client/src/core/spec/probe_snapshot.dart';
import 'package:better_opencode_client/src/design_system/app_theme.dart';
import 'package:better_opencode_client/src/features/connection/connection_home_screen.dart';
import 'package:better_opencode_client/src/features/home/workspace_home_screen.dart';
import 'package:better_opencode_client/src/i18n/locale_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('continue runs in background and unlocks workspace from home', (
    tester,
  ) async {
    _setLargeSurface(tester);
    final localeController = LocaleController();
    addTearDown(localeController.dispose);

    const profile = ServerProfile(
      id: 'studio',
      label: 'Studio',
      baseUrl: 'https://studio.example.com',
      username: 'operator',
      password: 'secret',
    );
    final completer = Completer<ServerProbeReport>();
    final probe = _FakeProbe((_) => completer.future);

    await tester.pumpWidget(
      _TestApp(
        child: WorkspaceHomeScreen(
          flavor: AppFlavor.release,
          localeController: localeController,
          probeService: probe,
          snapshot: const WorkspaceHomeSnapshot(
            savedProfiles: <ServerProfile>[profile],
            selectedProfile: profile,
          ),
          workspaceSectionBuilder: (context, selectedProfile, onOpenProject) {
            return const Placeholder(key: Key('workspace-section'));
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('home-workspace-connect-button')),
    );
    await tester.pump();

    expect(find.text('Studio'), findsWidgets);
    expect(find.text('Checking server...'), findsWidgets);
    expect(find.byType(ConnectionHomeScreen), findsNothing);
    expect(find.text('Live capability probe'), findsNothing);

    completer.complete(_report(ConnectionProbeClassification.ready));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('workspace-section')), findsOneWidget);
    expect(probe.calls, hasLength(1));

    final cacheEntry = await StaleCacheStore().load(
      'probe::${profile.storageKey}',
    );
    expect(cacheEntry, isNotNull);
    final cachedReport = ServerProbeReport.fromJson(
      (jsonDecode(cacheEntry!.payloadJson) as Map).cast<String, Object?>(),
    );
    expect(cachedReport.classification, ConnectionProbeClassification.ready);

    final recentConnections = await ServerProfileStore()
        .loadRecentConnections();
    expect(recentConnections, hasLength(1));
    expect(recentConnections.first.storageKey, profile.storageKey);
    expect(
      recentConnections.first.classification,
      ConnectionProbeClassification.ready,
    );
  });

  testWidgets('retry keeps auth failures on home without legacy probe UI', (
    tester,
  ) async {
    _setLargeSurface(tester);
    final localeController = LocaleController();
    addTearDown(localeController.dispose);

    const profile = ServerProfile(
      id: 'auth',
      label: 'Auth Gate',
      baseUrl: 'https://auth.example.com',
    );
    final probe = _FakeProbe(
      (_) async => _report(
        ConnectionProbeClassification.authFailure,
        summary: '401 token expired while probing /provider/auth',
        missingCapabilities: const <String>['/provider/auth'],
      ),
    );

    await tester.pumpWidget(
      _TestApp(
        child: WorkspaceHomeScreen(
          flavor: AppFlavor.release,
          localeController: localeController,
          probeService: probe,
          snapshot: const WorkspaceHomeSnapshot(
            savedProfiles: <ServerProfile>[profile],
            selectedProfile: profile,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('home-workspace-connect-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sign-in required'), findsWidgets);
    expect(
      find.byKey(const ValueKey<String>('home-workspace-connect-button')),
      findsOneWidget,
    );
    expect(find.byType(ConnectionHomeScreen), findsNothing);
    expect(find.text('Live capability probe'), findsNothing);
    expect(
      find.text('401 token expired while probing /provider/auth'),
      findsNothing,
    );
    expect(find.text('/provider/auth'), findsNothing);

    final recentConnections = await ServerProfileStore()
        .loadRecentConnections();
    expect(recentConnections, hasLength(1));
    expect(
      recentConnections.first.classification,
      ConnectionProbeClassification.authFailure,
    );
  });

  testWidgets(
    'spec fetch failures keep the user on home and show spec verification copy',
    (tester) async {
      _setLargeSurface(tester);
      final localeController = LocaleController();
      addTearDown(localeController.dispose);

      const profile = ServerProfile(
        id: 'static-site',
        label: 'Static Site',
        baseUrl: 'https://example.com',
      );
      final probe = _FakeProbe(
        (_) async => _report(ConnectionProbeClassification.specFetchFailure),
      );

      await tester.pumpWidget(
        _TestApp(
          child: WorkspaceHomeScreen(
            flavor: AppFlavor.release,
            localeController: localeController,
            probeService: probe,
            snapshot: const WorkspaceHomeSnapshot(
              savedProfiles: <ServerProfile>[profile],
              selectedProfile: profile,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('home-workspace-connect-button')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('workspace-notice-banner')),
        findsOneWidget,
      );
      expect(
        find.text(
          'The server is reachable, but the OpenAPI spec could not be fetched or parsed cleanly.',
        ),
        findsWidgets,
      );
      expect(
        find.textContaining("Couldn't connect to Static Site"),
        findsNothing,
      );
      expect(find.byType(ConnectionHomeScreen), findsNothing);
      expect(find.text('Live capability probe'), findsNothing);
    },
  );
}

class _FakeProbe implements OpenCodeServerProbe {
  _FakeProbe(this._onProbe);

  final Future<ServerProbeReport> Function(ServerProfile profile) _onProbe;
  final List<ServerProfile> calls = <ServerProfile>[];

  @override
  void dispose() {}

  @override
  Future<ServerProbeReport> probe(ServerProfile profile) {
    calls.add(profile);
    return _onProbe(profile);
  }
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.dark(),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      home: child,
    );
  }
}

ServerProbeReport _report(
  ConnectionProbeClassification classification, {
  String summary = 'Ready',
  List<String> missingCapabilities = const <String>[],
}) {
  final snapshot = ProbeSnapshot(
    name: 'Test Server',
    version: '0.1.0',
    paths: const <String>{
      '/global/health',
      '/doc',
      '/config',
      '/config/providers',
      '/provider',
      '/agent',
    },
    endpoints: const <String, ProbeEndpointResult>{
      '/global/health': ProbeEndpointResult(
        path: '/global/health',
        status: ProbeStatus.success,
        statusCode: 200,
      ),
      '/doc': ProbeEndpointResult(
        path: '/doc',
        status: ProbeStatus.success,
        statusCode: 200,
      ),
    },
  );

  return ServerProbeReport(
    snapshot: snapshot,
    capabilityRegistry: CapabilityRegistry.fromSnapshot(snapshot),
    classification: classification,
    summary: summary,
    checkedAt: DateTime(2026, 3, 19, 12, 0),
    missingCapabilities: missingCapabilities,
    discoveredExperimentalPaths: const <String>[],
    sseReady: classification == ConnectionProbeClassification.ready,
  );
}

void _setLargeSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 2200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
