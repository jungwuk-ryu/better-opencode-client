class TodoItem {
  const TodoItem({
    required this.id,
    required this.content,
    required this.status,
    required this.priority,
  });

  final String id;
  final String content;
  final String status;
  final String priority;

  factory TodoItem.fromJson(Map<String, Object?> json, {String? fallbackId}) {
    final content = json['content']?.toString().trim();
    final status = json['status']?.toString().trim();
    final priority = json['priority']?.toString().trim();
    final id = json['id']?.toString().trim();
    if (content == null || content.isEmpty) {
      throw const FormatException('Todo content is required.');
    }
    if (status == null || status.isEmpty) {
      throw const FormatException('Todo status is required.');
    }
    return TodoItem(
      id: id != null && id.isNotEmpty
          ? id
          : (fallbackId ?? _fallbackTodoId(json)),
      content: content,
      status: status,
      priority: priority == null || priority.isEmpty ? 'medium' : priority,
    );
  }

  static TodoItem? tryFromJson(
    Map<String, Object?> json, {
    String? fallbackId,
  }) {
    try {
      return TodoItem.fromJson(json, fallbackId: fallbackId);
    } catch (_) {
      return null;
    }
  }

  static List<TodoItem> listFromJson(List<dynamic> items) {
    final todos = <TodoItem>[];
    for (var index = 0; index < items.length; index += 1) {
      final item = items[index];
      if (item is! Map) {
        continue;
      }
      final parsed = TodoItem.tryFromJson(
        item.cast<String, Object?>(),
        fallbackId: _fallbackTodoId(item.cast<String, Object?>(), index: index),
      );
      if (parsed != null) {
        todos.add(parsed);
      }
    }
    return List<TodoItem>.unmodifiable(todos);
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'content': content,
    'status': status,
    'priority': priority,
  };
}

String _fallbackTodoId(Map<String, Object?> json, {int? index}) {
  final content = json['content']?.toString().trim().toLowerCase() ?? 'todo';
  final sanitized = content
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  final suffix = sanitized.isEmpty ? 'todo' : sanitized;
  if (index == null) {
    return 'todo_$suffix';
  }
  return 'todo_${index}_$suffix';
}
