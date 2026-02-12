import '../planning_item.dart';
import '../planner_rule.dart';
import '../planner_state.dart';
import '../day_block.dart';

class Limit135Rule implements PlannerRule {
  const Limit135Rule();

  @override
  PlannerState apply(PlannerState state, List<DayBlock> blocks) {
    final high = <PlanningItem>[];
    final medium = <PlanningItem>[];
    final low = <PlanningItem>[];
    final keep = <PlanningItem>[];

    for (final item in state.backlog) {
      switch (item.priority) {
        case 1:
          if (high.length < 1) {
            high.add(item);
            keep.add(item);
          }
          break;
        case 2:
          if (medium.length < 3) {
            medium.add(item);
            keep.add(item);
          }
          break;
        case 3:
          if (low.length < 5) {
            low.add(item);
            keep.add(item);
          }
          break;
        default:
          keep.add(item);
      }
    }

    return state.copyWith(backlog: keep);
  }
}



