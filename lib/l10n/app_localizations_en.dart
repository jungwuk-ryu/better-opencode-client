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
}
