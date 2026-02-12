import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../content/app_copy.dart';
import '../../data/models/catalog_item.dart';
import '../../data/models/inner_catalog_detail.dart';
import '../../data/models/inner_item.dart';
import '../../state/inner_catalog_state.dart';
import '../../ui/components/screen_hero.dart';
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
    return Scaffold(
      appBar: null,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScreenHero(
                title: 'Innen',
                subtitle:
                    'Stärken, Werte, Antreiber und Persönlichkeit: wähle aus, was dich beschreibt – und nutze es als Orientierung im Alltag.',
              ),
              _TabChipBar(
                controller: _tab,
                tabs: const ['Stärken', 'Persönlichkeit', 'Werte', 'Antreiber'],
              ),
              _buildActiveCatalog(
                context,
                strengthsAsync: strengthsAsync,
                valuesAsync: valuesAsync,
                driversAsync: driversAsync,
                personalityAsync: personalityAsync,
                selectedStrengthsAsync: selectedStrengthsAsync,
                selectedValuesAsync: selectedValuesAsync,
                selectedDriversAsync: selectedDriversAsync,
                selectedPersonalityAsync: selectedPersonalityAsync,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveCatalog(
    BuildContext context, {
    required AsyncValue<List<InnerCatalogDetail>> strengthsAsync,
    required AsyncValue<List<InnerCatalogDetail>> valuesAsync,
    required AsyncValue<List<InnerCatalogDetail>> driversAsync,
    required AsyncValue<List<InnerCatalogDetail>> personalityAsync,
    required AsyncValue<List<CatalogItem>> selectedStrengthsAsync,
    required AsyncValue<List<CatalogItem>> selectedValuesAsync,
    required AsyncValue<List<CatalogItem>> selectedDriversAsync,
    required AsyncValue<List<CatalogItem>> selectedPersonalityAsync,
  }) {
    switch (_tab.index) {
      case 0:
        return _buildCatalogList(
          context,
          itemsAsync: strengthsAsync,
          selectedAsync: selectedStrengthsAsync,
          type: InnerType.staerken,
          kind: _CatalogKind.strength,
        );
      case 1:
        return _buildCatalogList(
          context,
          itemsAsync: personalityAsync,
          selectedAsync: selectedPersonalityAsync,
          type: InnerType.persoenlichkeit,
          kind: _CatalogKind.personality,
        );
      case 2:
        return _buildCatalogList(
          context,
          itemsAsync: valuesAsync,
          selectedAsync: selectedValuesAsync,
          type: InnerType.werte,
          kind: _CatalogKind.value,
        );
      case 3:
        return _buildCatalogList(
          context,
          itemsAsync: driversAsync,
          selectedAsync: selectedDriversAsync,
          type: InnerType.antreiber,
          kind: _CatalogKind.driver,
        );
      default:
        return const SizedBox.shrink();
    }
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
          return const Padding(
            padding: EdgeInsets.fromLTRB(30, 12, 30, 24),
            child: Text('Noch kein Inhalt verfügbar.'),
          );
        }
        final selectedIds = selectedAsync.asData?.value
                .map((e) => e.id)
                .toSet() ??
            <String>{};
        return Padding(
          padding: const EdgeInsets.fromLTRB(30, 12, 30, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const Padding(
        padding: EdgeInsets.fromLTRB(30, 12, 30, 24),
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
    final maxHeight = MediaQuery.of(context).size.height * 0.5;
    showBottomCardSheet(
      context: context,
      child: SizedBox(
        height: maxHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 6),
                    if (item.description.isNotEmpty)
                      Text(
                        item.description,
                        style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                      ),
                    ..._buildDetailSections(item, kind, theme),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
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
    void addBullets(String title, List<String> lines) {
      if (lines.isEmpty) return;
      sections.add(const SizedBox(height: 10));
      sections.add(_sectionTitle(title, theme));
      sections.add(const SizedBox(height: 6));
      sections.addAll(lines.map((e) => _bulletItem(e, theme)));
    }

    void addChips(String title, List<String> lines) {
      if (lines.isEmpty) return;
      sections.add(const SizedBox(height: 10));
      sections.add(_sectionTitle(title, theme));
      sections.add(const SizedBox(height: 6));
      sections.add(_chipWrap(lines, theme));
    }

    void addTextSection(String title, String body) {
      if (body.isEmpty) return;
      sections.add(const SizedBox(height: 10));
      sections.add(_sectionTitle(title, theme));
      sections.add(const SizedBox(height: 6));
      sections.add(Text(body, style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)));
    }

    void addReflection(String title, List<String> questions) {
      if (questions.isEmpty) return;
      sections.add(const SizedBox(height: 10));
      sections.add(_sectionTitle(title, theme));
      sections.add(const SizedBox(height: 6));
      sections.addAll(questions.map((q) => _reflectionCard(q, theme)));
    }

    switch (kind) {
      case _CatalogKind.strength:
        addBullets('Beispiele', item.examples);
        addChips('Einsatzfelder', item.useCases);
        addReflection('Reflexionsfrage',
            item.reflectionQuestion.isEmpty ? [] : [item.reflectionQuestion]);
        break;
      case _CatalogKind.value:
        addBullets('Beispiele', item.examples);
        addReflection('Reflexionsfrage',
            item.reflectionQuestion.isEmpty ? [] : [item.reflectionQuestion]);
        break;
      case _CatalogKind.driver:
        addTextSection('Schutzfunktion', item.protectionFunction);
        addTextSection('Schattenseite', item.shadowSide);
        addTextSection('Neurahmung', item.reframe);
        addBullets('Beispiele', item.examples);
        addReflection('Reflexionsfragen', item.reflectionQuestions);
        break;
      case _CatalogKind.personality:
        addChips('Hilft bei', item.helpsWith);
        addChips('Achte auf', item.watchOutFor);
        addReflection('Reflexionsfrage',
            item.reflectionQuestion.isEmpty ? [] : [item.reflectionQuestion]);
        break;
    }
    return sections;
  }

  Widget _sectionTitle(String title, ThemeData theme) {
    return Text(title, style: theme.textTheme.labelLarge);
  }

  Widget _bulletItem(String text, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        '• $text',
        style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
      ),
    );
  }

  Widget _chipWrap(List<String> items, ThemeData theme) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: items
          .map(
            (item) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.7),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                item,
                style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.75),
                    ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _reflectionCard(String text, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium?.copyWith(
              fontStyle: FontStyle.italic,
              height: 1.4,
            ),
      ),
    );
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
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
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
      height: 56,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
        scrollDirection: Axis.horizontal,
        itemBuilder: (_, i) {
          final selected = controller.index == i;
          final scheme = Theme.of(context).colorScheme;
          return ChoiceChip(
            label: Text(tabs[i]),
            selected: selected,
            onSelected: (_) => controller.animateTo(i),
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
