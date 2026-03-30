// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '更好的开放代码客户端 (BOC)';

  @override
  String get foundationTitle => '基础工作区';

  @override
  String get foundationSubtitle => '在连接服务器之前，内置检查和实时更新已准备就绪。';

  @override
  String get currentFlavor => '味道';

  @override
  String get currentLocale => '语言环境';

  @override
  String get fullCapabilityProbe => '全服务器检查';

  @override
  String get legacyCapabilityProbe => '兼容性检查';

  @override
  String get probeErrorCapability => '检查错误处理';

  @override
  String get healthyStream => '健康流';

  @override
  String get staleStream => '过时流恢复';

  @override
  String get duplicateStream => '重复事件处理';

  @override
  String get resyncStream => '需要重新同步';

  @override
  String get capabilityFlags => '能力标志';

  @override
  String get streamFrames => '流帧';

  @override
  String get unknownFields => '保留未知字段';

  @override
  String get switchLocale => '切换区域设置';

  @override
  String get cacheSettingsAction => '缓存设置';

  @override
  String get cacheSettingsTitle => '缓存设置';

  @override
  String get cacheSettingsSubtitle => '调整缓存新鲜度并清除存储的连接检查和工作区快照。';

  @override
  String get cacheTtlLabel => '缓存新鲜度';

  @override
  String get cacheClearAction => '清除缓存数据';

  @override
  String get cacheClearingAction => '正在清除缓存...';

  @override
  String get cacheTtl15Seconds => '15秒';

  @override
  String get cacheTtl1Minute => '1分钟';

  @override
  String get cacheTtl5Minutes => '5分钟';

  @override
  String get cacheTtl15Minutes => '15分钟';

  @override
  String get connectionTitle => '服务器连接管理器';

  @override
  String get connectionSubtitle =>
      '存储受信任的 OpenCode 服务器，在需要时运行服务器检查，然后返回主页选择项目。';

  @override
  String get serverProfileManager => '服务器配置文件管理器';

  @override
  String get connectionProfileHint => '使用受信任主机保存的配置文件和最近的尝试进行快速重试。';

  @override
  String get profileLabel => '轮廓标签';

  @override
  String get serverAddress => '服务器地址';

  @override
  String get username => '用户名';

  @override
  String get password => '密码';

  @override
  String get testingConnection => '测试...';

  @override
  String get testConnection => '测试连接';

  @override
  String get saveProfile => '保存个人资料';

  @override
  String get deleteProfile => '删除个人资料';

  @override
  String get connectionGuidance =>
      '服务器检查确认运行状况、兼容性、登录、提供商访问和工具可用性。更多网络发现选项即将推出。';

  @override
  String get savedServers => '已保存的服务器';

  @override
  String get recentConnections => '最近的连接';

  @override
  String get noSavedServers => '还没有保存的服务器。';

  @override
  String get noRecentConnections => '最近还没有尝试。';

  @override
  String get connectionDiagnostics => '连接诊断';

  @override
  String get connectionDiagnosticsHint => '在打开工作区之前运行服务器检查以确认登录和兼容性。';

  @override
  String get serverVersion => '版本';

  @override
  String get sseStatus => '实时更新';

  @override
  String get readyStatus => '准备好';

  @override
  String get needsAttentionStatus => '需要注意';

  @override
  String get connectionEmptyState => '输入服务器配置文件并运行服务器检查以填充诊断信息。';

  @override
  String get connectionHeaderEyebrow => '实时服务器连接';

  @override
  String get connectionHeaderTitle => '连接真正的 OpenCode 服务器';

  @override
  String get connectionHeaderSubtitle =>
      '查看保存的服务器详细信息，验证登录，并在该服务器准备就绪后返回工作区主页。';

  @override
  String get connectionStatusAwaiting => '等待第一次检查';

  @override
  String get connectionFormTitle => '服务器配置文件管理器';

  @override
  String get connectionFormSubtitle => '更新保存的服务器详细信息，重试检查，并保留此配置文件以便回家。';

  @override
  String get savedProfilesCountLabel => '已保存';

  @override
  String get recentConnectionsCountLabel => '最近的';

  @override
  String get sseReadyLabel => '实时更新已准备就绪';

  @override
  String get ssePendingLabel => '支票待处理';

  @override
  String get connectionProfileLabel => '个人资料名称';

  @override
  String get connectionProfileLabelHint => '工作室舞台、笔记本电脑隧道、本地网关';

  @override
  String get connectionAddressLabel => '服务器地址';

  @override
  String get connectionAddressHint => 'https://opencode.example.com';

  @override
  String get connectionUsernameLabel => '基本身份验证用户名';

  @override
  String get connectionUsernameHint => '选修的';

  @override
  String get connectionPasswordLabel => '基本验证密码';

  @override
  String get connectionPasswordHint => '选修的';

  @override
  String get connectionAddressValidation => '输入有效的服务器地址。';

  @override
  String get connectionBackHomeAction => '回到家';

  @override
  String get connectionProbeAction => '检查服务器';

  @override
  String get connectionSaveAction => '保存个人资料';

  @override
  String get connectionDraftRestoredLabel => '恢复未保存的草稿';

  @override
  String get connectionPinProfileAction => '引脚轮廓';

  @override
  String get connectionUnpinProfileAction => '取消固定个人资料';

  @override
  String get connectionProbeResultTitle => '服务器检查';

  @override
  String get connectionProbeResultSubtitle =>
      '使用此详细视图可以确认保存的服务器是否仍然响应。项目选择是在工作区主页进行的。';

  @override
  String get connectionProbeEmptyTitle => '最近还没有检查';

  @override
  String get connectionProbeEmptySubtitle => '返回工作区主页之前，运行服务器检查以确认登录和兼容性。';

  @override
  String get connectionVersionLabel => '版本';

  @override
  String get connectionCheckedAtLabel => '已检查';

  @override
  String get connectionCapabilitiesLabel => '已启用的功能';

  @override
  String get connectionReadinessLabel => '准备情况';

  @override
  String get connectionMissingCapabilitiesLabel => '缺少所需的功能';

  @override
  String get connectionExperimentalPathsLabel => '高级工具';

  @override
  String get connectionEndpointSectionTitle => '检查结果';

  @override
  String get connectionCapabilitySectionTitle => '能力';

  @override
  String get savedProfilesTitle => '已保存的配置文件';

  @override
  String get savedProfilesSubtitle => '固定的服务器随时准备进行快速检查。';

  @override
  String get savedProfilesEmptyTitle => '尚未保存个人资料';

  @override
  String get savedProfilesEmptySubtitle => '保存工作地址，以便应用程序下次打开时使用已知的服务器目标。';

  @override
  String get recentConnectionsTitle => '最近的尝试';

  @override
  String get recentConnectionsSubtitle => '最近的服务器检查与固定服务器分开。';

  @override
  String get recentConnectionsEmptyTitle => '最近还没有尝试过';

  @override
  String get recentConnectionsEmptySubtitle => '检查服务器，最新结果将保留在这里以便快速重试。';

  @override
  String get connectionOutcomeReady => '准备连接';

  @override
  String get connectionOutcomeAuthFailure => '认证失败';

  @override
  String get connectionOutcomeSpecFailure => '规格获取失败';

  @override
  String get connectionOutcomeUnsupported => '不支持的功能集';

  @override
  String get connectionOutcomeConnectivityFailure => '连接失败';

  @override
  String get connectionDetailReady => '核心服务做出了回应，家庭现在可以提供项目选择。';

  @override
  String get connectionDetailAuthFailure => '服务器响应，但提供的登录详细信息被拒绝。';

  @override
  String get connectionDetailBasicAuthFailure =>
      '该服务器受基本身份验证保护。添加或更新用户名和密码，然后重试。';

  @override
  String get connectionDetailSpecFailure => '服务器可以访问，但无法干净地获取或解析 OpenAPI 规范。';

  @override
  String get connectionDetailUnsupported => '服务器可以访问，但仍然缺少此应用程序所需的功能。';

  @override
  String get connectionDetailConnectivityFailure => '无法足够可靠地到达服务器以完成检查。';

  @override
  String get endpointReadyStatus => '准备好';

  @override
  String get endpointAuthStatus => '授权';

  @override
  String get endpointUnsupportedStatus => '不支持的';

  @override
  String get endpointFailureStatus => '失败';

  @override
  String get endpointUnknownStatus => '未知';

  @override
  String get fixtureDiagnosticsTitle => '诊断';

  @override
  String get fixtureDiagnosticsSubtitle => '连接检查和状态详细信息位于此处。';

  @override
  String get capabilityCanShareSession => '分享会';

  @override
  String get capabilityCanForkSession => '派生会话';

  @override
  String get capabilityCanSummarizeSession => '总结会议';

  @override
  String get capabilityCanRevertSession => '恢复会话';

  @override
  String get capabilityHasQuestions => '问题';

  @override
  String get capabilityHasPermissions => '权限';

  @override
  String get capabilityHasExperimentalTools => '高级工具';

  @override
  String get capabilityHasProviderOAuth => '提供商 OAuth';

  @override
  String get capabilityHasMcpAuth => 'MCP 授权';

  @override
  String get capabilityHasTuiControl => '途易控制';

  @override
  String get projectSelectionTitle => '选择一个项目';

  @override
  String get projectSelectionSubtitle => '从此服务器打开项目、您最近的工作或文件夹路径。';

  @override
  String get currentProjectTitle => '当前项目';

  @override
  String get currentProjectSubtitle => '如果服务器已位于项目内，则它首先出现在此处。';

  @override
  String get serverProjectsTitle => '此服务器上的项目';

  @override
  String get serverProjectsSubtitle => '服务器现在可以打开其他项目。';

  @override
  String get serverProjectsEmpty => '目前没有可用的服务器项目。您仍然可以打开最近的项目或文件夹路径。';

  @override
  String get manualProjectTitle => '打开文件夹路径';

  @override
  String get manualProjectSubtitle => '当服务器列表为空或者您确切知道所需的文件夹时，请使用此选项。';

  @override
  String get manualProjectPathLabel => '项目目录';

  @override
  String get manualProjectPathHint => '/工作区/我的项目';

  @override
  String get projectInspectAction => '检查路径';

  @override
  String get projectInspectingAction => '正在检查...';

  @override
  String get projectBrowseAction => '浏览文件夹';

  @override
  String get projectPathSuggestionsLoading => '正在搜索服务器文件夹...';

  @override
  String get projectPathSuggestionsEmpty => '在此服务器上找不到匹配的文件夹。';

  @override
  String get recentProjectsTitle => '最近的项目';

  @override
  String get recentProjectsSubtitle => '您最近打开的项目，以及我们获得它们时的上次会话提示。';

  @override
  String get pinnedProjectsTitle => '固定项目';

  @override
  String get pinnedProjectsSubtitle => '本地收藏夹保留在顶部，以便快速移动访问。';

  @override
  String get projectFilterLabel => '筛选项目';

  @override
  String get projectFilterHint => '名称、文件夹、分支或会话';

  @override
  String get projectFilterEmpty => '没有项目匹配此过滤器。';

  @override
  String get recentProjectsEmpty => '还没有最近的项目。';

  @override
  String get projectPreviewTitle => '项目详情';

  @override
  String get projectPreviewSubtitle => '在打开下一个工作区之前查看它。';

  @override
  String get projectPreviewEmpty => '选择项目、最近的工作空间或文件夹路径以在此处查看详细信息。';

  @override
  String get projectDirectoryLabel => '目录';

  @override
  String get projectSourceLabel => '来源';

  @override
  String get projectVcsLabel => 'VCS';

  @override
  String get projectBranchLabel => '分支';

  @override
  String get projectLastSessionLabel => '最后一次会议';

  @override
  String get projectLastStatusLabel => '最后状态';

  @override
  String get projectLastSessionUnknown => '尚未捕获';

  @override
  String get projectLastStatusUnknown => '尚未捕获';

  @override
  String get projectSelectionReadyHint => '打开该项目以继续其会话。';

  @override
  String get homeHeaderEyebrow => '工作空间';

  @override
  String get homeHeaderSubtitle => '连接服务器，然后打开项目并继续您的会话。';

  @override
  String get homeAddServerAction => '添加服务器';

  @override
  String get homeBackToServersAction => '返回服务器';

  @override
  String get homeConnectServerAction => '连接';

  @override
  String get homeEditSelectedServerAction => '编辑选定的服务器';

  @override
  String get homeEditServerAction => '编辑服务器';

  @override
  String get homeSwitchServerAction => '切换服务器';

  @override
  String get homeNextStepsTitle => '后续步骤';

  @override
  String get homeNextStepsPinnedServers => '固定您最常使用的服务器，使它们保持在顶部。';

  @override
  String get homeNextStepsProjects => '服务器准备就绪后，打开项目并跳转到会话。';

  @override
  String get homeNextStepsRetryEdit => '足不出户即可重试或编辑服务器。';

  @override
  String get homeMetricSavedServers => '已保存的服务器';

  @override
  String get homeMetricRecentActivity => '最近的活动';

  @override
  String get homeMetricCurrentFocus => '当前服务器';

  @override
  String get homeChooseServerLabel => '选择服务器';

  @override
  String get homeResumeLastWorkspaceTitle => '恢复上一个工作区';

  @override
  String get homeOpenLastProjectTitle => '打开最后一个项目';

  @override
  String homeResumeLastWorkspaceBody(String project) {
    return '继续 $project 并从上次停下的地方继续。';
  }

  @override
  String homeOpenLastProjectBody(String project) {
    return '打开 $project，然后选择一个会话或开始一个新会话。';
  }

  @override
  String get homeResumeLastWorkspaceAction => '恢复工作区';

  @override
  String get homeOpenLastProjectAction => '打开项目';

  @override
  String get homeResumeMetricProject => '项目';

  @override
  String get homeResumeMetricLastSession => '最后一次会议';

  @override
  String get homeResumeMetricStatus => '地位';

  @override
  String get homeActionCheckingWorkspace => '正在检查工作区...';

  @override
  String get homeActionContinue => '继续';

  @override
  String get homeActionRetry => '重试';

  @override
  String get homeActionCheckingServer => '正在检查服务器...';

  @override
  String get homeThisServerLabel => '这个服务器';

  @override
  String get homeWorkspaceSectionTitle => '项目和会议';

  @override
  String get homeWorkspaceLoadingSubtitle => '加载您保存的服务器和最近的活动。';

  @override
  String get homeWorkspaceSelectionHint => '从列表中选择一台服务器或添加新服务器。';

  @override
  String get homeWorkspaceConnectHint => '连接所选服务器以加载其项目。';

  @override
  String get homeWorkspaceEmptySubtitle => '添加服务器以在此处开始打开项目和会话。';

  @override
  String get homeWorkspaceFeatureSaveTitle => '保存服务器一次';

  @override
  String get homeWorkspaceFeatureSaveBody => '将服务器放在一处，以便您回来时做好准备。';

  @override
  String get homeWorkspaceFeatureChooseTitle => '接下来打开一个项目';

  @override
  String get homeWorkspaceFeatureChooseBody => '服务器准备就绪后，选择一个项目并继续。';

  @override
  String get homeWorkspaceFeatureRecentTitle => '保留最近的记录';

  @override
  String get homeWorkspaceFeatureRecentBody => '保存的服务器和最近的检查一起显示在一个屏幕上。';

  @override
  String get homeWorkspaceSubtitleReady => '选择一个项目继续。';

  @override
  String get homeWorkspaceSubtitleSignIn => '更新登录详细信息或在项目加载之前重试。';

  @override
  String get homeWorkspaceSubtitleOffline => '重试该服务器或确认保存的地址。';

  @override
  String get homeWorkspaceSubtitleUpdate => '在项目加载之前更新服务器。';

  @override
  String get homeWorkspaceSubtitleUnknown => '在加载项目之前运行快速检查。';

  @override
  String get homeWorkspaceTitleChooseServer => '选择已保存的服务器';

  @override
  String homeWorkspaceTitleChecking(String server) {
    return '检查 $server';
  }

  @override
  String get homeWorkspaceTitleReady => '准备好项目';

  @override
  String get homeWorkspaceTitleSignInRequired => '需要登录';

  @override
  String get homeWorkspaceTitleOffline => '离线';

  @override
  String get homeWorkspaceTitleUpdate => '需要更新';

  @override
  String get homeWorkspaceTitleContinueFromHome => '从家里继续';

  @override
  String get homeWorkspaceBodyChecking => '在加载项目和会话之前检查登录和兼容性。';

  @override
  String homeWorkspaceBodyReady(String server) {
    return '$server 已准备就绪，但项目列表仍在加载中。';
  }

  @override
  String homeWorkspaceBodySignInRequired(String server) {
    return '$server 已回复，但在加载项目之前需要注意登录详细信息。';
  }

  @override
  String homeWorkspaceBodyBasicAuthRequired(String server) {
    return '$server 受基本身份验证保护。在加载项目之前编辑此服务器并添加用户名和密码。';
  }

  @override
  String homeWorkspaceBodyOffline(String server) {
    return '刚才无法联系 $server。重试，或编辑已保存的地址（如果已更改）。';
  }

  @override
  String homeWorkspaceBodyUpdateRequired(String server) {
    return '$server 已回复，但需要更新才能加载项目。';
  }

  @override
  String get homeWorkspaceBodyUnknown => '运行快速检查，然后仅在登录或需要注意地址时编辑详细信息。';

  @override
  String get homeNoticeWorkspaceUnavailable => '您的最后一个工作区不再可用。选择一个项目继续。';

  @override
  String get homeNoticeWorkspaceResumeFailed =>
      '目前无法重新打开您的上一个工作区。选择下面的项目或重试该服务器。';

  @override
  String get homeSavedServersTitle => '已保存的服务器';

  @override
  String get homeSavedServersSubtitle => '选择一个服务器，然后继续进行项目和会话。';

  @override
  String get homeServerPanelSubtitle => '添加服务器，编辑保存的详细信息，然后在准备好后进行连接。';

  @override
  String get homeSavedServersEmptyTitle => '还没有保存的服务器';

  @override
  String get homeSavedServersEmptySubtitle => '添加您的第一台服务器以开始打开项目和会话。';

  @override
  String get homeRecentActivityTitle => '最近的活动';

  @override
  String get homeRecentActivitySubtitle => '您最近检查的服务器的快速记录。';

  @override
  String get homeRecentActivityEmptyTitle => '最近还没有活动';

  @override
  String get homeRecentActivityEmptySubtitle => '连接或重试服务器后，最近的检查会显示在此处。';

  @override
  String get homeRecentActivityNotUsed => '尚未使用';

  @override
  String homeRecentActivityLastUsed(String timestamp) {
    return '最后使用 $timestamp';
  }

  @override
  String get homeCredentialsSaved => '凭证已保存';

  @override
  String get homeCredentialsMissing => '未保存凭据';

  @override
  String get homeServerCardBodyReady => '准备好在家打开项目和会议。';

  @override
  String get homeServerCardBodySignIn => '在加载项目之前重试或更新登录详细信息。';

  @override
  String get homeServerCardBodyBasicAuthRequired => '该服务器加载项目之前需要进行基本身份验证。';

  @override
  String get homeServerCardBodyOffline => '重试，或编辑保存的地址，然后再继续。';

  @override
  String get homeServerCardBodyUpdate => '在继续项目和会话之前更新服务器。';

  @override
  String get homeServerCardBodyUnknownWithAuth => '在加载项目之前运行快速检查。';

  @override
  String get homeServerCardBodyUnknown => '运行快速检查，然后仅在需要登录时编辑详细信息。';

  @override
  String homeConnectionFailedNotice(String server) {
    return '无法连接到 $server。检查保存的地址或凭据，然后重试。';
  }

  @override
  String get homeConnectionNeedsCredentialsNotice => '该服务器需要用户名和密码才能连接。';

  @override
  String get homeStatusNewHome => '新家';

  @override
  String get homeStatusChooseServer => '选择服务器';

  @override
  String get homeStatusCheckingServer => '检查服务器';

  @override
  String get homeStatusReadyForProjects => '准备好项目';

  @override
  String get homeStatusSignInRequired => '需要登录';

  @override
  String get homeStatusServerOffline => '服务器离线';

  @override
  String get homeStatusNeedsAttention => '需要注意';

  @override
  String get homeStatusAwaitingSetup => '等待设置';

  @override
  String get homeHeroTitleNoServers => '从服务器开始';

  @override
  String get homeHeroTitleOneServer => '您的服务器已准备就绪';

  @override
  String get homeHeroTitleManyServers => '您的所有服务器都集中在一处';

  @override
  String get homeHeroBodyNoServers => '添加服务器一次，然后返回此处打开项目并继续会话。';

  @override
  String get homeHeroBodyOneServer => '从家里继续，仅在发生变化时打开服务器详细信息。';

  @override
  String get homeHeroBodyManyServers => '选择一个服务器，查看最近的情况，并在需要时运行快速检查。';

  @override
  String get homeA11yAddServerAction => '添加服务器';

  @override
  String get homeA11yBackToServersAction => '返回服务器选择';

  @override
  String get homeA11yEditSelectedServerAction => '编辑选定的服务器';

  @override
  String get homeA11yWorkspacePrimaryAction => '工作区主要操作';

  @override
  String get homeA11yEditServerAction => '编辑服务器';

  @override
  String get homeA11ySwitchServerAction => '切换服务器';

  @override
  String get homeA11yResumeWorkspaceAction => '恢复工作区';

  @override
  String get homeStatusShortReady => '准备好';

  @override
  String get homeStatusShortSignInRequired => '需要登录';

  @override
  String get homeStatusShortOffline => '离线';

  @override
  String get homeStatusShortNeedsAttention => '需要注意';

  @override
  String get homeStatusShortNotCheckedYet => '尚未检查';

  @override
  String get projectCatalogUnavailableTitle => '项目清单不可用';

  @override
  String get projectCatalogUnavailableBody =>
      '我们刚才无法加载该服务器的项目列表。您仍然可以打开最近的工作区或输入文件夹路径。';

  @override
  String get projectOpenAction => '打开项目';

  @override
  String get projectPinAction => '引脚项目';

  @override
  String get projectUnpinAction => '取消固定项目';

  @override
  String get shellProjectRailTitle => '项目和会议';

  @override
  String get shellDestinationSessions => '会议';

  @override
  String get shellDestinationChat => '聊天';

  @override
  String get shellDestinationContext => '语境';

  @override
  String get shellDestinationSettings => '设置';

  @override
  String get shellAdvancedLabel => '先进的';

  @override
  String get shellAdvancedSubtitle => '高级设置和故障排除工具。';

  @override
  String get shellAdvancedOverviewSubtitle => '技术选项远离主流。';

  @override
  String get shellOpenAdvancedAction => '打开高级';

  @override
  String get shellBackToSettingsAction => '返回设置';

  @override
  String get shellA11yOpenCacheSettings => '打开缓存设置';

  @override
  String get shellA11yOpenAdvanced => '打开高级设置';

  @override
  String get shellA11yBackToSettings => '返回设置';

  @override
  String get shellA11yBackToProjectsAction => '返回项目';

  @override
  String get shellA11yComposerField => '留言栏';

  @override
  String get shellA11ySendMessageAction => '发送消息';

  @override
  String get shellIntegrationsLastAuthUrlTitle => '上次授权网址';

  @override
  String get shellIntegrationsEventsSubtitle => '事件流状态和恢复详细信息。';

  @override
  String get shellStreamHealthConnected => '已连接';

  @override
  String get shellStreamHealthStale => '陈旧';

  @override
  String get shellStreamHealthReconnecting => '重新连接';

  @override
  String get shellConfigPreviewUnavailable => '配置视图目前不可用。';

  @override
  String get shellNoticeLastSessionUnavailable =>
      '您的最后一个会话不再可用。选择另一个会话或开始一个新会话。';

  @override
  String get shellConfigJsonObjectError => '配置必须是 JSON 对象。';

  @override
  String get shellRecoveryLogReconnectRequested => '请求重新连接';

  @override
  String get shellRecoveryLogReconnectCompleted => '重新连接完成';

  @override
  String get shellUnknownLabel => '未知';

  @override
  String get shellBackToProjectsAction => '返回项目';

  @override
  String get shellSessionsTitle => '会议';

  @override
  String get shellSessionCurrent => '当前会话';

  @override
  String get shellSessionDraft => '草案分支';

  @override
  String get shellSessionReview => '审查分支';

  @override
  String get shellStatusActive => '积极的';

  @override
  String get shellStatusIdle => '闲置的';

  @override
  String get shellStatusError => '错误';

  @override
  String get shellChatHeaderTitle => '聊天工作区';

  @override
  String get shellThinkingModeLabel => '平衡思维';

  @override
  String get shellAgentLabel => '智能体';

  @override
  String get shellChatTimelineTitle => '对话';

  @override
  String get shellUserMessageTitle => '你';

  @override
  String get shellUserMessageBody => '选择一个会话，然后发送消息即可开始。';

  @override
  String get shellAssistantMessageTitle => '开放代码';

  @override
  String get shellAssistantMessageBody => '你在工作区。查看背景、选择会话并继续工作。';

  @override
  String get shellComposerPlaceholder => '写留言';

  @override
  String get shellComposerSendAction => '发送';

  @override
  String get shellComposerCreatingSession => '创建会话并发送';

  @override
  String get shellComposerSending => '正在发送...';

  @override
  String get shellComposerModelLabel => '模型';

  @override
  String get shellComposerModelDefault => '服务器默认';

  @override
  String get shellComposerThinkingLabel => '思维';

  @override
  String get shellComposerThinkingLow => '光';

  @override
  String get shellComposerThinkingBalanced => '均衡';

  @override
  String get shellComposerThinkingDeep => '深的';

  @override
  String get shellComposerThinkingMax => '最大限度';

  @override
  String get shellRenameSessionTitle => '重命名会话';

  @override
  String get shellSessionTitleHint => '会议标题';

  @override
  String get shellCancelAction => '取消';

  @override
  String get shellSaveAction => '节省';

  @override
  String get shellContextTitle => '上下文实用程序';

  @override
  String get shellFilesTitle => '文件';

  @override
  String get shellFilesSubtitle => '树、状态和搜索都在这里。';

  @override
  String get shellDiffTitle => '差异';

  @override
  String get shellDiffSubtitle => '补丁和快照审查显示在此处。';

  @override
  String get shellTodoTitle => '托多';

  @override
  String get shellTodoSubtitle => '任务进度和历史记录在这里可见。';

  @override
  String get shellToolsTitle => '工具';

  @override
  String get shellToolsSubtitle => '此工作区的有用工具。';

  @override
  String get shellTerminalTitle => '终端';

  @override
  String get shellTerminalSubtitle => '快速 shell 和附加流落在此处。';

  @override
  String get shellInspectorTitle => '督察';

  @override
  String get shellConfigTitle => '配置';

  @override
  String get shellConfigInvalid => '无效的配置';

  @override
  String get shellConfigDraftEmpty => '配置草案为空。';

  @override
  String shellConfigChangedKeys(int count) {
    return '更改的键：$count';
  }

  @override
  String get shellConfigApplying => '正在申请...';

  @override
  String get shellConfigApplyAction => '应用配置';

  @override
  String get shellIntegrationsTitle => '集成';

  @override
  String get shellIntegrationsProviders => '供应商';

  @override
  String get shellIntegrationsMethods => '方法';

  @override
  String get shellIntegrationsStartProviderAuth => '启动提供商身份验证';

  @override
  String get shellIntegrationsMcp => 'MCP';

  @override
  String get shellIntegrationsStartMcpAuth => '启动 MCP 身份验证';

  @override
  String get shellIntegrationsLsp => 'LSP';

  @override
  String get shellIntegrationsFormatter => '格式化程序';

  @override
  String get shellIntegrationsEnabled => '已启用';

  @override
  String get shellIntegrationsDisabled => '残疾人';

  @override
  String get shellIntegrationsRecentEvents => '近期活动';

  @override
  String get shellIntegrationsStreamHealth => '流健康状况';

  @override
  String get shellIntegrationsRecoveryLog => '恢复日志';

  @override
  String get shellWorkspaceEyebrow => '工作空间';

  @override
  String get shellSessionsEyebrow => '会议';

  @override
  String get shellControlsEyebrow => '控制';

  @override
  String get shellActionsTitle => '行动';

  @override
  String get shellActionFork => '叉';

  @override
  String get shellActionShare => '分享';

  @override
  String get shellActionUnshare => '取消分享';

  @override
  String get shellActionRename => '重命名';

  @override
  String get shellActionDelete => '删除';

  @override
  String get shellActionAbort => '中止';

  @override
  String get shellActionRevert => '恢复';

  @override
  String get shellActionUnrevert => '取消恢复';

  @override
  String get shellActionInit => '初始化';

  @override
  String get shellActionSummarize => '总结';

  @override
  String get shellPrimaryEyebrow => '基本的';

  @override
  String get shellTimelineEyebrow => '时间轴';

  @override
  String get shellFocusedThreadEyebrow => '聚焦线程';

  @override
  String get shellNewSessionDraft => '新会议草案';

  @override
  String shellTimelinePartsInFocus(int count) {
    return '$count 时间轴部分处于焦点';
  }

  @override
  String get shellReadyToStart => '准备开始';

  @override
  String get shellLiveContext => '实时背景';

  @override
  String shellPartsCount(int count) {
    return '$count 零件';
  }

  @override
  String get shellFocusedThreadSubtitle => '专注于活动线程';

  @override
  String get shellConversationSubtitle => '以较长形式的阅读和回复写作为中心';

  @override
  String get shellConnectionIssueTitle => '连接问题';

  @override
  String get shellUtilitiesEyebrow => '公用事业';

  @override
  String get shellFilesSearchHint => '搜索文件、文本或符号';

  @override
  String get shellPreviewTitle => '预览';

  @override
  String get shellCurrentSelection => '当前选择';

  @override
  String get shellMatchesTitle => '火柴';

  @override
  String get shellMatchesSubtitle => '相关文字结果';

  @override
  String get shellSymbolsTitle => '符号';

  @override
  String get shellSymbolsSubtitle => '快速代码地标';

  @override
  String get shellTerminalHint => '密码';

  @override
  String get shellTerminalRunAction => '运行命令';

  @override
  String get shellTerminalRunning => '跑步...';

  @override
  String get shellTrackedLabel => '被跟踪的';

  @override
  String get shellPendingApprovalsTitle => '待批准';

  @override
  String shellPendingApprovalsSubtitle(int count) {
    return '$count 项等待输入';
  }

  @override
  String get shellAllowOnceAction => '允许一次';

  @override
  String get shellRejectAction => '拒绝';

  @override
  String get shellAnswerAction => '回答';

  @override
  String get shellConfigPreviewSubtitle => '查看和编辑配置';

  @override
  String get shellInspectorSubtitle => '会话和消息元数据快照';

  @override
  String get shellIntegrationsLspSubtitle => '语言服务器准备情况';

  @override
  String get shellIntegrationsFormatterSubtitle => '格式化可用性';

  @override
  String get shellActionsSubtitle => '会话控制和生命周期操作';

  @override
  String shellActiveCount(int count) {
    return '$count 活跃';
  }

  @override
  String shellThreadsCount(int count) {
    return '$count 跨当前项目的线程';
  }

  @override
  String get chatPartAssistant => '助手';

  @override
  String get chatPartUser => '用户';

  @override
  String get chatPartThinking => '思维';

  @override
  String get chatPartTool => '工具';

  @override
  String chatPartToolNamed(String name) {
    return '工具：$name';
  }

  @override
  String get chatPartFile => '文件';

  @override
  String get chatPartStepStart => '步骤开始';

  @override
  String get chatPartStepFinish => '步骤完成';

  @override
  String get chatPartSnapshot => '快照';

  @override
  String get chatPartPatch => '修补';

  @override
  String get chatPartRetry => '重试';

  @override
  String get chatPartAgent => '智能体';

  @override
  String get chatPartSubtask => '子任务';

  @override
  String get chatPartCompaction => '压实';

  @override
  String get shellUtilitiesToggleTitle => '实用抽屉';

  @override
  String get shellUtilitiesToggleBody =>
      '打开底部实用程序抽屉以检查纵向布局上的文件、差异、待办事项、工具和终端面板。';

  @override
  String get shellUtilitiesToggleBodyCompact =>
      '打开实用程序以在文件、差异、待办事项、工具和终端面板之间切换。';

  @override
  String get shellContextEyebrow => '语境';

  @override
  String get shellSecondaryContextSubtitle => '活跃对话的次要背景';

  @override
  String get shellSupportRailsSubtitle => '文件、任务、命令和集成的支持轨';

  @override
  String shellModulesCount(int count) {
    return '$count 模块';
  }

  @override
  String get shellSwipeUtilitiesIntoView => '将实用程序滑入视图';

  @override
  String get shellOpenUtilityRail => '打开公用导轨';

  @override
  String get shellOpenCodeRemote => '中国银行';

  @override
  String get shellContextNearby => '附近的环境';

  @override
  String shellShownCount(int count) {
    return '显示 $count';
  }

  @override
  String get shellSymbolFallback => '象征';

  @override
  String shellFileStatusSummary(String status, int added, int removed) {
    return '$status +$added -$removed';
  }

  @override
  String get shellNewSession => '新会话';

  @override
  String get shellReplying => '正在回复';

  @override
  String get shellCompactComposer => '紧凑型编写器';

  @override
  String get shellExpandedComposer => '扩展编写器';

  @override
  String shellRetryAttempt(int count) {
    return '尝试 $count';
  }

  @override
  String shellStatusWithDetails(String status, String details) {
    return '$status - $details';
  }

  @override
  String get shellTodoStatusInProgress => '进行中';

  @override
  String get shellTodoStatusPending => '待办的';

  @override
  String get shellTodoStatusCompleted => '完全的';

  @override
  String get shellTodoStatusUnknown => '未知';

  @override
  String get shellQuestionAskedNotification => '提出问题';

  @override
  String get shellPermissionAskedNotification => '请求许可';

  @override
  String get shellNotificationOpenAction => '打开';

  @override
  String chatPartUnknown(String type) {
    return '未知部分：$type';
  }
}
