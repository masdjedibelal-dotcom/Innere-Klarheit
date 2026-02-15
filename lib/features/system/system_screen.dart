import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../widgets/bottom_sheet/bottom_card_sheet.dart';
import '../../widgets/bottom_sheet/habit_sheet.dart';
import '../../widgets/common/editorial_card.dart';
import '../../widgets/common/tag_chip.dart';
import '../../ui/components/screen_hero.dart';
import '../../state/user_state.dart';
import '../../state/guest_day_plan_state.dart';
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
  const SystemScreen({super.key, this.initialAction, this.initialTitle});

  final String? initialAction;
  final String? initialTitle;

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
  static const _wakeItemId = 'wake_up';
  static const _sleepItemId = 'sleep';
  static const _defaultWakeTime = TimeOfDay(hour: 8, minute: 0);
  static const _defaultSleepTime = TimeOfDay(hour: 0, minute: 0);
  static const _deepWorkMaxInstances = 2;
  static const _todoMaxInstances = 3;
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
  final Map<String, List<PlanningItem>> _planningItemsByDate = {};
  Map<String, List<PlanningItem>> _plannedAssignments = {};
  final Map<String, Map<String, List<PlanningItem>>> _plannedAssignmentsByDate =
      {};
  final Set<String> _completedPlanningItemIds = {};
  final Map<String, Set<String>> _completedPlanningItemIdsByDate = {};
  final Map<String, TimeOfDay> _wakeTimeByDate = {};
  final Map<String, TimeOfDay> _sleepTimeByDate = {};
  final List<int> _blockListPositions = [];
  final Set<String> _loadedDayKeys = {};
  final Set<String> _loadingDayKeys = {};
  String? _lastSyncedOrderKey;
  List<String> _lastSyncedOrderIds = const [];
  bool _initialized = false;
  int _headerCount = 0;
  bool _didAutoAction = false;

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
                    final seededMethods = withMiddayResetDefaultHabit(methods);
                    final seededLinks = withMiddayResetDefaultHabitLink(
                      methodDayBlocks,
                      seededMethods,
                    );
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
              _ensureDayLoaded(blocks, _selectedDate);

              final expandedBlocks =
                  _expandBlocksWithInstances(blocks, _activeBlockIds);
              final byId = {for (final b in expandedBlocks) b.id: b};
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
              if (!_didAutoAction &&
                  widget.initialAction != null &&
                  activeBlocks.isNotEmpty) {
                _didAutoAction = true;
                final title = widget.initialTitle?.trim();
                final initialItem = title != null && title.isNotEmpty
                    ? _buildPrefillItem(
                        title,
                        type: widget.initialAction == 'appointment'
                            ? PlanningType.appointment
                            : PlanningType.todo,
                      )
                    : null;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  switch (widget.initialAction) {
                    case 'todo':
                      _handleTodoSheet(
                        context,
                        blocks: activeBlocks,
                        initialItem: initialItem,
                      );
                      break;
                    case 'appointment':
                      _handleAppointmentSheet(
                        context,
                        blocks: activeBlocks,
                        initialItem: initialItem,
                      );
                      break;
                    case 'habit':
                      _showHabitBridge(context);
                      break;
                    case 'block':
                      _openBlockCatalog(context, blocks);
                      break;
                  }
                });
              }
              _syncBlockOrder(activeBlocks);
              _orderedBlockIds
                ..clear()
                ..addAll(activeBlocks.map((b) => b.id));
              _reorderableIds
                ..clear()
                ..addAll(activeBlocks
                    .where((b) => !_fixedBlockIds.contains(b.id))
                    .map((b) => b.id));

              final appointmentItems = _planningItems
                  .where((item) =>
                      item.type == PlanningType.appointment &&
                      !_isMarkerItem(item.id))
                  .toList()
                ..sort((a, b) {
                  final aTime = a.fixedStart ?? DateTime(2100);
                  final bTime = b.fixedStart ?? DateTime(2100);
                  return aTime.compareTo(bTime);
                });
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
                    onPressed: () => _handleAppointmentSheet(
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
              ];
              _headerCount = headers.length;

              final slotSchedule =
                  _buildBlockSlots(activeBlocks, _selectedDate);
              final slotByBlockId = {
                for (final slot in slotSchedule) slot.block.id: slot
              };
              final sleepAt = _sleepDateTime(_selectedDate);
              var appointmentIndex = 0;
              final timelineChildren = <Widget>[
                Padding(
                  key: const ValueKey('wake-block'),
                  padding: const EdgeInsets.fromLTRB(30, 12, 30, 12),
                  child: _WakeSleepBlock(
                    title: 'Aufwachen',
                    time: _wakeTimeFor(_selectedDate),
                    icon: Icons.alarm,
                    isLast: false,
                    onTap: () => _pickMarkerTime(
                      _selectedDate,
                      markerId: _wakeItemId,
                      title: 'Aufwachen',
                    ),
                  ),
                ),
                ..._collectAppointmentsBefore(
                  appointmentItems,
                  () => appointmentIndex,
                  (next) => appointmentIndex = next,
                  slotSchedule.isEmpty ? sleepAt : slotSchedule.first.start,
                  blocks,
                ),
                for (var i = 0; i < activeBlocks.length; i++) ...[
                  _BlockSection(
                    key: ValueKey(activeBlocks[i].id),
                    reorderIndex: _headerCount + i,
                    isFixedHabit: _fixedBlockIds.contains(activeBlocks[i].id),
                    block: activeBlocks[i],
                    timeRangeLabel: _formatTimeRange(
                      context,
                      slotByBlockId[activeBlocks[i].id],
                    ),
                    plannedItems:
                        _plannedAssignments[activeBlocks[i].id] ?? const [],
                    completedPlanningItemIds: _completedPlanningItemIds,
                    onTogglePlannedItem: _togglePlannedItem,
                    methods: () {
                      final blockLinks = _methodsForBlock(
                        seededMethods,
                        seededLinks,
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
                        seededMethods,
                        seededLinks,
                        activeBlocks[i].key,
                      );
                      return blockLinks
                          .where((m) =>
                              m.blockRole == 'meta_hidden' ||
                              isSystemLogicMethod(m))
                          .toList();
                    }(),
                    selectedDate: _selectedDate,
                    onAddTodo: () => _handleTodoSheet(
                      context,
                      blocks: activeBlocks,
                    ),
                    onEditTodo: (item) => _handleTodoSheet(
                      context,
                      blocks: activeBlocks,
                      initialItem: item,
                    ),
                    onDeleteTodo: (item) => _removePlanningItem(
                      item,
                      blocks: activeBlocks,
                    ),
                    onRedirectToBlock: (targetKey) {},
                    isLast: false,
                  ),
                  ..._collectAppointmentsBefore(
                    appointmentItems,
                    () => appointmentIndex,
                    (next) => appointmentIndex = next,
                    i + 1 < slotSchedule.length
                        ? slotSchedule[i + 1].start
                        : sleepAt,
                    blocks,
                  ),
                ],
                Padding(
                  key: const ValueKey('sleep-block'),
                  padding: const EdgeInsets.fromLTRB(30, 12, 30, 12),
                  child: _WakeSleepBlock(
                    title: 'Schlafen',
                    time: _sleepTimeFor(_selectedDate),
                    icon: Icons.nights_stay_outlined,
                    isLast: true,
                    onTap: () => _pickMarkerTime(
                      _selectedDate,
                      markerId: _sleepItemId,
                      title: 'Schlafen',
                    ),
                  ),
                ),
              ];
              final children = <Widget>[...headers, ...timelineChildren];
              _blockListPositions
                ..clear()
                ..addAll(
                  [
                    for (var i = 0; i < children.length; i++)
                      if (children[i] is _BlockSection) i
                  ],
                );

              return ReorderableListView(
                padding: const EdgeInsets.only(bottom: 24),
                buildDefaultDragHandles: false,
                onReorder: _reorderBlocks,
                children: children,
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
      _restoreDayState(_selectedDate);
    });
  }

  void _ensureDayLoaded(List<SystemBlock> blocks, DateTime date) {
    final key = dateKey(date);
    if (_loadedDayKeys.contains(key) || _loadingDayKeys.contains(key)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDayState(blocks, date);
    });
  }

  Future<void> _loadDayState(List<SystemBlock> blocks, DateTime date) async {
    final key = dateKey(date);
    if (_loadedDayKeys.contains(key) || _loadingDayKeys.contains(key)) return;
    _loadingDayKeys.add(key);
    if (!_hasEmailLogin()) {
      final entry = ref.read(guestDayPlanProvider).entryFor(date);
      final items = <PlanningItem>[];
      final completed = Set<String>.from(entry.completedItemIds);
      TimeOfDay? wakeTime;
      TimeOfDay? sleepTime;
      for (final item in entry.items) {
        if (_isMarkerItem(item.id)) {
          final markerTime = item.fixedStart == null
              ? null
              : TimeOfDay(
                  hour: item.fixedStart!.hour, minute: item.fixedStart!.minute);
          if (item.id == _wakeItemId) {
            wakeTime = markerTime;
          } else if (item.id == _sleepItemId) {
            sleepTime = markerTime;
          }
          continue;
        }
        items.add(item);
      }
      if (wakeTime == null) {
        wakeTime = _defaultWakeTime;
        _persistMarkerTime(
          date,
          markerId: _wakeItemId,
          title: 'Aufwachen',
          time: wakeTime,
        );
      }
      if (sleepTime == null) {
        sleepTime = _defaultSleepTime;
        _persistMarkerTime(
          date,
          markerId: _sleepItemId,
          title: 'Schlafen',
          time: sleepTime,
        );
      }
      _loadingDayKeys.remove(key);
      _loadedDayKeys.add(key);
      _wakeTimeByDate[key] = wakeTime;
      _sleepTimeByDate[key] = sleepTime;
      _planningItemsByDate[key] = List<PlanningItem>.from(items);
      _completedPlanningItemIdsByDate[key] = Set<String>.from(completed);
      _plannedAssignmentsByDate[key] = _planAssignments(
        items: items,
        blocks: blocks,
      );
      if (key == dateKey(_selectedDate)) {
        setState(() {
          _restoreDayState(date);
        });
      }
      return;
    }
    final repo = ref.read(dayPlanRepoProvider);
    final result = await repo.fetchDayPlan(date);
    if (!mounted) return;
    _loadingDayKeys.remove(key);
    _loadedDayKeys.add(key);
    if (!result.isSuccess) return;
    final data = result.data!;
    final items = <PlanningItem>[];
    final completed = <String>{};
    TimeOfDay? wakeTime;
    TimeOfDay? sleepTime;
    for (final item in data.items) {
      if (_isMarkerItem(item.id)) {
        final markerTime = item.fixedStart == null
            ? null
            : TimeOfDay(hour: item.fixedStart!.hour, minute: item.fixedStart!.minute);
        if (item.id == _wakeItemId) {
          wakeTime = markerTime;
        } else if (item.id == _sleepItemId) {
          sleepTime = markerTime;
        }
        continue;
      }
      items.add(item);
      if (data.completedItemIds.contains(item.id)) {
        completed.add(item.id);
      }
    }
    if (wakeTime == null) {
      wakeTime = _defaultWakeTime;
      _persistMarkerTime(
        date,
        markerId: _wakeItemId,
        title: 'Aufwachen',
        time: wakeTime,
      );
    }
    if (sleepTime == null) {
      sleepTime = _defaultSleepTime;
      _persistMarkerTime(
        date,
        markerId: _sleepItemId,
        title: 'Schlafen',
        time: sleepTime,
      );
    }
    _wakeTimeByDate[key] = wakeTime;
    _sleepTimeByDate[key] = sleepTime;
    _planningItemsByDate[key] = List<PlanningItem>.from(items);
    _completedPlanningItemIdsByDate[key] = Set<String>.from(completed);
    _plannedAssignmentsByDate[key] = _planAssignments(
      items: items,
      blocks: blocks,
    );
    ref.read(userStateProvider.notifier).setDayPlanForDate(
          date,
          data.blocks,
        );
    ref
        .read(userStateProvider.notifier)
        .setDayBlockOrderForDate(date, data.blockOrder);
    if (key == dateKey(_selectedDate)) {
      setState(() {
        _restoreDayState(date);
      });
    }
  }

  void _reorderBlocks(int oldIndex, int newIndex) {
    setState(() {
      if (_orderedBlockIds.isEmpty) return;
      if (oldIndex < _headerCount) return;
      final oldBlockIndex = _blockListPositions.indexOf(oldIndex);
      if (oldBlockIndex == -1) return;
      var newBlockIndex =
          _blockListPositions.where((i) => i < newIndex).length;
      if (newBlockIndex > _orderedBlockIds.length - 1) {
        newBlockIndex = _orderedBlockIds.length - 1;
      }
      if (newIndex > oldIndex) {
        newBlockIndex -= 1;
      }
      if (newBlockIndex < 0) newBlockIndex = 0;
      final oldId = _orderedBlockIds[oldBlockIndex];
      if (_fixedBlockIds.contains(oldId)) return;
      final next = List<String>.from(_reorderableIds);
      final oldReorderIndex = next.indexOf(oldId);
      if (oldReorderIndex == -1) return;
      var newReorderIndex = 0;
      for (var i = 0; i < _orderedBlockIds.length; i++) {
        if (_fixedBlockIds.contains(_orderedBlockIds[i])) continue;
        if (i == newBlockIndex) break;
        newReorderIndex++;
      }
      if (newBlockIndex > oldBlockIndex) newReorderIndex -= 1;
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
      _cacheDayState(_selectedDate);
      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
      _restoreDayState(_selectedDate);
    });
  }

  void _nextDay() {
    setState(() {
      _cacheDayState(_selectedDate);
      _selectedDate = _selectedDate.add(const Duration(days: 1));
      _restoreDayState(_selectedDate);
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
      _cacheDayState(_selectedDate);
      _selectedDate = picked;
      _restoreDayState(_selectedDate);
    });
  }

  void _restoreDayState(DateTime date) {
    final key = dateKey(date);
    final items = _planningItemsByDate[key];
    final assignments = _plannedAssignmentsByDate[key];
    final completed = _completedPlanningItemIdsByDate[key];
    _planningItems
      ..clear()
      ..addAll(items ?? const []);
    _plannedAssignments =
        assignments == null ? {} : _cloneAssignments(assignments);
    _completedPlanningItemIds
      ..clear()
      ..addAll(completed ?? const {});
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
          final block = blocks.firstWhere((b) => b.id == id, orElse: () => blocks.first);
          final maxInstances = _maxInstancesForKey(block.key);
          final count = _countInstancesForBase(id, _activeBlockIds);
          if (count >= maxInstances) return;
          final nextId = _nextInstanceId(id, _activeBlockIds);
          setState(() => _activeBlockIds.add(nextId));
          ref.read(userStateProvider.notifier).setDayPlanBlockForDate(
                _selectedDate,
                DayPlanBlock(
                  blockId: nextId,
                  outcome: null,
                  methodIds: const [],
                  doneMethodIds: const [],
                  done: false,
                ),
              );
        },
        onRemove: (id) {
          if (_fixedBlockIds.contains(id)) return;
          final removeId = _latestInstanceId(id, _activeBlockIds);
          if (removeId == null) return;
          setState(() => _activeBlockIds.remove(removeId));
          ref
              .read(userStateProvider.notifier)
              .removeDayPlanBlockForDate(_selectedDate, removeId);
        },
      ),
    );
  }

  Future<void> _handleAppointmentSheet(
    BuildContext context, {
    required List<SystemBlock> blocks,
    PlanningItem? initialItem,
  }) async {
    await _handlePlanningSheet(
      context,
      blocks: blocks,
      mode: _PlanningMode.appointment,
      initialItem: initialItem,
    );
  }

  Future<void> _handleTodoSheet(
    BuildContext context, {
    required List<SystemBlock> blocks,
    PlanningItem? initialItem,
  }) async {
    await _handlePlanningSheet(
      context,
      blocks: blocks,
      mode: _PlanningMode.todo,
      initialItem: initialItem,
    );
  }

  Future<void> _handlePlanningSheet(
    BuildContext context, {
    required List<SystemBlock> blocks,
    required _PlanningMode mode,
    PlanningItem? initialItem,
  }) async {
    final result = await showBottomCardSheet<_PlanningSheetResult>(
      context: context,
      maxHeightFactor: 0.8,
      child: _PlanningSheet(
        selectedDate: _selectedDate,
        mode: mode,
        initialItem: initialItem,
      ),
    );
    if (result == null) return;
    final nextItems = List<PlanningItem>.from(_planningItems);
    if (initialItem == null) {
      nextItems.add(result.item);
    } else {
      final index =
          nextItems.indexWhere((item) => item.id == initialItem.id);
      if (index == -1) {
        nextItems.add(result.item);
      } else {
        nextItems[index] = result.item;
      }
    }
    setState(() {
      _planningItems
        ..clear()
        ..addAll(nextItems);
      _plannedAssignments = _planAssignments(
        items: nextItems,
        blocks: blocks,
      );
    });
    if (_hasEmailLogin()) {
      ref.read(dayPlanRepoProvider).upsertPlanningItem(
            _selectedDate,
            result.item,
            completed: _completedPlanningItemIds.contains(result.item.id),
          );
    } else {
      ref.read(guestDayPlanProvider.notifier).upsertItem(
            _selectedDate,
            result.item,
            completed: _completedPlanningItemIds.contains(result.item.id),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'Ohne Registrierung werden deine Daten nach dem Schließen der App gelöscht.'),
            action: SnackBarAction(
              label: 'Registrieren',
              onPressed: () => context.push('/auth'),
            ),
          ),
        );
      }
    }
    _cacheDayState(_selectedDate);
    if (result.addAnother) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handlePlanningSheet(context, blocks: blocks, mode: mode);
      });
    }
  }

  PlanningItem _buildPrefillItem(
    String title, {
    required PlanningType type,
  }) {
    return PlanningItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      description: null,
      type: type,
      durationMin: 0,
      priority: 2,
      area: null,
      fixedStart: null,
    );
  }

  void _showHabitBridge(BuildContext context) {
    showBottomCardSheet(
      context: context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Als Habit übernehmen',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Wähle einen Block und füge eine passende Methode hinzu.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.7),
                ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Alles klar'),
            ),
          ),
        ],
      ),
    );
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

  List<_TimelineBlockSlot> _buildBlockSlots(
    List<SystemBlock> blocks,
    DateTime date,
  ) {
    final slots = <_TimelineBlockSlot>[];
    var cursor = _markerDateTime(date, _wakeTimeFor(date));
    for (final block in blocks) {
      final duration = _blockDurationMin(block);
      DateTime start;
      DateTime end;
      if (block.key == 'evening_shutdown') {
        end = _sleepDateTime(date);
        start = end.subtract(Duration(minutes: duration));
      } else if (block.key == 'midday_reset') {
        final midday = DateTime(date.year, date.month, date.day, 12, 0);
        start = cursor.isAfter(midday) ? cursor : midday;
        end = start.add(Duration(minutes: duration));
      } else {
        start = cursor;
        end = start.add(Duration(minutes: duration));
      }
      slots.add(_TimelineBlockSlot(block: block, start: start, end: end));
      cursor = end;
    }
    return slots;
  }

  List<Widget> _collectAppointmentsBefore(
    List<PlanningItem> appointments,
    int Function() getIndex,
    void Function(int) setIndex,
    DateTime before,
    List<SystemBlock> blocks,
  ) {
    final widgets = <Widget>[];
    var index = getIndex();
    while (index < appointments.length) {
      final time = _appointmentTime(appointments[index]);
      if (!time.isBefore(before)) break;
      final item = appointments[index];
      widgets.add(
        Padding(
          key: ValueKey('appointment-${item.id}'),
          padding: const EdgeInsets.fromLTRB(30, 12, 30, 12),
          child: _AppointmentBlock(
            item: item,
            onRemove: () => _removePlanningItem(
              item,
              blocks: blocks,
            ),
          ),
        ),
      );
      index++;
    }
    setIndex(index);
    return widgets;
  }

  DateTime _appointmentTime(PlanningItem item) {
    return item.fixedStart ?? DateTime(2100);
  }

  bool _isMarkerItem(String id) => id == _wakeItemId || id == _sleepItemId;

  String? _formatTimeRange(
    BuildContext context,
    _TimelineBlockSlot? slot,
  ) {
    if (slot == null) return null;
    final start = TimeOfDay.fromDateTime(slot.start).format(context);
    final end = TimeOfDay.fromDateTime(slot.end).format(context);
    return '$start–$end';
  }

  int _blockDurationMin(SystemBlock block) {
    if (_isHabitBlock(block.key)) return 60;
    if (block.key == 'deep_work' || block.key == 'work_pomodoro') {
      return 90;
    }
    return 60;
  }

  DateTime _sleepDateTime(DateTime date) {
    final wake = _markerDateTime(date, _wakeTimeFor(date));
    var sleep = _markerDateTime(date, _sleepTimeFor(date));
    if (!sleep.isAfter(wake)) {
      sleep = sleep.add(const Duration(days: 1));
    }
    return sleep;
  }

  TimeOfDay _wakeTimeFor(DateTime date) {
    return _wakeTimeByDate[dateKey(date)] ?? _defaultWakeTime;
  }

  TimeOfDay _sleepTimeFor(DateTime date) {
    return _sleepTimeByDate[dateKey(date)] ?? _defaultSleepTime;
  }

  Future<void> _pickMarkerTime(
    DateTime date, {
    required String markerId,
    required String title,
  }) async {
    final current =
        markerId == _wakeItemId ? _wakeTimeFor(date) : _sleepTimeFor(date);
    final picked = await showTimePicker(
      context: context,
      initialTime: current,
    );
    if (picked == null) return;
    setState(() {
      if (markerId == _wakeItemId) {
        _wakeTimeByDate[dateKey(date)] = picked;
      } else {
        _sleepTimeByDate[dateKey(date)] = picked;
      }
    });
    _persistMarkerTime(date,
        markerId: markerId, title: title, time: picked);
  }

  void _persistMarkerTime(
    DateTime date, {
    required String markerId,
    required String title,
    required TimeOfDay time,
  }) {
    final item = PlanningItem(
      id: markerId,
      title: title,
      description: null,
      type: PlanningType.appointment,
      durationMin: 0,
      priority: 2,
      area: null,
      fixedStart: _markerDateTime(date, time),
    );
    if (_hasEmailLogin()) {
      ref.read(dayPlanRepoProvider).upsertPlanningItem(
            date,
            item,
            completed: false,
          );
    } else {
      ref.read(guestDayPlanProvider.notifier).upsertItem(
            date,
            item,
            completed: false,
          );
    }
  }

  DateTime _markerDateTime(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  void _cacheDayState(DateTime date) {
    final key = dateKey(date);
    _planningItemsByDate[key] = List<PlanningItem>.from(_planningItems);
    _plannedAssignmentsByDate[key] = _cloneAssignments(_plannedAssignments);
    _completedPlanningItemIdsByDate[key] =
        Set<String>.from(_completedPlanningItemIds);
  }

  void _syncBlockOrder(List<SystemBlock> activeBlocks) {
    final key = dateKey(_selectedDate);
    final next = activeBlocks.map((b) => b.id).toList();
    if (_lastSyncedOrderKey == key && listEquals(_lastSyncedOrderIds, next)) {
      return;
    }
    _lastSyncedOrderKey = key;
    _lastSyncedOrderIds = List<String>.from(next);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(userStateProvider.notifier)
          .setDayBlockOrderForDate(_selectedDate, next);
    });
  }

  Map<String, List<PlanningItem>> _cloneAssignments(
    Map<String, List<PlanningItem>> source,
  ) {
    return source.map((key, value) => MapEntry(key, List.of(value)));
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
    if (_hasEmailLogin()) {
      ref.read(dayPlanRepoProvider).deletePlanningItem(
            _selectedDate,
            item.id,
          );
    } else {
      ref.read(guestDayPlanProvider.notifier).removeItem(_selectedDate, item.id);
    }
    _cacheDayState(_selectedDate);
  }

  void _togglePlannedItem(PlanningItem item) {
    final updated = Set<String>.from(_completedPlanningItemIds);
    if (!updated.add(item.id)) {
      updated.remove(item.id);
    }
    setState(() {
      _completedPlanningItemIds
        ..clear()
        ..addAll(updated);
    });
    if (_hasEmailLogin()) {
      ref.read(dayPlanRepoProvider).setPlanningItemCompleted(
            _selectedDate,
            item.id,
            updated.contains(item.id),
          );
    } else {
      ref
          .read(guestDayPlanProvider.notifier)
          .setCompleted(_selectedDate, item.id, updated.contains(item.id));
    }
    _cacheDayState(_selectedDate);
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

String? _blockMetaLabel(SystemBlock block) {
  switch (block.key) {
    case 'midday_reset':
      return '12:00 · 60 Min';
    case 'morning_reset':
    case 'evening_shutdown':
      return '60 Min';
    case 'deep_work':
    case 'work_pomodoro':
      return '90 Min';
    default:
      return null;
  }
}

String _displayTitleForBlock(SystemBlock block) {
  switch (block.key) {
    case 'deep_work':
      return 'Wichtige Aufgaben';
    case 'work_pomodoro':
      return 'To-Dos';
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

bool _hasEmailLogin() {
  final email = Supabase.instance.client.auth.currentUser?.email ?? '';
  return email.isNotEmpty;
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
            border: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.transparent),
            ),
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
  required VoidCallback onEdit,
  required VoidCallback onDelete,
}) {
  showBottomCardSheet(
    context: context,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HabitContentSheet(
          habit: habit,
          habitKey: habitKey,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onEdit,
                child: const Text('Bearbeiten'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextButton(
                onPressed: onDelete,
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                child: const Text('Löschen'),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

void _openHabitPickerSheet(
  BuildContext context, {
  required SystemBlock block,
  required List<MethodV2> habits,
  required DateTime selectedDate,
}) {
  showBottomCardSheet(
    context: context,
    child: _HabitPickerSheet(
      block: block,
      habits: habits,
      selectedDate: selectedDate,
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

class _BlockSection extends ConsumerStatefulWidget {
  const _BlockSection({
    super.key,
    required this.reorderIndex,
    required this.isFixedHabit,
    required this.block,
    this.timeRangeLabel,
    required this.plannedItems,
    required this.completedPlanningItemIds,
    required this.onTogglePlannedItem,
    required this.methods,
    required this.isLast,
    required this.metaHiddenMethods,
    required this.selectedDate,
    required this.onAddTodo,
    required this.onEditTodo,
    required this.onDeleteTodo,
    required this.onRedirectToBlock,
  });

  final int reorderIndex;
  final bool isFixedHabit;
  final SystemBlock block;
  final String? timeRangeLabel;
  final List<PlanningItem> plannedItems;
  final Set<String> completedPlanningItemIds;
  final ValueChanged<PlanningItem> onTogglePlannedItem;
  final _BlockMethods methods;
  final bool isLast;
  final List<MethodV2> metaHiddenMethods;
  final DateTime selectedDate;
  final VoidCallback onAddTodo;
  final ValueChanged<PlanningItem> onEditTodo;
  final ValueChanged<PlanningItem> onDeleteTodo;
  final ValueChanged<String> onRedirectToBlock;

  @override
  ConsumerState<_BlockSection> createState() => _BlockSectionState();
}

class _BlockSectionState extends ConsumerState<_BlockSection> {
  bool _showAllHabits = false;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userStateProvider);
    final dayPlan =
        user.dayPlansByDate[dateKey(widget.selectedDate)] ?? const {};
    final plan = dayPlan[widget.block.id] ??
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
        widget.methods.habits.where((m) => m.blockRole == 'required').toList();
    final optionalHabits =
        widget.methods.habits.where((m) => m.blockRole == 'optional').toList();
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
    final badges = _badgesForBlockKey(widget.block.key);
    final metaLabel = _blockMetaLabel(widget.block);
    final timeLabel = widget.timeRangeLabel;
    final habitIds = visibleMethods.map((m) => m.id).toList();
    final showHabits = _isHabitBlock(widget.block.key);
    final showTodoCta = _isWorkPlanningBlock(widget.block.key);

    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 12, 30, 12),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TimelineIcon(icon: _iconForBlock(widget.block), isLast: widget.isLast),
              const SizedBox(width: 12),
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: null,
                    child: EditorialCard(
                      backgroundColor: widget.isFixedHabit
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
                                  _displayTitleForBlock(widget.block),
                                  style:
                                      Theme.of(context).textTheme.titleLarge,
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (!widget.isFixedHabit)
                                ReorderableDragStartListener(
                                  index: widget.reorderIndex,
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
                          if (metaLabel != null || timeLabel != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              [
                                if (timeLabel != null) timeLabel,
                                if (metaLabel != null) metaLabel,
                              ].join(' · '),
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
                          ],
                          if (widget.block.desc.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              widget.block.desc,
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
                                        ...(_showAllHabits
                                                ? visibleMethods
                                                : visibleMethods.take(3))
                                            .map(
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
                                                      onEdit: () {
                                                        Navigator.of(context).pop();
                                                        WidgetsBinding.instance
                                                            .addPostFrameCallback(
                                                          (_) => _openHabitPickerSheet(
                                                            context,
                                                            block: widget.block,
                                                            habits: widget
                                                                .methods.habits,
                                                            selectedDate:
                                                                widget.selectedDate,
                                                          ),
                                                        );
                                                      },
                                                      onDelete: () {
                                                        if (m.blockRole ==
                                                            'required') {
                                                          ScaffoldMessenger.of(
                                                                  context)
                                                              .showSnackBar(
                                                            const SnackBar(
                                                              content: Text(
                                                                  'Pflicht-Habit kann nicht entfernt werden.'),
                                                            ),
                                                          );
                                                          return;
                                                        }
                                                        final notifier = ref.read(
                                                            userStateProvider
                                                                .notifier);
                                                        final nextIds =
                                                            List<String>.from(
                                                                plan.methodIds)
                                                              ..remove(m.id);
                                                        final nextDone =
                                                            List<String>.from(
                                                                doneIds)
                                                              ..remove(m.id);
                                                        notifier.setDayPlanBlockForDate(
                                                          widget.selectedDate,
                                                          plan.blockId.isEmpty
                                                              ? DayPlanBlock(
                                                                  blockId:
                                                                      widget.block.id,
                                                                  outcome: null,
                                                                  methodIds: nextIds,
                                                                  doneMethodIds:
                                                                      nextDone,
                                                                  done: false,
                                                                )
                                                              : plan.copyWith(
                                                                  methodIds:
                                                                      nextIds,
                                                                  doneMethodIds:
                                                                      nextDone,
                                                                ),
                                                        );
                                                        Navigator.of(context)
                                                            .pop();
                                                      },
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
                                                                      decoration: isDone
                                                                          ? TextDecoration
                                                                              .lineThrough
                                                                          : null,
                                                                      color: isDone
                                                                          ? Theme.of(
                                                                                  context)
                                                                              .colorScheme
                                                                              .onSurface
                                                                              .withOpacity(
                                                                                  0.55)
                                                                          : null,
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
                                                                        decoration: isDone
                                                                            ? TextDecoration
                                                                                .lineThrough
                                                                            : null,
                                                                        color: isDone
                                                                            ? Theme.of(
                                                                                    context)
                                                                                .colorScheme
                                                                                .onSurface
                                                                                .withOpacity(
                                                                                    0.45)
                                                                            : Theme.of(
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
                                                            notifier
                                                                .setDayPlanBlockForDate(
                                                              widget.selectedDate,
                                                              plan.blockId.isEmpty
                                                                  ? DayPlanBlock(
                                                                      blockId:
                                                                          widget.block.id,
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
                                            child: TextButton(
                                              style: TextButton.styleFrom(
                                                padding: EdgeInsets.zero,
                                                minimumSize: const Size(0, 0),
                                                tapTargetSize:
                                                    MaterialTapTargetSize.shrinkWrap,
                                              ),
                                              onPressed: () => setState(
                                                () => _showAllHabits =
                                                    !_showAllHabits,
                                              ),
                                              child: Text(
                                                _showAllHabits
                                                    ? 'Weniger anzeigen'
                                                    : '+${visibleMethods.length - 3} weitere',
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
                                          ),
                                        ],
                                      ],
                                    ),
                            ),
                          ],
                          if (!showHabits && widget.plannedItems.isEmpty) ...[
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
                          if (widget.plannedItems.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            _PlannedItemsList(
                              items: widget.plannedItems,
                              completedIds: widget.completedPlanningItemIds,
                              onToggle: widget.onTogglePlannedItem,
                              onOpenDetails: (item) =>
                                  _openTodoDetailsSheet(
                                context,
                                item,
                                onEdit: () => widget.onEditTodo(item),
                                onDelete: () => widget.onDeleteTodo(item),
                              ),
                            ),
                          ],
                          if (showTodoCta) ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: widget.onAddTodo,
                                icon: const Icon(Icons.add_circle_outline),
                                label: const Text('To-Dos hinzufügen'),
                                style: ElevatedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  textStyle:
                                      Theme.of(context).textTheme.titleSmall,
                                ),
                              ),
                            ),
                          ],
                          if (showHabits) ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: () => _openHabitPickerSheet(
                                  context,
                                  block: widget.block,
                                  habits: widget.methods.habits,
                                  selectedDate: widget.selectedDate,
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
        label: const Text('Termin hinzufügen'),
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
    required this.onOpenDetails,
  });

  final List<PlanningItem> items;
  final Set<String> completedIds;
  final ValueChanged<PlanningItem> onToggle;
  final ValueChanged<PlanningItem> onOpenDetails;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items.map((item) {
        final duration =
            item.durationMin > 0 ? '${item.durationMin} min' : '';
        final isDone = completedIds.contains(item.id);
        final subtitle = _todoSubtitle(item);
        final subtitlePreview = _todoSubtitlePreview(subtitle);
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => onOpenDetails(item),
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    decoration: isDone
                                        ? TextDecoration.lineThrough
                                        : null,
                                    color: isDone
                                        ? Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withOpacity(0.55)
                                        : null,
                                  ),
                            ),
                            if (subtitlePreview.isNotEmpty)
                              Text(
                                subtitlePreview,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      decoration: isDone
                                          ? TextDecoration.lineThrough
                                          : null,
                                      color: isDone
                                          ? Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withOpacity(0.45)
                                          : Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withOpacity(0.7),
                                    ),
                              ),
                            if (subtitlePreview.isEmpty && duration.isNotEmpty)
                              Text(
                                duration,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      decoration: isDone
                                          ? TextDecoration.lineThrough
                                          : null,
                                      color: isDone
                                          ? Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withOpacity(0.45)
                                          : Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withOpacity(0.7),
                                    ),
                              ),
                          ],
                        ),
                      ),
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

String _todoSubtitle(PlanningItem item) {
  final desc = item.description?.trim() ?? '';
  if (desc.isNotEmpty) return desc;
  return (item.area ?? '').trim();
}

String _todoSubtitlePreview(String subtitle) {
  if (subtitle.length <= 50) return subtitle;
  return subtitle.substring(0, 50);
}

List<String> _todoBadges(PlanningItem item) {
  final badges = <String>[];
  final area = (item.area ?? '').trim();
  if (area.isNotEmpty) {
    badges.addAll(
      area.split(' · ').map((s) => s.trim()).where((s) => s.isNotEmpty),
    );
  }
  switch (item.priority) {
    case 1:
      badges.add('Priorität: Hoch');
      break;
    case 3:
      badges.add('Priorität: Niedrig');
      break;
    default:
      badges.add('Priorität: Mittel');
  }
  return badges;
}

class _HabitPickerSheet extends ConsumerStatefulWidget {
  const _HabitPickerSheet({
    required this.block,
    required this.habits,
    required this.selectedDate,
  });

  final SystemBlock block;
  final List<MethodV2> habits;
  final DateTime selectedDate;

  @override
  ConsumerState<_HabitPickerSheet> createState() => _HabitPickerSheetState();
}

class _HabitPickerSheetState extends ConsumerState<_HabitPickerSheet> {
  String _selectedCategory = 'Alle';

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userStateProvider);
    final dayPlan =
        user.dayPlansByDate[dateKey(widget.selectedDate)] ?? const {};
    final plan = dayPlan[widget.block.id] ??
        const DayPlanBlock(
          blockId: '',
          outcome: null,
          methodIds: [],
          doneMethodIds: [],
          done: false,
        );
    final requiredIds =
        widget.habits.where((m) => m.blockRole == 'required').map((m) => m.id).toSet();
    final defaultOptionalIds = widget.habits
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
        widget.habits.where((m) => m.blockRole == 'optional').toList();
    final grouped = _groupHabitsForPicker(optionalHabits);
    final categories = grouped.keys.toList()..sort();
    final activeCategory = categories.contains(_selectedCategory) ||
            _selectedCategory == 'Alle'
        ? _selectedCategory
        : 'Alle';
    final filteredGrouped = activeCategory == 'Alle'
        ? grouped
        : {
            activeCategory: grouped[activeCategory] ?? const <MethodV2>[],
          };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Habits hinzufügen',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (grouped.isEmpty)
          const Text('Keine optionalen Habits verfügbar.')
        else ...[
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              FilterChip(
                label: const Text('Alle'),
                selected: activeCategory == 'Alle',
                onSelected: (_) => setState(() => _selectedCategory = 'Alle'),
              ),
              ...categories.map(
                (label) => FilterChip(
                  label: Text(label),
                  selected: activeCategory == label,
                  onSelected: (_) => setState(() => _selectedCategory = label),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._buildHabitGroups(
            context,
            filteredGrouped,
            selectedIds,
            onToggle: (habit) {
              final notifier = ref.read(userStateProvider.notifier);
              final current = plan.blockId.isEmpty
                  ? DayPlanBlock(
                      blockId: widget.block.id,
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
              notifier.setDayPlanBlockForDate(
                widget.selectedDate,
                current.copyWith(
                  methodIds: next,
                  doneMethodIds: nextDone,
                ),
              );
            },
          ),
        ],
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

enum _PlanningMode { todo, appointment }

class _PlanningSheet extends StatefulWidget {
  const _PlanningSheet({
    required this.selectedDate,
    required this.mode,
    this.initialItem,
  });

  final DateTime selectedDate;
  final _PlanningMode mode;
  final PlanningItem? initialItem;

  @override
  State<_PlanningSheet> createState() => _PlanningSheetState();
}

class _PlanningSheetState extends State<_PlanningSheet> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _priority = 'Mittel';
  String _todoContext = 'Privat';
  String _todoCategory = 'Entwicklung';
  bool _isUrgent = false;
  bool _isImportant = false;
  TimeOfDay? _appointmentTime;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialItem;
    if (initial == null) return;
    _titleController.text = initial.title;
    _descriptionController.text = initial.description?.trim() ?? '';
    if (widget.mode == _PlanningMode.appointment) {
      if (initial.fixedStart != null) {
        _appointmentTime = TimeOfDay.fromDateTime(initial.fixedStart!);
      }
      return;
    }
    _priority = initial.priority == 1
        ? 'Hoch'
        : initial.priority == 3
            ? 'Niedrig'
            : 'Mittel';
    final parts = (initial.area ?? '')
        .split(' · ')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.contains('Privat')) _todoContext = 'Privat';
    if (parts.contains('Beruflich')) _todoContext = 'Beruflich';
    if (parts.contains('Dringend')) _isUrgent = true;
    if (parts.contains('Wichtig')) _isImportant = true;
    if (parts.contains('Weiterentwicklung')) _todoCategory = 'Entwicklung';
    if (parts.contains('Entwicklung')) _todoCategory = 'Entwicklung';
    if (parts.contains('Lernen')) _todoCategory = 'Lernen';
    if (parts.contains('Hobby')) _todoCategory = 'Hobby';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surfaceVariant;
    final isTodo = widget.mode == _PlanningMode.todo;
    final isAppointment = widget.mode == _PlanningMode.appointment;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isAppointment ? 'Termin hinzufügen' : 'To-Dos hinzufügen',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            isAppointment
                ? 'Füge einen Termin für deinen Tag hinzu.'
                : 'Füge To-Dos für deinen Tag hinzu.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          _sectionCard(
            title: 'Details',
            child: _buildForm(context, surface: surface),
          ),
          const SizedBox(height: 16),
          if (isAppointment) ...[
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
          ] else if (isTodo)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _submit(addAnother: false),
                child: const Text('Hinzufügen'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  textStyle: Theme.of(context).textTheme.titleSmall,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildForm(BuildContext context, {required Color surface}) {
    final isTodo = widget.mode == _PlanningMode.todo;
    final isAppointment = widget.mode == _PlanningMode.appointment;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _titleController,
          decoration: InputDecoration(
            labelText: 'Titel',
            border: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.transparent),
            ),
            filled: true,
            fillColor: surface.withOpacity(0.55),
          ),
        ),
        if (isAppointment) ...[
          const SizedBox(height: 12),
          Text('Uhrzeit', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          _TimePickerRow(
            value: _appointmentTime,
            onTap: () => _pickTime(context),
          ),
        ],
        if (isTodo) ...[
          const SizedBox(height: 12),
          Text('Beschreibung', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          TextField(
            controller: _descriptionController,
            minLines: 2,
            maxLines: 4,
            maxLength: 50,
            decoration: InputDecoration(
              hintText: 'Worum geht es konkret?',
              counterText: '',
              border: const OutlineInputBorder(
                borderSide: BorderSide(color: Colors.transparent),
              ),
              filled: true,
              fillColor: surface.withOpacity(0.55),
            ),
          ),
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
          Text('Kategorie', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              'Entwicklung',
              'Lernen',
              'Hobby',
            ]
                .map(
                  (label) => ChoiceChip(
                    label: Text(label),
                    selected: _todoCategory == label,
                    onSelected: (_) => setState(() => _todoCategory = label),
                    selectedColor: Theme.of(context)
                        .colorScheme
                        .primary
                        .withOpacity(0.12),
                  ),
                )
                .toList(),
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
        if (isTodo) ...[
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
        border: Border.all(color: Colors.transparent),
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
    final item = _buildPlanningItem(title);
    if (item == null) return;
    Navigator.of(context).pop(_PlanningSheetResult(item, addAnother: addAnother));
  }

  PlanningItem? _buildPlanningItem(String title) {
    final isTodo = widget.mode == _PlanningMode.todo;
    final isAppointment = widget.mode == _PlanningMode.appointment;
    final priority = isTodo
        ? (_priority == 'Hoch'
            ? 1
            : _priority == 'Niedrig'
                ? 3
                : 2)
        : 2;
    final categoryValue =
        _todoCategory == 'Entwicklung' ? 'Weiterentwicklung' : _todoCategory;
    final area = isTodo
        ? [
            categoryValue,
            _todoContext,
            if (_isUrgent) 'Dringend',
            if (_isImportant) 'Wichtig',
          ].join(' · ')
        : null;
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
      id: widget.initialItem?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      description: isTodo ? _descriptionController.text.trim() : null,
      type: isAppointment ? PlanningType.appointment : PlanningType.todo,
      durationMin: 0,
      priority: priority,
      area: area,
      fixedStart: appointmentDate,
    );
  }
}

class _PlanningSheetResult {
  final PlanningItem item;
  final bool addAnother;
  const _PlanningSheetResult(this.item, {this.addAnother = false});
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
          border: Border.all(color: Colors.transparent),
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

class _AppointmentBlock extends StatelessWidget {
  const _AppointmentBlock({
    required this.item,
    required this.onRemove,
  });

  final PlanningItem item;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _TimelineIcon(icon: Icons.event_available_outlined, isLast: false),
        const SizedBox(width: 12),
        Expanded(
          child: EditorialCard(
            backgroundColor: Theme.of(context)
                .colorScheme
                .tertiaryContainer
                .withOpacity(0.35),
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
                      const SizedBox(height: 2),
                      Text(
                        _formatAppointmentTime(context, item.fixedStart),
                        style:
                            Theme.of(context).textTheme.labelSmall?.copyWith(
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
                  onPressed: onRemove,
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
          ),
        ),
      ],
    );
  }
}

class _WakeSleepBlock extends StatelessWidget {
  const _WakeSleepBlock({
    required this.title,
    required this.time,
    required this.icon,
    required this.isLast,
    required this.onTap,
  });

  final String title;
  final TimeOfDay time;
  final IconData icon;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TimelineIcon(icon: icon, isLast: isLast),
        const SizedBox(width: 12),
        Expanded(
          child: EditorialCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatTimeOfDay(context, time),
                        style:
                            Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.7),
                                ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: onTap,
                  icon: const Icon(Icons.schedule, size: 18),
                  label: const Text('Uhrzeit'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TimelineBlockSlot {
  const _TimelineBlockSlot({
    required this.block,
    required this.start,
    required this.end,
  });

  final SystemBlock block;
  final DateTime start;
  final DateTime end;
}

String _formatAppointmentTime(BuildContext context, DateTime? value) {
  if (value == null) return 'Uhrzeit offen';
  final time = TimeOfDay(hour: value.hour, minute: value.minute);
  return time.format(context);
}

String _formatTimeOfDay(BuildContext context, TimeOfDay value) {
  return value.format(context);
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

void _openTodoDetailsSheet(
  BuildContext context,
  PlanningItem item, {
  required VoidCallback onEdit,
  required VoidCallback onDelete,
}) {
  final subtitle = _todoSubtitle(item);
  final badges = _todoBadges(item);
  showBottomCardSheet(
    context: context,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(item.title, style: Theme.of(context).textTheme.titleLarge),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                ),
          ),
        ],
        if (badges.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: badges.map((b) => TagChip(label: b)).toList(),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  WidgetsBinding.instance
                      .addPostFrameCallback((_) => onEdit());
                },
                child: const Text('Bearbeiten'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  WidgetsBinding.instance
                      .addPostFrameCallback((_) => onDelete());
                },
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                child: const Text('Löschen'),
              ),
            ),
          ],
        ),
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
    required this.onRemove,
  });

  final List<SystemBlock> blocks;
  final List<String> activeIds;
  final List<String> fixedIds;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final candidates = blocks
        .where((b) => !fixedIds.contains(b.id))
        .where((b) => b.key == 'deep_work' || b.key == 'work_pomodoro')
        .toList()
      ..sort((a, b) => a.sortRank.compareTo(b.sortRank));
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Blöcke hinzufügen',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          if (candidates.isEmpty)
            const Text('Keine weiteren Blöcke verfügbar.')
          else
            ...candidates.map((b) {
              final count = _countInstancesForBase(b.id, activeIds);
              final max = _maxInstancesForKey(b.key);
              final canAdd = count < max;
              final canRemove = count > 0;
              return Column(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    leading: _TimelineIcon(icon: _iconForBlock(b), isLast: true),
                    title: Text(
                      _displayTitleForBlock(b),
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
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: canRemove ? () => onRemove(b.id) : null,
                        ),
                        Text(
                          '$count/$max',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: canAdd ? () => onAdd(b.id) : null,
                        ),
                      ],
                    ),
                    onTap: null,
                  ),
                  const Divider(height: 1),
                ],
              );
            }),
        ],
      ),
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

const _blockInstanceSeparator = '__';

int _maxInstancesForKey(String key) {
  switch (key) {
    case 'deep_work':
      return _SystemScreenState._deepWorkMaxInstances;
    case 'work_pomodoro':
      return _SystemScreenState._todoMaxInstances;
    default:
      return 1;
  }
}

String _baseBlockId(String id) {
  final index = id.indexOf(_blockInstanceSeparator);
  if (index == -1) return id;
  return id.substring(0, index);
}

int _instanceIndexFor(String id) {
  final index = id.indexOf(_blockInstanceSeparator);
  if (index == -1) return 1;
  final raw = id.substring(index + _blockInstanceSeparator.length);
  return int.tryParse(raw) ?? 1;
}

int _countInstancesForBase(String baseId, Iterable<String> ids) {
  return ids.where((id) => _baseBlockId(id) == baseId).length;
}

String _nextInstanceId(String baseId, Iterable<String> ids) {
  final existing = ids.where((id) => _baseBlockId(id) == baseId).toList();
  if (existing.isEmpty) return baseId;
  final maxIndex =
      existing.map(_instanceIndexFor).reduce((a, b) => a > b ? a : b);
  return '$baseId$_blockInstanceSeparator${maxIndex + 1}';
}

String? _latestInstanceId(String baseId, Iterable<String> ids) {
  final existing = ids.where((id) => _baseBlockId(id) == baseId).toList();
  if (existing.isEmpty) return null;
  existing.sort((a, b) => _instanceIndexFor(b).compareTo(_instanceIndexFor(a)));
  return existing.first;
}

List<SystemBlock> _expandBlocksWithInstances(
  List<SystemBlock> blocks,
  Iterable<String> activeIds,
) {
  final byId = {for (final block in blocks) block.id: block};
  final expanded = List<SystemBlock>.from(blocks);
  for (final id in activeIds) {
    if (byId.containsKey(id)) continue;
    final baseId = _baseBlockId(id);
    final base = byId[baseId];
    if (base == null) continue;
    final clone = SystemBlock(
      id: id,
      key: base.key,
      title: base.title,
      desc: base.desc,
      outcomes: base.outcomes,
      timeHint: base.timeHint,
      icon: base.icon,
      sortRank: base.sortRank,
      isActive: base.isActive,
    );
    expanded.add(clone);
    byId[id] = clone;
  }
  return expanded;
}
