part of 'web_home_screen.dart';

class _ServerPill extends StatelessWidget {
  const _ServerPill({required this.profile, required this.report, this.onTap});

  final ServerProfile? profile;
  final ServerProbeReport? report;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final color = switch (report?.classification) {
      ConnectionProbeClassification.ready => surfaces.success,
      ConnectionProbeClassification.authFailure => Theme.of(
        context,
      ).colorScheme.secondary,
      ConnectionProbeClassification.unsupportedCapabilities => surfaces.warning,
      ConnectionProbeClassification.specFetchFailure => surfaces.warning,
      ConnectionProbeClassification.connectivityFailure => surfaces.danger,
      null => surfaces.muted,
    };
    final child = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: appSoftCardDecoration(
        context,
        radius: AppSpacing.pillRadius,
        muted: true,
        emphasized: false,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(profile?.effectiveLabel ?? context.wp('Select Server')),
        ],
      ),
    );
    if (onTap == null) {
      return child;
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
      child: child,
    );
  }
}

class _ServersSheet extends StatefulWidget {
  const _ServersSheet({required this.controller});

  final WebParityAppController controller;

  @override
  State<_ServersSheet> createState() => _ServersSheetState();
}

class _ServersSheetState extends State<_ServersSheet> {
  WebParityAppController get controller => widget.controller;

  Future<void> _openServerEditor({ServerProfile? profile}) async {
    final draft = await showModalBottomSheet<ServerProfile>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.72,
        child: _ServerEditorSheet(initialProfile: profile),
      ),
    );
    if (draft == null) {
      return;
    }
    final savedProfile = await controller.saveProfile(draft);
    if (!mounted) {
      return;
    }
    showAppSnackBar(
      context,
      message: context.wp(
        'Saved "{label}" and refreshed status.',
        args: <String, Object?>{'label': savedProfile.effectiveLabel},
      ),
      tone: AppSnackBarTone.success,
    );
  }

  Future<void> _confirmDelete(ServerProfile profile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final surfaces = Theme.of(context).extension<AppSurfaces>()!;
        return AlertDialog(
          backgroundColor: surfaces.panelRaised,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            side: BorderSide(color: surfaces.lineSoft),
          ),
          title: Text(context.wp('Delete server?')),
          content: Text(
            context.wp(
              'Remove "{label}" from saved servers? This keeps the rest of your home screen intact.',
              args: <String, Object?>{'label': profile.effectiveLabel},
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.wp('Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(context.wp('Delete')),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    await controller.deleteServerProfile(profile);
    if (!mounted) {
      return;
    }
    showAppSnackBar(
      context,
      message: context.wp(
        'Removed "{label}".',
        args: <String, Object?>{'label': profile.effectiveLabel},
      ),
      tone: AppSnackBarTone.warning,
    );
  }

  Future<void> _moveProfile(ServerProfile profile, int offset) async {
    await controller.moveProfile(profile.id, offset);
  }

  Future<void> _refreshAll() async {
    for (final profile in controller.profiles) {
      await controller.refreshProbe(profile);
    }
    if (!mounted) {
      return;
    }
    showAppSnackBar(
      context,
      message: context.wp('Refreshed saved server status.'),
      tone: AppSnackBarTone.info,
    );
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final compactShell = MediaQuery.sizeOf(context).width < 620;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final profiles = controller.profiles;
        return AppGlassPanel(
          radius: AppSpacing.cardRadius,
          blur: 12,
          backgroundOpacity: 0.9,
          borderOpacity: 0.06,
          padding: EdgeInsets.all(compactShell ? AppSpacing.md : AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: surfaces.lineSoft,
                    borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
                  ),
                ),
              ),
              SizedBox(height: compactShell ? AppSpacing.sm : AppSpacing.md),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 620;
                  final titleBlock = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        context.wp('See Servers'),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        context.wp(
                          'Choose the active server, edit saved entries, reorder them, and keep connection status visible here.',
                        ),
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: surfaces.muted),
                      ),
                    ],
                  );
                  final actions = Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    alignment: WrapAlignment.end,
                    children: <Widget>[
                      OutlinedButton.icon(
                        onPressed: profiles.isEmpty ? null : _refreshAll,
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text(context.wp('Refresh')),
                      ),
                      FilledButton.icon(
                        key: const ValueKey<String>('servers-sheet-add-button'),
                        onPressed: _openServerEditor,
                        icon: const Icon(Icons.add_rounded),
                        label: Text(context.wp('Add Server')),
                      ),
                      IconButton(
                        tooltip: context.wp('Close'),
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  );
                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        titleBlock,
                        const SizedBox(height: AppSpacing.sm),
                        actions,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(child: titleBlock),
                      const SizedBox(width: AppSpacing.sm),
                      actions,
                    ],
                  );
                },
              ),
              SizedBox(height: compactShell ? AppSpacing.md : AppSpacing.lg),
              Expanded(
                child: profiles.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: surfaces.panelMuted.withValues(
                                  alpha: 0.92,
                                ),
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(color: surfaces.lineSoft),
                              ),
                              child: Icon(
                                Icons.storage_rounded,
                                size: 28,
                                color: surfaces.muted,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              context.wp('No saved servers yet.'),
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              context.wp(
                                'Add your first OpenCode server here and it will immediately be ready for project browsing.',
                              ),
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: surfaces.muted),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: profiles.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpacing.xs),
                        itemBuilder: (context, index) {
                          final profile = profiles[index];
                          final report = controller.reports[profile.storageKey];
                          final selected =
                              controller.selectedProfile?.id == profile.id;
                          return _ServerManagementCard(
                            key: ValueKey<String>(
                              'servers-sheet-card-${profile.id}',
                            ),
                            profile: profile,
                            report: report,
                            selected: selected,
                            isRefreshing: controller.isRefreshingProfile(
                              profile,
                            ),
                            canMoveUp: index > 0,
                            canMoveDown: index < profiles.length - 1,
                            onSelect: () => controller.selectProfile(profile),
                            onRefresh: () => controller.refreshProbe(profile),
                            onEdit: () => _openServerEditor(profile: profile),
                            onDelete: () => _confirmDelete(profile),
                            onMoveUp: index > 0
                                ? () => _moveProfile(profile, -1)
                                : null,
                            onMoveDown: index < profiles.length - 1
                                ? () => _moveProfile(profile, 1)
                                : null,
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ServerManagementCard extends StatelessWidget {
  const _ServerManagementCard({
    required this.profile,
    required this.report,
    required this.selected,
    required this.isRefreshing,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onSelect,
    required this.onRefresh,
    required this.onEdit,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
    this.keyNamespace = 'servers-sheet',
    this.footer,
    super.key,
  });

  final ServerProfile profile;
  final ServerProbeReport? report;
  final bool selected;
  final bool isRefreshing;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onSelect;
  final VoidCallback onRefresh;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final String keyNamespace;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final meta = _serverMetaItems(context, profile, report);
    final compactCard = MediaQuery.sizeOf(context).width < 620;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(AppSpacing.lg),
        child: Ink(
          decoration: appSoftCardDecoration(
            context,
            radius: AppSpacing.lg,
            tone: AppSurfaceTone.accent,
            muted: !selected,
            selected: selected,
            emphasized: selected,
          ),
          child: Padding(
            padding: EdgeInsets.all(
              compactCard ? AppSpacing.sm : AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: _StatusDot(report: report, busy: isRefreshing),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final compactBadges = constraints.maxWidth < 220;
                              final title = Text(
                                profile.effectiveLabel,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              );
                              final badges = Wrap(
                                spacing: AppSpacing.xs,
                                runSpacing: AppSpacing.xs,
                                children: <Widget>[
                                  _ServerStatusBadge(report: report),
                                  if (selected)
                                    _ServerMetaBadge(
                                      icon: Icons.check_circle_rounded,
                                      label: context.wp('Active'),
                                      tint: theme.colorScheme.primary,
                                    ),
                                ],
                              );
                              if (compactBadges) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    title,
                                    const SizedBox(height: AppSpacing.xxs),
                                    badges,
                                  ],
                                );
                              }
                              return Row(
                                children: <Widget>[
                                  Expanded(child: title),
                                  const SizedBox(width: AppSpacing.xs),
                                  badges,
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            profile.normalizedBaseUrl,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: surfaces.muted,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: meta
                      .map(
                        (item) => _ServerMetaBadge(
                          icon: item.icon,
                          label: item.label,
                          tint: item.tint,
                        ),
                      )
                      .toList(growable: false),
                ),
                if (footer != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  footer!,
                ],
                const SizedBox(height: AppSpacing.sm),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 560;
                    final actionButtons = <Widget>[
                      _ServerActionIconButton(
                        key: ValueKey<String>(
                          '$keyNamespace-refresh-${profile.id}',
                        ),
                        tooltip: context.wp('Refresh status'),
                        onPressed: isRefreshing ? null : onRefresh,
                        icon: isRefreshing
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.refresh_rounded, size: 18),
                      ),
                      _ServerActionIconButton(
                        key: ValueKey<String>(
                          '$keyNamespace-move-up-${profile.id}',
                        ),
                        tooltip: context.wp('Move up'),
                        onPressed: onMoveUp,
                        icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                      ),
                      _ServerActionIconButton(
                        key: ValueKey<String>(
                          '$keyNamespace-move-down-${profile.id}',
                        ),
                        tooltip: context.wp('Move down'),
                        onPressed: onMoveDown,
                        icon: const Icon(
                          Icons.arrow_downward_rounded,
                          size: 18,
                        ),
                      ),
                      _ServerActionIconButton(
                        key: ValueKey<String>(
                          '$keyNamespace-edit-${profile.id}',
                        ),
                        tooltip: context.wp('Edit server'),
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_outlined, size: 18),
                      ),
                      _ServerActionIconButton(
                        key: ValueKey<String>(
                          '$keyNamespace-delete-${profile.id}',
                        ),
                        tooltip: context.wp('Delete server'),
                        onPressed: onDelete,
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                        ),
                        destructive: true,
                      ),
                    ];
                    if (compact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          TextButton.icon(
                            key: ValueKey<String>(
                              '$keyNamespace-select-${profile.id}',
                            ),
                            onPressed: onSelect,
                            icon: Icon(
                              selected
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                            ),
                            label: Text(
                              selected
                                  ? context.wp('Selected')
                                  : context.wp('Use This Server'),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Wrap(
                              spacing: AppSpacing.xs,
                              children: actionButtons,
                            ),
                          ),
                        ],
                      );
                    }
                    return Row(
                      children: <Widget>[
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              key: ValueKey<String>(
                                '$keyNamespace-select-${profile.id}',
                              ),
                              onPressed: onSelect,
                              icon: Icon(
                                selected
                                    ? Icons.check_circle_rounded
                                    : Icons.radio_button_unchecked_rounded,
                              ),
                              label: Text(
                                selected
                                    ? context.wp('Selected')
                                    : context.wp('Use This Server'),
                              ),
                            ),
                          ),
                        ),
                        ...actionButtons,
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ServerEditorSheet extends StatefulWidget {
  const _ServerEditorSheet({this.initialProfile});

  final ServerProfile? initialProfile;

  @override
  State<_ServerEditorSheet> createState() => _ServerEditorSheetState();
}

class _ServerEditorSheetState extends State<_ServerEditorSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _labelController;
  late final TextEditingController _baseUrlController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    final profile = widget.initialProfile;
    _labelController = TextEditingController(text: profile?.label ?? '');
    _baseUrlController = TextEditingController(
      text: profile?.normalizedBaseUrl ?? '',
    );
    _usernameController = TextEditingController(text: profile?.username ?? '');
    _passwordController = TextEditingController(text: profile?.password ?? '');
  }

  @override
  void dispose() {
    _labelController.dispose();
    _baseUrlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final existing = widget.initialProfile;
    final profile = ServerProfile(
      id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      label: _labelController.text.trim(),
      baseUrl: _baseUrlController.text.trim(),
      username: _optionalValue(_usernameController.text),
      password: _optionalValue(_passwordController.text),
    );
    Navigator.of(context).pop(profile);
  }

  String? _optionalValue(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String? _validateAddress(String? value) {
    final draft = ServerProfile(id: 'draft', label: '', baseUrl: value ?? '');
    final uri = draft.uriOrNull;
    if (uri == null || uri.host.isEmpty) {
      return context.wp('Enter a valid server address.');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final editingExisting = widget.initialProfile != null;
    final compactSheet = MediaQuery.sizeOf(context).width < 560;
    return AppGlassPanel(
      radius: AppSpacing.cardRadius,
      blur: 12,
      backgroundOpacity: 0.9,
      borderOpacity: 0.06,
      padding: EdgeInsets.only(
        left: compactSheet ? AppSpacing.md : AppSpacing.lg,
        right: compactSheet ? AppSpacing.md : AppSpacing.lg,
        top: compactSheet ? AppSpacing.md : AppSpacing.lg,
        bottom:
            (compactSheet ? AppSpacing.md : AppSpacing.lg) +
            MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Form(
        key: _formKey,
        child: ListView(
          children: <Widget>[
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: surfaces.lineSoft,
                  borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              editingExisting
                  ? context.wp('Edit Server')
                  : context.wp('Add Server'),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              context.wp(
                'Save the server here and its status will be checked immediately.',
              ),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: surfaces.muted),
            ),
            SizedBox(height: compactSheet ? AppSpacing.md : AppSpacing.lg),
            Container(
              padding: EdgeInsets.all(
                compactSheet ? AppSpacing.sm : AppSpacing.md,
              ),
              decoration: appSoftCardDecoration(
                context,
                radius: AppSpacing.panelRadius,
                muted: true,
                emphasized: false,
              ),
              child: Column(
                children: <Widget>[
                  TextFormField(
                    key: const ValueKey<String>('servers-editor-label-field'),
                    controller: _labelController,
                    decoration: InputDecoration(
                      labelText: context.wp('Label'),
                      hintText: context.wp('Studio'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    key: const ValueKey<String>('servers-editor-url-field'),
                    controller: _baseUrlController,
                    keyboardType: TextInputType.url,
                    decoration: InputDecoration(
                      labelText: context.wp('Server URL'),
                      hintText: context.wp('https://studio.example.com'),
                    ),
                    validator: _validateAddress,
                  ),
                ],
              ),
            ),
            SizedBox(height: compactSheet ? AppSpacing.sm : AppSpacing.md),
            Container(
              padding: EdgeInsets.all(
                compactSheet ? AppSpacing.sm : AppSpacing.md,
              ),
              decoration: appSoftCardDecoration(
                context,
                radius: AppSpacing.panelRadius,
                muted: true,
                emphasized: false,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    context.wp('Optional credentials'),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    context.wp(
                      'Only add these when your server requires basic auth.',
                    ),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: surfaces.muted),
                  ),
                  SizedBox(
                    height: compactSheet ? AppSpacing.sm : AppSpacing.md,
                  ),
                  TextFormField(
                    key: const ValueKey<String>(
                      'servers-editor-username-field',
                    ),
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: context.wp('Username'),
                      hintText: context.wp('Optional'),
                    ),
                  ),
                  SizedBox(
                    height: compactSheet ? AppSpacing.sm : AppSpacing.md,
                  ),
                  TextFormField(
                    key: const ValueKey<String>(
                      'servers-editor-password-field',
                    ),
                    controller: _passwordController,
                    obscureText: !_showPassword,
                    decoration: InputDecoration(
                      labelText: context.wp('Password'),
                      hintText: context.wp('Optional'),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            _showPassword = !_showPassword;
                          });
                        },
                        icon: Icon(
                          _showPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: compactSheet ? AppSpacing.md : AppSpacing.lg),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 420;
                final cancelButton = OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(context.wp('Cancel')),
                );
                final saveButton = FilledButton.icon(
                  key: const ValueKey<String>('servers-editor-save-button'),
                  onPressed: _submit,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(
                    editingExisting
                        ? context.wp('Save Changes')
                        : context.wp('Save Server'),
                  ),
                );
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      saveButton,
                      const SizedBox(height: AppSpacing.sm),
                      cancelButton,
                    ],
                  );
                }
                return Row(
                  children: <Widget>[
                    Expanded(child: cancelButton),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: saveButton),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ServerMetaItem {
  const _ServerMetaItem({required this.icon, required this.label, this.tint});

  final IconData icon;
  final String label;
  final Color? tint;
}

class _ServerMetaBadge extends StatelessWidget {
  const _ServerMetaBadge({required this.icon, required this.label, this.tint});

  final IconData icon;
  final String label;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final accent = tint ?? surfaces.panelMuted;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
        border: Border.all(color: accent.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: accent),
          const SizedBox(width: AppSpacing.xxs),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ServerActionIconButton extends StatelessWidget {
  const _ServerActionIconButton({
    required this.tooltip,
    required this.onPressed,
    required this.icon,
    this.destructive = false,
    super.key,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final Widget icon;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final tint = destructive ? surfaces.danger : surfaces.muted;
    final enabled = onPressed != null;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            width: 40,
            height: 40,
            decoration: appSoftCardDecoration(
              context,
              radius: 14,
              tone: destructive
                  ? AppSurfaceTone.danger
                  : AppSurfaceTone.neutral,
              muted: !enabled,
              emphasized: enabled,
            ),
            child: IconTheme(
              data: IconThemeData(
                color: enabled ? tint : surfaces.muted.withValues(alpha: 0.5),
              ),
              child: Center(child: icon),
            ),
          ),
        ),
      ),
    );
  }
}

class _ServerStatusBadge extends StatelessWidget {
  const _ServerStatusBadge({required this.report});

  final ServerProbeReport? report;

  @override
  Widget build(BuildContext context) {
    return _ServerMetaBadge(
      icon: _statusIconData(report),
      label: _statusLabel(context, report),
      tint: _statusColor(context, report),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.report, this.busy = false});

  final ServerProbeReport? report;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(context, report);
    if (busy) {
      return SizedBox.square(
        dimension: 14,
        child: CircularProgressIndicator(
          strokeWidth: 2.2,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      );
    }
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

List<_ServerMetaItem> _serverMetaItems(
  BuildContext context,
  ServerProfile profile,
  ServerProbeReport? report,
) {
  final surfaces = Theme.of(context).extension<AppSurfaces>()!;
  final items = <_ServerMetaItem>[];
  final snapshotName = report?.snapshot.name.trim() ?? '';
  if (snapshotName.isNotEmpty &&
      snapshotName.toLowerCase() != profile.effectiveLabel.toLowerCase()) {
    items.add(
      _ServerMetaItem(
        icon: Icons.memory_rounded,
        label: snapshotName,
        tint: surfaces.accentSoft,
      ),
    );
  }
  final version = report?.snapshot.version.trim() ?? '';
  if (version.isNotEmpty && version.toLowerCase() != 'unknown') {
    items.add(
      _ServerMetaItem(
        icon: Icons.tag_rounded,
        label: context.wp(
          'v{version}',
          args: <String, Object?>{'version': version},
        ),
        tint: Theme.of(context).colorScheme.primary,
      ),
    );
  }
  final username = profile.username?.trim();
  if (username != null && username.isNotEmpty) {
    items.add(
      _ServerMetaItem(
        icon: Icons.person_outline_rounded,
        label: username,
        tint: surfaces.muted,
      ),
    );
  } else if (report?.requiresBasicAuth == true) {
    items.add(
      _ServerMetaItem(
        icon: Icons.lock_outline_rounded,
        label: context.wp('Basic Auth'),
        tint: Theme.of(context).colorScheme.secondary,
      ),
    );
  }
  if (report != null) {
    items.add(
      _ServerMetaItem(
        icon: Icons.schedule_rounded,
        label: _checkedAtLabel(context, report.checkedAt),
        tint: surfaces.muted,
      ),
    );
  } else {
    items.add(
      _ServerMetaItem(
        icon: Icons.schedule_rounded,
        label: context.wp('Not checked yet'),
        tint: surfaces.muted,
      ),
    );
  }
  return items;
}

String _statusLabel(BuildContext context, ServerProbeReport? report) {
  return switch (report?.classification) {
    ConnectionProbeClassification.ready => context.wp('Ready'),
    ConnectionProbeClassification.authFailure => context.wp('Sign In'),
    ConnectionProbeClassification.unsupportedCapabilities => context.wp(
      'Needs Update',
    ),
    ConnectionProbeClassification.specFetchFailure => context.wp('Unavailable'),
    ConnectionProbeClassification.connectivityFailure => context.wp('Offline'),
    null => context.wp('Unknown'),
  };
}

IconData _statusIconData(ServerProbeReport? report) {
  return switch (report?.classification) {
    ConnectionProbeClassification.ready => Icons.check_circle_rounded,
    ConnectionProbeClassification.authFailure => Icons.lock_outline_rounded,
    ConnectionProbeClassification.unsupportedCapabilities =>
      Icons.warning_amber_rounded,
    ConnectionProbeClassification.specFetchFailure =>
      Icons.error_outline_rounded,
    ConnectionProbeClassification.connectivityFailure => Icons.wifi_off_rounded,
    null => Icons.help_outline_rounded,
  };
}

Color _statusColor(BuildContext context, ServerProbeReport? report) {
  final surfaces = Theme.of(context).extension<AppSurfaces>()!;
  return switch (report?.classification) {
    ConnectionProbeClassification.ready => surfaces.success,
    ConnectionProbeClassification.authFailure => Theme.of(
      context,
    ).colorScheme.secondary,
    ConnectionProbeClassification.unsupportedCapabilities => surfaces.warning,
    ConnectionProbeClassification.specFetchFailure => surfaces.warning,
    ConnectionProbeClassification.connectivityFailure => surfaces.danger,
    null => surfaces.muted,
  };
}

String _statusTextForSession(BuildContext context, String? status) {
  final normalized = status?.trim().toLowerCase() ?? 'idle';
  return switch (normalized) {
    'running' => context.wp('Running'),
    'completed' => context.wp('Completed'),
    'error' => context.wp('Error'),
    'pending' => context.wp('Pending'),
    'queued' => context.wp('Queued'),
    'starting' => context.wp('Starting'),
    'steering' => context.wp('Steering'),
    'waiting' => context.wp('Waiting'),
    'idle' => context.wp('Idle'),
    _ =>
      normalized.isEmpty
          ? context.wp('Idle')
          : '${normalized[0].toUpperCase()}${normalized.substring(1)}',
  };
}

Color _sessionStatusTint(BuildContext context, String? status) {
  final surfaces = Theme.of(context).extension<AppSurfaces>()!;
  return switch (status?.trim().toLowerCase()) {
    'completed' => surfaces.success,
    'error' => surfaces.danger,
    'idle' => surfaces.muted,
    _ => Theme.of(context).colorScheme.primary,
  };
}

String _checkedAtLabel(BuildContext context, DateTime checkedAt) {
  final localizations = MaterialLocalizations.of(context);
  final time = TimeOfDay.fromDateTime(checkedAt);
  return context.wp(
    'Checked {time}',
    args: <String, Object?>{'time': localizations.formatTimeOfDay(time)},
  );
}
