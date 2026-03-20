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

  testWidgets('first run shows branded home scaffold without probe jargon', (
    tester,
  ) async {
    final localeController = LocaleController();
    addTearDown(localeController.dispose);

    await tester.pumpWidget(
      _TestApp(
        child: WorkspaceHomeScreen(
          flavor: AppFlavor.debug,
          localeController: localeController,
          snapshot: const WorkspaceHomeSnapshot(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Workspace'), findsOneWidget);
    expect(find.text('OpenCode Remote'), findsOneWidget);
    expect(find.text('Add server'), findsWidgets);
    expect(find.text('Saved servers'), findsOneWidget);
    expect(find.text('Recent activity'), findsOneWidget);
    expect(find.text('Projects and sessions'), findsOneWidget);
    expect(find.text('Start with a server, not a probe'), findsNothing);
    expect(
      find.text('Leave endpoint diagnostics tucked inside server details.'),
      findsNothing,
    );
    expect(find.text('Probe server'), findsNothing);
    expect(find.text('Live capability probe'), findsNothing);
  });

  testWidgets('saved ready server shows workspace section seam', (
    tester,
  ) async {
    final localeController = LocaleController();
    addTearDown(localeController.dispose);

    const profile = ServerProfile(
      id: 'alpha',
      label: 'Studio',
      baseUrl: 'https://studio.example.com',
    );
    final report = _readyReport();

    await tester.pumpWidget(
      _TestApp(
        child: WorkspaceHomeScreen(
          flavor: AppFlavor.debug,
          localeController: localeController,
          snapshot: WorkspaceHomeSnapshot(
            savedProfiles: const <ServerProfile>[profile],
            recentConnections: <RecentConnection>[
              RecentConnection(
                id: 'alpha',
                label: 'Studio',
                baseUrl: 'https://studio.example.com',
                attemptedAt: DateTime(2026, 3, 19, 9, 0),
                classification: ConnectionProbeClassification.ready,
                summary: 'Ready',
              ),
            ],
            cachedReports: <String, ServerProbeReport>{
              profile.storageKey: report,
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

    expect(find.text('Studio'), findsWidgets);
    expect(find.byKey(const Key('workspace-section-seam')), findsOneWidget);
    expect(find.text('Ready for projects'), findsWidgets);
    expect(find.text('Start with a server, not a probe'), findsNothing);
    expect(
      find.text('Leave endpoint diagnostics tucked inside server details.'),
      findsNothing,
    );
    expect(find.text('Probe server'), findsNothing);
    expect(find.text('Live capability probe'), findsNothing);
  });

  testWidgets(
    'unsupported server can still open the workspace chooser surface',
    (tester) async {
      final localeController = LocaleController();
      addTearDown(localeController.dispose);

      const profile = ServerProfile(
        id: 'alpha',
        label: 'Studio',
        baseUrl: 'https://studio.example.com',
      );
      final report = ServerProbeReport(
        snapshot: ProbeSnapshot(
          name: 'Studio Server',
          version: '1.2.27',
          paths: const <String>{
            '/global/health',
            '/config',
            '/config/providers',
            '/provider',
            '/agent',
            '/project',
            '/project/current',
            '/session',
            '/session/status',
            '/path',
            '/vcs',
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
        ),
        capabilityRegistry: CapabilityRegistry.fromSnapshot(
          ProbeSnapshot(
            name: 'Studio Server',
            version: '1.2.27',
            paths: const <String>{
              '/global/health',
              '/config',
              '/config/providers',
              '/provider',
              '/agent',
              '/project',
              '/project/current',
              '/session',
              '/session/status',
              '/path',
              '/vcs',
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
          ),
        ),
        classification: ConnectionProbeClassification.unsupportedCapabilities,
        summary: 'Needs attention',
        checkedAt: DateTime(2026, 3, 19, 9, 0),
        missingCapabilities: const <String>[],
        discoveredExperimentalPaths: const <String>[],
        sseReady: false,
      );

      await tester.pumpWidget(
        _TestApp(
          child: WorkspaceHomeScreen(
            flavor: AppFlavor.debug,
            localeController: localeController,
            snapshot: WorkspaceHomeSnapshot(
              savedProfiles: const <ServerProfile>[profile],
              cachedReports: <String, ServerProbeReport>{
                profile.storageKey: report,
              },
              selectedProfile: profile,
            ),
            workspaceSectionBuilder: (context, selectedProfile, onOpenProject) {
              return const Placeholder(
                key: Key('workspace-section-seam-unsupported'),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('workspace-section-seam-unsupported')),
        findsOneWidget,
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

ServerProbeReport _readyReport() {
  final snapshot = ProbeSnapshot(
    name: 'Studio Server',
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
    classification: ConnectionProbeClassification.ready,
    summary: 'Ready',
    checkedAt: DateTime(2026, 3, 19, 9, 0),
    missingCapabilities: const <String>[],
    discoveredExperimentalPaths: const <String>[],
    sseReady: true,
  );
}
