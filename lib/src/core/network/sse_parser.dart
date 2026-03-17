import 'dart:convert';

import 'sse_frame.dart';

class SseParser {
  const SseParser();

  Stream<SseFrame> bind(Stream<List<int>> source) async* {
    final decoder = utf8.decoder.bind(source);
    final buffer = StringBuffer();

    await for (final chunk in decoder) {
      buffer.write(chunk);
      final normalized = buffer.toString().replaceAll('\r\n', '\n');
      final segments = normalized.split('\n\n');
      if (segments.length == 1) {
        buffer
          ..clear()
          ..write(normalized);
        continue;
      }

      for (final segment in segments.take(segments.length - 1)) {
        final frame = _parseFrame(segment);
        if (frame != null) {
          yield frame;
        }
      }

      buffer
        ..clear()
        ..write(segments.last);
    }

    final trailing = buffer.toString().trim();
    if (trailing.isNotEmpty) {
      final frame = _parseFrame(trailing);
      if (frame != null) {
        yield frame;
      }
    }
  }

  SseFrame? _parseFrame(String raw) {
    String? event;
    String? id;
    final dataLines = <String>[];

    for (final line in raw.split('\n')) {
      if (line.isEmpty || line.startsWith(':')) {
        continue;
      }
      final separator = line.indexOf(':');
      if (separator == -1) {
        continue;
      }
      final field = line.substring(0, separator);
      final value = line.substring(separator + 1).trimLeft();
      switch (field) {
        case 'event':
          event = value;
        case 'id':
          id = value;
        case 'data':
          dataLines.add(value);
      }
    }

    if (event == null && id == null && dataLines.isEmpty) {
      return null;
    }
    return SseFrame(event: event, id: id, data: dataLines.join('\n'));
  }
}
