class IdentityRole {
  final String id;
  final String domain;
  final String title;
  final String desc;
  final List<String> tags;
  final int sortRank;
  final bool isActive;

  const IdentityRole({
    required this.id,
    required this.domain,
    required this.title,
    required this.desc,
    required this.tags,
    this.sortRank = 0,
    this.isActive = false,
  });
}
