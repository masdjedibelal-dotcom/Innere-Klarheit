enum PlanningType { appointment, todo, personal }

class PlanningItem {
  final String id;
  final String title;
  final String? description;
  final PlanningType type;
  final int durationMin;
  final int priority;
  final String? area;
  final DateTime? fixedStart;

  const PlanningItem({
    required this.id,
    required this.title,
    this.description,
    required this.type,
    required this.durationMin,
    required this.priority,
    required this.area,
    required this.fixedStart,
  });
}



