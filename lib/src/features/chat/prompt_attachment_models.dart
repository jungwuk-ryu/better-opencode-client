class PromptAttachment {
  const PromptAttachment({
    required this.id,
    required this.filename,
    required this.mime,
    required this.url,
  });

  final String id;
  final String filename;
  final String mime;
  final String url;

  bool get isImage => mime.startsWith('image/');
}

class PromptAttachmentLoadResult {
  const PromptAttachmentLoadResult({
    required this.attachments,
    required this.rejectedNames,
  });

  final List<PromptAttachment> attachments;
  final List<String> rejectedNames;
}
