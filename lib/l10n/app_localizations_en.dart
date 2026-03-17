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
}
