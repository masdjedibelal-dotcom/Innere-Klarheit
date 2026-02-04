import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/knowledge_snack.dart';
import '../../state/user_state.dart';
import '../../ui/components/screen_hero.dart';
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
  static const int _pageSize = 10;
  final ScrollController _scrollController = ScrollController();
  final List<KnowledgeSnack> _items = [];
  final List<String> _tags = [];
  int _pageIndex = 0;
  bool _hasMore = true;
  bool _isLoading = false;
  bool _isTagsLoading = false;
  String? _errorText;
  late final ProviderSubscription<UserState> _userStateSub;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userStateProvider);

    return Scaffold(
      appBar: null,
      body: SafeArea(
        child: ListView(
          controller: _scrollController,
          children: [
            ScreenHero(
              title: 'Wissen',
              subtitle:
                  'Kurze Wissenssnacks, die dich zurück in dein System bringen. Filtere nach Themen und speichere, was dich trifft.',
            ),
            _buildFiltersBar(),
            _buildSnackList(context, user),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltersBar() {
    if (_isTagsLoading && _tags.isEmpty) {
      return const SizedBox(height: 56);
    }
    final filterItems = _buildFilters(_tags);
    return _FilterBar(
      filters: filterItems,
      active: activeFilter,
      onChanged: (v) {
        if (v == activeFilter) return;
        setState(() {
          activeFilter = v;
        });
        _loadPage(reset: true);
      },
    );
  }

  Widget _buildSnackList(BuildContext context, UserState user) {
    if (_errorText != null && _items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Text(_errorText!),
      );
    }

    if (_isLoading && _items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Text('Noch kein Inhalt verfügbar.'),
      );
    }

    return Column(
      children: [
        ListView.separated(
          padding: const EdgeInsets.only(bottom: 12),
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: _items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) {
            final snack = _items[i];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
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
                              height: 1.5,
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
        ),
        _buildPaginationControls(),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildPaginationControls() {
    if (!_hasMore && !_isLoading) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TextButton(
              onPressed: _hasMore ? _loadNextPage : null,
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withOpacity(0.7),
                textStyle: Theme.of(context).textTheme.labelLarge,
              ),
              child: const Text('Mehr laden'),
            ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadTags();
    _loadPage(reset: true);
    _userStateSub = ref.listenManual<UserState>(userStateProvider, (prev, next) {
      if (activeFilter != 'saved') return;
      if (prev?.savedKnowledgeSnackIds != next.savedKnowledgeSnackIds) {
        _loadPage(reset: true);
      }
    });
  }

  @override
  void dispose() {
    _userStateSub.close();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadTags() async {
    if (_isTagsLoading) return;
    setState(() {
      _isTagsLoading = true;
    });
    final result = await ref.read(knowledgeRepoProvider).fetchSnackTags();
    if (!mounted) return;
    if (result.isSuccess) {
      setState(() {
        _tags
          ..clear()
          ..addAll(result.data!);
        _isTagsLoading = false;
      });
    } else {
      setState(() {
        _isTagsLoading = false;
      });
    }
  }

  Future<void> _loadNextPage() async {
    if (_isLoading || !_hasMore) return;
    await _loadPage();
  }

  Future<void> _loadPage({bool reset = false}) async {
    if (_isLoading) return;
    if (reset) {
      setState(() {
        _pageIndex = 0;
        _hasMore = true;
        _errorText = null;
        _items.clear();
      });
    }
    if (!_hasMore) return;
    setState(() {
      _isLoading = true;
    });

    final offset = _pageIndex * _pageSize;
    final user = ref.read(userStateProvider);
    List<String>? ids;
    String? tag;
    if (activeFilter == 'saved') {
      ids = user.savedKnowledgeSnackIds.toList();
      if (ids.isEmpty) {
        setState(() {
          _isLoading = false;
          _hasMore = false;
        });
        return;
      }
    } else if (activeFilter != 'alle') {
      tag = activeFilter;
    }

    final result = await ref.read(knowledgeRepoProvider).fetchSnacksPage(
          offset: offset,
          limit: _pageSize,
          tag: tag,
          ids: ids,
        );
    if (!mounted) return;
    if (result.isSuccess) {
      final page = result.data!;
      setState(() {
        _items.addAll(page.items);
        _hasMore = page.hasMore;
        _pageIndex += 1;
        _isLoading = false;
      });
    } else {
      setState(() {
        _errorText = 'Wissenssnacks konnten nicht geladen werden.';
        _isLoading = false;
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
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
        scrollDirection: Axis.horizontal,
        itemBuilder: (_, i) {
          final f = filters[i];
          final selected = f.value == active;
          final scheme = Theme.of(context).colorScheme;
          return ChoiceChip(
            label: Text(f.label),
            selected: selected,
            onSelected: (_) => onChanged(f.value),
            backgroundColor: scheme.surfaceVariant,
            selectedColor: scheme.primary.withOpacity(0.16),
            labelStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
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
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: filters.length,
      ),
    );
  }
}

List<_FilterItem> _buildFilters(List<String> tags) {
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
