class IdentityPillar {
  final String id;
  final String title;
  final String desc;
  final List<String> reflectionQuestions;
  final int sortRank;
  final bool isActive;

  const IdentityPillar({
    required this.id,
    required this.title,
    required this.desc,
    required this.reflectionQuestions,
    this.sortRank = 0,
    this.isActive = false,
  });
}

