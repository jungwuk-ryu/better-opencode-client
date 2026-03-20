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

  testWidgets('add server opens a blank editor flow from home', (tester) async {
    _setLargeSurface(tester);
    final localeController = LocaleController();
    addTearDown(localeController.dispose);

    const existingProfile = ServerProfile(
      id: 'existing',
      label: 'Existing Server',
      baseUrl: 'https://existing.example.com',
      username: 'saved-user',
      password: 'saved-pass',
    );

    await tester.pumpWidget(
      _TestApp(
        child: WorkspaceHomeScreen(
          flavor: AppFlavor.release,
          localeController: localeController,
          snapshot: WorkspaceHomeSnapshot(
            savedProfiles: const <ServerProfile>[existingProfile],
            cachedReports: <String, ServerProbeReport>{
              existingProfile.storageKey: _readyReport(),
            },
            selectedProfile: existingProfile,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add server').first);
    await tester.pumpAndSettle();

    final fields = tester
        .widgetList<TextFormField>(find.byType(TextFormField))
        .toList();
    expect(fields, hasLength(4));
    expect(fields[0].controller?.text, isEmpty);
    expect(fields[1].controller?.text, isEmpty);
    expect(fields[2].controller?.text, isEmpty);
    expect(fields[3].controller?.text, isEmpty);
    expect(find.text('Existing Server'), findsNothing);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('edit server opens a prefilled editor flow from home', (
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

    await tester.pumpWidget(
      _TestApp(
        child: WorkspaceHomeScreen(
          flavor: AppFlavor.release,
          localeController: localeController,
          snapshot: WorkspaceHomeSnapshot(
            savedProfiles: const <ServerProfile>[profile],
            cachedReports: <String, ServerProbeReport>{
              profile.storageKey: _readyReport(),
            },
            selectedProfile: profile,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Edit server'));
    await tester.pumpAndSettle();

    final fields = tester
        .widgetList<TextFormField>(find.byType(TextFormField))
        .toList();
    expect(fields, hasLength(4));
    expect(fields[0].controller?.text, 'Studio');
    expect(fields[1].controller?.text, 'https://studio.example.com');
    expect(fields[2].controller?.text, 'operator');
    expect(fields[3].controller?.text, 'secret');
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('add server offers a button to return home', (tester) async {
    _setLargeSurface(tester);
    final localeController = LocaleController();
    addTearDown(localeController.dispose);

    await tester.pumpWidget(
      _TestApp(
        child: WorkspaceHomeScreen(
          flavor: AppFlavor.release,
          localeController: localeController,
          snapshot: const WorkspaceHomeSnapshot(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add server').first);
    await tester.pumpAndSettle();

    expect(find.text('Back to home'), findsOneWidget);

    await tester.tap(find.text('Back to home'));
    await tester.pumpAndSettle();

    expect(find.text('Workspace'), findsOneWidget);
    expect(find.text('OpenCode Remote'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });
}

void _setLargeSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 2200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
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
