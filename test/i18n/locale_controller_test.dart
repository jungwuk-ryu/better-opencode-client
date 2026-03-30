import 'package:better_opencode_client/src/i18n/locale_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
}
