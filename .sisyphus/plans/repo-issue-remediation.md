# Repository Issue Remediation Plan

## TL;DR
> **Summary**: Remediate all confirmed repository issues except Android release signing by hardening shared URI construction, fixing workspace live-sync state recovery, tightening malformed event handling, cleaning package/localization/documentation drift, and adding repo-visible verification automation.
> **Deliverables**:
> - Shared URI builder with path-prefix and base-query preservation across affected services
> - Remote session deletion fallback parity and workspace SSE recovery parity
> - Malformed request/live event hardening with regression coverage
> - Package identity alignment, ARB cleanup, and Korean copy consistency
> - README/architecture/mission doc sync, iOS/generation hygiene alignment, and repo-visible CI
> **Effort**: XL
> **Parallel**: YES - 4 waves
> **Critical Path**: Task 1 -> Task 2 -> Task 3 -> Task 5 -> Task 8 -> Task 9

## Context
### Original Request
사용자는 Android 릴리즈 서명 이슈를 제외하고, 프로젝트의 코드/구조/리포지토리 차원에서 보고된 모든 이슈를 해결하기 위한 실행 계획을 요구했다. 사용자 제공 고우선 이슈 4개를 반드시 포함하고, 추가 에이전트가 이미 보고한 중복되지 않는 이슈도 함께 해결해야 한다. 또한 각 작업은 커밋, 테스트, 코드 리뷰, 버그 재검토를 명시적으로 요구한다.

### Interview Summary
- 사용자 제공 확정 이슈:
  - `ProjectCatalogService`의 base URL path prefix 손실
  - 원격 `session.deleted` 시 selected session fallback 누락
  - workspace SSE 복구 부재
  - 여러 서비스의 base query parameter 손실
- 추가 반영할 확정/준확정 이슈:
  - malformed request/live event 처리 취약성
  - ARB duplicate key와 한국어 번역 일관성 저하
  - README/architecture/mission docs drift
  - repo/package/app identity mismatch
  - repo-visible CI 부재
  - iOS Podfile/Xcode deployment target drift risk
  - generated-file/Xcode workspace metadata policy 부재
- 명시적 제외:
  - `android/app/build.gradle.kts` release signing debug config 문제는 이번 계획에서 제외

### Metis Review (gaps addressed)
- SSE 복구는 새 프로토콜 설계가 아니라 **기존 shell 복구 동작과의 behavioral parity**로 고정한다.
- docs drift는 **런타임을 문서에 맞추는 작업이 아니라, 필요한 코드 수정 후 문서를 현재 런타임에 맞추는 작업**으로 고정한다.
- URI 문제는 repo-wide 네트워킹 재설계가 아니라 **shared helper + 정확한 대상 서비스 이행**으로 제한한다.
- malformed payload 대응은 repo 전체 JSON 파싱 정비가 아니라 **확인된 live/request 경로 + 직접 인접 중복 패턴**으로 제한한다.
- 각 작업은 `red -> green -> review -> commit` 순서를 강제한다.

## Work Objectives
### Core Objective
Android release signing을 제외한 확인된 결함과 drift를 한 번의 remediation wave로 정리해, prefix/query-aware networking, resilient workspace live sync, non-crashing malformed event handling, coherent naming/localization/docs, and repo-visible verification automation을 확보한다.

### Deliverables
- `lib/src/core/network`에 shared URI builder 도입
- path prefix/query preservation이 필요한 서비스 전체 이행
- `WorkspaceController`의 remote deletion fallback 및 SSE recovery parity
- request/live event malformed payload hardening 및 regression tests
- `pubspec.yaml` package identity 정렬과 관련 import 갱신
- `lib/l10n/*.arb` duplicate key 제거 및 한국어 copy 정리
- `README.md`, `docs/architecture/*`, `docs/mission-*` 동기화
- `.github/workflows/ci.yml` 추가
- `ios/Podfile` target declaration 정렬 및 generated-file policy 명문화

### Definition of Done (verifiable conditions with commands)
- `"/home/ubuntu/tools/flutter/bin/flutter" analyze` exits `0`
- `"/home/ubuntu/tools/flutter/bin/flutter" test` exits `0`
- `"/home/ubuntu/tools/flutter/bin/flutter" test test/features/projects/project_catalog_service_test.dart test/core/network/event_stream_service_test.dart test/features/requests/request_service_test.dart test/features/files/file_browser_service_test.dart test/features/chat/chat_service_test.dart test/features/settings/config_service_test.dart test/features/settings/integration_status_service_test.dart` exits `0`
- `"/home/ubuntu/tools/flutter/bin/flutter" test test/features/web_parity/workspace_controller_live_sync_test.dart test/features/requests/request_event_applier_test.dart` exits `0`
- `"/home/ubuntu/tools/flutter/bin/flutter" test test/features/home/home_copy_accessibility_test.dart test/features/shell/shell_copy_accessibility_test.dart` exits `0`
- `grep -R "package:opencode_mobile_remote/" lib test tool` returns no matches
- `grep -n "shellRenameSessionTitle" lib/l10n/app_en.arb lib/l10n/app_ko.arb` shows one definition per file
- `grep -n "platform :ios, '13.0'" ios/Podfile` finds one active line
- `test -f .github/workflows/ci.yml` exits `0`
- `lsp_diagnostics` on modified Dart files reports no errors

### Must Have
- Base URL path prefix such as `https://example.com/api` must survive all migrated HTTP/SSE request building
- Existing base query parameters such as `?token=abc` must survive all migrated request building unless a request intentionally overrides the same key
- `WorkspaceController` remote deletion path must match local deletion semantics for selection fallback, panel reset, cache cleanup, and notification cleanup
- Workspace live stream must recover on both `onDone` and `onError` without duplicating subscriptions
- Malformed live/request events must not crash reducers/controllers or permanently stop valid later events
- Package/repo/app identity must stop mixing `opencode_mobile_remote` and `better-opencode-client` at the Dart package/import level
- ARB duplicate keys and obviously untranslated Korean technical strings must be resolved
- Repo-visible docs must describe the post-fix runtime structure and verification entry points
- Repo-visible CI must run analyze and tests using the repository’s Flutter workflow

### Must NOT Have (guardrails, AI slop patterns, scope boundaries)
- Must not modify Android release signing in this plan
- Must not redesign backend APIs, SSE protocol, or introduce Last-Event-ID/spec features not already present
- Must not replace PTY URI behavior; PTY is the preservation reference implementation
- Must not turn URI remediation into a full networking framework rewrite
- Must not expand malformed payload work into unrelated JSON parsing areas
- Must not perform a broad marketing/branding rewrite outside naming consistency needed to resolve the mismatch
- Must not add CI stages unrelated to current repository tooling (no release/deploy pipeline invention)

## Verification Strategy
> ZERO HUMAN INTERVENTION — all verification is agent-executed.
- Test decision: TDD for defect-fix tasks, tests-after for docs/CI tasks only
- QA policy: Every task includes executable scenarios plus a code-review focus and bug-review checklist
- Evidence: `.sisyphus/evidence/task-{N}-{slug}.{ext}`

## Execution Strategy
### Parallel Execution Waves
> Target: 5-8 tasks per wave. Shared contracts first, then behavior fixes, then hygiene/docs/CI.

Wave 1: package identity baseline, URI contract tests/helper, malformed-event characterization

Wave 2: URI migration, remote deletion fallback, workspace SSE recovery

Wave 3: malformed payload hardening, localization cleanup, iOS/generated-file hygiene

Wave 4: docs sync and repo-visible CI

### Dependency Matrix (full, all tasks)
| Task | Depends On | Enables |
|---|---|---|
| 1 | none | 2, 3, 8, 9 |
| 2 | none | 3, 9 |
| 3 | 1 | 4, 5, 9 |
| 4 | 3 | 8, 9 |
| 5 | 3 | 8, 9 |
| 6 | 1 | 8, 9 |
| 7 | none | 8, 9 |
| 8 | 4, 5, 6, 7 | 9 |
| 9 | 2, 3, 4, 5, 6, 7, 8 | Final Verification |

### Agent Dispatch Summary (wave → task count → categories)
- Wave 1 → 3 tasks → `unspecified-high`
- Wave 2 → 3 tasks → `unspecified-high`, `deep`
- Wave 3 → 2 tasks → `writing`, `unspecified-high`
- Wave 4 → 1 task → `writing`
- Final Verification → 4 tasks → `oracle`, `unspecified-high`, `deep`

## TODOs
> Implementation + Test = ONE task. Never separate.
> EVERY task MUST have: Agent Profile + Parallelization + QA Scenarios.

- [x] 1. Align Dart package identity with repository naming

  **What to do**: Rename the Dart package from `opencode_mobile_remote` to `better_opencode_client` in `pubspec.yaml` and update all Dart imports/usages under `lib/`, `test/`, and `tool/` to the new package name. Keep native bundle identifiers (`com.jungwuk.boc`) unchanged. Update any generated localization/package references only as required by the package rename, not as a general rebrand.
  **Must NOT do**: Do not touch Android signing, native application IDs, or user-facing copy outside the naming mismatch. Do not leave mixed old/new package imports.

  **Recommended Agent Profile**:
  - Category: `unspecified-high` — Reason: repo-wide import/package rename with high breakage risk
  - Skills: `[]` — existing repository patterns are sufficient
  - Omitted: `["writing"]` — this is structural consistency, not copy polish

  **Parallelization**: Can Parallel: YES | Wave 1 | Blocks: 2, 3, 8, 9 | Blocked By: none

  **References**:
  - Pattern: `pubspec.yaml:1-3` — current package identity source of truth
  - Pattern: `README.md:1-3` — repository/app-facing naming already uses `better-opencode-client`
  - Pattern: `lib/l10n/app_en.arb:3` — app title already uses `better-opencode-client (BOC)`
  - Pattern: `test/features/projects/project_catalog_service_test.dart:5-7` — current package import style to update consistently

  **Acceptance Criteria** (agent-executable only):
  - [ ] `grep -R "package:opencode_mobile_remote/" lib test tool` returns no matches
  - [ ] `grep -n "^name: better_opencode_client$" pubspec.yaml` finds exactly one line
  - [ ] `"/home/ubuntu/tools/flutter/bin/flutter" analyze` exits `0`

  **QA Scenarios** (MANDATORY — task incomplete without these):
  ```text
  Scenario: Old package imports are fully removed
    Tool: Bash
    Steps: Run `grep -R "package:opencode_mobile_remote/" lib test tool`
    Expected: Command returns no matches and exits non-zero only because nothing matched
    Evidence: .sisyphus/evidence/task-1-package-imports.txt

  Scenario: Renamed package still analyzes cleanly
    Tool: Bash
    Steps: Run `"/home/ubuntu/tools/flutter/bin/flutter" analyze`
    Expected: Analyzer exits 0 without new package/import errors
    Evidence: .sisyphus/evidence/task-1-analyze.txt
  ```

  **Code Review Focus**:
  - Verify no `package:opencode_mobile_remote/...` imports remain in repo-tracked Dart files
  - Verify generated/imported files reference the new package name consistently
  - Verify no native bundle identifiers were changed accidentally

  **Bug Review Checklist**:
  - Search for stale package strings in `lib/`, `test/`, `tool/`
  - Run analyzer to catch broken imports and generated references
  - Confirm user-facing branding changes were not unintentionally broadened

  **Commit**: YES | Message: `refactor(package): align dart package identity` | Files: `pubspec.yaml`, `lib/**`, `test/**`, `tool/**`

- [x] 2. Add shared request URI contract and regression tests

  **What to do**: Create a shared URI-building contract in `lib/src/core/network/request_uri.dart` that preserves base path prefixes and existing base query parameters while allowing request-specific params to override duplicates. Add tests that lock behavior for `https://example.com/api` and `https://example.com/api?token=abc`. Use PTY’s current preservation behavior as the semantic baseline.
  **Must NOT do**: Do not migrate unrelated service logic in this task. Do not change PTY semantics. Do not drop explicit per-request override behavior.

  **Recommended Agent Profile**:
  - Category: `unspecified-high` — Reason: shared contract plus regression foundation for multiple services
  - Skills: `[]` — repository code patterns are sufficient
  - Omitted: `["deep"]` — no new architecture is needed beyond the helper contract

  **Parallelization**: Can Parallel: YES | Wave 1 | Blocks: 3, 4, 5, 9 | Blocked By: none

  **References**:
  - Pattern: `lib/src/features/terminal/pty_service.dart:177-203` — query-preserving URI behavior to mirror
  - Pattern: `lib/src/features/projects/project_catalog_service.dart:88-95` — current prefix-breaking path builder
  - Pattern: `lib/src/core/network/event_stream_service.dart:49-59` — current base query loss in SSE path
  - Test: `test/features/projects/project_catalog_service_test.dart` — existing HTTP server assertion pattern
  - Test: `test/core/network/event_stream_service_test.dart` — existing SSE test server pattern

  **Acceptance Criteria** (agent-executable only):
  - [ ] `"/home/ubuntu/tools/flutter/bin/flutter" test test/core/network/request_uri_test.dart` exits `0`
  - [ ] `"/home/ubuntu/tools/flutter/bin/flutter" test test/features/projects/project_catalog_service_test.dart test/core/network/event_stream_service_test.dart` exits `0`
  - [ ] Shared helper tests prove: prefix preserved, base query preserved, duplicate key override works

  **QA Scenarios** (MANDATORY — task incomplete without these):
  ```text
  Scenario: Prefix and query contract is locked before migrations
    Tool: Bash
    Steps: Run `"/home/ubuntu/tools/flutter/bin/flutter" test test/core/network/request_uri_test.dart`
    Expected: Tests assert `/api` path survival, `token=abc` query survival, and request-level override semantics; suite exits 0
    Evidence: .sisyphus/evidence/task-2-request-uri.txt

  Scenario: Existing service-facing regression coverage still passes with the helper contract
    Tool: Bash
    Steps: Run `"/home/ubuntu/tools/flutter/bin/flutter" test test/features/projects/project_catalog_service_test.dart test/core/network/event_stream_service_test.dart`
    Expected: Existing service tests plus new prefix/query assertions pass together
    Evidence: .sisyphus/evidence/task-2-service-contract.txt
  ```

  **Code Review Focus**:
  - Verify helper semantics exactly mirror PTY’s path/query preservation contract
  - Verify duplicate query keys resolve in favor of request-level values only
  - Verify helper API is narrow and does not leak unrelated networking concerns

  **Bug Review Checklist**:
  - Test base URL with `/api` path prefix
  - Test base URL with `?token=abc`
  - Test same-key override and no-query baseline cases

  **Commit**: YES | Message: `test(network): lock shared request uri semantics` | Files: `lib/src/core/network/request_uri.dart`, `test/core/network/request_uri_test.dart`, `test/features/projects/project_catalog_service_test.dart`, `test/core/network/event_stream_service_test.dart`

- [x] 3. Migrate all affected services to the shared URI builder

  **What to do**: Replace ad hoc URI building in `ProjectCatalogService`, `EventStreamService`, `RequestService`, `FileBrowserService`, `ChatService`, `SessionActionService`, `ConfigService`, and `IntegrationStatusService` with the shared helper from Task 2. Preserve current per-request `directory`, `path`, `before`, `limit`, and similar query behavior. For `ProjectCatalogService`, fix all confirmed prefix-loss call sites (`inspectDirectory`, `_buildQueryUri`, `_getJson`, `updateProject`).
  **Must NOT do**: Do not change payload schemas, HTTP methods, or PTY service behavior. Do not leave any service using the old `baseUri.resolve(...).replace(queryParameters: ...)` anti-pattern.

  **Recommended Agent Profile**:
  - Category: `unspecified-high` — Reason: multi-service behavioral migration with high regression risk
  - Skills: `[]` — repository tests already define the needed behavior
  - Omitted: `["quick"]` — too many call sites and tests for a trivial patch

  **Parallelization**: Can Parallel: NO | Wave 2 | Blocks: 8, 9 | Blocked By: 2

  **References**:
  - Pattern: `lib/src/features/projects/project_catalog_service.dart:29-153,280-344,596-616` — project catalog and path helper sites to migrate
  - Pattern: `lib/src/core/network/event_stream_service.dart:45-59` — SSE URI construction to migrate
  - Pattern: `lib/src/features/requests/request_service.dart:141-157` — request pending/reply URI helper to migrate
  - Pattern: `lib/src/features/files/file_browser_service.dart:214-230` — file browser query builder to migrate
  - Pattern: `lib/src/features/chat/chat_service.dart:630-645` — chat paging GET builder to migrate
  - Pattern: `lib/src/features/chat/session_action_service.dart:220-236` — session action URI builder to migrate
  - Pattern: `lib/src/features/settings/config_service.dart:524-529,550-565` — config fetch/update URI sites to migrate
  - Pattern: `lib/src/features/settings/integration_status_service.dart:203-218,234-253` — integration status URI sites to migrate
  - Test: `test/features/requests/request_service_test.dart`
  - Test: `test/features/files/file_browser_service_test.dart`
  - Test: `test/features/chat/chat_service_test.dart`

  **Acceptance Criteria** (agent-executable only):
  - [ ] `"/home/ubuntu/tools/flutter/bin/flutter" test test/features/projects/project_catalog_service_test.dart test/core/network/event_stream_service_test.dart test/features/requests/request_service_test.dart test/features/files/file_browser_service_test.dart test/features/chat/chat_service_test.dart test/features/settings/config_service_test.dart test/features/settings/integration_status_service_test.dart` exits `0`
  - [ ] `grep -R "baseUri.resolve(" lib/src/features/projects/project_catalog_service.dart lib/src/core/network/event_stream_service.dart lib/src/features/requests/request_service.dart lib/src/features/files/file_browser_service.dart lib/src/features/chat/chat_service.dart lib/src/features/chat/session_action_service.dart lib/src/features/settings/config_service.dart lib/src/features/settings/integration_status_service.dart` returns no remaining migrated anti-pattern matches
  - [ ] `lsp_diagnostics` on modified Dart files reports no errors

  **QA Scenarios** (MANDATORY — task incomplete without these):
  ```text
  Scenario: Prefix deployment no longer breaks project, request, file, chat, and settings calls
    Tool: Bash
    Steps: Run `"/home/ubuntu/tools/flutter/bin/flutter" test test/features/projects/project_catalog_service_test.dart test/features/requests/request_service_test.dart test/features/files/file_browser_service_test.dart test/features/chat/chat_service_test.dart test/features/settings/config_service_test.dart test/features/settings/integration_status_service_test.dart`
    Expected: All targeted service tests pass with prefix/query preservation assertions
    Evidence: .sisyphus/evidence/task-3-service-migration.txt

  Scenario: SSE endpoint preserves base query parameters after migration
    Tool: Bash
    Steps: Run `"/home/ubuntu/tools/flutter/bin/flutter" test test/core/network/event_stream_service_test.dart`
    Expected: Event stream tests pass and new query-preservation assertions stay green
    Evidence: .sisyphus/evidence/task-3-event-stream.txt
  ```

  **Code Review Focus**:
  - Verify every migrated service uses the shared helper instead of ad hoc `resolve`/`replace(queryParameters:)`
  - Verify request-specific params (`directory`, `path`, `before`, `limit`) remain identical to current API contracts
  - Verify PTY remains unchanged and serves only as the semantic baseline

  **Bug Review Checklist**:
  - Re-check prefix-preserving behavior on all migrated services
  - Re-check base query preservation on all migrated services
  - Search for leftover migrated anti-pattern call sites after refactor

  **Commit**: YES | Message: `fix(network): preserve base uri prefixes and queries` | Files: `lib/src/core/network/request_uri.dart`, `lib/src/core/network/event_stream_service.dart`, `lib/src/features/projects/project_catalog_service.dart`, `lib/src/features/requests/request_service.dart`, `lib/src/features/files/file_browser_service.dart`, `lib/src/features/chat/chat_service.dart`, `lib/src/features/chat/session_action_service.dart`, `lib/src/features/settings/config_service.dart`, `lib/src/features/settings/integration_status_service.dart`, `test/**`

- [x] 4. Fix remote session deletion fallback parity in WorkspaceController

  **What to do**: Make the `session.deleted` event path in `WorkspaceController` mirror the semantics of `deleteSelectedSession()`: when the selected session or its tree is removed externally, choose a valid fallback session or safe empty state, clear/reload messages and panels, clear caches/todos/queued prompts/notifications for removed session IDs, and persist last-workspace state consistently.
  **Must NOT do**: Do not change local delete semantics. Do not leave `_selectedSessionId` pointing at a removed session. Do not retain stale `_messages`, `_pendingRequests`, review state, or selected review paths for a removed session.

  **Recommended Agent Profile**:
  - Category: `deep` — Reason: stateful controller parity work touching selection, panels, caches, and persistence
  - Skills: `[]` — current controller tests and local delete path provide the required contract
  - Omitted: `["visual-engineering"]` — this is controller behavior, not UI design

  **Parallelization**: Can Parallel: YES | Wave 2 | Blocks: 8, 9 | Blocked By: 3

  **References**:
  - Pattern: `lib/src/features/web_parity/workspace_controller.dart:3630-3690` — local delete path that already performs correct fallback and cleanup
  - Pattern: `lib/src/features/web_parity/workspace_controller.dart:4861-4908` — remote delete path missing fallback work
  - Test: `test/features/web_parity/workspace_controller_live_sync_test.dart:299-344` — current remote delete coverage to extend

  **Acceptance Criteria** (agent-executable only):
  - [ ] `"/home/ubuntu/tools/flutter/bin/flutter" test test/features/web_parity/workspace_controller_live_sync_test.dart` exits `0`
  - [ ] Remote deletion tests cover selected-session deletion, non-selected deletion, last-session deletion, and already-empty workspace state
  - [ ] Selected session, messages, todos, pending requests, review state, and notification state are consistent after deletion

  **QA Scenarios** (MANDATORY — task incomplete without these):
  ```text
  Scenario: Selected session deleted remotely falls back safely
    Tool: Bash
    Steps: Run `"/home/ubuntu/tools/flutter/bin/flutter" test test/features/web_parity/workspace_controller_live_sync_test.dart --plain-name "controller removes externally deleted sessions in real time"`
    Expected: Extended test proves the controller reselects a valid session or empty state instead of retaining a dead session id
    Evidence: .sisyphus/evidence/task-4-remote-delete.txt

  Scenario: Remote delete also clears stale panel and cache state
    Tool: Bash
    Steps: Run `"/home/ubuntu/tools/flutter/bin/flutter" test test/features/web_parity/workspace_controller_live_sync_test.dart`
    Expected: Suite proves message/todo/review/notification state remains internally consistent after remote deletion
    Evidence: .sisyphus/evidence/task-4-controller-live-sync.txt
  ```

  **Code Review Focus**:
  - Verify remote delete path now mirrors local delete path for selection, panel reset, cache cleanup, and last-workspace persistence
  - Verify only removed session tree IDs are cleared
  - Verify surviving sessions retain correct order and state

  **Bug Review Checklist**:
  - Delete currently selected root session remotely
  - Delete non-selected session remotely
  - Delete the last remaining session remotely and confirm safe empty state

  **Commit**: YES | Message: `fix(workspace): recover selection after remote session delete` | Files: `lib/src/features/web_parity/workspace_controller.dart`, `test/features/web_parity/workspace_controller_live_sync_test.dart`

- [x] 5. Add workspace SSE recovery parity with shell behavior

  **What to do**: Extend `WorkspaceController._connectEvents()` to recover on both `onDone` and `onError` using the existing shell behavior as the parity baseline: disconnect stale stream, reload the relevant workspace/session bundle, avoid duplicate active subscriptions, and resume processing valid later events. Surface recovery through stable controller state rather than silent failure.
  **Must NOT do**: Do not invent a new protocol feature or event replay system. Do not create multiple simultaneous reconnect loops. Do not block load when the SSE best-effort path is unavailable.

  **Recommended Agent Profile**:
  - Category: `deep` — Reason: live state recovery and subscription lifecycle coordination
  - Skills: `[]` — shell implementation already provides the behavioral source of truth
  - Omitted: `["oracle"]` — recovery direction is already fixed by the plan

  **Parallelization**: Can Parallel: YES | Wave 2 | Blocks: 8, 9 | Blocked By: 3

  **References**:
  - Pattern: `lib/src/features/web_parity/workspace_controller.dart:4837-4851` — current no-op recovery path
  - Pattern: `lib/src/features/shell/opencode_shell_screen.dart:2135-2235` — onDone/onError/drop recovery baseline to mirror behaviorally
  - Pattern: `lib/src/core/network/event_stream_service.dart:83-88` — `cancelOnError: true` stream behavior that makes recovery mandatory
  - Test: `test/features/web_parity/workspace_controller_live_sync_test.dart` — controller live sync harness to extend

  **Acceptance Criteria** (agent-executable only):
  - [ ] `"/home/ubuntu/tools/flutter/bin/flutter" test test/features/web_parity/workspace_controller_live_sync_test.dart` exits `0`
  - [ ] Tests prove recovery triggers on both `onDone` and `onError`
  - [ ] Tests prove one active recovery cycle at a time and no duplicate event subscriptions
  - [ ] Post-recovery valid events still update messages/todos/permissions in real time

  **QA Scenarios** (MANDATORY — task incomplete without these):
  ```text
  Scenario: Workspace live sync recovers after stream completion
    Tool: Bash
    Steps: Run `"/home/ubuntu/tools/flutter/bin/flutter" test test/features/web_parity/workspace_controller_live_sync_test.dart`
    Expected: New recovery tests verify onDone reloads state and later events still apply without duplicate listeners
    Evidence: .sisyphus/evidence/task-5-ondone-recovery.txt

  Scenario: Workspace live sync recovers after stream error
    Tool: Bash
    Steps: Run `"/home/ubuntu/tools/flutter/bin/flutter" test test/features/web_parity/workspace_controller_live_sync_test.dart`
    Expected: New recovery tests verify onError follows the same parity path and live updates resume
    Evidence: .sisyphus/evidence/task-5-onerror-recovery.txt
  ```

  **Code Review Focus**:
  - Verify `onDone` and `onError` share one recovery path and one active recovery loop
  - Verify reconnect flow does not leave duplicate subscriptions or stale callbacks alive
  - Verify recovery reload scope matches current workspace/session state only

  **Bug Review Checklist**:
  - Simulate `onDone` and ensure later events still apply
  - Simulate `onError` and ensure later events still apply
  - Trigger repeated drops and confirm no duplicate event application

  **Commit**: YES | Message: `fix(workspace): recover dropped live event streams` | Files: `lib/src/features/web_parity/workspace_controller.dart`, `test/features/web_parity/workspace_controller_live_sync_test.dart`

- [x] 6. Harden malformed request and live event handling

  **What to do**: Make `request_event_applier.dart` follow the same non-crashing semantics as `live_event_applier.dart` for malformed or partial event payloads. Also harden `RequestService.fetchPending()` to drop malformed items instead of failing the whole bundle, and extend controller live-sync tests so malformed events do not prevent later valid events from being processed.
  **Must NOT do**: Do not silently corrupt state. Do not broaden the task into unrelated model parsers. Do not let one malformed request/question payload kill the entire SSE or pending-request flow.

  **Recommended Agent Profile**:
  - Category: `unspecified-high` — Reason: defect-family hardening across reducers, services, and controller behavior
  - Skills: `[]` — existing safe-parse patterns already exist in-repo
  - Omitted: `["deep"]` — architectural shape remains unchanged

  **Parallelization**: Can Parallel: YES | Wave 3 | Blocks: 8, 9 | Blocked By: 1

  **References**:
  - Pattern: `lib/src/core/network/live_event_applier.dart:8-18` — malformed payload returns prior state safely
  - Pattern: `lib/src/features/requests/request_event_applier.dart:3-60` — current direct parse path to harden
  - Pattern: `lib/src/features/requests/request_service.dart:21-53` — current whole-bundle parse path to harden
  - API/Type: `lib/src/features/requests/request_models.dart:83-139` — request model decode behavior
  - Test: `test/features/requests/request_event_applier_test.dart:6-115` — current valid-only coverage
  - Test: `test/features/requests/request_service_test.dart:76-158` — pending request coverage to extend
  - Test: `test/features/web_parity/workspace_controller_live_sync_test.dart` — malformed-event non-crash regression to add

  **Acceptance Criteria** (agent-executable only):
  - [ ] `"/home/ubuntu/tools/flutter/bin/flutter" test test/features/requests/request_event_applier_test.dart test/features/requests/request_service_test.dart test/features/web_parity/workspace_controller_live_sync_test.dart` exits `0`
  - [ ] Malformed `question.asked` / `permission.asked` events leave prior state intact and do not throw
  - [ ] Malformed pending request items are skipped while valid siblings still load
  - [ ] A malformed live/request event does not stop later valid events from applying

  **QA Scenarios** (MANDATORY — task incomplete without these):
  ```text
  Scenario: Malformed request events do not crash reducers
    Tool: Bash
    Steps: Run `"/home/ubuntu/tools/flutter/bin/flutter" test test/features/requests/request_event_applier_test.dart`
    Expected: Added malformed-payload cases preserve prior state and suite exits 0
    Evidence: .sisyphus/evidence/task-6-request-applier.txt

  Scenario: Malformed live/request payloads do not poison later updates
    Tool: Bash
    Steps: Run `"/home/ubuntu/tools/flutter/bin/flutter" test test/features/web_parity/workspace_controller_live_sync_test.dart test/features/requests/request_service_test.dart`
    Expected: Suites prove invalid payloads are skipped and later valid events or pending items still apply
    Evidence: .sisyphus/evidence/task-6-live-sync.txt
  ```

  **Code Review Focus**:
  - Verify malformed payload handling returns prior state instead of throwing
  - Verify valid sibling items in pending bundles still load when one item is malformed
  - Verify controller continues processing later valid events after malformed ones

  **Bug Review Checklist**:
  - Inject malformed `question.asked` payload
  - Inject malformed `permission.asked` payload
  - Inject malformed pending-request list item beside a valid one

  **Commit**: YES | Message: `fix(events): ignore malformed request payloads safely` | Files: `lib/src/features/requests/request_event_applier.dart`, `lib/src/features/requests/request_service.dart`, `test/features/requests/request_event_applier_test.dart`, `test/features/requests/request_service_test.dart`, `test/features/web_parity/workspace_controller_live_sync_test.dart`

- [x] 7. Clean localization duplicates and Korean copy consistency

  **What to do**: Remove duplicate ARB keys in both `app_en.arb` and `app_ko.arb`, keep only one source-of-truth copy per key, clean obviously untranslated Korean technical English (`stale stream`, `capability`, `Thinking`, `diff`, `todo`, `shell` where user-facing Korean equivalents are appropriate), and regenerate `app_localizations*.dart` from the corrected ARB sources.
  **Must NOT do**: Do not rewrite unrelated product copy. Do not change user-facing English copy except where duplicate-key resolution requires choosing the intended surviving value. Do not leave generated localization outputs stale.

  **Recommended Agent Profile**:
  - Category: `writing` — Reason: localization quality and duplicate-key cleanup
  - Skills: `[]` — repository l10n files provide the needed context
  - Omitted: `["visual-engineering"]` — no layout work is required

  **Parallelization**: Can Parallel: YES | Wave 3 | Blocks: 8, 9 | Blocked By: none

  **References**:
  - Pattern: `lib/l10n/app_en.arb:401-404,492-495` — duplicate key block in English
  - Pattern: `lib/l10n/app_ko.arb:401-404,492-495` — duplicate key block in Korean
  - Pattern: `lib/l10n/app_ko.arb:12-17,84-101,396-415` — leftover English technical jargon to normalize
  - Test: `test/features/home/home_copy_accessibility_test.dart`
  - Test: `test/features/shell/shell_copy_accessibility_test.dart`

  **Acceptance Criteria** (agent-executable only):
  - [ ] `grep -n "shellRenameSessionTitle" lib/l10n/app_en.arb lib/l10n/app_ko.arb` shows one definition per file
  - [ ] `"/home/ubuntu/tools/flutter/bin/flutter" gen-l10n` exits `0`
  - [ ] `"/home/ubuntu/tools/flutter/bin/flutter" test test/features/home/home_copy_accessibility_test.dart test/features/shell/shell_copy_accessibility_test.dart` exits `0`

  **QA Scenarios** (MANDATORY — task incomplete without these):
  ```text
  Scenario: ARB duplicate keys are removed and localizations regenerate cleanly
    Tool: Bash
    Steps: Run `"/home/ubuntu/tools/flutter/bin/flutter" gen-l10n`
    Expected: Localization generation succeeds with no duplicate-key or ARB-shape errors
    Evidence: .sisyphus/evidence/task-7-gen-l10n.txt

  Scenario: User-facing copy remains stable after Korean cleanup
    Tool: Bash
    Steps: Run `"/home/ubuntu/tools/flutter/bin/flutter" test test/features/home/home_copy_accessibility_test.dart test/features/shell/shell_copy_accessibility_test.dart`
    Expected: Existing copy/a11y suites still pass after ARB cleanup and regeneration
    Evidence: .sisyphus/evidence/task-7-copy-tests.txt
  ```

  **Code Review Focus**:
  - Verify each duplicate key survives only once per ARB file
  - Verify Korean replacements are user-facing translations, not mixed English jargon
  - Verify regenerated localization outputs reflect only intended copy changes

  **Bug Review Checklist**:
  - Search duplicate keys in both ARB files after cleanup
  - Regenerate localization outputs and diff them for unintended churn
  - Re-run home/shell copy tests for regression detection

  **Commit**: YES | Message: `fix(l10n): remove duplicate keys and normalize ko copy` | Files: `lib/l10n/app_en.arb`, `lib/l10n/app_ko.arb`, `lib/l10n/app_localizations*.dart`, `test/features/home/*`, `test/features/shell/*`

- [x] 8. Align platform/repository hygiene and generated-file policy

  **What to do**: Activate `platform :ios, '13.0'` in `ios/Podfile` to match the already-declared Xcode deployment target, decide and document generated-file policy, and stop tracking Xcode workspace-check noise by adding ignore rules and removing tracked `IDEWorkspaceChecks.plist` files under iOS/macOS workspaces. Keep generated localization Dart files tracked if that remains the chosen repository policy, but document regeneration steps explicitly.
  **Must NOT do**: Do not change Android signing. Do not change iOS deployment target away from 13.0. Do not remove generated localization files without also replacing the workflow that depends on them.

  **Recommended Agent Profile**:
  - Category: `unspecified-high` — Reason: platform config + repository hygiene with low UI impact
  - Skills: `[]` — current repo layout is enough context
  - Omitted: `["writing"]` — policy text is secondary to the config/file-state fix

  **Parallelization**: Can Parallel: YES | Wave 3 | Blocks: 9 | Blocked By: 4, 5, 6, 7

  **References**:
  - Pattern: `ios/Podfile:1-2` — commented-out global iOS platform declaration to align
  - Pattern: `.metadata:21-35` — iOS/macOS remain active managed platforms
  - Pattern: `.gitignore:48-49` — current tracked-local-file policy is minimal
  - Pattern: `ios/Runner.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist` — tracked generated Xcode workspace check file to remove/ignore
  - Pattern: `macos/Runner.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist` — same class of tracked noise on macOS

  **Acceptance Criteria** (agent-executable only):
  - [ ] `grep -n "platform :ios, '13.0'" ios/Podfile` finds one active line
  - [ ] `git ls-files | grep "IDEWorkspaceChecks.plist"` returns no tracked workspace-check files
  - [ ] `.gitignore` contains explicit ignore rules for workspace-check noise and documented generated-file policy references

  **QA Scenarios** (MANDATORY — task incomplete without these):
  ```text
  Scenario: iOS deployment target declaration is aligned at the Podfile entry point
    Tool: Bash
    Steps: Run `grep -n "platform :ios, '13.0'" ios/Podfile`
    Expected: One active Podfile platform declaration matches the Xcode target floor
    Evidence: .sisyphus/evidence/task-8-ios-platform.txt

  Scenario: Xcode workspace-check noise is no longer tracked
    Tool: Bash
    Steps: Run `git ls-files | grep "IDEWorkspaceChecks.plist"`
    Expected: No tracked IDEWorkspaceChecks files remain
    Evidence: .sisyphus/evidence/task-8-workspace-checks.txt
  ```

  **Code Review Focus**:
  - Verify Podfile target matches the existing Xcode deployment floor of 13.0
  - Verify only workspace-check noise is removed/ignored, not required workspace metadata
  - Verify generated-file policy is explicit about what stays tracked vs ignored

  **Bug Review Checklist**:
  - Confirm no tracked `IDEWorkspaceChecks.plist` files remain
  - Confirm Podfile target activation does not change the target version
  - Confirm localization generation policy stays executable after repo cleanup

  **Commit**: YES | Message: `chore(repo): align ios target and generated-file policy` | Files: `ios/Podfile`, `.gitignore`, `ios/**/IDEWorkspaceChecks.plist`, `macos/**/IDEWorkspaceChecks.plist`, `README.md`

- [ ] 9. Refresh README, architecture docs, mission notes, and repo-visible CI

  **What to do**: Replace the template-level README with project-specific setup/run/test/debug guidance, add explicit references to manual tools under `tool/manual`, document the post-fix URI/recovery behavior at a repo-facing level, update `docs/architecture/foundation-architecture.md` so it no longer claims a single active `EventReducer` writer, correct outdated mission notes where they describe now-obsolete runtime ownership, and add `.github/workflows/ci.yml` to run analyze, gen-l10n, and tests on GitHub Actions.
  **Must NOT do**: Do not invent release/deploy automation or external infrastructure beyond CI for existing repository checks. Do not leave docs describing the pre-fix runtime. Do not keep the template Flutter getting-started text.

  **Recommended Agent Profile**:
  - Category: `writing` — Reason: documentation correctness plus CI description and workflow clarity
  - Skills: `[]` — repo docs and tests provide the necessary source material
  - Omitted: `["deep"]` — architecture is being documented, not redesigned

  **Parallelization**: Can Parallel: NO | Wave 4 | Blocks: Final Verification | Blocked By: 1, 2, 3, 4, 5, 6, 7, 8

  **References**:
  - Pattern: `README.md:5-17` — template text to replace fully
  - Pattern: `docs/architecture/foundation-architecture.md:45-58` — single-writer reducer claim to revise
  - Pattern: `docs/mission-04-performance-notes.md:7-26` — shell/runtime references to refresh where stale
  - Pattern: `docs/mission-06-scenario-review.md:32-44` — outdated reducer/shell responsibility references to refresh
  - Pattern: `tool/manual/run_shell_derived_data.dart:8-56` — example manual verification tool to surface in docs
  - Pattern: `.sisyphus/plans/release-ready-app-redesign.md:48-54` — existing repository command conventions for explicit Flutter paths

  **Acceptance Criteria** (agent-executable only):
  - [ ] `test -f .github/workflows/ci.yml` exits `0`
  - [ ] `grep -n "starting point for a Flutter application" README.md` returns no matches
  - [ ] `grep -n "single writer" docs/architecture/foundation-architecture.md` returns no stale runtime claim
  - [ ] `"/home/ubuntu/tools/flutter/bin/flutter" analyze && "/home/ubuntu/tools/flutter/bin/flutter" gen-l10n && "/home/ubuntu/tools/flutter/bin/flutter" test` is the exact command sequence encoded in CI

  **QA Scenarios** (MANDATORY — task incomplete without these):
  ```text
  Scenario: README and architecture docs reflect the real post-fix runtime
    Tool: Bash
    Steps: Run `grep -n "starting point for a Flutter application" README.md`; run `grep -n "single writer" docs/architecture/foundation-architecture.md`
    Expected: Template README text is gone and stale single-writer runtime wording is gone
    Evidence: .sisyphus/evidence/task-9-docs-sync.txt

  Scenario: Repo-visible CI exists and matches local verification commands
    Tool: Bash
    Steps: Run `test -f .github/workflows/ci.yml`; read the workflow file and confirm it runs analyze, gen-l10n, and tests
    Expected: Workflow exists and encodes the same verification sequence used locally
    Evidence: .sisyphus/evidence/task-9-ci.txt
  ```

  **Code Review Focus**:
  - Verify README replaces template text with current project setup/test/manual-tool guidance
  - Verify architecture and mission docs describe the post-fix runtime ownership accurately
  - Verify CI workflow mirrors local verification commands without adding unrelated deployment scope

  **Bug Review Checklist**:
  - Search for stale template README text
  - Search for stale `single writer` architecture wording
  - Read CI YAML and confirm it runs analyze, gen-l10n, and tests in that order

  **Commit**: YES | Message: `docs(repo): sync runtime docs and add ci checks` | Files: `README.md`, `docs/architecture/foundation-architecture.md`, `docs/mission-04-performance-notes.md`, `docs/mission-06-scenario-review.md`, `.github/workflows/ci.yml`

## Final Verification Wave (MANDATORY — after ALL implementation tasks)
> 4 review agents run in PARALLEL. ALL must APPROVE. Present consolidated results to user and get explicit "okay" before completing.
> **Do NOT auto-proceed after verification. Wait for user's explicit approval before marking work complete.**
> **Never mark F1-F4 as checked before getting user's okay.** Rejection or user feedback -> fix -> re-run -> present again -> wait for okay.
- [x] F1. Plan Compliance Audit — oracle
- [x] F2. Code Quality Review — unspecified-high
- [x] F3. Real Manual QA — unspecified-high (+ playwright if UI)
- [x] F4. Scope Fidelity Check — deep

## Commit Strategy
- Commit 1: `refactor(package): align dart package identity`
- Commit 2: `test(network): lock shared request uri semantics`
- Commit 3: `fix(network): preserve base uri prefixes and queries`
- Commit 4: `fix(workspace): recover selection after remote session delete`
- Commit 5: `fix(workspace): recover dropped live event streams`
- Commit 6: `fix(events): ignore malformed request payloads safely`
- Commit 7: `fix(l10n): remove duplicate keys and normalize ko copy`
- Commit 8: `chore(repo): align ios target and generated-file policy`
- Commit 9: `docs(repo): sync runtime docs and add ci checks`

## Success Criteria
- Prefix-routed and query-routed deployments behave consistently across all migrated services
- Workspace selected-session state never remains stuck on a remotely deleted session
- Workspace live updates recover after disconnect/error and resume applying valid later events
- Malformed question/permission/live payloads no longer crash or poison subsequent valid updates
- Dart package naming is consistent with the repository identity
- Localization files have no duplicate keys and Korean copy no longer leaks obvious English technical jargon
- Repo-facing docs and mission notes describe the actual post-fix runtime and tooling
- GitHub-hosted CI is present and enforces analyze, localization generation, and tests
