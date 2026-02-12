class CatalogItem {
  final String id;
  final String title;
  final int sortRank;

  const CatalogItem({
    required this.id,
    required this.title,
    this.sortRank = 0,
  });
}

