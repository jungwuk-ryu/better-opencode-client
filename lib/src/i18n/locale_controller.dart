import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

class LocaleController extends ChangeNotifier with WidgetsBindingObserver {
  LocaleController({
    WidgetsBinding? binding,
    PlatformDispatcher? platformDispatcher,
  }) : _binding = binding ?? WidgetsBinding.instance,
       _platformDispatcher =
           platformDispatcher ?? WidgetsBinding.instance.platformDispatcher,
       _systemLocale = _resolveSupportedLocale(
         (platformDispatcher ?? WidgetsBinding.instance.platformDispatcher)
             .locales,
       ) {
    _binding.addObserver(this);
  }

  final WidgetsBinding _binding;
  final PlatformDispatcher _platformDispatcher;
  Locale _systemLocale;
  Locale? _localeOverride;

  Locale get locale => _localeOverride ?? _systemLocale;

  void toggle() {
    final supportedLocales = AppLocalizations.supportedLocales;
    final currentIndex = supportedLocales.indexWhere(
      (candidate) => _sameLocale(candidate, locale),
    );
    final nextIndex =
        currentIndex == -1 ? 0 : (currentIndex + 1) % supportedLocales.length;
    final nextLocale = supportedLocales[nextIndex];
    _localeOverride = _sameLocale(nextLocale, _systemLocale) ? null : nextLocale;
    notifyListeners();
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    final nextSystemLocale = _resolveSupportedLocale(
      locales ?? _platformDispatcher.locales,
    );
    if (_sameLocale(nextSystemLocale, _systemLocale)) {
      return;
    }
    _systemLocale = nextSystemLocale;
    if (_localeOverride == null) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _binding.removeObserver(this);
    super.dispose();
  }

  static Locale _resolveSupportedLocale(List<Locale> locales) {
    return basicLocaleListResolution(
          locales,
          AppLocalizations.supportedLocales,
        ) ??
        AppLocalizations.supportedLocales.first;
  }

  static bool _sameLocale(Locale left, Locale right) {
    return left.languageCode == right.languageCode &&
        left.scriptCode == right.scriptCode &&
        left.countryCode == right.countryCode;
  }
}
