import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile_remote/l10n/app_localizations.dart';
import 'package:opencode_mobile_remote/src/app/flavor.dart';
import 'package:opencode_mobile_remote/src/core/connection/connection_models.dart';
import 'package:opencode_mobile_remote/src/core/network/opencode_server_probe.dart';
import 'package:opencode_mobile_remote/src/core/spec/capability_registry.dart';
import 'package:opencode_mobile_remote/src/core/spec/probe_snapshot.dart';
import 'package:opencode_mobile_remote/src/design_system/app_theme.dart';
import 'package:opencode_mobile_remote/src/features/home/workspace_home_screen.dart';
import 'package:opencode_mobile_remote/src/i18n/locale_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('auth failure stays inside the simple connect pane', (
    tester,
  ) async {
    final localeController = LocaleController();
    addTearDown(localeController.dispose);

    const profile = ServerProfile(
      id: 'auth',
      label: 'Auth Gate',
      baseUrl: 'https://auth.example.com',
    );

    await tester.pumpWidget(
      _TestApp(
        child: WorkspaceHomeScreen(
          flavor: AppFlavor.release,
          localeController: localeController,
          snapshot: WorkspaceHomeSnapshot(
            savedProfiles: const <ServerProfile>[profile],
            cachedReports: <String, ServerProbeReport>{
              profile.storageKey: _report(
                ConnectionProbeClassification.authFailure,
                summary: '401 token expired while probing /provider/auth',
                missingCapabilities: const <String>['/provider/auth'],
                authScheme: 'Basic',
              ),
            },
            selectedProfile: profile,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('server-status-banner')), findsNothing);
    expect(find.text('Connect'), findsWidgets);
    expect(
      find.text('401 token expired while probing /provider/auth'),
      findsNothing,
    );
    expect(find.text('/provider/auth'), findsNothing);
  });

  testWidgets(
    'offline state keeps the simple connect panel without probe detail',
    (tester) async {
      final localeController = LocaleController();
      addTearDown(localeController.dispose);

      const profile = ServerProfile(
        id: 'offline',
        label: 'Offline Edge',
        baseUrl: 'https://offline.example.com',
      );

      await tester.pumpWidget(
        _TestApp(
          child: WorkspaceHomeScreen(
            flavor: AppFlavor.release,
            localeController: localeController,
            snapshot: WorkspaceHomeSnapshot(
              savedProfiles: const <ServerProfile>[profile],
              cachedReports: <String, ServerProbeReport>{
                profile.storageKey: _report(
                  ConnectionProbeClassification.connectivityFailure,
                  summary: 'Timed out while contacting /global/health.',
                ),
              },
              selectedProfile: profile,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('server-status-banner')), findsNothing);
      expect(find.text('Connect'), findsWidgets);
      expect(
        find.text('Timed out while contacting /global/health.'),
        findsNothing,
      );
      expect(find.text('/global/health'), findsNothing);
    },
  );

  testWidgets(
    'incompatible state hides capability paths behind the simple project entry flow',
    (tester) async {
      final localeController = LocaleController();
      addTearDown(localeController.dispose);

      const profile = ServerProfile(
        id: 'legacy',
        label: 'Legacy Edge',
        baseUrl: 'https://legacy.example.com',
      );

      await tester.pumpWidget(
        _TestApp(
          child: WorkspaceHomeScreen(
            flavor: AppFlavor.release,
            localeController: localeController,
            snapshot: WorkspaceHomeSnapshot(
              savedProfiles: const <ServerProfile>[profile],
              cachedReports: <String, ServerProbeReport>{
                profile.storageKey: _report(
                  ConnectionProbeClassification.unsupportedCapabilities,
                  summary: 'Missing capability paths and experimental routes',
                  missingCapabilities: const <String>['/provider/auth'],
                  experimentalPaths: const <String>['/experimental/tool/ids'],
                ),
              },
              selectedProfile: profile,
            ),
            workspaceSectionBuilder: (context, selectedProfile, onOpenProject) {
              return const Placeholder(key: Key('workspace-section-seam'));
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('server-status-banner')), findsNothing);
      expect(find.byKey(const Key('workspace-section-seam')), findsOneWidget);
      expect(find.text('/provider/auth'), findsNothing);
      expect(find.text('/experimental/tool/ids'), findsNothing);
      expect(
        find.text('Missing capability paths and experimental routes'),
        findsNothing,
      );
    },
  );
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
  required String summary,
  List<String> missingCapabilities = const <String>[],
  List<String> experimentalPaths = const <String>[],
  String? authScheme,
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
    discoveredExperimentalPaths: experimentalPaths,
    sseReady: classification == ConnectionProbeClassification.ready,
    authScheme: authScheme,
  );
}
