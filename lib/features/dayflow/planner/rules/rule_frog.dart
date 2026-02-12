import '../day_block.dart';
import '../planning_item.dart';
import '../planner_rule.dart';
import '../planner_state.dart';

class FrogRule implements PlannerRule {
  const FrogRule();

  @override
  PlannerState apply(PlannerState state, List<DayBlock> blocks) {
    final index = state.backlog.indexWhere((item) => item.priority == 1);
    if (index == -1) return state;

    final target =
        _findBlockByType(blocks, DayBlockType.deepWork) ??
            _findBlockByType(blocks, DayBlockType.morningFixed);
    if (target == null) return state;

    final item = state.backlog[index];
    final nextBacklog = List<PlanningItem>.from(state.backlog)
      ..removeAt(index);
    final assignments = _cloneAssignments(state.assignments);
    final list = assignments.putIfAbsent(target.id, () => []);
    list.insert(0, item);

    return state.copyWith(
      backlog: nextBacklog,
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



