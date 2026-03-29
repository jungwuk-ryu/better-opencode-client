import 'request_models.dart';

List<QuestionRequestSummary> applyQuestionAskedEvent(
  List<QuestionRequestSummary> questions,
  Map<String, Object?> properties, {
  required String? selectedSessionId,
}) {
  final nextQuestion = _tryParseQuestionRequest(properties);
  if (nextQuestion == null) {
    return questions;
  }
  if (!_matchesSelectedSession(selectedSessionId, nextQuestion.sessionId)) {
    return questions;
  }

  final next = List<QuestionRequestSummary>.from(questions);
  final index = next.indexWhere((question) => question.id == nextQuestion.id);
  if (index < 0) {
    next.add(nextQuestion);
  } else {
    next[index] = nextQuestion;
  }
  return next.toList(growable: false);
}

List<QuestionRequestSummary> applyQuestionResolvedEvent(
  List<QuestionRequestSummary> questions,
  Map<String, Object?> properties, {
  required String? selectedSessionId,
}) {
  final sessionId = properties['sessionID']?.toString();
  final requestId = properties['requestID']?.toString();
  if (!_matchesSelectedSession(selectedSessionId, sessionId) ||
      requestId == null ||
      requestId.isEmpty) {
    return questions;
  }

  return questions
      .where((question) => question.id != requestId)
      .toList(growable: false);
}

List<PermissionRequestSummary> applyPermissionAskedEvent(
  List<PermissionRequestSummary> permissions,
  Map<String, Object?> properties, {
  required String? selectedSessionId,
}) {
  final nextPermission = _tryParsePermissionRequest(properties);
  if (nextPermission == null) {
    return permissions;
  }
  if (!_matchesSelectedSession(selectedSessionId, nextPermission.sessionId)) {
    return permissions;
  }

  final next = List<PermissionRequestSummary>.from(permissions);
  final index = next.indexWhere(
    (permission) => permission.id == nextPermission.id,
  );
  if (index < 0) {
    next.add(nextPermission);
  } else {
    next[index] = nextPermission;
  }
  return next.toList(growable: false);
}

List<PermissionRequestSummary> applyPermissionResolvedEvent(
  List<PermissionRequestSummary> permissions,
  Map<String, Object?> properties, {
  required String? selectedSessionId,
}) {
  final sessionId = properties['sessionID']?.toString();
  final requestId = properties['requestID']?.toString();
  if (!_matchesSelectedSession(selectedSessionId, sessionId) ||
      requestId == null ||
      requestId.isEmpty) {
    return permissions;
  }

  return permissions
      .where((permission) => permission.id != requestId)
      .toList(growable: false);
}

bool _matchesSelectedSession(
  String? selectedSessionId,
  String? eventSessionId,
) {
  return selectedSessionId == null ||
      (eventSessionId != null && selectedSessionId == eventSessionId);
}

QuestionRequestSummary? _tryParseQuestionRequest(Map<String, Object?> json) {
  try {
    final request = QuestionRequestSummary.fromJson(json);
    if (request.id.isEmpty ||
        request.sessionId.isEmpty ||
        request.questions.isEmpty) {
      return null;
    }
    return request;
  } catch (_) {
    return null;
  }
}

PermissionRequestSummary? _tryParsePermissionRequest(
  Map<String, Object?> json,
) {
  try {
    final request = PermissionRequestSummary.fromJson(json);
    if (request.id.isEmpty ||
        request.sessionId.isEmpty ||
        request.permission.isEmpty) {
      return null;
    }
    return request;
  } catch (_) {
    return null;
  }
}
