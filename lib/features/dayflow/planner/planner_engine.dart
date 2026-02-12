import 'day_block.dart';
import 'planning_item.dart';
import 'planner_rule.dart';
import 'planner_state.dart';

class PlannerEngine {
  final List<PlannerRule> rules;

  const PlannerEngine(this.rules);

  PlannerState plan({
    required List<PlanningItem> items,
    required List<DayBlock> blocks,
  }) {
    var state = PlannerState(
      backlog: List<PlanningItem>.from(items),
      assignments: {},
    );
    for (final rule in rules) {
      state = rule.apply(state, blocks);
    }
    return state;
  }
}



