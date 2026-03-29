# Issues

- 2026-03-29: Extra build verification found two unrelated blockers outside the package-identity rename scope: `flutter build web` fails because `lib/src/core/persistence/stale_cache_store.dart` uses large integer literals that `dart2js` cannot represent exactly in JavaScript, and `flutter build bundle` fails in this environment because the Android SDK is unavailable.
