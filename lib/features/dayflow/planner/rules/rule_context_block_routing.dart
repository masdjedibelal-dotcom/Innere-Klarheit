import '../day_block.dart';
import '../planning_item.dart';
import '../planner_rule.dart';
import '../planner_state.dart';

class ContextBlockRoutingRule implements PlannerRule {
  const ContextBlockRoutingRule();

  @override
  PlannerState apply(PlannerState state, List<DayBlock> blocks) {
    final appointmentsBlock =
        _findBlockByType(blocks, DayBlockType.appointments) ??
            _findBlockByType(blocks, DayBlockType.morningFixed);
    final personalBlock =
        _findBlockByType(blocks, DayBlockType.personalFocus);
    final deepWorkBlock =
        _findBlockByType(blocks, DayBlockType.deepWork) ??
            _findBlockByType(blocks, DayBlockType.morningFixed);
    if (appointmentsBlock == null &&
        personalBlock == null &&
        deepWorkBlock == null) {
      return state;
    }

    final assignments = _cloneAssignments(state.assignments);
    final remaining = <PlanningItem>[];

    for (final item in state.backlog) {
      if (item.type == PlanningType.appointment &&
          appointmentsBlock != null) {
        assignments
            .putIfAbsent(appointmentsBlock.id, () => [])
            .add(item);
        continue;
      }
      final area = item.area?.toLowerCase().trim() ?? '';
      final isDevelopment = area.contains('entwicklung');
      final isBusiness = area.contains('business');
      if ((isDevelopment || isBusiness) && deepWorkBlock != null) {
        final list = assignments.putIfAbsent(deepWorkBlock.id, () => []);
        list.insert(0, item);
        continue;
      }
      if (item.type == PlanningType.personal && personalBlock != null) {
        assignments.putIfAbsent(personalBlock.id, () => []).add(item);
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

