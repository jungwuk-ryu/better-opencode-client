// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => 'OpenCode Remote';

  @override
  String get foundationTitle => '파운데이션 디버그 워크스페이스';

  @override
  String get foundationSubtitle =>
      'UI 패리티 작업 전에 capability, fixture, stream 기반을 먼저 연결합니다.';

  @override
  String get currentFlavor => '플레이버';

  @override
  String get currentLocale => '로케일';

  @override
  String get fullCapabilityProbe => '전체 capability probe';

  @override
  String get legacyCapabilityProbe => '레거시 capability probe';

  @override
  String get probeErrorCapability => 'probe 오류 처리';

  @override
  String get healthyStream => '정상 스트림';

  @override
  String get staleStream => 'stale stream 복구';

  @override
  String get duplicateStream => '중복 이벤트 처리';

  @override
  String get resyncStream => 'resync 필요';

  @override
  String get capabilityFlags => 'capability 플래그';

  @override
  String get streamFrames => '스트림 프레임';

  @override
  String get unknownFields => '알 수 없는 필드 보존';

  @override
  String get switchLocale => '언어 전환';
}
