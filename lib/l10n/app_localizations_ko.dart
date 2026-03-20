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
  String get foundationTitle => '파운데이션 워크스페이스';

  @override
  String get foundationSubtitle => '서버를 연결하기 전에 기본 확인과 라이브 업데이트 준비를 마칩니다.';

  @override
  String get currentFlavor => '플레이버';

  @override
  String get currentLocale => '로케일';

  @override
  String get fullCapabilityProbe => '전체 서버 확인';

  @override
  String get legacyCapabilityProbe => '호환성 확인';

  @override
  String get probeErrorCapability => '확인 오류 처리';

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
  String get cacheSettingsAction => '캐시 설정';

  @override
  String get cacheSettingsTitle => '캐시 설정';

  @override
  String get cacheSettingsSubtitle =>
      '캐시 유지 시간을 조정하고 저장된 연결 확인과 워크스페이스 스냅샷을 비웁니다.';

  @override
  String get cacheTtlLabel => '캐시 유지 시간';

  @override
  String get cacheClearAction => '캐시 데이터 비우기';

  @override
  String get cacheClearingAction => '캐시 비우는 중...';

  @override
  String get cacheTtl15Seconds => '15초';

  @override
  String get cacheTtl1Minute => '1분';

  @override
  String get cacheTtl5Minutes => '5분';

  @override
  String get cacheTtl15Minutes => '15분';

  @override
  String get connectionTitle => '서버 연결 관리자';

  @override
  String get connectionSubtitle =>
      '신뢰할 수 있는 OpenCode 서버를 저장하고, 필요할 때 서버 상태를 확인한 뒤 홈에서 프로젝트를 고릅니다.';

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
      '서버 확인은 상태, 호환성, 인증, 프로바이더 접근, 도구 사용 가능 여부를 확인합니다. 더 많은 네트워크 탐지 옵션은 추후 제공됩니다.';

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
  String get connectionDiagnosticsHint => '서버 확인을 실행해 인증과 호환성을 먼저 점검합니다.';

  @override
  String get serverVersion => '버전';

  @override
  String get sseStatus => '라이브 업데이트';

  @override
  String get readyStatus => '준비됨';

  @override
  String get needsAttentionStatus => '주의 필요';

  @override
  String get connectionEmptyState => '서버 프로필을 입력하고 서버 확인을 실행하면 진단 정보가 채워집니다.';

  @override
  String get connectionHeaderEyebrow => '실서버 연결';

  @override
  String get connectionHeaderTitle => '실제 OpenCode 서버 연결';

  @override
  String get connectionHeaderSubtitle =>
      '저장된 서버 정보를 검토하고 인증 상태를 확인한 뒤, 준비가 되면 워크스페이스 홈으로 돌아갑니다.';

  @override
  String get connectionStatusAwaiting => '첫 확인 대기 중';

  @override
  String get connectionFormTitle => '서버 프로필 매니저';

  @override
  String get connectionFormSubtitle =>
      '저장된 서버 정보를 수정하고 다시 확인해 홈에서 쓸 수 있는 상태를 유지합니다.';

  @override
  String get savedProfilesCountLabel => '저장됨';

  @override
  String get recentConnectionsCountLabel => '최근';

  @override
  String get sseReadyLabel => '라이브 업데이트 준비 완료';

  @override
  String get ssePendingLabel => '확인 대기';

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
  String get connectionBackHomeAction => '홈으로 돌아가기';

  @override
  String get connectionProbeAction => '서버 확인';

  @override
  String get connectionSaveAction => '프로필 저장';

  @override
  String get connectionDraftRestoredLabel => '저장되지 않은 초안을 복원했습니다';

  @override
  String get connectionPinProfileAction => '프로필 고정';

  @override
  String get connectionUnpinProfileAction => '프로필 고정 해제';

  @override
  String get connectionProbeResultTitle => '서버 확인 결과';

  @override
  String get connectionProbeResultSubtitle =>
      '이 상세 화면에서 저장된 서버가 아직 응답하는지 확인합니다. 프로젝트 선택은 워크스페이스 홈에서 진행합니다.';

  @override
  String get connectionProbeEmptyTitle => '최근 확인 기록이 없습니다';

  @override
  String get connectionProbeEmptySubtitle =>
      '서버 확인을 실행해 인증과 호환성을 점검한 뒤 워크스페이스 홈으로 돌아가세요.';

  @override
  String get connectionVersionLabel => '버전';

  @override
  String get connectionCheckedAtLabel => '확인 시각';

  @override
  String get connectionCapabilitiesLabel => '활성 capability 수';

  @override
  String get connectionReadinessLabel => '준비 상태';

  @override
  String get connectionMissingCapabilitiesLabel => '누락된 필수 기능';

  @override
  String get connectionExperimentalPathsLabel => '고급 도구';

  @override
  String get connectionEndpointSectionTitle => '확인 결과';

  @override
  String get connectionCapabilitySectionTitle => '기능 목록';

  @override
  String get savedProfilesTitle => '저장된 프로필';

  @override
  String get savedProfilesSubtitle => '고정한 서버는 빠르게 다시 확인할 수 있습니다.';

  @override
  String get savedProfilesEmptyTitle => '저장된 프로필이 없습니다';

  @override
  String get savedProfilesEmptySubtitle => '동작하는 주소를 저장해 다음 실행 때 바로 서버를 불러오세요.';

  @override
  String get recentConnectionsTitle => '최근 시도';

  @override
  String get recentConnectionsSubtitle => '고정 서버와 분리된 최근 서버 확인 기록입니다.';

  @override
  String get recentConnectionsEmptyTitle => '최근 시도가 없습니다';

  @override
  String get recentConnectionsEmptySubtitle =>
      '서버를 확인하면 최신 결과가 여기에 남아 빠르게 다시 시도할 수 있습니다.';

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
  String get connectionDetailReady => '핵심 서비스가 응답했고 이제 홈에서 프로젝트를 고를 수 있습니다.';

  @override
  String get connectionDetailAuthFailure => '서버는 응답했지만 제공한 인증 정보가 거부되었습니다.';

  @override
  String get connectionDetailBasicAuthFailure =>
      '이 서버는 Basic auth로 보호됩니다. 사용자 이름과 비밀번호를 추가하거나 수정한 뒤 다시 시도하세요.';

  @override
  String get connectionDetailSpecFailure =>
      '서버에는 도달했지만 OpenAPI spec을 정상적으로 가져오거나 파싱하지 못했습니다.';

  @override
  String get connectionDetailUnsupported =>
      '서버에 연결할 수 있지만 이 앱에 필요한 기능이 아직 부족합니다.';

  @override
  String get connectionDetailConnectivityFailure =>
      '서버 확인을 완료할 만큼 안정적으로 연결하지 못했습니다.';

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
  String get fixtureDiagnosticsTitle => '진단';

  @override
  String get fixtureDiagnosticsSubtitle => '연결 확인과 상태 세부 정보가 여기에 표시됩니다.';

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
  String get capabilityHasExperimentalTools => '고급 도구';

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
      '이 서버, 최근 작업, 또는 폴더 경로에서 열 프로젝트를 고릅니다.';

  @override
  String get currentProjectTitle => '현재 프로젝트';

  @override
  String get currentProjectSubtitle => '서버가 이미 어떤 프로젝트 안에 있다면 여기에서 먼저 보여줍니다.';

  @override
  String get serverProjectsTitle => '이 서버의 프로젝트';

  @override
  String get serverProjectsSubtitle => '지금 이 서버에서 열 수 있는 다른 프로젝트들입니다.';

  @override
  String get serverProjectsEmpty =>
      '지금 사용할 수 있는 서버 프로젝트가 없습니다. 최근 프로젝트나 폴더 경로는 계속 열 수 있습니다.';

  @override
  String get manualProjectTitle => '폴더 경로 열기';

  @override
  String get manualProjectSubtitle =>
      '서버 목록이 비어 있거나 원하는 폴더를 정확히 알고 있을 때 사용합니다.';

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
  String get recentProjectsSubtitle => '최근에 연 프로젝트이며, 있으면 마지막 세션 힌트도 함께 보여줍니다.';

  @override
  String get pinnedProjectsTitle => '고정한 프로젝트';

  @override
  String get pinnedProjectsSubtitle =>
      '모바일에서 빠르게 다시 열 수 있도록 위쪽에 유지하는 로컬 즐겨찾기입니다.';

  @override
  String get recentProjectsEmpty => '최근 프로젝트가 아직 없습니다.';

  @override
  String get projectPreviewTitle => '프로젝트 상세';

  @override
  String get projectPreviewSubtitle => '열기 전에 다음 워크스페이스를 확인합니다.';

  @override
  String get projectPreviewEmpty =>
      '프로젝트, 최근 워크스페이스, 또는 폴더 경로를 선택하면 여기에서 상세 정보를 볼 수 있습니다.';

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
  String get projectSelectionReadyHint => '이 프로젝트를 열어 해당 세션으로 이어서 작업합니다.';

  @override
  String get homeHeaderEyebrow => '워크스페이스';

  @override
  String get homeHeaderSubtitle => '서버를 연결한 뒤 프로젝트를 열고 세션을 이어서 작업하세요.';

  @override
  String get homeAddServerAction => '서버 추가';

  @override
  String get homeBackToServersAction => '서버 선택으로 돌아가기';

  @override
  String get homeEditSelectedServerAction => '선택한 서버 편집';

  @override
  String get homeEditServerAction => '서버 편집';

  @override
  String get homeSwitchServerAction => '서버 전환';

  @override
  String get homeNextStepsTitle => '다음 단계';

  @override
  String get homeNextStepsPinnedServers => '자주 쓰는 서버를 고정해 항상 위에 두세요.';

  @override
  String get homeNextStepsProjects => '서버가 준비되면 프로젝트를 열고 세션으로 이어갑니다.';

  @override
  String get homeNextStepsRetryEdit => '홈을 떠나지 않고도 재시도하거나 서버 정보를 수정할 수 있어요.';

  @override
  String get homeMetricSavedServers => '저장된 서버';

  @override
  String get homeMetricRecentActivity => '최근 활동';

  @override
  String get homeMetricCurrentFocus => '현재 서버';

  @override
  String get homeChooseServerLabel => '서버 선택';

  @override
  String get homeResumeLastWorkspaceTitle => '마지막 워크스페이스 재개';

  @override
  String get homeOpenLastProjectTitle => '마지막 프로젝트 열기';

  @override
  String homeResumeLastWorkspaceBody(String project) {
    return '$project에서 이어서 작업하고 이전 상태로 돌아갑니다.';
  }

  @override
  String homeOpenLastProjectBody(String project) {
    return '$project를 열고 세션을 고르거나 새로 시작하세요.';
  }

  @override
  String get homeResumeLastWorkspaceAction => '워크스페이스 재개';

  @override
  String get homeOpenLastProjectAction => '프로젝트 열기';

  @override
  String get homeResumeMetricProject => '프로젝트';

  @override
  String get homeResumeMetricLastSession => '마지막 세션';

  @override
  String get homeResumeMetricStatus => '상태';

  @override
  String get homeActionCheckingWorkspace => '워크스페이스 확인 중...';

  @override
  String get homeActionContinue => '계속';

  @override
  String get homeActionRetry => '재시도';

  @override
  String get homeActionCheckingServer => '서버 확인 중...';

  @override
  String get homeThisServerLabel => '이 서버';

  @override
  String get homeWorkspaceSectionTitle => '프로젝트와 세션';

  @override
  String get homeWorkspaceLoadingSubtitle => '저장된 서버와 최근 활동을 불러오는 중입니다.';

  @override
  String get homeWorkspaceEmptySubtitle => '서버를 추가하면 여기에서 프로젝트와 세션을 열 수 있습니다.';

  @override
  String get homeWorkspaceFeatureSaveTitle => '서버는 한 번만 저장';

  @override
  String get homeWorkspaceFeatureSaveBody => '서버를 한곳에 모아두고 필요할 때 바로 불러오세요.';

  @override
  String get homeWorkspaceFeatureChooseTitle => '다음은 프로젝트 열기';

  @override
  String get homeWorkspaceFeatureChooseBody => '서버가 준비되면 프로젝트를 고르고 이어서 작업합니다.';

  @override
  String get homeWorkspaceFeatureRecentTitle => '최근 기록 유지';

  @override
  String get homeWorkspaceFeatureRecentBody =>
      '저장된 서버와 최근 확인 결과가 한 화면에 함께 보입니다.';

  @override
  String get homeWorkspaceSubtitleReady => '프로젝트를 골라 계속하세요.';

  @override
  String get homeWorkspaceSubtitleSignIn =>
      '프로젝트를 불러오기 전에 인증 정보를 확인하거나 재시도하세요.';

  @override
  String get homeWorkspaceSubtitleOffline => '서버에 다시 연결하거나 저장된 주소를 확인하세요.';

  @override
  String get homeWorkspaceSubtitleUpdate => '프로젝트를 열기 전에 서버 업데이트가 필요합니다.';

  @override
  String get homeWorkspaceSubtitleUnknown => '프로젝트를 불러오기 전에 간단히 확인하세요.';

  @override
  String get homeWorkspaceTitleChooseServer => '저장된 서버 선택';

  @override
  String homeWorkspaceTitleChecking(String server) {
    return '$server 확인 중';
  }

  @override
  String get homeWorkspaceTitleReady => '프로젝트 준비 완료';

  @override
  String get homeWorkspaceTitleSignInRequired => '인증 필요';

  @override
  String get homeWorkspaceTitleOffline => '오프라인';

  @override
  String get homeWorkspaceTitleUpdate => '업데이트 필요';

  @override
  String get homeWorkspaceTitleContinueFromHome => '홈에서 계속';

  @override
  String get homeWorkspaceBodyChecking =>
      '프로젝트와 세션을 불러오기 전에 인증과 호환성을 확인하는 중입니다.';

  @override
  String homeWorkspaceBodyReady(String server) {
    return '$server는 준비됐지만 프로젝트 목록을 불러오는 중입니다.';
  }

  @override
  String homeWorkspaceBodySignInRequired(String server) {
    return '$server는 응답했지만 프로젝트를 불러오려면 인증 정보가 필요합니다.';
  }

  @override
  String homeWorkspaceBodyBasicAuthRequired(String server) {
    return '$server는 Basic auth로 보호됩니다. 프로젝트를 불러오기 전에 서버 편집에서 사용자 이름과 비밀번호를 추가하세요.';
  }

  @override
  String homeWorkspaceBodyOffline(String server) {
    return '지금은 $server에 연결할 수 없습니다. 재시도하거나 주소가 바뀌었으면 수정하세요.';
  }

  @override
  String homeWorkspaceBodyUpdateRequired(String server) {
    return '$server는 응답했지만 프로젝트를 열려면 업데이트가 필요합니다.';
  }

  @override
  String get homeWorkspaceBodyUnknown => '먼저 간단히 확인한 뒤, 필요할 때만 인증이나 주소를 수정하세요.';

  @override
  String get homeNoticeWorkspaceUnavailable =>
      '마지막 워크스페이스를 찾을 수 없습니다. 프로젝트를 골라 계속하세요.';

  @override
  String get homeNoticeWorkspaceResumeFailed =>
      '지금은 마지막 워크스페이스를 다시 열 수 없습니다. 아래에서 프로젝트를 고르거나 이 서버를 재시도하세요.';

  @override
  String get homeSavedServersTitle => '저장된 서버';

  @override
  String get homeSavedServersSubtitle => '서버를 고른 뒤 프로젝트와 세션으로 이어갑니다.';

  @override
  String get homeSavedServersEmptyTitle => '저장된 서버가 없습니다';

  @override
  String get homeSavedServersEmptySubtitle => '첫 서버를 추가해 프로젝트와 세션을 열어보세요.';

  @override
  String get homeRecentActivityTitle => '최근 활동';

  @override
  String get homeRecentActivitySubtitle => '최근에 확인한 서버 기록입니다.';

  @override
  String get homeRecentActivityEmptyTitle => '최근 활동이 없습니다';

  @override
  String get homeRecentActivityEmptySubtitle =>
      '서버를 연결하거나 재시도하면 기록이 여기에 표시됩니다.';

  @override
  String get homeRecentActivityNotUsed => '사용 기록 없음';

  @override
  String homeRecentActivityLastUsed(String timestamp) {
    return '마지막 사용 $timestamp';
  }

  @override
  String get homeCredentialsSaved => '자격 증명 저장됨';

  @override
  String get homeCredentialsMissing => '저장된 자격 증명 없음';

  @override
  String get homeServerCardBodyReady => '홈에서 프로젝트와 세션을 바로 열 수 있습니다.';

  @override
  String get homeServerCardBodySignIn => '재시도하거나 인증 정보를 수정하세요.';

  @override
  String get homeServerCardBodyBasicAuthRequired =>
      '이 서버는 프로젝트를 불러오기 전에 Basic auth가 필요합니다.';

  @override
  String get homeServerCardBodyOffline => '재시도하거나 저장된 주소를 수정하세요.';

  @override
  String get homeServerCardBodyUpdate => '프로젝트와 세션으로 이어서 작업하려면 서버 업데이트가 필요합니다.';

  @override
  String get homeServerCardBodyUnknownWithAuth => '프로젝트를 불러오기 전에 간단히 확인하세요.';

  @override
  String get homeServerCardBodyUnknown => '간단히 확인한 뒤, 필요하면 인증 정보를 수정하세요.';

  @override
  String get homeStatusNewHome => '새 홈';

  @override
  String get homeStatusChooseServer => '서버 선택';

  @override
  String get homeStatusCheckingServer => '서버 확인 중';

  @override
  String get homeStatusReadyForProjects => '프로젝트 준비됨';

  @override
  String get homeStatusSignInRequired => '인증 필요';

  @override
  String get homeStatusServerOffline => '서버 오프라인';

  @override
  String get homeStatusNeedsAttention => '확인 필요';

  @override
  String get homeStatusAwaitingSetup => '설정 대기';

  @override
  String get homeHeroTitleNoServers => '서버부터 시작하세요';

  @override
  String get homeHeroTitleOneServer => '저장된 서버로 바로 시작';

  @override
  String get homeHeroTitleManyServers => '서버를 한곳에서 관리';

  @override
  String get homeHeroBodyNoServers =>
      '서버를 한 번 추가해두면 여기로 돌아와 프로젝트와 세션을 열 수 있습니다.';

  @override
  String get homeHeroBodyOneServer => '홈에서 바로 이어서 작업하고, 필요할 때만 서버 정보를 수정하세요.';

  @override
  String get homeHeroBodyManyServers =>
      '서버를 고르고 최근 기록을 확인한 뒤 필요할 때만 빠르게 확인합니다.';

  @override
  String get homeA11yAddServerAction => '서버 추가';

  @override
  String get homeA11yBackToServersAction => '서버 선택으로 돌아가기';

  @override
  String get homeA11yEditSelectedServerAction => '선택한 서버 편집';

  @override
  String get homeA11yWorkspacePrimaryAction => '워크스페이스 주요 작업';

  @override
  String get homeA11yEditServerAction => '서버 편집';

  @override
  String get homeA11ySwitchServerAction => '서버 전환';

  @override
  String get homeA11yResumeWorkspaceAction => '워크스페이스 재개';

  @override
  String get homeStatusShortReady => '준비됨';

  @override
  String get homeStatusShortSignInRequired => '인증 필요';

  @override
  String get homeStatusShortOffline => '오프라인';

  @override
  String get homeStatusShortNeedsAttention => '확인 필요';

  @override
  String get homeStatusShortNotCheckedYet => '아직 확인 전';

  @override
  String get projectCatalogUnavailableTitle => '프로젝트 목록을 불러올 수 없습니다';

  @override
  String get projectCatalogUnavailableBody =>
      '지금은 이 서버의 프로젝트 목록을 불러오지 못했습니다. 최근 워크스페이스를 열거나 폴더 경로를 직접 입력할 수 있습니다.';

  @override
  String get projectOpenAction => '프로젝트 열기';

  @override
  String get projectPinAction => '프로젝트 고정';

  @override
  String get projectUnpinAction => '프로젝트 고정 해제';

  @override
  String get shellProjectRailTitle => '프로젝트와 세션';

  @override
  String get shellDestinationSessions => '세션';

  @override
  String get shellDestinationChat => '채팅';

  @override
  String get shellDestinationContext => '컨텍스트';

  @override
  String get shellDestinationSettings => '설정';

  @override
  String get shellAdvancedLabel => '고급';

  @override
  String get shellAdvancedSubtitle => '고급 설정과 문제 해결 도구입니다.';

  @override
  String get shellAdvancedOverviewSubtitle => '주요 흐름 밖에 두는 기술 옵션입니다.';

  @override
  String get shellOpenAdvancedAction => '고급 열기';

  @override
  String get shellBackToSettingsAction => '설정으로 돌아가기';

  @override
  String get shellA11yOpenCacheSettings => '캐시 설정 열기';

  @override
  String get shellA11yOpenAdvanced => '고급 설정 열기';

  @override
  String get shellA11yBackToSettings => '설정으로 돌아가기';

  @override
  String get shellA11yBackToProjectsAction => '프로젝트로 돌아가기';

  @override
  String get shellA11yComposerField => '메시지 입력';

  @override
  String get shellA11ySendMessageAction => '메시지 보내기';

  @override
  String get shellIntegrationsLastAuthUrlTitle => '마지막 인증 URL';

  @override
  String get shellIntegrationsEventsSubtitle => '이벤트 스트림 상태와 복구 정보입니다.';

  @override
  String get shellStreamHealthConnected => '연결됨';

  @override
  String get shellStreamHealthStale => '지연됨';

  @override
  String get shellStreamHealthReconnecting => '재연결 중';

  @override
  String get shellConfigPreviewUnavailable => '지금은 설정 화면을 사용할 수 없습니다.';

  @override
  String get shellNoticeLastSessionUnavailable =>
      '마지막 세션을 더는 찾을 수 없습니다. 다른 세션을 고르거나 새로 시작하세요.';

  @override
  String get shellConfigJsonObjectError => '설정은 JSON 객체여야 합니다.';

  @override
  String get shellRecoveryLogReconnectRequested => '재연결 요청';

  @override
  String get shellRecoveryLogReconnectCompleted => '재연결 완료';

  @override
  String get shellUnknownLabel => '알 수 없음';

  @override
  String get shellBackToProjectsAction => '프로젝트로 돌아가기';

  @override
  String get shellSessionsTitle => '세션';

  @override
  String get shellSessionCurrent => '현재 세션';

  @override
  String get shellSessionDraft => '초안 브랜치';

  @override
  String get shellSessionReview => '검토 브랜치';

  @override
  String get shellStatusActive => '활성';

  @override
  String get shellStatusIdle => '대기';

  @override
  String get shellStatusError => '오류';

  @override
  String get shellChatHeaderTitle => '채팅 워크스페이스';

  @override
  String get shellThinkingModeLabel => '균형 사고';

  @override
  String get shellAgentLabel => '에이전트';

  @override
  String get shellChatTimelineTitle => '대화';

  @override
  String get shellUserMessageTitle => '사용자';

  @override
  String get shellUserMessageBody => '세션을 고른 뒤 메시지를 보내 시작하세요.';

  @override
  String get shellAssistantMessageTitle => 'OpenCode';

  @override
  String get shellAssistantMessageBody =>
      '워크스페이스입니다. 컨텍스트를 확인하고 세션을 골라 작업을 이어가세요.';

  @override
  String get shellComposerPlaceholder => '메시지 작성';

  @override
  String get shellComposerSendAction => '보내기';

  @override
  String get shellComposerCreatingSession => '세션 생성 후 보내기';

  @override
  String get shellComposerSending => '전송 중...';

  @override
  String get shellRenameSessionTitle => '세션 이름 변경';

  @override
  String get shellSessionTitleHint => '세션 제목';

  @override
  String get shellCancelAction => '취소';

  @override
  String get shellSaveAction => '저장';

  @override
  String get shellContextTitle => '문맥 유틸리티';

  @override
  String get shellFilesTitle => '파일';

  @override
  String get shellFilesSubtitle => '트리, 상태, 검색이 여기에 들어옵니다.';

  @override
  String get shellDiffTitle => 'diff';

  @override
  String get shellDiffSubtitle => '패치와 스냅샷 검토가 여기에 나타납니다.';

  @override
  String get shellTodoTitle => 'todo';

  @override
  String get shellTodoSubtitle => '작업 진행과 히스토리가 여기에 보입니다.';

  @override
  String get shellToolsTitle => '도구';

  @override
  String get shellToolsSubtitle => '이 워크스페이스에서 쓸 수 있는 도구입니다.';

  @override
  String get shellTerminalTitle => '터미널';

  @override
  String get shellTerminalSubtitle => '빠른 shell과 attach 흐름이 여기에 배치됩니다.';

  @override
  String get shellInspectorTitle => '인스펙터';

  @override
  String get shellConfigTitle => '설정';

  @override
  String get shellConfigInvalid => '설정 JSON이 올바르지 않습니다.';

  @override
  String get shellConfigDraftEmpty => '설정 초안이 비어 있습니다.';

  @override
  String shellConfigChangedKeys(int count) {
    return '변경된 키: $count';
  }

  @override
  String get shellConfigApplying => '적용 중...';

  @override
  String get shellConfigApplyAction => '설정 적용';

  @override
  String get shellIntegrationsTitle => '통합 상태';

  @override
  String get shellIntegrationsProviders => '프로바이더';

  @override
  String get shellIntegrationsMethods => '방식';

  @override
  String get shellIntegrationsStartProviderAuth => '프로바이더 인증 시작';

  @override
  String get shellIntegrationsMcp => 'MCP';

  @override
  String get shellIntegrationsStartMcpAuth => 'MCP 인증 시작';

  @override
  String get shellIntegrationsLsp => 'LSP';

  @override
  String get shellIntegrationsFormatter => '포매터';

  @override
  String get shellIntegrationsEnabled => '활성';

  @override
  String get shellIntegrationsDisabled => '비활성';

  @override
  String get shellIntegrationsRecentEvents => '최근 이벤트';

  @override
  String get shellIntegrationsStreamHealth => '스트림 상태';

  @override
  String get shellIntegrationsRecoveryLog => '복구 로그';

  @override
  String get shellWorkspaceEyebrow => '워크스페이스';

  @override
  String get shellSessionsEyebrow => '세션';

  @override
  String get shellControlsEyebrow => '제어';

  @override
  String get shellActionsTitle => '작업';

  @override
  String get shellActionFork => '포크';

  @override
  String get shellActionShare => '공유';

  @override
  String get shellActionUnshare => '공유 해제';

  @override
  String get shellActionRename => '이름 변경';

  @override
  String get shellActionDelete => '삭제';

  @override
  String get shellActionAbort => '중단';

  @override
  String get shellActionRevert => '되돌리기';

  @override
  String get shellActionUnrevert => '되돌림 해제';

  @override
  String get shellActionInit => '초기화';

  @override
  String get shellActionSummarize => '요약';

  @override
  String get shellPrimaryEyebrow => '주요 흐름';

  @override
  String get shellTimelineEyebrow => '타임라인';

  @override
  String get shellFocusedThreadEyebrow => '집중 스레드';

  @override
  String get shellNewSessionDraft => '새 세션 초안';

  @override
  String shellTimelinePartsInFocus(int count) {
    return '포커스된 타임라인 파트 $count개';
  }

  @override
  String get shellReadyToStart => '시작 준비 완료';

  @override
  String get shellLiveContext => '실시간 문맥';

  @override
  String shellPartsCount(int count) {
    return '파트 $count개';
  }

  @override
  String get shellFocusedThreadSubtitle => '활성 스레드에 집중합니다';

  @override
  String get shellConversationSubtitle => '긴 대화 읽기와 응답 작성에 맞춘 중심 영역입니다';

  @override
  String get shellConnectionIssueTitle => '연결 문제';

  @override
  String get shellUtilitiesEyebrow => '유틸리티';

  @override
  String get shellFilesSearchHint => '파일, 텍스트, 심볼 검색';

  @override
  String get shellPreviewTitle => '미리보기';

  @override
  String get shellCurrentSelection => '현재 선택';

  @override
  String get shellMatchesTitle => '검색 결과';

  @override
  String get shellMatchesSubtitle => '관련 텍스트 결과';

  @override
  String get shellSymbolsTitle => '심볼';

  @override
  String get shellSymbolsSubtitle => '빠른 코드 랜드마크';

  @override
  String get shellTerminalHint => 'pwd';

  @override
  String get shellTerminalRunAction => '명령 실행';

  @override
  String get shellTerminalRunning => '실행 중...';

  @override
  String get shellTrackedLabel => '추적됨';

  @override
  String get shellPendingApprovalsTitle => '대기 중인 승인';

  @override
  String shellPendingApprovalsSubtitle(int count) {
    return '입력을 기다리는 항목 $count개';
  }

  @override
  String get shellAllowOnceAction => '이번만 허용';

  @override
  String get shellRejectAction => '거부';

  @override
  String get shellAnswerAction => '응답';

  @override
  String get shellConfigPreviewSubtitle => '설정을 확인하고 편집합니다';

  @override
  String get shellInspectorSubtitle => '세션과 메시지 메타데이터 스냅샷';

  @override
  String get shellIntegrationsLspSubtitle => '언어 서버 준비 상태';

  @override
  String get shellIntegrationsFormatterSubtitle => '포맷터 사용 가능 상태';

  @override
  String get shellActionsSubtitle => '세션 제어와 수명주기 작업';

  @override
  String shellActiveCount(int count) {
    return '활성 $count개';
  }

  @override
  String shellThreadsCount(int count) {
    return '현재 프로젝트의 스레드 $count개';
  }

  @override
  String get chatPartAssistant => '어시스턴트';

  @override
  String get chatPartUser => '사용자';

  @override
  String get chatPartThinking => '사고 과정';

  @override
  String get chatPartTool => '도구';

  @override
  String chatPartToolNamed(String name) {
    return '도구: $name';
  }

  @override
  String get chatPartFile => '파일';

  @override
  String get chatPartStepStart => '단계 시작';

  @override
  String get chatPartStepFinish => '단계 완료';

  @override
  String get chatPartSnapshot => '스냅샷';

  @override
  String get chatPartPatch => '패치';

  @override
  String get chatPartRetry => '재시도';

  @override
  String get chatPartAgent => '에이전트';

  @override
  String get chatPartSubtask => '하위 작업';

  @override
  String get chatPartCompaction => '압축';

  @override
  String get shellUtilitiesToggleTitle => '유틸리티 서랍';

  @override
  String get shellUtilitiesToggleBody =>
      '세로 레이아웃에서는 아래 유틸리티 서랍을 열어 파일, diff, todo, tools, terminal 패널을 확인합니다.';

  @override
  String get shellUtilitiesToggleBodyCompact =>
      '유틸리티를 열어 파일, diff, todo, tools, terminal 패널을 전환합니다.';

  @override
  String get shellContextEyebrow => '컨텍스트';

  @override
  String get shellSecondaryContextSubtitle => '활성 대화를 위한 보조 문맥';

  @override
  String get shellSupportRailsSubtitle => '파일, 작업, 명령, 통합을 위한 보조 레일';

  @override
  String shellModulesCount(int count) {
    return '모듈 $count개';
  }

  @override
  String get shellSwipeUtilitiesIntoView => '유틸리티를 화면으로 밀어 올리기';

  @override
  String get shellOpenUtilityRail => '유틸리티 레일 열기';

  @override
  String get shellOpenCodeRemote => 'OpenCode 리모트';

  @override
  String get shellContextNearby => '주변 컨텍스트';

  @override
  String shellShownCount(int count) {
    return '$count개 표시 중';
  }

  @override
  String get shellSymbolFallback => '심볼';

  @override
  String shellFileStatusSummary(String status, int added, int removed) {
    return '$status +$added -$removed';
  }

  @override
  String get shellNewSession => '새 세션';

  @override
  String get shellReplying => '응답 중';

  @override
  String get shellCompactComposer => '간결한 작성기';

  @override
  String get shellExpandedComposer => '확장 작성기';

  @override
  String shellRetryAttempt(int count) {
    return '시도 $count회';
  }

  @override
  String shellStatusWithDetails(String status, String details) {
    return '$status - $details';
  }

  @override
  String get shellTodoStatusInProgress => '진행 중';

  @override
  String get shellTodoStatusPending => '대기 중';

  @override
  String get shellTodoStatusCompleted => '완료';

  @override
  String get shellTodoStatusUnknown => '알 수 없음';

  @override
  String get shellQuestionAskedNotification => '질문 요청 도착';

  @override
  String get shellPermissionAskedNotification => '권한 요청 도착';

  @override
  String get shellNotificationOpenAction => '열기';

  @override
  String chatPartUnknown(String type) {
    return '알 수 없는 파트: $type';
  }
}
