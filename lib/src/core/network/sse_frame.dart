class SseFrame {
  const SseFrame({this.event, this.id, this.data = ''});

  final String? event;
  final String? id;
  final String data;
}
