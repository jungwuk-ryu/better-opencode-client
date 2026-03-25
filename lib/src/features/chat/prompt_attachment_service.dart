import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

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

  static final XTypeGroup pickerTypeGroup = XTypeGroup(
    label: 'Attachments',
    extensions: acceptedFileExtensions,
  );

  static const int _textSampleSize = 4096;
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

  Future<PromptAttachment?> _readFile(XFile file, int index) async {
    final bytes = await file.readAsBytes();
    final mime = _attachmentMime(file, bytes);
    if (mime == null) {
      return null;
    }
    final name = file.name.trim().isEmpty ? 'attachment-$index' : file.name;
    return PromptAttachment(
      id: 'att_${DateTime.now().microsecondsSinceEpoch}_$index',
      filename: name,
      mime: mime,
      url: 'data:$mime;base64,${base64Encode(bytes)}',
    );
  }

  String? _attachmentMime(XFile file, Uint8List bytes) {
    final type = _normalizedMime(file.mimeType ?? '');
    if (_imageMimeByExtension.containsValue(type)) {
      return type;
    }
    if (type == 'application/pdf') {
      return type;
    }

    final extension = _fileExtension(file.name);
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
}
