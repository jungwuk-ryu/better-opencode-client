enum AppFlavor { debug, release }

extension AppFlavorX on AppFlavor {
  String get label => switch (this) {
    AppFlavor.debug => 'debug',
    AppFlavor.release => 'release',
  };

  bool get enablesFixtureTools => this == AppFlavor.debug;
}

AppFlavor currentFlavor() {
  const value = String.fromEnvironment('APP_FLAVOR', defaultValue: 'debug');
  return switch (value) {
    'release' => AppFlavor.release,
    _ => AppFlavor.debug,
  };
}
