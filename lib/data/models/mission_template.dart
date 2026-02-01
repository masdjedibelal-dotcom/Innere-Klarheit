class MissionTemplate {
  final String id;
  final String key;
  final String template;
  final String tone;
  final int sortRank;
  final bool isActive;
  final DateTime createdAt;

  const MissionTemplate({
    required this.id,
    required this.key,
    required this.template,
    required this.tone,
    required this.sortRank,
    required this.isActive,
    required this.createdAt,
  });
}

