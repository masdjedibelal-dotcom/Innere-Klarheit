class MethodV2 {
  final String id;
  final String key;
  final String pillarKey;
  final String category;
  final String title;
  final String shortDesc;
  final List<String> examples;
  final List<String> steps;
  final int durationMinutes;
  final String benefit;
  final List<String> pitfalls;
  final List<String> impactTags;
  final List<String> contexts;
  final bool isActive;
  final int sortRank;

  const MethodV2({
    required this.id,
    required this.key,
    required this.pillarKey,
    required this.category,
    required this.title,
    required this.shortDesc,
    required this.examples,
    required this.steps,
    required this.durationMinutes,
    required this.benefit,
    required this.pitfalls,
    required this.impactTags,
    required this.contexts,
    required this.isActive,
    required this.sortRank,
  });
}


