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

  factory TodoItem.fromJson(Map<String, Object?> json) {
    return TodoItem(
      id: json['id']! as String,
      content: json['content']! as String,
      status: json['status']! as String,
      priority: (json['priority'] as String?) ?? 'medium',
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'content': content,
    'status': status,
    'priority': priority,
  };
}
