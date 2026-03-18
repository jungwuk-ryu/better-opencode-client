# Mission 4 Performance Notes

This note records the performance scan and the optimizations that were applied without changing the design language.

## Hotspots Found

1. `lib/src/features/shell/opencode_shell_screen.dart`
   - SSE frames and health updates triggered multiple `setState` calls per event.
   - Chat parts were flattened repeatedly in build-heavy paths.
   - Todo rows were sorted during widget build.
   - File status lookup scanned the full status list for each visible row.
   - Inspector JSON strings were regenerated during rebuilds.
   - Text controllers were created inside build for file search and terminal inputs.

2. `lib/src/features/connection/connection_home_screen.dart`
   - Large column-based sections already existed, but the highest-value low-risk wins were still concentrated in the shell path.

## Changes Applied

- `c7477d0 perf: reduce shell rebuild overhead`
- Coalesced live-event state application so one event updates shell state in a single `setState` path.
- Cached flattened chat parts in `_ChatCanvas` instead of recomputing on unrelated rebuilds.
- Cached sorted todos in `_TodoTileList` instead of sorting in `build`.
- Indexed file statuses once per build instead of scanning linearly per row.
- Replaced build-time text controller creation with synced stateful fields.
- Moved inspector JSON derivation into cached helper paths in `lib/src/features/shell/shell_derived_data.dart`.

## Verification

- `dart analyze` -> passed
- `tool/manual/run_shell_derived_data.dart` -> verified todo ordering, file status indexing, and inspector JSON helper output during implementation
