import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../../l10n/app_localizations.dart';
import '../features/web_parity/web_home_screen.dart';
import '../features/web_parity/workspace_screen.dart';
import '../i18n/locale_controller.dart';
import '../i18n/locale_scope.dart';
import 'app_controller.dart';
import 'app_release_notes_dialog.dart';
import 'app_routes.dart';
import 'app_scope.dart';
import 'flavor.dart';

class OpenCodeRemoteApp extends StatefulWidget {
  const OpenCodeRemoteApp({
    this.appController,
    this.localeController,
    this.autoLoadAppController = true,
    super.key,
  });

  final WebParityAppController? appController;
  final LocaleController? localeController;
  final bool autoLoadAppController;

  @override
  State<OpenCodeRemoteApp> createState() => _OpenCodeRemoteAppState();
}

class _OpenCodeRemoteAppState extends State<OpenCodeRemoteApp> {
  late final bool _ownsLocaleController = widget.localeController == null;
  late final LocaleController _localeController =
      widget.localeController ?? LocaleController();
  late final AppFlavor _flavor = currentFlavor();
  late final bool _ownsAppController = widget.appController == null;
  late final WebParityAppController _appController =
      widget.appController ?? WebParityAppController();
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  String? _scheduledReleaseNotesVersion;

  @override
  void initState() {
    super.initState();
    unawaited(_localeController.load());
    if (widget.autoLoadAppController) {
      unawaited(_appController.load());
    }
  }

  @override
  void dispose() {
    if (_ownsAppController) {
      _appController.dispose();
    }
    if (_ownsLocaleController) {
      _localeController.dispose();
    }
    super.dispose();
  }

  void _scheduleReleaseNotesDialog(BuildContext context) {
    final notes = _appController.pendingReleaseNotes;
    if (_appController.loading || notes == null) {
      return;
    }
    if (_scheduledReleaseNotesVersion == notes.currentVersion) {
      return;
    }
    _scheduledReleaseNotesVersion = notes.currentVersion;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final navigator = _navigatorKey.currentState;
      if (!mounted || navigator == null) {
        _scheduledReleaseNotesVersion = null;
        return;
      }
      await _appController.markReleaseNotesSeen(notes.currentVersion);
      if (!mounted || !navigator.mounted) {
        return;
      }
      await navigator.push<void>(
        DialogRoute<void>(
          context: navigator.context,
          builder: (dialogContext) => AppReleaseNotesDialog(notes: notes),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        _localeController,
        _appController,
      ]),
      builder: (context, child) {
        return AppScope(
          controller: _appController,
          child: AppLocaleScope(
            controller: _localeController,
            child: MaterialApp(
              navigatorKey: _navigatorKey,
              onGenerateTitle: (context) =>
                  AppLocalizations.of(context)!.appTitle,
              debugShowCheckedModeBanner: false,
              theme: _appController.lightThemeData,
              darkTheme: _appController.darkThemeData,
              themeMode: _appController.themeMode,
              builder: (context, child) {
                _scheduleReleaseNotesDialog(context);
                final mediaQuery = MediaQuery.maybeOf(context);
                if (mediaQuery == null) {
                  return child ?? const SizedBox.shrink();
                }
                return MediaQuery(
                  data: mediaQuery.copyWith(
                    textScaler: _ScaledTextScaler(
                      base: mediaQuery.textScaler,
                      multiplier: _appController.effectiveTextScaleFactor,
                    ),
                  ),
                  child: child ?? const SizedBox.shrink(),
                );
              },
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
          ),
        );
      },
    );
  }
}

class _ScaledTextScaler extends TextScaler {
  const _ScaledTextScaler({required this.base, required this.multiplier})
    : assert(multiplier > 0);

  final TextScaler base;
  final double multiplier;

  @override
  double scale(double fontSize) => base.scale(fontSize) * multiplier;

  @override
  double get textScaleFactor => scale(1);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is _ScaledTextScaler &&
        other.base == base &&
        other.multiplier == multiplier;
  }

  @override
  int get hashCode => Object.hash(base, multiplier);
}
