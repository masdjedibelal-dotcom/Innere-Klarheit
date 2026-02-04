import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/bottom_sheet/bottom_card_sheet.dart';
import '../../widgets/bottom_sheet/method_catalog_sheet.dart';
import '../../widgets/common/editorial_card.dart';
import '../../widgets/common/tag_chip.dart';
import '../../ui/components/screen_hero.dart';
import '../../state/user_state.dart';
import '../../data/models/method_v2.dart';
import '../../data/models/system_block.dart';

class SystemScreen extends ConsumerStatefulWidget {
  const SystemScreen({super.key});

  @override
  ConsumerState<SystemScreen> createState() => _SystemScreenState();
}

class _SystemScreenState extends ConsumerState<SystemScreen> {
  static const _defaultBlockKeys = {
    'morning_reset',
    'deep_work',
    'movement',
    'evening_shutdown',
  };

  DateTime _selectedDate = DateTime.now();
  final List<String> _activeBlockIds = [];
  bool _initialized = false;
  int _headerCount = 0;

  @override
  Widget build(BuildContext context) {
    final blocksAsync = ref.watch(systemBlocksProvider);
    final methodsAsync = ref.watch(systemMethodsProvider);

    return Scaffold(
      appBar: null,
      body: SafeArea(
        child: blocksAsync.when(
        data: (blocks) {
          return methodsAsync.when(
            data: (methods) {
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

              final activeBlocks = _activeBlockIds
                  .map((id) => blocks.firstWhere((b) => b.id == id))
                  .toList();

              final headers = <Widget>[
                ScreenHero(
                  key: const ValueKey('hero'),
                  title: 'System',
                  subtitle:
                      'Baue deinen Tag in Blöcken. Wähle passende Methoden pro Block – einfach, konkret, wiederholbar.',
                ),
                _DateBar(
                  key: const ValueKey('datebar'),
                  date: _selectedDate,
                  onPrevious: _previousDay,
                  onNext: _nextDay,
                  onPickDate: () => _pickDate(context),
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
                      block: activeBlocks[i],
                      methods: methods
                          .where((m) => m.contexts.contains(activeBlocks[i].key))
                          .toList(),
                      isLast: i == activeBlocks.length - 1,
                    ),
                ],
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
    final defaults = blocks
        .where((b) => _defaultBlockKeys.contains(b.key))
        .toList()
      ..sort((a, b) => a.sortRank.compareTo(b.sortRank));
    setState(() {
      _activeBlockIds
        ..clear()
        ..addAll(defaults.map((b) => b.id));
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
      if (newIndex > oldIndex) newIndex -= 1;
      final id = _activeBlockIds.removeAt(oldIndex);
      _activeBlockIds.insert(newIndex, id);
    });
  }

  void _previousDay() {
    setState(() {
      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
    });
  }

  void _nextDay() {
    setState(() {
      _selectedDate = _selectedDate.add(const Duration(days: 1));
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
    setState(() => _selectedDate = picked);
  }

  void _openBlockCatalog(BuildContext context, List<SystemBlock> blocks) {
    showBottomCardSheet(
      context: context,
      child: _BlockCatalogSheet(
        blocks: blocks,
        activeIds: _activeBlockIds,
        onAdd: (id) {
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
    required this.block,
    required this.methods,
    required this.isLast,
  });

  final int reorderIndex;
  final SystemBlock block;
  final List<MethodV2> methods;
  final bool isLast;

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
    final selectedIds = List<String>.from(
        plan.blockId.isEmpty ? const <String>[] : plan.methodIds);
    final doneIds = List<String>.from(
        plan.blockId.isEmpty ? const <String>[] : plan.doneMethodIds);
    final selectedMethods =
        methods.where((m) => selectedIds.contains(m.id)).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 12, 30, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TimelineIcon(icon: _iconForBlock(block), isLast: isLast),
          const SizedBox(width: 12),
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: selectedMethods.isEmpty
                    ? null
                    : () => _openMethodCatalog(
                          context,
                          block,
                          methods,
                          initialTab: MethodCatalogSheet.selectedTabLabel,
                        ),
                child: EditorialCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(block.title,
                            style: Theme.of(context).textTheme.titleLarge),
                      ),
                      const SizedBox(width: 8),
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
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.75),
                          ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: selectedMethods.isEmpty
                        ? Text(
                            'Noch keine Methoden ausgewählt.',
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
                              ...selectedMethods.take(3).map(
                                (m) {
                                  final isDone = doneIds.contains(m.id);
                                  return Column(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 6,
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    m.title,
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodySmall
                                                        ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                  ),
                                                  if (m.shortDesc.isNotEmpty)
                                                    Text(
                                                      m.shortDesc,
                                                      style: Theme.of(context)
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
                                                final notifier = ref.read(
                                                    userStateProvider.notifier);
                                                final nextDone =
                                                    List<String>.from(doneIds);
                                                if (isDone) {
                                                  nextDone.remove(m.id);
                                                } else {
                                                  nextDone.add(m.id);
                                                }
                                                notifier.setDayPlanBlock(
                                                  plan.blockId.isEmpty
                                                      ? DayPlanBlock(
                                                          blockId: block.id,
                                                          outcome: null,
                                                          methodIds:
                                                              selectedIds,
                                                          doneMethodIds:
                                                              nextDone,
                                                          done: false,
                                                        )
                                                      : plan.copyWith(
                                                          doneMethodIds:
                                                              nextDone,
                                                        ),
                                                );
                                              },
                                              icon: Icon(
                                                isDone
                                                    ? Icons.check_circle
                                                    : Icons.circle_outlined,
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
                                      const Divider(height: 1),
                                    ],
                                  );
                                },
                              ),
                              if (selectedMethods.length > 3) ...[
                                const SizedBox(height: 4),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    '+${selectedMethods.length - 3} weitere',
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
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () =>
                          _openMethodCatalog(context, block, methods),
                      child: const Text('Methoden hinzufügen'),
                    ),
                  ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
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

void _openMethodCatalog(
  BuildContext context,
  SystemBlock block,
  List<MethodV2> methods, {
  String? initialTab,
}) {
  showBottomCardSheet(
    context: context,
    child: MethodCatalogSheet(
      block: block,
      methods: methods,
      initialTab: initialTab,
    ),
  );
}

class _BlockCatalogSheet extends StatelessWidget {
  const _BlockCatalogSheet({
    required this.blocks,
    required this.activeIds,
    required this.onAdd,
  });

  final List<SystemBlock> blocks;
  final List<String> activeIds;
  final ValueChanged<String> onAdd;

  @override
  Widget build(BuildContext context) {
    final available =
        blocks.where((b) => !activeIds.contains(b.id)).toList()
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
