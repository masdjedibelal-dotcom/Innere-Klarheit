import 'package:flutter/material.dart';

import '../../data/models/method_v2.dart';
import '../../data/models/system_block.dart';

class HabitSheet extends StatelessWidget {
  const HabitSheet({
    super.key,
    required this.habit,
    required this.contentItems,
  });

  final MethodV2 habit;
  final List<MethodV2> contentItems;

  @override
  Widget build(BuildContext context) {
    final grouped = _groupByContentType(contentItems);
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(habit.title, style: Theme.of(context).textTheme.titleLarge),
          if (habit.habitContent.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              habit.habitContent,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color:
                        Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                  ),
            ),
          ],
          if (habit.shortDesc.isNotEmpty &&
              habit.shortDesc != habit.habitContent) ...[
            const SizedBox(height: 8),
            Text(
              habit.shortDesc,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color:
                        Theme.of(context).colorScheme.onSurface.withOpacity(0.75),
                  ),
            ),
          ],
          if (contentItems.isEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Noch kein Inhalt hinterlegt.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.7),
                  ),
            ),
          ] else ...[
            const SizedBox(height: 16),
            ..._buildGroups(context, grouped),
          ],
        ],
      ),
    );
  }
}

class HabitBlockSheet extends StatelessWidget {
  const HabitBlockSheet({
    super.key,
    required this.block,
    required this.habits,
    required this.onHabitTap,
  });

  final SystemBlock block;
  final List<MethodV2> habits;
  final ValueChanged<MethodV2> onHabitTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(block.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (habits.isEmpty)
            const Text('Noch keine Habits verfügbar.')
          else
            ...habits.map(
              (habit) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  habit.title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                subtitle: habit.shortDesc.isEmpty
                    ? null
                    : Text(
                        habit.shortDesc,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => onHabitTap(habit),
              ),
            ),
        ],
      ),
    );
  }
}

class _HabitContentItem extends StatelessWidget {
  const _HabitContentItem({required this.item});

  final MethodV2 item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          if (item.habitContent.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              item.habitContent,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.8),
                  ),
            ),
          ],
          if (item.shortDesc.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              item.shortDesc,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.75),
                  ),
            ),
          ],
          if (item.examples.isNotEmpty) ...[
            const SizedBox(height: 6),
            ...item.examples.map(
              (e) => Text(
                '• $e',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.7),
                    ),
              ),
            ),
          ],
          if (item.steps.isNotEmpty) ...[
            const SizedBox(height: 6),
            ...item.steps.map(
              (s) => Text(
                '• $s',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.7),
                    ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

Map<String, List<MethodV2>> _groupByContentType(List<MethodV2> items) {
  final map = <String, List<MethodV2>>{};
  for (final item in items) {
    final key = item.contentType.trim().toLowerCase();
    final normalized = key.isEmpty ? 'content' : key;
    map.putIfAbsent(normalized, () => []).add(item);
  }
  return map;
}

List<Widget> _buildGroups(
  BuildContext context,
  Map<String, List<MethodV2>> grouped,
) {
  final order = ['questions', 'tips', 'methods', 'examples', 'content'];
  final labels = {
    'questions': 'Fragen',
    'tips': 'Tipps',
    'methods': 'Methoden',
    'examples': 'Beispiele',
    'content': 'Inhalt',
  };
  final widgets = <Widget>[];
  for (final key in order) {
    final items = grouped[key];
    if (items == null || items.isEmpty) continue;
    widgets.add(Text(
      labels[key] ?? key,
      style: Theme.of(context).textTheme.labelLarge,
    ));
    widgets.add(const SizedBox(height: 8));
    widgets.addAll(items.map((item) => _HabitContentItem(item: item)));
    widgets.add(const SizedBox(height: 6));
  }
  return widgets;
}


