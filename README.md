# OpenCode Mobile Remote

OpenCode Mobile Remote is a Flutter client for staying connected to remote OpenCode workspaces when you are away from your desk. It is built for the moments where you need to reconnect quickly, triage pending approvals or questions, inspect a project, and close a small Git loop from a phone or tablet.

## Why It Exists

- Shared connection links can open directly into the app and are QR-ready because the same deep link can be encoded as a QR code by the sender.
- Connection probe and trust metadata help explain whether a failure is network, TLS, auth, or capability related before you enter a workspace.
- A mobile-first workspace keeps sessions, inbox triage, project actions, and terminal fallback close to the prompt composer instead of hiding them behind desktop-heavy navigation.
- The Git loop covers the practical minimum: repository status, stage or unstage, commit, pull, push, branch switch or create, and read-only PR or check summaries.
- Mobile-native helpers such as voice input, quick attachment, recent links, and inbox triage reduce typing and repeated navigation during remote work.

## Core Flows

### 1. Connect Fast

1. Run `flutter pub get`
2. Launch the app with `flutter run`
3. Open a shared `opencode-remote://` link on the device, or scan a QR code that contains the same link
4. Review the imported connection profile and save it
5. Run the built-in probe and confirm the server, capability, and auth status

### 2. Work From the Workspace

- Open the workspace inbox to triage pending questions, approvals, and unread session activity.
- Use Project Actions to jump to saved commands, recent links, port presets, and runtime status.
- Use the Git workflow sheet to inspect status, stage files, commit, sync, and switch branches.
- Fall back to terminal tabs when a workflow needs more power than the guided sheet exposes.

### 3. Stay Productive on Mobile

- Start voice dictation directly from the composer.
- Attach images, PDFs, and text files from the picker or clipboard.
- Re-open session share links and project URLs without leaving the workspace.
- Keep one-hand actions close through toolbar chips, compact overflow actions, and slash commands.

## Platform Notes

- Deep links are configured for Android and iOS with the `opencode-remote` scheme.
- Voice input requests microphone and speech recognition access on mobile platforms.
- The project uses `app_links`, `speech_to_text`, and `url_launcher` to support connection import and mobile actions.

## Docs

- Quickstart: [docs/quickstart-first-connection.md](/Users/jungwuk/Documents/works/opencode-mobile-remote/docs/quickstart-first-connection.md)
- Remote usage scenarios: [docs/remote-usage-scenarios.md](/Users/jungwuk/Documents/works/opencode-mobile-remote/docs/remote-usage-scenarios.md)
- Product roadmap: [docs/product-roadmap-2026-03-31.md](/Users/jungwuk/Documents/works/opencode-mobile-remote/docs/product-roadmap-2026-03-31.md)
- Continuity strategy: [docs/continuity-strategy-2026-03-31.md](/Users/jungwuk/Documents/works/opencode-mobile-remote/docs/continuity-strategy-2026-03-31.md)
- Support entry points: [docs/support-entry-points-2026-03-31.md](/Users/jungwuk/Documents/works/opencode-mobile-remote/docs/support-entry-points-2026-03-31.md)
- Demo asset pack: [docs/demo-assets-shot-list-2026-03-31.md](/Users/jungwuk/Documents/works/opencode-mobile-remote/docs/demo-assets-shot-list-2026-03-31.md)

## Validation

The current delivery gate for this branch is:

```bash
flutter analyze
flutter test test/features/chat/prompt_attachment_service_test.dart \
  test/features/connection/connection_profile_import_test.dart \
  test/features/projects/project_git_service_test.dart
```

## Current Boundaries

- The Git workflow intentionally stays within a safe, mobile-sized scope and still exposes terminal fallback for advanced flows.
- Demo assets in `docs/demo-assets/` are packaged storyboard frames for public communication when live capture is not available.
- The app remains a Flutter client and does not attempt to replace full desktop review or repository management tools.

## Repository Development

For architecture and repo-facing development notes:

- Architecture: [docs/architecture/foundation-architecture.md](/Users/jungwuk/Documents/works/opencode-mobile-remote/docs/architecture/foundation-architecture.md)
- Testing rules: [docs/testing-rules.md](/Users/jungwuk/Documents/works/opencode-mobile-remote/docs/testing-rules.md)
