import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/snacks_state.dart';
import '../../widgets/common/editorial_card.dart';
import '../../widgets/common/generated_media.dart';
import '../../widgets/common/knowledge_snack_sheet.dart';

class SnacksListScreen extends ConsumerStatefulWidget {
  const SnacksListScreen({super.key});

  @override
  ConsumerState<SnacksListScreen> createState() => _SnacksListScreenState();
}

class _SnacksListScreenState extends ConsumerState<SnacksListScreen> {
  String activeFilter = 'Alle';

  @override
  Widget build(BuildContext context) {
    final snacksAsync = ref.watch(snacksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Snacks'),
      ),
      body: snacksAsync.when(
        data: (snacks) {
          final tags = snacks
              .expand((s) => s.tags)
              .toSet()
              .toList()
            ..sort();
          final filters = ['Alle', ...tags];
          final filtered = snacks.where((s) {
            if (activeFilter == 'Alle') return true;
            return s.tags.contains(activeFilter);
          }).toList();

          return Column(
            children: [
              SizedBox(
                height: 56,
                child: ListView.separated(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  scrollDirection: Axis.horizontal,
                  itemBuilder: (_, i) {
                    final f = filters[i];
                    final selected = f == activeFilter;
                    final scheme = Theme.of(context).colorScheme;
                    return ChoiceChip(
                      label: Text(f),
                      selected: selected,
                      onSelected: (_) => setState(() => activeFilter = f),
                      backgroundColor: scheme.surfaceVariant,
                      selectedColor: scheme.primary.withOpacity(0.16),
                      labelStyle:
                          Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: selected
                                    ? scheme.primary
                                    : scheme.onSurface.withOpacity(0.7),
                              ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: selected
                              ? scheme.primary.withOpacity(0.35)
                              : Colors.transparent,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemCount: filters.length,
                ),
              ),
              Expanded(
                child: ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  itemBuilder: (_, i) {
                    final snack = filtered[i];
                    return InkWell(
                      onTap: () => showKnowledgeSnackSheet(
                        context: context,
                        snack: snack,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      child: EditorialCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GeneratedMedia(
                              seed: snack.id,
                              height: 120,
                              borderRadius: 16,
                              icon: Icons.chrome_reader_mode_outlined,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              snack.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              snack.preview,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
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
                        ),
                      ),
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemCount: filtered.length,
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(
          child: Text('Snacks konnten nicht geladen werden.'),
        ),
      ),
    );
  }
}

