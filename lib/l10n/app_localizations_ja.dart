// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'より良いオープンコードクライアント (BOC)';

  @override
  String get foundationTitle => '基礎ワークスペース';

  @override
  String get foundationSubtitle => 'サーバーに接続する前に、組み込みのチェックとライブ アップデートの準備が整います。';

  @override
  String get currentFlavor => '風味';

  @override
  String get currentLocale => 'ロケール';

  @override
  String get fullCapabilityProbe => 'サーバーの完全チェック';

  @override
  String get legacyCapabilityProbe => '互換性チェック';

  @override
  String get probeErrorCapability => 'エラー処理を確認してください';

  @override
  String get healthyStream => '健全な流れ';

  @override
  String get staleStream => '古いストリームの回復';

  @override
  String get duplicateStream => '重複イベントの処理';

  @override
  String get resyncStream => '再同期が必要です';

  @override
  String get capabilityFlags => '機能フラグ';

  @override
  String get streamFrames => 'ストリームフレーム';

  @override
  String get unknownFields => '不明なフィールドが保存される';

  @override
  String get switchLocale => 'ロケールを切り替える';

  @override
  String get cacheSettingsAction => 'キャッシュ設定';

  @override
  String get cacheSettingsTitle => 'キャッシュ設定';

  @override
  String get cacheSettingsSubtitle =>
      'キャッシュの鮮度を調整し、保存された接続チェックとワークスペースのスナップショットをクリアします。';

  @override
  String get cacheTtlLabel => 'キャッシュの鮮度';

  @override
  String get cacheClearAction => 'キャッシュされたデータをクリアする';

  @override
  String get cacheClearingAction => 'キャッシュをクリアしています...';

  @override
  String get cacheTtl15Seconds => '15秒';

  @override
  String get cacheTtl1Minute => '1分';

  @override
  String get cacheTtl5Minutes => '5分';

  @override
  String get cacheTtl15Minutes => '15分';

  @override
  String get connectionTitle => 'サーバー接続マネージャー';

  @override
  String get connectionSubtitle =>
      '信頼できる OpenCode サーバーを保存し、必要に応じてサーバー チェックを実行し、ホームに戻ってプロジェクトを選択します。';

  @override
  String get serverProfileManager => 'サーバープロファイルマネージャー';

  @override
  String get connectionProfileHint =>
      '信頼できるホストには保存されたプロファイルを使用し、高速な再試行には最近の試行を使用します。';

  @override
  String get profileLabel => 'プロファイルラベル';

  @override
  String get serverAddress => 'サーバーアドレス';

  @override
  String get username => 'ユーザー名';

  @override
  String get password => 'パスワード';

  @override
  String get testingConnection => 'テスト中...';

  @override
  String get testConnection => 'テスト接続';

  @override
  String get saveProfile => 'プロファイルの保存';

  @override
  String get deleteProfile => 'プロフィールの削除';

  @override
  String get connectionGuidance =>
      'サーバー チェックでは、健全性、互換性、サインイン、プロバイダー アクセス、およびツールの可用性を確認します。さらに多くのネットワーク検出オプションが追加される予定です。';

  @override
  String get savedServers => '保存されたサーバー';

  @override
  String get recentConnections => '最近のつながり';

  @override
  String get noSavedServers => '保存されたサーバーはまだありません。';

  @override
  String get noRecentConnections => '最近の試みはまだありません。';

  @override
  String get connectionDiagnostics => '接続診断';

  @override
  String get connectionDiagnosticsHint =>
      'ワークスペースを開く前に、サーバー チェックを実行してサインインと互換性を確認します。';

  @override
  String get serverVersion => 'バージョン';

  @override
  String get sseStatus => 'ライブアップデート';

  @override
  String get readyStatus => '準備ができて';

  @override
  String get needsAttentionStatus => '注意が必要です';

  @override
  String get connectionEmptyState => 'サーバー プロファイルを入力し、サーバー チェックを実行して診断を入力します。';

  @override
  String get connectionHeaderEyebrow => 'ライブサーバー接続';

  @override
  String get connectionHeaderTitle => '実際の OpenCode サーバーに接続する';

  @override
  String get connectionHeaderSubtitle =>
      '保存されたサーバーの詳細を確認し、サインインを確認し、このサーバーの準備ができたらワークスペースのホームに戻ります。';

  @override
  String get connectionStatusAwaiting => '最初のチェック待ち';

  @override
  String get connectionFormTitle => 'サーバープロファイルマネージャー';

  @override
  String get connectionFormSubtitle =>
      '保存されたサーバーの詳細を更新し、チェックを再試行して、このプロファイルを自宅で使用できるようにしておいてください。';

  @override
  String get savedProfilesCountLabel => '保存されました';

  @override
  String get recentConnectionsCountLabel => '最近の';

  @override
  String get sseReadyLabel => 'ライブアップデートの準備完了';

  @override
  String get ssePendingLabel => 'チェック保留中';

  @override
  String get connectionProfileLabel => 'プロファイル名';

  @override
  String get connectionProfileLabelHint => 'スタジオステージング、ラップトップトンネル、オンプレミスゲートウェイ';

  @override
  String get connectionAddressLabel => 'サーバーアドレス';

  @override
  String get connectionAddressHint => 'https://opencode.example.com';

  @override
  String get connectionUsernameLabel => '基本認証ユーザー名';

  @override
  String get connectionUsernameHint => 'オプション';

  @override
  String get connectionPasswordLabel => '基本認証パスワード';

  @override
  String get connectionPasswordHint => 'オプション';

  @override
  String get connectionAddressValidation => '有効なサーバー アドレスを入力してください。';

  @override
  String get connectionBackHomeAction => '家に戻る';

  @override
  String get connectionProbeAction => 'サーバーをチェックする';

  @override
  String get connectionSaveAction => 'プロファイルの保存';

  @override
  String get connectionDraftRestoredLabel => '保存されていないドラフトを復元しました';

  @override
  String get connectionPinProfileAction => 'ピンプロファイル';

  @override
  String get connectionUnpinProfileAction => 'プロフィールの固定を解除する';

  @override
  String get connectionProbeResultTitle => 'サーバーチェック';

  @override
  String get connectionProbeResultSubtitle =>
      'この詳細ビューを使用して、保存されたサーバーがまだ応答しているかどうかを確認します。プロジェクトの選択はワークスペース ホームから行われます。';

  @override
  String get connectionProbeEmptyTitle => '最近のチェックはまだありません';

  @override
  String get connectionProbeEmptySubtitle =>
      'ワークスペースのホームに戻る前に、サーバー チェックを実行してサインインと互換性を確認します。';

  @override
  String get connectionVersionLabel => 'バージョン';

  @override
  String get connectionCheckedAtLabel => 'チェック済み';

  @override
  String get connectionCapabilitiesLabel => '有効な機能';

  @override
  String get connectionReadinessLabel => '準備完了';

  @override
  String get connectionMissingCapabilitiesLabel => '必要な機能が不足している';

  @override
  String get connectionExperimentalPathsLabel => '高度なツール';

  @override
  String get connectionEndpointSectionTitle => 'チェック結果';

  @override
  String get connectionCapabilitySectionTitle => '能力';

  @override
  String get savedProfilesTitle => '保存されたプロファイル';

  @override
  String get savedProfilesSubtitle => 'ピン留めされたサーバーは、迅速なチェックの準備ができています。';

  @override
  String get savedProfilesEmptyTitle => '保存されたプロファイルはまだありません';

  @override
  String get savedProfilesEmptySubtitle =>
      '次回アプリが既知のサーバーターゲットで開くように、作業アドレスを保存します。';

  @override
  String get recentConnectionsTitle => '最近の試み';

  @override
  String get recentConnectionsSubtitle => '最近のサーバー チェック。固定されたサーバーとは別に保持されます。';

  @override
  String get recentConnectionsEmptyTitle => '最近の試みはまだありません';

  @override
  String get recentConnectionsEmptySubtitle =>
      'サーバーをチェックすると、すぐに再試行できるように最新の結果がここに表示されます。';

  @override
  String get connectionOutcomeReady => '接続の準備ができました';

  @override
  String get connectionOutcomeAuthFailure => '認証失敗';

  @override
  String get connectionOutcomeSpecFailure => '仕様の取得に失敗しました';

  @override
  String get connectionOutcomeUnsupported => 'サポートされていない機能セット';

  @override
  String get connectionOutcomeConnectivityFailure => '接続障害';

  @override
  String get connectionDetailReady => 'コアサービスが応答し、自宅でプロジェクトの選択肢を提供できるようになりました。';

  @override
  String get connectionDetailAuthFailure =>
      'サーバーは応答しましたが、提供されたサインインの詳細は拒否されました。';

  @override
  String get connectionDetailBasicAuthFailure =>
      'このサーバーは基本認証によって保護されています。ユーザー名とパスワードを追加または更新して、再試行してください。';

  @override
  String get connectionDetailSpecFailure =>
      'サーバーにはアクセスできますが、OpenAPI 仕様を取得または解析できませんでした。';

  @override
  String get connectionDetailUnsupported =>
      'サーバーにはアクセスできますが、このアプリに必要な機能がまだありません。';

  @override
  String get connectionDetailConnectivityFailure =>
      'チェックを完了するのに十分な信頼性でサーバーにアクセスできませんでした。';

  @override
  String get endpointReadyStatus => '準備ができて';

  @override
  String get endpointAuthStatus => '認証';

  @override
  String get endpointUnsupportedStatus => 'サポートされていない';

  @override
  String get endpointFailureStatus => '失敗';

  @override
  String get endpointUnknownStatus => '未知';

  @override
  String get fixtureDiagnosticsTitle => '診断';

  @override
  String get fixtureDiagnosticsSubtitle => '接続チェックとステータスの詳細はここにあります。';

  @override
  String get capabilityCanShareSession => 'セッションを共有する';

  @override
  String get capabilityCanForkSession => 'セッションをフォーク';

  @override
  String get capabilityCanSummarizeSession => 'セッションを要約する';

  @override
  String get capabilityCanRevertSession => 'セッションを元に戻す';

  @override
  String get capabilityHasQuestions => '質問';

  @override
  String get capabilityHasPermissions => '権限';

  @override
  String get capabilityHasExperimentalTools => '高度なツール';

  @override
  String get capabilityHasProviderOAuth => 'プロバイダーOAuth';

  @override
  String get capabilityHasMcpAuth => 'MCP認証';

  @override
  String get capabilityHasTuiControl => 'TUI制御';

  @override
  String get projectSelectionTitle => 'プロジェクトを選択してください';

  @override
  String get projectSelectionSubtitle =>
      'このサーバーからプロジェクト、最近の作業、またはフォルダー パスを開きます。';

  @override
  String get currentProjectTitle => '現在のプロジェクト';

  @override
  String get currentProjectSubtitle => 'サーバーがすでにプロジェクト内にある場合は、最初にここに表示されます。';

  @override
  String get serverProjectsTitle => 'このサーバー上のプロジェクト';

  @override
  String get serverProjectsSubtitle => 'サーバーが現在開くことができる他のプロジェクト。';

  @override
  String get serverProjectsEmpty =>
      '現在利用可能なサーバー プロジェクトはありません。最近のプロジェクトまたはフォルダー パスを開くことはできます。';

  @override
  String get manualProjectTitle => 'フォルダーのパスを開く';

  @override
  String get manualProjectSubtitle =>
      'これは、サーバー リストが空の場合、または必要なフォルダーが正確にわかっている場合に使用します。';

  @override
  String get manualProjectPathLabel => 'プロジェクトディレクトリ';

  @override
  String get manualProjectPathHint => '/ワークスペース/私のプロジェクト';

  @override
  String get projectInspectAction => 'パスの検査';

  @override
  String get projectInspectingAction => '検査中...';

  @override
  String get projectBrowseAction => 'フォルダを参照する';

  @override
  String get projectPathSuggestionsLoading => 'サーバーフォルダーを検索しています...';

  @override
  String get projectPathSuggestionsEmpty => 'このサーバーには一致するフォルダーが見つかりません。';

  @override
  String get recentProjectsTitle => '最近のプロジェクト';

  @override
  String get recentProjectsSubtitle =>
      '最近開いたプロジェクト。最新セッションのヒントがある場合はそれも表示されます。';

  @override
  String get pinnedProjectsTitle => '固定されたプロジェクト';

  @override
  String get pinnedProjectsSubtitle => '地元のお気に入りが常に上位に表示され、モバイルから簡単にアクセスできます。';

  @override
  String get projectFilterLabel => 'プロジェクトをフィルタリングする';

  @override
  String get projectFilterHint => '名前、フォルダー、ブランチ、またはセッション';

  @override
  String get projectFilterEmpty => 'このフィルターに一致するプロジェクトはありません。';

  @override
  String get recentProjectsEmpty => '最近のプロジェクトはまだありません。';

  @override
  String get projectPreviewTitle => 'プロジェクトの詳細';

  @override
  String get projectPreviewSubtitle => '次のワークスペースを開く前に確認してください。';

  @override
  String get projectPreviewEmpty =>
      'プロジェクト、最近のワークスペース、またはフォルダー パスを選択すると、ここで詳細が表示されます。';

  @override
  String get projectDirectoryLabel => 'ディレクトリ';

  @override
  String get projectSourceLabel => 'ソース';

  @override
  String get projectVcsLabel => 'VCS';

  @override
  String get projectBranchLabel => '支店';

  @override
  String get projectLastSessionLabel => '最後のセッション';

  @override
  String get projectLastStatusLabel => '最終ステータス';

  @override
  String get projectLastSessionUnknown => 'まだ捕まっていない';

  @override
  String get projectLastStatusUnknown => 'まだ捕まっていない';

  @override
  String get projectSelectionReadyHint => 'このプロジェクトを開いてセッションを続行します。';

  @override
  String get homeHeaderEyebrow => 'ワークスペース';

  @override
  String get homeHeaderSubtitle => 'サーバーに接続し、プロジェクトを開いてセッションを続行します。';

  @override
  String get homeAddServerAction => 'サーバーの追加';

  @override
  String get homeBackToServersAction => 'サーバーに戻る';

  @override
  String get homeConnectServerAction => '接続する';

  @override
  String get homeEditSelectedServerAction => '選択したサーバーを編集する';

  @override
  String get homeEditServerAction => 'サーバーの編集';

  @override
  String get homeSwitchServerAction => 'サーバーを切り替える';

  @override
  String get homeNextStepsTitle => '次のステップ';

  @override
  String get homeNextStepsPinnedServers => '最も使用するサーバーを固定して、上位に表示されるようにします。';

  @override
  String get homeNextStepsProjects => 'サーバーの準備ができたら、プロジェクトを開いてセッションにジャンプします。';

  @override
  String get homeNextStepsRetryEdit => '家から出ずにサーバーを再試行または編集します。';

  @override
  String get homeMetricSavedServers => '保存されたサーバー';

  @override
  String get homeMetricRecentActivity => '最近の活動';

  @override
  String get homeMetricCurrentFocus => '現在のサーバー';

  @override
  String get homeChooseServerLabel => 'サーバーを選択してください';

  @override
  String get homeResumeLastWorkspaceTitle => '最後のワークスペースを再開する';

  @override
  String get homeOpenLastProjectTitle => '最後のプロジェクトを開く';

  @override
  String homeResumeLastWorkspaceBody(String project) {
    return '$project で続行し、中断したところから再開します。';
  }

  @override
  String homeOpenLastProjectBody(String project) {
    return '$project を開き、セッションを選択するか、新しいセッションを開始します。';
  }

  @override
  String get homeResumeLastWorkspaceAction => 'ワークスペースを再開する';

  @override
  String get homeOpenLastProjectAction => 'プロジェクトを開く';

  @override
  String get homeResumeMetricProject => 'プロジェクト';

  @override
  String get homeResumeMetricLastSession => '最後のセッション';

  @override
  String get homeResumeMetricStatus => '状態';

  @override
  String get homeActionCheckingWorkspace => 'ワークスペースを確認しています...';

  @override
  String get homeActionContinue => '続く';

  @override
  String get homeActionRetry => 'リトライ';

  @override
  String get homeActionCheckingServer => 'サーバーをチェックしています...';

  @override
  String get homeThisServerLabel => 'このサーバー';

  @override
  String get homeWorkspaceSectionTitle => 'プロジェクトとセッション';

  @override
  String get homeWorkspaceLoadingSubtitle => '保存したサーバーと最近のアクティビティを読み込みます。';

  @override
  String get homeWorkspaceSelectionHint => 'リストからサーバーを選択するか、新しいサーバーを追加します。';

  @override
  String get homeWorkspaceConnectHint => '選択したサーバーに接続してプロジェクトをロードします。';

  @override
  String get homeWorkspaceEmptySubtitle =>
      'ここでサーバーを追加して、プロジェクトとセッションの開始を開始します。';

  @override
  String get homeWorkspaceFeatureSaveTitle => 'サーバーを一度保存​​する';

  @override
  String get homeWorkspaceFeatureSaveBody =>
      'サーバーを 1 か所に保管し、戻ってきたときにすぐに使えるようにします。';

  @override
  String get homeWorkspaceFeatureChooseTitle => '次にプロジェクトを開きます';

  @override
  String get homeWorkspaceFeatureChooseBody => 'サーバーの準備ができたら、プロジェクトを選択して続行します。';

  @override
  String get homeWorkspaceFeatureRecentTitle => '最近のことを常に表示しておきます';

  @override
  String get homeWorkspaceFeatureRecentBody =>
      '保存されたサーバーと最近のチェックは 1 つの画面にまとめて表示されます。';

  @override
  String get homeWorkspaceSubtitleReady => '続行するプロジェクトを選択してください。';

  @override
  String get homeWorkspaceSubtitleSignIn =>
      'サインインの詳細を更新するか、プロジェクトを読み込む前に再試行してください。';

  @override
  String get homeWorkspaceSubtitleOffline =>
      'このサーバーを再試行するか、保存されたアドレスを確認してください。';

  @override
  String get homeWorkspaceSubtitleUpdate => 'プロジェクトを読み込む前にサーバーを更新してください。';

  @override
  String get homeWorkspaceSubtitleUnknown => 'プロジェクトをロードする前に簡単なチェックを実行します。';

  @override
  String get homeWorkspaceTitleChooseServer => '保存されたサーバーを選択してください';

  @override
  String homeWorkspaceTitleChecking(String server) {
    return '$serverの確認';
  }

  @override
  String get homeWorkspaceTitleReady => 'プロジェクトの準備完了';

  @override
  String get homeWorkspaceTitleSignInRequired => 'サインインが必要です';

  @override
  String get homeWorkspaceTitleOffline => 'オフライン';

  @override
  String get homeWorkspaceTitleUpdate => 'アップデートが必要です';

  @override
  String get homeWorkspaceTitleContinueFromHome => '自宅から続ける';

  @override
  String get homeWorkspaceBodyChecking =>
      'プロジェクトとセッションを読み込む前に、サインインと互換性をチェックします。';

  @override
  String homeWorkspaceBodyReady(String server) {
    return '$server の準備は完了しましたが、プロジェクト リストはまだロード中です。';
  }

  @override
  String homeWorkspaceBodySignInRequired(String server) {
    return '$server が応答しましたが、プロジェクトを読み込む前にサインインの詳細に注意する必要があります。';
  }

  @override
  String homeWorkspaceBodyBasicAuthRequired(String server) {
    return '$server は Basic 認証によって保護されています。プロジェクトをロードする前に、このサーバーを編集し、ユーザー名とパスワードを追加してください。';
  }

  @override
  String homeWorkspaceBodyOffline(String server) {
    return '今、$server に到達できませんでした。再試行するか、保存されたアドレスが変更されている場合は編集します。';
  }

  @override
  String homeWorkspaceBodyUpdateRequired(String server) {
    return '$server は応答しましたが、プロジェクトをロードするには更新が必要です。';
  }

  @override
  String get homeWorkspaceBodyUnknown =>
      '簡単なチェックを実行し、サインインまたはアドレスに注意が必要な場合にのみ詳細を編集します。';

  @override
  String get homeNoticeWorkspaceUnavailable =>
      '最後のワークスペースは利用できなくなりました。続行するプロジェクトを選択してください。';

  @override
  String get homeNoticeWorkspaceResumeFailed =>
      '現在、最後のワークスペースを再度開くことができませんでした。以下のプロジェクトを選択するか、このサーバーを再試行してください。';

  @override
  String get homeSavedServersTitle => '保存されたサーバー';

  @override
  String get homeSavedServersSubtitle => 'サーバーを選択し、プロジェクトとセッションに進みます。';

  @override
  String get homeServerPanelSubtitle => 'サーバーを追加し、保存された詳細を編集し、準備ができたら接続します。';

  @override
  String get homeSavedServersEmptyTitle => '保存されたサーバーはまだありません';

  @override
  String get homeSavedServersEmptySubtitle =>
      '最初のサーバーを追加して、プロジェクトとセッションの開始を開始します。';

  @override
  String get homeRecentActivityTitle => '最近の活動';

  @override
  String get homeRecentActivitySubtitle => '最近チェックしたサーバーの簡単な記録。';

  @override
  String get homeRecentActivityEmptyTitle => '最近の活動はまだありません';

  @override
  String get homeRecentActivityEmptySubtitle =>
      'サーバーに接続または再試行すると、最近のチェックがここに表示されます。';

  @override
  String get homeRecentActivityNotUsed => 'まだ使用されていません';

  @override
  String homeRecentActivityLastUsed(String timestamp) {
    return '最後に使用したのは $timestamp';
  }

  @override
  String get homeCredentialsSaved => '認証情報が保存されました';

  @override
  String get homeCredentialsMissing => '認証情報が保存されていません';

  @override
  String get homeServerCardBodyReady => '自宅からプロジェクトやセッションを開く準備ができました。';

  @override
  String get homeServerCardBodySignIn =>
      '再試行するか、プロジェクトを読み込む前にサインインの詳細を更新してください。';

  @override
  String get homeServerCardBodyBasicAuthRequired =>
      'このサーバーがプロジェクトをロードするには、基本認証が必要です。';

  @override
  String get homeServerCardBodyOffline => '再試行するか、続行する前に保存されたアドレスを編集してください。';

  @override
  String get homeServerCardBodyUpdate => 'プロジェクトやセッションを続行する前に、サーバーを更新してください。';

  @override
  String get homeServerCardBodyUnknownWithAuth =>
      'プロジェクトをロードする前に簡単なチェックを実行します。';

  @override
  String get homeServerCardBodyUnknown => '簡単なチェックを実行し、サインインが必要な場合にのみ詳細を編集します。';

  @override
  String homeConnectionFailedNotice(String server) {
    return '$serverに接続できませんでした。保存されたアドレスまたは資格情報を確認して、再試行してください。';
  }

  @override
  String get homeConnectionNeedsCredentialsNotice =>
      'このサーバーは接続する前にユーザー名とパスワードが必要です。';

  @override
  String get homeStatusNewHome => '新しい家';

  @override
  String get homeStatusChooseServer => 'サーバーを選択してください';

  @override
  String get homeStatusCheckingServer => 'サーバーをチェックしています';

  @override
  String get homeStatusReadyForProjects => 'プロジェクトの準備完了';

  @override
  String get homeStatusSignInRequired => 'サインインが必要です';

  @override
  String get homeStatusServerOffline => 'サーバーがオフライン';

  @override
  String get homeStatusNeedsAttention => '注意が必要です';

  @override
  String get homeStatusAwaitingSetup => 'セットアップを待っています';

  @override
  String get homeHeroTitleNoServers => 'サーバーから始める';

  @override
  String get homeHeroTitleOneServer => 'サーバー、準備完了';

  @override
  String get homeHeroTitleManyServers => 'すべてのサーバーを 1 か所に';

  @override
  String get homeHeroBodyNoServers =>
      'サーバーを一度追加してから、ここに戻ってプロジェクトを開いてセッションを続行します。';

  @override
  String get homeHeroBodyOneServer => '自宅から続行し、何か変更があった場合にのみサーバーの詳細を開きます。';

  @override
  String get homeHeroBodyManyServers =>
      'サーバーを選択し、最新情報を表示しておき、必要に応じて簡単なチェックを実行します。';

  @override
  String get homeA11yAddServerAction => 'サーバーの追加';

  @override
  String get homeA11yBackToServersAction => 'サーバーの選択に戻る';

  @override
  String get homeA11yEditSelectedServerAction => '選択したサーバーを編集する';

  @override
  String get homeA11yWorkspacePrimaryAction => 'ワークスペースの主なアクション';

  @override
  String get homeA11yEditServerAction => 'サーバーの編集';

  @override
  String get homeA11ySwitchServerAction => 'サーバーを切り替える';

  @override
  String get homeA11yResumeWorkspaceAction => 'ワークスペースを再開する';

  @override
  String get homeStatusShortReady => '準備ができて';

  @override
  String get homeStatusShortSignInRequired => 'サインインが必要です';

  @override
  String get homeStatusShortOffline => 'オフライン';

  @override
  String get homeStatusShortNeedsAttention => '注意が必要です';

  @override
  String get homeStatusShortNotCheckedYet => 'まだチェックされていません';

  @override
  String get projectCatalogUnavailableTitle => 'プロジェクトリストは利用できません';

  @override
  String get projectCatalogUnavailableBody =>
      '今、このサーバーのプロジェクト リストをロードできませんでした。最近使用したワークスペースを開いたり、フォルダー パスを入力したりすることはできます。';

  @override
  String get projectOpenAction => 'プロジェクトを開く';

  @override
  String get projectPinAction => 'ピンプロジェクト';

  @override
  String get projectUnpinAction => 'プロジェクトの固定を解除する';

  @override
  String get shellProjectRailTitle => 'プロジェクトとセッション';

  @override
  String get shellDestinationSessions => 'セッション';

  @override
  String get shellDestinationChat => 'チャット';

  @override
  String get shellDestinationContext => 'コンテクスト';

  @override
  String get shellDestinationSettings => '設定';

  @override
  String get shellAdvancedLabel => '高度な';

  @override
  String get shellAdvancedSubtitle => '高度な設定とトラブルシューティング ツール。';

  @override
  String get shellAdvancedOverviewSubtitle => '技術的なオプションはメインフローから除外されます。';

  @override
  String get shellOpenAdvancedAction => 'アドバンストを開く';

  @override
  String get shellBackToSettingsAction => '設定に戻る';

  @override
  String get shellA11yOpenCacheSettings => 'キャッシュ設定を開く';

  @override
  String get shellA11yOpenAdvanced => '詳細設定を開く';

  @override
  String get shellA11yBackToSettings => '設定に戻る';

  @override
  String get shellA11yBackToProjectsAction => 'プロジェクトに戻る';

  @override
  String get shellA11yComposerField => 'メッセージフィールド';

  @override
  String get shellA11ySendMessageAction => 'メッセージを送信する';

  @override
  String get shellIntegrationsLastAuthUrlTitle => '最終認証URL';

  @override
  String get shellIntegrationsEventsSubtitle => 'イベント ストリームのステータスとリカバリの詳細。';

  @override
  String get shellStreamHealthConnected => '接続済み';

  @override
  String get shellStreamHealthStale => '古い';

  @override
  String get shellStreamHealthReconnecting => '再接続中';

  @override
  String get shellConfigPreviewUnavailable => '現在、構成ビューは利用できません。';

  @override
  String get shellNoticeLastSessionUnavailable =>
      '最後のセッションは利用できなくなりました。別のセッションを選択するか、新しいセッションを開始してください。';

  @override
  String get shellConfigJsonObjectError => 'Config は JSON オブジェクトである必要があります。';

  @override
  String get shellRecoveryLogReconnectRequested => '再接続が要求されました';

  @override
  String get shellRecoveryLogReconnectCompleted => '再接続が完了しました';

  @override
  String get shellUnknownLabel => '未知';

  @override
  String get shellBackToProjectsAction => 'プロジェクトに戻る';

  @override
  String get shellSessionsTitle => 'セッション';

  @override
  String get shellSessionCurrent => '現在のセッション';

  @override
  String get shellSessionDraft => 'ドラフトブランチ';

  @override
  String get shellSessionReview => 'レビューブランチ';

  @override
  String get shellStatusActive => 'アクティブ';

  @override
  String get shellStatusIdle => 'アイドル状態';

  @override
  String get shellStatusError => 'エラー';

  @override
  String get shellChatHeaderTitle => 'チャットワークスペース';

  @override
  String get shellThinkingModeLabel => 'バランスの取れた思考';

  @override
  String get shellAgentLabel => 'エージェント';

  @override
  String get shellChatTimelineTitle => '会話';

  @override
  String get shellUserMessageTitle => 'あなた';

  @override
  String get shellUserMessageBody => 'セッションを選択し、メッセージを送信して開始します。';

  @override
  String get shellAssistantMessageTitle => 'オープンコード';

  @override
  String get shellAssistantMessageBody =>
      'あなたはワークスペースにいます。コンテキストを確認し、セッションを選択し、作業を進めます。';

  @override
  String get shellComposerPlaceholder => 'メッセージを書く';

  @override
  String get shellComposerSendAction => '送信';

  @override
  String get shellComposerCreatingSession => 'セッションを作成して送信する';

  @override
  String get shellComposerSending => '送信中...';

  @override
  String get shellComposerModelLabel => 'モデル';

  @override
  String get shellComposerModelDefault => 'サーバーのデフォルト';

  @override
  String get shellComposerThinkingLabel => '考え';

  @override
  String get shellComposerThinkingLow => 'ライト';

  @override
  String get shellComposerThinkingBalanced => 'バランスの取れた';

  @override
  String get shellComposerThinkingDeep => '深い';

  @override
  String get shellComposerThinkingMax => 'マックス';

  @override
  String get shellRenameSessionTitle => 'セッション名の変更';

  @override
  String get shellSessionTitleHint => 'セッションタイトル';

  @override
  String get shellCancelAction => 'キャンセル';

  @override
  String get shellSaveAction => '保存';

  @override
  String get shellContextTitle => 'コンテキストユーティリティ';

  @override
  String get shellFilesTitle => 'ファイル';

  @override
  String get shellFilesSubtitle => 'ツリー、ステータス、検索はここにあります。';

  @override
  String get shellDiffTitle => '差分';

  @override
  String get shellDiffSubtitle => 'パッチとスナップショットのレビューがここに表示されます。';

  @override
  String get shellTodoTitle => '藤堂';

  @override
  String get shellTodoSubtitle => 'タスクの進行状況と履歴はここに表示されたままになります。';

  @override
  String get shellToolsTitle => 'ツール';

  @override
  String get shellToolsSubtitle => 'このワークスペースに役立つツール。';

  @override
  String get shellTerminalTitle => 'ターミナル';

  @override
  String get shellTerminalSubtitle => 'クイックシェルとアタッチフローがここに着陸します。';

  @override
  String get shellInspectorTitle => '検査官';

  @override
  String get shellConfigTitle => '構成';

  @override
  String get shellConfigInvalid => '無効な構成';

  @override
  String get shellConfigDraftEmpty => '構成ドラフトは空です。';

  @override
  String shellConfigChangedKeys(int count) {
    return '変更されたキー: $count';
  }

  @override
  String get shellConfigApplying => '申請中...';

  @override
  String get shellConfigApplyAction => '構成を適用する';

  @override
  String get shellIntegrationsTitle => '統合';

  @override
  String get shellIntegrationsProviders => 'プロバイダー';

  @override
  String get shellIntegrationsMethods => 'メソッド';

  @override
  String get shellIntegrationsStartProviderAuth => 'プロバイダー認証を開始する';

  @override
  String get shellIntegrationsMcp => 'MCP';

  @override
  String get shellIntegrationsStartMcpAuth => 'MCP認証を開始する';

  @override
  String get shellIntegrationsLsp => 'LSP';

  @override
  String get shellIntegrationsFormatter => 'フォーマッタ';

  @override
  String get shellIntegrationsEnabled => '有効';

  @override
  String get shellIntegrationsDisabled => '無効';

  @override
  String get shellIntegrationsRecentEvents => '最近の出来事';

  @override
  String get shellIntegrationsStreamHealth => 'ストリームの健全性';

  @override
  String get shellIntegrationsRecoveryLog => '回復ログ';

  @override
  String get shellWorkspaceEyebrow => 'ワークスペース';

  @override
  String get shellSessionsEyebrow => 'セッション';

  @override
  String get shellControlsEyebrow => 'コントロール';

  @override
  String get shellActionsTitle => 'アクション';

  @override
  String get shellActionFork => 'フォーク';

  @override
  String get shellActionShare => '共有';

  @override
  String get shellActionUnshare => '共有を解除する';

  @override
  String get shellActionRename => '名前の変更';

  @override
  String get shellActionDelete => '消去';

  @override
  String get shellActionAbort => 'アボート';

  @override
  String get shellActionRevert => '元に戻す';

  @override
  String get shellActionUnrevert => '元に戻す';

  @override
  String get shellActionInit => '初期化する';

  @override
  String get shellActionSummarize => '要約する';

  @override
  String get shellPrimaryEyebrow => '主要な';

  @override
  String get shellTimelineEyebrow => 'タイムライン';

  @override
  String get shellFocusedThreadEyebrow => '注目のスレッド';

  @override
  String get shellNewSessionDraft => '新しいセッションの草稿';

  @override
  String shellTimelinePartsInFocus(int count) {
    return '$count タイムライン パーツにフォーカス';
  }

  @override
  String get shellReadyToStart => '始める準備完了';

  @override
  String get shellLiveContext => 'ライブコンテキスト';

  @override
  String shellPartsCount(int count) {
    return '$countパーツ';
  }

  @override
  String get shellFocusedThreadSubtitle => 'アクティブなスレッドに焦点を当てる';

  @override
  String get shellConversationSubtitle => '長文の読み上げと返信の作成が中心';

  @override
  String get shellConnectionIssueTitle => '接続の問題';

  @override
  String get shellUtilitiesEyebrow => '公共事業';

  @override
  String get shellFilesSearchHint => 'ファイル、テキスト、またはシンボルを検索する';

  @override
  String get shellPreviewTitle => 'プレビュー';

  @override
  String get shellCurrentSelection => '現在の選択内容';

  @override
  String get shellMatchesTitle => '一致';

  @override
  String get shellMatchesSubtitle => '関連するテキストの結果';

  @override
  String get shellSymbolsTitle => '記号';

  @override
  String get shellSymbolsSubtitle => 'クイックコードのランドマーク';

  @override
  String get shellTerminalHint => '障害者';

  @override
  String get shellTerminalRunAction => 'コマンドの実行';

  @override
  String get shellTerminalRunning => '走っています...';

  @override
  String get shellTrackedLabel => '追跡された';

  @override
  String get shellPendingApprovalsTitle => '承認待ち';

  @override
  String shellPendingApprovalsSubtitle(int count) {
    return '$count 項目が入力待ちです';
  }

  @override
  String get shellAllowOnceAction => '一度許可する';

  @override
  String get shellRejectAction => '拒否する';

  @override
  String get shellAnswerAction => '答え';

  @override
  String get shellConfigPreviewSubtitle => '構成の確認と編集';

  @override
  String get shellInspectorSubtitle => 'セッションとメッセージのメタデータのスナップショット';

  @override
  String get shellIntegrationsLspSubtitle => '言語サーバーの準備状況';

  @override
  String get shellIntegrationsFormatterSubtitle => 'フォーマットの利用可能性';

  @override
  String get shellActionsSubtitle => 'セッションコントロールとライフサイクルアクション';

  @override
  String shellActiveCount(int count) {
    return '$count アクティブ';
  }

  @override
  String shellThreadsCount(int count) {
    return '現在のプロジェクト全体の $count スレッド';
  }

  @override
  String get chatPartAssistant => 'アシスタント';

  @override
  String get chatPartUser => 'ユーザー';

  @override
  String get chatPartThinking => '考え';

  @override
  String get chatPartTool => '道具';

  @override
  String chatPartToolNamed(String name) {
    return 'ツール: $name';
  }

  @override
  String get chatPartFile => 'ファイル';

  @override
  String get chatPartStepStart => 'ステップスタート';

  @override
  String get chatPartStepFinish => 'ステップフィニッシュ';

  @override
  String get chatPartSnapshot => 'スナップショット';

  @override
  String get chatPartPatch => 'パッチ';

  @override
  String get chatPartRetry => 'リトライ';

  @override
  String get chatPartAgent => 'エージェント';

  @override
  String get chatPartSubtask => 'サブタスク';

  @override
  String get chatPartCompaction => '圧縮';

  @override
  String get shellUtilitiesToggleTitle => 'ユーティリティドロワー';

  @override
  String get shellUtilitiesToggleBody =>
      '下部のユーティリティ ドロワーを開いて、ファイル、差分、Todo、ツール、縦向きレイアウトのターミナル パネルを調べます。';

  @override
  String get shellUtilitiesToggleBodyCompact =>
      'ユーティリティを開いて、ファイル、差分、Todo、ツール、ターミナル パネルを切り替えます。';

  @override
  String get shellContextEyebrow => 'コンテクスト';

  @override
  String get shellSecondaryContextSubtitle => 'アクティブな会話の二次コンテキスト';

  @override
  String get shellSupportRailsSubtitle => 'ファイル、タスク、コマンド、統合用のサポートレール';

  @override
  String shellModulesCount(int count) {
    return '$countモジュール';
  }

  @override
  String get shellSwipeUtilitiesIntoView => 'ユーティリティをスワイプして表示します';

  @override
  String get shellOpenUtilityRail => 'ユーティリティレールを開きます';

  @override
  String get shellOpenCodeRemote => 'BOC';

  @override
  String get shellContextNearby => '近くのコンテキスト';

  @override
  String shellShownCount(int count) {
    return '表示は$count';
  }

  @override
  String get shellSymbolFallback => 'シンボル';

  @override
  String shellFileStatusSummary(String status, int added, int removed) {
    return '$status +$added -$removed';
  }

  @override
  String get shellNewSession => '新しいセッション';

  @override
  String get shellReplying => '返信する';

  @override
  String get shellCompactComposer => 'コンパクトコンポーザー';

  @override
  String get shellExpandedComposer => '拡張されたコンポーザー';

  @override
  String shellRetryAttempt(int count) {
    return '$count を試みます';
  }

  @override
  String shellStatusWithDetails(String status, String details) {
    return '$status - $details';
  }

  @override
  String get shellTodoStatusInProgress => '進行中';

  @override
  String get shellTodoStatusPending => '保留中';

  @override
  String get shellTodoStatusCompleted => '完成した';

  @override
  String get shellTodoStatusUnknown => '未知';

  @override
  String get shellQuestionAskedNotification => '質問がリクエストされました';

  @override
  String get shellPermissionAskedNotification => '許可が要求されました';

  @override
  String get shellNotificationOpenAction => '開ける';

  @override
  String chatPartUnknown(String type) {
    return '不明な部分: $type';
  }
}
