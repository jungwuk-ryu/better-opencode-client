enum PtySessionStatus { running, exited }

class PtySessionSize {
  const PtySessionSize({required this.cols, required this.rows});

  final int cols;
  final int rows;

  Map<String, Object?> toJson() => <String, Object?>{
    'cols': cols,
    'rows': rows,
  };
}

class PtySessionInfo {
  const PtySessionInfo({
    required this.id,
    required this.title,
    required this.command,
    required this.args,
    required this.cwd,
    required this.status,
    required this.pid,
  });

  final String id;
  final String title;
  final String command;
  final List<String> args;
  final String cwd;
  final PtySessionStatus status;
  final int pid;

  bool get isRunning => status == PtySessionStatus.running;

  PtySessionInfo copyWith({
    String? id,
    String? title,
    String? command,
    List<String>? args,
    String? cwd,
    PtySessionStatus? status,
    int? pid,
  }) {
    return PtySessionInfo(
      id: id ?? this.id,
      title: title ?? this.title,
      command: command ?? this.command,
      args: args ?? this.args,
      cwd: cwd ?? this.cwd,
      status: status ?? this.status,
      pid: pid ?? this.pid,
    );
  }

  factory PtySessionInfo.fromJson(Map<String, Object?> json) {
    final rawStatus = (json['status'] as String?) ?? 'running';
    return PtySessionInfo(
      id: (json['id'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      command: (json['command'] as String?) ?? '',
      args: ((json['args'] as List?) ?? const <Object?>[])
          .map((value) => value.toString())
          .toList(growable: false),
      cwd: (json['cwd'] as String?) ?? '',
      status: rawStatus == 'exited'
          ? PtySessionStatus.exited
          : PtySessionStatus.running,
      pid: (json['pid'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'title': title,
    'command': command,
    'args': args,
    'cwd': cwd,
    'status': status.name,
    'pid': pid,
  };
}

class PtyControlFrame {
  const PtyControlFrame({this.cursor});

  final int? cursor;

  factory PtyControlFrame.fromJson(Map<String, Object?> json) {
    return PtyControlFrame(cursor: (json['cursor'] as num?)?.toInt());
  }
}
