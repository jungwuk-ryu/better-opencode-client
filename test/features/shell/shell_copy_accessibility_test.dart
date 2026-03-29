import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:better_opencode_client/l10n/app_localizations.dart';
import 'package:better_opencode_client/src/core/connection/connection_models.dart';
import 'package:better_opencode_client/src/core/spec/capability_registry.dart';
import 'package:better_opencode_client/src/core/spec/probe_snapshot.dart';
import 'package:better_opencode_client/src/design_system/app_theme.dart';
import 'package:better_opencode_client/src/features/projects/project_models.dart';
import 'package:better_opencode_client/src/features/shell/opencode_shell_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('shell exposes stable semantics labels for key controls', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const profile = ServerProfile(
      id: 'server-1',
      label: 'Mock server',
      baseUrl: 'http://127.0.0.1:8787',
    );
    const project = ProjectTarget(
      directory: '/workspace/demo',
      label: 'Demo',
      source: 'server',
      vcs: 'git',
      branch: 'main',
    );
    final capabilities = CapabilityRegistry.fromSnapshot(
      ProbeSnapshot(
        name: 'minimal',
        version: '1.0.0',
        paths: const <String>{'/project', '/project/current'},
        endpoints: const <String, ProbeEndpointResult>{},
      ),
    );

    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: OpenCodeShellScreen(
            profile: profile,
            project: project,
            capabilities: capabilities,
            onExit: _noop,
          ),
        ),
      );

      await tester.pump();
      for (var index = 0; index < 5; index += 1) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      expect(find.bySemanticsLabel('Back to servers'), findsWidgets);
      expect(find.bySemanticsLabel('Message field'), findsOneWidget);
      expect(find.bySemanticsLabel('Send message'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });
}

void _noop() {}
