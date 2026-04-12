# Better OpenCode Client (BOC)

[English](README.md) | [简体中文](README.zh-CN.md) | [繁體中文](README.zh-TW.md) | [한국어](README.ko.md) | [Deutsch](README.de.md) | [Español](README.es.md) | [Français](README.fr.md) | [Italiano](README.it.md) | [Dansk](README.da.md) | [日本語](README.ja.md) | [Polski](README.pl.md) | [Русский](README.ru.md) | [Bosanski](README.bs.md) | [العربية](README.ar.md) | [Norsk](README.no.md) | [Português (Brasil)](README.pt-BR.md) | [ไทย](README.th.md) | [Türkçe](README.tr.md) | [Українська](README.uk.md) | [বাংলা](README.bn.md) | [Ελληνικά](README.el.md) | [Tiếng Việt](README.vi.md)

<p align="center">
  <img src="assets/readme/app-icon.png" alt="BOC 應用程式圖示" width="112">
</p>

遠端使用 OpenCode，不必一直守在電腦前。

BOC 是跨平台 Flutter 用戶端，可在 iOS、Android、macOS 和 Windows 上遠端使用 OpenCode。它以 OpenCode `1.4.3` 相容性為設計目標，專注於你離開主要工作站時真正需要的工作：連線到伺服器、恢復工作區、追蹤 session、回答請求、檢視 context，並在需要時執行 shell 命令。

有寬螢幕嗎？

![BOC 多面板工作區](assets/readme/multi-pane.png)

BOC 可以展開成多面板指揮中心，用於 session 監控、Review、檔案、context、shell 輸出與並行工作區活動。

## 為什麼選擇 BOC

- **遠端優先工作流程**：儲存 OpenCode 伺服器、檢查連線狀態，並快速回到正確的工作區。
- **行動端原生控制**：觸控友善導覽、緊湊版面、語音輸入、檔案附件、通知與單手操作。
- **桌面級工作區**：寬螢幕可使用分割面板、側邊面板、session 清單、Review 介面與 context 詳情，而不會變成擁擠的行動版畫面。
- **即時操作回饋**：工作執行時，shell 輸出、待處理問題、權限、todos、context 用量與 session 活動保持可見。
- **可預期的伺服器管理**：伺服器項目容易瀏覽、重新整理、編輯、刪除與重新連線。

## 核心功能

- 從簡潔的首頁管理多個遠端 OpenCode 伺服器。
- 進入工作區前探測伺服器健康狀態與相容性。
- 瀏覽專案與 session，包括最近提示詞和活動中的子 session。
- 使用 slash commands、附件、模型選擇與 reasoning 控制與 OpenCode session 對話。
- 在不失去對話位置的情況下回答待處理問題與權限請求。
- 從專用面板檢視 context 用量、檔案、review diff、inbox 項目、todos 與 shell 活動。
- 在引導式 UI 不夠用時執行終端分頁。
- 在手機、平板、筆電與桌面顯示器之間使用自適應版面。

## 相容性

BOC 以 OpenCode `1.4.3` 為目標。當前發布準備驗證聚焦於連線探測、工作區/session 載入、聊天、shell 與終端流程、待處理問題、權限請求、review/files/context 面板，以及自適應多面板版面。

支援的用戶端平台：

- iOS
- Android
- macOS
- Windows

OpenCode 伺服器仍然在遠端執行；BOC 是連線到它的用戶端介面，而不是伺服器本身的替代品。

## 需求

- Flutter，並使用相容 `^3.11.1` 的 Dart SDK
- 可連線的 OpenCode `1.4.3` 伺服器
- 你計畫執行的目標平台工具鏈：iOS、Android、macOS 或 Windows

## 快速開始

```bash
flutter pub get
flutter run
```

接著在首頁新增你的 OpenCode 伺服器，確認連線探測通過，然後開啟工作區。

指定裝置執行：

```bash
flutter devices
flutter run -d <device-id>
```

## 開發

使用與專案 CI 相同的檢查：

```bash
flutter analyze
flutter test
```

## 專案狀態

BOC 正在準備發布。目前重點是穩定性、可預期的跨平台 UX，以及與受支援 OpenCode 版本的相容性。
