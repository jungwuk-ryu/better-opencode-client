import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../../l10n/app_localizations.dart';
import '../features/web_parity/web_home_screen.dart';
import '../features/web_parity/workspace_screen.dart';
import '../i18n/locale_controller.dart';
import '../i18n/locale_scope.dart';
import '../design_system/app_modal.dart';
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
  late final NavigatorObserver _launchLocationObserver =
      _LaunchLocationObserver(_appController);
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  String? _scheduledReleaseNotesVersion;
  String _initialRoute = '/';
  String? _pendingAppLinkRoute;
  late bool _startupComplete = !widget.autoLoadAppController;
  StreamSubscription<Uri>? _appLinksSubscription;

  @override
  void initState() {
    super.initState();
    unawaited(_localeController.load());
    if (widget.autoLoadAppController) {
      unawaited(_loadAppControllerForStartup());
    } else {
      _initialRoute = _appController.resolvedLaunchLocation;
    }
    _configureAppLinks();
  }

  @override
  void dispose() {
    _appLinksSubscription?.cancel();
    if (_ownsAppController) {
      _appController.dispose();
    }
    if (_ownsLocaleController) {
      _localeController.dispose();
    }
    super.dispose();
  }

  Future<void> _loadAppControllerForStartup() async {
    await _appController.load();
    if (!mounted) {
      return;
    }
    setState(() {
      _initialRoute = _appController.resolvedLaunchLocation;
      _startupComplete = true;
    });
    _schedulePendingAppLinkRoute();
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
      await showAppDialog<void>(
        context: navigator.context,
        useRootNavigator: true,
        builder: (dialogContext) => AppReleaseNotesDialog(notes: notes),
      );
    });
  }

  void _configureAppLinks() {
    if (kIsWeb) {
      return;
    }
    try {
      final appLinks = AppLinks();
      unawaited(_consumeInitialAppLink(appLinks));
      _appLinksSubscription = appLinks.uriLinkStream.listen(
        _handleIncomingAppLink,
      );
    } catch (_) {
      _appLinksSubscription = null;
    }
  }

  Future<void> _consumeInitialAppLink(AppLinks appLinks) async {
    try {
      final uri = await appLinks.getInitialLink();
      if (uri != null) {
        _handleIncomingAppLink(uri);
      }
    } catch (_) {}
  }

  void _handleIncomingAppLink(Uri uri) {
    final route = _routeLocationForUri(uri);
    final navigator = _navigatorKey.currentState;
    if (!mounted || route == null) {
      return;
    }
    if (!_startupComplete || navigator == null) {
      _pendingAppLinkRoute = route;
      return;
    }
    navigator.pushNamedAndRemoveUntil(route, (route) => false);
  }

  void _schedulePendingAppLinkRoute() {
    final route = _pendingAppLinkRoute;
    if (route == null) {
      return;
    }
    _pendingAppLinkRoute = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigator = _navigatorKey.currentState;
      if (!mounted || navigator == null) {
        _pendingAppLinkRoute = route;
        return;
      }
      navigator.pushNamedAndRemoveUntil(route, (route) => false);
    });
  }

  String? _routeLocationForUri(Uri uri) {
    final parsed = AppRouteData.parse(uri.toString());
    return switch (parsed) {
      HomeRouteData(:final connectionImport) when connectionImport != null =>
        connectionImport.location ?? '/',
      HomeRouteData() => '/',
      WorkspaceRouteData(:final location) => location,
    };
  }

  Route<void> _buildAppRoute(RouteSettings settings) {
    final route = AppRouteData.parse(settings.name);
    return MaterialPageRoute<void>(
      settings: RouteSettings(
        name: settings.name ?? '/',
        arguments: settings.arguments,
      ),
      builder: (context) {
        return switch (route) {
          HomeRouteData(:final connectionImport) => WebParityHomeScreen(
            flavor: _flavor,
            localeController: _localeController,
            connectionImport: connectionImport,
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
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        _localeController,
        _appController,
      ]),
      builder: (context, child) {
        if (!_startupComplete) {
          return const SizedBox.shrink();
        }
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
                return _AppKeyboardDismissOnTap(
                  child: MediaQuery(
                    data: mediaQuery.copyWith(
                      textScaler: _ScaledTextScaler(
                        base: mediaQuery.textScaler,
                        multiplier: _appController.effectiveTextScaleFactor,
                      ),
                    ),
                    child: child ?? const SizedBox.shrink(),
                  ),
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
              navigatorObservers: <NavigatorObserver>[_launchLocationObserver],
              initialRoute: _initialRoute,
              onGenerateInitialRoutes: (initialRoute) => <Route<dynamic>>[
                _buildAppRoute(RouteSettings(name: initialRoute)),
              ],
              onGenerateRoute: _buildAppRoute,
            ),
          ),
        );
      },
    );
  }
}

class _LaunchLocationObserver extends NavigatorObserver {
  _LaunchLocationObserver(this.controller);

  final WebParityAppController controller;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _remember(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _remember(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _remember(newRoute);
  }

  void _remember(Route<dynamic>? route) {
    unawaited(controller.rememberLaunchLocation(route?.settings.name));
  }
}

class _AppKeyboardDismissOnTap extends StatelessWidget {
  const _AppKeyboardDismissOnTap({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Actions(
      actions: <Type, Action<Intent>>{
        EditableTextTapOutsideIntent:
            CallbackAction<EditableTextTapOutsideIntent>(
              onInvoke: (intent) {
                if (!intent.focusNode.hasFocus) {
                  return null;
                }
                intent.focusNode.unfocus();
                FocusManager.instance.primaryFocus?.unfocus();
                return null;
              },
            ),
      },
      child: TapRegionSurface(child: child),
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
