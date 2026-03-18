# Mission 5 App-Only Feature Plan

Mission 5 required planning 5 features that are useful in the mobile app but not part of the OpenCode Web surface, then selecting 3 to implement.

## Candidate Features

1. Local connection draft restore
   - Restore unfinished server form input across app restarts.
2. Pinned server profiles
   - Keep favorite server profiles at the top for repeat mobile use.
3. Pinned projects
   - Keep favorite project targets at the top for quick re-entry.
4. Last-project quick resume
   - Re-open the last selected project context with one tap.
5. Mobile share/copy shortcuts
   - Add mobile-native copy/share affordances around connection and project metadata.

## Selected for Implementation

The three highest-value, lowest-risk features were:

1. Local connection draft restore
2. Pinned server profiles
3. Pinned projects

These were selected because they fit the existing `shared_preferences` persistence pattern, are clearly mobile-native convenience wins, and avoid overlapping with documented OpenCode Web capabilities.

## Implementation Record

- `775dd90 feat: add local mobile connection shortcuts`
- Added local draft persistence in `lib/src/core/persistence/server_profile_store.dart`.
- Surfaced draft restoration and server-profile pinning in `lib/src/features/connection/connection_home_screen.dart`.
- Added project pinning support in `lib/src/features/projects/project_store.dart` and `lib/src/features/projects/project_workspace_section.dart`.
- Added focused Flutter tests for the new persistence behavior.

## Verification

- `dart analyze` -> passed
- `flutter test test/core/persistence/server_profile_store_test.dart test/features/projects/project_store_test.dart` -> passed
