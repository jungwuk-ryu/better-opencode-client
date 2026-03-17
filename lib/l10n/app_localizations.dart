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

  /// No description provided for @connectionHeaderEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Phase 2 · Live server connection'**
  String get connectionHeaderEyebrow;

  /// No description provided for @connectionHeaderTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect a real OpenCode server'**
  String get connectionHeaderTitle;

  /// No description provided for @connectionHeaderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Probe the live spec, verify auth, and keep the next handoff grounded in actual server capability.'**
  String get connectionHeaderSubtitle;

  /// No description provided for @connectionStatusAwaiting.
  ///
  /// In en, this message translates to:
  /// **'Awaiting first probe'**
  String get connectionStatusAwaiting;

  /// No description provided for @connectionFormTitle.
  ///
  /// In en, this message translates to:
  /// **'Server profile manager'**
  String get connectionFormTitle;

  /// No description provided for @connectionFormSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Save known endpoints, retry recent attempts, and verify whether the server is actually ready for this client.'**
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
  /// **'SSE-ready'**
  String get sseReadyLabel;

  /// No description provided for @ssePendingLabel.
  ///
  /// In en, this message translates to:
  /// **'Probe pending'**
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

  /// No description provided for @connectionProbeAction.
  ///
  /// In en, this message translates to:
  /// **'Probe server'**
  String get connectionProbeAction;

  /// No description provided for @connectionSaveAction.
  ///
  /// In en, this message translates to:
  /// **'Save profile'**
  String get connectionSaveAction;

  /// No description provided for @connectionProbeResultTitle.
  ///
  /// In en, this message translates to:
  /// **'Live capability probe'**
  String get connectionProbeResultTitle;

  /// No description provided for @connectionProbeResultSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Each run checks health, spec, config, providers, agents, and experimental tools when the spec exposes them.'**
  String get connectionProbeResultSubtitle;

  /// No description provided for @connectionProbeEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No live probe yet'**
  String get connectionProbeEmptyTitle;

  /// No description provided for @connectionProbeEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Run a probe to classify auth failures, spec fetch issues, unsupported capability gaps, or readiness for the SSE/connectivity layer.'**
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
  /// **'Missing required endpoints'**
  String get connectionMissingCapabilitiesLabel;

  /// No description provided for @connectionExperimentalPathsLabel.
  ///
  /// In en, this message translates to:
  /// **'Experimental tool endpoints'**
  String get connectionExperimentalPathsLabel;

  /// No description provided for @connectionEndpointSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Endpoint outcomes'**
  String get connectionEndpointSectionTitle;

  /// No description provided for @connectionCapabilitySectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Capability registry'**
  String get connectionCapabilitySectionTitle;

  /// No description provided for @savedProfilesTitle.
  ///
  /// In en, this message translates to:
  /// **'Saved profiles'**
  String get savedProfilesTitle;

  /// No description provided for @savedProfilesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pinned connections stay ready for repeat probe cycles.'**
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
  /// **'Last live probes, kept separate from pinned server profiles.'**
  String get recentConnectionsSubtitle;

  /// No description provided for @recentConnectionsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No recent attempts yet'**
  String get recentConnectionsEmptyTitle;

  /// No description provided for @recentConnectionsEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Probe a server and the latest outcome will stay here for quick retry.'**
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
  /// **'Core endpoints responded and the server looks ready for SSE handoff.'**
  String get connectionDetailReady;

  /// No description provided for @connectionDetailAuthFailure.
  ///
  /// In en, this message translates to:
  /// **'The server responded, but at least one core endpoint rejected the supplied credentials.'**
  String get connectionDetailAuthFailure;

  /// No description provided for @connectionDetailSpecFailure.
  ///
  /// In en, this message translates to:
  /// **'The server is reachable, but the OpenAPI spec could not be fetched or parsed cleanly.'**
  String get connectionDetailSpecFailure;

  /// No description provided for @connectionDetailUnsupported.
  ///
  /// In en, this message translates to:
  /// **'The server spec is readable, but required endpoints for this client are still missing.'**
  String get connectionDetailUnsupported;

  /// No description provided for @connectionDetailConnectivityFailure.
  ///
  /// In en, this message translates to:
  /// **'The server could not be reached reliably enough to complete probing.'**
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
  /// **'Fixture diagnostics'**
  String get fixtureDiagnosticsTitle;

  /// No description provided for @fixtureDiagnosticsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The phase 1 manual QA surfaces stay visible here while live connection work comes online.'**
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
  /// **'Experimental tools'**
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
  /// **'Project selection'**
  String get projectSelectionTitle;

  /// No description provided for @projectSelectionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose the active project context from the server\'s current project, server-listed projects, a manual path, or a folder browser.'**
  String get projectSelectionSubtitle;

  /// No description provided for @currentProjectTitle.
  ///
  /// In en, this message translates to:
  /// **'Current project'**
  String get currentProjectTitle;

  /// No description provided for @currentProjectSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The project currently scoped by the connected server instance.'**
  String get currentProjectSubtitle;

  /// No description provided for @serverProjectsTitle.
  ///
  /// In en, this message translates to:
  /// **'Server-listed projects'**
  String get serverProjectsTitle;

  /// No description provided for @serverProjectsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Projects OpenCode already knows about on this server.'**
  String get serverProjectsSubtitle;

  /// No description provided for @serverProjectsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No server-listed projects yet.'**
  String get serverProjectsEmpty;

  /// No description provided for @manualProjectTitle.
  ///
  /// In en, this message translates to:
  /// **'Manual path or folder browser'**
  String get manualProjectTitle;

  /// No description provided for @manualProjectSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use this when search misses a folder or you need to open an exact path.'**
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
  /// **'Recent local project targets kept separately from server-listed projects.'**
  String get recentProjectsSubtitle;

  /// No description provided for @recentProjectsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No recent projects yet.'**
  String get recentProjectsEmpty;

  /// No description provided for @projectPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Project preview'**
  String get projectPreviewTitle;

  /// No description provided for @projectPreviewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Metadata for the next project context before sessions and chat bind to it.'**
  String get projectPreviewSubtitle;

  /// No description provided for @projectPreviewEmpty.
  ///
  /// In en, this message translates to:
  /// **'Select a project from one of the four entry points to preview it here.'**
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
  /// **'This target is ready for the next phase where sessions and chat use the selected project context.'**
  String get projectSelectionReadyHint;
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
