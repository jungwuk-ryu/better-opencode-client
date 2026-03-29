# Issues

- 2026-03-29: Extra build verification found two unrelated blockers outside the package-identity rename scope: `flutter build web` fails because `lib/src/core/persistence/stale_cache_store.dart` uses large integer literals that `dart2js` cannot represent exactly in JavaScript, and `flutter build bundle` fails in this environment because the Android SDK is unavailable.
- 2026-03-29: Task 4 (remote session deletion fallback parity) introduced no new blockers; scoped diagnostics and `workspace_controller_live_sync_test.dart` pass.
- 2026-03-29: Repo-facing docs follow-up: `docs/testing-rules.md` had a stale machine-specific absolute path pointing at an old repo checkout; updated to use the repo-relative helper path.
