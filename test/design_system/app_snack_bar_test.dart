import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:better_opencode_client/src/design_system/app_snack_bar.dart';
import 'package:better_opencode_client/src/design_system/app_theme.dart';

void main() {
  testWidgets('app snack bars float with blur and transparent chrome', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () {
                showAppSnackBar(
                  context,
                  message: 'Saved changes.',
                  tone: AppSnackBarTone.success,
                  action: AppSnackBarAction(label: 'Undo', onPressed: () {}),
                );
              },
              child: const Text('Show'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show'));
    await tester.pump();

    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.behavior, SnackBarBehavior.floating);
    expect(snackBar.backgroundColor, Colors.transparent);
    expect(snackBar.elevation, 0);
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(find.text('Saved changes.'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
  });

  test('dark theme defaults snack bars to floating transparent chrome', () {
    final theme = AppTheme.dark();
    expect(theme.snackBarTheme.behavior, SnackBarBehavior.floating);
    expect(theme.snackBarTheme.backgroundColor, Colors.transparent);
    expect(theme.snackBarTheme.elevation, 0);
  });
}
