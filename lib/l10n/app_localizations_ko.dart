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

  @override
  String get connectionHeaderEyebrow => '2단계 · 실서버 연결';

  @override
  String get connectionHeaderTitle => '실제 OpenCode 서버 연결';

  @override
  String get connectionHeaderSubtitle =>
      '실시간 spec을 probe하고 인증 상태를 확인해 다음 handoff를 실제 서버 capability 기준으로 맞춥니다.';

  @override
  String get connectionStatusAwaiting => '첫 probe 대기 중';

  @override
  String get connectionFormTitle => '서버 프로필 매니저';

  @override
  String get connectionFormSubtitle =>
      '알려진 엔드포인트를 저장하고 최근 시도를 다시 불러오며 이 클라이언트 기준 readiness를 바로 확인합니다.';

  @override
  String get savedProfilesCountLabel => '저장됨';

  @override
  String get recentConnectionsCountLabel => '최근';

  @override
  String get sseReadyLabel => 'SSE 준비 완료';

  @override
  String get ssePendingLabel => 'probe 대기';

  @override
  String get connectionProfileLabel => '프로필 이름';

  @override
  String get connectionProfileLabelHint => '스테이징, 로컬 터널, 사내 게이트웨이';

  @override
  String get connectionAddressLabel => '서버 주소';

  @override
  String get connectionAddressHint => 'https://opencode.example.com';

  @override
  String get connectionUsernameLabel => 'Basic auth 사용자 이름';

  @override
  String get connectionUsernameHint => '선택 사항';

  @override
  String get connectionPasswordLabel => 'Basic auth 비밀번호';

  @override
  String get connectionPasswordHint => '선택 사항';

  @override
  String get connectionAddressValidation => '유효한 서버 주소를 입력하세요.';

  @override
  String get connectionProbeAction => '서버 probe';

  @override
  String get connectionSaveAction => '프로필 저장';

  @override
  String get connectionProbeResultTitle => '실시간 capability probe';

  @override
  String get connectionProbeResultSubtitle =>
      '실행할 때마다 health, spec, config, provider, agent, 그리고 spec에 드러난 experimental tool 엔드포인트를 확인합니다.';

  @override
  String get connectionProbeEmptyTitle => '아직 실시간 probe가 없습니다';

  @override
  String get connectionProbeEmptySubtitle =>
      'probe를 실행하면 인증 실패, spec fetch 실패, 미지원 capability, SSE/connectivity 준비 상태를 구분해 보여줍니다.';

  @override
  String get connectionVersionLabel => '버전';

  @override
  String get connectionCheckedAtLabel => '확인 시각';

  @override
  String get connectionCapabilitiesLabel => '활성 capability 수';

  @override
  String get connectionReadinessLabel => '준비 상태';

  @override
  String get connectionMissingCapabilitiesLabel => '누락된 필수 엔드포인트';

  @override
  String get connectionExperimentalPathsLabel => 'experimental tool 엔드포인트';

  @override
  String get connectionEndpointSectionTitle => '엔드포인트 결과';

  @override
  String get connectionCapabilitySectionTitle => 'capability 레지스트리';

  @override
  String get savedProfilesTitle => '저장된 프로필';

  @override
  String get savedProfilesSubtitle => '고정한 연결 대상을 반복 probe 흐름에 바로 다시 사용합니다.';

  @override
  String get savedProfilesEmptyTitle => '저장된 프로필이 없습니다';

  @override
  String get savedProfilesEmptySubtitle => '동작하는 주소를 저장해 다음 실행 때 바로 서버를 불러오세요.';

  @override
  String get recentConnectionsTitle => '최근 시도';

  @override
  String get recentConnectionsSubtitle => '고정 프로필과 분리된 최근 실시간 probe 기록입니다.';

  @override
  String get recentConnectionsEmptyTitle => '최근 시도가 없습니다';

  @override
  String get recentConnectionsEmptySubtitle =>
      '서버를 probe하면 최신 결과가 여기에 남아 빠르게 다시 시도할 수 있습니다.';

  @override
  String get connectionOutcomeReady => '연결 준비 완료';

  @override
  String get connectionOutcomeAuthFailure => '인증 실패';

  @override
  String get connectionOutcomeSpecFailure => 'spec fetch 실패';

  @override
  String get connectionOutcomeUnsupported => '미지원 capability';

  @override
  String get connectionOutcomeConnectivityFailure => '연결 실패';

  @override
  String get connectionDetailReady =>
      '핵심 엔드포인트가 응답했고 서버가 SSE handoff 준비 상태로 보입니다.';

  @override
  String get connectionDetailAuthFailure =>
      '서버는 응답했지만 핵심 엔드포인트 중 하나 이상이 제공한 자격 증명을 거부했습니다.';

  @override
  String get connectionDetailSpecFailure =>
      '서버에는 도달했지만 OpenAPI spec을 정상적으로 가져오거나 파싱하지 못했습니다.';

  @override
  String get connectionDetailUnsupported =>
      '서버 spec은 읽을 수 있지만 이 클라이언트에 필요한 엔드포인트가 아직 부족합니다.';

  @override
  String get connectionDetailConnectivityFailure =>
      'probe를 끝낼 만큼 안정적으로 서버에 연결하지 못했습니다.';

  @override
  String get endpointReadyStatus => '준비됨';

  @override
  String get endpointAuthStatus => '인증';

  @override
  String get endpointUnsupportedStatus => '미지원';

  @override
  String get endpointFailureStatus => '실패';

  @override
  String get endpointUnknownStatus => '알 수 없음';

  @override
  String get fixtureDiagnosticsTitle => 'fixture 진단';

  @override
  String get fixtureDiagnosticsSubtitle =>
      '1단계 수동 QA 표면을 유지한 채 실서버 연결 작업을 이어갑니다.';

  @override
  String get capabilityCanShareSession => '세션 공유';

  @override
  String get capabilityCanForkSession => '세션 포크';

  @override
  String get capabilityCanSummarizeSession => '세션 요약';

  @override
  String get capabilityCanRevertSession => '세션 되돌리기';

  @override
  String get capabilityHasQuestions => '질문';

  @override
  String get capabilityHasPermissions => '권한';

  @override
  String get capabilityHasExperimentalTools => 'experimental tools';

  @override
  String get capabilityHasProviderOAuth => 'provider OAuth';

  @override
  String get capabilityHasMcpAuth => 'MCP 인증';

  @override
  String get capabilityHasTuiControl => 'TUI 제어';

  @override
  String get projectSelectionTitle => '프로젝트 선택';

  @override
  String get projectSelectionSubtitle =>
      '연결된 서버의 현재 프로젝트, 서버 목록, 수동 경로, 폴더 브라우저 중 하나에서 활성 프로젝트 문맥을 고릅니다.';

  @override
  String get currentProjectTitle => '현재 프로젝트';

  @override
  String get currentProjectSubtitle => '연결된 서버 인스턴스가 현재 가리키는 프로젝트입니다.';

  @override
  String get serverProjectsTitle => '서버 목록 프로젝트';

  @override
  String get serverProjectsSubtitle => '이 서버에서 OpenCode가 이미 알고 있는 프로젝트들입니다.';

  @override
  String get serverProjectsEmpty => '서버 목록 프로젝트가 아직 없습니다.';

  @override
  String get manualProjectTitle => '수동 경로 또는 폴더 브라우저';

  @override
  String get manualProjectSubtitle => '검색에서 빠진 폴더나 정확한 경로를 열 때 사용합니다.';

  @override
  String get manualProjectPathLabel => '프로젝트 디렉터리';

  @override
  String get manualProjectPathHint => '/workspace/my-project';

  @override
  String get projectInspectAction => '경로 확인';

  @override
  String get projectInspectingAction => '확인 중...';

  @override
  String get projectBrowseAction => '폴더 탐색';

  @override
  String get recentProjectsTitle => '최근 프로젝트';

  @override
  String get recentProjectsSubtitle => '서버 목록과 분리된 로컬 최근 프로젝트 대상입니다.';

  @override
  String get recentProjectsEmpty => '최근 프로젝트가 아직 없습니다.';

  @override
  String get projectPreviewTitle => '프로젝트 미리보기';

  @override
  String get projectPreviewSubtitle => '세션과 채팅이 연결되기 전 다음 프로젝트 문맥의 메타데이터입니다.';

  @override
  String get projectPreviewEmpty =>
      '네 가지 진입점 중 하나에서 프로젝트를 선택하면 여기에 미리보기가 나타납니다.';

  @override
  String get projectDirectoryLabel => '디렉터리';

  @override
  String get projectSourceLabel => '출처';

  @override
  String get projectVcsLabel => 'VCS';

  @override
  String get projectBranchLabel => '브랜치';

  @override
  String get projectLastSessionLabel => '마지막 세션';

  @override
  String get projectLastStatusLabel => '마지막 상태';

  @override
  String get projectLastSessionUnknown => '아직 기록 없음';

  @override
  String get projectLastStatusUnknown => '아직 기록 없음';

  @override
  String get projectSelectionReadyHint =>
      '이 대상은 다음 단계에서 세션과 채팅이 선택된 프로젝트 문맥을 사용하도록 연결할 준비가 되었습니다.';
}
