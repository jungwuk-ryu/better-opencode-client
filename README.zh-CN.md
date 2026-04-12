# Better OpenCode Client (BOC)

[English](README.md) | [简体中文](README.zh-CN.md) | [繁體中文](README.zh-TW.md) | [한국어](README.ko.md) | [Deutsch](README.de.md) | [Español](README.es.md) | [Français](README.fr.md) | [Italiano](README.it.md) | [Dansk](README.da.md) | [日本語](README.ja.md) | [Polski](README.pl.md) | [Русский](README.ru.md) | [Bosanski](README.bs.md) | [العربية](README.ar.md) | [Norsk](README.no.md) | [Português (Brasil)](README.pt-BR.md) | [ไทย](README.th.md) | [Türkçe](README.tr.md) | [Українська](README.uk.md) | [বাংলা](README.bn.md) | [Ελληνικά](README.el.md) | [Tiếng Việt](README.vi.md)

<p align="center">
  <img src="assets/readme/app-icon.png" alt="BOC 应用图标" width="112">
</p>

远程使用 OpenCode，不必一直守在电脑前。

BOC 是一个跨平台 Flutter 客户端，可在 iOS、Android、macOS 和 Windows 上远程使用 OpenCode。它围绕 OpenCode `1.4.3` 兼容性设计，专注于你离开主工作站时真正需要的工作：连接服务器、恢复工作区、跟进会话、回答请求、查看上下文，并在需要时运行 shell 命令。

有宽屏设备？

![BOC 多面板工作区](assets/readme/multi-pane.png)

BOC 可以展开为多面板指挥中心，用于会话监控、Review、文件、上下文、shell 输出以及并行工作区活动。

## 为什么选择 BOC

- **远程优先流程**：保存 OpenCode 服务器、检查连接状态，并快速回到正确的工作区。
- **移动端原生控制**：触控友好的导航、紧凑布局、语音输入、文件附件、通知和单手操作。
- **桌面级工作区**：宽屏上可使用分屏、侧边面板、会话列表、Review 界面和上下文详情，而不会变成拥挤的移动视图。
- **实时操作反馈**：工作运行时，shell 输出、待处理问题、权限、todos、上下文用量和会话活动保持可见。
- **可预期的服务器管理**：服务器条目易于浏览、刷新、编辑、删除和重新连接。

## 核心功能

- 在简单的首页管理多个远程 OpenCode 服务器。
- 进入工作区前探测服务器健康状态和兼容性。
- 浏览项目和会话，包括最近提示词和活动中的子会话。
- 通过 slash commands、附件、模型选择和 reasoning 控制与 OpenCode 会话聊天。
- 在不丢失对话位置的情况下回答待处理问题和权限请求。
- 在专用面板中查看上下文用量、文件、review diff、inbox 项、todos 和 shell 活动。
- 当引导式 UI 不够用时运行终端标签页。
- 在手机、平板、笔记本和桌面显示器之间使用自适应布局。

## 兼容性

BOC 以 OpenCode `1.4.3` 为目标。当前发布准备验证聚焦于连接探测、工作区/会话加载、聊天、shell 与终端流程、待处理问题、权限请求、review/files/context 面板以及自适应多面板布局。

支持的客户端平台：

- iOS
- Android
- macOS
- Windows

OpenCode 服务器仍然在远端运行；BOC 是连接它的客户端界面，而不是服务器本身的替代品。

## 要求

- Flutter，并使用兼容 `^3.11.1` 的 Dart SDK
- 可访问的 OpenCode `1.4.3` 服务器
- 你计划运行的目标平台工具链：iOS、Android、macOS 或 Windows

## 快速开始

```bash
flutter pub get
flutter run
```

然后在首页添加你的 OpenCode 服务器，确认连接探测通过，并打开一个工作区。

指定设备运行：

```bash
flutter devices
flutter run -d <device-id>
```

## 开发

使用与项目 CI 相同的检查：

```bash
flutter analyze
flutter test
```

## 项目状态

BOC 正在为发布做准备。当前重点是稳定性、可预期的跨平台 UX，以及与受支持 OpenCode 版本的兼容性。
