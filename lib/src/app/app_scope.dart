import 'package:flutter/widgets.dart';

import 'app_controller.dart';

class AppScope extends InheritedNotifier<WebParityAppController> {
  const AppScope({
    required WebParityAppController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static WebParityAppController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope is missing from the widget tree.');
    return scope!.notifier!;
  }
}
