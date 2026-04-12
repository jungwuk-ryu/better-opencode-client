# UI Performance War Room - 2026-04-10

## Objective

Optimize Flutter UI performance for:

- very large message histories
- many concurrent sessions
- many watched/child sessions
- high-frequency live event streams

Constraints:

- no user-visible behavior change
- no commit unless explicitly requested
- every implementation task must receive critical review from at least 2 sub-agents
- testing must be thorough before a task is considered done
- use live macOS app profiling when possible
- use the real server at `http://134.185.112.3:3002` when it is safe and useful

## Current Status

- State: In progress
- Branch state: dirty worktree detected before this task; do not overwrite unrelated changes
- Commit status: no commits made for this task; all changes remain local and uncommitted
- App runtime path: `flutter run -d macos`
- Tooling confirmed: Flutter 3.41.6, Dart 3.11.4, DevTools 2.54.2

## Final Phased Plan

### Phase 0 - Measurement Baseline and Parity Lock

- Freeze user-visible behavior: no changes to UX flow, copy, ordering semantics, or session meaning.
- Use a repeatable stress matrix:
  - 4-pane desktop workload on the real Siftly workspace
  - large streamed responses on multiple concurrent sessions
  - long timeline/history sessions
  - side-surface open/rebuild scenarios for Context, Git, and Inbox
- Collect proof from:
  - targeted Flutter/widget regressions
  - `flutter run -d macos --profile`
  - DevTools / VM service timeline where usable
  - `xctrace` Animation Hitches and Time Profiler

### Phase 1 - Event and Rebuild Fan-out

- Reduce unrelated-session work in `WorkspaceController`.
- Split inactive-pane rebuild fan-out in `workspace_screen.dart`.
- Acceptance criteria:
  - selected-session message list remains unchanged for foreign-session live events
  - watched timelines and child previews still update correctly
  - split-pane correctness and request notifications remain intact

### Phase 2 - Derived State and Recovery Stability

- Remove cache-signature blind spots and stale preview regressions introduced by partial event updates.
- Harden regression helpers so asynchronous expectations fail loudly instead of timing out silently.
- Acceptance criteria:
  - cache persistence updates when tool-state titles change
  - active child previews do not regress on older watched-message updates/removals
  - reconnect/recovery paths keep parity with existing behavior

### Phase 3 - Heavy Surface Lazyization

- Convert the heaviest eager surfaces to builder-backed or expansion-gated rendering:
  - Context raw messages
  - Git changed files and branch picker
  - Inbox lists and per-row lookup work
- Acceptance criteria:
  - opening or refreshing these sheets scales with visible rows, not total rows
  - no missing controls, badges, labels, or row actions

### Phase 4 - Runtime Sign-off

- Re-run the stress matrix after each material change set.
- Compare:
  - hitch counts and durations
  - qualitative pane responsiveness during bursty streaming
  - regression suite status
- Exit condition:
  - no blocker correctness regressions remain
  - critical reviewers have signed off on each active change set
  - target stress scenarios no longer show obvious interaction hitches and no longer produce multi-hundred-millisecond main-thread stalls during the verified workload

## Verified Priority Order

1. Reduce workspace-wide rebuild fan-out from monolithic controller listening.
2. Reduce per-event CPU cost, especially `message.part.delta` and unrelated-session event overhead.
3. Reduce repeated session-tree, watched-session, hover-preview, and active-child recomputation.
4. Make heavy side surfaces lazy and memoized: Context, Git sheet, Inbox, Review.
5. Reduce spill/cache/recovery/network amplification and prove parity with tests and profiling.

## Non-Goals For First Pass

- broad visual redesign
- behavior changes to session semantics
- rewriting the entire message list virtualization path before fixing higher-value fan-out problems
- committing or pushing changes

## Execution Rules

For each concrete change set:

1. Implement the smallest safe performance improvement.
2. Request at least 2 critical sub-agent reviews.
3. Address or explicitly reject review concerns with evidence.
4. Run relevant tests plus broader regression coverage.
5. Re-profile the affected scenario in the macOS app when possible.
6. Update this file before moving on.

## Review Ledger

### Change Set 1 - Foreign Session Event Waste Cut

- Scope:
  - `workspace_controller.dart` foreign-session guards for `message.updated`, `message.part.updated`, and `message.part.delta`
  - cache-signature coverage for nested tool-state updates
  - watched child preview/timeline recomputation correctness
- Critical reviewers:
  - `Lorentz`: no blocker in the guard logic; originally flagged weak regression coverage, which was addressed
  - `Ramanujan`: no blocker in the guard logic; originally flagged watched-timeline coverage gap, which was addressed
  - `Chandrasekhar`: flagged nested tool-state cache signature blind spot; fixed
  - `Meitner`: flagged watched child preview regressions on older update/remove shapes; watched-session fixes landed, non-watched semantics still under cross-review
- Status:
  - implemented
  - broader regressions passing
  - cache-signature blind spots identified during follow-up review were expanded beyond nested title-only updates and are now covered by regression tests
  - one non-watched active-child preview semantics question still remains as a documented residual issue:
    - `message.removed` for a non-watched active child still clears the preview eagerly because preview provenance is not tracked
    - `Ramanujan` argued this is semantically lossy for older-message removals
    - `Lorentz` agreed it is real but not blocker-severity for the current guard optimization because exact recomputation is unavailable without additional provenance tracking

### Change Set 2 - Inactive Pane Fan-out Reduction

- Scope:
  - pane-local `AnimatedBuilder`
  - shell-signature-gated parent rebuilds
  - live pane project re-resolution
- Critical reviewers:
  - `Nietzsche`: initial blocker on stale-pane cleanup; fixed, then re-reviewed with no blocker
  - `Euler`: no blocker; noted stale layout persistence as a follow-up, not a blocker
  - `McClintock`: no blocker
  - `Sartre`: no blocker
- Status:
  - implemented
  - critical review requirement satisfied
  - targeted and broader regressions passing

### Change Set 3 - Heavy Surface Lazyization

- Scope:
  - Context raw messages
  - Git sheet changed-file list and branch picker
  - Inbox list building and per-row lookup work
- Critical reviewers:
  - `Tesla`: identified concrete P1/P2 hotspots and exact files/lines
  - `Meitner`: found raw-message widget identity and retained-payload issues; fixed and re-reviewed with no blocker
  - `Lorentz`: found test coverage gaps around lazyization semantics; addressed and re-reviewed with no blocker
  - `Nietzsche`: no blocker on final pass
- Status:
  - implemented
  - critical review requirement satisfied
  - implemented changes:
    - raw message payload formatting now happens on expansion instead of every context-panel rebuild
    - raw message tiles now have stable parent/widget identity and clear cached formatted payloads on collapse
    - Git changed files now render through a sliver builder
    - Git branch picker now renders branch rows through a builder
    - Inbox sections now use sliver builders and pre-index session labels instead of repeated scans
  - residual non-blocking note:
    - inbox test coverage could still be hardened further by explicitly proving a late approval row becomes visible after scrolling; current coverage already proves late approvals are absent before scroll and that the section remains reachable

## Runtime Validation Matrix

- Scenario: 4-pane real Siftly workspace, real server, concurrent async prompt burst across four active sessions.
  - Result: reproduced real streaming pressure on the live macOS profile build.
  - Evidence:
    - `prompt_async` returned `204` for all four sessions repeatedly
    - Skia screenshots captured before and after burst:
      - `/tmp/opencode-skia-before-burst.png`
      - `/tmp/opencode-skia-after-burst.png`
- Scenario: `xctrace` Animation Hitches during an 8-second 4-session burst.
  - Result: not yet at sign-off quality.
  - Evidence:
    - main-thread `Potential Interaction Delay` events at about `86.81 ms` and `41.58 ms`
    - one `Microhang` at about `484.68 ms`
    - trace artifact: `/tmp/opencode-animation-hitches-burst.trace`
  - Interpretation:
    - the war room remains open
    - current changes improved correctness boundaries and fan-out, but did not yet eliminate user-perceptible jank under the validated burst workload
- Scenario: `xctrace` Time Profiler during the same burst.
  - Result: captured, but first pass was distorted by Flutter widget-build profiling overhead; second pass was re-run with profiling extensions disabled.
  - Evidence:
    - traces:
      - `/tmp/opencode-time-profiler-burst.trace`
      - `/tmp/opencode-time-profiler-burst-unprofiled.trace`
    - first profiled pass showed instrumentation overhead in `SchedulerBinding._profileFramePostEvent`
    - second pass removes that distortion and is the basis for subsequent hotspot narrowing
- Scenario: post-change-set-3 Animation Hitches during the same 4-session burst.
  - Result: materially better than the earlier baseline under the validated replay.
  - Evidence:
    - trace artifact: `/tmp/opencode-animation-hitches-side-surfaces-rerun.trace`
    - exported `potential-hangs` table returned schema only and no hang rows
    - compared with the earlier burst trace, the previously observed `~86.81 ms`, `~41.58 ms`, and `~484.68 ms` entries did not reproduce in this rerun
  - Caveat:
    - one follow-up foreground rerun produced an `xctrace export` document error, so the clean rerun trace is the best usable artifact from this batch

## Work Log

### 2026-04-10 Initial Capture

- Created this file as the single source of truth for plan and live status.
- Confirmed runnable local Flutter/macOS toolchain.
- Confirmed current repo is already dirty before this task.
- Completed multi-agent static code audit and cross-check.
- Static audit consensus:
  - root workspace rebuild fan-out is the top issue
  - per-event state work remains too expensive even with end-of-frame notify coalescing
  - `message.part.delta` path is a likely dominant hot path under large streaming loads
  - watched timelines, child previews, hover previews, Context raw messages, Git sheet, and Inbox sheet are significant secondary amplifiers

### 2026-04-10 Next Immediate Actions

- Run dependency/bootstrap checks needed for local macOS execution.
- Launch the macOS app and connect profiling tooling.
- Exercise realistic scenarios, including the real server if reachable and safe.
- Convert static findings into measured hotspots.
- Start the first low-risk optimization batch after measurement.

### 2026-04-10 Runtime Prep Update

- `flutter pub get` completed successfully.
- Confirmed runnable local devices include `macOS (desktop)`.
- Real server reachability verified:
  - `http://134.185.112.3:3002` responds
  - `/project/current` returns the global `/` workspace
  - manual catalog probe succeeded with `projects=11`
- Next step is automatic profile injection or equivalent startup automation so the macOS app can be launched directly into a real profiling path.

### 2026-04-10 Runtime State Discovery

- Confirmed the macOS app preference domain can be read through `defaults export com.jungwuk.boc -`.
- Verified persisted app keys relevant to launch automation:
  - `flutter.server_profiles`
  - `flutter.web_parity.selected_profile`
  - `flutter.last_workspace::<serverStorageKey>`
  - `flutter.recent_projects`
  - `flutter.hidden_projects`
- Verified the app startup path can be steered by persisted profile selection plus `last_workspace`, which is lower risk than trying to click through setup manually before profiling.
- Next step is to inject a dedicated real-server profile for `http://134.185.112.3:3002`, persist a target workspace, and launch `flutter run -d macos --profile` into a reproducible scenario.

### 2026-04-10 Live Runtime Hookup

- Backed up the current macOS preference domain export to `/tmp/com.jungwuk.boc.backup.20260410.plist`.
- Injected a dedicated profile for `http://134.185.112.3:3002` with `flutter.web_parity.selected_profile` pointing to it.
- Seeded `flutter.last_workspace::http://134.185.112.3:3002|` for `/home/ubuntu/works/Siftly`.
- Seeded `flutter.workspace.desktopSessionPanes::http://134.185.112.3:3002|` with a 4-pane Siftly scenario so the first profile run opens directly into a multi-session workload.
- Launched the real macOS app in profile mode with route:
  - `/L2hvbWUvdWJ1bnR1L3dvcmtzL1NpZnRseQ/session/ses_2f99cb35fffevUKZppKTEX3wIC`
- Captured live runtime endpoints from `flutter run`:
  - VM service: `http://127.0.0.1:49313/iErVfyg2p_0=/`
  - DevTools: `http://127.0.0.1:49313/iErVfyg2p_0=/devtools/?uri=ws://127.0.0.1:49313/iErVfyg2p_0=/ws`
- DevTools browser session was opened successfully against the running app.

### 2026-04-10 Change Set 1 - Foreign Delta Waste Cut

- Implemented the first narrow controller optimization:
  - file: `lib/src/features/web_parity/workspace_controller.dart`
  - change: foreign-session `message.updated`, `message.part.updated`, and `message.part.delta` now skip selected-session `_messages` recompute work when they do not target the selected session
  - preserved behavior: watched-session timeline updates and active child preview refresh still run before the guard
- Added a regression test in `test/features/web_parity/workspace_controller_live_sync_test.dart` to lock the intended boundary:
  - selected session remains stable
  - background child delta still updates active child preview
- Expanded the controller follow-up fix set after critical review:
  - selected-session cache persistence now notices nested tool-state title changes
  - watched child previews are re-derived after watched `message.updated`, `message.part.updated`, and `message.removed` events
  - async `_waitFor` test helper now fails loudly instead of silently timing out
  - hidden false-positive queue-flush test was corrected to assert the actual flush behavior
- Critical review summary:
  - two independent pre-implementation reviews completed
  - two independent post-implementation reviews completed for the original guard change
  - follow-up critical reviews identified cache-signature and watched-preview issues, which were fixed
  - one non-watched active-child preview semantics question remains under active cross-review before this change set is fully closed
- Validation completed so far:
  - `flutter analyze lib/src/features/web_parity/workspace_controller.dart test/features/web_parity/workspace_controller_live_sync_test.dart`
  - `flutter test test/core/network/live_event_applier_test.dart`
  - `flutter test test/core/network/live_event_reducer_test.dart`
  - `flutter test test/features/web_parity/workspace_controller_live_sync_test.dart`
  - broader regression bundle covering active child sessions, timeline activity, session switching, and sidebar roots

### 2026-04-10 Change Set 3 - Active Work Start

- Began the heavy-surface optimization batch because runtime traces still show a `~484.68 ms` microhang under a four-session real-server burst.
- Narrowed the next implementation targets to:
  - `lib/src/features/web_parity/workspace_screen_side_panel.dart`
  - `lib/src/features/web_parity/workspace_git_sheet.dart`
  - `lib/src/features/web_parity/workspace_inbox_sheet.dart`
- Current working hypothesis:
  - raw-message pretty formatting and zero-width-break insertion are still paid too eagerly
  - Git changed files and branch lists still scale with total rows instead of visible rows
  - Inbox still eagerly allocates all section tiles and performs repeated session-title lookup scans
- Cross-review for this batch is being collected in parallel before closure; no commit has been made.

### 2026-04-10 Change Set 3 - Implementation and Closure

- Implemented side-surface lazyization in:
  - `lib/src/features/web_parity/workspace_screen_side_panel.dart`
  - `lib/src/features/web_parity/workspace_git_sheet.dart`
  - `lib/src/features/web_parity/workspace_inbox_sheet.dart`
- Added/updated regression coverage in:
  - `test/features/web_parity/workspace_context_panel_test.dart`
  - `test/features/web_parity/workspace_side_sheets_test.dart`
- Critical-review outcomes:
  - `Meitner` initially found a real raw-message state bug:
    - expanded rows could lose stable identity when messages were inserted ahead of them
    - collapsed rows kept large formatted payloads resident
    - both were fixed, then re-reviewed with no blocker
  - `Lorentz` initially found that the new tests did not actually prove lazyization semantics
    - tests were expanded to prove late rows are absent before scroll
    - raw-message coverage now proves prepend + same-message payload refresh
    - re-review reported no blocker
  - `Nietzsche` reported no blocker on the final pass
- Validation completed:
  - `dart format` on all touched side-surface/test files
  - targeted widget regressions for context, Git sheet, and Inbox sheet
  - broad regression bundle covering live event applier/reducer, controller live sync, active child sessions, timeline activity, session switching, sidebar roots, context panel, and side sheets
  - targeted `flutter analyze` for touched files with only one pre-existing informational lint remaining in `workspace_screen_side_panel.dart`
- Runtime outcome:
  - relaunched the macOS profile app against the real Siftly workspace
  - replayed the same four-session async burst using the real server at `http://134.185.112.3:3002`
  - the best usable post-change trace did not reproduce the earlier potential hangs
  - `flutter test test/features/web_parity/workspace_controller_live_sync_test.dart`
  - `flutter test test/features/web_parity/workspace_active_child_sessions_panel_test.dart`
  - `flutter test test/features/web_parity/workspace_timeline_activity_test.dart`
- Note: full-repo `flutter analyze` still reports pre-existing unrelated warnings/info outside this change set; the targeted files are clean.

### 2026-04-10 Change Set 2 - Inactive Pane Fan-out Reduction

- Implemented a screen-side optimization in `lib/src/features/web_parity/workspace_screen.dart`:
  - inactive/observed pane cards now rebuild through pane-local `AnimatedBuilder`
  - pane project labels are re-resolved from current controller state inside the pane card
  - the unconditional observed-pane `setState()` was replaced with shell-signature gating so parent rebuilds only happen when pane shell state actually changes
- Important follow-up from critical review:
  - initial version removed too much parent invalidation and risked leaving stale inactive panes mounted
  - fixed by reintroducing a parent rebuild only when observed pane shell signature changes (`loading`, `selectedSessionId`, `error`, session-id membership)
- Critical review status:
  - two independent pre-implementation reviews completed
  - four post-fix reviews completed with no blocker-level regressions
- Validation completed so far:
  - `flutter test test/features/web_parity/workspace_screen_session_switch_test.dart --plain-name 'workspace sends an OS notification when a permission arrives'`
  - `flutter test test/features/web_parity/workspace_screen_session_switch_test.dart --plain-name 'split panes keep each session question panel visible without focus'`
  - `flutter test test/features/web_parity/workspace_screen_session_switch_test.dart --plain-name 'split panes keep each session permission panel visible without focus'`
  - `flutter test test/features/web_parity/workspace_screen_session_switch_test.dart --plain-name 'desktop layout lets users collapse and reopen both side panels'`
  - `flutter test test/features/web_parity/workspace_sidebar_root_sessions_test.dart --plain-name 'sidebar shows a hover preview for recent session prompts'`
  - `flutter test test/features/web_parity/workspace_sidebar_root_sessions_test.dart --plain-name 'sidebar shows project and session notification badges'`
- Analysis status:
  - `flutter analyze lib/src/features/web_parity/workspace_screen.dart` shows only pre-existing warnings/info in that file; no new compile errors from this change set

### 2026-04-10 Live Load Exercise

- Confirmed `prompt_async` accepts requests on the real server for all four seeded Siftly pane sessions.
- Fired concurrent async prompts across the four open pane sessions twice.
- Enabled the Flutter performance overlay via `flutter run` interactive command.
- Practical limitation:
  - local screenshot capture of the native macOS window is blocked in the current environment
  - DevTools opened successfully, but this environment is better suited for connection/protocol validation than rich visual inspection of the native Flutter window
- Coarse runtime observation only:
  - process-level CPU sampling during the concurrent async prompt burst did not show an obvious sustained spike for the macOS app process
  - this is only a rough signal, not a substitute for frame-timing proof
- Next step is to improve measurement fidelity for live frame timing while continuing to reduce the active selected-session hot path.

### 2026-04-10 Test Hardening Update

- Tightened `_waitFor(...)` in `workspace_controller_live_sync_test.dart` so timeout cases now fail the test instead of silently succeeding.
- This exposed a false-positive in the queued follow-up flush test; the test was corrected to assert actual queue flush completion instead of an impossible `ses_other` state.
- Result:
  - controller-specific analyze and live-sync regressions are green again
  - the broader regression bundle across controller, timeline, pane, sidebar, and network reducer tests is green again

### 2026-04-10 Runtime Trace Update

- Captured real-server burst artifacts against the live macOS profile build:
  - `/tmp/opencode-animation-hitches-burst.trace`
  - `/tmp/opencode-time-profiler-burst.trace`
  - `/tmp/opencode-time-profiler-burst-unprofiled.trace`
- Captured supporting Skia screenshots:
  - `/tmp/opencode-skia-before-burst.png`
  - `/tmp/opencode-skia-after-burst.png`
- Current runtime conclusion:
  - the app is improved but not yet at the “jank effectively gone” bar
  - `Animation Hitches` still reports at least one `Microhang` around `484.68 ms` during the 4-session burst
  - this keeps the war room open; more optimization work is still required

## Open Risks

- Real server schema/runtime behavior may differ from fixture assumptions.
- Existing dirty files may constrain how aggressively some changes can be made in overlapping areas.
- Some improvements may move cost rather than remove it; runtime tracing is mandatory.
