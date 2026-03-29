import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:better_opencode_client/src/core/network/sse_parser.dart';

void main() {
  test('parser reads multiple frames and multiline data', () async {
    const source =
        'event: server.connected\n'
        'data: {}\n\n'
        'event: message.part.updated\n'
        'data: {"partID":"p-1",\n'
        'data: "content":"hello"}\n\n';

    final frames = await const SseParser()
        .bind(Stream<List<int>>.value(utf8.encode(source)))
        .toList();

    expect(frames.length, 2);
    expect(frames.first.event, 'server.connected');
    expect(frames.last.event, 'message.part.updated');
    expect(frames.last.data, contains('content'));
  });
}
