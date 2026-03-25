import 'dart:async';
import 'dart:convert';

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

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final activeSession = _resolveActiveSession(sessions, activeSessionId);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1240),
          child: Container(
            height: 320,
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
    super.key,
  });

  final ServerProfile profile;
  final String directory;
  final PtyService service;
  final PtySessionInfo session;
  final void Function(String id, String title) onTitleChanged;
  final ValueChanged<String> onSessionMissing;

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
  });

  final ServerProfile profile;
  final String directory;
  final PtyService service;
  final List<PtySessionInfo> sessions;
  final String activeSessionId;
  final void Function(String id, String title) onTitleChanged;
  final ValueChanged<String> onSessionMissing;

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
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final statusTone = widget.session.isRunning
        ? Theme.of(context).colorScheme.primary
        : surfaces.muted;
    final connectionTone = _reconnecting
        ? Theme.of(context).colorScheme.primary
        : surfaces.warning;

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
                Wrap(
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
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: TerminalView(
              _terminal,
              controller: _terminalController,
              scrollController: _scrollController,
              autoResize: true,
              autofocus: true,
              backgroundOpacity: 1,
              theme: _buildTheme(context),
              textStyle: TerminalStyle(
                fontFamily: GoogleFonts.ibmPlexMono().fontFamily ?? 'Menlo',
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
