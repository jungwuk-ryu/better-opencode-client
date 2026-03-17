# Flutter OpenCode Client - Foundation Plan

## Goal

Build a spec-driven Flutter client for OpenCode servers that adapts to current and future server capabilities without pinning the UI to one server version.

## Phase 0 Acceptance Criteria

- A runtime capability probe exists and reads `GET /global/health`, `GET /doc`, `GET /config`, `GET /config/providers`, `GET /provider`, `GET /provider/auth`, `GET /agent`, and optional experimental tool endpoints.
- The client computes feature flags from OpenAPI path existence, schema shape, endpoint probe results, and version metadata.
- Optional or legacy probe failures from `401`, `403`, `404`, and `501` on optional endpoints do not fail startup and are mapped to `unsupported` or `unknown` capabilities.
- Unknown config fields round-trip without loss.
- Decode to encode tests preserve unknown nested fields for `/config` and `/config/providers` payloads.
- SSE infrastructure supports connection, heartbeat, reconnect with backoff, stale-stream detection, and explicit resync hooks.
- Recorded fixtures exist for a full-capability server, a legacy server with missing optional endpoints, a probe-error server, at least one health response, one OpenAPI spec, and representative global/session event streams.

## Initial Milestones

1. Bootstrap Flutter SDK usage, create the app scaffold, and establish package structure under `lib/src` for core, features, design system, and i18n.
2. Add probe fixtures and contract tests before implementing capability models and probing.
3. Implement spec and capability models before major UI work.
4. Add SSE fixtures and reducer plus transport tests before implementing SSE transport and reducer-owned live state.
5. Implement SSE transport and reducer-owned live state before chat rendering.
6. Add fixture-driven debug and manual QA surfaces for probing and stream verification.

## Atomic Commit Boundaries

1. `docs: add foundation architecture and acceptance criteria`
2. `chore: bootstrap Flutter project structure`
3. `test: add probe fixtures and contract tests`
4. `core: add spec and capability probing models`
5. `test: add SSE fixtures and reducer transport tests`
6. `core: add SSE transport and event reducers`
7. `debug: add fixture-driven probe and stream inspector`

## QA Gates

- `flutter analyze` passes.
- `flutter test` passes for healthy stream, missed heartbeat, server-close reconnect, duplicate delivery, resync-required recovery, full-capability probe, legacy probe, and probe-error fixtures.
- A fixture-driven debug screen or harness can load each probe fixture and show the exact computed capability flags plus graceful degradation for unsupported endpoints.
- A fixture-driven stream debug screen or harness can ingest representative event sequences and show the resulting reducer state after reconnect and resync transitions.
