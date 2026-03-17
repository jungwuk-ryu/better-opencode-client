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
  String get foundationTitle => 'Foundation debug workspace';

  @override
  String get foundationSubtitle =>
      'Capability, fixture, and stream foundations are wired before UI parity work.';

  @override
  String get currentFlavor => 'Flavor';

  @override
  String get currentLocale => 'Locale';

  @override
  String get fullCapabilityProbe => 'Full capability probe';

  @override
  String get legacyCapabilityProbe => 'Legacy capability probe';

  @override
  String get probeErrorCapability => 'Probe error handling';

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
  String get connectionTitle => 'Server connection manager';

  @override
  String get connectionSubtitle =>
      'Store trusted OpenCode endpoints, probe capabilities first, then step into project and session workflows.';

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
      'Probe checks health, spec, config, providers, agent availability, and experimental tool support. mDNS and richer network discovery are next in the roadmap.';

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
      'Run a probe to classify auth, spec, capability, and SSE readiness before opening a workspace.';

  @override
  String get serverVersion => 'Version';

  @override
  String get sseStatus => 'SSE';

  @override
  String get readyStatus => 'ready';

  @override
  String get needsAttentionStatus => 'needs attention';

  @override
  String get connectionEmptyState =>
      'Enter a server profile and run the probe to populate capability diagnostics.';

  @override
  String get connectionHeaderEyebrow => 'Phase 2 · Live server connection';

  @override
  String get connectionHeaderTitle => 'Connect a real OpenCode server';

  @override
  String get connectionHeaderSubtitle =>
      'Probe the live spec, verify auth, and keep the next handoff grounded in actual server capability.';

  @override
  String get connectionStatusAwaiting => 'Awaiting first probe';

  @override
  String get connectionFormTitle => 'Server profile manager';

  @override
  String get connectionFormSubtitle =>
      'Save known endpoints, retry recent attempts, and verify whether the server is actually ready for this client.';

  @override
  String get savedProfilesCountLabel => 'saved';

  @override
  String get recentConnectionsCountLabel => 'recent';

  @override
  String get sseReadyLabel => 'SSE-ready';

  @override
  String get ssePendingLabel => 'Probe pending';

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
  String get connectionProbeAction => 'Probe server';

  @override
  String get connectionSaveAction => 'Save profile';

  @override
  String get connectionProbeResultTitle => 'Live capability probe';

  @override
  String get connectionProbeResultSubtitle =>
      'Each run checks health, spec, config, providers, agents, and experimental tools when the spec exposes them.';

  @override
  String get connectionProbeEmptyTitle => 'No live probe yet';

  @override
  String get connectionProbeEmptySubtitle =>
      'Run a probe to classify auth failures, spec fetch issues, unsupported capability gaps, or readiness for the SSE/connectivity layer.';

  @override
  String get connectionVersionLabel => 'Version';

  @override
  String get connectionCheckedAtLabel => 'Checked';

  @override
  String get connectionCapabilitiesLabel => 'Capabilities enabled';

  @override
  String get connectionReadinessLabel => 'Readiness';

  @override
  String get connectionMissingCapabilitiesLabel => 'Missing required endpoints';

  @override
  String get connectionExperimentalPathsLabel => 'Experimental tool endpoints';

  @override
  String get connectionEndpointSectionTitle => 'Endpoint outcomes';

  @override
  String get connectionCapabilitySectionTitle => 'Capability registry';

  @override
  String get savedProfilesTitle => 'Saved profiles';

  @override
  String get savedProfilesSubtitle =>
      'Pinned connections stay ready for repeat probe cycles.';

  @override
  String get savedProfilesEmptyTitle => 'No saved profiles yet';

  @override
  String get savedProfilesEmptySubtitle =>
      'Save a working address so the app opens with a known server target next time.';

  @override
  String get recentConnectionsTitle => 'Recent attempts';

  @override
  String get recentConnectionsSubtitle =>
      'Last live probes, kept separate from pinned server profiles.';

  @override
  String get recentConnectionsEmptyTitle => 'No recent attempts yet';

  @override
  String get recentConnectionsEmptySubtitle =>
      'Probe a server and the latest outcome will stay here for quick retry.';

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
      'Core endpoints responded and the server looks ready for SSE handoff.';

  @override
  String get connectionDetailAuthFailure =>
      'The server responded, but at least one core endpoint rejected the supplied credentials.';

  @override
  String get connectionDetailSpecFailure =>
      'The server is reachable, but the OpenAPI spec could not be fetched or parsed cleanly.';

  @override
  String get connectionDetailUnsupported =>
      'The server spec is readable, but required endpoints for this client are still missing.';

  @override
  String get connectionDetailConnectivityFailure =>
      'The server could not be reached reliably enough to complete probing.';

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
  String get fixtureDiagnosticsTitle => 'Fixture diagnostics';

  @override
  String get fixtureDiagnosticsSubtitle =>
      'The phase 1 manual QA surfaces stay visible here while live connection work comes online.';

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
  String get capabilityHasExperimentalTools => 'Experimental tools';

  @override
  String get capabilityHasProviderOAuth => 'Provider OAuth';

  @override
  String get capabilityHasMcpAuth => 'MCP auth';

  @override
  String get capabilityHasTuiControl => 'TUI control';

  @override
  String get projectSelectionTitle => 'Project selection';

  @override
  String get projectSelectionSubtitle =>
      'Choose the active project context from the server\'s current project, server-listed projects, a manual path, or a folder browser.';

  @override
  String get currentProjectTitle => 'Current project';

  @override
  String get currentProjectSubtitle =>
      'The project currently scoped by the connected server instance.';

  @override
  String get serverProjectsTitle => 'Server-listed projects';

  @override
  String get serverProjectsSubtitle =>
      'Projects OpenCode already knows about on this server.';

  @override
  String get serverProjectsEmpty => 'No server-listed projects yet.';

  @override
  String get manualProjectTitle => 'Manual path or folder browser';

  @override
  String get manualProjectSubtitle =>
      'Use this when search misses a folder or you need to open an exact path.';

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
      'Recent local project targets kept separately from server-listed projects.';

  @override
  String get recentProjectsEmpty => 'No recent projects yet.';

  @override
  String get projectPreviewTitle => 'Project preview';

  @override
  String get projectPreviewSubtitle =>
      'Metadata for the next project context before sessions and chat bind to it.';

  @override
  String get projectPreviewEmpty =>
      'Select a project from one of the four entry points to preview it here.';

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
      'This target is ready for the next phase where sessions and chat use the selected project context.';

  @override
  String get projectOpenAction => 'Open project';

  @override
  String get shellProjectRailTitle => 'Project and sessions';

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
  String get shellAgentLabel => 'build agent';

  @override
  String get shellChatTimelineTitle => 'Conversation';

  @override
  String get shellUserMessageTitle => 'You';

  @override
  String get shellUserMessageBody =>
      'Review the selected project context and continue from the latest session state.';

  @override
  String get shellAssistantMessageTitle => 'OpenCode';

  @override
  String get shellAssistantMessageBody =>
      'Shell layout is ready. Session, message parts, tools, and context panels attach here in the next phase.';

  @override
  String get shellComposerPlaceholder =>
      'Message composer stays here without autofocus by default.';

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
  String get shellToolsSubtitle =>
      'Built-in and experimental tools surface here.';

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
  String get shellActionInit => 'Init';

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
  String get shellConfigPreviewSubtitle =>
      'Live preview of editable configuration';

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
  String get shellTodoStatusInProgress => 'in progress';

  @override
  String get shellTodoStatusPending => 'pending';

  @override
  String get shellTodoStatusCompleted => 'completed';

  @override
  String get shellTodoStatusUnknown => 'unknown';

  @override
  String chatPartUnknown(String type) {
    return 'Unknown part: $type';
  }
}
