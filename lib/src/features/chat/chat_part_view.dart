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
    final rendered =
        _chatPartRenderers[part.type]?.call(l10n, message, part) ??
        _RenderedChatPart(
          title: l10n.chatPartUnknown(part.type),
          body: _defaultBody(part),
        );
    if (_isActivityPart(part)) {
      return _ActivityPartCard(
        key: ValueKey<String>('chat-part-activity-${part.id}'),
        message: message,
        part: part,
        rendered: rendered,
      );
    }
    final isUserMessage = message.role == 'user';
    final accent = !isUserMessage;
    final bubbleAlignment = isUserMessage
        ? Alignment.centerRight
        : Alignment.centerLeft;
    final bubbleCrossAxisAlignment = isUserMessage
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;
    final bubbleTextAlign = isUserMessage ? TextAlign.right : TextAlign.left;
    final primary = accent
        ? Color.alphaBlend(
            theme.colorScheme.primary.withValues(alpha: 0.08),
            surfaces.panelEmphasis.withValues(alpha: 0.92),
          )
        : Color.alphaBlend(
            theme.colorScheme.secondary.withValues(alpha: 0.08),
            surfaces.panelRaised.withValues(alpha: 0.92),
          );
    final secondary = accent
        ? surfaces.panel.withValues(alpha: 0.98)
        : surfaces.panelMuted.withValues(alpha: 0.94);
    final secondaryLabel = _secondaryPartLabel(
      l10n: l10n,
      part: part,
      rendered: rendered,
      accent: accent,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxBubbleWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth * 0.84
            : 760.0;
        return Align(
          key: ValueKey<String>('chat-part-bubble-${message.id}'),
          alignment: bubbleAlignment,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxBubbleWidth.clamp(0, 760)),
            child: DecoratedBox(
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
                      : theme.colorScheme.secondary.withValues(alpha: 0.14),
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
                  crossAxisAlignment: bubbleCrossAxisAlignment,
                  children: <Widget>[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        _MessagePill(
                          label: accent
                              ? l10n.chatPartAssistant
                              : rendered.title,
                          icon: accent
                              ? Icons.auto_awesome_rounded
                              : Icons.person_outline_rounded,
                          emphasis: accent,
                        ),
                        if (secondaryLabel != null) ...<Widget>[
                          const SizedBox(width: AppSpacing.xs),
                          _MessagePill(
                            label: secondaryLabel,
                            icon: Icons.layers_outlined,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      rendered.body,
                      textAlign: bubbleTextAlign,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

bool _isActivityPart(ChatPart part) => part.type != 'text';

class _ActivityPartCard extends StatelessWidget {
  const _ActivityPartCard({
    required this.message,
    required this.part,
    required this.rendered,
    super.key,
  });

  final ChatMessageInfo message;
  final ChatPart part;
  final _RenderedChatPart rendered;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final palette = _activityPalette(context, part.type);
    final secondaryLabel = _activitySecondaryLabel(part);
    final shimmer = _shouldShimmerLabel(part.type);
    final summaryOnly = part.type == 'tool';
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxCardWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth * 0.92
            : 820.0;
        return Align(
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxCardWidth.clamp(0, 820)),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[palette.primary, palette.secondary],
                ),
                borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                border: Border.all(color: palette.border),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: palette.shadow,
                    blurRadius: 28,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: Stack(
                children: <Widget>[
                  Positioned(
                    left: 0,
                    top: 18,
                    bottom: 18,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: palette.accent,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.pillRadius,
                        ),
                      ),
                      child: const SizedBox(width: 4),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: <Color>[
                              Colors.white.withValues(alpha: 0.06),
                              Colors.transparent,
                              palette.accent.withValues(alpha: 0.04),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.md,
                      AppSpacing.md,
                      AppSpacing.md,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: palette.accent.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.pillRadius,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(AppSpacing.sm),
                                child: Icon(
                                  _activityIcon(part.type),
                                  size: 18,
                                  color: palette.accent,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  if (shimmer)
                                    _ShimmerLabel(
                                      key: ValueKey<String>(
                                        'chat-part-shimmer-${part.id}',
                                      ),
                                      text: rendered.title,
                                      baseColor:
                                          theme.textTheme.titleMedium?.color ??
                                          Colors.white,
                                      highlightColor: palette.accent,
                                    )
                                  else
                                    Text(
                                      rendered.title,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  const SizedBox(height: AppSpacing.xxs),
                                  Text(
                                    _activityCaption(message, part),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: surfaces.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _MessagePill(
                              label: part.type,
                              icon: Icons.memory_rounded,
                              emphasis: shimmer,
                            ),
                          ],
                        ),
                        if (secondaryLabel != null) ...<Widget>[
                          const SizedBox(height: AppSpacing.sm),
                          Wrap(
                            spacing: AppSpacing.xs,
                            runSpacing: AppSpacing.xs,
                            children: <Widget>[
                              _MessagePill(
                                label: secondaryLabel,
                                icon: Icons.layers_outlined,
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: AppSpacing.md),
                        if (summaryOnly)
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(
                                AppSpacing.formFieldRadius,
                              ),
                              border: Border.all(
                                color: palette.accent.withValues(alpha: 0.12),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    'Summary',
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                          color: palette.accent,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    _activitySummary(rendered.body),
                                    key: ValueKey<String>(
                                      'chat-part-summary-${part.id}',
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      height: 1.55,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(
                                AppSpacing.formFieldRadius,
                              ),
                              border: Border.all(
                                color: palette.accent.withValues(alpha: 0.12),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              child: Text(
                                rendered.body,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  height: 1.65,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ActivityPalette {
  const _ActivityPalette({
    required this.primary,
    required this.secondary,
    required this.border,
    required this.accent,
    required this.shadow,
  });

  final Color primary;
  final Color secondary;
  final Color border;
  final Color accent;
  final Color shadow;
}

_ActivityPalette _activityPalette(BuildContext context, String type) {
  final theme = Theme.of(context);
  final surfaces = theme.extension<AppSurfaces>()!;
  return switch (type) {
    'reasoning' || 'agent' || 'subtask' => _ActivityPalette(
      primary: Color.alphaBlend(
        theme.colorScheme.primary.withValues(alpha: 0.12),
        surfaces.panelEmphasis.withValues(alpha: 0.96),
      ),
      secondary: surfaces.panel.withValues(alpha: 0.96),
      border: theme.colorScheme.primary.withValues(alpha: 0.22),
      accent: theme.colorScheme.primary,
      shadow: theme.colorScheme.primary.withValues(alpha: 0.08),
    ),
    'tool' || 'patch' || 'file' => _ActivityPalette(
      primary: Color.alphaBlend(
        theme.colorScheme.tertiary.withValues(alpha: 0.12),
        surfaces.panelRaised.withValues(alpha: 0.94),
      ),
      secondary: surfaces.panelMuted.withValues(alpha: 0.94),
      border: theme.colorScheme.tertiary.withValues(alpha: 0.2),
      accent: theme.colorScheme.tertiary,
      shadow: theme.colorScheme.tertiary.withValues(alpha: 0.08),
    ),
    _ => _ActivityPalette(
      primary: surfaces.panelRaised.withValues(alpha: 0.94),
      secondary: surfaces.panel.withValues(alpha: 0.94),
      border: surfaces.lineSoft,
      accent: surfaces.accentSoft,
      shadow: Colors.black.withValues(alpha: 0.12),
    ),
  };
}

IconData _activityIcon(String type) {
  return switch (type) {
    'reasoning' => Icons.psychology_alt_outlined,
    'tool' => Icons.build_circle_outlined,
    'agent' => Icons.auto_awesome_rounded,
    'subtask' => Icons.account_tree_outlined,
    'file' => Icons.insert_drive_file_outlined,
    'patch' => Icons.auto_fix_high_outlined,
    'step-start' => Icons.play_circle_outline_rounded,
    'step-finish' => Icons.task_alt_rounded,
    'snapshot' => Icons.camera_outlined,
    'retry' => Icons.refresh_rounded,
    'compaction' => Icons.compress_rounded,
    _ => Icons.bolt_rounded,
  };
}

bool _shouldShimmerLabel(String type) {
  return switch (type) {
    'reasoning' || 'tool' || 'agent' || 'subtask' || 'step-start' => true,
    _ => false,
  };
}

String _activityCaption(ChatMessageInfo message, ChatPart part) {
  final roleLabel = message.role == 'user' ? 'User' : 'Agent';
  final toolLabel = part.tool?.trim();
  if (toolLabel != null && toolLabel.isNotEmpty) {
    return '$roleLabel activity · $toolLabel';
  }
  return '$roleLabel activity · ${part.type}';
}

String _activitySummary(String body) {
  final normalized = body
      .split(RegExp(r'\s+'))
      .where((segment) => segment.isNotEmpty)
      .join(' ')
      .trim();
  if (normalized.length <= 140) {
    return normalized;
  }
  return '${normalized.substring(0, 137).trimRight()}...';
}

String? _activitySecondaryLabel(ChatPart part) {
  if ((part.filename ?? '').trim().isNotEmpty) {
    return part.filename!.trim();
  }
  if ((part.tool ?? '').trim().isNotEmpty) {
    return part.tool!.trim();
  }
  return null;
}

class _ShimmerLabel extends StatefulWidget {
  const _ShimmerLabel({
    required this.text,
    required this.baseColor,
    required this.highlightColor,
    super.key,
  });

  final String text;
  final Color baseColor;
  final Color highlightColor;

  @override
  State<_ShimmerLabel> createState() => _ShimmerLabelState();
}

class _ShimmerLabelState extends State<_ShimmerLabel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final center = _controller.value;
        final stops = <double>[
          (center - 0.35).clamp(0.0, 1.0),
          (center - 0.15).clamp(0.0, 1.0),
          center.clamp(0.0, 1.0),
          (center + 0.15).clamp(0.0, 1.0),
          (center + 0.35).clamp(0.0, 1.0),
        ];
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: <Color>[
              widget.baseColor.withValues(alpha: 0.76),
              widget.baseColor,
              widget.highlightColor.withValues(alpha: 0.96),
              widget.baseColor,
              widget.baseColor.withValues(alpha: 0.76),
            ],
            stops: stops,
          ).createShader(bounds),
          child: child,
        );
      },
      child: Text(widget.text, style: textStyle),
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
  return rendered.title;
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
