import '../../data/models/method_v2.dart';

const _systemLogicKeys = <String>{
  'eisenhower',
  'chrono',
  'eat_the_frog',
  'one_three_five',
  'batching',
  'pomodoro',
  'definition_of_done',
  'outcome',
};

const _habitDefinitions = <_HabitDefinition>[
  _HabitDefinition(
    key: 'journaling',
    keywords: ['journaling', 'journal', 'tagebuch', 'reflexion'],
  ),
  _HabitDefinition(
    key: 'movement',
    keywords: ['bewegung', 'sport', 'training', 'movement', 'walk', 'laufen'],
  ),
  _HabitDefinition(
    key: 'hydration',
    keywords: ['trinken', 'wasser', 'hydration', 'drink'],
  ),
  _HabitDefinition(
    key: 'planning',
    keywords: ['tag planen', 'planung', 'plan', 'tagesplanung'],
  ),
  _HabitDefinition(
    key: 'nutrition',
    keywords: ['ernährung', 'essen', 'nutrition', 'meal'],
  ),
  _HabitDefinition(
    key: 'pause_reset',
    keywords: ['pause', 'reset', 'break', 'recovery'],
  ),
  _HabitDefinition(
    key: 'reflection',
    keywords: ['reflexion', 'review', 'rückblick'],
  ),
  _HabitDefinition(
    key: 'learning',
    keywords: ['lernen', 'learning', 'study'],
  ),
  _HabitDefinition(
    key: 'wind_down',
    keywords: ['runterfahren', 'abschalten', 'abend', 'shutdown'],
  ),
];

class _HabitDefinition {
  const _HabitDefinition({
    required this.key,
    required this.keywords,
  });

  final String key;
  final List<String> keywords;
}

bool isSystemLogicMethod(MethodV2 method) {
  return _systemLogicKeys.contains(method.key.trim().toLowerCase());
}

bool isHabitMethod(MethodV2 method) {
  if (method.methodType.trim().isNotEmpty) {
    return method.methodType.trim().toLowerCase() == 'habit';
  }
  return habitKeyForMethod(method) != null;
}

bool isPlanningHabit(MethodV2 method) {
  return habitKeyForMethod(method) == 'planning';
}

String? habitKeyForMethod(MethodV2 method) {
  final explicit = method.habitKey.trim().toLowerCase();
  if (explicit.isNotEmpty) return explicit;
  final text = _methodText(method);
  for (final habit in _habitDefinitions) {
    for (final keyword in habit.keywords) {
      if (text.contains(keyword)) return habit.key;
    }
  }
  return null;
}

Map<String, List<MethodV2>> groupHabitContent(List<MethodV2> methods) {
  final map = <String, List<MethodV2>>{};
  for (final method in methods) {
    if (method.blockRole == 'meta_hidden') continue;
    if (isSystemLogicMethod(method)) continue;
    if (isHabitMethod(method)) continue;
    final habitKey = habitKeyForMethod(method);
    if (habitKey == null) continue;
    map.putIfAbsent(habitKey, () => []).add(method);
  }
  for (final entry in map.entries) {
    entry.value.sort((a, b) => a.sortRank.compareTo(b.sortRank));
  }
  return map;
}

String _methodText(MethodV2 method) {
  final buffer = StringBuffer();
  buffer.write(method.key.toLowerCase());
  buffer.write(' ');
  buffer.write(method.title.toLowerCase());
  if (method.shortDesc.isNotEmpty) {
    buffer.write(' ');
    buffer.write(method.shortDesc.toLowerCase());
  }
  return buffer.toString();
}


