import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../../l10n/app_localizations.dart';
import '../design_system/app_theme.dart';
import '../features/connection/connection_home_screen.dart';
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
          home: ConnectionHomeScreen(
            flavor: _flavor,
            localeController: _localeController,
          ),
        );
      },
    );
  }
}
