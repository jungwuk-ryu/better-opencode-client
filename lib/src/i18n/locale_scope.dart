import 'package:flutter/widgets.dart';

import 'locale_controller.dart';

class AppLocaleScope extends InheritedNotifier<LocaleController> {
  const AppLocaleScope({
    required LocaleController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static LocaleController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppLocaleScope>();
    assert(scope != null, 'AppLocaleScope is missing from the widget tree.');
    return scope!.notifier!;
  }

  static LocaleController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<AppLocaleScope>()
        ?.notifier;
  }
}
