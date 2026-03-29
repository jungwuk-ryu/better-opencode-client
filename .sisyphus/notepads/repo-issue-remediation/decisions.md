# Decisions

- 2026-03-29: Kept generated localization Dart outputs under `lib/l10n/` tracked as the repository policy, and documented `flutter gen-l10n` in `README.md` as the explicit regeneration step after ARB changes.
- 2026-03-29: Added `.github/workflows/ci.yml` that mirrors the repo's verification convention using the explicit Flutter binary path for `analyze`, `gen-l10n`, and `test`.
