# Learnings

- 2026-03-29: Aligned the Dart package identity by changing `pubspec.yaml` `name:` to `better_opencode_client` and updating all `package:opencode_mobile_remote/...` imports in the allowed Dart groups: `lib/`, `test/`, `tool/`, and `integration_test/`.
- 2026-03-29: The package rename was purely a package-prefix swap; native bundle IDs and Android signing settings were intentionally left untouched, so the safe pattern was to replace only the import prefix and avoid any platform config edits.
