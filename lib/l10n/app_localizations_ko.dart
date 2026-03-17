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

  @override
  String get projectOpenAction => '프로젝트 열기';

  @override
  String get shellProjectRailTitle => '프로젝트와 세션';

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
  String get shellAgentLabel => 'build 에이전트';

  @override
  String get shellChatTimelineTitle => '대화';

  @override
  String get shellUserMessageTitle => '사용자';

  @override
  String get shellUserMessageBody => '선택한 프로젝트 문맥을 검토하고 최신 세션 상태에서 이어서 작업합니다.';

  @override
  String get shellAssistantMessageTitle => 'OpenCode';

  @override
  String get shellAssistantMessageBody =>
      'shell 레이아웃 준비가 끝났습니다. 다음 단계에서 세션, 메시지 파트, 도구, 문맥 패널이 여기에 연결됩니다.';

  @override
  String get shellComposerPlaceholder => '입력창은 기본 자동 포커스 없이 이 위치를 유지합니다.';

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
  String get shellToolsSubtitle => '기본 도구와 experimental 도구가 여기에 표시됩니다.';

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
  String get shellConfigPreviewSubtitle => '편집 가능한 설정의 실시간 미리보기';

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
}
