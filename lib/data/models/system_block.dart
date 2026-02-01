class SystemBlock {
  final String id;
  final String key;
  final String title;
  final String desc;
  final List<String> outcomes;
  final String timeHint;
  final String icon;
  final int sortRank;
  final bool isActive;

  const SystemBlock({
    required this.id,
    required this.key,
    required this.title,
    required this.desc,
    required this.outcomes,
    required this.timeHint,
    required this.icon,
    this.sortRank = 0,
    this.isActive = false,
  });
}
