import 'planning_item.dart';

class PlannerState {
  final List<PlanningItem> backlog;
  final Map<String, List<PlanningItem>> assignments;

  const PlannerState({
    required this.backlog,
    required this.assignments,
  });

  PlannerState copyWith({
    List<PlanningItem>? backlog,
    Map<String, List<PlanningItem>>? assignments,
  }) {
    return PlannerState(
      backlog: backlog ?? this.backlog,
      assignments: assignments ?? this.assignments,
    );
  }
}



