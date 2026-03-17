class QuestionOptionSummary {
  const QuestionOptionSummary({required this.label, required this.description});

  final String label;
  final String description;

  factory QuestionOptionSummary.fromJson(Map<String, Object?> json) {
    return QuestionOptionSummary(
      label: (json['label'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
    );
  }
}

class QuestionPromptSummary {
  const QuestionPromptSummary({
    required this.question,
    required this.header,
    required this.options,
    required this.multiple,
  });

  final String question;
  final String header;
  final List<QuestionOptionSummary> options;
  final bool multiple;

  factory QuestionPromptSummary.fromJson(Map<String, Object?> json) {
    return QuestionPromptSummary(
      question: (json['question'] as String?) ?? '',
      header: (json['header'] as String?) ?? '',
      options: ((json['options'] as List?) ?? const <Object?>[])
          .whereType<Map>()
          .map(
            (item) =>
                QuestionOptionSummary.fromJson(item.cast<String, Object?>()),
          )
          .toList(growable: false),
      multiple: (json['multiple'] as bool?) ?? false,
    );
  }
}

class QuestionRequestSummary {
  const QuestionRequestSummary({
    required this.id,
    required this.sessionId,
    required this.questions,
  });

  final String id;
  final String sessionId;
  final List<QuestionPromptSummary> questions;

  factory QuestionRequestSummary.fromJson(Map<String, Object?> json) {
    return QuestionRequestSummary(
      id: (json['id'] as String?) ?? '',
      sessionId: (json['sessionID'] as String?) ?? '',
      questions: ((json['questions'] as List?) ?? const <Object?>[])
          .whereType<Map>()
          .map(
            (item) =>
                QuestionPromptSummary.fromJson(item.cast<String, Object?>()),
          )
          .toList(growable: false),
    );
  }
}

class PermissionRequestSummary {
  const PermissionRequestSummary({
    required this.id,
    required this.sessionId,
    required this.permission,
    required this.patterns,
  });

  final String id;
  final String sessionId;
  final String permission;
  final List<String> patterns;

  factory PermissionRequestSummary.fromJson(Map<String, Object?> json) {
    return PermissionRequestSummary(
      id: (json['id'] as String?) ?? '',
      sessionId: (json['sessionID'] as String?) ?? '',
      permission: (json['permission'] as String?) ?? '',
      patterns: ((json['patterns'] as List?) ?? const <Object?>[])
          .map((item) => item.toString())
          .toList(growable: false),
    );
  }
}

class PendingRequestBundle {
  const PendingRequestBundle({
    required this.questions,
    required this.permissions,
  });

  final List<QuestionRequestSummary> questions;
  final List<PermissionRequestSummary> permissions;
}
