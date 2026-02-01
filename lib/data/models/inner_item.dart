enum InnerType { staerken, persoenlichkeit, werte, antreiber }

class InnerItem {
  final String id;
  final InnerType type;
  final String title;
  final String shortDesc;
  final String longDesc;
  final List<String> questions;
  final List<String> pitfalls;
  final List<String> tags;
  final int sortRank;
  final bool isActive;

  const InnerItem({
    required this.id,
    required this.type,
    required this.title,
    required this.shortDesc,
    required this.longDesc,
    required this.questions,
    required this.pitfalls,
    required this.tags,
    this.sortRank = 0,
    this.isActive = false,
  });
}
