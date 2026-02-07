import '../day_block.dart';
import '../planning_item.dart';
import '../planner_rule.dart';
import '../planner_state.dart';

class BatchingRule implements PlannerRule {
  const BatchingRule();

  @override
  PlannerState apply(PlannerState state, List<DayBlock> blocks) {
    if (state.backlog.isEmpty) return state;
    final pomodoro = _findBlockByType(blocks, DayBlockType.pomodoro);
    final deepWork = _findBlockByType(blocks, DayBlockType.deepWork);
    if (pomodoro == null && deepWork == null) return state;

    final assignments = _cloneAssignments(state.assignments);
    final remaining = <PlanningItem>[];
    final todos = <PlanningItem>[];
    for (final item in state.backlog) {
      if (item.type == PlanningType.todo) {
        todos.add(item);
      } else {
        remaining.add(item);
      }
    }

    final deepWorkList =
        deepWork == null ? null : assignments.putIfAbsent(deepWork.id, () => []);
    final pomodoroList =
        pomodoro == null ? null : assignments.putIfAbsent(pomodoro.id, () => []);

    final prioritizedForDeepWork = <PlanningItem>[];
    for (final item in todos) {
      final area = item.area?.toLowerCase().trim() ?? '';
      if (area.contains('weiterentwicklung') || area.contains('business')) {
        prioritizedForDeepWork.add(item);
      }
    }
    todos.removeWhere(prioritizedForDeepWork.contains);
    if (deepWorkList != null && prioritizedForDeepWork.isNotEmpty) {
      deepWorkList.insertAll(0, prioritizedForDeepWork);
    }

    if (deepWorkList != null && deepWorkList.isEmpty) {
      final longHigh = todos
          .where((item) => item.priority == 1 && item.durationMin >= 60)
          .toList();
      todos.removeWhere(longHigh.contains);
      deepWorkList.addAll(longHigh);
    }

    if (pomodoroList != null && todos.isNotEmpty) {
      pomodoroList.addAll(_sortPomodoroTodos(todos));
    } else {
      remaining.addAll(todos);
    }

    return state.copyWith(
      backlog: remaining,
      assignments: assignments,
    );
  }

  List<PlanningItem> _sortPomodoroTodos(List<PlanningItem> items) {
    const shortLimit = 30;
    final short = <PlanningItem>[];
    final rest = <PlanningItem>[];
    for (final item in items) {
      if (item.durationMin > 0 && item.durationMin <= shortLimit) {
        short.add(item);
      } else {
        rest.add(item);
      }
    }
    short.sort((a, b) => a.priority.compareTo(b.priority));
    final high = rest.where((i) => i.priority == 1).toList();
    final medium = rest.where((i) => i.priority == 2).toList();
    final low = rest.where((i) => i.priority == 3).toList();
    return [
      ...short,
      ...high,
      ...medium,
      ...low,
    ];
  }

  DayBlock? _findBlockByType(List<DayBlock> blocks, DayBlockType type) {
    for (final block in blocks) {
      if (block.type == type) return block;
    }
    return null;
  }

  Map<String, List<PlanningItem>> _cloneAssignments(
    Map<String, List<PlanningItem>> assignments,
  ) {
    return assignments.map((key, value) => MapEntry(key, List.of(value)));
  }
}

