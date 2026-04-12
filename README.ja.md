# Better OpenCode Client (BOC)

[English](README.md) | [简体中文](README.zh-CN.md) | [繁體中文](README.zh-TW.md) | [한국어](README.ko.md) | [Deutsch](README.de.md) | [Español](README.es.md) | [Français](README.fr.md) | [Italiano](README.it.md) | [Dansk](README.da.md) | [日本語](README.ja.md) | [Polski](README.pl.md) | [Русский](README.ru.md) | [Bosanski](README.bs.md) | [العربية](README.ar.md) | [Norsk](README.no.md) | [Português (Brasil)](README.pt-BR.md) | [ไทย](README.th.md) | [Türkçe](README.tr.md) | [Українська](README.uk.md) | [বাংলা](README.bn.md) | [Ελληνικά](README.el.md) | [Tiếng Việt](README.vi.md)

<p align="center">
  <img src="assets/readme/app-icon.png" alt="BOC アプリアイコン" width="112">
</p>

机に縛られず、OpenCode をリモートで使えます。

BOC は、iOS、Android、macOS、Windows から OpenCode をリモート利用するためのクロスプラットフォーム Flutter クライアントです。OpenCode `1.4.3` との互換性を軸に設計されており、メインのワークステーションから離れているときに本当に必要な作業に集中します。サーバー接続、workspace の再開、session の追跡、リクエストへの回答、context の確認、必要に応じた shell コマンド実行です。

広い画面がありますか？

![BOC マルチペイン workspace](assets/readme/multi-pane.png)

BOC は、session 監視、Review、ファイル、context、shell 出力、並列 workspace アクティビティを扱うマルチペインのコマンドセンターとして展開できます。

## BOC を選ぶ理由

- **リモート優先のワークフロー**：OpenCode サーバーを保存し、接続状態を確認し、必要な workspace に素早く戻れます。
- **モバイルネイティブな操作**：タッチしやすいナビゲーション、コンパクトなレイアウト、音声入力、ファイル添付、通知、片手操作。
- **デスクトップ級 workspace**：広い画面では split pane、side panel、session リスト、Review 画面、context 詳細を、窮屈なモバイル表示にせず利用できます。
- **ライブの作業フィードバック**：作業実行中も shell 出力、保留中の質問、権限、todos、context 使用量、session アクティビティを表示します。
- **予測しやすいサーバー管理**：サーバー項目を確認、更新、編集、削除、再接続しやすくします。

## 主な機能

- シンプルなホーム画面から複数のリモート OpenCode サーバーを管理。
- workspace に入る前にサーバーの health と互換性を probe。
- 最近の prompt とアクティブな child session を含めて project と session を閲覧。
- slash commands、添付、モデル選択、reasoning コントロールで OpenCode session とチャット。
- 会話中の位置を失わずに保留中の質問や permission request に回答。
- 専用ペインで context 使用量、ファイル、review diff、inbox item、todos、shell アクティビティを確認。
- ガイド付き UI では足りないときに terminal tab を実行。
- スマートフォン、タブレット、ノート PC、デスクトップ画面で適応型レイアウトを使用。

## 互換性

BOC は OpenCode `1.4.3` を対象にしています。現在のリリース準備検証では、connection probing、workspace/session loading、chat、shell と terminal の flow、保留中の質問、permission request、review/files/context pane、適応型マルチペインレイアウトを重点的に確認しています。

対応クライアントプラットフォーム：

- iOS
- Android
- macOS
- Windows

OpenCode サーバーは引き続きリモートで実行されます。BOC はそのサーバーへ接続するためのクライアント画面であり、サーバー自体の代替ではありません。

## 要件

- `^3.11.1` と互換性のある Dart SDK を含む Flutter
- 到達可能な OpenCode `1.4.3` サーバー
- 実行対象プラットフォームの toolchain：iOS、Android、macOS、Windows

## はじめに

```bash
flutter pub get
flutter run
```

次にホーム画面から OpenCode サーバーを追加し、connection probe が成功することを確認して workspace を開きます。

特定のデバイスで実行する場合：

```bash
flutter devices
flutter run -d <device-id>
```

## 開発

プロジェクト CI と同じチェックを使います：

```bash
flutter analyze
flutter test
```

## プロジェクト状況

BOC はリリース準備中です。現在の焦点は安定性、予測しやすいクロスプラットフォーム UX、対応 OpenCode バージョンとの互換性です。
