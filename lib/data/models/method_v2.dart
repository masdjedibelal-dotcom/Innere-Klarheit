class MethodV2 {
  final String id;
  final String key;
  final String pillarKey;
  final String methodLevel;
  final String blockRole;
  final bool defaultSelected;
  final String habitKey;
  final String habitContent;
  final String methodType;
  final String contentType;
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
    required this.methodLevel,
    required this.blockRole,
    required this.defaultSelected,
    required this.habitKey,
    required this.habitContent,
    required this.methodType,
    required this.contentType,
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

  MethodV2 copyWith({
    String? key,
    String? pillarKey,
    String? methodLevel,
    String? blockRole,
    bool? defaultSelected,
    String? habitKey,
    String? habitContent,
    String? methodType,
    String? contentType,
    String? category,
    String? title,
    String? shortDesc,
    List<String>? examples,
    List<String>? steps,
    int? durationMinutes,
    String? benefit,
    List<String>? pitfalls,
    List<String>? impactTags,
    List<String>? contexts,
    bool? isActive,
    int? sortRank,
  }) {
    return MethodV2(
      id: id,
      key: key ?? this.key,
      pillarKey: pillarKey ?? this.pillarKey,
      methodLevel: methodLevel ?? this.methodLevel,
      blockRole: blockRole ?? this.blockRole,
      defaultSelected: defaultSelected ?? this.defaultSelected,
      habitKey: habitKey ?? this.habitKey,
      habitContent: habitContent ?? this.habitContent,
      methodType: methodType ?? this.methodType,
      contentType: contentType ?? this.contentType,
      category: category ?? this.category,
      title: title ?? this.title,
      shortDesc: shortDesc ?? this.shortDesc,
      examples: examples ?? this.examples,
      steps: steps ?? this.steps,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      benefit: benefit ?? this.benefit,
      pitfalls: pitfalls ?? this.pitfalls,
      impactTags: impactTags ?? this.impactTags,
      contexts: contexts ?? this.contexts,
      isActive: isActive ?? this.isActive,
      sortRank: sortRank ?? this.sortRank,
    );
  }
}


