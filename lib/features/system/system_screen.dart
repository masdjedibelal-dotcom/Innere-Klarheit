import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/bottom_sheet/bottom_card_sheet.dart';
import '../../widgets/bottom_sheet/habit_sheet.dart';
import '../../widgets/common/editorial_card.dart';
import '../../widgets/common/tag_chip.dart';
import '../../ui/components/screen_hero.dart';
import '../../state/user_state.dart';
import '../../state/system_tasks_state.dart';
import '../../data/models/method_day_block.dart';
import '../../data/models/method_v2.dart';
import '../../data/models/system_block.dart';
import '../../data/models/system_task.dart';
import 'system_habits.dart';
import 'system_rules.dart';
import '../dayflow/planner/day_block.dart';
import '../dayflow/planner/planner_engine.dart';
import '../dayflow/planner/planning_item.dart';
import '../dayflow/planner/rules/rule_batching.dart';
import '../dayflow/planner/rules/rule_chrono.dart';
import '../dayflow/planner/rules/rule_context_block_routing.dart';
import '../dayflow/planner/rules/rule_fixed_appointments.dart';
import '../dayflow/planner/rules/rule_frog.dart';
import '../dayflow/planner/rules/rule_limit_135.dart';

class SystemScreen extends ConsumerStatefulWidget {
  const SystemScreen({super.key});

  @override
  ConsumerState<SystemScreen> createState() => _SystemScreenState();
}

class _SystemScreenState extends ConsumerState<SystemScreen> {
  static const _defaultBlockKeys = {
    'morning_reset',
    'deep_work',
    'work_pomodoro',
    'evening_shutdown',
  };
  static const _appointmentsBlockId = 'appointments_block';
  static const _fixedHabitBlockKeys = [
    'morning_reset',
    'midday_reset',
    'evening_shutdown',
  ];

  DateTime _selectedDate = DateTime.now();
  final List<String> _activeBlockIds = [];
  final List<String> _fixedBlockIds = [];
  final List<String> _orderedBlockIds = [];
  final List<String> _reorderableIds = [];
  final List<PlanningItem> _planningItems = [];
  Map<String, List<PlanningItem>> _plannedAssignments = {};
  final Set<String> _completedPlanningItemIds = {};
  bool _initialized = false;
  int _headerCount = 0;

  @override
  Widget build(BuildContext context) {
    final blocksAsync = ref.watch(systemBlocksProvider);
    final methodsAsync = ref.watch(systemHabitsProvider);
    final methodDayBlocksAsync = ref.watch(systemMethodDayBlocksProvider);

    return Scaffold(
      appBar: null,
      body: SafeArea(
        child: blocksAsync.when(
        data: (blocks) {
          return methodsAsync.when(
            data: (methods) {
              return methodDayBlocksAsync.when(
                data: (methodDayBlocks) {
              if (blocks.isEmpty) {
                return const Center(
                  child: Text('Noch kein Inhalt verfügbar.'),
                );
              }

              if (!_initialized) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _initBlocks(blocks);
                });
              }

              final byId = {for (final b in blocks) b.id: b};
              final byKey = {for (final b in blocks) b.key: b};
              final morningBlock = byKey['morning_reset'];
              final middayBlock = byKey['midday_reset'];
              final eveningBlock = byKey['evening_shutdown'];
              final nonFixedBlocks = _activeBlockIds
                  .where((id) => !_fixedBlockIds.contains(id))
                  .map((id) => byId[id])
                  .whereType<SystemBlock>()
                  .toList();
              final morningSegment = nonFixedBlocks
                  .where((b) => _segmentForBlock(b) == _DaySegment.morning)
                  .toList();
              final middaySegment = nonFixedBlocks
                  .where((b) => _segmentForBlock(b) == _DaySegment.midday)
                  .toList();
              final eveningSegment = nonFixedBlocks
                  .where((b) => _segmentForBlock(b) == _DaySegment.evening)
                  .toList();
              final activeBlocks = <SystemBlock>[
                if (morningBlock != null) morningBlock,
                ...morningSegment,
                if (middayBlock != null) middayBlock,
                ...middaySegment,
                if (eveningBlock != null) eveningBlock,
                ...eveningSegment,
              ];
              _orderedBlockIds
                ..clear()
                ..addAll(activeBlocks.map((b) => b.id));
              _reorderableIds
                ..clear()
                ..addAll(activeBlocks
                    .where((b) => !_fixedBlockIds.contains(b.id))
                    .map((b) => b.id));

              final appointmentItems =
                  _plannedAssignments[_appointmentsBlockId] ?? const [];
              final headers = <Widget>[
                ScreenHero(
                  key: const ValueKey('hero'),
                  title: 'System',
                  subtitle:
                      'Baue deinen Tag in Blöcken. Habits geben dir Struktur – klar, ruhig, wiederholbar.',
                ),
                _DateBar(
                  key: const ValueKey('datebar'),
                  date: _selectedDate,
                  onPrevious: _previousDay,
                  onNext: _nextDay,
                  onPickDate: () => _pickDate(context),
                ),
                Padding(
                  key: const ValueKey('planning-cta'),
                  padding: const EdgeInsets.fromLTRB(30, 4, 30, 8),
                  child: _PlanningCtaButton(
                    onPressed: () => _handlePlanningSheet(
                      context,
                      blocks: activeBlocks,
                    ),
                  ),
                ),
                Padding(
                  key: const ValueKey('block-actions'),
                  padding: const EdgeInsets.fromLTRB(30, 8, 30, 0),
                  child: Row(
                    children: [
                      Text('Tagesblöcke',
                          style: Theme.of(context).textTheme.titleMedium),
                      const Spacer(),
                      TextButton(
                        onPressed: () => _openBlockCatalog(
                          context,
                          blocks,
                        ),
                        child: const Text('Block hinzufügen'),
                      ),
                    ],
                  ),
                ),
                if (appointmentItems.isNotEmpty)
                  Padding(
                    key: const ValueKey('appointments-block'),
                    padding: const EdgeInsets.fromLTRB(30, 12, 30, 12),
                    child: _AppointmentSection(
                      items: appointmentItems,
                      onRemove: (item) => _removePlanningItem(
                        item,
                        blocks: blocks,
                      ),
                    ),
                  ),
              ];
              _headerCount = headers.length;

              return ReorderableListView(
                padding: const EdgeInsets.only(bottom: 24),
                buildDefaultDragHandles: false,
                onReorder: _reorderBlocks,
                children: [
                  ...headers,
                  for (var i = 0; i < activeBlocks.length; i++)
                    _BlockSection(
                      key: ValueKey(activeBlocks[i].id),
                      reorderIndex: _headerCount + i,
                      isFixedHabit:
                          _fixedBlockIds.contains(activeBlocks[i].id),
                      block: activeBlocks[i],
                      plannedItems:
                          _plannedAssignments[activeBlocks[i].id] ?? const [],
                      completedPlanningItemIds: _completedPlanningItemIds,
                      onTogglePlannedItem: (item) {
                        final updated =
                            Set<String>.from(_completedPlanningItemIds);
                        if (!updated.add(item.id)) {
                          updated.remove(item.id);
                        }
                        setState(() {
                          _completedPlanningItemIds
                            ..clear()
                            ..addAll(updated);
                        });
                      },
                      methods: () {
                        final blockLinks = _methodsForBlock(
                          methods,
                          methodDayBlocks,
                          activeBlocks[i].key,
                        );
                        final metaHiddenMethods = blockLinks
                            .where((m) =>
                                m.blockRole == 'meta_hidden' ||
                                isSystemLogicMethod(m))
                            .toList();
                        final habits = blockLinks.where((m) {
                          if (m.blockRole == 'meta_hidden') return false;
                          if (isSystemLogicMethod(m)) return false;
                          return isHabitMethod(m);
                        }).toList();
                        return _BlockMethods(
                          habits: habits,
                          metaHidden: metaHiddenMethods,
                        );
                      }(),
                      metaHiddenMethods: () {
                        final blockLinks = _methodsForBlock(
                          methods,
                          methodDayBlocks,
                          activeBlocks[i].key,
                        );
                        return blockLinks
                            .where((m) =>
                                m.blockRole == 'meta_hidden' ||
                                isSystemLogicMethod(m))
                            .toList();
                      }(),
                      selectedDate: _selectedDate,
                      onRedirectToBlock: (targetKey) {},
                      isLast: i == activeBlocks.length - 1,
                    ),
                ],
              );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Center(
                  child: Text('Methoden konnten nicht geladen werden.'),
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Center(
              child: Text('Methoden konnten nicht geladen werden.'),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(
          child: Text('Tag-Daten konnten nicht geladen werden.'),
        ),
        ),
      ),
    );
  }

  void _initBlocks(List<SystemBlock> blocks) {
    if (_initialized) return;
    final byKey = <String, SystemBlock>{
      for (final b in blocks) b.key: b,
    };
    _fixedBlockIds
      ..clear()
      ..addAll(_fixedHabitBlockKeys
          .map((k) => byKey[k])
          .whereType<SystemBlock>()
          .map((b) => b.id));
    final defaults = blocks
        .where((b) => _defaultBlockKeys.contains(b.key))
        .toList()
      ..sort((a, b) => a.sortRank.compareTo(b.sortRank));
    setState(() {
      _activeBlockIds
        ..clear()
        ..addAll(defaults
            .where((b) => !_fixedBlockIds.contains(b.id))
            .map((b) => b.id));
      _initialized = true;
    });
  }

  void _reorderBlocks(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < _headerCount || newIndex < _headerCount) {
        return;
      }
      oldIndex -= _headerCount;
      newIndex -= _headerCount;
      if (_orderedBlockIds.isEmpty) return;
      if (oldIndex >= _orderedBlockIds.length) return;
      if (newIndex >= _orderedBlockIds.length) {
        newIndex = _orderedBlockIds.length - 1;
      }
      final oldId = _orderedBlockIds[oldIndex];
      if (_fixedBlockIds.contains(oldId)) return;
      final next = List<String>.from(_reorderableIds);
      final oldReorderIndex = next.indexOf(oldId);
      if (oldReorderIndex == -1) return;
      var newReorderIndex = 0;
      for (var i = 0; i < _orderedBlockIds.length; i++) {
        if (_fixedBlockIds.contains(_orderedBlockIds[i])) continue;
        if (i == newIndex) break;
        newReorderIndex++;
      }
      if (newIndex > oldIndex) newReorderIndex -= 1;
      final id = next.removeAt(oldReorderIndex);
      if (newReorderIndex < 0) newReorderIndex = 0;
      if (newReorderIndex > next.length) newReorderIndex = next.length;
      next.insert(newReorderIndex, id);
      _activeBlockIds
        ..clear()
        ..addAll(next);
    });
  }

  void _previousDay() {
    setState(() {
      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
      _resetDayState();
    });
  }

  void _nextDay() {
    setState(() {
      _selectedDate = _selectedDate.add(const Duration(days: 1));
      _resetDayState();
    });
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _selectedDate = picked;
      _resetDayState();
    });
  }

  void _resetDayState() {
    _planningItems.clear();
    _plannedAssignments = {};
    _completedPlanningItemIds.clear();
    ref.read(userStateProvider.notifier).clearDayPlan();
  }

  void _openBlockCatalog(BuildContext context, List<SystemBlock> blocks) {
    showBottomCardSheet(
      context: context,
      child: _BlockCatalogSheet(
        blocks: blocks,
        activeIds: _activeBlockIds,
        fixedIds: _fixedBlockIds,
        onAdd: (id) {
          if (_fixedBlockIds.contains(id)) return;
          if (_activeBlockIds.contains(id)) return;
          setState(() => _activeBlockIds.add(id));
          ref.read(userStateProvider.notifier).setDayPlanBlock(
                DayPlanBlock(
                  blockId: id,
                  outcome: null,
                  methodIds: const [],
                  doneMethodIds: const [],
                  done: false,
                ),
              );
        },
      ),
    );
  }

  Future<void> _handlePlanningSheet(
    BuildContext context, {
    required List<SystemBlock> blocks,
  }) async {
    final result = await showBottomCardSheet<_PlanningSheetResult>(
      context: context,
      maxHeightFactor: 0.8,
      child: _PlanningSheet(selectedDate: _selectedDate),
    );
    if (result == null) return;
    final nextItems = List<PlanningItem>.from(_planningItems)
      ..add(result.item);
    setState(() {
      _planningItems
        ..clear()
        ..addAll(nextItems);
      _plannedAssignments = _planAssignments(
        items: nextItems,
        blocks: blocks,
      );
    });
    if (result.addAnother) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handlePlanningSheet(context, blocks: blocks);
      });
    }
  }

  Map<String, List<PlanningItem>> _planAssignments({
    required List<PlanningItem> items,
    required List<SystemBlock> blocks,
  }) {
    final engine = buildPlannerEngine();
    final dayBlocks = [
      ...blocks.map(_toDayBlock).whereType<DayBlock>(),
      const DayBlock(
        id: _appointmentsBlockId,
        type: DayBlockType.appointments,
        fixed: true,
        start: null,
        end: null,
      ),
    ];
    final planned = engine.plan(items: items, blocks: dayBlocks);
    return planned.assignments;
  }

  void _removePlanningItem(
    PlanningItem item, {
    required List<SystemBlock> blocks,
  }) {
    final nextItems = List<PlanningItem>.from(_planningItems)
      ..removeWhere((p) => p.id == item.id);
    setState(() {
      _planningItems
        ..clear()
        ..addAll(nextItems);
      _plannedAssignments = _planAssignments(
        items: nextItems,
        blocks: blocks,
      );
      _completedPlanningItemIds.remove(item.id);
    });
  }
}

List<MethodV2> _methodsForBlock(
  List<MethodV2> methods,
  List<MethodDayBlock> links,
  String blockKey,
) {
  final byId = {for (final m in methods) m.id: m};
  final matching = links
      .where((l) => l.dayBlockKey == blockKey)
      .toList()
    ..sort((a, b) => a.sortRank.compareTo(b.sortRank));
  final joined = <MethodV2>[];
  for (final link in matching) {
    final method = byId[link.methodId];
    if (method != null) {
      final role = link.blockRole.trim().isEmpty ? 'optional' : link.blockRole;
      joined.add(method.copyWith(
        blockRole: role,
        defaultSelected: link.defaultSelected,
      ));
    }
  }
  return joined;
}

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

List<String> _badgesForBlockKey(String key) {
  switch (key) {
    case 'morning_reset':
      return const ['Klarheit', 'Ruhe'];
    case 'midday_reset':
      return const ['Recovery'];
    case 'evening_shutdown':
      return const ['Wachstum', 'Abschluss'];
    case 'deep_work':
      return const ['Umsetzung', 'Fokus'];
    case 'work_pomodoro':
      return const ['Umsetzung'];
    default:
      return const [];
  }
}

String _displayTitleForBlock(SystemBlock block) {
  switch (block.key) {
    case 'deep_work':
      return 'Wichtige Aufgaben';
    case 'work_pomodoro':
      return 'To-Dos & Kommunikation';
    default:
      return block.title;
  }
}

bool _isWorkPlanningBlock(String key) {
  return key == 'deep_work' || key == 'work_pomodoro';
}

bool _isHabitBlock(String key) {
  return key == 'morning_reset' ||
      key == 'midday_reset' ||
      key == 'evening_shutdown';
}

PlannerEngine buildPlannerEngine() {
  return const PlannerEngine([
    Limit135Rule(),
    ContextBlockRoutingRule(),
    FixedAppointmentRule(),
    FrogRule(),
    ChronoRule(),
    BatchingRule(),
  ]);
}

DayBlock? _toDayBlock(SystemBlock block) {
  final type = _dayBlockTypeForKey(block.key);
  if (type == null) return null;
  return DayBlock(
    id: block.id,
    type: type,
    fixed: type == DayBlockType.morningFixed ||
        type == DayBlockType.middayFixed ||
        type == DayBlockType.eveningFixed,
    start: null,
    end: null,
  );
}

DayBlockType? _dayBlockTypeForKey(String key) {
  switch (key) {
    case 'morning_reset':
      return DayBlockType.morningFixed;
    case 'deep_work':
      return DayBlockType.deepWork;
    case 'work_pomodoro':
      return DayBlockType.pomodoro;
    case 'midday_reset':
      return DayBlockType.middayFixed;
    case 'evening_shutdown':
      return DayBlockType.eveningFixed;
    default:
      return null;
  }
}

enum _DaySegment { morning, midday, evening }

_DaySegment _segmentForBlock(SystemBlock block) {
  final key = block.key.toLowerCase();
  final hint = block.timeHint.toLowerCase();
  if (key.contains('deep_work')) {
    return _DaySegment.morning;
  }
  if (key.contains('pomodoro')) {
    return _DaySegment.midday;
  }
  if (key.contains('morning') || hint.contains('morgen')) {
    return _DaySegment.morning;
  }
  if (hint.contains('vormittag')) {
    return _DaySegment.morning;
  }
  if (key.contains('midday') || hint.contains('mittag')) {
    return _DaySegment.midday;
  }
  if (hint.contains('nachmittag')) {
    return _DaySegment.midday;
  }
  if (key.contains('evening') || hint.contains('abend')) {
    return _DaySegment.evening;
  }
  if (hint.contains('nacht')) {
    return _DaySegment.evening;
  }
  return _DaySegment.midday;
}

class _BlockMethods {
  const _BlockMethods({
    required this.habits,
    required this.metaHidden,
  });

  final List<MethodV2> habits;
  final List<MethodV2> metaHidden;
}

class _MethodTaskList extends StatelessWidget {
  const _MethodTaskList({
    required this.tasks,
    required this.onToggle,
  });

  final List<SystemTask> tasks;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        children: tasks.map((t) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Checkbox(
                  value: t.completed,
                  onChanged: (_) => onToggle(t.id),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    t.title,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.8),
                        ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

void _showAddTaskSheet({
  required BuildContext context,
  required SystemBlock block,
  required MethodV2 method,
  required DateTime selectedDate,
  required List<MethodV2> metaHiddenMethods,
  required List<SystemTask> existingTasks,
  required List<SystemTask> blockTasks,
  required bool isActiveMethod,
  required ValueChanged<String> onRedirectToBlock,
  required WidgetRef ref,
}) {
  if (!isActiveMethod && method.blockRole == 'optional') {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Aktiviere die Methode, um Aufgaben hinzuzufügen.'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
      ),
    );
    return;
  }
  final decision = validateTaskCreation(
    metaHiddenMethods: metaHiddenMethods,
    block: block,
    method: method,
    date: selectedDate,
    existingMethodTasks: existingTasks,
    existingBlockTasks: blockTasks,
  );
  if (!decision.allowed) {
    final hint = decision.hint ?? 'Heute lieber weniger.';
    final hasRedirect = decision.redirectBlockKey?.isNotEmpty ?? false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(hint),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
        action: hasRedirect
            ? SnackBarAction(
                label: 'Zum Block',
                onPressed: () =>
                    onRedirectToBlock(decision.redirectBlockKey!),
              )
            : null,
      ),
    );
    return;
  }

  final controller = TextEditingController();
  showBottomCardSheet(
    context: context,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Aufgabe hinzufügen',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Titel der Aufgabe',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              final title = controller.text.trim();
              if (title.isEmpty) return;
              ref.read(systemTasksProvider.notifier).addTask(
                    SystemTask(
                      id: DateTime.now().microsecondsSinceEpoch.toString(),
                      title: title,
                      date: selectedDate,
                      blockKey: block.key,
                      methodId: method.id,
                      completed: false,
                    ),
                  );
              Navigator.of(context).pop();
            },
            child: const Text('Hinzufügen'),
          ),
        ),
      ],
    ),
  );
}

void _openHabitSheet(
  BuildContext context, {
  required MethodV2 habit,
  required String habitKey,
}) {
  showBottomCardSheet(
    context: context,
    child: _HabitContentSheet(
      habit: habit,
      habitKey: habitKey,
    ),
  );
}

void _openHabitPickerSheet(
  BuildContext context, {
  required SystemBlock block,
  required List<MethodV2> habits,
}) {
  showBottomCardSheet(
    context: context,
    child: _HabitPickerSheet(
      block: block,
      habits: habits,
    ),
  );
}

class _DateBar extends StatelessWidget {
  const _DateBar({
    super.key,
    required this.date,
    required this.onPrevious,
    required this.onNext,
    required this.onPickDate,
  });

  final DateTime date;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPickDate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 8, 30, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Text(
              _formatDate(date),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onPickDate,
            icon: const Icon(Icons.calendar_month_outlined),
          ),
        ],
      ),
    );
  }
}

class _BlockSection extends ConsumerWidget {
  const _BlockSection({
    super.key,
    required this.reorderIndex,
    required this.isFixedHabit,
    required this.block,
    required this.plannedItems,
    required this.completedPlanningItemIds,
    required this.onTogglePlannedItem,
    required this.methods,
    required this.isLast,
    required this.metaHiddenMethods,
    required this.selectedDate,
    required this.onRedirectToBlock,
  });

  final int reorderIndex;
  final bool isFixedHabit;
  final SystemBlock block;
  final List<PlanningItem> plannedItems;
  final Set<String> completedPlanningItemIds;
  final ValueChanged<PlanningItem> onTogglePlannedItem;
  final _BlockMethods methods;
  final bool isLast;
  final List<MethodV2> metaHiddenMethods;
  final DateTime selectedDate;
  final ValueChanged<String> onRedirectToBlock;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userStateProvider);
    final plan = user.todayPlan[block.id] ??
        const DayPlanBlock(
          blockId: '',
          outcome: null,
          methodIds: [],
          doneMethodIds: [],
          done: false,
        );
    final doneIds = List<String>.from(
        plan.blockId.isEmpty ? const <String>[] : plan.doneMethodIds);
    final requiredHabits =
        methods.habits.where((m) => m.blockRole == 'required').toList();
    final optionalHabits =
        methods.habits.where((m) => m.blockRole == 'optional').toList();
    final hasPlan = plan.blockId.isNotEmpty;
    final requiredIds = requiredHabits.map((m) => m.id).toSet();
    final defaultOptionalIds = optionalHabits
        .where((m) => m.defaultSelected)
        .map((m) => m.id)
        .toSet();
    final selectedIds = {
      ...requiredIds,
      if (!hasPlan) ...defaultOptionalIds,
      ...plan.methodIds,
    };
    final visibleMethods = [
      ...requiredHabits,
      ...optionalHabits.where((m) => selectedIds.contains(m.id)),
    ];
    final badges = _badgesForBlockKey(block.key);
    final habitIds = visibleMethods.map((m) => m.id).toList();
    final showHabits = _isHabitBlock(block.key);

    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 12, 30, 12),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TimelineIcon(icon: _iconForBlock(block), isLast: isLast),
              const SizedBox(width: 12),
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: null,
                    child: EditorialCard(
                      backgroundColor: isFixedHabit
                          ? Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.08)
                          : null,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  _displayTitleForBlock(block),
                                  style:
                                      Theme.of(context).textTheme.titleLarge,
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (!isFixedHabit)
                                ReorderableDragStartListener(
                                  index: reorderIndex,
                                  child: Icon(
                                    Icons.drag_handle,
                                    size: 20,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.5),
                                  ),
                                ),
                            ],
                          ),
                          if (block.desc.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              block.desc,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.75),
                                  ),
                            ),
                          ],
                          if (badges.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children:
                                  badges.map((b) => TagChip(label: b)).toList(),
                            ),
                          ],
                          const SizedBox(height: 12),
                          if (showHabits) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: visibleMethods.isEmpty
                                  ? Text(
                                      'Noch keine Habits verfügbar.',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withOpacity(0.7),
                                          ),
                                    )
                                  : Column(
                                      children: [
                                        ...visibleMethods.take(3).map(
                                          (m) {
                                            final isDone =
                                                doneIds.contains(m.id);
                                            return Column(
                                              children: [
                                                Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    vertical: 6,
                                                  ),
                                                  child: InkWell(
                                                    onTap: () => _openHabitSheet(
                                                      context,
                                                      habit: m,
                                                      habitKey:
                                                          habitKeyForMethod(m) ??
                                                              m.key,
                                                    ),
                                                    child: Row(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment.start,
                                                      children: [
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Text(
                                                                m.title,
                                                                style: Theme.of(
                                                                        context)
                                                                    .textTheme
                                                                    .bodySmall
                                                                    ?.copyWith(
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w600,
                                                                    ),
                                                              ),
                                                              if (m.shortDesc
                                                                  .isNotEmpty)
                                                                Text(
                                                                  m.shortDesc,
                                                                  style: Theme.of(
                                                                          context)
                                                                      .textTheme
                                                                      .labelSmall
                                                                      ?.copyWith(
                                                                        color: Theme.of(
                                                                                context)
                                                                            .colorScheme
                                                                            .onSurface
                                                                            .withOpacity(
                                                                                0.7),
                                                                      ),
                                                                ),
                                                            ],
                                                          ),
                                                        ),
                                                        IconButton(
                                                          visualDensity:
                                                              VisualDensity.compact,
                                                          onPressed: () {
                                                            final notifier =
                                                                ref.read(
                                                                    userStateProvider
                                                                        .notifier);
                                                            final nextDone =
                                                                List<String>.from(
                                                                    doneIds);
                                                            if (isDone) {
                                                              nextDone
                                                                  .remove(m.id);
                                                            } else {
                                                              nextDone.add(m.id);
                                                            }
                                                            notifier.setDayPlanBlock(
                                                              plan.blockId.isEmpty
                                                                  ? DayPlanBlock(
                                                                      blockId:
                                                                          block.id,
                                                                      outcome: null,
                                                                      methodIds:
                                                                          habitIds,
                                                                      doneMethodIds:
                                                                          nextDone,
                                                                      done: false,
                                                                    )
                                                                  : plan.copyWith(
                                                                      methodIds:
                                                                          habitIds,
                                                                      doneMethodIds:
                                                                          nextDone,
                                                                    ),
                                                            );
                                                          },
                                                          icon: Icon(
                                                            isDone
                                                                ? Icons.check_circle
                                                                : Icons
                                                                    .circle_outlined,
                                                            size: 20,
                                                            color: isDone
                                                                ? Theme.of(context)
                                                                    .colorScheme
                                                                    .primary
                                                                : Theme.of(context)
                                                                    .iconTheme
                                                                    .color,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                                const Divider(height: 1),
                                              ],
                                            );
                                          },
                                        ),
                                        if (visibleMethods.length > 3) ...[
                                          const SizedBox(height: 4),
                                          Align(
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              '+${visibleMethods.length - 3} weitere',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelSmall
                                                  ?.copyWith(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurface
                                                        .withOpacity(0.6),
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                            ),
                          ],
                          if (!showHabits && plannedItems.isEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Noch keine To-Dos.',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.7),
                                  ),
                            ),
                          ],
                          if (plannedItems.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            _PlannedItemsList(
                              items: plannedItems,
                              completedIds: completedPlanningItemIds,
                              onToggle: onTogglePlannedItem,
                            ),
                          ],
                          if (showHabits) ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: () => _openHabitPickerSheet(
                                  context,
                                  block: block,
                                  habits: methods.habits,
                                ),
                                child: const Text('Habits hinzufügen'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlanningCtaButton extends StatelessWidget {
  const _PlanningCtaButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.add_circle_outline),
        label: const Text('To-Dos hinzufügen'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          textStyle: Theme.of(context).textTheme.titleSmall,
        ),
      ),
    );
  }
}

class _HabitContentSheet extends ConsumerWidget {
  const _HabitContentSheet({
    required this.habit,
    required this.habitKey,
  });

  final MethodV2 habit;
  final String habitKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(systemHabitContentProvider(habitKey));
    return async.when(
      data: (items) => HabitSheet(
        habit: habit,
        contentItems: items,
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Text('Inhalt konnte nicht geladen werden.'),
    );
  }
}

class _PlannedItemsList extends StatelessWidget {
  const _PlannedItemsList({
    required this.items,
    required this.completedIds,
    required this.onToggle,
  });

  final List<PlanningItem> items;
  final Set<String> completedIds;
  final ValueChanged<PlanningItem> onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items.map((item) {
        final duration =
            item.durationMin > 0 ? '${item.durationMin} min' : '';
        final isDone = completedIds.contains(item.id);
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        if (duration.isNotEmpty)
                          Text(
                            duration,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.7),
                                ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => onToggle(item),
                    icon: Icon(
                      isDone ? Icons.check_circle : Icons.circle_outlined,
                      size: 20,
                      color: isDone
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).iconTheme.color,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
          ],
        );
      }).toList(),
    );
  }
}

class _HabitPickerSheet extends ConsumerWidget {
  const _HabitPickerSheet({
    required this.block,
    required this.habits,
  });

  final SystemBlock block;
  final List<MethodV2> habits;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userStateProvider);
    final plan = user.todayPlan[block.id] ??
        const DayPlanBlock(
          blockId: '',
          outcome: null,
          methodIds: [],
          doneMethodIds: [],
          done: false,
        );
    final requiredIds =
        habits.where((m) => m.blockRole == 'required').map((m) => m.id).toSet();
    final defaultOptionalIds = habits
        .where((m) => m.blockRole == 'optional' && m.defaultSelected)
        .map((m) => m.id)
        .toSet();
    final hasPlan = plan.blockId.isNotEmpty;
    final selectedIds = {
      ...requiredIds,
      if (!hasPlan) ...defaultOptionalIds,
      ...plan.methodIds,
    };
    final optionalHabits =
        habits.where((m) => m.blockRole == 'optional').toList();
    final grouped = _groupHabitsForPicker(optionalHabits);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Habits hinzufügen',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (grouped.isEmpty)
          const Text('Keine optionalen Habits verfügbar.')
        else
          ..._buildHabitGroups(
            context,
            grouped,
            selectedIds,
            onToggle: (habit) {
              final notifier = ref.read(userStateProvider.notifier);
              final current = plan.blockId.isEmpty
                  ? DayPlanBlock(
                      blockId: block.id,
                      outcome: null,
                      methodIds: const [],
                      doneMethodIds: const [],
                      done: false,
                    )
                  : plan;
              final next = List<String>.from(
                hasPlan ? current.methodIds : defaultOptionalIds,
              );
              final nextDone = List<String>.from(current.doneMethodIds);
              final selected = selectedIds.contains(habit.id);
              if (selected) {
                next.remove(habit.id);
                nextDone.remove(habit.id);
              } else {
                next.add(habit.id);
              }
              for (final id in requiredIds) {
                if (!next.contains(id)) next.add(id);
              }
              notifier.setDayPlanBlock(
                current.copyWith(
                  methodIds: next,
                  doneMethodIds: nextDone,
                ),
              );
            },
          ),
      ],
    );
  }
}

Map<String, List<MethodV2>> _groupHabitsForPicker(List<MethodV2> habits) {
  final map = <String, List<MethodV2>>{};
  for (final habit in habits) {
    final key = habit.category.trim().isEmpty
        ? (habit.habitKey.trim().isEmpty ? 'Weitere' : habit.habitKey)
        : habit.category;
    map.putIfAbsent(key, () => []).add(habit);
  }
  for (final entry in map.entries) {
    entry.value.sort((a, b) => a.sortRank.compareTo(b.sortRank));
  }
  return map;
}

List<Widget> _buildHabitGroups(
  BuildContext context,
  Map<String, List<MethodV2>> grouped,
  Set<String> selectedIds, {
    required ValueChanged<MethodV2> onToggle,
  }) {
  final widgets = <Widget>[];
  final keys = grouped.keys.toList()..sort();
  for (final key in keys) {
    final items = grouped[key] ?? const <MethodV2>[];
    if (items.isEmpty) continue;
    widgets.add(Text(key, style: Theme.of(context).textTheme.labelLarge));
    widgets.add(const SizedBox(height: 6));
    for (final habit in items) {
      final selected = selectedIds.contains(habit.id);
      widgets.add(
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          title: Text(habit.title),
          subtitle: habit.shortDesc.isEmpty ? null : Text(habit.shortDesc),
          trailing: Icon(
            selected ? Icons.check_circle_outline : Icons.add_circle_outline,
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).iconTheme.color?.withOpacity(0.6),
          ),
          onTap: () => onToggle(habit),
        ),
      );
      widgets.add(const Divider(height: 1));
    }
    widgets.add(const SizedBox(height: 8));
  }
  return widgets;
}

class _PlanningSheet extends StatefulWidget {
  const _PlanningSheet({required this.selectedDate});

  final DateTime selectedDate;

  @override
  State<_PlanningSheet> createState() => _PlanningSheetState();
}

class _PlanningSheetState extends State<_PlanningSheet> {
  final _titleController = TextEditingController();
  final _durationController = TextEditingController();
  String _durationUnit = 'Minuten';
  String _category = 'To-Do';
  String _priority = 'Mittel';
  String _todoContext = 'Privat';
  String _personalArea = 'Berufliche Weiterentwicklung';
  bool _isUrgent = false;
  bool _isImportant = false;
  TimeOfDay? _appointmentTime;

  @override
  void dispose() {
    _titleController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surfaceVariant;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tag planen',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            'Füge Aufgaben, Termine oder persönlichen Fokus hinzu.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          _sectionCard(
            title: 'Typ',
            child: _PlanningCategorySelector(
              value: _category,
              onChanged: (v) => setState(() => _category = v),
            ),
          ),
          const SizedBox(height: 12),
          _sectionCard(
            title: 'Details',
            child: _buildForm(context, surface: surface),
          ),
          const SizedBox(height: 16),
          if (_category == 'Termin') ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _submit(addAnother: false),
                child: const Text('Termin hinzufügen'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _submit(addAnother: true),
                child: const Text('Weiteren Termin hinzufügen'),
              ),
            ),
          ] else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _submit(addAnother: false),
                child: const Text('Hinzufügen'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildForm(BuildContext context, {required Color surface}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _titleController,
          decoration: InputDecoration(
            labelText: 'Titel',
            border: OutlineInputBorder(),
            filled: true,
            fillColor: surface.withOpacity(0.55),
          ),
        ),
        if (_category == 'Termin') ...[
          const SizedBox(height: 12),
          Text('Uhrzeit', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          _TimePickerRow(
            value: _appointmentTime,
            onTap: () => _pickTime(context),
          ),
        ],
        if (_category == 'To-Do') ...[
          const SizedBox(height: 12),
          Text('Privat oder Beruflich',
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Privat'),
                selected: _todoContext == 'Privat',
                onSelected: (_) => setState(() => _todoContext = 'Privat'),
                selectedColor: Theme.of(context)
                    .colorScheme
                    .primary
                    .withOpacity(0.12),
              ),
              ChoiceChip(
                label: const Text('Beruflich'),
                selected: _todoContext == 'Beruflich',
                onSelected: (_) => setState(() => _todoContext = 'Beruflich'),
                selectedColor: Theme.of(context)
                    .colorScheme
                    .primary
                    .withOpacity(0.12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Dringend / Wichtig',
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              FilterChip(
                label: const Text('Dringend'),
                selected: _isUrgent,
                onSelected: (v) => setState(() => _isUrgent = v),
                selectedColor: Theme.of(context)
                    .colorScheme
                    .primary
                    .withOpacity(0.16),
              ),
              FilterChip(
                label: const Text('Wichtig'),
                selected: _isImportant,
                onSelected: (v) => setState(() => _isImportant = v),
                selectedColor: Theme.of(context)
                    .colorScheme
                    .primary
                    .withOpacity(0.16),
              ),
            ],
          ),
        ],
        if (_category == 'Persönlich') ...[
          const SizedBox(height: 12),
          Text('Bereich', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              'Berufliche Weiterentwicklung',
              'Sport',
              'Private Weiterentwicklung',
              'Lernen',
              'Hobbys',
            ]
                .map(
                  (label) => ChoiceChip(
                    label: Text(label),
                    selected: _personalArea == label,
                    onSelected: (_) => setState(() => _personalArea = label),
                    selectedColor: Theme.of(context)
                        .colorScheme
                        .primary
                        .withOpacity(0.12),
                  ),
                )
                .toList(),
          ),
        ],
        if (_category == 'To-Do') ...[
          const SizedBox(height: 12),
          Text('Priorität', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Hoch'),
                selected: _priority == 'Hoch',
                onSelected: (_) => setState(() => _priority = 'Hoch'),
                selectedColor: Theme.of(context)
                    .colorScheme
                    .primary
                    .withOpacity(0.12),
              ),
              ChoiceChip(
                label: const Text('Mittel'),
                selected: _priority == 'Mittel',
                onSelected: (_) => setState(() => _priority = 'Mittel'),
                selectedColor: Theme.of(context)
                    .colorScheme
                    .primary
                    .withOpacity(0.12),
              ),
              ChoiceChip(
                label: const Text('Niedrig'),
                selected: _priority == 'Niedrig',
                onSelected: (_) => setState(() => _priority = 'Niedrig'),
                selectedColor: Theme.of(context)
                    .colorScheme
                    .primary
                    .withOpacity(0.12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _DurationRow(
            controller: _durationController,
            unit: _durationUnit,
            onUnitChanged: (v) => setState(() => _durationUnit = v),
          ),
        ],
      ],
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Future<void> _pickTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _appointmentTime ?? TimeOfDay.now(),
    );
    if (picked == null) return;
    setState(() => _appointmentTime = picked);
  }

  void _submit({required bool addAnother}) {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    final duration = int.tryParse(_durationController.text) ?? 0;
    final durationMin = _durationUnit == 'Stunden' ? duration * 60 : duration;
    final item = _buildPlanningItem(title, durationMin);
    if (item == null) return;
    Navigator.of(context).pop(_PlanningSheetResult(item, addAnother: addAnother));
  }

  PlanningItem? _buildPlanningItem(String title, int durationMin) {
    final priority = _category == 'To-Do'
        ? (_priority == 'Hoch'
            ? 1
            : _priority == 'Niedrig'
                ? 3
                : 2)
        : 2;
    final area = _category == 'To-Do' ? _todoContext : _personalArea;
    final isAppointment = _category == 'Termin';
    if (isAppointment && _appointmentTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte eine Uhrzeit auswählen.')),
      );
      return null;
    }
    final appointmentDate = isAppointment
        ? DateTime(
            widget.selectedDate.year,
            widget.selectedDate.month,
            widget.selectedDate.day,
            _appointmentTime!.hour,
            _appointmentTime!.minute,
          )
        : null;
    return PlanningItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      type: isAppointment
          ? PlanningType.appointment
          : _category == 'To-Do'
              ? PlanningType.todo
              : PlanningType.personal,
      durationMin: _category == 'To-Do' ? durationMin : 0,
      priority: priority,
      area: isAppointment ? null : area,
      fixedStart: appointmentDate,
    );
  }
}

class _PlanningSheetResult {
  final PlanningItem item;
  final bool addAnother;
  const _PlanningSheetResult(this.item, {this.addAnother = false});
}

class _PlanningCategorySelector extends StatelessWidget {
  const _PlanningCategorySelector({
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        ...const [
          'To-Do',
          'Termin',
          'Persönlich',
        ].map(
          (label) => ChoiceChip(
            label: Text(label),
            selected: value == label,
            onSelected: (_) => onChanged(label),
          ),
        ),
      ],
    );
  }
}

class _DurationRow extends StatelessWidget {
  const _DurationRow({
    required this.controller,
    required this.unit,
    required this.onUnitChanged,
  });

  final TextEditingController controller;
  final String unit;
  final ValueChanged<String> onUnitChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Dauer',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 130,
          child: DropdownButtonFormField<String>(
            value: unit,
            decoration: const InputDecoration(
              labelText: 'Einheit',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'Minuten', child: Text('Minuten')),
              DropdownMenuItem(value: 'Stunden', child: Text('Stunden')),
            ],
            onChanged: (v) => onUnitChanged(v ?? unit),
          ),
        ),
      ],
    );
  }
}

class _TimePickerRow extends StatelessWidget {
  const _TimePickerRow({
    required this.value,
    required this.onTap,
  });

  final TimeOfDay? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final display = value == null
        ? 'Uhrzeit auswählen'
        : value!.format(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).dividerColor.withOpacity(0.4),
          ),
          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
        ),
        child: Row(
          children: [
            Icon(
              Icons.schedule,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              display,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _AppointmentSection extends StatelessWidget {
  const _AppointmentSection({
    required this.items,
    required this.onRemove,
  });

  final List<PlanningItem> items;
  final ValueChanged<PlanningItem> onRemove;

  @override
  Widget build(BuildContext context) {
    final sorted = List<PlanningItem>.from(items)
      ..sort((a, b) {
        final aTime = a.fixedStart ?? DateTime(2100);
        final bTime = b.fixedStart ?? DateTime(2100);
        return aTime.compareTo(bTime);
      });
    return EditorialCard(
      backgroundColor:
          Theme.of(context).colorScheme.tertiaryContainer.withOpacity(0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Termine',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            'Deine festen Termine für den Tag.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.7),
                ),
          ),
          const SizedBox(height: 12),
          ...sorted.map(
            (item) => Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatAppointmentTime(context, item.fixedStart),
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.7),
                                ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => onRemove(item),
                      icon: Icon(
                        Icons.close,
                        size: 20,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 1),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatAppointmentTime(BuildContext context, DateTime? value) {
  if (value == null) return 'Uhrzeit offen';
  final time = TimeOfDay(hour: value.hour, minute: value.minute);
  return time.format(context);
}

class _TimelineIcon extends StatelessWidget {
  const _TimelineIcon({required this.icon, required this.isLast});

  final IconData icon;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: scheme.surfaceVariant,
          ),
          child: Icon(icon, size: 18, color: scheme.onSurface.withOpacity(0.7)),
        ),
        if (!isLast)
          Container(
            width: 2,
            height: 90,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: scheme.outline.withOpacity(0.4),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
      ],
    );
  }
}

class _MethodRow extends StatelessWidget {
  const _MethodRow({
    required this.method,
    this.showExamples = false,
    this.trailing,
    this.onTap,
  });

  final MethodV2 method;
  final bool showExamples;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(method.title,
                      style: Theme.of(context).textTheme.titleSmall),
                  if (method.shortDesc.isNotEmpty ||
                      method.category.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      method.shortDesc.isNotEmpty
                          ? method.shortDesc
                          : method.category,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.75),
                          ),
                    ),
                  ],
                  if (showExamples && method.examples.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ...method.examples
                        .map((e) => Text(
                              '• $e',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.7),
                                  ),
                            ))
                        .toList(),
                  ],
                  if (method.impactTags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: method.impactTags
                          .map((t) => TagChip(label: t))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
            trailing ?? const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

void _openMethodDetails(BuildContext context, MethodV2 m) {
  showBottomCardSheet(
    context: context,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(m.title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (m.shortDesc.isNotEmpty) Text(m.shortDesc),
        if (m.category.isNotEmpty && m.shortDesc.isEmpty) Text(m.category),
        if (m.examples.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Beispiele', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          ...m.examples.map((s) => Text('• $s')),
        ],
        if (m.steps.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Schritte', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          ...m.steps.map((s) => Text('• $s')),
        ],
        if (m.durationMinutes > 0) ...[
          const SizedBox(height: 12),
          Text('Dauer', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          Text('${m.durationMinutes} Min'),
        ],
        if (m.benefit.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Nutzen', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          Text(m.benefit),
        ],
      ],
    ),
  );
}

class _BlockCatalogSheet extends StatelessWidget {
  const _BlockCatalogSheet({
    required this.blocks,
    required this.activeIds,
    required this.fixedIds,
    required this.onAdd,
  });

  final List<SystemBlock> blocks;
  final List<String> activeIds;
  final List<String> fixedIds;
  final ValueChanged<String> onAdd;

  @override
  Widget build(BuildContext context) {
    final available = blocks
        .where((b) => !activeIds.contains(b.id))
        .where((b) => !fixedIds.contains(b.id))
        .toList()
          ..sort((a, b) => a.sortRank.compareTo(b.sortRank));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Blöcke hinzufügen',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 12),
        if (available.isEmpty)
          const Text('Keine weiteren Blöcke verfügbar.')
        else
          ...available.map(
            (b) => Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: _TimelineIcon(icon: _iconForBlock(b), isLast: true),
                  title: Text(
                    b.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  subtitle: b.desc.isEmpty
                      ? null
                      : Text(
                          b.desc,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                  trailing: const Icon(Icons.add_circle_outline),
                  onTap: () {
                    onAdd(b.id);
                    Navigator.pop(context);
                  },
                ),
                const Divider(height: 1),
              ],
            ),
          ),
      ],
    );
  }
}

String _formatDate(DateTime date) {
  const weekdays = [
    'Mo',
    'Di',
    'Mi',
    'Do',
    'Fr',
    'Sa',
    'So',
  ];
  const months = [
    'Jan',
    'Feb',
    'Mär',
    'Apr',
    'Mai',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Okt',
    'Nov',
    'Dez',
  ];
  final weekday = weekdays[date.weekday - 1];
  final month = months[date.month - 1];
  return '$weekday, ${date.day}. $month ${date.year}';
}

IconData _iconForBlock(SystemBlock block) {
  switch (block.key) {
    case 'morning_reset':
      return Icons.wb_sunny_outlined;
    case 'deep_work':
      return Icons.psychology_outlined;
    case 'movement':
      return Icons.fitness_center;
    case 'evening_shutdown':
      return Icons.nightlight_round;
    case 'sleep_prep':
      return Icons.bedtime_outlined;
    case 'midday_reset':
      return Icons.local_cafe_outlined;
    case 'work_pomodoro':
      return Icons.timer_outlined;
    case 'weekly_review':
      return Icons.calendar_month_outlined;
    default:
      return Icons.circle_outlined;
  }
}
