import '../day_block.dart';
import '../planning_item.dart';
import '../planner_rule.dart';
import '../planner_state.dart';

class ChronoRule implements PlannerRule {
  const ChronoRule();

  @override
  PlannerState apply(PlannerState state, List<DayBlock> blocks) {
    final deepWork = _findBlockByType(blocks, DayBlockType.deepWork);
    final pomodoro = _findBlockByType(blocks, DayBlockType.pomodoro);
    if (deepWork == null && pomodoro == null) return state;

    final assignments = _cloneAssignments(state.assignments);
    final remaining = <PlanningItem>[];

    for (final item in state.backlog) {
      if (item.priority == 2 && deepWork != null) {
        assignments.putIfAbsent(deepWork.id, () => []).add(item);
        continue;
      }
      if (item.priority == 3 && pomodoro != null) {
        assignments.putIfAbsent(pomodoro.id, () => []).add(item);
        continue;
      }
      remaining.add(item);
    }

    return state.copyWith(
      backlog: remaining,
      assignments: assignments,
    );
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



