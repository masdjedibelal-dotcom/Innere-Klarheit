class MethodItem {
  final String id;
  final String blockId;
  final String title;
  final String shortDesc;
  final List<String> steps;
  final int durationMinutes;
  final String benefit;
  final List<String> pitfalls;
  final List<String> tags;

  const MethodItem({
    required this.id,
    required this.blockId,
    required this.title,
    required this.shortDesc,
    required this.steps,
    required this.durationMinutes,
    required this.benefit,
    required this.pitfalls,
    required this.tags,
  });
}
