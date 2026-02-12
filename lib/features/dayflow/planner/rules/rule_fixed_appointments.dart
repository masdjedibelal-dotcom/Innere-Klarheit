import '../day_block.dart';
import '../planning_item.dart';
import '../planner_rule.dart';
import '../planner_state.dart';

class FixedAppointmentRule implements PlannerRule {
  const FixedAppointmentRule();

  @override
  PlannerState apply(PlannerState state, List<DayBlock> blocks) {
    final assignments = _cloneAssignments(state.assignments);
    final remaining = <PlanningItem>[];

    for (final item in state.backlog) {
      if (item.type != PlanningType.appointment || item.fixedStart == null) {
        remaining.add(item);
        continue;
      }

      final target = _findBlockForTime(blocks, item.fixedStart!);
      if (target == null) {
        remaining.add(item);
        continue;
      }
      assignments.putIfAbsent(target.id, () => []).add(item);
    }

    return state.copyWith(
      backlog: remaining,
      assignments: assignments,
    );
  }

  DayBlock? _findBlockForTime(List<DayBlock> blocks, DateTime time) {
    for (final block in blocks) {
      final start = block.start;
      final end = block.end;
      if (start == null || end == null) continue;
      if (!time.isBefore(start) && time.isBefore(end)) {
        return block;
      }
    }
    for (final block in blocks) {
      if (block.type == DayBlockType.morningFixed) return block;
    }
    return blocks.isNotEmpty ? blocks.first : null;
  }

  Map<String, List<PlanningItem>> _cloneAssignments(
    Map<String, List<PlanningItem>> assignments,
  ) {
    return assignments.map((key, value) => MapEntry(key, List.of(value)));
  }
}

