# Testing Rules

## Responsive UI Matrix Rule

Every screen-level or panel-level Flutter widget test must include responsive
matrix coverage.

Required viewport set:

- `320x568` phone-se
- `360x740` phone-compact
- `390x844` phone-standard
- `430x932` phone-large
- `768x1024` tablet-portrait
- `1024x768` tablet-landscape
- `1366x1024` tablet-large
- `1280x800` desktop-narrow
- `1440x900` desktop-standard
- `2880x900` desktop-ultrawide
- `900x1800` desktop-tall
- `1200x2200` desktop-extra-tall

Implementation rules:

- Reuse `/Users/jungwuk/Documents/works/opencode-mobile-remote/test/test_helpers/responsive_viewports.dart`.
- Every UI test file must contain at least one responsive matrix smoke test for
  the surface it owns.
- Use the full matrix by default. If a surface has a narrower supported range,
  use a named subset that still covers phone, tablet, desktop, ultrawide, and
  tall-window cases.
- Breakpoint-specific behavior tests may still pin a single viewport, but they
  do not replace the matrix smoke test.
- If a test intentionally targets a fixed viewport only, keep the fixed
  assertion and add a nearby comment explaining why that case is breakpoint
  specific.

Verification rules:

- Run `flutter analyze`
- Run `flutter test`
- Run `flutter build macos --debug`
