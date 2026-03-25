import 'dart:convert';

import '../settings/config_service.dart';
import 'chat_models.dart';

enum SessionContextBreakdownKey { system, user, assistant, tool, other }

class SessionContextBreakdownSegment {
  const SessionContextBreakdownSegment({
    required this.key,
    required this.tokens,
    required this.widthPercent,
    required this.labelPercent,
  });

  final SessionContextBreakdownKey key;
  final int tokens;
  final double widthPercent;
  final double labelPercent;
}

class SessionContextSnapshot {
  const SessionContextSnapshot({
    required this.message,
    required this.providerLabel,
    required this.modelLabel,
    required this.inputTokens,
    required this.outputTokens,
    required this.reasoningTokens,
    required this.cacheReadTokens,
    required this.cacheWriteTokens,
    required this.totalTokens,
    required this.usagePercent,
    this.contextLimit,
  });

  final ChatMessage message;
  final String providerLabel;
  final String modelLabel;
  final int? contextLimit;
  final int inputTokens;
  final int outputTokens;
  final int reasoningTokens;
  final int cacheReadTokens;
  final int cacheWriteTokens;
  final int totalTokens;
  final int? usagePercent;
}

class SessionContextMetrics {
  const SessionContextMetrics({
    required this.totalCost,
    required this.context,
  });

  final double totalCost;
  final SessionContextSnapshot? context;
}

SessionContextMetrics getSessionContextMetrics({
  required List<ChatMessage> messages,
  ProviderCatalog? providerCatalog,
}) {
  final totalCost = messages.fold<double>(0, (sum, message) {
    if (message.info.role != 'assistant') {
      return sum;
    }
    return sum + (message.info.cost ?? 0);
  });

  ChatMessage? message;
  for (final candidate in messages.reversed) {
    if (candidate.info.role != 'assistant') {
      continue;
    }
    if (!candidate.info.hasTokenUsage) {
      continue;
    }
    message = candidate;
    break;
  }

  if (message == null) {
    return SessionContextMetrics(totalCost: totalCost, context: null);
  }

  final providerId = message.info.providerId?.trim();
  final modelId = message.info.modelId?.trim();
  final provider =
      providerId == null || providerId.isEmpty || providerCatalog == null
      ? null
      : _findProvider(providerCatalog, providerId);
  final model = provider == null || modelId == null || modelId.isEmpty
      ? null
      : _findModel(provider, providerId!, modelId);
  final totalTokens = message.info.resolvedTotalTokens;
  final contextLimit = model?.contextLimit;

  return SessionContextMetrics(
    totalCost: totalCost,
    context: SessionContextSnapshot(
      message: message,
      providerLabel: provider?.name.isNotEmpty == true
          ? provider!.name
          : (providerId?.isNotEmpty == true ? providerId! : '—'),
      modelLabel: model?.name.isNotEmpty == true
          ? model!.name
          : (modelId?.isNotEmpty == true ? modelId! : '—'),
      contextLimit: contextLimit,
      inputTokens: message.info.inputTokens ?? 0,
      outputTokens: message.info.outputTokens ?? 0,
      reasoningTokens: message.info.reasoningTokens ?? 0,
      cacheReadTokens: message.info.cacheReadTokens ?? 0,
      cacheWriteTokens: message.info.cacheWriteTokens ?? 0,
      totalTokens: totalTokens,
      usagePercent: contextLimit == null || contextLimit <= 0
          ? null
          : ((totalTokens / contextLimit) * 100).round(),
    ),
  );
}

List<SessionContextBreakdownSegment> estimateSessionContextBreakdown({
  required List<ChatMessage> messages,
  required int inputTokens,
  String? systemPrompt,
}) {
  if (inputTokens <= 0) {
    return const <SessionContextBreakdownSegment>[];
  }

  var systemChars = systemPrompt?.length ?? 0;
  var userChars = 0;
  var assistantChars = 0;
  var toolChars = 0;

  for (final message in messages) {
    if (message.info.role == 'user') {
      for (final part in message.parts) {
        userChars += _charsFromUserPart(part);
      }
      continue;
    }
    if (message.info.role != 'assistant') {
      continue;
    }
    for (final part in message.parts) {
      final counts = _charsFromAssistantPart(part);
      assistantChars += counts.assistantChars;
      toolChars += counts.toolChars;
    }
  }

  final estimatedSystem = _estimateTokens(systemChars);
  final estimatedUser = _estimateTokens(userChars);
  final estimatedAssistant = _estimateTokens(assistantChars);
  final estimatedTool = _estimateTokens(toolChars);
  final estimatedTotal =
      estimatedSystem + estimatedUser + estimatedAssistant + estimatedTool;

  if (estimatedTotal <= inputTokens) {
    return _buildSegments(
      inputTokens: inputTokens,
      systemTokens: estimatedSystem,
      userTokens: estimatedUser,
      assistantTokens: estimatedAssistant,
      toolTokens: estimatedTool,
      otherTokens: inputTokens - estimatedTotal,
    );
  }

  final scale = inputTokens / estimatedTotal;
  final scaledSystem = (estimatedSystem * scale).floor();
  final scaledUser = (estimatedUser * scale).floor();
  final scaledAssistant = (estimatedAssistant * scale).floor();
  final scaledTool = (estimatedTool * scale).floor();
  final scaledTotal = scaledSystem + scaledUser + scaledAssistant + scaledTool;

  return _buildSegments(
    inputTokens: inputTokens,
    systemTokens: scaledSystem,
    userTokens: scaledUser,
    assistantTokens: scaledAssistant,
    toolTokens: scaledTool,
    otherTokens: (inputTokens - scaledTotal).clamp(0, inputTokens),
  );
}

String? resolveSessionSystemPrompt({
  required List<ChatMessage> messages,
  String? revertMessageId,
}) {
  for (final message in messages.reversed) {
    if (message.info.role != 'user') {
      continue;
    }
    if (revertMessageId != null &&
        revertMessageId.isNotEmpty &&
        message.info.id.compareTo(revertMessageId) >= 0) {
      continue;
    }
    final prompt = message.info.systemPrompt?.trim();
    if (prompt != null && prompt.isNotEmpty) {
      return prompt;
    }
  }
  return null;
}

String formatRawSessionMessage(ChatMessage message) {
  return const JsonEncoder.withIndent('  ').convert(<String, Object?>{
    'message': message.info.toJson(),
    'parts': message.parts.map((part) => part.toJson()).toList(growable: false),
  });
}

ProviderDefinition? _findProvider(ProviderCatalog catalog, String providerId) {
  for (final provider in catalog.providers) {
    if (provider.id == providerId) {
      return provider;
    }
  }
  return null;
}

ProviderModelDefinition? _findModel(
  ProviderDefinition provider,
  String providerId,
  String modelId,
) {
  final exactKey = '$providerId/$modelId';
  final exact = provider.models[exactKey];
  if (exact != null) {
    return exact;
  }
  for (final model in provider.models.values) {
    if (model.id == modelId) {
      return model;
    }
  }
  return null;
}

List<SessionContextBreakdownSegment> _buildSegments({
  required int inputTokens,
  required int systemTokens,
  required int userTokens,
  required int assistantTokens,
  required int toolTokens,
  required int otherTokens,
}) {
  final candidates = <(SessionContextBreakdownKey, int)>[
    (SessionContextBreakdownKey.system, systemTokens),
    (SessionContextBreakdownKey.user, userTokens),
    (SessionContextBreakdownKey.assistant, assistantTokens),
    (SessionContextBreakdownKey.tool, toolTokens),
    (SessionContextBreakdownKey.other, otherTokens),
  ];
  return candidates
      .where((entry) => entry.$2 > 0)
      .map(
        (entry) => SessionContextBreakdownSegment(
          key: entry.$1,
          tokens: entry.$2,
          widthPercent: _toPercent(entry.$2, inputTokens),
          labelPercent: _toPercentLabel(entry.$2, inputTokens),
        ),
      )
      .toList(growable: false);
}

int _estimateTokens(int characters) => (characters / 4).ceil();

double _toPercent(int tokens, int inputTokens) => (tokens / inputTokens) * 100;

double _toPercentLabel(int tokens, int inputTokens) {
  return ((_toPercent(tokens, inputTokens) * 10).round()) / 10;
}

int _charsFromUserPart(ChatPart part) {
  switch (part.type) {
    case 'text':
      return part.text?.length ?? 0;
    case 'file':
      return _nestedString(
            part.metadata,
            const <String>['source', 'text', 'value'],
          )?.length ??
          0;
    case 'agent':
      return _nestedString(part.metadata, const <String>['source', 'value'])
              ?.length ??
          0;
    default:
      return 0;
  }
}

({int assistantChars, int toolChars}) _charsFromAssistantPart(ChatPart part) {
  switch (part.type) {
    case 'text':
    case 'reasoning':
      return (assistantChars: part.text?.length ?? 0, toolChars: 0);
    case 'tool':
      final state = _nestedMap(part.metadata, const <String>['state']);
      final status = state?['status']?.toString();
      final input = _nestedMap(part.metadata, const <String>['state', 'input']);
      final inputChars = input == null ? 0 : input.length * 16;
      switch (status) {
        case 'pending':
          return (
            assistantChars: 0,
            toolChars: inputChars + (state?['raw']?.toString().length ?? 0),
          );
        case 'completed':
          return (
            assistantChars: 0,
            toolChars:
                inputChars + (state?['output']?.toString().length ?? 0),
          );
        case 'error':
          return (
            assistantChars: 0,
            toolChars:
                inputChars + (state?['error']?.toString().length ?? 0),
          );
        default:
          return (assistantChars: 0, toolChars: inputChars);
      }
    default:
      return (assistantChars: 0, toolChars: 0);
  }
}

Map<String, Object?>? _nestedMap(Map<String, Object?> source, List<String> path) {
  Object? current = source;
  for (final segment in path) {
    if (current is! Map) {
      return null;
    }
    current = current[segment];
  }
  if (current is Map) {
    return current.cast<String, Object?>();
  }
  return null;
}

String? _nestedString(Map<String, Object?> source, List<String> path) {
  Object? current = source;
  for (final segment in path) {
    if (current is! Map) {
      return null;
    }
    current = current[segment];
  }
  return current?.toString();
}
