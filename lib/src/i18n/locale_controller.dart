import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_localizations.dart';

enum AppLocaleMode {
  system,
  english,
  korean;

  static const _englishLocale = Locale('en');
  static const _koreanLocale = Locale('ko');

  String get storageValue => name;

  Locale? get overrideLocale => switch (this) {
    AppLocaleMode.system => null,
    AppLocaleMode.english => _englishLocale,
    AppLocaleMode.korean => _koreanLocale,
  };

  static AppLocaleMode fromStorage(String? value) {
    return switch (value?.trim().toLowerCase()) {
      'english' || 'en' => AppLocaleMode.english,
      'korean' || 'ko' => AppLocaleMode.korean,
      _ => AppLocaleMode.system,
    };
  }
}

class LocaleController extends ChangeNotifier with WidgetsBindingObserver {
  static const _localeModeKey = 'app.locale_mode';

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
  AppLocaleMode _mode = AppLocaleMode.system;

  Locale get locale => _mode.overrideLocale ?? _systemLocale;
  AppLocaleMode get mode => _mode;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final nextMode = AppLocaleMode.fromStorage(prefs.getString(_localeModeKey));
    if (_mode == nextMode) {
      return;
    }
    _mode = nextMode;
    notifyListeners();
  }

  Future<void> setMode(AppLocaleMode value) async {
    if (_mode == value) {
      return;
    }
    _mode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeModeKey, value.storageValue);
  }

  void toggle() {
    final nextMode = locale.languageCode == 'ko'
        ? AppLocaleMode.english
        : AppLocaleMode.korean;
    unawaited(setMode(nextMode));
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
    if (_mode == AppLocaleMode.system) {
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
