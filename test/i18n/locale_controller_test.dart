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
    'locale controller resolves japanese and chinese system locales',
    (tester) async {
      tester.binding.platformDispatcher.localesTestValue = const <Locale>[
        Locale('ja', 'JP'),
      ];
      addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);

      final japaneseController = LocaleController();
      addTearDown(japaneseController.dispose);

      expect(japaneseController.locale, const Locale('ja'));

      tester.binding.platformDispatcher.localesTestValue = const <Locale>[
        Locale('zh', 'CN'),
      ];

      final chineseController = LocaleController();
      addTearDown(chineseController.dispose);

      expect(chineseController.locale, const Locale('zh'));
    },
  );

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
      expect(controller.locale, const Locale('ja'));

      tester.binding.platformDispatcher.localesTestValue = const <Locale>[
        Locale('fr', 'FR'),
      ];
      expect(controller.locale, const Locale('ja'));

      controller.toggle();
      expect(controller.locale, const Locale('zh'));

      controller.toggle();
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
      'app.locale_mode': 'japanese',
    });
    tester.binding.platformDispatcher.localesTestValue = const <Locale>[
      Locale('ko', 'KR'),
    ];
    addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);

    final controller = LocaleController();
    addTearDown(controller.dispose);

    expect(controller.locale, const Locale('ko'));

    await controller.load();

    expect(controller.mode, AppLocaleMode.japanese);
    expect(controller.locale, const Locale('ja'));
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

    await controller.setMode(AppLocaleMode.chinese);

    expect(controller.mode, AppLocaleMode.chinese);
    expect(controller.locale, const Locale('zh'));

    final restored = LocaleController();
    addTearDown(restored.dispose);

    await restored.load();

    expect(restored.mode, AppLocaleMode.chinese);
    expect(restored.locale, const Locale('zh'));
  });
}
