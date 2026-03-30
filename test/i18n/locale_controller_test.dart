import 'package:better_opencode_client/src/i18n/locale_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('locale controller starts from the supported system locale', (
    tester,
  ) async {
    tester.binding.platformDispatcher.localesTestValue = const <Locale>[
      Locale('ko', 'KR'),
    ];
    addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);

    final controller = LocaleController();
    addTearDown(controller.dispose);

    expect(controller.locale, const Locale('ko'));
  });

  testWidgets(
    'locale controller keeps following system changes until a manual toggle overrides it',
    (tester) async {
      tester.binding.platformDispatcher.localesTestValue = const <Locale>[
        Locale('en', 'US'),
      ];
      addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);

      final controller = LocaleController();
      addTearDown(controller.dispose);

      expect(controller.locale, const Locale('en'));

      tester.binding.platformDispatcher.localesTestValue = const <Locale>[
        Locale('ko', 'KR'),
      ];
      expect(controller.locale, const Locale('ko'));

      controller.toggle();
      expect(controller.locale, const Locale('en'));

      tester.binding.platformDispatcher.localesTestValue = const <Locale>[
        Locale('fr', 'FR'),
      ];
      expect(controller.locale, const Locale('en'));

      controller.toggle();
      tester.binding.platformDispatcher.localesTestValue = const <Locale>[
        Locale('ko', 'KR'),
      ];
      expect(controller.locale, const Locale('ko'));
    },
  );

  testWidgets('stored app language overrides the system locale after load', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app.locale_mode': 'english',
    });
    tester.binding.platformDispatcher.localesTestValue = const <Locale>[
      Locale('ko', 'KR'),
    ];
    addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);

    final controller = LocaleController();
    addTearDown(controller.dispose);

    expect(controller.locale, const Locale('ko'));

    await controller.load();

    expect(controller.mode, AppLocaleMode.english);
    expect(controller.locale, const Locale('en'));
  });

  testWidgets('selected app language persists across controller reloads', (
    tester,
  ) async {
    tester.binding.platformDispatcher.localesTestValue = const <Locale>[
      Locale('en', 'US'),
    ];
    addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);

    final controller = LocaleController();
    addTearDown(controller.dispose);

    await controller.setMode(AppLocaleMode.korean);

    expect(controller.mode, AppLocaleMode.korean);
    expect(controller.locale, const Locale('ko'));

    final restored = LocaleController();
    addTearDown(restored.dispose);

    await restored.load();

    expect(restored.mode, AppLocaleMode.korean);
    expect(restored.locale, const Locale('ko'));
  });
}
