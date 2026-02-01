import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../content/app_copy.dart';
import '../../state/user_state.dart';
import '../../widgets/common/editorial_card.dart';
import '../../widgets/common/secondary_button.dart';
import '../../widgets/common/generated_media.dart';
import '../../widgets/common/knowledge_snack_sheet.dart';

class WissenScreen extends ConsumerStatefulWidget {
  const WissenScreen({super.key});

  @override
  ConsumerState<WissenScreen> createState() => _WissenScreenState();
}

class _WissenScreenState extends ConsumerState<WissenScreen> {
  String activeFilter = 'alle';
  static const int _pageSize = 5;
  int _visibleCount = _pageSize;
  final ScrollController _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    final knowledgeAsync = ref.watch(knowledgeProvider);
    final user = ref.watch(userStateProvider);
    final intro = copy('knowledge.feed');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wissen'),
        actions: [
          IconButton(
            onPressed: () => context.push('/profil'),
            icon: const Icon(Icons.person_outline),
            tooltip: 'Profil',
          ),
        ],
      ),
      body: ListView(
        controller: _scrollController,
        children: [
          if (intro.title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(intro.title,
                      style: Theme.of(context).textTheme.titleLarge),
                  if (intro.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      intro.subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.8),
                          ),
                    ),
                  ],
                  if (intro.body.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      intro.body,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.75),
                          ),
                    ),
                  ],
                ],
              ),
            ),
          knowledgeAsync.when(
            data: (items) {
              final filterItems = _buildFilters(items);
              return Column(
                children: [
                  _FilterBar(
                    filters: filterItems,
                    active: activeFilter,
                    onChanged: (v) => setState(() {
                      activeFilter = v;
                      _visibleCount = _pageSize;
                    }),
                  ),
                  _buildSnackList(context, user, items),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Center(
              child: Text('Wissenssnacks konnten nicht geladen werden.'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSnackList(
      BuildContext context, UserState user, List<dynamic> items) {
              final filtered = items.where((e) {
                if (activeFilter == 'alle') return true;
                if (activeFilter == 'saved') {
                  return user.savedKnowledgeSnackIds.contains(e.id);
                }
                return e.tags.contains(activeFilter);
              }).toList();

              if (filtered.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: Text('Noch kein Inhalt verfügbar.'),
                );
              }

    final visible = filtered.take(_visibleCount).toList();

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 24),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: visible.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final snack = visible[i];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GestureDetector(
            onTap: () => showKnowledgeSnackSheet(
              context: context,
              snack: snack,
            ),
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
                  Text(snack.title,
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 6),
                  Text(
                    snack.preview,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.75),
                        ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        '${snack.readTimeMinutes} Min',
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
                      const Spacer(),
                      SecondaryButton(
                        label: 'Speichern',
                        onPressed: () => ref
                            .read(userStateProvider.notifier)
                            .toggleSnackSaved(snack.id),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 120) {
      setState(() {
        _visibleCount += _pageSize;
      });
    }
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.filters,
    required this.active,
    required this.onChanged,
  });

  final List<_FilterItem> filters;
  final String active;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        scrollDirection: Axis.horizontal,
        itemBuilder: (_, i) {
          final f = filters[i];
          final selected = f.value == active;
          return ChoiceChip(
            label: Text(f.label),
            selected: selected,
            onSelected: (_) => onChanged(f.value),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: filters.length,
      ),
    );
  }
}

List<_FilterItem> _buildFilters(List<dynamic> items) {
  final tags = <String>{};
  for (final item in items) {
    if (item.tags is List) {
      tags.addAll((item.tags as List).map((e) => e.toString()));
    }
  }
  final sorted = tags.toList()..sort();
  return <_FilterItem>[
    const _FilterItem('Alle', 'alle'),
    const _FilterItem('Gespeichert', 'saved'),
    ...sorted.map((t) => _FilterItem(_labelize(t), t)),
  ];
}

String _labelize(String tag) {
  if (tag.isEmpty) return tag;
  return tag[0].toUpperCase() + tag.substring(1);
}

class _FilterItem {
  final String label;
  final String value;

  const _FilterItem(this.label, this.value);
}
