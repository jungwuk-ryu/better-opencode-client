# Better OpenCode Client (BOC)

[English](README.md) | [简体中文](README.zh-CN.md) | [繁體中文](README.zh-TW.md) | [한국어](README.ko.md) | [Deutsch](README.de.md) | [Español](README.es.md) | [Français](README.fr.md) | [Italiano](README.it.md) | [Dansk](README.da.md) | [日本語](README.ja.md) | [Polski](README.pl.md) | [Русский](README.ru.md) | [Bosanski](README.bs.md) | [العربية](README.ar.md) | [Norsk](README.no.md) | [Português (Brasil)](README.pt-BR.md) | [ไทย](README.th.md) | [Türkçe](README.tr.md) | [Українська](README.uk.md) | [বাংলা](README.bn.md) | [Ελληνικά](README.el.md) | [Tiếng Việt](README.vi.md)

<p align="center">
  <img src="assets/readme/app-icon.png" alt="BOC app icon" width="112">
</p>

Remote OpenCode, without being glued to your desk.

BOC is a cross-platform Flutter client for using OpenCode remotely from iOS, Android, macOS, and Windows. It is designed around compatibility with OpenCode `1.4.3` and focuses on the work you actually need when you are away from your main workstation: connect to a server, resume a workspace, follow sessions, answer requests, inspect context, and run the occasional shell command.

Have a wide screen?

![BOC multi-pane workspace](assets/readme/multi-pane.png)

BOC can stretch into a multi-pane command center for session monitoring, review, files, context, shell output, and parallel workspace activity.

## Why BOC

- **Remote-first workflow**: save OpenCode servers, check connection status, and jump back into the right workspace quickly.
- **Mobile-native controls**: touch-friendly navigation, compact layouts, voice input, file attachments, notifications, and one-hand actions.
- **Desktop-grade workspace**: wide screens get split panes, side panels, session lists, review surfaces, and context details without turning the UI into a cramped mobile view.
- **Live operational feedback**: shell output, pending questions, permissions, todos, context usage, and session activity stay visible while work is running.
- **Predictable server management**: server entries are easy to scan, refresh, edit, delete, and reconnect.

## Core Features

- Manage multiple remote OpenCode servers from a simple home screen.
- Probe server health and compatibility before entering a workspace.
- Browse projects and sessions, including recent prompts and active child sessions.
- Chat with OpenCode sessions using slash commands, attachments, model selection, and reasoning controls.
- Answer pending questions and permission requests without losing your place in the conversation.
- Inspect context usage, files, review diffs, inbox items, todos, and shell activity from dedicated panes.
- Run terminal tabs when a guided UI is not enough.
- Use adaptive layouts across phones, tablets, laptops, and desktop displays.

## Compatibility

BOC targets OpenCode `1.4.3`. The current release-prep validation focuses on connection probing, workspace/session loading, chat, shell and terminal flows, pending questions, permission requests, review/files/context panes, and adaptive multi-pane layouts.

Supported client platforms:

- iOS
- Android
- macOS
- Windows

The OpenCode server still runs remotely; BOC is the client surface for connecting to it, not a replacement for the server itself.

## Requirements

- Flutter with a Dart SDK compatible with `^3.11.1`
- A reachable OpenCode `1.4.3` server
- Platform toolchains for the targets you plan to run: iOS, Android, macOS, or Windows

## Getting Started

```bash
flutter pub get
flutter run
```

Then add your OpenCode server from the home screen, confirm that the connection probe passes, and open a workspace.

For device-specific runs:

```bash
flutter devices
flutter run -d <device-id>
```

## Development

Use the same checks as the project CI:

```bash
flutter analyze
flutter test
```

## Project Status

BOC is being prepared for release. The focus right now is stability, predictable cross-platform UX, and compatibility with the supported OpenCode version.
