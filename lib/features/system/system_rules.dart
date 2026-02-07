import '../../data/models/method_v2.dart';
import '../../data/models/system_task.dart';
import '../../data/models/system_block.dart';

typedef SystemMethod = MethodV2;

List<SystemMethod> applyMetaHiddenRules({
  required List<SystemMethod> visibleMethods,
  required List<SystemMethod> metaHiddenMethods,
  required SystemBlock block,
  required DateTime date,
}) {
  final hiddenIds = metaHiddenMethods.map((m) => m.id).toSet();
  var filtered = visibleMethods.where((m) => !hiddenIds.contains(m.id)).toList();

  final metaKeys = metaHiddenMethods.map((m) => m.key).toSet();
  if (metaKeys.contains('eisenhower')) {
    filtered.sort((a, b) => b.sortRank.compareTo(a.sortRank));
  }
  if (metaKeys.contains('low_energy') && filtered.length > 3) {
    filtered = filtered.take(3).toList();
  }

  return filtered;
}

class TaskCreationDecision {
  final bool allowed;
  final String? hint;
  final String? redirectBlockKey;

  const TaskCreationDecision({
    required this.allowed,
    this.hint,
    this.redirectBlockKey,
  });

  const TaskCreationDecision.allowed() : this(allowed: true);

  const TaskCreationDecision.blocked(String hint)
      : this(allowed: false, hint: hint);

  const TaskCreationDecision.redirect({
    required String targetBlockKey,
    required String hint,
  }) : this(allowed: false, hint: hint, redirectBlockKey: targetBlockKey);
}

TaskCreationDecision validateTaskCreation({
  required List<SystemMethod> metaHiddenMethods,
  required SystemBlock block,
  required SystemMethod method,
  required DateTime date,
  required List<SystemTask> existingMethodTasks,
  required List<SystemTask> existingBlockTasks,
}) {
  final metaKeys = metaHiddenMethods.map((m) => m.key).toSet();
  final methodLevel = method.methodLevel.toLowerCase().trim();
  final blockKey = block.key.toLowerCase().trim();
  final timeHint = block.timeHint.toLowerCase().trim();

  if (method.blockRole == 'meta_hidden') {
    return const TaskCreationDecision.blocked(
      'Diese Methode ist gerade nicht verfügbar.',
    );
  }

  if (metaKeys.contains('chrono')) {
    final isMorningOrDeepWork =
        blockKey.contains('morning') || blockKey.contains('deep_work');
    final isLowEnergyOrAdmin =
        methodLevel == 'low_energy' || methodLevel == 'admin';
    if (isMorningOrDeepWork && isLowEnergyOrAdmin) {
      return const TaskCreationDecision.blocked(
        'Diese Aufgabe passt besser in den Nachmittag.',
      );
    }
  }

  final isEvening = blockKey.contains('evening') || timeHint.contains('abend');
  if (isEvening && methodLevel == 'output') {
    return const TaskCreationDecision.blocked(
      'Abends geht es ums Abschließen, nicht ums Starten.',
    );
  }

  if (blockKey.contains('deep_work')) {
    if (existingMethodTasks.length >= 1 || existingBlockTasks.length >= 3) {
      return const TaskCreationDecision.blocked(
        'Eine Fokusaufgabe reicht für diesen Block.',
      );
    }
  }

  if (blockKey.contains('deep_work') && _looksLikeAdminWork(method)) {
    return const TaskCreationDecision.redirect(
      targetBlockKey: 'midday',
      hint: 'Diese Aufgabe passt besser in den Mittags-Block.',
    );
  }

  if (metaKeys.contains('low_energy') && existingBlockTasks.length >= 3) {
    return const TaskCreationDecision.blocked(
      'Heute weniger Aufgaben – bleib bei maximal 3.',
    );
  }

  return const TaskCreationDecision.allowed();
}

bool _looksLikeAdminWork(SystemMethod method) {
  final level = method.methodLevel.toLowerCase().trim();
  if (level == 'admin' || level == 'light' || level == 'low_energy') {
    return true;
  }
  final title = method.title.toLowerCase();
  return title.contains('email') ||
      title.contains('mail') ||
      title.contains('inbox') ||
      title.contains('orga') ||
      title.contains('organisation') ||
      title.contains('routine');
}

