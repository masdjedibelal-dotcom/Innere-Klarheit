import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/system_task.dart';

final systemTasksProvider =
    StateNotifierProvider<SystemTasksNotifier, List<SystemTask>>(
  (ref) => SystemTasksNotifier(),
);

class SystemTasksNotifier extends StateNotifier<List<SystemTask>> {
  SystemTasksNotifier() : super(const []);

  void addTask(SystemTask task) {
    state = [...state, task];
  }

  void toggleTask(String taskId) {
    state = [
      for (final task in state)
        if (task.id == taskId)
          task.copyWith(completed: !task.completed)
        else
          task,
    ];
  }
}



