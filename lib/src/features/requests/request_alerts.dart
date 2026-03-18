import 'request_models.dart';

enum PendingRequestAlertKind { question, permission }

class PendingRequestAlert {
  const PendingRequestAlert({
    required this.kind,
    required this.requestId,
    required this.summary,
    this.detail,
  });

  final PendingRequestAlertKind kind;
  final String requestId;
  final String summary;
  final String? detail;
}

PendingRequestAlert? buildQuestionAskedAlert({
  required List<QuestionRequestSummary> previous,
  required List<QuestionRequestSummary> next,
}) {
  final previousIds = previous.map((question) => question.id).toSet();
  final added = next.where((question) => !previousIds.contains(question.id));
  if (added.isEmpty) {
    return null;
  }
  final request = added.first;
  final prompt = request.questions.isEmpty ? null : request.questions.first;
  final summary =
      _cleanText(prompt?.header) ?? _cleanText(prompt?.question) ?? request.id;
  return PendingRequestAlert(
    kind: PendingRequestAlertKind.question,
    requestId: request.id,
    summary: summary,
    detail: _cleanText(prompt?.question),
  );
}

PendingRequestAlert? buildPermissionAskedAlert({
  required List<PermissionRequestSummary> previous,
  required List<PermissionRequestSummary> next,
}) {
  final previousIds = previous.map((permission) => permission.id).toSet();
  final added = next.where(
    (permission) => !previousIds.contains(permission.id),
  );
  if (added.isEmpty) {
    return null;
  }
  final request = added.first;
  final detail = request.patterns
      .map(_cleanText)
      .whereType<String>()
      .join(', ');
  return PendingRequestAlert(
    kind: PendingRequestAlertKind.permission,
    requestId: request.id,
    summary: _cleanText(request.permission) ?? request.id,
    detail: detail.isEmpty ? null : detail,
  );
}

String? _cleanText(String? value) {
  final cleaned = value?.trim();
  if (cleaned == null || cleaned.isEmpty) {
    return null;
  }
  return cleaned;
}
