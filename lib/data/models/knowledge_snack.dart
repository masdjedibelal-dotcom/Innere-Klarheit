class KnowledgeSnack {
  final String id;
  final String title;
  final String preview;
  final String content;
  final List<String> tags;
  final int readTimeMinutes;
  final int sortRank;
  final bool isPublished;
  final DateTime createdAt;

  const KnowledgeSnack({
    required this.id,
    required this.title,
    required this.preview,
    required this.content,
    required this.tags,
    required this.readTimeMinutes,
    this.sortRank = 0,
    this.isPublished = false,
    required this.createdAt,
  });
}
