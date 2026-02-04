import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/method_v2.dart';
import '../../data/models/system_block.dart';
import '../../state/user_state.dart';
import '../../widgets/common/tag_chip.dart';

class MethodCatalogSheet extends ConsumerStatefulWidget {
  const MethodCatalogSheet({
    super.key,
    required this.block,
    required this.methods,
    this.initialTab,
  });

  static const allTabLabel = 'Alle';
  static const selectedTabLabel = 'Ausgewählte';

  final SystemBlock block;
  final List<MethodV2> methods;
  final String? initialTab;

  @override
  ConsumerState<MethodCatalogSheet> createState() =>
      _MethodCatalogSheetState();
}

class _MethodCatalogSheetState extends ConsumerState<MethodCatalogSheet> {
  String query = '';
  static const _allTab = MethodCatalogSheet.allTabLabel;
  static const _selectedTab = MethodCatalogSheet.selectedTabLabel;
  late String _selectedCategory;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialTab ?? _allTab;
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userStateProvider);
    final selectedIds = user.todayPlan[widget.block.id]?.methodIds ?? const [];
    final base = widget.methods.where((m) {
      if (!m.contexts.contains(widget.block.key)) return false;
      if (query.trim().isEmpty) return true;
      final q = query.toLowerCase();
      return m.title.toLowerCase().contains(q) ||
          m.shortDesc.toLowerCase().contains(q) ||
          m.category.toLowerCase().contains(q);
    }).toList();

    final categories = base
        .map((m) => m.category.trim())
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final tabs = [_allTab, _selectedTab, ...categories];
    if (!tabs.contains(_selectedCategory)) {
      _selectedCategory = _allTab;
    }
    final selectedMethods =
        base.where((m) => selectedIds.contains(m.id)).toList();

    Widget buildList(List<MethodV2> list) {
      if (list.isEmpty) {
        return Center(
          child: Text(
            _selectedCategory == _selectedTab
                ? 'Noch keine ausgewählten Methoden.'
                : 'Keine Methoden gefunden.',
          ),
        );
      }
      return ListView.separated(
        padding: const EdgeInsets.only(bottom: 8),
        itemCount: list.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final m = list[i];
          final selected = selectedIds.contains(m.id);
          final scheme = Theme.of(context).colorScheme;
          return _MethodRow(
            method: m,
            showExamples: true,
            trailing: Icon(
              selected ? Icons.check_circle_outline : Icons.add_circle_outline,
              color: selected ? scheme.primary : scheme.onSurface.withOpacity(0.45),
            ),
            highlight: selected,
            onTap: () {
              final notifier = ref.read(userStateProvider.notifier);
              final current = user.todayPlan[widget.block.id] ??
                  DayPlanBlock(
                    blockId: widget.block.id,
                    outcome: null,
                    methodIds: const [],
                    doneMethodIds: const [],
                    done: false,
                  );
              final next = List<String>.from(current.methodIds);
              final nextDone = List<String>.from(current.doneMethodIds);
              if (selected) {
                next.remove(m.id);
                nextDone.remove(m.id);
              } else {
                next.add(m.id);
              }
              notifier.setDayPlanBlock(
                current.copyWith(
                  methodIds: next,
                  doneMethodIds: nextDone,
                ),
              );
            },
          );
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.block.title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        TextField(
          decoration: const InputDecoration(
            hintText: 'Methoden filtern …',
            border: OutlineInputBorder(),
          ),
          onChanged: (v) => setState(() => query = v),
        ),
        const SizedBox(height: 10),
        _ChipTabBar(
          tabs: tabs,
          selected: _selectedCategory,
          onSelected: (v) => setState(() => _selectedCategory = v),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: _selectedCategory == _allTab
              ? buildList(base)
              : _selectedCategory == _selectedTab
                  ? buildList(selectedMethods)
                  : buildList(
                      base
                          .where((m) =>
                              m.category.trim().toLowerCase() ==
                              _selectedCategory.toLowerCase())
                          .toList(),
                    ),
        ),
      ],
    );
  }
}

class _ChipTabBar extends StatelessWidget {
  const _ChipTabBar({
    required this.tabs,
    required this.selected,
    required this.onSelected,
  });

  final List<String> tabs;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
        scrollDirection: Axis.horizontal,
        itemBuilder: (_, i) {
          final label = tabs[i];
          final scheme = Theme.of(context).colorScheme;
          final isSelected = label == selected;
          return ChoiceChip(
            label: Text(label),
            selected: isSelected,
            onSelected: (_) => onSelected(label),
            backgroundColor: scheme.surfaceVariant,
            selectedColor: scheme.primary.withOpacity(0.16),
            labelStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: isSelected
                      ? scheme.primary
                      : scheme.onSurface.withOpacity(0.7),
                ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: isSelected
                    ? scheme.primary.withOpacity(0.35)
                    : Colors.transparent,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: tabs.length,
      ),
    );
  }
}

class _MethodRow extends StatelessWidget {
  const _MethodRow({
    required this.method,
    this.showExamples = false,
    this.trailing,
    this.highlight = false,
    this.onTap,
  });

  final MethodV2 method;
  final bool showExamples;
  final Widget? trailing;
  final bool highlight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: highlight ? scheme.primary.withOpacity(0.06) : null,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    method.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: highlight
                              ? scheme.onSurface
                              : scheme.onSurface,
                        ),
                  ),
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

