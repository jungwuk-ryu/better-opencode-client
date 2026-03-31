import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'prompt_attachment_models.dart';

class PromptAttachmentService {
  static const List<String> acceptedFileExtensions = <String>[
    'png',
    'jpg',
    'jpeg',
    'gif',
    'webp',
    'pdf',
    'txt',
    'text',
    'md',
    'markdown',
    'log',
    'csv',
    'c',
    'cc',
    'cjs',
    'conf',
    'cpp',
    'css',
    'cts',
    'env',
    'go',
    'gql',
    'graphql',
    'h',
    'hh',
    'hpp',
    'htm',
    'html',
    'ini',
    'java',
    'js',
    'json',
    'jsonld',
    'jsx',
    'mjs',
    'mts',
    'py',
    'rb',
    'rs',
    'sass',
    'scss',
    'sh',
    'sql',
    'toml',
    'ts',
    'tsx',
    'xml',
    'yaml',
    'yml',
    'zsh',
  ];

  static XTypeGroup pickerTypeGroupForPlatform(TargetPlatform platform) {
    if (platform == TargetPlatform.iOS) {
      // file_selector on iOS requires uniformTypeIdentifiers for filtered
      // groups. We allow picking any file here and keep validation in the
      // attachment loader so unsupported files are still skipped consistently.
      return const XTypeGroup(label: 'Attachments');
    }
    return const XTypeGroup(
      label: 'Attachments',
      extensions: acceptedFileExtensions,
    );
  }

  static XTypeGroup get pickerTypeGroup =>
      pickerTypeGroupForPlatform(defaultTargetPlatform);

  static const int _textSampleSize = 4096;
  static const List<String> supportedImageMimeTypes = <String>[
    'image/png',
    'image/jpeg',
    'image/jpg',
    'image/gif',
    'image/webp',
  ];
  static const List<String> supportedContentInsertionMimeTypes = <String>[
    'image/png',
    'image/jpeg',
    'image/jpg',
    'image/gif',
    'image/webp',
  ];
  static const Map<String, String> _imageMimeByExtension = <String, String>{
    'png': 'image/png',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'gif': 'image/gif',
    'webp': 'image/webp',
  };
  static const Set<String> _textMimes = <String>{
    'application/json',
    'application/ld+json',
    'application/toml',
    'application/x-toml',
    'application/x-yaml',
    'application/xml',
    'application/yaml',
  };

  Future<PromptAttachmentLoadResult> loadFiles(List<XFile> files) async {
    final attachments = <PromptAttachment>[];
    final rejectedNames = <String>[];

    for (var index = 0; index < files.length; index += 1) {
      final attachment = await _readFile(files[index], index);
      if (attachment == null) {
        final name = files[index].name.trim();
        rejectedNames.add(name.isEmpty ? 'unnamed file' : name);
        continue;
      }
      attachments.add(attachment);
    }

    return PromptAttachmentLoadResult(
      attachments: attachments,
      rejectedNames: rejectedNames,
    );
  }

  PromptAttachment? attachmentFromBytes({
    required Uint8List bytes,
    required String mime,
    String? filename,
    int fallbackIndex = 0,
  }) {
    final resolvedMime = _attachmentMime(
      name: filename ?? '',
      mimeType: mime,
      bytes: bytes,
    );
    if (resolvedMime == null) {
      return null;
    }
    return _buildAttachment(
      bytes: bytes,
      mime: resolvedMime,
      filename: filename,
      fallbackIndex: fallbackIndex,
    );
  }

  PromptAttachment? attachmentFromInsertedContent(
    KeyboardInsertedContent content,
  ) {
    final data = content.data;
    if (data == null || data.isEmpty) {
      return null;
    }
    return attachmentFromBytes(
      bytes: data,
      mime: content.mimeType,
      filename: _filenameFromInsertedContent(
        uri: content.uri,
        mime: content.mimeType,
      ),
    );
  }

  Future<PromptAttachment?> _readFile(XFile file, int index) async {
    final bytes = await file.readAsBytes();
    return attachmentFromBytes(
      bytes: bytes,
      mime: file.mimeType ?? '',
      filename: file.name,
      fallbackIndex: index,
    );
  }

  PromptAttachment _buildAttachment({
    required Uint8List bytes,
    required String mime,
    required int fallbackIndex,
    String? filename,
  }) {
    final trimmedFilename = filename?.trim();
    final resolvedFilename = trimmedFilename == null || trimmedFilename.isEmpty
        ? _defaultFilenameForMime(mime, fallbackIndex)
        : trimmedFilename;
    return PromptAttachment(
      id: 'att_${DateTime.now().microsecondsSinceEpoch}_$fallbackIndex',
      filename: resolvedFilename,
      mime: mime,
      url: 'data:$mime;base64,${base64Encode(bytes)}',
    );
  }

  String? _attachmentMime({
    required String name,
    required String mimeType,
    required Uint8List bytes,
  }) {
    final type = _normalizedMime(mimeType);
    if (supportedImageMimeTypes.contains(type)) {
      return type;
    }
    if (type == 'application/pdf') {
      return type;
    }

    final extension = _fileExtension(name);
    final imageFallback = _imageMimeByExtension[extension];
    if ((type.isEmpty || type == 'application/octet-stream') &&
        imageFallback != null) {
      return imageFallback;
    }
    if ((type.isEmpty || type == 'application/octet-stream') &&
        extension == 'pdf') {
      return 'application/pdf';
    }

    if (_isTextMime(type) || _looksLikeText(bytes)) {
      return 'text/plain';
    }
    return null;
  }

  String _normalizedMime(String type) {
    final normalized = type.split(';').first.trim().toLowerCase();
    if (normalized == 'image/jpg') {
      return 'image/jpeg';
    }
    return normalized;
  }

  String _fileExtension(String name) {
    final index = name.lastIndexOf('.');
    if (index == -1 || index == name.length - 1) {
      return '';
    }
    return name.substring(index + 1).toLowerCase();
  }

  bool _isTextMime(String mime) {
    if (mime.isEmpty) {
      return false;
    }
    if (mime.startsWith('text/')) {
      return true;
    }
    if (_textMimes.contains(mime)) {
      return true;
    }
    if (mime.endsWith('+json')) {
      return true;
    }
    return mime.endsWith('+xml');
  }

  bool _looksLikeText(Uint8List bytes) {
    if (bytes.isEmpty) {
      return true;
    }
    final length = bytes.length > _textSampleSize
        ? _textSampleSize
        : bytes.length;
    var controlCount = 0;
    for (var index = 0; index < length; index += 1) {
      final byte = bytes[index];
      if (byte == 0) {
        return false;
      }
      if (byte < 9 || (byte > 13 && byte < 32)) {
        controlCount += 1;
      }
    }
    return controlCount / length <= 0.3;
  }

  String _filenameFromInsertedContent({
    required String uri,
    required String mime,
  }) {
    final parsed = Uri.tryParse(uri);
    final lastSegment = parsed?.pathSegments.isNotEmpty == true
        ? parsed!.pathSegments.last.trim()
        : '';
    if (lastSegment.isNotEmpty && lastSegment.contains('.')) {
      return lastSegment;
    }
    return _defaultFilenameForMime(_normalizedMime(mime), 0);
  }

  String _defaultFilenameForMime(String mime, int fallbackIndex) {
    final extension = switch (mime) {
      'image/png' => 'png',
      'image/jpeg' => 'jpg',
      'image/gif' => 'gif',
      'image/webp' => 'webp',
      'application/pdf' => 'pdf',
      _ => 'txt',
    };
    return 'attachment-$fallbackIndex.$extension';
  }
}
