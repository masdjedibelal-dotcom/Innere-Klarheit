import 'day_block.dart';
import 'planner_state.dart';

abstract class PlannerRule {
  PlannerState apply(PlannerState state, List<DayBlock> blocks);
}



