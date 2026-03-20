// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'OpenCode Remote';

  @override
  String get foundationTitle => 'Foundation workspace';

  @override
  String get foundationSubtitle =>
      'Built-in checks and live updates are ready before you connect a server.';

  @override
  String get currentFlavor => 'Flavor';

  @override
  String get currentLocale => 'Locale';

  @override
  String get fullCapabilityProbe => 'Full server check';

  @override
  String get legacyCapabilityProbe => 'Compatibility check';

  @override
  String get probeErrorCapability => 'Check error handling';

  @override
  String get healthyStream => 'Healthy stream';

  @override
  String get staleStream => 'Stale stream recovery';

  @override
  String get duplicateStream => 'Duplicate event handling';

  @override
  String get resyncStream => 'Resync required';

  @override
  String get capabilityFlags => 'Capability flags';

  @override
  String get streamFrames => 'Stream frames';

  @override
  String get unknownFields => 'Unknown fields preserved';

  @override
  String get switchLocale => 'Switch locale';

  @override
  String get cacheSettingsAction => 'Cache settings';

  @override
  String get cacheSettingsTitle => 'Cache settings';

  @override
  String get cacheSettingsSubtitle =>
      'Adjust cache freshness and clear stored connection checks and workspace snapshots.';

  @override
  String get cacheTtlLabel => 'Cache freshness';

  @override
  String get cacheClearAction => 'Clear cached data';

  @override
  String get cacheClearingAction => 'Clearing cache...';

  @override
  String get cacheTtl15Seconds => '15 seconds';

  @override
  String get cacheTtl1Minute => '1 minute';

  @override
  String get cacheTtl5Minutes => '5 minutes';

  @override
  String get cacheTtl15Minutes => '15 minutes';

  @override
  String get connectionTitle => 'Server connection manager';

  @override
  String get connectionSubtitle =>
      'Store trusted OpenCode servers, run a server check when needed, and return to home to choose projects.';

  @override
  String get serverProfileManager => 'Server profile manager';

  @override
  String get connectionProfileHint =>
      'Use saved profiles for trusted hosts and recent attempts for fast retries.';

  @override
  String get profileLabel => 'Profile label';

  @override
  String get serverAddress => 'Server address';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get testingConnection => 'Testing...';

  @override
  String get testConnection => 'Test connection';

  @override
  String get saveProfile => 'Save profile';

  @override
  String get deleteProfile => 'Delete profile';

  @override
  String get connectionGuidance =>
      'Server check confirms health, compatibility, sign-in, provider access, and tool availability. More network discovery options are coming.';

  @override
  String get savedServers => 'Saved servers';

  @override
  String get recentConnections => 'Recent connections';

  @override
  String get noSavedServers => 'No saved servers yet.';

  @override
  String get noRecentConnections => 'No recent attempts yet.';

  @override
  String get connectionDiagnostics => 'Connection diagnostics';

  @override
  String get connectionDiagnosticsHint =>
      'Run a server check to confirm sign-in and compatibility before opening a workspace.';

  @override
  String get serverVersion => 'Version';

  @override
  String get sseStatus => 'Live updates';

  @override
  String get readyStatus => 'ready';

  @override
  String get needsAttentionStatus => 'needs attention';

  @override
  String get connectionEmptyState =>
      'Enter a server profile and run a server check to populate diagnostics.';

  @override
  String get connectionHeaderEyebrow => 'Live server connection';

  @override
  String get connectionHeaderTitle => 'Connect a real OpenCode server';

  @override
  String get connectionHeaderSubtitle =>
      'Review saved server details, verify sign-in, and return to workspace home once this server is ready.';

  @override
  String get connectionStatusAwaiting => 'Awaiting first check';

  @override
  String get connectionFormTitle => 'Server profile manager';

  @override
  String get connectionFormSubtitle =>
      'Update saved server details, retry a check, and keep this profile ready for home.';

  @override
  String get savedProfilesCountLabel => 'saved';

  @override
  String get recentConnectionsCountLabel => 'recent';

  @override
  String get sseReadyLabel => 'Live updates ready';

  @override
  String get ssePendingLabel => 'Check pending';

  @override
  String get connectionProfileLabel => 'Profile name';

  @override
  String get connectionProfileLabelHint =>
      'Studio staging, laptop tunnel, on-prem gateway';

  @override
  String get connectionAddressLabel => 'Server address';

  @override
  String get connectionAddressHint => 'https://opencode.example.com';

  @override
  String get connectionUsernameLabel => 'Basic auth username';

  @override
  String get connectionUsernameHint => 'Optional';

  @override
  String get connectionPasswordLabel => 'Basic auth password';

  @override
  String get connectionPasswordHint => 'Optional';

  @override
  String get connectionAddressValidation => 'Enter a valid server address.';

  @override
  String get connectionBackHomeAction => 'Back to home';

  @override
  String get connectionProbeAction => 'Check server';

  @override
  String get connectionSaveAction => 'Save profile';

  @override
  String get connectionDraftRestoredLabel => 'Restored unsaved draft';

  @override
  String get connectionPinProfileAction => 'Pin profile';

  @override
  String get connectionUnpinProfileAction => 'Unpin profile';

  @override
  String get connectionProbeResultTitle => 'Server check';

  @override
  String get connectionProbeResultSubtitle =>
      'Use this detail view to confirm whether the saved server still responds. Project selection happens from workspace home.';

  @override
  String get connectionProbeEmptyTitle => 'No recent check yet';

  @override
  String get connectionProbeEmptySubtitle =>
      'Run a server check to confirm sign-in and compatibility before returning to workspace home.';

  @override
  String get connectionVersionLabel => 'Version';

  @override
  String get connectionCheckedAtLabel => 'Checked';

  @override
  String get connectionCapabilitiesLabel => 'Capabilities enabled';

  @override
  String get connectionReadinessLabel => 'Readiness';

  @override
  String get connectionMissingCapabilitiesLabel => 'Missing required features';

  @override
  String get connectionExperimentalPathsLabel => 'Advanced tools';

  @override
  String get connectionEndpointSectionTitle => 'Check results';

  @override
  String get connectionCapabilitySectionTitle => 'Capabilities';

  @override
  String get savedProfilesTitle => 'Saved profiles';

  @override
  String get savedProfilesSubtitle =>
      'Pinned servers stay ready for quick checks.';

  @override
  String get savedProfilesEmptyTitle => 'No saved profiles yet';

  @override
  String get savedProfilesEmptySubtitle =>
      'Save a working address so the app opens with a known server target next time.';

  @override
  String get recentConnectionsTitle => 'Recent attempts';

  @override
  String get recentConnectionsSubtitle =>
      'Recent server checks, kept separate from pinned servers.';

  @override
  String get recentConnectionsEmptyTitle => 'No recent attempts yet';

  @override
  String get recentConnectionsEmptySubtitle =>
      'Check a server and the latest outcome will stay here for quick retry.';

  @override
  String get connectionOutcomeReady => 'Ready for connection';

  @override
  String get connectionOutcomeAuthFailure => 'Auth failure';

  @override
  String get connectionOutcomeSpecFailure => 'Spec fetch failure';

  @override
  String get connectionOutcomeUnsupported => 'Unsupported capability set';

  @override
  String get connectionOutcomeConnectivityFailure => 'Connectivity failure';

  @override
  String get connectionDetailReady =>
      'Core services responded and home can now offer project choices.';

  @override
  String get connectionDetailAuthFailure =>
      'The server responded, but the provided sign-in details were rejected.';

  @override
  String get connectionDetailBasicAuthFailure =>
      'This server is protected by Basic auth. Add or update the username and password, then try again.';

  @override
  String get connectionDetailSpecFailure =>
      'The server is reachable, but the OpenAPI spec could not be fetched or parsed cleanly.';

  @override
  String get connectionDetailUnsupported =>
      'The server is reachable, but required features for this app are still missing.';

  @override
  String get connectionDetailConnectivityFailure =>
      'The server could not be reached reliably enough to complete the check.';

  @override
  String get endpointReadyStatus => 'ready';

  @override
  String get endpointAuthStatus => 'auth';

  @override
  String get endpointUnsupportedStatus => 'unsupported';

  @override
  String get endpointFailureStatus => 'failure';

  @override
  String get endpointUnknownStatus => 'unknown';

  @override
  String get fixtureDiagnosticsTitle => 'Diagnostics';

  @override
  String get fixtureDiagnosticsSubtitle =>
      'Connection checks and status details live here.';

  @override
  String get capabilityCanShareSession => 'Share session';

  @override
  String get capabilityCanForkSession => 'Fork session';

  @override
  String get capabilityCanSummarizeSession => 'Summarize session';

  @override
  String get capabilityCanRevertSession => 'Revert session';

  @override
  String get capabilityHasQuestions => 'Questions';

  @override
  String get capabilityHasPermissions => 'Permissions';

  @override
  String get capabilityHasExperimentalTools => 'Advanced tools';

  @override
  String get capabilityHasProviderOAuth => 'Provider OAuth';

  @override
  String get capabilityHasMcpAuth => 'MCP auth';

  @override
  String get capabilityHasTuiControl => 'TUI control';

  @override
  String get projectSelectionTitle => 'Choose a project';

  @override
  String get projectSelectionSubtitle =>
      'Open a project from this server, your recent work, or a folder path.';

  @override
  String get currentProjectTitle => 'Current project';

  @override
  String get currentProjectSubtitle =>
      'If the server is already inside a project, it appears here first.';

  @override
  String get serverProjectsTitle => 'Projects on this server';

  @override
  String get serverProjectsSubtitle =>
      'Other projects the server can open right now.';

  @override
  String get serverProjectsEmpty =>
      'No server projects are available right now. You can still open a recent project or folder path.';

  @override
  String get manualProjectTitle => 'Open a folder path';

  @override
  String get manualProjectSubtitle =>
      'Use this when the server list is empty or you know exactly which folder you want.';

  @override
  String get manualProjectPathLabel => 'Project directory';

  @override
  String get manualProjectPathHint => '/workspace/my-project';

  @override
  String get projectInspectAction => 'Inspect path';

  @override
  String get projectInspectingAction => 'Inspecting...';

  @override
  String get projectBrowseAction => 'Browse folder';

  @override
  String get recentProjectsTitle => 'Recent projects';

  @override
  String get recentProjectsSubtitle =>
      'Projects you\'ve opened recently, with last session hints when we have them.';

  @override
  String get pinnedProjectsTitle => 'Pinned projects';

  @override
  String get pinnedProjectsSubtitle =>
      'Local favorites kept at the top for quick mobile access.';

  @override
  String get recentProjectsEmpty => 'No recent projects yet.';

  @override
  String get projectPreviewTitle => 'Project details';

  @override
  String get projectPreviewSubtitle =>
      'Review the next workspace before you open it.';

  @override
  String get projectPreviewEmpty =>
      'Select a project, recent workspace, or folder path to see details here.';

  @override
  String get projectDirectoryLabel => 'Directory';

  @override
  String get projectSourceLabel => 'Source';

  @override
  String get projectVcsLabel => 'VCS';

  @override
  String get projectBranchLabel => 'Branch';

  @override
  String get projectLastSessionLabel => 'Last session';

  @override
  String get projectLastStatusLabel => 'Last status';

  @override
  String get projectLastSessionUnknown => 'Not captured yet';

  @override
  String get projectLastStatusUnknown => 'Not captured yet';

  @override
  String get projectSelectionReadyHint =>
      'Open this project to continue into its sessions.';

  @override
  String get homeHeaderEyebrow => 'Workspace';

  @override
  String get homeHeaderSubtitle =>
      'Connect a server, then open a project and continue your sessions.';

  @override
  String get homeAddServerAction => 'Add server';

  @override
  String get homeBackToServersAction => 'Back to servers';

  @override
  String get homeEditSelectedServerAction => 'Edit selected server';

  @override
  String get homeEditServerAction => 'Edit server';

  @override
  String get homeSwitchServerAction => 'Switch server';

  @override
  String get homeNextStepsTitle => 'Next steps';

  @override
  String get homeNextStepsPinnedServers =>
      'Pin the servers you use most, so they stay at the top.';

  @override
  String get homeNextStepsProjects =>
      'Once a server is ready, open a project and jump into sessions.';

  @override
  String get homeNextStepsRetryEdit =>
      'Retry or edit a server without leaving home.';

  @override
  String get homeMetricSavedServers => 'Saved servers';

  @override
  String get homeMetricRecentActivity => 'Recent activity';

  @override
  String get homeMetricCurrentFocus => 'Current server';

  @override
  String get homeChooseServerLabel => 'Choose a server';

  @override
  String get homeResumeLastWorkspaceTitle => 'Resume last workspace';

  @override
  String get homeOpenLastProjectTitle => 'Open last project';

  @override
  String homeResumeLastWorkspaceBody(String project) {
    return 'Continue in $project and pick up where you left off.';
  }

  @override
  String homeOpenLastProjectBody(String project) {
    return 'Open $project, then choose a session or start a new one.';
  }

  @override
  String get homeResumeLastWorkspaceAction => 'Resume workspace';

  @override
  String get homeOpenLastProjectAction => 'Open project';

  @override
  String get homeResumeMetricProject => 'Project';

  @override
  String get homeResumeMetricLastSession => 'Last session';

  @override
  String get homeResumeMetricStatus => 'Status';

  @override
  String get homeActionCheckingWorkspace => 'Checking workspace...';

  @override
  String get homeActionContinue => 'Continue';

  @override
  String get homeActionRetry => 'Retry';

  @override
  String get homeActionCheckingServer => 'Checking server...';

  @override
  String get homeThisServerLabel => 'This server';

  @override
  String get homeWorkspaceSectionTitle => 'Projects and sessions';

  @override
  String get homeWorkspaceLoadingSubtitle =>
      'Loading your saved servers and recent activity.';

  @override
  String get homeWorkspaceEmptySubtitle =>
      'Add a server to start opening projects and sessions here.';

  @override
  String get homeWorkspaceFeatureSaveTitle => 'Save a server once';

  @override
  String get homeWorkspaceFeatureSaveBody =>
      'Keep servers in one place, ready when you come back.';

  @override
  String get homeWorkspaceFeatureChooseTitle => 'Open a project next';

  @override
  String get homeWorkspaceFeatureChooseBody =>
      'When the server is ready, choose a project and continue.';

  @override
  String get homeWorkspaceFeatureRecentTitle => 'Keep recents in view';

  @override
  String get homeWorkspaceFeatureRecentBody =>
      'Saved servers and recent checks stay together on one screen.';

  @override
  String get homeWorkspaceSubtitleReady => 'Choose a project to continue.';

  @override
  String get homeWorkspaceSubtitleSignIn =>
      'Update sign-in details or retry before projects can load.';

  @override
  String get homeWorkspaceSubtitleOffline =>
      'Retry this server or confirm the saved address.';

  @override
  String get homeWorkspaceSubtitleUpdate =>
      'Update the server before projects can load.';

  @override
  String get homeWorkspaceSubtitleUnknown =>
      'Run a quick check before loading projects.';

  @override
  String get homeWorkspaceTitleChooseServer => 'Choose a saved server';

  @override
  String homeWorkspaceTitleChecking(String server) {
    return 'Checking $server';
  }

  @override
  String get homeWorkspaceTitleReady => 'Ready for projects';

  @override
  String get homeWorkspaceTitleSignInRequired => 'Sign-in required';

  @override
  String get homeWorkspaceTitleOffline => 'Offline';

  @override
  String get homeWorkspaceTitleUpdate => 'Update required';

  @override
  String get homeWorkspaceTitleContinueFromHome => 'Continue from home';

  @override
  String get homeWorkspaceBodyChecking =>
      'Checking sign-in and compatibility before loading projects and sessions.';

  @override
  String homeWorkspaceBodyReady(String server) {
    return '$server is ready, but the project list is still loading.';
  }

  @override
  String homeWorkspaceBodySignInRequired(String server) {
    return '$server responded, but sign-in details need attention before projects can load.';
  }

  @override
  String homeWorkspaceBodyBasicAuthRequired(String server) {
    return '$server is protected by Basic auth. Edit this server and add the username and password before loading projects.';
  }

  @override
  String homeWorkspaceBodyOffline(String server) {
    return 'Couldn\'t reach $server just now. Retry, or edit the saved address if it changed.';
  }

  @override
  String homeWorkspaceBodyUpdateRequired(String server) {
    return '$server responded, but it needs an update before projects can load.';
  }

  @override
  String get homeWorkspaceBodyUnknown =>
      'Run a quick check, then edit details only if sign-in or the address needs attention.';

  @override
  String get homeNoticeWorkspaceUnavailable =>
      'Your last workspace is no longer available. Choose a project to continue.';

  @override
  String get homeNoticeWorkspaceResumeFailed =>
      'Couldn\'t reopen your last workspace right now. Choose a project below or retry this server.';

  @override
  String get homeSavedServersTitle => 'Saved servers';

  @override
  String get homeSavedServersSubtitle =>
      'Pick a server, then continue into projects and sessions.';

  @override
  String get homeSavedServersEmptyTitle => 'No saved servers yet';

  @override
  String get homeSavedServersEmptySubtitle =>
      'Add your first server to start opening projects and sessions.';

  @override
  String get homeRecentActivityTitle => 'Recent activity';

  @override
  String get homeRecentActivitySubtitle =>
      'A quick record of the servers you checked most recently.';

  @override
  String get homeRecentActivityEmptyTitle => 'No recent activity yet';

  @override
  String get homeRecentActivityEmptySubtitle =>
      'Recent checks show up here after you connect or retry a server.';

  @override
  String get homeRecentActivityNotUsed => 'Not used yet';

  @override
  String homeRecentActivityLastUsed(String timestamp) {
    return 'Last used $timestamp';
  }

  @override
  String get homeCredentialsSaved => 'Credentials saved';

  @override
  String get homeCredentialsMissing => 'No credentials saved';

  @override
  String get homeServerCardBodyReady =>
      'Ready to open projects and sessions from home.';

  @override
  String get homeServerCardBodySignIn =>
      'Retry, or update sign-in details before projects can load.';

  @override
  String get homeServerCardBodyBasicAuthRequired =>
      'Basic auth is required before this server can load projects.';

  @override
  String get homeServerCardBodyOffline =>
      'Retry, or edit the saved address before continuing.';

  @override
  String get homeServerCardBodyUpdate =>
      'Update the server before continuing into projects and sessions.';

  @override
  String get homeServerCardBodyUnknownWithAuth =>
      'Run a quick check before loading projects.';

  @override
  String get homeServerCardBodyUnknown =>
      'Run a quick check, then edit details only if sign-in is needed.';

  @override
  String get homeStatusNewHome => 'New home';

  @override
  String get homeStatusChooseServer => 'Choose a server';

  @override
  String get homeStatusCheckingServer => 'Checking server';

  @override
  String get homeStatusReadyForProjects => 'Ready for projects';

  @override
  String get homeStatusSignInRequired => 'Sign-in required';

  @override
  String get homeStatusServerOffline => 'Server offline';

  @override
  String get homeStatusNeedsAttention => 'Needs attention';

  @override
  String get homeStatusAwaitingSetup => 'Awaiting setup';

  @override
  String get homeHeroTitleNoServers => 'Start with a server';

  @override
  String get homeHeroTitleOneServer => 'Your server, ready to go';

  @override
  String get homeHeroTitleManyServers => 'All your servers in one place';

  @override
  String get homeHeroBodyNoServers =>
      'Add a server once, then return here to open projects and continue sessions.';

  @override
  String get homeHeroBodyOneServer =>
      'Continue from home, and only open server details when something changes.';

  @override
  String get homeHeroBodyManyServers =>
      'Pick a server, keep recents in view, and run a quick check when needed.';

  @override
  String get homeA11yAddServerAction => 'Add server';

  @override
  String get homeA11yBackToServersAction => 'Back to server selection';

  @override
  String get homeA11yEditSelectedServerAction => 'Edit selected server';

  @override
  String get homeA11yWorkspacePrimaryAction => 'Workspace primary action';

  @override
  String get homeA11yEditServerAction => 'Edit server';

  @override
  String get homeA11ySwitchServerAction => 'Switch server';

  @override
  String get homeA11yResumeWorkspaceAction => 'Resume workspace';

  @override
  String get homeStatusShortReady => 'Ready';

  @override
  String get homeStatusShortSignInRequired => 'Sign-in required';

  @override
  String get homeStatusShortOffline => 'Offline';

  @override
  String get homeStatusShortNeedsAttention => 'Needs attention';

  @override
  String get homeStatusShortNotCheckedYet => 'Not checked yet';

  @override
  String get projectCatalogUnavailableTitle => 'Project list unavailable';

  @override
  String get projectCatalogUnavailableBody =>
      'We couldn\'t load this server\'s project list just now. You can still open a recent workspace or enter a folder path.';

  @override
  String get projectOpenAction => 'Open project';

  @override
  String get projectPinAction => 'Pin project';

  @override
  String get projectUnpinAction => 'Unpin project';

  @override
  String get shellProjectRailTitle => 'Project and sessions';

  @override
  String get shellDestinationSessions => 'Sessions';

  @override
  String get shellDestinationChat => 'Chat';

  @override
  String get shellDestinationContext => 'Context';

  @override
  String get shellDestinationSettings => 'Settings';

  @override
  String get shellAdvancedLabel => 'Advanced';

  @override
  String get shellAdvancedSubtitle =>
      'Advanced settings and troubleshooting tools.';

  @override
  String get shellAdvancedOverviewSubtitle =>
      'Technical options kept out of the main flow.';

  @override
  String get shellOpenAdvancedAction => 'Open advanced';

  @override
  String get shellBackToSettingsAction => 'Back to settings';

  @override
  String get shellA11yOpenCacheSettings => 'Open cache settings';

  @override
  String get shellA11yOpenAdvanced => 'Open advanced settings';

  @override
  String get shellA11yBackToSettings => 'Back to settings';

  @override
  String get shellA11yBackToProjectsAction => 'Back to projects';

  @override
  String get shellA11yComposerField => 'Message field';

  @override
  String get shellA11ySendMessageAction => 'Send message';

  @override
  String get shellIntegrationsLastAuthUrlTitle => 'Last authorization URL';

  @override
  String get shellIntegrationsEventsSubtitle =>
      'Event stream status and recovery details.';

  @override
  String get shellStreamHealthConnected => 'Connected';

  @override
  String get shellStreamHealthStale => 'Stale';

  @override
  String get shellStreamHealthReconnecting => 'Reconnecting';

  @override
  String get shellConfigPreviewUnavailable =>
      'Configuration view is unavailable right now.';

  @override
  String get shellNoticeLastSessionUnavailable =>
      'Your last session is no longer available. Choose another session or start a new one.';

  @override
  String get shellConfigJsonObjectError => 'Config must be a JSON object.';

  @override
  String get shellRecoveryLogReconnectRequested => 'Reconnect requested';

  @override
  String get shellRecoveryLogReconnectCompleted => 'Reconnect completed';

  @override
  String get shellUnknownLabel => 'unknown';

  @override
  String get shellBackToProjectsAction => 'Back to projects';

  @override
  String get shellSessionsTitle => 'Sessions';

  @override
  String get shellSessionCurrent => 'Current session';

  @override
  String get shellSessionDraft => 'Draft branch';

  @override
  String get shellSessionReview => 'Review branch';

  @override
  String get shellStatusActive => 'active';

  @override
  String get shellStatusIdle => 'idle';

  @override
  String get shellStatusError => 'error';

  @override
  String get shellChatHeaderTitle => 'Chat workspace';

  @override
  String get shellThinkingModeLabel => 'Balanced thinking';

  @override
  String get shellAgentLabel => 'Agent';

  @override
  String get shellChatTimelineTitle => 'Conversation';

  @override
  String get shellUserMessageTitle => 'You';

  @override
  String get shellUserMessageBody =>
      'Pick a session, then send a message to get started.';

  @override
  String get shellAssistantMessageTitle => 'OpenCode';

  @override
  String get shellAssistantMessageBody =>
      'You\'re in the workspace. Review context, pick a session, and keep work moving.';

  @override
  String get shellComposerPlaceholder => 'Write a message';

  @override
  String get shellComposerSendAction => 'Send';

  @override
  String get shellComposerCreatingSession => 'Create session and send';

  @override
  String get shellComposerSending => 'Sending...';

  @override
  String get shellRenameSessionTitle => 'Rename session';

  @override
  String get shellSessionTitleHint => 'Session title';

  @override
  String get shellCancelAction => 'Cancel';

  @override
  String get shellSaveAction => 'Save';

  @override
  String get shellContextTitle => 'Context utilities';

  @override
  String get shellFilesTitle => 'Files';

  @override
  String get shellFilesSubtitle => 'Tree, status, and search live here.';

  @override
  String get shellDiffTitle => 'Diff';

  @override
  String get shellDiffSubtitle => 'Patch and snapshot review appear here.';

  @override
  String get shellTodoTitle => 'Todo';

  @override
  String get shellTodoSubtitle =>
      'Task progress and history stay visible here.';

  @override
  String get shellToolsTitle => 'Tools';

  @override
  String get shellToolsSubtitle => 'Helpful tools for this workspace.';

  @override
  String get shellTerminalTitle => 'Terminal';

  @override
  String get shellTerminalSubtitle => 'Quick shell and attach flows land here.';

  @override
  String get shellInspectorTitle => 'Inspector';

  @override
  String get shellConfigTitle => 'Config';

  @override
  String get shellConfigInvalid => 'Invalid config';

  @override
  String get shellConfigDraftEmpty => 'Config draft is empty.';

  @override
  String shellConfigChangedKeys(int count) {
    return 'Changed keys: $count';
  }

  @override
  String get shellConfigApplying => 'Applying...';

  @override
  String get shellConfigApplyAction => 'Apply config';

  @override
  String get shellIntegrationsTitle => 'Integrations';

  @override
  String get shellIntegrationsProviders => 'Providers';

  @override
  String get shellIntegrationsMethods => 'Methods';

  @override
  String get shellIntegrationsStartProviderAuth => 'Start provider auth';

  @override
  String get shellIntegrationsMcp => 'MCP';

  @override
  String get shellIntegrationsStartMcpAuth => 'Start MCP auth';

  @override
  String get shellIntegrationsLsp => 'LSP';

  @override
  String get shellIntegrationsFormatter => 'Formatter';

  @override
  String get shellIntegrationsEnabled => 'enabled';

  @override
  String get shellIntegrationsDisabled => 'disabled';

  @override
  String get shellIntegrationsRecentEvents => 'Recent events';

  @override
  String get shellIntegrationsStreamHealth => 'Stream health';

  @override
  String get shellIntegrationsRecoveryLog => 'Recovery log';

  @override
  String get shellWorkspaceEyebrow => 'Workspace';

  @override
  String get shellSessionsEyebrow => 'Sessions';

  @override
  String get shellControlsEyebrow => 'Controls';

  @override
  String get shellActionsTitle => 'Actions';

  @override
  String get shellActionFork => 'Fork';

  @override
  String get shellActionShare => 'Share';

  @override
  String get shellActionUnshare => 'Unshare';

  @override
  String get shellActionRename => 'Rename';

  @override
  String get shellActionDelete => 'Delete';

  @override
  String get shellActionAbort => 'Abort';

  @override
  String get shellActionRevert => 'Revert';

  @override
  String get shellActionUnrevert => 'Unrevert';

  @override
  String get shellActionInit => 'Initialize';

  @override
  String get shellActionSummarize => 'Summarize';

  @override
  String get shellPrimaryEyebrow => 'Primary';

  @override
  String get shellTimelineEyebrow => 'Timeline';

  @override
  String get shellFocusedThreadEyebrow => 'Focused thread';

  @override
  String get shellNewSessionDraft => 'New session draft';

  @override
  String shellTimelinePartsInFocus(int count) {
    return '$count timeline parts in focus';
  }

  @override
  String get shellReadyToStart => 'Ready to start';

  @override
  String get shellLiveContext => 'Live context';

  @override
  String shellPartsCount(int count) {
    return '$count parts';
  }

  @override
  String get shellFocusedThreadSubtitle => 'Focused on the active thread';

  @override
  String get shellConversationSubtitle =>
      'Centered for longer-form reading and reply composition';

  @override
  String get shellConnectionIssueTitle => 'Connection issue';

  @override
  String get shellUtilitiesEyebrow => 'Utilities';

  @override
  String get shellFilesSearchHint => 'Search files, text, or symbols';

  @override
  String get shellPreviewTitle => 'Preview';

  @override
  String get shellCurrentSelection => 'Current selection';

  @override
  String get shellMatchesTitle => 'Matches';

  @override
  String get shellMatchesSubtitle => 'Relevant text results';

  @override
  String get shellSymbolsTitle => 'Symbols';

  @override
  String get shellSymbolsSubtitle => 'Quick code landmarks';

  @override
  String get shellTerminalHint => 'pwd';

  @override
  String get shellTerminalRunAction => 'Run command';

  @override
  String get shellTerminalRunning => 'Running...';

  @override
  String get shellTrackedLabel => 'tracked';

  @override
  String get shellPendingApprovalsTitle => 'Pending approvals';

  @override
  String shellPendingApprovalsSubtitle(int count) {
    return '$count items awaiting input';
  }

  @override
  String get shellAllowOnceAction => 'Allow once';

  @override
  String get shellRejectAction => 'Reject';

  @override
  String get shellAnswerAction => 'Answer';

  @override
  String get shellConfigPreviewSubtitle => 'Review and edit configuration';

  @override
  String get shellInspectorSubtitle => 'Session and message metadata snapshot';

  @override
  String get shellIntegrationsLspSubtitle => 'Language server readiness';

  @override
  String get shellIntegrationsFormatterSubtitle => 'Formatting availability';

  @override
  String get shellActionsSubtitle => 'Session controls and lifecycle actions';

  @override
  String shellActiveCount(int count) {
    return '$count active';
  }

  @override
  String shellThreadsCount(int count) {
    return '$count threads across the current project';
  }

  @override
  String get chatPartAssistant => 'Assistant';

  @override
  String get chatPartUser => 'User';

  @override
  String get chatPartThinking => 'Thinking';

  @override
  String get chatPartTool => 'Tool';

  @override
  String chatPartToolNamed(String name) {
    return 'Tool: $name';
  }

  @override
  String get chatPartFile => 'File';

  @override
  String get chatPartStepStart => 'Step start';

  @override
  String get chatPartStepFinish => 'Step finish';

  @override
  String get chatPartSnapshot => 'Snapshot';

  @override
  String get chatPartPatch => 'Patch';

  @override
  String get chatPartRetry => 'Retry';

  @override
  String get chatPartAgent => 'Agent';

  @override
  String get chatPartSubtask => 'Subtask';

  @override
  String get chatPartCompaction => 'Compaction';

  @override
  String get shellUtilitiesToggleTitle => 'Utilities drawer';

  @override
  String get shellUtilitiesToggleBody =>
      'Open the bottom utility drawer to inspect files, diff, todo, tools, and terminal panels on portrait layouts.';

  @override
  String get shellUtilitiesToggleBodyCompact =>
      'Open utilities to switch between files, diff, todo, tools, and terminal panels.';

  @override
  String get shellContextEyebrow => 'Context';

  @override
  String get shellSecondaryContextSubtitle =>
      'Secondary context for the active conversation';

  @override
  String get shellSupportRailsSubtitle =>
      'Support rails for files, tasks, commands, and integrations';

  @override
  String shellModulesCount(int count) {
    return '$count modules';
  }

  @override
  String get shellSwipeUtilitiesIntoView => 'Swipe utilities into view';

  @override
  String get shellOpenUtilityRail => 'Open the utility rail';

  @override
  String get shellOpenCodeRemote => 'OpenCode remote';

  @override
  String get shellContextNearby => 'Context nearby';

  @override
  String shellShownCount(int count) {
    return '$count shown';
  }

  @override
  String get shellSymbolFallback => 'symbol';

  @override
  String shellFileStatusSummary(String status, int added, int removed) {
    return '$status +$added -$removed';
  }

  @override
  String get shellNewSession => 'New session';

  @override
  String get shellReplying => 'Replying';

  @override
  String get shellCompactComposer => 'Compact composer';

  @override
  String get shellExpandedComposer => 'Expanded composer';

  @override
  String shellRetryAttempt(int count) {
    return 'attempt $count';
  }

  @override
  String shellStatusWithDetails(String status, String details) {
    return '$status - $details';
  }

  @override
  String get shellTodoStatusInProgress => 'in progress';

  @override
  String get shellTodoStatusPending => 'pending';

  @override
  String get shellTodoStatusCompleted => 'completed';

  @override
  String get shellTodoStatusUnknown => 'unknown';

  @override
  String get shellQuestionAskedNotification => 'Question requested';

  @override
  String get shellPermissionAskedNotification => 'Permission requested';

  @override
  String get shellNotificationOpenAction => 'Open';

  @override
  String chatPartUnknown(String type) {
    return 'Unknown part: $type';
  }
}
