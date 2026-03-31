import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:xterm/xterm.dart';

import '../../core/connection/connection_models.dart';
import '../../design_system/app_spacing.dart';
import '../../design_system/app_theme.dart';
import 'pty_models.dart';
import 'pty_service.dart';

bool _showsTerminalSpecialKeyPalette(TargetPlatform platform) {
  return platform == TargetPlatform.android || platform == TargetPlatform.iOS;
}

void _triggerTerminalSpecialKeyHapticFeedback() {
  unawaited(HapticFeedback.selectionClick().catchError((_) {}));
}

class PtyTerminalPanel extends StatelessWidget {
  const PtyTerminalPanel({
    required this.profile,
    required this.directory,
    required this.service,
    required this.sessions,
    required this.activeSessionId,
    required this.loading,
    required this.creating,
    required this.error,
    required this.onSelectSession,
    required this.onCreateSession,
    required this.onCloseSession,
    required this.onRetry,
    required this.onTitleChanged,
    required this.onSessionMissing,
    this.expandToFill = false,
    this.onFocusChanged,
    super.key,
  });

  final ServerProfile profile;
  final String directory;
  final PtyService service;
  final List<PtySessionInfo> sessions;
  final String? activeSessionId;
  final bool loading;
  final bool creating;
  final String? error;
  final ValueChanged<String> onSelectSession;
  final VoidCallback onCreateSession;
  final ValueChanged<String> onCloseSession;
  final VoidCallback onRetry;
  final void Function(String id, String title) onTitleChanged;
  final ValueChanged<String> onSessionMissing;
  final bool expandToFill;
  final ValueChanged<bool>? onFocusChanged;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final activeSession = _resolveActiveSession(sessions, activeSessionId);
    const panelPadding = EdgeInsets.fromLTRB(
      AppSpacing.md,
      0,
      AppSpacing.md,
      AppSpacing.md,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight.isFinite
            ? math.max(0, constraints.maxHeight - panelPadding.vertical)
            : 320.0;
        final resolvedHeight =
            (expandToFill ? availableHeight : math.min(320.0, availableHeight))
                .toDouble();

        return Padding(
          key: const ValueKey<String>('pty-terminal-panel-root'),
          padding: panelPadding,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1240),
              child: SizedBox(
                key: const ValueKey<String>('pty-terminal-panel-frame'),
                height: resolvedHeight,
                child: Container(
                  decoration: BoxDecoration(
                    color: surfaces.panelRaised,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: surfaces.lineSoft),
                  ),
                  child: Column(
                    children: <Widget>[
                      _PtyPanelHeader(
                        sessions: sessions,
                        activeSessionId: activeSession?.id,
                        creating: creating,
                        onSelectSession: onSelectSession,
                        onCloseSession: onCloseSession,
                        onCreateSession: onCreateSession,
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(18),
                          ),
                          child: Builder(
                            builder: (context) {
                              if (loading && sessions.isEmpty) {
                                return _TerminalPlaceholder(
                                  title: 'Loading terminals...',
                                  subtitle: 'Fetching active PTY sessions.',
                                  busy: true,
                                );
                              }
                              if (error != null && sessions.isEmpty) {
                                return _TerminalPlaceholder(
                                  title: 'Terminal unavailable',
                                  subtitle: error!,
                                  actionLabel: 'Retry',
                                  onAction: onRetry,
                                );
                              }
                              if (activeSession == null) {
                                return _TerminalPlaceholder(
                                  title: creating
                                      ? 'Opening terminal...'
                                      : 'No terminal tabs yet',
                                  subtitle: creating
                                      ? 'Creating a new PTY session on the server.'
                                      : 'Create a terminal tab to interact with the remote shell.',
                                  busy: creating,
                                  actionLabel: creating ? null : 'New Terminal',
                                  onAction: creating ? null : onCreateSession,
                                );
                              }
                              return _PtyTerminalViewport(
                                profile: profile,
                                directory: directory,
                                service: service,
                                sessions: sessions,
                                activeSessionId: activeSession.id,
                                onTitleChanged: onTitleChanged,
                                onSessionMissing: onSessionMissing,
                                onFocusChanged: onFocusChanged,
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  PtySessionInfo? _resolveActiveSession(
    List<PtySessionInfo> items,
    String? activeId,
  ) {
    if (items.isEmpty) {
      return null;
    }
    if (activeId != null) {
      for (final session in items) {
        if (session.id == activeId) {
          return session;
        }
      }
    }
    return items.first;
  }
}

class _PtyPanelHeader extends StatelessWidget {
  const _PtyPanelHeader({
    required this.sessions,
    required this.activeSessionId,
    required this.creating,
    required this.onSelectSession,
    required this.onCloseSession,
    required this.onCreateSession,
  });

  final List<PtySessionInfo> sessions;
  final String? activeSessionId;
  final bool creating;
  final ValueChanged<String> onSelectSession;
  final ValueChanged<String> onCloseSession;
  final VoidCallback onCreateSession;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: surfaces.lineSoft)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: sessions.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
              itemBuilder: (context, index) {
                final session = sessions[index];
                final selected = session.id == activeSessionId;
                return _PtySessionTab(
                  session: session,
                  selected: selected,
                  onTap: () => onSelectSession(session.id),
                  onClose: () => onCloseSession(session.id),
                );
              },
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton(
            onPressed: creating ? null : onCreateSession,
            icon: creating
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_rounded),
            tooltip: 'New terminal',
          ),
        ],
      ),
    );
  }
}

class _PtySessionTab extends StatelessWidget {
  const _PtySessionTab({
    required this.session,
    required this.selected,
    required this.onTap,
    required this.onClose,
  });

  final PtySessionInfo session;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minWidth: 108, maxWidth: 240),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: selected
                ? colorScheme.primary.withValues(alpha: 0.14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? colorScheme.primary : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: session.isRunning
                      ? colorScheme.primary
                      : surfaces.muted,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  session.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              InkWell(
                onTap: onClose,
                borderRadius: BorderRadius.circular(999),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: selected ? null : surfaces.muted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TerminalPlaceholder extends StatelessWidget {
  const _TerminalPlaceholder({
    required this.title,
    required this.subtitle,
    this.busy = false,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String subtitle;
  final bool busy;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;

    return ColoredBox(
      color: surfaces.panel,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (busy)
                const Padding(
                  padding: EdgeInsets.only(bottom: AppSpacing.md),
                  child: CircularProgressIndicator(),
                ),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(
                subtitle,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: surfaces.muted),
                textAlign: TextAlign.center,
              ),
              if (actionLabel != null && onAction != null) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PtyTerminalView extends StatefulWidget {
  const _PtyTerminalView({
    required this.profile,
    required this.directory,
    required this.service,
    required this.session,
    required this.onTitleChanged,
    required this.onSessionMissing,
    this.onFocusChanged,
    super.key,
  });

  final ServerProfile profile;
  final String directory;
  final PtyService service;
  final PtySessionInfo session;
  final void Function(String id, String title) onTitleChanged;
  final ValueChanged<String> onSessionMissing;
  final ValueChanged<bool>? onFocusChanged;

  @override
  State<_PtyTerminalView> createState() => _PtyTerminalViewState();
}

class _PtyTerminalViewport extends StatefulWidget {
  const _PtyTerminalViewport({
    required this.profile,
    required this.directory,
    required this.service,
    required this.sessions,
    required this.activeSessionId,
    required this.onTitleChanged,
    required this.onSessionMissing,
    this.onFocusChanged,
  });

  final ServerProfile profile;
  final String directory;
  final PtyService service;
  final List<PtySessionInfo> sessions;
  final String activeSessionId;
  final void Function(String id, String title) onTitleChanged;
  final ValueChanged<String> onSessionMissing;
  final ValueChanged<bool>? onFocusChanged;

  @override
  State<_PtyTerminalViewport> createState() => _PtyTerminalViewportState();
}

class _PtyTerminalViewportState extends State<_PtyTerminalViewport> {
  final Set<String> _mountedSessionIds = <String>{};

  @override
  void initState() {
    super.initState();
    _mountedSessionIds.add(widget.activeSessionId);
  }

  @override
  void didUpdateWidget(covariant _PtyTerminalViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    _mountedSessionIds.add(widget.activeSessionId);
    final validIds = widget.sessions.map((session) => session.id).toSet();
    _mountedSessionIds.removeWhere(
      (sessionId) => !validIds.contains(sessionId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mountedSessions = widget.sessions
        .where((session) => _mountedSessionIds.contains(session.id))
        .toList(growable: false);
    final activeIndex = mountedSessions.indexWhere(
      (session) => session.id == widget.activeSessionId,
    );
    if (mountedSessions.isEmpty || activeIndex == -1) {
      return const SizedBox.shrink();
    }

    return IndexedStack(
      index: activeIndex,
      children: mountedSessions
          .map(
            (session) => _PtyTerminalView(
              key: ValueKey<String>('pty-${session.id}'),
              profile: widget.profile,
              directory: widget.directory,
              service: widget.service,
              session: session,
              onTitleChanged: widget.onTitleChanged,
              onSessionMissing: widget.onSessionMissing,
              onFocusChanged: session.id == widget.activeSessionId
                  ? widget.onFocusChanged
                  : null,
            ),
          )
          .toList(growable: false),
    );
  }
}

class _PtyTerminalViewState extends State<_PtyTerminalView> {
  late final Terminal _terminal;
  late final TerminalController _terminalController;
  late final ScrollController _scrollController;
  late final FocusNode _terminalFocusNode;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  Timer? _resizeDebounce;
  Timer? _titleDebounce;
  bool _disposed = false;
  bool _reconnecting = false;
  String? _connectionNotice;
  int _cursor = 0;
  int? _lastCols;
  int? _lastRows;
  bool _specialKeyPanelVisible = false;
  double _lastObservedKeyboardInset = 0;

  bool get _showsSpecialKeyPalette =>
      _showsTerminalSpecialKeyPalette(defaultTargetPlatform);

  @override
  void initState() {
    super.initState();
    _terminal = Terminal(
      maxLines: 10000,
      platform: _targetPlatform(),
      onOutput: _handleOutput,
      onResize: _handleResize,
      onTitleChange: _handleTitleChange,
    );
    _terminalController = TerminalController();
    _scrollController = ScrollController();
    _terminalFocusNode = FocusNode(
      debugLabel: 'pty-terminal-${widget.session.id}',
    )..addListener(_handleFocusChanged);
    unawaited(_connect(resetCursor: true));
  }

  @override
  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _resizeDebounce?.cancel();
    _titleDebounce?.cancel();
    unawaited(_disposeConnection());
    _scrollController.dispose();
    _terminalController.dispose();
    _terminalFocusNode
      ..removeListener(_handleFocusChanged)
      ..dispose();
    super.dispose();
  }

  void _handleFocusChanged() {
    widget.onFocusChanged?.call(_terminalFocusNode.hasFocus);
  }

  Future<void> _connect({required bool resetCursor}) async {
    await _disposeConnection();
    if (_disposed) {
      return;
    }
    if (resetCursor) {
      _cursor = 0;
    }

    final channel = widget.service.connectSession(
      profile: widget.profile,
      directory: widget.directory,
      ptyId: widget.session.id,
      cursor: _cursor,
    );
    _channel = channel;
    _subscription = channel.stream.listen(
      _handleSocketData,
      onDone: _handleSocketClosed,
      onError: (Object error, StackTrace stackTrace) {
        _scheduleReconnect('Terminal connection lost.');
      },
      cancelOnError: false,
    );

    if (mounted) {
      setState(() {
        _reconnecting = !resetCursor;
        _connectionNotice = resetCursor ? 'Connecting…' : 'Reconnecting…';
      });
    }

    try {
      await channel.ready;
      if (_disposed || _channel != channel || !mounted) {
        return;
      }
      setState(() {
        _reconnecting = false;
        _connectionNotice = null;
      });
      if (_lastCols != null && _lastRows != null) {
        unawaited(
          widget.service.updateSession(
            profile: widget.profile,
            directory: widget.directory,
            ptyId: widget.session.id,
            size: PtySessionSize(cols: _lastCols!, rows: _lastRows!),
          ),
        );
      }
    } catch (_) {
      _scheduleReconnect('Unable to connect to remote PTY.');
    }
  }

  Future<void> _disposeConnection() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
  }

  void _handleSocketData(dynamic event) {
    if (_disposed) {
      return;
    }

    if (event is String) {
      _terminal.write(event);
      _cursor += event.length;
      return;
    }

    if (event is List<int>) {
      if (event.isNotEmpty && event.first == 0) {
        final payload = utf8.decode(event.sublist(1), allowMalformed: true);
        final decoded = jsonDecode(payload) as Map<String, Object?>;
        final frame = PtyControlFrame.fromJson(decoded);
        final nextCursor = frame.cursor;
        if (nextCursor != null) {
          _cursor = nextCursor;
        }
        return;
      }
      final text = utf8.decode(event, allowMalformed: true);
      if (text.isEmpty) {
        return;
      }
      _terminal.write(text);
      _cursor += text.length;
    }
  }

  void _handleSocketClosed() {
    _scheduleReconnect('Terminal connection closed.');
  }

  void _scheduleReconnect(String message) {
    if (_disposed || _reconnectTimer != null) {
      return;
    }

    if (mounted) {
      setState(() {
        _reconnecting = true;
        _connectionNotice = message;
      });
    }

    _reconnectTimer = Timer(const Duration(milliseconds: 500), () async {
      _reconnectTimer = null;
      final session = await widget.service.getSession(
        profile: widget.profile,
        directory: widget.directory,
        ptyId: widget.session.id,
      );
      if (_disposed) {
        return;
      }
      if (session == null) {
        widget.onSessionMissing(widget.session.id);
        return;
      }
      unawaited(_connect(resetCursor: false));
    });
  }

  void _handleOutput(String data) {
    final channel = _channel;
    if (channel == null) {
      return;
    }
    try {
      channel.sink.add(data);
    } catch (_) {}
  }

  void _handleResize(int width, int height, int pixelWidth, int pixelHeight) {
    if (width <= 0 || height <= 0) {
      return;
    }
    if (_lastCols == width && _lastRows == height) {
      return;
    }
    _lastCols = width;
    _lastRows = height;

    _resizeDebounce?.cancel();
    _resizeDebounce = Timer(const Duration(milliseconds: 120), () async {
      try {
        await widget.service.updateSession(
          profile: widget.profile,
          directory: widget.directory,
          ptyId: widget.session.id,
          size: PtySessionSize(cols: width, rows: height),
        );
      } catch (_) {}
    });
  }

  void _handleTitleChange(String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      return;
    }
    _titleDebounce?.cancel();
    _titleDebounce = Timer(const Duration(milliseconds: 180), () {
      widget.onTitleChanged(widget.session.id, trimmed);
    });
  }

  TerminalTargetPlatform _targetPlatform() {
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => TerminalTargetPlatform.android,
      TargetPlatform.iOS => TerminalTargetPlatform.ios,
      TargetPlatform.fuchsia => TerminalTargetPlatform.fuchsia,
      TargetPlatform.linux => TerminalTargetPlatform.linux,
      TargetPlatform.macOS => TerminalTargetPlatform.macos,
      TargetPlatform.windows => TerminalTargetPlatform.windows,
    };
  }

  Future<void> _handleSecondaryTap() async {
    final selection = _terminalController.selection;
    if (selection != null) {
      final text = _terminal.buffer.getText(selection);
      _terminalController.clearSelection();
      if (text.isNotEmpty) {
        await Clipboard.setData(ClipboardData(text: text));
      }
      return;
    }
    final data = await Clipboard.getData('text/plain');
    final text = data?.text;
    if (text != null && text.isNotEmpty) {
      _terminal.paste(text);
    }
  }

  void _focusTerminal() {
    if (!_terminalFocusNode.hasFocus) {
      _terminalFocusNode.requestFocus();
    }
  }

  Future<void> _hideSystemKeyboard() {
    return SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  }

  Future<void> _showSystemKeyboard() {
    return SystemChannels.textInput.invokeMethod<void>('TextInput.show');
  }

  void _scrollTerminalToBottom() {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    if (!position.hasContentDimensions) {
      return;
    }
    _scrollController.jumpTo(position.maxScrollExtent);
  }

  void _sendSpecialTerminalKey(
    TerminalKey key, {
    bool ctrl = false,
    bool alt = false,
    bool shift = false,
  }) {
    _focusTerminal();
    final handled = _terminal.keyInput(key, ctrl: ctrl, alt: alt, shift: shift);
    if (!handled) {
      return;
    }
    _scrollTerminalToBottom();
    _triggerTerminalSpecialKeyHapticFeedback();
    if (_specialKeyPanelVisible) {
      unawaited(_hideSystemKeyboard());
    }
  }

  void _sendSpecialTerminalChar(
    String character, {
    bool ctrl = false,
    bool alt = false,
  }) {
    if (character.isEmpty) {
      return;
    }
    _focusTerminal();
    final handled = _terminal.charInput(
      character.codeUnitAt(0),
      ctrl: ctrl,
      alt: alt,
    );
    if (!handled) {
      if (alt) {
        _terminal.keyInput(TerminalKey.escape);
      }
      _terminal.textInput(character);
    }
    _scrollTerminalToBottom();
    _triggerTerminalSpecialKeyHapticFeedback();
    if (_specialKeyPanelVisible) {
      unawaited(_hideSystemKeyboard());
    }
  }

  List<_TerminalSpecialKeyAction> _commonSpecialKeyActions() {
    return <_TerminalSpecialKeyAction>[
      _TerminalSpecialKeyAction(
        id: 'esc',
        label: 'Esc',
        onPressed: () => _sendSpecialTerminalKey(TerminalKey.escape),
      ),
      _TerminalSpecialKeyAction(
        id: 'tab',
        label: 'Tab',
        onPressed: () => _sendSpecialTerminalKey(TerminalKey.tab),
      ),
      _TerminalSpecialKeyAction(
        id: 'ctrl-c',
        label: 'Ctrl+C',
        onPressed: () => _sendSpecialTerminalChar('c', ctrl: true),
      ),
      _TerminalSpecialKeyAction(
        id: 'ctrl-d',
        label: 'Ctrl+D',
        onPressed: () => _sendSpecialTerminalChar('d', ctrl: true),
      ),
      _TerminalSpecialKeyAction(
        id: 'ctrl-l',
        label: 'Ctrl+L',
        onPressed: () => _sendSpecialTerminalChar('l', ctrl: true),
      ),
      _TerminalSpecialKeyAction(
        id: 'ctrl-z',
        label: 'Ctrl+Z',
        onPressed: () => _sendSpecialTerminalChar('z', ctrl: true),
      ),
    ];
  }

  List<_TerminalSpecialKeyAction> _navigationSpecialKeyActions() {
    return <_TerminalSpecialKeyAction>[
      _TerminalSpecialKeyAction(
        id: 'up',
        label: 'Up',
        onPressed: () => _sendSpecialTerminalKey(TerminalKey.arrowUp),
      ),
      _TerminalSpecialKeyAction(
        id: 'down',
        label: 'Down',
        onPressed: () => _sendSpecialTerminalKey(TerminalKey.arrowDown),
      ),
      _TerminalSpecialKeyAction(
        id: 'left',
        label: 'Left',
        onPressed: () => _sendSpecialTerminalKey(TerminalKey.arrowLeft),
      ),
      _TerminalSpecialKeyAction(
        id: 'right',
        label: 'Right',
        onPressed: () => _sendSpecialTerminalKey(TerminalKey.arrowRight),
      ),
      _TerminalSpecialKeyAction(
        id: 'home',
        label: 'Home',
        onPressed: () => _sendSpecialTerminalKey(TerminalKey.home),
      ),
      _TerminalSpecialKeyAction(
        id: 'end',
        label: 'End',
        onPressed: () => _sendSpecialTerminalKey(TerminalKey.end),
      ),
      _TerminalSpecialKeyAction(
        id: 'page-up',
        label: 'PgUp',
        onPressed: () => _sendSpecialTerminalKey(TerminalKey.pageUp),
      ),
      _TerminalSpecialKeyAction(
        id: 'page-down',
        label: 'PgDn',
        onPressed: () => _sendSpecialTerminalKey(TerminalKey.pageDown),
      ),
      _TerminalSpecialKeyAction(
        id: 'insert',
        label: 'Ins',
        onPressed: () => _sendSpecialTerminalKey(TerminalKey.insert),
      ),
      _TerminalSpecialKeyAction(
        id: 'delete',
        label: 'Del',
        onPressed: () => _sendSpecialTerminalKey(TerminalKey.delete),
      ),
    ];
  }

  List<_TerminalSpecialKeyAction> _functionSpecialKeyActions() {
    return <_TerminalSpecialKeyAction>[
      _TerminalSpecialKeyAction(
        id: 'f1',
        label: 'F1',
        onPressed: () => _sendSpecialTerminalKey(TerminalKey.f1),
      ),
      _TerminalSpecialKeyAction(
        id: 'f2',
        label: 'F2',
        onPressed: () => _sendSpecialTerminalKey(TerminalKey.f2),
      ),
      _TerminalSpecialKeyAction(
        id: 'f3',
        label: 'F3',
        onPressed: () => _sendSpecialTerminalKey(TerminalKey.f3),
      ),
      _TerminalSpecialKeyAction(
        id: 'f4',
        label: 'F4',
        onPressed: () => _sendSpecialTerminalKey(TerminalKey.f4),
      ),
      _TerminalSpecialKeyAction(
        id: 'f5',
        label: 'F5',
        onPressed: () => _sendSpecialTerminalKey(TerminalKey.f5),
      ),
      _TerminalSpecialKeyAction(
        id: 'f6',
        label: 'F6',
        onPressed: () => _sendSpecialTerminalKey(TerminalKey.f6),
      ),
      _TerminalSpecialKeyAction(
        id: 'f7',
        label: 'F7',
        onPressed: () => _sendSpecialTerminalKey(TerminalKey.f7),
      ),
      _TerminalSpecialKeyAction(
        id: 'f8',
        label: 'F8',
        onPressed: () => _sendSpecialTerminalKey(TerminalKey.f8),
      ),
      _TerminalSpecialKeyAction(
        id: 'f9',
        label: 'F9',
        onPressed: () => _sendSpecialTerminalKey(TerminalKey.f9),
      ),
      _TerminalSpecialKeyAction(
        id: 'f10',
        label: 'F10',
        onPressed: () => _sendSpecialTerminalKey(TerminalKey.f10),
      ),
      _TerminalSpecialKeyAction(
        id: 'f11',
        label: 'F11',
        onPressed: () => _sendSpecialTerminalKey(TerminalKey.f11),
      ),
      _TerminalSpecialKeyAction(
        id: 'f12',
        label: 'F12',
        onPressed: () => _sendSpecialTerminalKey(TerminalKey.f12),
      ),
    ];
  }

  double _resolvedSpecialKeyPanelHeight(
    BuildContext context,
    BoxConstraints constraints,
  ) {
    final mediaQuery = MediaQuery.of(context);
    final desiredHeight =
        (_lastObservedKeyboardInset > 0
                ? _lastObservedKeyboardInset
                : math.min(mediaQuery.size.height * 0.34, 236.0))
            .toDouble();
    final maxAllowed = math.max(148.0, constraints.maxHeight - 88.0);
    return desiredHeight.clamp(148.0, maxAllowed);
  }

  Future<void> _toggleSpecialKeyPanel() async {
    if (!_showsSpecialKeyPalette) {
      return;
    }
    _focusTerminal();
    final nextVisible = !_specialKeyPanelVisible;
    setState(() {
      _specialKeyPanelVisible = nextVisible;
    });
    if (nextVisible) {
      await _hideSystemKeyboard();
    } else {
      await _showSystemKeyboard();
    }
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final statusTone = widget.session.isRunning
        ? Theme.of(context).colorScheme.primary
        : surfaces.muted;
    final connectionTone = _reconnecting
        ? Theme.of(context).colorScheme.primary
        : surfaces.warning;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    if (keyboardInset > 0) {
      _lastObservedKeyboardInset = keyboardInset;
    }

    return DecoratedBox(
      decoration: BoxDecoration(color: surfaces.panel),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.xs,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    widget.session.cwd,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: surfaces.muted,
                      fontFamily: GoogleFonts.ibmPlexMono().fontFamily,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        if (_connectionNotice != null)
                          _TerminalStatusChip(
                            label: _connectionNotice!,
                            tone: connectionTone,
                          ),
                        _TerminalStatusChip(
                          label: widget.session.isRunning ? 'live' : 'exited',
                          tone: statusTone,
                        ),
                        if (_showsSpecialKeyPalette)
                          _TerminalSpecialKeyPaletteButton(
                            active: _specialKeyPanelVisible,
                            onTap: () => unawaited(_toggleSpecialKeyPanel()),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final specialPanelHeight = _resolvedSpecialKeyPanelHeight(
                  context,
                  constraints,
                );
                return Column(
                  children: <Widget>[
                    Expanded(
                      child: Listener(
                        behavior: HitTestBehavior.translucent,
                        onPointerDown: (_) {
                          if (!_specialKeyPanelVisible || !mounted) {
                            return;
                          }
                          setState(() {
                            _specialKeyPanelVisible = false;
                          });
                          unawaited(_showSystemKeyboard());
                        },
                        child: TerminalView(
                          _terminal,
                          controller: _terminalController,
                          scrollController: _scrollController,
                          autoResize: true,
                          autofocus: true,
                          focusNode: _terminalFocusNode,
                          backgroundOpacity: 1,
                          theme: _buildTheme(context),
                          textStyle: TerminalStyle(
                            fontFamily:
                                GoogleFonts.ibmPlexMono().fontFamily ?? 'Menlo',
                            fontFamilyFallback: const <String>[
                              'Menlo',
                              'Monaco',
                              'Consolas',
                              'Courier New',
                              'monospace',
                            ],
                            fontSize: 13,
                            height: 1.25,
                          ),
                          onSecondaryTapDown: (details, offset) {
                            unawaited(_handleSecondaryTap());
                          },
                        ),
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SizeTransition(
                            sizeFactor: animation,
                            axisAlignment: 1,
                            child: child,
                          ),
                        );
                      },
                      child: _showsSpecialKeyPalette && _specialKeyPanelVisible
                          ? _InlineTerminalSpecialKeyPanel(
                              key: const ValueKey<String>(
                                'pty-terminal-special-keys-panel',
                              ),
                              height: specialPanelHeight,
                              commonActions: _commonSpecialKeyActions(),
                              navigationActions: _navigationSpecialKeyActions(),
                              functionActions: _functionSpecialKeyActions(),
                              onClose: () =>
                                  unawaited(_toggleSpecialKeyPanel()),
                            )
                          : const SizedBox.shrink(
                              key: ValueKey<String>(
                                'pty-terminal-special-keys-hidden',
                              ),
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  TerminalTheme _buildTheme(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    return TerminalTheme(
      cursor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.9),
      selection: Theme.of(context).colorScheme.primary.withValues(alpha: 0.28),
      foreground: const Color(0xFFE8EAED),
      background: surfaces.panel,
      black: const Color(0xFF0D0E10),
      red: const Color(0xFFE57373),
      green: const Color(0xFF7ADCD3),
      yellow: const Color(0xFFE2BF76),
      blue: const Color(0xFF69A6FF),
      magenta: const Color(0xFFCA9EFF),
      cyan: const Color(0xFF57D6FF),
      white: const Color(0xFFE8EAED),
      brightBlack: const Color(0xFF5D6773),
      brightRed: const Color(0xFFF28B82),
      brightGreen: const Color(0xFF8FE3C8),
      brightYellow: const Color(0xFFF4D58D),
      brightBlue: const Color(0xFF8AB4F8),
      brightMagenta: const Color(0xFFD7AEFB),
      brightCyan: const Color(0xFF80DEEA),
      brightWhite: const Color(0xFFFFFFFF),
      searchHitBackground: Theme.of(
        context,
      ).colorScheme.primary.withValues(alpha: 0.22),
      searchHitBackgroundCurrent: Theme.of(
        context,
      ).colorScheme.primary.withValues(alpha: 0.38),
      searchHitForeground: const Color(0xFF0D0E10),
    );
  }
}

class _TerminalStatusChip extends StatelessWidget {
  const _TerminalStatusChip({required this.label, required this.tone});

  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tone.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: tone),
      ),
    );
  }
}

class _TerminalSpecialKeyAction {
  const _TerminalSpecialKeyAction({
    required this.id,
    required this.label,
    required this.onPressed,
  });

  final String id;
  final String label;
  final VoidCallback onPressed;
}

class _TerminalSpecialKeySection extends StatelessWidget {
  const _TerminalSpecialKeySection({
    required this.title,
    required this.actions,
  });

  final String title;
  final List<_TerminalSpecialKeyAction> actions;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: surfaces.muted),
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: actions
              .map((action) => _TerminalSpecialKeyButton(action: action))
              .toList(growable: false),
        ),
      ],
    );
  }
}

class _InlineTerminalSpecialKeyPanel extends StatelessWidget {
  const _InlineTerminalSpecialKeyPanel({
    required this.height,
    required this.commonActions,
    required this.navigationActions,
    required this.functionActions,
    required this.onClose,
    super.key,
  });

  final double height;
  final List<_TerminalSpecialKeyAction> commonActions;
  final List<_TerminalSpecialKeyAction> navigationActions;
  final List<_TerminalSpecialKeyAction> functionActions;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;

    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: surfaces.panelRaised,
        border: Border(top: BorderSide(color: surfaces.lineSoft)),
      ),
      child: SingleChildScrollView(
        key: const ValueKey<String>('pty-terminal-special-keys-scroll'),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Terminal keys', style: theme.textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        'Use touch controls for function keys, navigation keys, and common control shortcuts.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: surfaces.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                IconButton(
                  key: const ValueKey<String>(
                    'pty-terminal-special-keys-close',
                  ),
                  onPressed: onClose,
                  icon: const Icon(Icons.keyboard_hide_rounded),
                  tooltip: 'Return to keyboard',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _TerminalSpecialKeySection(title: 'Common', actions: commonActions),
            const SizedBox(height: AppSpacing.md),
            _TerminalSpecialKeySection(
              title: 'Navigation',
              actions: navigationActions,
            ),
            const SizedBox(height: AppSpacing.md),
            _TerminalSpecialKeySection(
              title: 'Function keys',
              actions: functionActions,
            ),
          ],
        ),
      ),
    );
  }
}

class _TerminalSpecialKeyButton extends StatelessWidget {
  const _TerminalSpecialKeyButton({required this.action});

  final _TerminalSpecialKeyAction action;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    return OutlinedButton(
      key: ValueKey<String>('pty-terminal-special-key-${action.id}'),
      onPressed: action.onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        side: BorderSide(color: surfaces.lineSoft),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(action.label),
    );
  }
}

class _TerminalSpecialKeyPaletteButton extends StatelessWidget {
  const _TerminalSpecialKeyPaletteButton({
    required this.onTap,
    this.active = false,
  });

  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Material(
      color: colorScheme.primary.withValues(alpha: active ? 0.22 : 0.14),
      borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
      child: InkWell(
        key: const ValueKey<String>('pty-terminal-special-keys-button'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 6,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.keyboard_command_key_rounded,
                size: 16,
                color: colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.xxs),
              Text(
                'Keys',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
