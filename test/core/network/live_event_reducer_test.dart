import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile_remote/src/core/network/live_event_reducer.dart';

void main() {
  test('reducer deduplicates by part id through overwrite semantics', () {
    final reducer = LiveEventReducer();

    reducer.apply('server.connected', '{}');
    reducer.apply('message.part.updated', '{"partID":"p-2","content":"draft"}');
    reducer.apply('message.part.updated', '{"partID":"p-2","content":"draft"}');

    expect(reducer.state.connectionCount, 1);
    expect(reducer.state.messageParts.length, 1);
    expect(reducer.state.messageParts['p-2'], 'draft');
  });

  test('reducer marks resync requirement when requested', () {
    final reducer = LiveEventReducer();

    reducer.apply('stream.resync_required', '{"reason":"missed sequence"}');

    expect(reducer.state.needsResync, isTrue);
  });
}
