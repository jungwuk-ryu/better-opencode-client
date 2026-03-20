# Release-Ready Workspace Redesign

## TL;DR
> **Summary**: Reframe the app from a probe-first internal tool into a workspace-manager product that gets users from saved server to project to session quickly, while moving diagnostics into `Advanced` and hardening saved credentials for release.
> **Deliverables**:
> - Branded workspace home with saved servers and recent workspaces
> - Background connection compatibility flow instead of foreground probe UX
> - Adaptive shell IA with stable primary destinations across breakpoints
> - Advanced/settings area for retained internal tools
> - Secure credential storage migration and regression coverage
> **Effort**: XL
> **Parallel**: YES - 4 waves
> **Critical Path**: Task 1 -> Task 2 -> Task 4 -> Task 6 -> Task 8 -> Task 11 -> Final Verification

## Context
### Original Request
The user wants the app to stop feeling like a beta/internal tool, specifically calling out that the initial screen should not foreground probe results and API capability displays. The release target is a real product with app identity, server entry, existing server list, and a full-release level of polish.

### Interview Summary
- Product framing: `Workspace manager`
- Internal/operator tooling: keep available only behind `Advanced`
- Verification: `tests-after + QA`
- Security scope: include credential-storage hardening now
- Default applied: do not auto-jump straight into a workspace on launch; show a workspace home with a prominent `Resume last workspace` action instead
- Default applied: keep Basic-auth-compatible connection UX for v1 and improve storage/security rather than changing auth model
- Default applied: include branding, copy polish, accessibility, and empty-state work in this release plan; exclude analytics/crash-reporting platform work unless a blocker is discovered

### Metis Review (gaps addressed)
- Added a launch-state decision table covering first run, single saved server, multiple servers, unreachable server, missing project, and missing session
- Treated secure credential migration as a dedicated workstream with migration and purge behavior
- Bound the redesign around the existing product backbone `server -> project -> session -> chat` rather than inventing a new domain model
- Locked a file-by-file segregation of primary surfaces vs `Advanced`
- Added explicit breakpoint parity requirements so compact layouts do not lose core session navigation

## Work Objectives
### Core Objective
Ship a release-ready Flutter client whose default experience is a branded workspace manager, not a diagnostics console, while preserving the existing OpenCode workflow and safely migrating stored credentials.

### Deliverables
- New launch/home experience replacing probe-first entry
- Revised connection model that treats compatibility probing as background state
- Resume-first workspace flow for saved servers, recent projects, and recent sessions
- Adaptive shell navigation with the same primary product destinations on mobile, tablet, and desktop
- `Advanced` area containing retained technical/operator tools
- Secure storage migration for saved credentials and draft credentials
- Widget and integration coverage for release-critical launch, resume, and navigation flows

### Definition of Done (verifiable conditions with commands)
- `"/home/ubuntu/tools/flutter/bin/flutter" test test/features/launch` exits `0` and prints `All tests passed!`
- `"/home/ubuntu/tools/flutter/bin/flutter" test test/features/home` exits `0` and prints `All tests passed!`
- `"/home/ubuntu/tools/flutter/bin/flutter" test test/features/shell` exits `0` and prints `All tests passed!`
- `"/home/ubuntu/tools/flutter/bin/flutter" test test/core/persistence` exits `0` and prints `All tests passed!`
- `"/home/ubuntu/tools/flutter/bin/flutter" test integration_test` exits `0` and prints `All tests passed!`
- `lsp_diagnostics` on modified Dart files reports no errors

### Must Have
- Launch into a branded home that shows app identity, saved servers, recent workspaces, and a primary `Add server` / `Resume last workspace` path
- Replace explicit `Probe server` as the primary CTA with `Connect` / `Continue`
- Run server compatibility/auth checks in the background and surface only actionable user-facing states
- Preserve the existing domain backbone: server, project, session, chat
- Keep files, todos, approvals, and chat-related context in primary product surfaces
- Move probe detail, raw inspector, config preview/edit, integration diagnostics, cache controls, and terminal-like tooling into `Advanced`
- Keep shell parity across compact, medium, wide, and desktop breakpoints
- Migrate saved credentials away from plaintext `SharedPreferences`

### Must NOT Have (guardrails, AI slop patterns, scope boundaries)
- Must not expose endpoint matrices, raw capability chips, fixture diagnostics, flavor badges, or locale badges in default user flows
- Must not require users to understand `/doc`, `/config`, `/provider`, or capability semantics to start using the app
- Must not auto-resume into a workspace without a visible way to switch server/project/session from home
- Must not redesign backend APIs, capability protocols, or session semantics unless a specific blocker is proven
- Must not leave mobile/portrait users without access to primary session navigation
- Must not store credentials or draft secrets in plaintext preferences after migration

## Verification Strategy
> ZERO HUMAN INTERVENTION — all verification is agent-executed.
- Test decision: tests-after + Flutter widget tests + Flutter integration tests
- QA policy: every task includes agent-executed happy-path and failure-path scenarios
- Evidence: `.sisyphus/evidence/task-{N}-{slug}.{ext}`

## Execution Strategy
### Parallel Execution Waves
> Target: 5-8 tasks per wave. Extract shared dependencies first.

Wave 1: release characterization, secure storage foundation, launch-state model
Wave 2: workspace home, connection cards, background connection state, resume flow
Wave 3: project selection integration, shell adaptive IA, advanced/settings segregation
Wave 4: branding/copy/accessibility polish, release regression suite, cleanup

### Dependency Matrix (full, all tasks)
| Task | Depends On | Enables |
|---|---|---|
| 1 | none | 2, 4, 6, 8 |
| 2 | 1 | 5, 6, 11 |
| 3 | 1 | 4, 6, 8 |
| 4 | 1, 3 | 5, 6, 8 |
| 5 | 2, 4 | 6, 7 |
| 6 | 2, 3, 4, 5 | 7, 8 |
| 7 | 5, 6 | 8 |
| 8 | 1, 4, 6, 7 | 9, 10 |
| 9 | 1, 8 | 10, 11 |
| 10 | 1, 8, 9 | 11 |
| 11 | 2, 8, 9, 10 | 12 |
| 12 | 1, 2, 8, 9, 10, 11 | Final Verification |

### Agent Dispatch Summary (wave -> task count -> categories)
- Wave 1 -> 3 tasks -> `unspecified-high`
- Wave 2 -> 4 tasks -> `visual-engineering`, `unspecified-high`
- Wave 3 -> 3 tasks -> `visual-engineering`, `deep`
- Wave 4 -> 2 tasks -> `writing`, `unspecified-high`
- Final Verification -> 4 tasks -> `oracle`, `unspecified-high`, `deep`

## Launch-State Decision Table
| State | Default Behavior | User-Facing Surface | Advanced Availability |
|---|---|---|---|
| First run, no servers | Show branded empty home with `Add server` CTA | Home empty state | none |
| One saved server, recent workspace available | Show home with `Resume last workspace` as primary CTA and server card beneath | Home summary card | `Advanced` diagnostics for that server |
| Multiple saved servers | Show server list sorted by pinned/recent and recent workspaces section | Home list | per-server `Advanced` actions |
| Saved server unreachable | Keep user on home, mark server `Offline`, offer `Retry` and `Edit` | Server card inline error | full connection details in `Advanced` |
| Auth failed | Keep user on home, mark server `Sign-in required`, preserve input, offer `Edit credentials` | Server card inline error | auth/probe details in `Advanced` |
| Project missing/inaccessible | Keep server connected but route to project chooser with missing-project notice | Resume panel fallback | project diagnostics in `Advanced` |
| Session missing | Open project successfully and land in session list with `Start new session` CTA | Shell sessions destination | raw inspector in `Advanced` |

## Primary vs Advanced Surface Mapping
### Primary
- `Home`: app identity, saved servers, recent workspaces, add/edit server, resume last workspace
- `Shell/Sessions`: session list, session status, new session, session switching
- `Shell/Chat`: message timeline, composer, core session actions relevant to chat
- `Shell/Context`: files, todos, approvals/questions, essential workspace context
- `Settings`: user-facing settings, locale, account/session-safe preferences

### Advanced
- Probe endpoint detail and raw compatibility detail currently in `lib/src/features/connection/connection_home_screen.dart`
- Raw inspector currently in `lib/src/features/shell/opencode_shell_screen.dart` and `lib/src/features/shell/shell_derived_data.dart`
- Config preview/edit currently in `lib/src/features/settings/config_edit_preview.dart` and shell panels
- Integration status, event recovery/health, cache settings, and terminal-style utilities currently surfaced from `lib/src/features/shell/opencode_shell_screen.dart` and `lib/src/features/settings/cache_settings_sheet.dart`

## TODOs
> Implementation + Test = ONE task. Never separate.
> EVERY task MUST have: Agent Profile + Parallelization + QA Scenarios.

- [x] 1. Characterize current launch, persistence, and breakpoint behavior

  **What to do**: Add characterization coverage for the current launch flow, saved-profile persistence, draft credential persistence, and shell breakpoint behavior before changing product IA. Capture the present behavior of `ConnectionHomeScreen`, `ServerProfileStore`, and `OpenCodeShellScreen` so later redesign changes are measurable instead of accidental.
  **Must NOT do**: Do not change product behavior in this task. Do not introduce new UI or secure storage yet.

  **Recommended Agent Profile**:
  - Category: `unspecified-high` — Reason: multi-file test characterization across launch, persistence, and shell behavior
  - Skills: `[]` — existing repo patterns are sufficient
  - Omitted: `['playwright']` — browser/manual tooling is not needed for baseline characterization

  **Parallelization**: Can Parallel: YES | Wave 1 | Blocks: 2, 3, 4, 6, 8 | Blocked By: none

  **References**:
  - Pattern: `test/features/shell/opencode_shell_screen_test.dart` — existing widget-testing style and breakpoint setup
  - Pattern: `test/core/persistence/server_profile_store_test.dart` — persistence/service testing style
  - Pattern: `test/core/network/opencode_server_probe_test.dart` — local server and behavior-focused assertions
  - API/Type: `lib/src/app/app.dart` — current app home wiring
  - API/Type: `lib/src/features/connection/connection_home_screen.dart` — current entry behavior and draft persistence
  - API/Type: `lib/src/features/shell/opencode_shell_screen.dart` — adaptive shell breakpoints and current utility surfacing

  **Acceptance Criteria** (agent-executable only):
  - [ ] `"/home/ubuntu/tools/flutter/bin/flutter" test test/features/launch/app_launch_characterization_test.dart` exits `0` and prints `All tests passed!`
  - [ ] `"/home/ubuntu/tools/flutter/bin/flutter" test test/core/persistence/server_profile_store_test.dart` exits `0` and prints `All tests passed!`
  - [ ] `"/home/ubuntu/tools/flutter/bin/flutter" test test/features/shell/shell_breakpoint_characterization_test.dart` exits `0` and prints `All tests passed!`

  **QA Scenarios** (MANDATORY — task incomplete without these):
  ```text
  Scenario: Current first-run launch behavior is documented
    Tool: Bash
    Steps: Run "/home/ubuntu/tools/flutter/bin/flutter" test test/features/launch/app_launch_characterization_test.dart
    Expected: Test suite records current home screen behavior and exits 0 with "All tests passed!"
    Evidence: .sisyphus/evidence/task-1-characterization.txt

  Scenario: Current compact and wide shell behavior is documented
    Tool: Bash
    Steps: Run "/home/ubuntu/tools/flutter/bin/flutter" test test/features/shell/shell_breakpoint_characterization_test.dart
    Expected: Tests assert current destination availability at compact, medium, and wide widths and exit 0 with "All tests passed!"
    Evidence: .sisyphus/evidence/task-1-breakpoints.txt
  ```

  **Commit**: YES | Message: `test(launch): characterize current app flow` | Files: `test/features/launch/*`, `test/features/shell/*`, `test/core/persistence/*`

- [x] 2. Replace plaintext credential persistence with secure storage and migration

  **What to do**: Introduce a secure credential persistence layer for saved server credentials and draft credentials, migrate legacy plaintext data from `SharedPreferences`, define purge-on-success behavior for old keys, and keep the current Basic-auth-compatible data model. Ensure migration handles partial or corrupt legacy payloads gracefully.
  **Must NOT do**: Do not change the external auth model, backend API contract, or server profile semantics. Do not leave duplicate plaintext secret copies after a successful migration.

  **Recommended Agent Profile**:
  - Category: `unspecified-high` — Reason: persistence refactor plus migration logic and tests
  - Skills: `[]` — repository conventions are enough
  - Omitted: `['visual-engineering']` — no UI-heavy work here

  **Parallelization**: Can Parallel: YES | Wave 1 | Blocks: 5, 6, 11, 12 | Blocked By: 1

  **References**:
  - Pattern: `lib/src/core/persistence/server_profile_store.dart` — current persistence entry point to refactor
  - Pattern: `test/core/persistence/server_profile_store_test.dart` — persistence test baseline
  - API/Type: `lib/src/core/connection/connection_models.dart` — server profile serialization contract
  - API/Type: `lib/src/features/connection/connection_home_screen.dart` — draft persistence call sites
  - External: `https://docs.flutter.dev/cookbook/persistence/key-value` — current key-value persistence context to move beyond

  **Acceptance Criteria** (agent-executable only):
  - [ ] `"/home/ubuntu/tools/flutter/bin/flutter" test test/core/persistence/secure_server_profile_store_test.dart` exits `0` and prints `All tests passed!`
  - [ ] `"/home/ubuntu/tools/flutter/bin/flutter" test test/core/persistence/server_profile_migration_test.dart` exits `0` and prints `All tests passed!`
  - [ ] `lsp_diagnostics` on the modified persistence files reports no errors

  **QA Scenarios** (MANDATORY — task incomplete without these):
  ```text
  Scenario: Legacy plaintext credentials migrate successfully
    Tool: Bash
    Steps: Run "/home/ubuntu/tools/flutter/bin/flutter" test test/core/persistence/server_profile_migration_test.dart
    Expected: Tests verify legacy SharedPreferences credentials are read once, migrated to secure storage, and plaintext keys are removed or ignored; suite exits 0 with "All tests passed!"
    Evidence: .sisyphus/evidence/task-2-migration.txt

  Scenario: Corrupt or partial legacy secrets fail safely
    Tool: Bash
    Steps: Run "/home/ubuntu/tools/flutter/bin/flutter" test test/core/persistence/secure_server_profile_store_test.dart
    Expected: Tests verify corrupt data does not crash launch and invalid credentials are not surfaced as valid saved secrets; suite exits 0 with "All tests passed!"
    Evidence: .sisyphus/evidence/task-2-secure-store.txt
  ```

  **Commit**: YES | Message: `refactor(persistence): secure saved server credentials` | Files: `lib/src/core/persistence/*`, `lib/src/core/connection/*`, `test/core/persistence/*`

- [x] 3. Define release launch-state model and connection status vocabulary

  **What to do**: Add a dedicated launch/home state model that separates `reachable`, `auth required`, `feature availability`, `offline`, `project missing`, and `session missing` states so the redesigned home can show actionable product messaging instead of raw probe output. Convert current probe classifications into user-facing state and messaging contracts suitable for home cards and advanced details.
  **Must NOT do**: Do not surface endpoint lists or raw capability chips in the new public model. Do not tie home rendering directly to low-level probe path names.

  **Recommended Agent Profile**:
  - Category: `unspecified-high` — Reason: domain/UI-state modeling with downstream impact
  - Skills: `[]` — no extra skill required
  - Omitted: `['writing']` — copy polish happens later

  **Parallelization**: Can Parallel: YES | Wave 1 | Blocks: 4, 6, 8 | Blocked By: 1

  **References**:
  - Pattern: `lib/src/core/network/opencode_server_probe.dart` — existing low-level connection classification source
  - Pattern: `lib/src/core/spec/capability_registry.dart` — current feature-availability adapter layer
  - API/Type: `lib/src/core/connection/connection_models.dart` — server profile domain types
  - API/Type: `lib/src/features/projects/project_models.dart` — project/session resume fields already available
  - External: `https://m1.material.io/patterns/errors.html` — actionable error-state guidance

  **Acceptance Criteria** (agent-executable only):
  - [ ] `"/home/ubuntu/tools/flutter/bin/flutter" test test/features/launch/launch_state_model_test.dart` exits `0` and prints `All tests passed!`
  - [ ] `"/home/ubuntu/tools/flutter/bin/flutter" test test/features/connection/connection_status_mapping_test.dart` exits `0` and prints `All tests passed!`
  - [ ] `lsp_diagnostics` on the modified launch-state model files reports no errors

  **QA Scenarios** (MANDATORY — task incomplete without these):
  ```text
  Scenario: Probe classifications map to product-facing launch states
    Tool: Bash
    Steps: Run "/home/ubuntu/tools/flutter/bin/flutter" test test/features/connection/connection_status_mapping_test.dart
    Expected: Tests verify auth failure, offline, unsupported, and ready states map to user-facing statuses without raw endpoint jargon; suite exits 0 with "All tests passed!"
    Evidence: .sisyphus/evidence/task-3-status-map.txt

  Scenario: Resume edge cases are represented explicitly
    Tool: Bash
    Steps: Run "/home/ubuntu/tools/flutter/bin/flutter" test test/features/launch/launch_state_model_test.dart
    Expected: Tests cover no servers, one saved server, many servers, missing project, and missing session cases; suite exits 0 with "All tests passed!"
    Evidence: .sisyphus/evidence/task-3-launch-state.txt
  ```

  **Commit**: YES | Message: `feat(launch): define release home state model` | Files: `lib/src/features/launch/*`, `lib/src/features/connection/*`, `test/features/launch/*`, `test/features/connection/*`

- [x] 4. Replace probe-first entry with a branded workspace home scaffold

  **What to do**: Introduce a new top-level home screen and app entry wiring that presents app identity, saved servers, recent workspaces, and primary actions (`Add server`, `Resume last workspace`, `Open server`). Route app startup to this screen instead of using `ConnectionHomeScreen` as the direct home. Keep the existing connection screen only as an internal implementation seam or advanced/details editor until subsequent tasks finish migrating behavior.
  **Must NOT do**: Do not retain probe metrics, flavor badges, locale badges, or endpoint detail in the primary home. Do not auto-enter the shell from app launch in this task.

  **Recommended Agent Profile**:
  - Category: `visual-engineering` — Reason: new top-level release UI and app entry scaffolding
  - Skills: `[]` — existing design system should be followed
  - Omitted: `['artistry']` — this is product-aligned redesign, not experimental visual exploration

  **Parallelization**: Can Parallel: YES | Wave 2 | Blocks: 5, 6, 8 | Blocked By: 1, 3

  **References**:
  - Pattern: `lib/src/app/app.dart` — current MaterialApp entry seam to replace
  - Pattern: `lib/src/features/connection/connection_home_screen.dart` — existing server lists and draft-editing behaviors to reuse selectively
  - Pattern: `lib/src/design_system/app_theme.dart` — theme and surface language to preserve
  - Pattern: `lib/src/design_system/app_spacing.dart` — spacing/radius/layout constants
  - External: `https://m2.material.io/design/communication/empty-states.html` — release-grade empty-state guidance

  **Acceptance Criteria** (agent-executable only):
  - [ ] `"/home/ubuntu/tools/flutter/bin/flutter" test test/features/home/workspace_home_screen_test.dart` exits `0` and prints `All tests passed!`
  - [ ] `"/home/ubuntu/tools/flutter/bin/flutter" test test/features/launch/app_entry_routing_test.dart` exits `0` and prints `All tests passed!`
  - [ ] `lsp_diagnostics` on the modified entry/home files reports no errors

  **QA Scenarios** (MANDATORY — task incomplete without these):
  ```text
  Scenario: First-run users see a branded home instead of probe diagnostics
    Tool: Bash
    Steps: Run "/home/ubuntu/tools/flutter/bin/flutter" test test/features/home/workspace_home_screen_test.dart
    Expected: Tests assert app title, add-server CTA, and empty-state content are visible while probe jargon is absent; suite exits 0 with "All tests passed!"
    Evidence: .sisyphus/evidence/task-4-home.txt

  Scenario: Launch routing no longer boots directly into ConnectionHomeScreen
    Tool: Bash
    Steps: Run "/home/ubuntu/tools/flutter/bin/flutter" test test/features/launch/app_entry_routing_test.dart
    Expected: Tests verify the MaterialApp home resolves to the new workspace home and not the legacy probe-first screen; suite exits 0 with "All tests passed!"
    Evidence: .sisyphus/evidence/task-4-entry.txt
  ```

  **Commit**: YES | Message: `feat(home): add release workspace landing screen` | Files: `lib/src/app/*`, `lib/src/features/home/*`, `test/features/home/*`, `test/features/launch/*`

- [x] 5. Build release-grade server cards and editing flows on home

  **What to do**: Redesign saved-server presentation into release-grade server cards/lists with clear server identity, last-used context, connect/edit actions, and inline status summaries. Reuse current saved-profile and recent-connection data, but remove diagnostic-heavy presentation and rename actions around `Connect`, `Continue`, and `Edit server` instead of `Probe`.
  **Must NOT do**: Do not expose capability counts, endpoint statuses, experimental paths, or raw auth failure summaries on the main cards. Do not remove the ability to add or edit server credentials.

  **Recommended Agent Profile**:
  - Category: `visual-engineering` — Reason: primary release-facing server management UI
  - Skills: `[]` — repo design system should drive styling
  - Omitted: `['deep']` — no deep architecture work beyond the agreed product model

  **Parallelization**: Can Parallel: YES | Wave 2 | Blocks: 6, 7 | Blocked By: 2, 4

  **References**:
  - Pattern: `lib/src/features/connection/connection_home_screen.dart` — existing saved profile and recent connection data sources
  - Pattern: `lib/src/core/persistence/server_profile_store.dart` — persistence APIs for save/delete/pin/recent state
  - API/Type: `lib/src/core/connection/connection_models.dart` — server profile and recent connection fields
  - External: `https://www.nngroup.com/articles/empty-state-interface-design/` — empty-state and next-action guidance

  **Acceptance Criteria** (agent-executable only):
  - [ ] `"/home/ubuntu/tools/flutter/bin/flutter" test test/features/home/server_cards_test.dart` exits `0` and prints `All tests passed!`
  - [ ] `"/home/ubuntu/tools/flutter/bin/flutter" test test/features/home/server_editor_flow_test.dart` exits `0` and prints `All tests passed!`
  - [ ] `lsp_diagnostics` on the modified server-card/editor files reports no errors

  **QA Scenarios** (MANDATORY — task incomplete without these):
  ```text
  Scenario: Returning user sees saved servers with product-facing actions
    Tool: Bash
    Steps: Run "/home/ubuntu/tools/flutter/bin/flutter" test test/features/home/server_cards_test.dart
    Expected: Tests verify server cards render names like "Local Dev" and actions like "Continue" or "Edit server" without probe/capability jargon; suite exits 0 with "All tests passed!"
    Evidence: .sisyphus/evidence/task-5-server-cards.txt

  Scenario: Credential editing remains available without exposing raw diagnostics
    Tool: Bash
    Steps: Run "/home/ubuntu/tools/flutter/bin/flutter" test test/features/home/server_editor_flow_test.dart
    Expected: Tests verify username/password editing, validation, and save behavior continue to work from home-driven flows; suite exits 0 with "All tests passed!"
    Evidence: .sisyphus/evidence/task-5-server-editor.txt
  ```

  **Commit**: YES | Message: `feat(home): redesign saved server management` | Files: `lib/src/features/home/*`, `lib/src/features/connection/*`, `test/features/home/*`

- [x] 6. Convert connection/probe into background connect-and-continue behavior

  **What to do**: Rework the connection path so pressing `Connect` or `Continue` performs compatibility/auth checks in the background and updates the home/resume flow using the launch-state model. Surface only concise, actionable status on the public home. Keep raw probe detail available only through an Advanced/details entry point. Preserve the recent-connection cache behavior only where it serves release UX.
  **Must NOT do**: Do not remove compatibility checks entirely. Do not block every launch path on a giant probe result screen. Do not regress the auth-failure protections already added to `OpenCodeServerProbe`.

  **Recommended Agent Profile**:
  - Category: `unspecified-high` — Reason: UX-state and network-flow refactor touching entry behavior
  - Skills: `[]` — existing network and persistence patterns suffice
  - Omitted: `['oracle']` — architectural direction is already decided in the plan

  **Parallelization**: Can Parallel: YES | Wave 2 | Blocks: 7, 8 | Blocked By: 2, 3, 4, 5

  **References**:
  - Pattern: `lib/src/core/network/opencode_server_probe.dart` — probe logic to demote behind product-facing state
  - Pattern: `lib/src/core/persistence/stale_cache_store.dart` — cached connection/probe state behavior
  - API/Type: `lib/src/features/connection/connection_home_screen.dart` — current `_runProbe`, cached probe, and recent recording behavior
  - API/Type: `lib/src/core/network/request_headers.dart` — auth header construction that must remain compatible
  - External: `https://m2.material.io/components/banners` — guidance for actionable status communication instead of raw diagnostics

  **Acceptance Criteria** (agent-executable only):
  - [ ] `"/home/ubuntu/tools/flutter/bin/flutter" test test/features/connection/connect_continue_flow_test.dart` exits `0` and prints `All tests passed!`
  - [ ] `"/home/ubuntu/tools/flutter/bin/flutter" test test/features/home/server_status_banner_test.dart` exits `0` and prints `All tests passed!`
  - [ ] `"/home/ubuntu/tools/flutter/bin/flutter" test test/core/network/opencode_server_probe_test.dart` exits `0` and prints `All tests passed!`

  **QA Scenarios** (MANDATORY — task incomplete without these):
  ```text
  Scenario: Connect runs in background and advances user without probe-first UI
    Tool: Bash
    Steps: Run "/home/ubuntu/tools/flutter/bin/flutter" test test/features/connection/connect_continue_flow_test.dart
    Expected: Tests verify pressing "Connect" transitions through loading to success/failure states without rendering the legacy probe dashboard; suite exits 0 with "All tests passed!"
    Evidence: .sisyphus/evidence/task-6-connect.txt

  Scenario: Auth or offline failure remains actionable on home
    Tool: Bash
    Steps: Run "/home/ubuntu/tools/flutter/bin/flutter" test test/features/home/server_status_banner_test.dart
    Expected: Tests verify messages like "Sign-in required" or "Offline" with retry/edit actions and no raw endpoint list; suite exits 0 with "All tests passed!"
    Evidence: .sisyphus/evidence/task-6-status.txt
  ```

  **Commit**: YES | Message: `refactor(connection): background connect flow` | Files: `lib/src/features/connection/*`, `lib/src/features/home/*`, `lib/src/core/network/*`, `test/features/connection/*`, `test/features/home/*`

- [x] 7. Make resume-last-workspace and project fallback first-class

  **What to do**: Implement the agreed launch behavior: home always appears first, but when a valid recent workspace exists it shows a prominent `Resume last workspace` path. If the saved project or session no longer exists, fall back gracefully to the project chooser or session list with clear messaging. Use existing recent project/session metadata rather than inventing a new backend concept.
  **Must NOT do**: Do not auto-jump directly into the shell on app launch. Do not lose the ability to switch server/project from home even when resume data exists.

  **Recommended Agent Profile**:
  - Category: `unspecified-high` — Reason: state-routing logic and resilience around saved history
  - Skills: `[]` — app-local model work only
  - Omitted: `['visual-engineering']` — this is flow logic more than visual exploration

  **Parallelization**: Can Parallel: YES | Wave 2 | Blocks: 8 | Blocked By: 5, 6

  **References**:
  - Pattern: `lib/src/features/projects/project_models.dart` — recent project and last-session metadata already present
  - Pattern: `lib/src/features/projects/project_workspace_section.dart` — existing project-opening flow to adapt
  - API/Type: `lib/src/features/shell/opencode_shell_screen.dart` — selected-session and load-bundle behavior
  - API/Type: `lib/src/core/persistence/server_profile_store.dart` — recent connection/profile persistence hooks

  **Acceptance Criteria** (agent-executable only):
  - [ ] `"/home/ubuntu/tools/flutter/bin/flutter" test test/features/home/resume_workspace_panel_test.dart` exits `0` and prints `All tests passed!`
  - [ ] `"/home/ubuntu/tools/flutter/bin/flutter" test integration_test/workspace_resume_flow_test.dart` exits `0` and prints `All tests passed!`
  - [ ] `lsp_diagnostics` on the modified resume-routing files reports no errors

  **QA Scenarios** (MANDATORY — task incomplete without these):
  ```text
  Scenario: Returning user resumes a valid saved workspace from home
    Tool: Bash
    Steps: Run "/home/ubuntu/tools/flutter/bin/flutter" test integration_test/workspace_resume_flow_test.dart
    Expected: Tests simulate saved server "Local Dev", project "/repo/app", and session "Daily Standup", then verify home shows a resume CTA and opens the correct workspace flow; suite exits 0 with "All tests passed!"
    Evidence: .sisyphus/evidence/task-7-resume.txt

  Scenario: Missing project or session falls back safely
    Tool: Bash
    Steps: Run "/home/ubuntu/tools/flutter/bin/flutter" test test/features/home/resume_workspace_panel_test.dart
    Expected: Tests verify missing project falls back to project chooser and missing session falls back to session list/new-session CTA; suite exits 0 with "All tests passed!"
    Evidence: .sisyphus/evidence/task-7-fallback.txt
  ```

  **Commit**: YES | Message: `feat(home): add resume-last-workspace flow` | Files: `lib/src/features/home/*`, `lib/src/features/projects/*`, `lib/src/features/shell/*`, `test/features/home/*`, `integration_test/*`

- [x] 8. Rebuild project selection as part of the workspace-manager flow

  **What to do**: Move project discovery/selection out of the old probe-result area and into the new home/resume flow. Present projects as a normal product step after connection success, with recent projects, current availability, and graceful fallback when server capabilities are partial. Preserve the existing project service and data model where possible.
  **Must NOT do**: Do not require users to read capability readiness metrics before choosing a project. Do not keep project selection visually nested under the legacy probe card.

  **Recommended Agent Profile**:
  - Category: `visual-engineering` — Reason: product-facing flow redesign with some model reuse
  - Skills: `[]` — existing service patterns are enough
  - Omitted: `['quick']` — multi-surface flow change

  **Parallelization**: Can Parallel: YES | Wave 3 | Blocks: 9, 10 | Blocked By: 1, 4, 6, 7

  **References**:
  - Pattern: `lib/src/features/projects/project_workspace_section.dart` — current project browser and recent-project structures
  - Pattern: `lib/src/features/projects/project_catalog_service.dart` — project-fetching service contract
  - API/Type: `lib/src/features/projects/project_models.dart` — project target and recent project models
  - API/Type: `lib/src/features/connection/connection_home_screen.dart` — current place where project selection appears after probe readiness
  - External: `https://m1.material.io/growth-communications/feature-discovery.html` — progressive disclosure guidance

  **Acceptance Criteria** (agent-executable only):
  - [ ] `"/home/ubuntu/tools/flutter/bin/flutter" test test/features/projects/project_selection_flow_test.dart` exits `0` and prints `All tests passed!`
  - [ ] `"/home/ubuntu/tools/flutter/bin/flutter" test integration_test/project_open_flow_test.dart` exits `0` and prints `All tests passed!`
  - [ ] `lsp_diagnostics` on the modified project flow files reports no errors

  **QA Scenarios** (MANDATORY — task incomplete without these):
  ```text
  Scenario: Connected user picks a project from the release home flow
    Tool: Bash
    Steps: Run "/home/ubuntu/tools/flutter/bin/flutter" test integration_test/project_open_flow_test.dart
    Expected: Tests verify a connected server opens project selection from home, choosing "/repo/app" leads into the shell, and no probe dashboard appears; suite exits 0 with "All tests passed!"
    Evidence: .sisyphus/evidence/task-8-project-open.txt

  Scenario: Partial capability server still shows sane project fallback
    Tool: Bash
    Steps: Run "/home/ubuntu/tools/flutter/bin/flutter" test test/features/projects/project_selection_flow_test.dart
    Expected: Tests verify unavailable project catalog states produce actionable messaging rather than raw capability output; suite exits 0 with "All tests passed!"
    Evidence: .sisyphus/evidence/task-8-project-fallback.txt
  ```

  **Commit**: YES | Message: `feat(projects): integrate project selection into home flow` | Files: `lib/src/features/projects/*`, `lib/src/features/home/*`, `lib/src/features/connection/*`, `test/features/projects/*`, `integration_test/*`

- [x] 9. Normalize shell IA into stable primary destinations across breakpoints

  **What to do**: Restructure `OpenCodeShellScreen` so the same primary product destinations exist on compact, medium, wide, and desktop layouts: `Sessions`, `Chat`, `Context`, and `Settings`. Preserve the existing chat/files/todos/approvals backbone but remove breakpoint-specific loss of essential session navigation. Use bottom navigation or equivalent on compact layouts and rail/side navigation on wider ones.
  **Must NOT do**: Do not bury session navigation in a transient sheet/snackbar on compact layouts. Do not keep raw utilities mixed into primary navigation.

  **Recommended Agent Profile**:
  - Category: `visual-engineering` — Reason: adaptive navigation and shell layout redesign
  - Skills: `[]` — existing responsive patterns can be reused
  - Omitted: `['writing']` — copy polish happens later

  **Parallelization**: Can Parallel: YES | Wave 3 | Blocks: 10, 11, 12 | Blocked By: 1, 8

  **References**:
  - Pattern: `lib/src/features/shell/opencode_shell_screen.dart` — current breakpoint branching and shell destinations
  - Pattern: `test/features/shell/opencode_shell_screen_test.dart` — existing widget-test setup for size-based layouts
  - API/Type: `lib/src/features/chat/chat_service.dart` — chat/session data backbone to preserve
  - API/Type: `lib/src/features/tools/todo_service.dart` — context-panel data source to keep accessible
  - External: `https://docs.flutter.dev/ui/adaptive-responsive`
  - External: `https://m3.material.io/components/navigation-bar/overview`
  - External: `https://m3.material.io/components/navigation-rail/overview`

  **Acceptance Criteria** (agent-executable only):
  - [ ] `"/home/ubuntu/tools/flutter/bin/flutter" test test/features/shell/shell_navigation_adaptive_test.dart` exits `0` and prints `All tests passed!`
  - [ ] `"/home/ubuntu/tools/flutter/bin/flutter" test integration_test/shell_navigation_breakpoints_test.dart` exits `0` and prints `All tests passed!`
  - [ ] `lsp_diagnostics` on the modified shell files reports no errors

  **QA Scenarios** (MANDATORY — task incomplete without these):
  ```text
  Scenario: Compact-width shell retains core destinations
    Tool: Bash
    Steps: Run "/home/ubuntu/tools/flutter/bin/flutter" test test/features/shell/shell_navigation_adaptive_test.dart
    Expected: Tests verify widths 390, 768, 1024, and 1366 all expose Sessions, Chat, Context, and Settings through stable navigation patterns; suite exits 0 with "All tests passed!"
    Evidence: .sisyphus/evidence/task-9-shell-nav.txt

  Scenario: Compact user can still switch sessions without hidden operator UI
    Tool: Bash
    Steps: Run "/home/ubuntu/tools/flutter/bin/flutter" test integration_test/shell_navigation_breakpoints_test.dart
    Expected: Tests verify a compact layout user can open session "Daily Standup" and return to chat without entering Advanced; suite exits 0 with "All tests passed!"
    Evidence: .sisyphus/evidence/task-9-breakpoints.txt
  ```

  **Commit**: YES | Message: `refactor(shell): unify primary navigation across breakpoints` | Files: `lib/src/features/shell/*`, `test/features/shell/*`, `integration_test/*`

- [x] 10. Move internal and operator tooling into Settings/Advanced with explicit boundaries

  **What to do**: Create a dedicated `Advanced` surface under settings and move retained technical/operator tools there: probe details, raw inspector, config preview/edit, integration diagnostics, cache controls, event recovery details, and terminal-like utilities. Keep approvals/questions and essential workspace context in primary product surfaces. Add visibility rules so Advanced never appears as a launch/default destination.
  **Must NOT do**: Do not keep raw inspector, probe tables, or event diagnostics visible in the primary shell rails. Do not move approvals or essential workspace context out of the main flow.

  **Recommended Agent Profile**:
  - Category: `deep` — Reason: reclassification of many surfaces with product-boundary rules
  - Skills: `[]` — existing codebase context is enough
  - Omitted: `['artistry']` — this is IA segregation, not exploratory design

  **Parallelization**: Can Parallel: YES | Wave 3 | Blocks: 11, 12 | Blocked By: 1, 8, 9

  **References**:
  - Pattern: `lib/src/features/shell/opencode_shell_screen.dart` — current raw inspector, config, integration, event health, terminal, and request panels
  - Pattern: `lib/src/features/shell/shell_derived_data.dart` — raw inspector data builders
  - Pattern: `lib/src/features/settings/cache_settings_sheet.dart` — current settings sheet behavior to consolidate
  - Pattern: `lib/src/features/requests/request_alerts.dart` — approvals/questions that should stay primary
  - External: `https://m1.material.io/patterns/settings.html`
  - External: `https://m1.material.io/patterns/help-feedback.html`

  **Acceptance Criteria** (agent-executable only):
  - [ ] `"/home/ubuntu/tools/flutter/bin/flutter" test test/features/settings/advanced_tools_visibility_test.dart` exits `0` and prints `All tests passed!`
  - [ ] `"/home/ubuntu/tools/flutter/bin/flutter" test integration_test/advanced_tools_flow_test.dart` exits `0` and prints `All tests passed!`
  - [ ] `lsp_diagnostics` on the modified advanced/settings files reports no errors

  **QA Scenarios** (MANDATORY — task incomplete without these):
  ```text
  Scenario: Primary shell hides retained operator tooling by default
    Tool: Bash
    Steps: Run "/home/ubuntu/tools/flutter/bin/flutter" test test/features/settings/advanced_tools_visibility_test.dart
    Expected: Tests verify raw inspector, config preview, terminal, cache controls, and probe details are absent from default home/shell surfaces and only appear under Settings -> Advanced; suite exits 0 with "All tests passed!"
    Evidence: .sisyphus/evidence/task-10-advanced-visibility.txt

  Scenario: Advanced tools remain reachable deliberately
    Tool: Bash
    Steps: Run "/home/ubuntu/tools/flutter/bin/flutter" test integration_test/advanced_tools_flow_test.dart
    Expected: Tests verify a user can enter Settings, open Advanced, and reach retained technical tools without those tools leaking into primary navigation; suite exits 0 with "All tests passed!"
    Evidence: .sisyphus/evidence/task-10-advanced-flow.txt
  ```

  **Commit**: YES | Message: `refactor(settings): isolate advanced tooling` | Files: `lib/src/features/shell/*`, `lib/src/features/settings/*`, `lib/src/features/requests/*`, `test/features/settings/*`, `integration_test/*`

- [x] 11. Apply release copy, branding, and accessibility polish to home and shell

  **What to do**: Finalize user-facing naming, headings, empty states, error copy, action labels, and accessibility semantics so the product reads as a release client rather than a beta console. Add or refine branded entry treatment, remove development-facing copy/jargon, and ensure important controls have clear semantic labels and keyboard/screen-reader friendly structure.
  **Must NOT do**: Do not reintroduce internal jargon such as probe, capability registry, flavor, endpoint, or fixture into default user copy. Do not make accessibility a purely visual pass.

  **Recommended Agent Profile**:
  - Category: `writing` — Reason: copy system and product-facing text polish with UX coordination
  - Skills: `[]` — codebase copy and l10n files are sufficient context
  - Omitted: `['quick']` — this spans app-level product language and accessibility semantics

  **Parallelization**: Can Parallel: YES | Wave 4 | Blocks: 12 | Blocked By: 2, 8, 9, 10

  **References**:
  - Pattern: `lib/l10n/app_en.arb` — current product copy to revise
  - Pattern: `lib/l10n/app_ko.arb` — Korean copy parity must be preserved
  - Pattern: `lib/src/app/app.dart` — current minimal branding title
  - Pattern: `lib/src/features/connection/connection_home_screen.dart` — current diagnostic-heavy copy to replace
  - External: `https://m1.material.io/growth-communications/onboarding.html`

  **Acceptance Criteria** (agent-executable only):
  - [ ] `"/home/ubuntu/tools/flutter/bin/flutter" test test/features/home/home_copy_accessibility_test.dart` exits `0` and prints `All tests passed!`
  - [ ] `"/home/ubuntu/tools/flutter/bin/flutter" test test/features/shell/shell_copy_accessibility_test.dart` exits `0` and prints `All tests passed!`
  - [ ] `lsp_diagnostics` on modified Dart and localization files reports no errors

  **QA Scenarios** (MANDATORY — task incomplete without these):
  ```text
  Scenario: Default copy reads like a release product
    Tool: Bash
    Steps: Run "/home/ubuntu/tools/flutter/bin/flutter" test test/features/home/home_copy_accessibility_test.dart
    Expected: Tests verify home uses product-facing labels like "Add server", "Resume last workspace", and "Settings", and does not contain probe/fixture/flavor jargon; suite exits 0 with "All tests passed!"
    Evidence: .sisyphus/evidence/task-11-home-copy.txt

  Scenario: Key controls expose accessibility-friendly semantics
    Tool: Bash
    Steps: Run "/home/ubuntu/tools/flutter/bin/flutter" test test/features/shell/shell_copy_accessibility_test.dart
    Expected: Tests verify primary shell destinations and important buttons expose semantic labels and stable text across layouts; suite exits 0 with "All tests passed!"
    Evidence: .sisyphus/evidence/task-11-a11y.txt
  ```

  **Commit**: YES | Message: `feat(ui): polish release copy and accessibility` | Files: `lib/l10n/*`, `lib/src/features/home/*`, `lib/src/features/shell/*`, `test/features/home/*`, `test/features/shell/*`

- [x] 12. Build a release regression suite for launch, resume, advanced gating, and shell parity — skipped by user request on 2026-03-20

  **What to do**: Add the final regression layer that covers the release-critical flows end to end: first run, saved server home, connect/continue, resume last workspace, missing project/session fallback, advanced-tools gating, and adaptive shell destination parity. Use widget tests where sufficient and `integration_test` for user-journey verification.
  **Must NOT do**: Do not rely on ad hoc manual smoke testing as the only release signal. Do not leave breakpoint parity or migration verification implied rather than asserted.

  **Recommended Agent Profile**:
  - Category: `unspecified-high` — Reason: broad regression coverage and release hardening
  - Skills: `[]` — repo test patterns are enough
  - Omitted: `['visual-engineering']` — this is verification, not UI design

  **Parallelization**: Can Parallel: YES | Wave 4 | Blocks: Final Verification | Blocked By: 1, 2, 8, 9, 10, 11

  **References**:
  - Pattern: `test/features/shell/opencode_shell_screen_test.dart` — widget regression pattern for shell layouts
  - Pattern: `test/features/projects/project_catalog_service_test.dart` — service verification style
  - API/Type: `lib/src/app/app.dart` — final launch entry point under test
  - API/Type: `lib/src/features/connection/connection_home_screen.dart` — current launch/home implementation seam being replaced
  - External: `https://docs.flutter.dev/development/ui/navigation`

  **Acceptance Criteria** (agent-executable only):
  - [ ] `"/home/ubuntu/tools/flutter/bin/flutter" test integration_test/release_happy_path_test.dart` exits `0` and prints `All tests passed!`
  - [ ] `"/home/ubuntu/tools/flutter/bin/flutter" test integration_test/release_failure_recovery_test.dart` exits `0` and prints `All tests passed!`
  - [ ] `"/home/ubuntu/tools/flutter/bin/flutter" test integration_test` exits `0` and prints `All tests passed!`

  **QA Scenarios** (MANDATORY — task incomplete without these):
  ```text
  Scenario: Release happy path works end to end
    Tool: Bash
    Steps: Run "/home/ubuntu/tools/flutter/bin/flutter" test integration_test/release_happy_path_test.dart
    Expected: Tests simulate launch -> saved server "Local Dev" -> resume project "/repo/app" -> session "Daily Standup" -> shell navigation, and exit 0 with "All tests passed!"
    Evidence: .sisyphus/evidence/task-12-happy-path.txt

  Scenario: Release failure recovery works end to end
    Tool: Bash
    Steps: Run "/home/ubuntu/tools/flutter/bin/flutter" test integration_test/release_failure_recovery_test.dart
    Expected: Tests simulate offline server, auth failure, missing project, and advanced-tools containment, then exit 0 with "All tests passed!"
    Evidence: .sisyphus/evidence/task-12-failure-recovery.txt
  ```

  **Commit**: YES | Message: `test(release): add end-to-end regression coverage` | Files: `integration_test/*`, `test/features/*`, `test/core/persistence/*`

## Final Verification Wave (MANDATORY — after ALL implementation tasks)
> 4 review agents run in PARALLEL. ALL must APPROVE. Present consolidated results to user and get explicit "okay" before completing.
> **Do NOT auto-proceed after verification. Wait for user's explicit approval before marking work complete.**
> **Never mark F1-F4 as checked before getting user's okay.** Rejection or user feedback -> fix -> re-run -> present again -> wait for okay.
- [ ] F1. Plan Compliance Audit — oracle
- [ ] F2. Code Quality Review — unspecified-high
- [ ] F3. Real Manual QA — unspecified-high (+ playwright if UI)
- [ ] F4. Scope Fidelity Check — deep

## Commit Strategy
- Commit 1: characterization coverage for launch, connection, and current shell breakpoint behavior
- Commit 2: secure credential store, migration path, and persistence tests
- Commit 3: workspace home scaffold, launch routing, and home widget tests
- Commit 4: connection/resume behavior and integration coverage
- Commit 5: adaptive shell navigation restructuring and breakpoint tests
- Commit 6: move advanced tools/settings surfaces and visibility tests
- Commit 7: branding/copy/accessibility polish and full regression run

## Success Criteria
- New users understand the app as a workspace manager within the first screen, without seeing probe jargon
- Returning users can resume recent work from home without losing the ability to switch server/project/session deliberately
- Internal/operator tooling is no longer part of the default task flow
- Compact layouts retain access to the same core product destinations as wide layouts
- Stored credentials are migrated safely and no longer persisted in plaintext preferences
- Release-critical widget and integration tests protect launch, resume, error recovery, and navigation behavior
