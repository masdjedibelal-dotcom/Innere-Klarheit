enum DayBlockType {
  morningFixed,
  deepWork,
  pomodoro,
  middayFixed,
  eveningFixed,
  appointments,
  personalFocus,
}

class DayBlock {
  final String id;
  final DayBlockType type;
  final bool fixed;
  final DateTime? start;
  final DateTime? end;
  final String? outcome;

  const DayBlock({
    required this.id,
    required this.type,
    required this.fixed,
    required this.start,
    required this.end,
    this.outcome,
  });
}

