import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:better_opencode_client/src/features/chat/prompt_attachment_service.dart';

void main() {
  final service = PromptAttachmentService();

  test('accepts image, pdf, and text attachments', () async {
    final result = await service.loadFiles(<XFile>[
      XFile.fromData(
        Uint8List.fromList(<int>[0x89, 0x50, 0x4E, 0x47]),
        name: 'diagram.png',
        mimeType: 'image/png',
      ),
      XFile.fromData(
        Uint8List.fromList(<int>[0x25, 0x50, 0x44, 0x46]),
        name: 'report.pdf',
        mimeType: 'application/pdf',
      ),
      XFile.fromData(
        Uint8List.fromList('hello world'.codeUnits),
        name: 'notes.md',
        mimeType: 'text/markdown',
      ),
    ]);

    expect(result.attachments, hasLength(3));
    expect(result.attachments[0].mime, 'image/png');
    expect(result.attachments[1].mime, 'application/pdf');
    expect(result.attachments[2].mime, 'text/plain');
    expect(result.rejectedNames, isEmpty);
  });

  test('preserves filenames for dropped path-based files', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'prompt_attachment_service_drop_test',
    );
    addTearDown(() => tempDir.delete(recursive: true));

    final notesFile = File('${tempDir.path}/notes.txt');
    await notesFile.writeAsString('hello world');
    final imageFile = File('${tempDir.path}/diagram.png');
    await imageFile.writeAsBytes(const <int>[0x89, 0x50, 0x4E, 0x47]);

    final result = await service.loadFiles(<XFile>[
      XFile(notesFile.path, mimeType: 'text/plain'),
      XFile(imageFile.path, mimeType: 'image/png'),
    ]);

    expect(
      result.attachments.map((attachment) => attachment.filename).toList(),
      <String>['notes.txt', 'diagram.png'],
    );
    expect(
      result.attachments.map((attachment) => attachment.mime).toList(),
      <String>['text/plain', 'image/png'],
    );
    expect(result.rejectedNames, isEmpty);
  });

  test('rejects unsupported binary attachments', () async {
    final result = await service.loadFiles(<XFile>[
      XFile.fromData(
        Uint8List.fromList(<int>[0, 159, 146, 150, 0, 1, 2, 3]),
        name: 'archive.bin',
        mimeType: 'application/octet-stream',
      ),
    ]);

    expect(result.attachments, isEmpty);
    expect(result.rejectedNames, <String>['unnamed file']);
  });
}
