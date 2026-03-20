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
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('saved server cards show identity, context, and clear actions', (
    tester,
  ) async {
    _setLargeSurface(tester);
    final localeController = LocaleController();
    addTearDown(localeController.dispose);

    const profile = ServerProfile(
      id: 'studio',
      label: 'Studio North',
      baseUrl: 'https://studio.example.com',
      username: 'operator',
      password: 'secret',
    );

    await tester.pumpWidget(
      _TestApp(
        child: WorkspaceHomeScreen(
          flavor: AppFlavor.release,
          localeController: localeController,
          snapshot: WorkspaceHomeSnapshot(
            savedProfiles: const <ServerProfile>[profile],
            recentConnections: <RecentConnection>[
              RecentConnection(
                id: 'studio',
                label: 'Studio North',
                baseUrl: 'https://studio.example.com',
                username: 'operator',
                attemptedAt: DateTime(2026, 3, 19, 9, 0),
                classification: ConnectionProbeClassification.ready,
                summary: 'Ready',
              ),
            ],
            pinnedProfileKeys: <String>{profile.storageKey},
            cachedReports: <String, ServerProbeReport>{
              profile.storageKey: _report(
                classification: ConnectionProbeClassification.ready,
                summary: 'Ready',
              ),
            },
            selectedProfile: profile,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Studio North'), findsWidgets);
    expect(find.text('https://studio.example.com'), findsWidgets);
    expect(find.text('Ready for projects'), findsWidgets);
    expect(find.text('Credentials saved'), findsOneWidget);
    expect(find.textContaining('Last used'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('Edit server'), findsOneWidget);
    expect(find.text('Current server'), findsOneWidget);
  });

  testWidgets('saved server cards hide probe jargon and raw probe detail', (
    tester,
  ) async {
    _setLargeSurface(tester);
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
            recentConnections: <RecentConnection>[
              RecentConnection(
                id: 'legacy',
                label: 'Legacy Edge',
                baseUrl: 'https://legacy.example.com',
                attemptedAt: DateTime(2026, 3, 19, 10, 30),
                classification:
                    ConnectionProbeClassification.unsupportedCapabilities,
                summary: '401 token expired while probing /provider/auth',
              ),
            ],
            cachedReports: <String, ServerProbeReport>{
              profile.storageKey: _report(
                classification:
                    ConnectionProbeClassification.unsupportedCapabilities,
                summary: 'Missing capability paths and experimental routes',
                missingCapabilities: const <String>['/provider/auth'],
                experimentalPaths: const <String>['/experimental/tool/ids'],
              ),
            },
            selectedProfile: profile,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Needs attention'), findsWidgets);
    expect(find.text('Start with a server, not a probe'), findsNothing);
    expect(
      find.text('Leave endpoint diagnostics tucked inside server details.'),
      findsNothing,
    );
    expect(
      find.text('401 token expired while probing /provider/auth'),
      findsNothing,
    );
    expect(find.text('/provider/auth'), findsNothing);
    expect(find.text('/experimental/tool/ids'), findsNothing);
    expect(find.textContaining('Capabilities'), findsNothing);
    expect(find.textContaining('endpoint diagnostics'), findsNothing);
  });

  testWidgets(
    'unsupported saved server still offers continue when the user wants to proceed',
    (tester) async {
      _setLargeSurface(tester);
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
                  classification:
                      ConnectionProbeClassification.unsupportedCapabilities,
                  summary: 'Needs attention',
                ),
              },
              selectedProfile: profile,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Continue'), findsOneWidget);
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

ServerProbeReport _report({
  required ConnectionProbeClassification classification,
  required String summary,
  List<String> missingCapabilities = const <String>[],
  List<String> experimentalPaths = const <String>[],
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
    checkedAt: DateTime(2026, 3, 19, 9, 0),
    missingCapabilities: missingCapabilities,
    discoveredExperimentalPaths: experimentalPaths,
    sseReady: classification == ConnectionProbeClassification.ready,
  );
}

void _setLargeSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 2200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
