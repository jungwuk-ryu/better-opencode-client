import 'package:flutter/services.dart';

import 'prompt_attachment_models.dart';
import 'prompt_attachment_service.dart';

class ClipboardImageService {
  static const MethodChannel _channel = MethodChannel(
    'opencode_mobile_remote/clipboard_image',
  );

  Future<PromptAttachment?> loadClipboardImageAttachment(
    PromptAttachmentService attachmentService,
  ) async {
    final payload = await _readClipboardImagePayload();
    if (payload == null) {
      return null;
    }
    return attachmentService.attachmentFromBytes(
      bytes: payload.bytes,
      mime: payload.mime,
      filename: payload.filename,
    );
  }

  Future<_ClipboardImagePayload?> _readClipboardImagePayload() async {
    try {
      final result = await _channel.invokeMethod<Object?>('readClipboardImage');
      if (result is! Map<Object?, Object?>) {
        return null;
      }
      final bytes = result['bytes'];
      final mime = (result['mimeType'] as String?)?.trim();
      final filename = (result['filename'] as String?)?.trim();
      if (bytes is! Uint8List ||
          bytes.isEmpty ||
          mime == null ||
          mime.isEmpty) {
        return null;
      }
      return _ClipboardImagePayload(
        bytes: bytes,
        mime: mime,
        filename: filename,
      );
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}

class _ClipboardImagePayload {
  const _ClipboardImagePayload({
    required this.bytes,
    required this.mime,
    this.filename,
  });

  final Uint8List bytes;
  final String mime;
  final String? filename;
}
