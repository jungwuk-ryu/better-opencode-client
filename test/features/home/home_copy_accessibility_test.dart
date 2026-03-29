import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:better_opencode_client/l10n/app_localizations.dart';
import 'package:better_opencode_client/src/app/flavor.dart';
import 'package:better_opencode_client/src/core/connection/connection_models.dart';
import 'package:better_opencode_client/src/design_system/app_theme.dart';
import 'package:better_opencode_client/src/features/home/workspace_home_screen.dart';
import 'package:better_opencode_client/src/i18n/locale_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('home copy uses release labels and stable semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    final localeController = LocaleController();
    addTearDown(localeController.dispose);

    try {
      await tester.pumpWidget(
        _TestApp(
          child: WorkspaceHomeScreen(
            flavor: AppFlavor.debug,
            localeController: localeController,
            snapshot: const WorkspaceHomeSnapshot(
              savedProfiles: <ServerProfile>[
                ServerProfile(
                  id: 'server-1',
                  label: 'Studio',
                  baseUrl: 'https://studio.example.com',
                ),
              ],
              selectedProfile: ServerProfile(
                id: 'server-1',
                label: 'Studio',
                baseUrl: 'https://studio.example.com',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Workspace'), findsOneWidget);
      expect(find.text('better-opencode-client (BOC)'), findsOneWidget);
      expect(find.text('Add server'), findsWidgets);
      expect(
        find.bySemanticsLabel(RegExp(r'Workspace primary action')),
        findsOneWidget,
      );
    } finally {
      semantics.dispose();
    }
  });
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
