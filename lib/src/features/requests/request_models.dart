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

  Map<String, Object?> toJson() => <String, Object?>{
    'label': label,
    'description': description,
  };
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

  Map<String, Object?> toJson() => <String, Object?>{
    'question': question,
    'header': header,
    'options': options.map((item) => item.toJson()).toList(growable: false),
    'multiple': multiple,
  };
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

  QuestionRequestSummary copyWith({
    String? id,
    String? sessionId,
    List<QuestionPromptSummary>? questions,
  }) {
    return QuestionRequestSummary(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      questions: questions ?? this.questions,
    );
  }

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

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'sessionID': sessionId,
    'questions': questions.map((item) => item.toJson()).toList(growable: false),
  };
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

  PermissionRequestSummary copyWith({
    String? id,
    String? sessionId,
    String? permission,
    List<String>? patterns,
  }) {
    return PermissionRequestSummary(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      permission: permission ?? this.permission,
      patterns: patterns ?? this.patterns,
    );
  }

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

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'sessionID': sessionId,
    'permission': permission,
    'patterns': patterns,
  };
}

class PendingRequestBundle {
  const PendingRequestBundle({
    required this.questions,
    required this.permissions,
  });

  final List<QuestionRequestSummary> questions;
  final List<PermissionRequestSummary> permissions;

  Map<String, Object?> toJson() => <String, Object?>{
    'questions': questions.map((item) => item.toJson()).toList(growable: false),
    'permissions': permissions
        .map((item) => item.toJson())
        .toList(growable: false),
  };

  factory PendingRequestBundle.fromJson(Map<String, Object?> json) {
    return PendingRequestBundle(
      questions: ((json['questions'] as List?) ?? const <Object?>[])
          .whereType<Map>()
          .map(
            (item) =>
                QuestionRequestSummary.fromJson(item.cast<String, Object?>()),
          )
          .toList(growable: false),
      permissions: ((json['permissions'] as List?) ?? const <Object?>[])
          .whereType<Map>()
          .map(
            (item) =>
                PermissionRequestSummary.fromJson(item.cast<String, Object?>()),
          )
          .toList(growable: false),
    );
  }
}
