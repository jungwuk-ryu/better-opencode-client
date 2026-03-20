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
  /// **'Foundation workspace'**
  String get foundationTitle;

  /// No description provided for @foundationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Built-in checks and live updates are ready before you connect a server.'**
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
  /// **'Full server check'**
  String get fullCapabilityProbe;

  /// No description provided for @legacyCapabilityProbe.
  ///
  /// In en, this message translates to:
  /// **'Compatibility check'**
  String get legacyCapabilityProbe;

  /// No description provided for @probeErrorCapability.
  ///
  /// In en, this message translates to:
  /// **'Check error handling'**
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

  /// No description provided for @cacheSettingsAction.
  ///
  /// In en, this message translates to:
  /// **'Cache settings'**
  String get cacheSettingsAction;

  /// No description provided for @cacheSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Cache settings'**
  String get cacheSettingsTitle;

  /// No description provided for @cacheSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Adjust cache freshness and clear stored connection checks and workspace snapshots.'**
  String get cacheSettingsSubtitle;

  /// No description provided for @cacheTtlLabel.
  ///
  /// In en, this message translates to:
  /// **'Cache freshness'**
  String get cacheTtlLabel;

  /// No description provided for @cacheClearAction.
  ///
  /// In en, this message translates to:
  /// **'Clear cached data'**
  String get cacheClearAction;

  /// No description provided for @cacheClearingAction.
  ///
  /// In en, this message translates to:
  /// **'Clearing cache...'**
  String get cacheClearingAction;

  /// No description provided for @cacheTtl15Seconds.
  ///
  /// In en, this message translates to:
  /// **'15 seconds'**
  String get cacheTtl15Seconds;

  /// No description provided for @cacheTtl1Minute.
  ///
  /// In en, this message translates to:
  /// **'1 minute'**
  String get cacheTtl1Minute;

  /// No description provided for @cacheTtl5Minutes.
  ///
  /// In en, this message translates to:
  /// **'5 minutes'**
  String get cacheTtl5Minutes;

  /// No description provided for @cacheTtl15Minutes.
  ///
  /// In en, this message translates to:
  /// **'15 minutes'**
  String get cacheTtl15Minutes;

  /// No description provided for @connectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Server connection manager'**
  String get connectionTitle;

  /// No description provided for @connectionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Store trusted OpenCode servers, run a server check when needed, and return to home to choose projects.'**
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
  /// **'Server check confirms health, compatibility, sign-in, provider access, and tool availability. More network discovery options are coming.'**
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
  /// **'Run a server check to confirm sign-in and compatibility before opening a workspace.'**
  String get connectionDiagnosticsHint;

  /// No description provided for @serverVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get serverVersion;

  /// No description provided for @sseStatus.
  ///
  /// In en, this message translates to:
  /// **'Live updates'**
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
  /// **'Enter a server profile and run a server check to populate diagnostics.'**
  String get connectionEmptyState;

  /// No description provided for @connectionHeaderEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Live server connection'**
  String get connectionHeaderEyebrow;

  /// No description provided for @connectionHeaderTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect a real OpenCode server'**
  String get connectionHeaderTitle;

  /// No description provided for @connectionHeaderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Review saved server details, verify sign-in, and return to workspace home once this server is ready.'**
  String get connectionHeaderSubtitle;

  /// No description provided for @connectionStatusAwaiting.
  ///
  /// In en, this message translates to:
  /// **'Awaiting first check'**
  String get connectionStatusAwaiting;

  /// No description provided for @connectionFormTitle.
  ///
  /// In en, this message translates to:
  /// **'Server profile manager'**
  String get connectionFormTitle;

  /// No description provided for @connectionFormSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Update saved server details, retry a check, and keep this profile ready for home.'**
  String get connectionFormSubtitle;

  /// No description provided for @savedProfilesCountLabel.
  ///
  /// In en, this message translates to:
  /// **'saved'**
  String get savedProfilesCountLabel;

  /// No description provided for @recentConnectionsCountLabel.
  ///
  /// In en, this message translates to:
  /// **'recent'**
  String get recentConnectionsCountLabel;

  /// No description provided for @sseReadyLabel.
  ///
  /// In en, this message translates to:
  /// **'Live updates ready'**
  String get sseReadyLabel;

  /// No description provided for @ssePendingLabel.
  ///
  /// In en, this message translates to:
  /// **'Check pending'**
  String get ssePendingLabel;

  /// No description provided for @connectionProfileLabel.
  ///
  /// In en, this message translates to:
  /// **'Profile name'**
  String get connectionProfileLabel;

  /// No description provided for @connectionProfileLabelHint.
  ///
  /// In en, this message translates to:
  /// **'Studio staging, laptop tunnel, on-prem gateway'**
  String get connectionProfileLabelHint;

  /// No description provided for @connectionAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'Server address'**
  String get connectionAddressLabel;

  /// No description provided for @connectionAddressHint.
  ///
  /// In en, this message translates to:
  /// **'https://opencode.example.com'**
  String get connectionAddressHint;

  /// No description provided for @connectionUsernameLabel.
  ///
  /// In en, this message translates to:
  /// **'Basic auth username'**
  String get connectionUsernameLabel;

  /// No description provided for @connectionUsernameHint.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get connectionUsernameHint;

  /// No description provided for @connectionPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Basic auth password'**
  String get connectionPasswordLabel;

  /// No description provided for @connectionPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get connectionPasswordHint;

  /// No description provided for @connectionAddressValidation.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid server address.'**
  String get connectionAddressValidation;

  /// No description provided for @connectionBackHomeAction.
  ///
  /// In en, this message translates to:
  /// **'Back to home'**
  String get connectionBackHomeAction;

  /// No description provided for @connectionProbeAction.
  ///
  /// In en, this message translates to:
  /// **'Check server'**
  String get connectionProbeAction;

  /// No description provided for @connectionSaveAction.
  ///
  /// In en, this message translates to:
  /// **'Save profile'**
  String get connectionSaveAction;

  /// No description provided for @connectionDraftRestoredLabel.
  ///
  /// In en, this message translates to:
  /// **'Restored unsaved draft'**
  String get connectionDraftRestoredLabel;

  /// No description provided for @connectionPinProfileAction.
  ///
  /// In en, this message translates to:
  /// **'Pin profile'**
  String get connectionPinProfileAction;

  /// No description provided for @connectionUnpinProfileAction.
  ///
  /// In en, this message translates to:
  /// **'Unpin profile'**
  String get connectionUnpinProfileAction;

  /// No description provided for @connectionProbeResultTitle.
  ///
  /// In en, this message translates to:
  /// **'Server check'**
  String get connectionProbeResultTitle;

  /// No description provided for @connectionProbeResultSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use this detail view to confirm whether the saved server still responds. Project selection happens from workspace home.'**
  String get connectionProbeResultSubtitle;

  /// No description provided for @connectionProbeEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No recent check yet'**
  String get connectionProbeEmptyTitle;

  /// No description provided for @connectionProbeEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Run a server check to confirm sign-in and compatibility before returning to workspace home.'**
  String get connectionProbeEmptySubtitle;

  /// No description provided for @connectionVersionLabel.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get connectionVersionLabel;

  /// No description provided for @connectionCheckedAtLabel.
  ///
  /// In en, this message translates to:
  /// **'Checked'**
  String get connectionCheckedAtLabel;

  /// No description provided for @connectionCapabilitiesLabel.
  ///
  /// In en, this message translates to:
  /// **'Capabilities enabled'**
  String get connectionCapabilitiesLabel;

  /// No description provided for @connectionReadinessLabel.
  ///
  /// In en, this message translates to:
  /// **'Readiness'**
  String get connectionReadinessLabel;

  /// No description provided for @connectionMissingCapabilitiesLabel.
  ///
  /// In en, this message translates to:
  /// **'Missing required features'**
  String get connectionMissingCapabilitiesLabel;

  /// No description provided for @connectionExperimentalPathsLabel.
  ///
  /// In en, this message translates to:
  /// **'Advanced tools'**
  String get connectionExperimentalPathsLabel;

  /// No description provided for @connectionEndpointSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Check results'**
  String get connectionEndpointSectionTitle;

  /// No description provided for @connectionCapabilitySectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Capabilities'**
  String get connectionCapabilitySectionTitle;

  /// No description provided for @savedProfilesTitle.
  ///
  /// In en, this message translates to:
  /// **'Saved profiles'**
  String get savedProfilesTitle;

  /// No description provided for @savedProfilesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pinned servers stay ready for quick checks.'**
  String get savedProfilesSubtitle;

  /// No description provided for @savedProfilesEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No saved profiles yet'**
  String get savedProfilesEmptyTitle;

  /// No description provided for @savedProfilesEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Save a working address so the app opens with a known server target next time.'**
  String get savedProfilesEmptySubtitle;

  /// No description provided for @recentConnectionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent attempts'**
  String get recentConnectionsTitle;

  /// No description provided for @recentConnectionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Recent server checks, kept separate from pinned servers.'**
  String get recentConnectionsSubtitle;

  /// No description provided for @recentConnectionsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No recent attempts yet'**
  String get recentConnectionsEmptyTitle;

  /// No description provided for @recentConnectionsEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Check a server and the latest outcome will stay here for quick retry.'**
  String get recentConnectionsEmptySubtitle;

  /// No description provided for @connectionOutcomeReady.
  ///
  /// In en, this message translates to:
  /// **'Ready for connection'**
  String get connectionOutcomeReady;

  /// No description provided for @connectionOutcomeAuthFailure.
  ///
  /// In en, this message translates to:
  /// **'Auth failure'**
  String get connectionOutcomeAuthFailure;

  /// No description provided for @connectionOutcomeSpecFailure.
  ///
  /// In en, this message translates to:
  /// **'Spec fetch failure'**
  String get connectionOutcomeSpecFailure;

  /// No description provided for @connectionOutcomeUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Unsupported capability set'**
  String get connectionOutcomeUnsupported;

  /// No description provided for @connectionOutcomeConnectivityFailure.
  ///
  /// In en, this message translates to:
  /// **'Connectivity failure'**
  String get connectionOutcomeConnectivityFailure;

  /// No description provided for @connectionDetailReady.
  ///
  /// In en, this message translates to:
  /// **'Core services responded and home can now offer project choices.'**
  String get connectionDetailReady;

  /// No description provided for @connectionDetailAuthFailure.
  ///
  /// In en, this message translates to:
  /// **'The server responded, but the provided sign-in details were rejected.'**
  String get connectionDetailAuthFailure;

  /// No description provided for @connectionDetailBasicAuthFailure.
  ///
  /// In en, this message translates to:
  /// **'This server is protected by Basic auth. Add or update the username and password, then try again.'**
  String get connectionDetailBasicAuthFailure;

  /// No description provided for @connectionDetailSpecFailure.
  ///
  /// In en, this message translates to:
  /// **'The server is reachable, but the OpenAPI spec could not be fetched or parsed cleanly.'**
  String get connectionDetailSpecFailure;

  /// No description provided for @connectionDetailUnsupported.
  ///
  /// In en, this message translates to:
  /// **'The server is reachable, but required features for this app are still missing.'**
  String get connectionDetailUnsupported;

  /// No description provided for @connectionDetailConnectivityFailure.
  ///
  /// In en, this message translates to:
  /// **'The server could not be reached reliably enough to complete the check.'**
  String get connectionDetailConnectivityFailure;

  /// No description provided for @endpointReadyStatus.
  ///
  /// In en, this message translates to:
  /// **'ready'**
  String get endpointReadyStatus;

  /// No description provided for @endpointAuthStatus.
  ///
  /// In en, this message translates to:
  /// **'auth'**
  String get endpointAuthStatus;

  /// No description provided for @endpointUnsupportedStatus.
  ///
  /// In en, this message translates to:
  /// **'unsupported'**
  String get endpointUnsupportedStatus;

  /// No description provided for @endpointFailureStatus.
  ///
  /// In en, this message translates to:
  /// **'failure'**
  String get endpointFailureStatus;

  /// No description provided for @endpointUnknownStatus.
  ///
  /// In en, this message translates to:
  /// **'unknown'**
  String get endpointUnknownStatus;

  /// No description provided for @fixtureDiagnosticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get fixtureDiagnosticsTitle;

  /// No description provided for @fixtureDiagnosticsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Connection checks and status details live here.'**
  String get fixtureDiagnosticsSubtitle;

  /// No description provided for @capabilityCanShareSession.
  ///
  /// In en, this message translates to:
  /// **'Share session'**
  String get capabilityCanShareSession;

  /// No description provided for @capabilityCanForkSession.
  ///
  /// In en, this message translates to:
  /// **'Fork session'**
  String get capabilityCanForkSession;

  /// No description provided for @capabilityCanSummarizeSession.
  ///
  /// In en, this message translates to:
  /// **'Summarize session'**
  String get capabilityCanSummarizeSession;

  /// No description provided for @capabilityCanRevertSession.
  ///
  /// In en, this message translates to:
  /// **'Revert session'**
  String get capabilityCanRevertSession;

  /// No description provided for @capabilityHasQuestions.
  ///
  /// In en, this message translates to:
  /// **'Questions'**
  String get capabilityHasQuestions;

  /// No description provided for @capabilityHasPermissions.
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get capabilityHasPermissions;

  /// No description provided for @capabilityHasExperimentalTools.
  ///
  /// In en, this message translates to:
  /// **'Advanced tools'**
  String get capabilityHasExperimentalTools;

  /// No description provided for @capabilityHasProviderOAuth.
  ///
  /// In en, this message translates to:
  /// **'Provider OAuth'**
  String get capabilityHasProviderOAuth;

  /// No description provided for @capabilityHasMcpAuth.
  ///
  /// In en, this message translates to:
  /// **'MCP auth'**
  String get capabilityHasMcpAuth;

  /// No description provided for @capabilityHasTuiControl.
  ///
  /// In en, this message translates to:
  /// **'TUI control'**
  String get capabilityHasTuiControl;

  /// No description provided for @projectSelectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a project'**
  String get projectSelectionTitle;

  /// No description provided for @projectSelectionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Open a project from this server, your recent work, or a folder path.'**
  String get projectSelectionSubtitle;

  /// No description provided for @currentProjectTitle.
  ///
  /// In en, this message translates to:
  /// **'Current project'**
  String get currentProjectTitle;

  /// No description provided for @currentProjectSubtitle.
  ///
  /// In en, this message translates to:
  /// **'If the server is already inside a project, it appears here first.'**
  String get currentProjectSubtitle;

  /// No description provided for @serverProjectsTitle.
  ///
  /// In en, this message translates to:
  /// **'Projects on this server'**
  String get serverProjectsTitle;

  /// No description provided for @serverProjectsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Other projects the server can open right now.'**
  String get serverProjectsSubtitle;

  /// No description provided for @serverProjectsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No server projects are available right now. You can still open a recent project or folder path.'**
  String get serverProjectsEmpty;

  /// No description provided for @manualProjectTitle.
  ///
  /// In en, this message translates to:
  /// **'Open a folder path'**
  String get manualProjectTitle;

  /// No description provided for @manualProjectSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use this when the server list is empty or you know exactly which folder you want.'**
  String get manualProjectSubtitle;

  /// No description provided for @manualProjectPathLabel.
  ///
  /// In en, this message translates to:
  /// **'Project directory'**
  String get manualProjectPathLabel;

  /// No description provided for @manualProjectPathHint.
  ///
  /// In en, this message translates to:
  /// **'/workspace/my-project'**
  String get manualProjectPathHint;

  /// No description provided for @projectInspectAction.
  ///
  /// In en, this message translates to:
  /// **'Inspect path'**
  String get projectInspectAction;

  /// No description provided for @projectInspectingAction.
  ///
  /// In en, this message translates to:
  /// **'Inspecting...'**
  String get projectInspectingAction;

  /// No description provided for @projectBrowseAction.
  ///
  /// In en, this message translates to:
  /// **'Browse folder'**
  String get projectBrowseAction;

  /// No description provided for @recentProjectsTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent projects'**
  String get recentProjectsTitle;

  /// No description provided for @recentProjectsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Projects you\'ve opened recently, with last session hints when we have them.'**
  String get recentProjectsSubtitle;

  /// No description provided for @pinnedProjectsTitle.
  ///
  /// In en, this message translates to:
  /// **'Pinned projects'**
  String get pinnedProjectsTitle;

  /// No description provided for @pinnedProjectsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Local favorites kept at the top for quick mobile access.'**
  String get pinnedProjectsSubtitle;

  /// No description provided for @recentProjectsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No recent projects yet.'**
  String get recentProjectsEmpty;

  /// No description provided for @projectPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Project details'**
  String get projectPreviewTitle;

  /// No description provided for @projectPreviewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Review the next workspace before you open it.'**
  String get projectPreviewSubtitle;

  /// No description provided for @projectPreviewEmpty.
  ///
  /// In en, this message translates to:
  /// **'Select a project, recent workspace, or folder path to see details here.'**
  String get projectPreviewEmpty;

  /// No description provided for @projectDirectoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Directory'**
  String get projectDirectoryLabel;

  /// No description provided for @projectSourceLabel.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get projectSourceLabel;

  /// No description provided for @projectVcsLabel.
  ///
  /// In en, this message translates to:
  /// **'VCS'**
  String get projectVcsLabel;

  /// No description provided for @projectBranchLabel.
  ///
  /// In en, this message translates to:
  /// **'Branch'**
  String get projectBranchLabel;

  /// No description provided for @projectLastSessionLabel.
  ///
  /// In en, this message translates to:
  /// **'Last session'**
  String get projectLastSessionLabel;

  /// No description provided for @projectLastStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Last status'**
  String get projectLastStatusLabel;

  /// No description provided for @projectLastSessionUnknown.
  ///
  /// In en, this message translates to:
  /// **'Not captured yet'**
  String get projectLastSessionUnknown;

  /// No description provided for @projectLastStatusUnknown.
  ///
  /// In en, this message translates to:
  /// **'Not captured yet'**
  String get projectLastStatusUnknown;

  /// No description provided for @projectSelectionReadyHint.
  ///
  /// In en, this message translates to:
  /// **'Open this project to continue into its sessions.'**
  String get projectSelectionReadyHint;

  /// No description provided for @homeHeaderEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Workspace'**
  String get homeHeaderEyebrow;

  /// No description provided for @homeHeaderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Connect a server, then open a project and continue your sessions.'**
  String get homeHeaderSubtitle;

  /// No description provided for @homeAddServerAction.
  ///
  /// In en, this message translates to:
  /// **'Add server'**
  String get homeAddServerAction;

  /// No description provided for @homeBackToServersAction.
  ///
  /// In en, this message translates to:
  /// **'Back to servers'**
  String get homeBackToServersAction;

  /// No description provided for @homeConnectServerAction.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get homeConnectServerAction;

  /// No description provided for @homeEditSelectedServerAction.
  ///
  /// In en, this message translates to:
  /// **'Edit selected server'**
  String get homeEditSelectedServerAction;

  /// No description provided for @homeEditServerAction.
  ///
  /// In en, this message translates to:
  /// **'Edit server'**
  String get homeEditServerAction;

  /// No description provided for @homeSwitchServerAction.
  ///
  /// In en, this message translates to:
  /// **'Switch server'**
  String get homeSwitchServerAction;

  /// No description provided for @homeNextStepsTitle.
  ///
  /// In en, this message translates to:
  /// **'Next steps'**
  String get homeNextStepsTitle;

  /// No description provided for @homeNextStepsPinnedServers.
  ///
  /// In en, this message translates to:
  /// **'Pin the servers you use most, so they stay at the top.'**
  String get homeNextStepsPinnedServers;

  /// No description provided for @homeNextStepsProjects.
  ///
  /// In en, this message translates to:
  /// **'Once a server is ready, open a project and jump into sessions.'**
  String get homeNextStepsProjects;

  /// No description provided for @homeNextStepsRetryEdit.
  ///
  /// In en, this message translates to:
  /// **'Retry or edit a server without leaving home.'**
  String get homeNextStepsRetryEdit;

  /// No description provided for @homeMetricSavedServers.
  ///
  /// In en, this message translates to:
  /// **'Saved servers'**
  String get homeMetricSavedServers;

  /// No description provided for @homeMetricRecentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent activity'**
  String get homeMetricRecentActivity;

  /// No description provided for @homeMetricCurrentFocus.
  ///
  /// In en, this message translates to:
  /// **'Current server'**
  String get homeMetricCurrentFocus;

  /// No description provided for @homeChooseServerLabel.
  ///
  /// In en, this message translates to:
  /// **'Choose a server'**
  String get homeChooseServerLabel;

  /// No description provided for @homeResumeLastWorkspaceTitle.
  ///
  /// In en, this message translates to:
  /// **'Resume last workspace'**
  String get homeResumeLastWorkspaceTitle;

  /// No description provided for @homeOpenLastProjectTitle.
  ///
  /// In en, this message translates to:
  /// **'Open last project'**
  String get homeOpenLastProjectTitle;

  /// No description provided for @homeResumeLastWorkspaceBody.
  ///
  /// In en, this message translates to:
  /// **'Continue in {project} and pick up where you left off.'**
  String homeResumeLastWorkspaceBody(String project);

  /// No description provided for @homeOpenLastProjectBody.
  ///
  /// In en, this message translates to:
  /// **'Open {project}, then choose a session or start a new one.'**
  String homeOpenLastProjectBody(String project);

  /// No description provided for @homeResumeLastWorkspaceAction.
  ///
  /// In en, this message translates to:
  /// **'Resume workspace'**
  String get homeResumeLastWorkspaceAction;

  /// No description provided for @homeOpenLastProjectAction.
  ///
  /// In en, this message translates to:
  /// **'Open project'**
  String get homeOpenLastProjectAction;

  /// No description provided for @homeResumeMetricProject.
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get homeResumeMetricProject;

  /// No description provided for @homeResumeMetricLastSession.
  ///
  /// In en, this message translates to:
  /// **'Last session'**
  String get homeResumeMetricLastSession;

  /// No description provided for @homeResumeMetricStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get homeResumeMetricStatus;

  /// No description provided for @homeActionCheckingWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Checking workspace...'**
  String get homeActionCheckingWorkspace;

  /// No description provided for @homeActionContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get homeActionContinue;

  /// No description provided for @homeActionRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get homeActionRetry;

  /// No description provided for @homeActionCheckingServer.
  ///
  /// In en, this message translates to:
  /// **'Checking server...'**
  String get homeActionCheckingServer;

  /// No description provided for @homeThisServerLabel.
  ///
  /// In en, this message translates to:
  /// **'This server'**
  String get homeThisServerLabel;

  /// No description provided for @homeWorkspaceSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Projects and sessions'**
  String get homeWorkspaceSectionTitle;

  /// No description provided for @homeWorkspaceLoadingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Loading your saved servers and recent activity.'**
  String get homeWorkspaceLoadingSubtitle;

  /// No description provided for @homeWorkspaceSelectionHint.
  ///
  /// In en, this message translates to:
  /// **'Select a server from the list or add a new one.'**
  String get homeWorkspaceSelectionHint;

  /// No description provided for @homeWorkspaceConnectHint.
  ///
  /// In en, this message translates to:
  /// **'Connect the selected server to load its projects.'**
  String get homeWorkspaceConnectHint;

  /// No description provided for @homeWorkspaceEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add a server to start opening projects and sessions here.'**
  String get homeWorkspaceEmptySubtitle;

  /// No description provided for @homeWorkspaceFeatureSaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Save a server once'**
  String get homeWorkspaceFeatureSaveTitle;

  /// No description provided for @homeWorkspaceFeatureSaveBody.
  ///
  /// In en, this message translates to:
  /// **'Keep servers in one place, ready when you come back.'**
  String get homeWorkspaceFeatureSaveBody;

  /// No description provided for @homeWorkspaceFeatureChooseTitle.
  ///
  /// In en, this message translates to:
  /// **'Open a project next'**
  String get homeWorkspaceFeatureChooseTitle;

  /// No description provided for @homeWorkspaceFeatureChooseBody.
  ///
  /// In en, this message translates to:
  /// **'When the server is ready, choose a project and continue.'**
  String get homeWorkspaceFeatureChooseBody;

  /// No description provided for @homeWorkspaceFeatureRecentTitle.
  ///
  /// In en, this message translates to:
  /// **'Keep recents in view'**
  String get homeWorkspaceFeatureRecentTitle;

  /// No description provided for @homeWorkspaceFeatureRecentBody.
  ///
  /// In en, this message translates to:
  /// **'Saved servers and recent checks stay together on one screen.'**
  String get homeWorkspaceFeatureRecentBody;

  /// No description provided for @homeWorkspaceSubtitleReady.
  ///
  /// In en, this message translates to:
  /// **'Choose a project to continue.'**
  String get homeWorkspaceSubtitleReady;

  /// No description provided for @homeWorkspaceSubtitleSignIn.
  ///
  /// In en, this message translates to:
  /// **'Update sign-in details or retry before projects can load.'**
  String get homeWorkspaceSubtitleSignIn;

  /// No description provided for @homeWorkspaceSubtitleOffline.
  ///
  /// In en, this message translates to:
  /// **'Retry this server or confirm the saved address.'**
  String get homeWorkspaceSubtitleOffline;

  /// No description provided for @homeWorkspaceSubtitleUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update the server before projects can load.'**
  String get homeWorkspaceSubtitleUpdate;

  /// No description provided for @homeWorkspaceSubtitleUnknown.
  ///
  /// In en, this message translates to:
  /// **'Run a quick check before loading projects.'**
  String get homeWorkspaceSubtitleUnknown;

  /// No description provided for @homeWorkspaceTitleChooseServer.
  ///
  /// In en, this message translates to:
  /// **'Choose a saved server'**
  String get homeWorkspaceTitleChooseServer;

  /// No description provided for @homeWorkspaceTitleChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking {server}'**
  String homeWorkspaceTitleChecking(String server);

  /// No description provided for @homeWorkspaceTitleReady.
  ///
  /// In en, this message translates to:
  /// **'Ready for projects'**
  String get homeWorkspaceTitleReady;

  /// No description provided for @homeWorkspaceTitleSignInRequired.
  ///
  /// In en, this message translates to:
  /// **'Sign-in required'**
  String get homeWorkspaceTitleSignInRequired;

  /// No description provided for @homeWorkspaceTitleOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get homeWorkspaceTitleOffline;

  /// No description provided for @homeWorkspaceTitleUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update required'**
  String get homeWorkspaceTitleUpdate;

  /// No description provided for @homeWorkspaceTitleContinueFromHome.
  ///
  /// In en, this message translates to:
  /// **'Continue from home'**
  String get homeWorkspaceTitleContinueFromHome;

  /// No description provided for @homeWorkspaceBodyChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking sign-in and compatibility before loading projects and sessions.'**
  String get homeWorkspaceBodyChecking;

  /// No description provided for @homeWorkspaceBodyReady.
  ///
  /// In en, this message translates to:
  /// **'{server} is ready, but the project list is still loading.'**
  String homeWorkspaceBodyReady(String server);

  /// No description provided for @homeWorkspaceBodySignInRequired.
  ///
  /// In en, this message translates to:
  /// **'{server} responded, but sign-in details need attention before projects can load.'**
  String homeWorkspaceBodySignInRequired(String server);

  /// No description provided for @homeWorkspaceBodyBasicAuthRequired.
  ///
  /// In en, this message translates to:
  /// **'{server} is protected by Basic auth. Edit this server and add the username and password before loading projects.'**
  String homeWorkspaceBodyBasicAuthRequired(String server);

  /// No description provided for @homeWorkspaceBodyOffline.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach {server} just now. Retry, or edit the saved address if it changed.'**
  String homeWorkspaceBodyOffline(String server);

  /// No description provided for @homeWorkspaceBodyUpdateRequired.
  ///
  /// In en, this message translates to:
  /// **'{server} responded, but it needs an update before projects can load.'**
  String homeWorkspaceBodyUpdateRequired(String server);

  /// No description provided for @homeWorkspaceBodyUnknown.
  ///
  /// In en, this message translates to:
  /// **'Run a quick check, then edit details only if sign-in or the address needs attention.'**
  String get homeWorkspaceBodyUnknown;

  /// No description provided for @homeNoticeWorkspaceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Your last workspace is no longer available. Choose a project to continue.'**
  String get homeNoticeWorkspaceUnavailable;

  /// No description provided for @homeNoticeWorkspaceResumeFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reopen your last workspace right now. Choose a project below or retry this server.'**
  String get homeNoticeWorkspaceResumeFailed;

  /// No description provided for @homeSavedServersTitle.
  ///
  /// In en, this message translates to:
  /// **'Saved servers'**
  String get homeSavedServersTitle;

  /// No description provided for @homeSavedServersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pick a server, then continue into projects and sessions.'**
  String get homeSavedServersSubtitle;

  /// No description provided for @homeServerPanelSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add a server, edit saved details, and connect when you\'re ready.'**
  String get homeServerPanelSubtitle;

  /// No description provided for @homeSavedServersEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No saved servers yet'**
  String get homeSavedServersEmptyTitle;

  /// No description provided for @homeSavedServersEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add your first server to start opening projects and sessions.'**
  String get homeSavedServersEmptySubtitle;

  /// No description provided for @homeRecentActivityTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent activity'**
  String get homeRecentActivityTitle;

  /// No description provided for @homeRecentActivitySubtitle.
  ///
  /// In en, this message translates to:
  /// **'A quick record of the servers you checked most recently.'**
  String get homeRecentActivitySubtitle;

  /// No description provided for @homeRecentActivityEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No recent activity yet'**
  String get homeRecentActivityEmptyTitle;

  /// No description provided for @homeRecentActivityEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Recent checks show up here after you connect or retry a server.'**
  String get homeRecentActivityEmptySubtitle;

  /// No description provided for @homeRecentActivityNotUsed.
  ///
  /// In en, this message translates to:
  /// **'Not used yet'**
  String get homeRecentActivityNotUsed;

  /// No description provided for @homeRecentActivityLastUsed.
  ///
  /// In en, this message translates to:
  /// **'Last used {timestamp}'**
  String homeRecentActivityLastUsed(String timestamp);

  /// No description provided for @homeCredentialsSaved.
  ///
  /// In en, this message translates to:
  /// **'Credentials saved'**
  String get homeCredentialsSaved;

  /// No description provided for @homeCredentialsMissing.
  ///
  /// In en, this message translates to:
  /// **'No credentials saved'**
  String get homeCredentialsMissing;

  /// No description provided for @homeServerCardBodyReady.
  ///
  /// In en, this message translates to:
  /// **'Ready to open projects and sessions from home.'**
  String get homeServerCardBodyReady;

  /// No description provided for @homeServerCardBodySignIn.
  ///
  /// In en, this message translates to:
  /// **'Retry, or update sign-in details before projects can load.'**
  String get homeServerCardBodySignIn;

  /// No description provided for @homeServerCardBodyBasicAuthRequired.
  ///
  /// In en, this message translates to:
  /// **'Basic auth is required before this server can load projects.'**
  String get homeServerCardBodyBasicAuthRequired;

  /// No description provided for @homeServerCardBodyOffline.
  ///
  /// In en, this message translates to:
  /// **'Retry, or edit the saved address before continuing.'**
  String get homeServerCardBodyOffline;

  /// No description provided for @homeServerCardBodyUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update the server before continuing into projects and sessions.'**
  String get homeServerCardBodyUpdate;

  /// No description provided for @homeServerCardBodyUnknownWithAuth.
  ///
  /// In en, this message translates to:
  /// **'Run a quick check before loading projects.'**
  String get homeServerCardBodyUnknownWithAuth;

  /// No description provided for @homeServerCardBodyUnknown.
  ///
  /// In en, this message translates to:
  /// **'Run a quick check, then edit details only if sign-in is needed.'**
  String get homeServerCardBodyUnknown;

  /// No description provided for @homeConnectionFailedNotice.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t connect to {server}. Check the saved address or credentials and try again.'**
  String homeConnectionFailedNotice(String server);

  /// No description provided for @homeConnectionNeedsCredentialsNotice.
  ///
  /// In en, this message translates to:
  /// **'This server needs username and password before it can connect.'**
  String get homeConnectionNeedsCredentialsNotice;

  /// No description provided for @homeStatusNewHome.
  ///
  /// In en, this message translates to:
  /// **'New home'**
  String get homeStatusNewHome;

  /// No description provided for @homeStatusChooseServer.
  ///
  /// In en, this message translates to:
  /// **'Choose a server'**
  String get homeStatusChooseServer;

  /// No description provided for @homeStatusCheckingServer.
  ///
  /// In en, this message translates to:
  /// **'Checking server'**
  String get homeStatusCheckingServer;

  /// No description provided for @homeStatusReadyForProjects.
  ///
  /// In en, this message translates to:
  /// **'Ready for projects'**
  String get homeStatusReadyForProjects;

  /// No description provided for @homeStatusSignInRequired.
  ///
  /// In en, this message translates to:
  /// **'Sign-in required'**
  String get homeStatusSignInRequired;

  /// No description provided for @homeStatusServerOffline.
  ///
  /// In en, this message translates to:
  /// **'Server offline'**
  String get homeStatusServerOffline;

  /// No description provided for @homeStatusNeedsAttention.
  ///
  /// In en, this message translates to:
  /// **'Needs attention'**
  String get homeStatusNeedsAttention;

  /// No description provided for @homeStatusAwaitingSetup.
  ///
  /// In en, this message translates to:
  /// **'Awaiting setup'**
  String get homeStatusAwaitingSetup;

  /// No description provided for @homeHeroTitleNoServers.
  ///
  /// In en, this message translates to:
  /// **'Start with a server'**
  String get homeHeroTitleNoServers;

  /// No description provided for @homeHeroTitleOneServer.
  ///
  /// In en, this message translates to:
  /// **'Your server, ready to go'**
  String get homeHeroTitleOneServer;

  /// No description provided for @homeHeroTitleManyServers.
  ///
  /// In en, this message translates to:
  /// **'All your servers in one place'**
  String get homeHeroTitleManyServers;

  /// No description provided for @homeHeroBodyNoServers.
  ///
  /// In en, this message translates to:
  /// **'Add a server once, then return here to open projects and continue sessions.'**
  String get homeHeroBodyNoServers;

  /// No description provided for @homeHeroBodyOneServer.
  ///
  /// In en, this message translates to:
  /// **'Continue from home, and only open server details when something changes.'**
  String get homeHeroBodyOneServer;

  /// No description provided for @homeHeroBodyManyServers.
  ///
  /// In en, this message translates to:
  /// **'Pick a server, keep recents in view, and run a quick check when needed.'**
  String get homeHeroBodyManyServers;

  /// No description provided for @homeA11yAddServerAction.
  ///
  /// In en, this message translates to:
  /// **'Add server'**
  String get homeA11yAddServerAction;

  /// No description provided for @homeA11yBackToServersAction.
  ///
  /// In en, this message translates to:
  /// **'Back to server selection'**
  String get homeA11yBackToServersAction;

  /// No description provided for @homeA11yEditSelectedServerAction.
  ///
  /// In en, this message translates to:
  /// **'Edit selected server'**
  String get homeA11yEditSelectedServerAction;

  /// No description provided for @homeA11yWorkspacePrimaryAction.
  ///
  /// In en, this message translates to:
  /// **'Workspace primary action'**
  String get homeA11yWorkspacePrimaryAction;

  /// No description provided for @homeA11yEditServerAction.
  ///
  /// In en, this message translates to:
  /// **'Edit server'**
  String get homeA11yEditServerAction;

  /// No description provided for @homeA11ySwitchServerAction.
  ///
  /// In en, this message translates to:
  /// **'Switch server'**
  String get homeA11ySwitchServerAction;

  /// No description provided for @homeA11yResumeWorkspaceAction.
  ///
  /// In en, this message translates to:
  /// **'Resume workspace'**
  String get homeA11yResumeWorkspaceAction;

  /// No description provided for @homeStatusShortReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get homeStatusShortReady;

  /// No description provided for @homeStatusShortSignInRequired.
  ///
  /// In en, this message translates to:
  /// **'Sign-in required'**
  String get homeStatusShortSignInRequired;

  /// No description provided for @homeStatusShortOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get homeStatusShortOffline;

  /// No description provided for @homeStatusShortNeedsAttention.
  ///
  /// In en, this message translates to:
  /// **'Needs attention'**
  String get homeStatusShortNeedsAttention;

  /// No description provided for @homeStatusShortNotCheckedYet.
  ///
  /// In en, this message translates to:
  /// **'Not checked yet'**
  String get homeStatusShortNotCheckedYet;

  /// No description provided for @projectCatalogUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Project list unavailable'**
  String get projectCatalogUnavailableTitle;

  /// No description provided for @projectCatalogUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t load this server\'s project list just now. You can still open a recent workspace or enter a folder path.'**
  String get projectCatalogUnavailableBody;

  /// No description provided for @projectOpenAction.
  ///
  /// In en, this message translates to:
  /// **'Open project'**
  String get projectOpenAction;

  /// No description provided for @projectPinAction.
  ///
  /// In en, this message translates to:
  /// **'Pin project'**
  String get projectPinAction;

  /// No description provided for @projectUnpinAction.
  ///
  /// In en, this message translates to:
  /// **'Unpin project'**
  String get projectUnpinAction;

  /// No description provided for @shellProjectRailTitle.
  ///
  /// In en, this message translates to:
  /// **'Project and sessions'**
  String get shellProjectRailTitle;

  /// No description provided for @shellDestinationSessions.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get shellDestinationSessions;

  /// No description provided for @shellDestinationChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get shellDestinationChat;

  /// No description provided for @shellDestinationContext.
  ///
  /// In en, this message translates to:
  /// **'Context'**
  String get shellDestinationContext;

  /// No description provided for @shellDestinationSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get shellDestinationSettings;

  /// No description provided for @shellAdvancedLabel.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get shellAdvancedLabel;

  /// No description provided for @shellAdvancedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Advanced settings and troubleshooting tools.'**
  String get shellAdvancedSubtitle;

  /// No description provided for @shellAdvancedOverviewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Technical options kept out of the main flow.'**
  String get shellAdvancedOverviewSubtitle;

  /// No description provided for @shellOpenAdvancedAction.
  ///
  /// In en, this message translates to:
  /// **'Open advanced'**
  String get shellOpenAdvancedAction;

  /// No description provided for @shellBackToSettingsAction.
  ///
  /// In en, this message translates to:
  /// **'Back to settings'**
  String get shellBackToSettingsAction;

  /// No description provided for @shellA11yOpenCacheSettings.
  ///
  /// In en, this message translates to:
  /// **'Open cache settings'**
  String get shellA11yOpenCacheSettings;

  /// No description provided for @shellA11yOpenAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Open advanced settings'**
  String get shellA11yOpenAdvanced;

  /// No description provided for @shellA11yBackToSettings.
  ///
  /// In en, this message translates to:
  /// **'Back to settings'**
  String get shellA11yBackToSettings;

  /// No description provided for @shellA11yBackToProjectsAction.
  ///
  /// In en, this message translates to:
  /// **'Back to projects'**
  String get shellA11yBackToProjectsAction;

  /// No description provided for @shellA11yComposerField.
  ///
  /// In en, this message translates to:
  /// **'Message field'**
  String get shellA11yComposerField;

  /// No description provided for @shellA11ySendMessageAction.
  ///
  /// In en, this message translates to:
  /// **'Send message'**
  String get shellA11ySendMessageAction;

  /// No description provided for @shellIntegrationsLastAuthUrlTitle.
  ///
  /// In en, this message translates to:
  /// **'Last authorization URL'**
  String get shellIntegrationsLastAuthUrlTitle;

  /// No description provided for @shellIntegrationsEventsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Event stream status and recovery details.'**
  String get shellIntegrationsEventsSubtitle;

  /// No description provided for @shellStreamHealthConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get shellStreamHealthConnected;

  /// No description provided for @shellStreamHealthStale.
  ///
  /// In en, this message translates to:
  /// **'Stale'**
  String get shellStreamHealthStale;

  /// No description provided for @shellStreamHealthReconnecting.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting'**
  String get shellStreamHealthReconnecting;

  /// No description provided for @shellConfigPreviewUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Configuration view is unavailable right now.'**
  String get shellConfigPreviewUnavailable;

  /// No description provided for @shellNoticeLastSessionUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Your last session is no longer available. Choose another session or start a new one.'**
  String get shellNoticeLastSessionUnavailable;

  /// No description provided for @shellConfigJsonObjectError.
  ///
  /// In en, this message translates to:
  /// **'Config must be a JSON object.'**
  String get shellConfigJsonObjectError;

  /// No description provided for @shellRecoveryLogReconnectRequested.
  ///
  /// In en, this message translates to:
  /// **'Reconnect requested'**
  String get shellRecoveryLogReconnectRequested;

  /// No description provided for @shellRecoveryLogReconnectCompleted.
  ///
  /// In en, this message translates to:
  /// **'Reconnect completed'**
  String get shellRecoveryLogReconnectCompleted;

  /// No description provided for @shellUnknownLabel.
  ///
  /// In en, this message translates to:
  /// **'unknown'**
  String get shellUnknownLabel;

  /// No description provided for @shellBackToProjectsAction.
  ///
  /// In en, this message translates to:
  /// **'Back to projects'**
  String get shellBackToProjectsAction;

  /// No description provided for @shellSessionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get shellSessionsTitle;

  /// No description provided for @shellSessionCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current session'**
  String get shellSessionCurrent;

  /// No description provided for @shellSessionDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft branch'**
  String get shellSessionDraft;

  /// No description provided for @shellSessionReview.
  ///
  /// In en, this message translates to:
  /// **'Review branch'**
  String get shellSessionReview;

  /// No description provided for @shellStatusActive.
  ///
  /// In en, this message translates to:
  /// **'active'**
  String get shellStatusActive;

  /// No description provided for @shellStatusIdle.
  ///
  /// In en, this message translates to:
  /// **'idle'**
  String get shellStatusIdle;

  /// No description provided for @shellStatusError.
  ///
  /// In en, this message translates to:
  /// **'error'**
  String get shellStatusError;

  /// No description provided for @shellChatHeaderTitle.
  ///
  /// In en, this message translates to:
  /// **'Chat workspace'**
  String get shellChatHeaderTitle;

  /// No description provided for @shellThinkingModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Balanced thinking'**
  String get shellThinkingModeLabel;

  /// No description provided for @shellAgentLabel.
  ///
  /// In en, this message translates to:
  /// **'Agent'**
  String get shellAgentLabel;

  /// No description provided for @shellChatTimelineTitle.
  ///
  /// In en, this message translates to:
  /// **'Conversation'**
  String get shellChatTimelineTitle;

  /// No description provided for @shellUserMessageTitle.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get shellUserMessageTitle;

  /// No description provided for @shellUserMessageBody.
  ///
  /// In en, this message translates to:
  /// **'Pick a session, then send a message to get started.'**
  String get shellUserMessageBody;

  /// No description provided for @shellAssistantMessageTitle.
  ///
  /// In en, this message translates to:
  /// **'OpenCode'**
  String get shellAssistantMessageTitle;

  /// No description provided for @shellAssistantMessageBody.
  ///
  /// In en, this message translates to:
  /// **'You\'re in the workspace. Review context, pick a session, and keep work moving.'**
  String get shellAssistantMessageBody;

  /// No description provided for @shellComposerPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Write a message'**
  String get shellComposerPlaceholder;

  /// No description provided for @shellComposerSendAction.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get shellComposerSendAction;

  /// No description provided for @shellComposerCreatingSession.
  ///
  /// In en, this message translates to:
  /// **'Create session and send'**
  String get shellComposerCreatingSession;

  /// No description provided for @shellComposerSending.
  ///
  /// In en, this message translates to:
  /// **'Sending...'**
  String get shellComposerSending;

  /// No description provided for @shellRenameSessionTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename session'**
  String get shellRenameSessionTitle;

  /// No description provided for @shellSessionTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Session title'**
  String get shellSessionTitleHint;

  /// No description provided for @shellCancelAction.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get shellCancelAction;

  /// No description provided for @shellSaveAction.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get shellSaveAction;

  /// No description provided for @shellContextTitle.
  ///
  /// In en, this message translates to:
  /// **'Context utilities'**
  String get shellContextTitle;

  /// No description provided for @shellFilesTitle.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get shellFilesTitle;

  /// No description provided for @shellFilesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tree, status, and search live here.'**
  String get shellFilesSubtitle;

  /// No description provided for @shellDiffTitle.
  ///
  /// In en, this message translates to:
  /// **'Diff'**
  String get shellDiffTitle;

  /// No description provided for @shellDiffSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Patch and snapshot review appear here.'**
  String get shellDiffSubtitle;

  /// No description provided for @shellTodoTitle.
  ///
  /// In en, this message translates to:
  /// **'Todo'**
  String get shellTodoTitle;

  /// No description provided for @shellTodoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Task progress and history stay visible here.'**
  String get shellTodoSubtitle;

  /// No description provided for @shellToolsTitle.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get shellToolsTitle;

  /// No description provided for @shellToolsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Helpful tools for this workspace.'**
  String get shellToolsSubtitle;

  /// No description provided for @shellTerminalTitle.
  ///
  /// In en, this message translates to:
  /// **'Terminal'**
  String get shellTerminalTitle;

  /// No description provided for @shellTerminalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Quick shell and attach flows land here.'**
  String get shellTerminalSubtitle;

  /// No description provided for @shellInspectorTitle.
  ///
  /// In en, this message translates to:
  /// **'Inspector'**
  String get shellInspectorTitle;

  /// No description provided for @shellConfigTitle.
  ///
  /// In en, this message translates to:
  /// **'Config'**
  String get shellConfigTitle;

  /// No description provided for @shellConfigInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid config'**
  String get shellConfigInvalid;

  /// No description provided for @shellConfigDraftEmpty.
  ///
  /// In en, this message translates to:
  /// **'Config draft is empty.'**
  String get shellConfigDraftEmpty;

  /// No description provided for @shellConfigChangedKeys.
  ///
  /// In en, this message translates to:
  /// **'Changed keys: {count}'**
  String shellConfigChangedKeys(int count);

  /// No description provided for @shellConfigApplying.
  ///
  /// In en, this message translates to:
  /// **'Applying...'**
  String get shellConfigApplying;

  /// No description provided for @shellConfigApplyAction.
  ///
  /// In en, this message translates to:
  /// **'Apply config'**
  String get shellConfigApplyAction;

  /// No description provided for @shellIntegrationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Integrations'**
  String get shellIntegrationsTitle;

  /// No description provided for @shellIntegrationsProviders.
  ///
  /// In en, this message translates to:
  /// **'Providers'**
  String get shellIntegrationsProviders;

  /// No description provided for @shellIntegrationsMethods.
  ///
  /// In en, this message translates to:
  /// **'Methods'**
  String get shellIntegrationsMethods;

  /// No description provided for @shellIntegrationsStartProviderAuth.
  ///
  /// In en, this message translates to:
  /// **'Start provider auth'**
  String get shellIntegrationsStartProviderAuth;

  /// No description provided for @shellIntegrationsMcp.
  ///
  /// In en, this message translates to:
  /// **'MCP'**
  String get shellIntegrationsMcp;

  /// No description provided for @shellIntegrationsStartMcpAuth.
  ///
  /// In en, this message translates to:
  /// **'Start MCP auth'**
  String get shellIntegrationsStartMcpAuth;

  /// No description provided for @shellIntegrationsLsp.
  ///
  /// In en, this message translates to:
  /// **'LSP'**
  String get shellIntegrationsLsp;

  /// No description provided for @shellIntegrationsFormatter.
  ///
  /// In en, this message translates to:
  /// **'Formatter'**
  String get shellIntegrationsFormatter;

  /// No description provided for @shellIntegrationsEnabled.
  ///
  /// In en, this message translates to:
  /// **'enabled'**
  String get shellIntegrationsEnabled;

  /// No description provided for @shellIntegrationsDisabled.
  ///
  /// In en, this message translates to:
  /// **'disabled'**
  String get shellIntegrationsDisabled;

  /// No description provided for @shellIntegrationsRecentEvents.
  ///
  /// In en, this message translates to:
  /// **'Recent events'**
  String get shellIntegrationsRecentEvents;

  /// No description provided for @shellIntegrationsStreamHealth.
  ///
  /// In en, this message translates to:
  /// **'Stream health'**
  String get shellIntegrationsStreamHealth;

  /// No description provided for @shellIntegrationsRecoveryLog.
  ///
  /// In en, this message translates to:
  /// **'Recovery log'**
  String get shellIntegrationsRecoveryLog;

  /// No description provided for @shellWorkspaceEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Workspace'**
  String get shellWorkspaceEyebrow;

  /// No description provided for @shellSessionsEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get shellSessionsEyebrow;

  /// No description provided for @shellControlsEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Controls'**
  String get shellControlsEyebrow;

  /// No description provided for @shellActionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get shellActionsTitle;

  /// No description provided for @shellActionFork.
  ///
  /// In en, this message translates to:
  /// **'Fork'**
  String get shellActionFork;

  /// No description provided for @shellActionShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get shellActionShare;

  /// No description provided for @shellActionUnshare.
  ///
  /// In en, this message translates to:
  /// **'Unshare'**
  String get shellActionUnshare;

  /// No description provided for @shellActionRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get shellActionRename;

  /// No description provided for @shellActionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get shellActionDelete;

  /// No description provided for @shellActionAbort.
  ///
  /// In en, this message translates to:
  /// **'Abort'**
  String get shellActionAbort;

  /// No description provided for @shellActionRevert.
  ///
  /// In en, this message translates to:
  /// **'Revert'**
  String get shellActionRevert;

  /// No description provided for @shellActionUnrevert.
  ///
  /// In en, this message translates to:
  /// **'Unrevert'**
  String get shellActionUnrevert;

  /// No description provided for @shellActionInit.
  ///
  /// In en, this message translates to:
  /// **'Initialize'**
  String get shellActionInit;

  /// No description provided for @shellActionSummarize.
  ///
  /// In en, this message translates to:
  /// **'Summarize'**
  String get shellActionSummarize;

  /// No description provided for @shellPrimaryEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Primary'**
  String get shellPrimaryEyebrow;

  /// No description provided for @shellTimelineEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get shellTimelineEyebrow;

  /// No description provided for @shellFocusedThreadEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Focused thread'**
  String get shellFocusedThreadEyebrow;

  /// No description provided for @shellNewSessionDraft.
  ///
  /// In en, this message translates to:
  /// **'New session draft'**
  String get shellNewSessionDraft;

  /// No description provided for @shellTimelinePartsInFocus.
  ///
  /// In en, this message translates to:
  /// **'{count} timeline parts in focus'**
  String shellTimelinePartsInFocus(int count);

  /// No description provided for @shellReadyToStart.
  ///
  /// In en, this message translates to:
  /// **'Ready to start'**
  String get shellReadyToStart;

  /// No description provided for @shellLiveContext.
  ///
  /// In en, this message translates to:
  /// **'Live context'**
  String get shellLiveContext;

  /// No description provided for @shellPartsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} parts'**
  String shellPartsCount(int count);

  /// No description provided for @shellFocusedThreadSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Focused on the active thread'**
  String get shellFocusedThreadSubtitle;

  /// No description provided for @shellConversationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Centered for longer-form reading and reply composition'**
  String get shellConversationSubtitle;

  /// No description provided for @shellConnectionIssueTitle.
  ///
  /// In en, this message translates to:
  /// **'Connection issue'**
  String get shellConnectionIssueTitle;

  /// No description provided for @shellUtilitiesEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Utilities'**
  String get shellUtilitiesEyebrow;

  /// No description provided for @shellFilesSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search files, text, or symbols'**
  String get shellFilesSearchHint;

  /// No description provided for @shellPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get shellPreviewTitle;

  /// No description provided for @shellCurrentSelection.
  ///
  /// In en, this message translates to:
  /// **'Current selection'**
  String get shellCurrentSelection;

  /// No description provided for @shellMatchesTitle.
  ///
  /// In en, this message translates to:
  /// **'Matches'**
  String get shellMatchesTitle;

  /// No description provided for @shellMatchesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Relevant text results'**
  String get shellMatchesSubtitle;

  /// No description provided for @shellSymbolsTitle.
  ///
  /// In en, this message translates to:
  /// **'Symbols'**
  String get shellSymbolsTitle;

  /// No description provided for @shellSymbolsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Quick code landmarks'**
  String get shellSymbolsSubtitle;

  /// No description provided for @shellTerminalHint.
  ///
  /// In en, this message translates to:
  /// **'pwd'**
  String get shellTerminalHint;

  /// No description provided for @shellTerminalRunAction.
  ///
  /// In en, this message translates to:
  /// **'Run command'**
  String get shellTerminalRunAction;

  /// No description provided for @shellTerminalRunning.
  ///
  /// In en, this message translates to:
  /// **'Running...'**
  String get shellTerminalRunning;

  /// No description provided for @shellTrackedLabel.
  ///
  /// In en, this message translates to:
  /// **'tracked'**
  String get shellTrackedLabel;

  /// No description provided for @shellPendingApprovalsTitle.
  ///
  /// In en, this message translates to:
  /// **'Pending approvals'**
  String get shellPendingApprovalsTitle;

  /// No description provided for @shellPendingApprovalsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{count} items awaiting input'**
  String shellPendingApprovalsSubtitle(int count);

  /// No description provided for @shellAllowOnceAction.
  ///
  /// In en, this message translates to:
  /// **'Allow once'**
  String get shellAllowOnceAction;

  /// No description provided for @shellRejectAction.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get shellRejectAction;

  /// No description provided for @shellAnswerAction.
  ///
  /// In en, this message translates to:
  /// **'Answer'**
  String get shellAnswerAction;

  /// No description provided for @shellConfigPreviewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Review and edit configuration'**
  String get shellConfigPreviewSubtitle;

  /// No description provided for @shellInspectorSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Session and message metadata snapshot'**
  String get shellInspectorSubtitle;

  /// No description provided for @shellIntegrationsLspSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Language server readiness'**
  String get shellIntegrationsLspSubtitle;

  /// No description provided for @shellIntegrationsFormatterSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Formatting availability'**
  String get shellIntegrationsFormatterSubtitle;

  /// No description provided for @shellActionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Session controls and lifecycle actions'**
  String get shellActionsSubtitle;

  /// No description provided for @shellActiveCount.
  ///
  /// In en, this message translates to:
  /// **'{count} active'**
  String shellActiveCount(int count);

  /// No description provided for @shellThreadsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} threads across the current project'**
  String shellThreadsCount(int count);

  /// No description provided for @chatPartAssistant.
  ///
  /// In en, this message translates to:
  /// **'Assistant'**
  String get chatPartAssistant;

  /// No description provided for @chatPartUser.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get chatPartUser;

  /// No description provided for @chatPartThinking.
  ///
  /// In en, this message translates to:
  /// **'Thinking'**
  String get chatPartThinking;

  /// No description provided for @chatPartTool.
  ///
  /// In en, this message translates to:
  /// **'Tool'**
  String get chatPartTool;

  /// No description provided for @chatPartToolNamed.
  ///
  /// In en, this message translates to:
  /// **'Tool: {name}'**
  String chatPartToolNamed(String name);

  /// No description provided for @chatPartFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get chatPartFile;

  /// No description provided for @chatPartStepStart.
  ///
  /// In en, this message translates to:
  /// **'Step start'**
  String get chatPartStepStart;

  /// No description provided for @chatPartStepFinish.
  ///
  /// In en, this message translates to:
  /// **'Step finish'**
  String get chatPartStepFinish;

  /// No description provided for @chatPartSnapshot.
  ///
  /// In en, this message translates to:
  /// **'Snapshot'**
  String get chatPartSnapshot;

  /// No description provided for @chatPartPatch.
  ///
  /// In en, this message translates to:
  /// **'Patch'**
  String get chatPartPatch;

  /// No description provided for @chatPartRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get chatPartRetry;

  /// No description provided for @chatPartAgent.
  ///
  /// In en, this message translates to:
  /// **'Agent'**
  String get chatPartAgent;

  /// No description provided for @chatPartSubtask.
  ///
  /// In en, this message translates to:
  /// **'Subtask'**
  String get chatPartSubtask;

  /// No description provided for @chatPartCompaction.
  ///
  /// In en, this message translates to:
  /// **'Compaction'**
  String get chatPartCompaction;

  /// No description provided for @shellUtilitiesToggleTitle.
  ///
  /// In en, this message translates to:
  /// **'Utilities drawer'**
  String get shellUtilitiesToggleTitle;

  /// No description provided for @shellUtilitiesToggleBody.
  ///
  /// In en, this message translates to:
  /// **'Open the bottom utility drawer to inspect files, diff, todo, tools, and terminal panels on portrait layouts.'**
  String get shellUtilitiesToggleBody;

  /// No description provided for @shellUtilitiesToggleBodyCompact.
  ///
  /// In en, this message translates to:
  /// **'Open utilities to switch between files, diff, todo, tools, and terminal panels.'**
  String get shellUtilitiesToggleBodyCompact;

  /// No description provided for @shellContextEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Context'**
  String get shellContextEyebrow;

  /// No description provided for @shellSecondaryContextSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Secondary context for the active conversation'**
  String get shellSecondaryContextSubtitle;

  /// No description provided for @shellSupportRailsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Support rails for files, tasks, commands, and integrations'**
  String get shellSupportRailsSubtitle;

  /// No description provided for @shellModulesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} modules'**
  String shellModulesCount(int count);

  /// No description provided for @shellSwipeUtilitiesIntoView.
  ///
  /// In en, this message translates to:
  /// **'Swipe utilities into view'**
  String get shellSwipeUtilitiesIntoView;

  /// No description provided for @shellOpenUtilityRail.
  ///
  /// In en, this message translates to:
  /// **'Open the utility rail'**
  String get shellOpenUtilityRail;

  /// No description provided for @shellOpenCodeRemote.
  ///
  /// In en, this message translates to:
  /// **'OpenCode remote'**
  String get shellOpenCodeRemote;

  /// No description provided for @shellContextNearby.
  ///
  /// In en, this message translates to:
  /// **'Context nearby'**
  String get shellContextNearby;

  /// No description provided for @shellShownCount.
  ///
  /// In en, this message translates to:
  /// **'{count} shown'**
  String shellShownCount(int count);

  /// No description provided for @shellSymbolFallback.
  ///
  /// In en, this message translates to:
  /// **'symbol'**
  String get shellSymbolFallback;

  /// No description provided for @shellFileStatusSummary.
  ///
  /// In en, this message translates to:
  /// **'{status} +{added} -{removed}'**
  String shellFileStatusSummary(String status, int added, int removed);

  /// No description provided for @shellNewSession.
  ///
  /// In en, this message translates to:
  /// **'New session'**
  String get shellNewSession;

  /// No description provided for @shellReplying.
  ///
  /// In en, this message translates to:
  /// **'Replying'**
  String get shellReplying;

  /// No description provided for @shellCompactComposer.
  ///
  /// In en, this message translates to:
  /// **'Compact composer'**
  String get shellCompactComposer;

  /// No description provided for @shellExpandedComposer.
  ///
  /// In en, this message translates to:
  /// **'Expanded composer'**
  String get shellExpandedComposer;

  /// No description provided for @shellRetryAttempt.
  ///
  /// In en, this message translates to:
  /// **'attempt {count}'**
  String shellRetryAttempt(int count);

  /// No description provided for @shellStatusWithDetails.
  ///
  /// In en, this message translates to:
  /// **'{status} - {details}'**
  String shellStatusWithDetails(String status, String details);

  /// No description provided for @shellTodoStatusInProgress.
  ///
  /// In en, this message translates to:
  /// **'in progress'**
  String get shellTodoStatusInProgress;

  /// No description provided for @shellTodoStatusPending.
  ///
  /// In en, this message translates to:
  /// **'pending'**
  String get shellTodoStatusPending;

  /// No description provided for @shellTodoStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'completed'**
  String get shellTodoStatusCompleted;

  /// No description provided for @shellTodoStatusUnknown.
  ///
  /// In en, this message translates to:
  /// **'unknown'**
  String get shellTodoStatusUnknown;

  /// No description provided for @shellQuestionAskedNotification.
  ///
  /// In en, this message translates to:
  /// **'Question requested'**
  String get shellQuestionAskedNotification;

  /// No description provided for @shellPermissionAskedNotification.
  ///
  /// In en, this message translates to:
  /// **'Permission requested'**
  String get shellPermissionAskedNotification;

  /// No description provided for @shellNotificationOpenAction.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get shellNotificationOpenAction;

  /// No description provided for @chatPartUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown part: {type}'**
  String chatPartUnknown(String type);
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
