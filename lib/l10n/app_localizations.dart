import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ko.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ko'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'OpenCode Remote'**
  String get appTitle;

  /// No description provided for @foundationTitle.
  ///
  /// In en, this message translates to:
  /// **'Foundation debug workspace'**
  String get foundationTitle;

  /// No description provided for @foundationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Capability, fixture, and stream foundations are wired before UI parity work.'**
  String get foundationSubtitle;

  /// No description provided for @currentFlavor.
  ///
  /// In en, this message translates to:
  /// **'Flavor'**
  String get currentFlavor;

  /// No description provided for @currentLocale.
  ///
  /// In en, this message translates to:
  /// **'Locale'**
  String get currentLocale;

  /// No description provided for @fullCapabilityProbe.
  ///
  /// In en, this message translates to:
  /// **'Full capability probe'**
  String get fullCapabilityProbe;

  /// No description provided for @legacyCapabilityProbe.
  ///
  /// In en, this message translates to:
  /// **'Legacy capability probe'**
  String get legacyCapabilityProbe;

  /// No description provided for @probeErrorCapability.
  ///
  /// In en, this message translates to:
  /// **'Probe error handling'**
  String get probeErrorCapability;

  /// No description provided for @healthyStream.
  ///
  /// In en, this message translates to:
  /// **'Healthy stream'**
  String get healthyStream;

  /// No description provided for @staleStream.
  ///
  /// In en, this message translates to:
  /// **'Stale stream recovery'**
  String get staleStream;

  /// No description provided for @duplicateStream.
  ///
  /// In en, this message translates to:
  /// **'Duplicate event handling'**
  String get duplicateStream;

  /// No description provided for @resyncStream.
  ///
  /// In en, this message translates to:
  /// **'Resync required'**
  String get resyncStream;

  /// No description provided for @capabilityFlags.
  ///
  /// In en, this message translates to:
  /// **'Capability flags'**
  String get capabilityFlags;

  /// No description provided for @streamFrames.
  ///
  /// In en, this message translates to:
  /// **'Stream frames'**
  String get streamFrames;

  /// No description provided for @unknownFields.
  ///
  /// In en, this message translates to:
  /// **'Unknown fields preserved'**
  String get unknownFields;

  /// No description provided for @switchLocale.
  ///
  /// In en, this message translates to:
  /// **'Switch locale'**
  String get switchLocale;

  /// No description provided for @connectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Server connection manager'**
  String get connectionTitle;

  /// No description provided for @connectionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Store trusted OpenCode endpoints, probe capabilities first, then step into project and session workflows.'**
  String get connectionSubtitle;

  /// No description provided for @serverProfileManager.
  ///
  /// In en, this message translates to:
  /// **'Server profile manager'**
  String get serverProfileManager;

  /// No description provided for @connectionProfileHint.
  ///
  /// In en, this message translates to:
  /// **'Use saved profiles for trusted hosts and recent attempts for fast retries.'**
  String get connectionProfileHint;

  /// No description provided for @profileLabel.
  ///
  /// In en, this message translates to:
  /// **'Profile label'**
  String get profileLabel;

  /// No description provided for @serverAddress.
  ///
  /// In en, this message translates to:
  /// **'Server address'**
  String get serverAddress;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @testingConnection.
  ///
  /// In en, this message translates to:
  /// **'Testing...'**
  String get testingConnection;

  /// No description provided for @testConnection.
  ///
  /// In en, this message translates to:
  /// **'Test connection'**
  String get testConnection;

  /// No description provided for @saveProfile.
  ///
  /// In en, this message translates to:
  /// **'Save profile'**
  String get saveProfile;

  /// No description provided for @deleteProfile.
  ///
  /// In en, this message translates to:
  /// **'Delete profile'**
  String get deleteProfile;

  /// No description provided for @connectionGuidance.
  ///
  /// In en, this message translates to:
  /// **'Probe checks health, spec, config, providers, agent availability, and experimental tool support. mDNS and richer network discovery are next in the roadmap.'**
  String get connectionGuidance;

  /// No description provided for @savedServers.
  ///
  /// In en, this message translates to:
  /// **'Saved servers'**
  String get savedServers;

  /// No description provided for @recentConnections.
  ///
  /// In en, this message translates to:
  /// **'Recent connections'**
  String get recentConnections;

  /// No description provided for @noSavedServers.
  ///
  /// In en, this message translates to:
  /// **'No saved servers yet.'**
  String get noSavedServers;

  /// No description provided for @noRecentConnections.
  ///
  /// In en, this message translates to:
  /// **'No recent attempts yet.'**
  String get noRecentConnections;

  /// No description provided for @connectionDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Connection diagnostics'**
  String get connectionDiagnostics;

  /// No description provided for @connectionDiagnosticsHint.
  ///
  /// In en, this message translates to:
  /// **'Run a probe to classify auth, spec, capability, and SSE readiness before opening a workspace.'**
  String get connectionDiagnosticsHint;

  /// No description provided for @serverVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get serverVersion;

  /// No description provided for @sseStatus.
  ///
  /// In en, this message translates to:
  /// **'SSE'**
  String get sseStatus;

  /// No description provided for @readyStatus.
  ///
  /// In en, this message translates to:
  /// **'ready'**
  String get readyStatus;

  /// No description provided for @needsAttentionStatus.
  ///
  /// In en, this message translates to:
  /// **'needs attention'**
  String get needsAttentionStatus;

  /// No description provided for @connectionEmptyState.
  ///
  /// In en, this message translates to:
  /// **'Enter a server profile and run the probe to populate capability diagnostics.'**
  String get connectionEmptyState;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ko'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ko':
      return AppLocalizationsKo();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
