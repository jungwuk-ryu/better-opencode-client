import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../../l10n/app_localizations.dart';
import '../design_system/app_theme.dart';
import '../features/web_parity/web_home_screen.dart';
import '../features/web_parity/workspace_screen.dart';
import '../i18n/locale_controller.dart';
import 'app_controller.dart';
import 'app_routes.dart';
import 'app_scope.dart';
import 'flavor.dart';

class OpenCodeRemoteApp extends StatefulWidget {
  const OpenCodeRemoteApp({super.key});

  @override
  State<OpenCodeRemoteApp> createState() => _OpenCodeRemoteAppState();
}

class _OpenCodeRemoteAppState extends State<OpenCodeRemoteApp> {
  final LocaleController _localeController = LocaleController();
  late final AppFlavor _flavor = currentFlavor();
  late final WebParityAppController _appController = WebParityAppController()
    ..load();

  @override
  void dispose() {
    _appController.dispose();
    _localeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _localeController,
      builder: (context, child) {
        return AppScope(
          controller: _appController,
          child: MaterialApp(
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
            initialRoute: '/',
            onGenerateRoute: (settings) {
              final route = AppRouteData.parse(settings.name);
              return MaterialPageRoute<void>(
                settings: RouteSettings(
                  name: settings.name ?? '/',
                  arguments: settings.arguments,
                ),
                builder: (context) {
                  return switch (route) {
                    HomeRouteData() => WebParityHomeScreen(
                      flavor: _flavor,
                      localeController: _localeController,
                    ),
                    WorkspaceRouteData(:final directory, :final sessionId) =>
                      WebParityWorkspaceScreen(
                        key: ValueKey<String>('workspace-$directory'),
                        directory: directory,
                        sessionId: sessionId,
                      ),
                  };
                },
              );
            },
          ),
        );
      },
    );
  }
}
