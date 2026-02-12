class SystemTask {
  final String id;
  final String title;
  final DateTime date;
  final String blockKey;
  final String methodId;
  final bool completed;

  const SystemTask({
    required this.id,
    required this.title,
    required this.date,
    required this.blockKey,
    required this.methodId,
    required this.completed,
  });

  SystemTask copyWith({
    String? title,
    DateTime? date,
    String? blockKey,
    String? methodId,
    bool? completed,
  }) {
    return SystemTask(
      id: id,
      title: title ?? this.title,
      date: date ?? this.date,
      blockKey: blockKey ?? this.blockKey,
      methodId: methodId ?? this.methodId,
      completed: completed ?? this.completed,
    );
  }
}



