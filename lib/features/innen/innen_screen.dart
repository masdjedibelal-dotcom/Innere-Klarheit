import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../content/app_copy.dart';
import '../../data/models/catalog_item.dart';
import '../../data/models/inner_catalog_detail.dart';
import '../../data/models/inner_item.dart';
import '../../state/inner_catalog_state.dart';
import '../../widgets/bottom_sheet/bottom_card_sheet.dart';
import '../../widgets/common/selection_list_row.dart';

class InnenScreen extends ConsumerStatefulWidget {
  const InnenScreen({super.key});

  @override
  ConsumerState<InnenScreen> createState() => _InnenScreenState();
}

class _InnenScreenState extends ConsumerState<InnenScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final Map<String, int> strengthLevels = {};
  final Map<String, int> personalityLevels = {};
  final Set<String> expandedPersonalityIds = {};

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
    _tab.addListener(() {
      if (!mounted) return;
      if (!_tab.indexIsChanging) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final strengthsAsync = ref.watch(innerStrengthsDetailProvider);
    final valuesAsync = ref.watch(innerValuesDetailProvider);
    final driversAsync = ref.watch(innerDriversDetailProvider);
    final personalityAsync = ref.watch(innerPersonalityDetailProvider);
    final selectedStrengthsAsync = ref.watch(userSelectedStrengthsProvider);
    final selectedValuesAsync = ref.watch(userSelectedValuesProvider);
    final selectedDriversAsync = ref.watch(userSelectedDriversProvider);
    final selectedPersonalityAsync = ref.watch(userSelectedPersonalityProvider);
    final screenIntro = copy('inner.intro');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Innen'),
        actions: [
          IconButton(
            onPressed: () => context.push('/profil'),
            icon: const Icon(Icons.person_outline),
            tooltip: 'Profil',
          ),
        ],
      ),
      body: Column(
        children: [
          if (screenIntro.title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _IntroBlock(copy: screenIntro),
            ),
          _TabChipBar(
            controller: _tab,
            tabs: const ['Stärken', 'Persönlichkeit', 'Werte', 'Antreiber'],
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _buildCatalogList(
                  context,
                  itemsAsync: strengthsAsync,
                  selectedAsync: selectedStrengthsAsync,
                  type: InnerType.staerken,
                  kind: _CatalogKind.strength,
                ),
                _buildCatalogList(
                  context,
                  itemsAsync: personalityAsync,
                  selectedAsync: selectedPersonalityAsync,
                  type: InnerType.persoenlichkeit,
                  kind: _CatalogKind.personality,
                ),
                _buildCatalogList(
                  context,
                  itemsAsync: valuesAsync,
                  selectedAsync: selectedValuesAsync,
                  type: InnerType.werte,
                  kind: _CatalogKind.value,
                ),
                _buildCatalogList(
                  context,
                  itemsAsync: driversAsync,
                  selectedAsync: selectedDriversAsync,
                  type: InnerType.antreiber,
                  kind: _CatalogKind.driver,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCatalogList(
    BuildContext context, {
    required AsyncValue<List<InnerCatalogDetail>> itemsAsync,
    required AsyncValue<List<CatalogItem>> selectedAsync,
    required InnerType type,
    required _CatalogKind kind,
  }) {
    final intro = copy(_introKeyForType(type));

    return itemsAsync.when(
      data: (items) {
        if (items.isEmpty) {
          return const Center(
            child: Text('Noch kein Inhalt verfügbar.'),
          );
        }
        final selectedIds = selectedAsync.asData?.value
                .map((e) => e.id)
                .toSet() ??
            <String>{};
        return ListView(
          padding: const EdgeInsets.only(top: 12, bottom: 24),
          children: [
            if (intro.title.isNotEmpty) _IntroBlock(copy: intro),
            ...items.map((e) {
              final selected = selectedIds.contains(e.id);
              return Column(
                children: [
                  SelectionListRow(
                    title: e.title,
                    subtitle: e.description,
                    selected: selected,
                    footer: _levelFooter(
                      kind: kind,
                      itemId: e.id,
                      expanded: expandedPersonalityIds.contains(e.id),
                    ),
                    trailing: _buildTrailing(
                      kind: kind,
                      selected: selected,
                      isExpanded: expandedPersonalityIds.contains(e.id),
                      onToggleExpand: () {
                        setState(() {
                          if (expandedPersonalityIds.contains(e.id)) {
                            expandedPersonalityIds.remove(e.id);
                          } else {
                            expandedPersonalityIds.add(e.id);
                          }
                        });
                      },
                    ),
                    onTap: () => _openCatalogInfo(
                      context,
                      item: e,
                      selected: selected,
                      selectedIds: selectedIds,
                      kind: kind,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              );
            }),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(
        child: Text('Innen-Daten konnten nicht geladen werden.'),
      ),
    );
  }

  void _openCatalogInfo(
    BuildContext context, {
    required InnerCatalogDetail item,
    required bool selected,
    required Set<String> selectedIds,
    required _CatalogKind kind,
  }) {
    final theme = Theme.of(context);
    showBottomCardSheet(
      context: context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          if (item.description.isNotEmpty) Text(item.description),
          ..._buildDetailSections(item, kind, theme),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () async {
                    await _toggleSelection(
                      context,
                      kind: kind,
                      itemId: item.id,
                      selectedIds: selectedIds,
                    );
                    Navigator.pop(context);
                  },
                  child: Text(selected ? 'Entfernen' : 'Auswählen'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _toggleSelection(
    BuildContext context, {
    required _CatalogKind kind,
    required String itemId,
    required Set<String> selectedIds,
  }) async {
    final next = Set<String>.from(selectedIds);
    if (!next.add(itemId)) {
      next.remove(itemId);
    }
    final repo = ref.read(innerSelectionsRepositoryProvider);
    final ids = next.toList();
    dynamic result;
    switch (kind) {
      case _CatalogKind.strength:
        result = await repo.upsertSelectedStrengths(ids);
        ref.invalidate(userSelectedStrengthsProvider);
        break;
      case _CatalogKind.value:
        result = await repo.upsertSelectedValues(ids);
        ref.invalidate(userSelectedValuesProvider);
        break;
      case _CatalogKind.driver:
        result = await repo.upsertSelectedDrivers(ids);
        ref.invalidate(userSelectedDriversProvider);
        break;
      case _CatalogKind.personality:
        result = await repo.upsertSelectedPersonality(ids);
        ref.invalidate(userSelectedPersonalityProvider);
        break;
    }
    if (result == null || result.isSuccess == true) return;
    final msg = result.error?.message == 'Not logged in'
        ? 'Bitte anmelden, um auszuwählen.'
        : 'Auswahl konnte nicht gespeichert werden.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  List<Widget> _buildDetailSections(
      InnerCatalogDetail item, _CatalogKind kind, ThemeData theme) {
    final sections = <Widget>[];
    void addSection(String title, List<String> lines) {
      if (lines.isEmpty) return;
      sections.add(const SizedBox(height: 12));
      sections.add(Text(title, style: theme.textTheme.labelLarge));
      sections.add(const SizedBox(height: 6));
      sections.addAll(lines.map((e) => Text('• $e')));
    }

    void addTextSection(String title, String body) {
      if (body.isEmpty) return;
      sections.add(const SizedBox(height: 12));
      sections.add(Text(title, style: theme.textTheme.labelLarge));
      sections.add(const SizedBox(height: 6));
      sections.add(Text(body));
    }

    switch (kind) {
      case _CatalogKind.strength:
        addSection('Beispiele', item.examples);
        addSection('Einsatzfelder', item.useCases);
        addTextSection('Reflexionsfrage', item.reflectionQuestion);
        break;
      case _CatalogKind.value:
        addSection('Beispiele', item.examples);
        addTextSection('Reflexionsfrage', item.reflectionQuestion);
        break;
      case _CatalogKind.driver:
        addTextSection('Schutzfunktion', item.protectionFunction);
        addTextSection('Schattenseite', item.shadowSide);
        addTextSection('Neurahmung', item.reframe);
        addSection('Beispiele', item.examples);
        addSection('Reflexionsfragen', item.reflectionQuestions);
        break;
      case _CatalogKind.personality:
        addSection('Hilft bei', item.helpsWith);
        addSection('Achte auf', item.watchOutFor);
        addTextSection('Reflexionsfrage', item.reflectionQuestion);
        break;
    }
    return sections;
  }

  Widget? _levelFooter({
    required _CatalogKind kind,
    required String itemId,
    required bool expanded,
  }) {
    if (kind != _CatalogKind.personality) {
      return null;
    }

    final current = personalityLevels[itemId] ?? 1;
    final label = _levelLabel(current);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Ausprägung',
                style: Theme.of(context).textTheme.labelSmall),
            const Spacer(),
            Text(label, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
        if (expanded)
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            ),
            child: Slider(
              value: current.toDouble(),
              min: 0,
              max: 2,
              divisions: 2,
              onChanged: (v) {
                setState(() {
                  personalityLevels[itemId] = v.round();
                });
              },
            ),
          ),
      ],
    );
  }

  String _levelLabel(int value) {
    switch (value) {
      case 0:
        return 'Niedrig';
      case 1:
        return 'Mittel';
      case 2:
        return 'Hoch';
      default:
        return 'Mittel';
    }
  }

  Widget _buildTrailing({
    required _CatalogKind kind,
    required bool selected,
    required bool isExpanded,
    required VoidCallback onToggleExpand,
  }) {
    if (kind == _CatalogKind.personality) {
      return IconButton(
        icon: Icon(
          isExpanded ? Icons.expand_less : Icons.tune,
        ),
        onPressed: onToggleExpand,
      );
    }
    if (kind == _CatalogKind.strength ||
        kind == _CatalogKind.value ||
        kind == _CatalogKind.driver) {
      return Icon(
        selected ? Icons.check_circle_outline : Icons.add_circle_outline,
        color: selected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).iconTheme.color,
      );
    }
    return const SizedBox.shrink();
  }
}

class _IntroBlock extends StatelessWidget {
  const _IntroBlock({required this.copy});
  final AppCopyItem copy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(copy.title, style: Theme.of(context).textTheme.titleLarge),
          if (copy.subtitle.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              copy.subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.8),
                  ),
            ),
          ],
          if (copy.body.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              copy.body,
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
    );
  }
}

class _TabChipBar extends StatelessWidget {
  const _TabChipBar({required this.controller, required this.tabs});

  final TabController controller;
  final List<String> tabs;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        scrollDirection: Axis.horizontal,
        itemBuilder: (_, i) {
          final selected = controller.index == i;
          return ChoiceChip(
            label: Text(tabs[i]),
            selected: selected,
            onSelected: (_) => controller.animateTo(i),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: tabs.length,
      ),
    );
  }
}

String _introKeyForType(InnerType type) {
  switch (type) {
    case InnerType.werte:
      return 'inner.tab.values';
    case InnerType.persoenlichkeit:
      return 'inner.tab.personality';
    case InnerType.antreiber:
      return 'inner.tab.drivers';
    case InnerType.staerken:
      return 'inner.tab.strengths';
  }
}

enum _CatalogKind { strength, value, driver, personality }
