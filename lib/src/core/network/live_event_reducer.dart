import 'dart:convert';

class LiveEventState {
  const LiveEventState({
    this.connectionCount = 0,
    this.needsResync = false,
    this.sessionStatus = const {},
    this.messageParts = const {},
    this.todoItems = const {},
  });

  final int connectionCount;
  final bool needsResync;
  final Map<String, String> sessionStatus;
  final Map<String, String> messageParts;
  final Map<String, String> todoItems;

  LiveEventState copyWith({
    int? connectionCount,
    bool? needsResync,
    Map<String, String>? sessionStatus,
    Map<String, String>? messageParts,
    Map<String, String>? todoItems,
  }) {
    return LiveEventState(
      connectionCount: connectionCount ?? this.connectionCount,
      needsResync: needsResync ?? this.needsResync,
      sessionStatus: sessionStatus ?? this.sessionStatus,
      messageParts: messageParts ?? this.messageParts,
      todoItems: todoItems ?? this.todoItems,
    );
  }
}

class LiveEventReducer {
  LiveEventState _state = const LiveEventState();

  LiveEventState get state => _state;

  void apply(String eventType, String data) {
    final payload = data.isEmpty
        ? const <String, Object?>{}
        : jsonDecode(data) as Map<String, Object?>;
    switch (eventType) {
      case 'server.connected':
        _state = _state.copyWith(
          connectionCount: _state.connectionCount + 1,
          needsResync: false,
        );
      case 'session.status':
        final sessionId = payload['sessionID'] as String?;
        final status = payload['status'] as String?;
        if (sessionId != null && status != null) {
          final next = Map<String, String>.from(_state.sessionStatus)
            ..[sessionId] = status;
          _state = _state.copyWith(sessionStatus: next);
        }
      case 'message.part.updated':
        final partId = payload['partID'] as String?;
        final content = payload['content'] as String?;
        if (partId != null && content != null) {
          final next = Map<String, String>.from(_state.messageParts)
            ..[partId] = content;
          _state = _state.copyWith(messageParts: next);
        }
      case 'todo.updated':
        final todoId = payload['todoID'] as String?;
        final status = payload['status'] as String?;
        if (todoId != null && status != null) {
          final next = Map<String, String>.from(_state.todoItems)
            ..[todoId] = status;
          _state = _state.copyWith(todoItems: next);
        }
      case 'stream.resync_required':
        _state = _state.copyWith(needsResync: true);
    }
  }
}
