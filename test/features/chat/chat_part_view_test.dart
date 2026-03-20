import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile_remote/l10n/app_localizations.dart';
import 'package:opencode_mobile_remote/src/design_system/app_theme.dart';
import 'package:opencode_mobile_remote/src/features/chat/chat_models.dart';
import 'package:opencode_mobile_remote/src/features/chat/chat_part_view.dart';

void main() {
  Future<void> pumpPart(
    WidgetTester tester, {
    required ChatMessageInfo message,
    bool settle = true,
    ChatPart part = const ChatPart(
      id: 'part-1',
      type: 'text',
      text: 'Hello from the chat panel.',
    ),
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: SizedBox(
            width: 800,
            child: ChatPartView(message: message, part: part),
          ),
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  testWidgets('assistant messages align to the left', (tester) async {
    const message = ChatMessageInfo(
      id: 'assistant-message',
      role: 'assistant',
      sessionId: 'session-1',
    );

    await pumpPart(tester, message: message);

    final align = tester.widget<Align>(
      find.byKey(const ValueKey<String>('chat-part-bubble-assistant-message')),
    );
    expect(align.alignment, Alignment.centerLeft);
  });

  testWidgets('user messages align to the right', (tester) async {
    const message = ChatMessageInfo(
      id: 'user-message',
      role: 'user',
      sessionId: 'session-1',
    );

    await pumpPart(tester, message: message);

    final align = tester.widget<Align>(
      find.byKey(const ValueKey<String>('chat-part-bubble-user-message')),
    );
    expect(align.alignment, Alignment.centerRight);
  });

  testWidgets('tool parts render as standalone activity cards', (tester) async {
    const message = ChatMessageInfo(
      id: 'assistant-tool-message',
      role: 'assistant',
      sessionId: 'session-1',
    );

    await pumpPart(
      tester,
      message: message,
      settle: false,
      part: const ChatPart(
        id: 'tool-part',
        type: 'tool',
        tool: 'search',
        text: 'Searching the workspace for matching files.',
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('chat-part-activity-tool-part')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('chat-part-shimmer-tool-part')),
      findsOneWidget,
    );
    expect(
      find.text('Searching the workspace for matching files.'),
      findsOneWidget,
    );
  });
}
