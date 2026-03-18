# Mission 6 Scenario Review

Mission 6 required defining at least 10 failure/edge scenarios, reviewing the relevant code path for each, and fixing gaps where needed.

## Scenario Checklist

1. Connection timeout during probe
   - Code: `lib/src/core/network/opencode_server_probe.dart`
   - Status: handled

2. Invalid or empty server URL
   - Code: `lib/src/features/connection/connection_home_screen.dart`, `lib/src/core/network/opencode_server_probe.dart`
   - Status: handled

3. Login/auth failure on protected endpoints
   - Code: `lib/src/core/network/opencode_server_probe.dart`, `lib/src/core/network/request_headers.dart`
   - Status: handled

4. Connecting to an OpenCode server that does not require login
   - Code: `lib/src/core/network/request_headers.dart`
   - Status: handled

5. Unsupported or missing capabilities in the probed server
   - Code: `lib/src/core/spec/capability_registry.dart`, `lib/src/core/network/opencode_server_probe.dart`
   - Status: handled

6. Unexpected `/doc` or probe response shape
   - Code: `lib/src/core/network/opencode_server_probe.dart`
   - Status: handled

7. SSE stream drop or stale heartbeat
   - Code: `lib/src/features/shell/opencode_shell_screen.dart`, `lib/src/core/network/sse_connection_monitor.dart`
   - Status: handled

8. `stream.resync_required` event from live stream
   - Code: `lib/src/core/network/live_event_reducer.dart`, shell event handling
   - Status: reviewed, no fix in this slice

9. Todo capability absent on the target server
   - Code: `lib/src/features/shell/opencode_shell_screen.dart`
   - Status: handled

10. Question/permission capability absent on one or both endpoints
    - Code: `lib/src/features/requests/request_service.dart`, `lib/src/features/shell/opencode_shell_screen.dart`
    - Status: fixed

11. Empty or malformed session/message payloads
    - Code: `lib/src/features/chat/chat_service.dart`
    - Status: reviewed

12. File preview/search failure
    - Code: `lib/src/features/files/file_browser_service.dart`, `lib/src/features/shell/opencode_shell_screen.dart`
    - Status: fixed for file-select action error propagation

13. Invalid config JSON during apply
    - Code: `lib/src/features/settings/config_edit_preview.dart`, `lib/src/features/shell/opencode_shell_screen.dart`
    - Status: reviewed

14. Shell command execution failure
    - Code: `lib/src/features/terminal/terminal_service.dart`, `lib/src/features/shell/opencode_shell_screen.dart`
    - Status: handled

## Fixes Applied

- `32627e0 fix: harden shell request failure handling`
- Added capability-aware request loading so unsupported `/question` or `/permission` endpoints no longer poison the whole pending-request refresh.
- Wrapped file selection, auth launch actions, request replies, and session actions in guarded shell error handling so uncaught exceptions surface through `_error` instead of bubbling through the UI.
- Added a regression test for mixed capability pending-request loading in `test/features/requests/request_service_test.dart`.

## Verification

- `dart analyze` -> passed
- `flutter test test/features/requests/request_service_test.dart` -> passed
