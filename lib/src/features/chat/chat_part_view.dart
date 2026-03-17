import 'package:flutter/material.dart';

import '../../design_system/app_spacing.dart';
import '../../design_system/app_theme.dart';
import 'chat_models.dart';

class ChatPartView extends StatelessWidget {
  const ChatPartView({required this.message, required this.part, super.key});

  final ChatMessageInfo message;
  final ChatPart part;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final accent = message.role == 'assistant';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: (accent ? surfaces.accentSoft : surfaces.panelRaised).withValues(
          alpha: 0.12,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: surfaces.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(_title(), style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(_body()),
          ],
        ),
      ),
    );
  }

  String _title() {
    return switch (part.type) {
      'text' => message.role == 'assistant' ? 'Assistant' : 'User',
      'reasoning' => 'Thinking',
      'tool' => part.tool == null ? 'Tool' : 'Tool: ${part.tool}',
      'file' => 'File',
      'step-start' => 'Step start',
      'step-finish' => 'Step finish',
      'snapshot' => 'Snapshot',
      'patch' => 'Patch',
      'agent' => 'Agent',
      'subtask' => 'Subtask',
      'compaction' => 'Compaction',
      _ => part.type,
    };
  }

  String _body() {
    if ((part.text ?? '').trim().isNotEmpty) {
      return part.text!.trim();
    }
    if ((part.filename ?? '').trim().isNotEmpty) {
      return part.filename!.trim();
    }
    return part.metadata.toString();
  }
}
