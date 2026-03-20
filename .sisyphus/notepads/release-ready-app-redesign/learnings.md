- 2026-03-19: `OpenCodeRemoteApp` still launches directly into `ConnectionHomeScreen`, showing the legacy connection-first copy (`Connect a real OpenCode server`, `Probe server`, `Live capability probe`) instead of a workspace home.
- 2026-03-19: `OpenCodeShellScreen` currently branches at width thresholds `<700`, `700-959`, `960-1319`, and `>=1320`; compact and portrait keep the utility sheet hinted via `Utilities drawer`, landscape adds rails, and desktop exposes the full terminal-capable utility rail.
- 2026-03-19: `ServerProfileStore` persists both draft and saved profile credentials as plaintext JSON in `SharedPreferences`, with draft data under `draft_server_profile` and saved profiles in the `server_profiles` string list.
- 2026-03-19: Task 2 migrated saved and draft `ServerProfile` credentials to `flutter_secure_storage`; `SharedPreferences` now keeps only scrubbed profile metadata (`id`, `label`, normalized `baseUrl`) while hydration restores username/password before the existing Basic-auth flow uses them.
- 2026-03-19: Task 3 has a clean seam between low-level probe outputs in `opencode_server_probe.dart`/`ConnectionProbeClassification` and a new product-facing home model in a new `features/launch` layer; `ConnectionHomeScreen` currently mixes both concerns directly.
- 2026-03-19: Task 3 now codifies that seam in `lib/src/features/launch/launch_state_model.dart` and `lib/src/features/connection/connection_status_mapper.dart`; saved-server inventory, product-facing connection status, and project/session routing are modeled as separate concerns.
- 2026-03-19: Task 4 now routes `OpenCodeRemoteApp` into `WorkspaceHomeScreen`, which loads saved servers plus recent connections from persistence and derives home status only from cached probe reports through `mapLaunchConnectionStatus()` instead of surfacing probe detail on first launch.
- 2026-03-19: Task 5 replaces the temporary `_ServerTile` list in `WorkspaceHomeScreen` with richer server cards that keep home copy product-facing: identity, launch-status summary, last-used context, and credential state stay visible while capability counts, endpoint rows, experimental paths, and raw probe summaries stay hidden.
- 2026-03-19: `ConnectionHomeScreen` now accepts explicit home-entry intents (`initialProfile` and `startInAddMode`), letting home open a true add flow (blank editor unless a draft exists) or a prefilled edit flow without changing `ServerProfileStore` draft/save semantics.
- 2026-03-19: Task 5 regression fix: `WorkspaceHomeScreen` copy must guard against legacy launch jargon on the primary home surface; widget coverage now explicitly rejects strings like `Start with a server, not a probe` and `Leave endpoint diagnostics tucked inside server details.`.
- 2026-03-19: Task 6 moved probe execution onto `WorkspaceHomeScreen` itself: home now calls `OpenCodeServerProbe`, writes `probe::${profile.storageKey}` back through `StaleCacheStore`, and records recents through `ServerProfileStore.recordRecentConnection` so cached status and recent activity stay in sync without routing users through `ConnectionHomeScreen`.
- 2026-03-19: The new home-owned status banner only exposes product-facing outcomes (`Sign-in required`, `Offline`, `Update required`) plus `Retry`/`Edit server`; raw probe summaries, endpoint paths, and capability details stay hidden even when the cached `ServerProbeReport` contains them.
- 2026-03-19: Task 8 keeps `ProjectWorkspaceSection` mounted only from `WorkspaceHomeScreen`'s ready-state path, while `ConnectionHomeScreen` now stays a server-details seam and no longer renders a second project-launch surface after a successful check.
- 2026-03-19: `ProjectWorkspaceSection` now stays usable when project catalog fetches fail or return sparse data: cached catalog data still renders when present, and the fallback state keeps recent projects plus manual path entry visible behind a product-facing notice instead of exposing raw errors.
- 2026-03-19: Task 9 lands cleanly when the shell keeps the same four primary destinations (`Sessions`, `Chat`, `Context`, `Settings`) across breakpoints but only compact/portrait switch the whole body; wide and desktop can keep the existing sessions/chat backbone while the right rail swaps between context and a narrow settings surface.
- 2026-03-19: Shell widget tests need `SharedPreferences.setMockInitialValues({})` and a fixed multi-frame pump helper instead of `pumpAndSettle()`; otherwise shell persistence startup and animated shell chrome make session-switch tests flaky or time out.
- 2026-03-19: Task 10 correction: Advanced config assertions are more reliable against a stable panel seam (`ValueKey('advanced-config-panel')`) than against one specific empty-state sentence, because integration runs can render different config content timing.
- 2026-03-20: Task 12 release regressions can keep the home-to-shell path network-safe by seeding `StaleCacheStore` with `shell.bundle::*` and `shell.messages::*` entries, then letting `WorkspaceHomeScreen` drive real resume/open navigation while `OpenCodeShellScreen` reads fresh cached chat state instead of hitting live backends.
- 2026-03-20: The Linux multi-file `flutter test integration_test` restart failure was not actually caused by the app runner after all; the decisive fix on this machine was rebuilding `flutter_tools` with a patched `DesktopLogReader` that recreates its stream controller for each desktop process instead of closing one shared controller after the first file, which finally let later Linux integration launches expose their VM-service line.

- 2026-03-20: `WorkspaceHomeScreen._loadHomeData()` must re-check `mounted` after awaiting `ProjectStore.loadLastWorkspace()`; otherwise fast navigation away during home startup can hit `setState()` after dispose.

- 2026-03-20: Shell session switching must treat a missing todo cache as stale (not fresh) and must not reuse the previous session's in-memory todos when message cache exists; otherwise stale todos can flash and todo fetch can be skipped.

- 2026-03-20: Linux runner: treat `/tmp/.X11-unix/X99` as a hint only; probe `:99` with `XOpenDisplay()` before reusing it so we do not bind to stale/foreign X servers.
- Unified resumable-session detection: `ProjectSessionHint` only counts as resumable when `title` is non-empty (status-only hints no longer drive resume).

- 2026-03-20: EventStreamService SSE transport guard: `connect()` now rejects non-2xx or non-`text/event-stream` responses early (eg 401 JSON / 500 HTML) so they don't enter the SSE parser.
- 2026-03-20: Linux runner: Xvfb readiness probe window widened (more retries at the same interval) to reduce slow-boot CI/VM flakes.
 
- 2026-03-20: Ownership fix: `OpenCodeShellScreen` now disposes `ChatService`/`TodoService` only when it created them internally, and updates its references in `didUpdateWidget` when injected instances are swapped.

- 2026-03-20: Home profile switching now clears the in-memory remembered workspace immediately so the resume panel never briefly shows/acts on the previous server while `loadLastWorkspace()` reloads.

- 2026-03-20: Shell cached-bundle resume path must reset the same per-project/session UI state as the fresh-fetch path (todos/files/requests/config/integration/event snapshots), otherwise stale cached state can leak across project/profile switches.

- 2026-03-20: `OpenCodeShellScreen` async reuse-path fixes need both a scope/request token for `_loadBundle()` and current-session guards for `_selectSession()`/`_loadTodos()`; rebuilding tests with a new key hides the real `didUpdateWidget()` race.

- 2026-03-20: `OpenCodeShellScreen` scope swaps must clear uncached visible shell state immediately, and each optional loader (`_loadFiles`, pending requests, config, integrations) needs its own scope/request guard so late responses from the previous project cannot repaint a reused shell.

- 2026-03-20: `OpenCodeShellScreen` also needs a current event-stream scope lease plus exact session-scoped guards for `_runShellCommand()` and `_submitPrompt()`; `mounted` alone still lets stale SSE frames or late shell/prompt completions repopulate reused state after project/profile/session swaps.

- 2026-03-20: Shell guard follow-up: `_applyConfigRaw()`, integration auth starts, and `_runGuardedAction()` now use per-scope request tokens so late completions from a previous project/profile cannot overwrite `_configSnapshot`, `_lastIntegrationAuthUrl`, or surface `_error` on a reused shell.

- 2026-03-20: `WorkspaceHomeScreen._resumeWorkspaceFromHome()` needs the same profile/request-token lease as other guarded home loads; otherwise a delayed resume can reopen or clear remembered workspace state after the user switches to a different server.

- 2026-03-20: `OpenCodeShellScreen` event-stream reuse needs two separate guards: same-scope injected service swaps must reconnect immediately, and `_recoverEventStream()` must carry both the original scope and service lease so stale recovery cannot disconnect the current stream, reload the new scope, or append a late `Reconnect completed` log.
