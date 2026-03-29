# better-opencode-client (BOC)

better-opencode-client is a spec-driven Flutter client for OpenCode. It is designed to stay compatible across server releases by relying on the server's OpenAPI document plus runtime capability probes.

## Setup

1. Install Flutter for your platform.
2. Fetch dependencies:

   ```bash
   flutter pub get
   ```

## Run

```bash
flutter run
```

## Test

The repo's CI mirrors this sequence:

```bash
flutter analyze
flutter gen-l10n
flutter test
```

## Localization outputs (tracked)

Generated localization Dart files in `lib/l10n/` are tracked in this repository. After changing the ARB files, regenerate them with:

```bash
flutter gen-l10n
```

## Debug and manual tools

This repo keeps a small set of manual verification scripts under `tool/manual/`.

Example:

```bash
dart run tool/manual/run_shell_derived_data.dart
```

That script exercises shell derived-data helpers (todo ordering, file status indexing, and inspector JSON building) without launching the full app.

## Runtime behavior notes (post-fix)

These are repo-facing expectations that are covered by implementation and tests:

- Request URIs preserve the base path prefix and base query parameters from the configured server URL, then merge request-specific query keys on top.
- Remote `session.deleted` events use the same cleanup semantics as the local delete fallback, so session removal is consistent even when upstream delete payloads vary.
- Workspace SSE drop recovery uses a refetch-based recovery path and reconnects without applying duplicate live events.
- Malformed or partial request and live payloads are ignored safely so a bad event does not block later valid updates.

## Docs

- Architecture: `docs/architecture/foundation-architecture.md`
- Project rules: `docs/testing-rules.md`
