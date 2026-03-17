import 'package:flutter/material.dart';
import 'package:opencode_mobile_remote/l10n/app_localizations.dart';

import '../../design_system/app_spacing.dart';
import '../../design_system/app_theme.dart';
import 'chat_models.dart';

typedef _ChatPartRenderer =
    _RenderedChatPart Function(
      AppLocalizations l10n,
      ChatMessageInfo message,
      ChatPart part,
    );

class _RenderedChatPart {
  const _RenderedChatPart({required this.title, required this.body});

  final String title;
  final String body;
}

final Map<String, _ChatPartRenderer>
_chatPartRenderers = <String, _ChatPartRenderer>{
  'text': (l10n, message, part) => _RenderedChatPart(
    title: message.role == 'assistant'
        ? l10n.chatPartAssistant
        : l10n.chatPartUser,
    body: _defaultBody(part),
  ),
  'reasoning': (l10n, _, part) =>
      _RenderedChatPart(title: l10n.chatPartThinking, body: _defaultBody(part)),
  'tool': (l10n, _, part) => _RenderedChatPart(
    title: part.tool == null
        ? l10n.chatPartTool
        : l10n.chatPartToolNamed(part.tool!),
    body: _defaultBody(part),
  ),
  'file': (l10n, _, part) =>
      _RenderedChatPart(title: l10n.chatPartFile, body: _defaultBody(part)),
  'step-start': (l10n, _, part) => _RenderedChatPart(
    title: l10n.chatPartStepStart,
    body: _defaultBody(part),
  ),
  'step-finish': (l10n, _, part) => _RenderedChatPart(
    title: l10n.chatPartStepFinish,
    body: _defaultBody(part),
  ),
  'snapshot': (l10n, _, part) =>
      _RenderedChatPart(title: l10n.chatPartSnapshot, body: _defaultBody(part)),
  'patch': (l10n, _, part) =>
      _RenderedChatPart(title: l10n.chatPartPatch, body: _defaultBody(part)),
  'retry': (l10n, _, part) =>
      _RenderedChatPart(title: l10n.chatPartRetry, body: _defaultBody(part)),
  'agent': (l10n, _, part) =>
      _RenderedChatPart(title: l10n.chatPartAgent, body: _defaultBody(part)),
  'subtask': (l10n, _, part) =>
      _RenderedChatPart(title: l10n.chatPartSubtask, body: _defaultBody(part)),
  'compaction': (l10n, _, part) => _RenderedChatPart(
    title: l10n.chatPartCompaction,
    body: _defaultBody(part),
  ),
};

class ChatPartView extends StatelessWidget {
  const ChatPartView({required this.message, required this.part, super.key});

  final ChatMessageInfo message;
  final ChatPart part;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final accent = message.role == 'assistant';
    final primary = accent
        ? Color.alphaBlend(
            theme.colorScheme.primary.withValues(alpha: 0.08),
            surfaces.panelEmphasis.withValues(alpha: 0.92),
          )
        : surfaces.panelRaised.withValues(alpha: 0.82);
    final secondary = accent
        ? surfaces.panel.withValues(alpha: 0.98)
        : surfaces.panelMuted.withValues(alpha: 0.94);
    final rendered =
        _chatPartRenderers[part.type]?.call(l10n, message, part) ??
        _RenderedChatPart(
          title: l10n.chatPartUnknown(part.type),
          body: _defaultBody(part),
        );
    final secondaryLabel = _secondaryPartLabel(
      l10n: l10n,
      part: part,
      rendered: rendered,
      accent: accent,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[primary, secondary],
        ),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(
          color: accent
              ? theme.colorScheme.primary.withValues(alpha: 0.22)
              : surfaces.lineSoft,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: accent
                ? theme.colorScheme.primary.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                _MessagePill(
                  label: accent ? l10n.chatPartAssistant : rendered.title,
                  icon: accent
                      ? Icons.auto_awesome_rounded
                      : Icons.person_outline_rounded,
                  emphasis: accent,
                ),
                const SizedBox(width: AppSpacing.xs),
                if (secondaryLabel != null)
                  _MessagePill(
                    label: secondaryLabel,
                    icon: Icons.layers_outlined,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              rendered.body,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessagePill extends StatelessWidget {
  const _MessagePill({
    required this.label,
    required this.icon,
    this.emphasis = false,
  });

  final String label;
  final IconData icon;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: emphasis
            ? theme.colorScheme.primary.withValues(alpha: 0.12)
            : surfaces.panelMuted.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
        border: Border.all(
          color: emphasis
              ? theme.colorScheme.primary.withValues(alpha: 0.18)
              : surfaces.lineSoft,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              icon,
              size: 14,
              color: emphasis ? theme.colorScheme.primary : surfaces.accentSoft,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: emphasis ? theme.colorScheme.primary : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String? _secondaryPartLabel({
  required AppLocalizations l10n,
  required ChatPart part,
  required _RenderedChatPart rendered,
  required bool accent,
}) {
  if (part.type == 'text' || !accent) {
    return null;
  }
  return _chatPartRenderers.containsKey(part.type)
      ? rendered.title
      : l10n.chatPartUnknown(part.type);
}

String _defaultBody(ChatPart part) {
  if ((part.text ?? '').trim().isNotEmpty) {
    return part.text!.trim();
  }
  if ((part.filename ?? '').trim().isNotEmpty) {
    return part.filename!.trim();
  }
  return part.metadata.toString();
}
