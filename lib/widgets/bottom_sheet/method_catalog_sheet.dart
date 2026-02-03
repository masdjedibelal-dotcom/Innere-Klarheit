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
  });

  final SystemBlock block;
  final List<MethodV2> methods;

  @override
  ConsumerState<MethodCatalogSheet> createState() =>
      _MethodCatalogSheetState();
}

class _MethodCatalogSheetState extends ConsumerState<MethodCatalogSheet> {
  String query = '';
  static const _allTab = 'Alle';
  String _selectedCategory = _allTab;

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
    final tabs = [_allTab, ...categories];
    if (!tabs.contains(_selectedCategory)) {
      _selectedCategory = _allTab;
    }

    Widget buildList(List<MethodV2> list) {
      if (list.isEmpty) {
        return const Center(child: Text('Keine Methoden gefunden.'));
      }
      return ListView.separated(
        padding: const EdgeInsets.only(bottom: 8),
        itemCount: list.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final m = list[i];
          final selected = selectedIds.contains(m.id);
          return _MethodRow(
            method: m,
            showExamples: true,
            trailing: Icon(
              selected ? Icons.check_circle_outline : Icons.add_circle_outline,
            ),
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
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
        scrollDirection: Axis.horizontal,
        itemBuilder: (_, i) {
          final label = tabs[i];
          final scheme = Theme.of(context).colorScheme;
          return ChoiceChip(
            label: Text(label),
            selected: label == selected,
            onSelected: (_) => onSelected(label),
            backgroundColor: scheme.surfaceVariant,
            selectedColor: scheme.surfaceVariant.withOpacity(0.8),
            labelStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurface.withOpacity(0.7),
                ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.transparent),
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

