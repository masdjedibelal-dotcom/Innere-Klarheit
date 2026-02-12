class InnerCatalogDetail {
  final String id;
  final String key;
  final String title;
  final String description;
  final List<String> examples;
  final List<String> useCases;
  final String reflectionQuestion;
  final List<String> reflectionQuestions;
  final String protectionFunction;
  final String shadowSide;
  final String reframe;
  final List<String> helpsWith;
  final List<String> watchOutFor;
  final int sortRank;
  final bool isActive;

  const InnerCatalogDetail({
    required this.id,
    required this.key,
    required this.title,
    required this.description,
    required this.examples,
    required this.useCases,
    required this.reflectionQuestion,
    required this.reflectionQuestions,
    required this.protectionFunction,
    required this.shadowSide,
    required this.reframe,
    required this.helpsWith,
    required this.watchOutFor,
    this.sortRank = 0,
    this.isActive = false,
  });
}

