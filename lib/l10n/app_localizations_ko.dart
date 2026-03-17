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

  @override
  String get connectionTitle => '서버 연결 관리자';

  @override
  String get connectionSubtitle =>
      '신뢰할 수 있는 OpenCode 엔드포인트를 저장하고, 먼저 capability를 probe한 뒤 프로젝트와 세션 흐름으로 들어갑니다.';

  @override
  String get serverProfileManager => '서버 프로필 관리자';

  @override
  String get connectionProfileHint =>
      '신뢰하는 호스트는 저장된 프로필로, 빠른 재시도는 최근 연결 목록으로 관리합니다.';

  @override
  String get profileLabel => '프로필 이름';

  @override
  String get serverAddress => '서버 주소';

  @override
  String get username => '사용자 이름';

  @override
  String get password => '비밀번호';

  @override
  String get testingConnection => '테스트 중...';

  @override
  String get testConnection => '연결 테스트';

  @override
  String get saveProfile => '프로필 저장';

  @override
  String get deleteProfile => '프로필 삭제';

  @override
  String get connectionGuidance =>
      'probe는 health, spec, config, provider, agent, experimental tool 지원을 확인합니다. mDNS와 더 풍부한 네트워크 탐지는 다음 단계에서 이어집니다.';

  @override
  String get savedServers => '저장된 서버';

  @override
  String get recentConnections => '최근 연결';

  @override
  String get noSavedServers => '저장된 서버가 아직 없습니다.';

  @override
  String get noRecentConnections => '최근 연결 시도가 아직 없습니다.';

  @override
  String get connectionDiagnostics => '연결 진단';

  @override
  String get connectionDiagnosticsHint =>
      'probe를 실행해 auth, spec, capability, SSE 준비 상태를 먼저 분류합니다.';

  @override
  String get serverVersion => '버전';

  @override
  String get sseStatus => 'SSE';

  @override
  String get readyStatus => '준비됨';

  @override
  String get needsAttentionStatus => '주의 필요';

  @override
  String get connectionEmptyState =>
      '서버 프로필을 입력하고 probe를 실행하면 capability 진단이 채워집니다.';
}
