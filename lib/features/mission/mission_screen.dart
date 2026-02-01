import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/catalog_item.dart';
import '../../data/models/mission_template.dart';
import '../../state/mission_state.dart';
import '../../widgets/common/primary_button.dart';
import '../../widgets/common/secondary_button.dart';

class MissionScreen extends ConsumerStatefulWidget {
  const MissionScreen({super.key});

  @override
  ConsumerState<MissionScreen> createState() => _MissionScreenState();
}

class _MissionScreenState extends ConsumerState<MissionScreen> {
  MissionTemplate? selectedTemplate;
  String? strength;
  String? value;
  String? value2;
  String? target;
  String? activity;
  String? impact;
  bool showBuilder = true;
  bool _defaultsInitialized = false;

  @override
  Widget build(BuildContext context) {
    final templatesAsync = ref.watch(missionTemplatesProvider);
    final strengthsAsync = ref.watch(userStrengthsProvider);
    final valuesAsync = ref.watch(userValuesProvider);
    final strengthsCatalogAsync = ref.watch(innerStrengthsCatalogProvider);
    final valuesCatalogAsync = ref.watch(innerValuesCatalogProvider);
    final driversCatalogAsync = ref.watch(innerDriversCatalogProvider);
    final personalityCatalogAsync = ref.watch(innerPersonalityCatalogProvider);
    final pillarsCatalogAsync = ref.watch(identityPillarsCatalogProvider);
    final statementAsync = ref.watch(userMissionStatementProvider);

    _initDefaults(
      templatesAsync: templatesAsync,
      strengthsAsync: strengthsAsync,
      valuesAsync: valuesAsync,
      strengthsCatalogAsync: strengthsCatalogAsync,
      valuesCatalogAsync: valuesCatalogAsync,
      driversCatalogAsync: driversCatalogAsync,
      personalityCatalogAsync: personalityCatalogAsync,
      pillarsCatalogAsync: pillarsCatalogAsync,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mission'),
        actions: [
          IconButton(
            onPressed: () => context.push('/profil'),
            icon: const Icon(Icons.person_outline),
            tooltip: 'Profil',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text(
              'Deine Mission ist ein Satz, der dich ruhig ausrichtet. Ohne Druck – nur Klarheit.',
            ),
          ),
          statementAsync.when(
            data: (saved) {
              final hasSaved = saved != null;
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: _PreviewCard(
                  sentence: _buildSentence(
                    template: selectedTemplate?.template ?? '',
                  ),
                  savedSentence: hasSaved ? saved.statement : null,
                  onEdit: hasSaved
                      ? () => setState(() => showBuilder = true)
                      : null,
                  onCopy: hasSaved
                      ? () {
                          Clipboard.setData(
                            ClipboardData(text: saved.statement),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Kopiert.')),
                          );
                        }
                      : null,
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: _SelectionBox(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  templatesAsync.when(
                    data: (templates) {
                      if (templates.isEmpty) {
                        return const Text('Noch keine Templates verfügbar.');
                      }
                      selectedTemplate ??= templates.first;
                      return _TemplateCarousel(
                        templates: templates,
                        selectedId: selectedTemplate?.id,
                        onSelect: (t) => setState(() => selectedTemplate = t),
                      );
                    },
                    loading: () => const Center(
                        child: Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(),
                    )),
                    error: (_, __) =>
                        const Text('Templates konnten nicht geladen werden.'),
                  ),
                  if (showBuilder) ...[
                    const SizedBox(height: 8),
                    _buildOptionSection(
                      context,
                      title: 'Stärke',
                      value: strength,
                      catalogAsync: strengthsCatalogAsync,
                      selectionAsync: strengthsAsync,
                      emptyText: 'Keine Stärken verfügbar.',
                      onSelect: (v) => setState(() => strength = v),
                    ),
                    _buildOptionSection(
                      context,
                      title: 'Wert',
                      value: value,
                      catalogAsync: valuesCatalogAsync,
                      selectionAsync: valuesAsync,
                      emptyText: 'Keine Werte verfügbar.',
                      onSelect: (v) => setState(() => value = v),
                    ),
                    _buildOptionSection(
                      context,
                      title: 'Wert 2',
                      value: value2,
                      catalogAsync: valuesCatalogAsync,
                      selectionAsync: valuesAsync,
                      emptyText: 'Keine Werte verfügbar.',
                      onSelect: (v) => setState(() => value2 = v),
                    ),
                    pillarsCatalogAsync.when(
                      data: (options) {
                        return _buildChipSection(
                          title: 'Ziel',
                          value: target,
                          options: options.map((e) => e.title).toList(),
                          onSelect: (v) => setState(() => target = v),
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) =>
                          const Text('Ziele konnten nicht geladen werden.'),
                    ),
                    personalityCatalogAsync.when(
                      data: (options) {
                        return _buildChipSection(
                          title: 'Aktivität',
                          value: activity,
                          options: options.map((e) => e.title).toList(),
                          onSelect: (v) => setState(() => activity = v),
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) =>
                          const Text('Aktivitäten konnten nicht geladen werden.'),
                    ),
                    driversCatalogAsync.when(
                      data: (options) {
                        return _buildChipSection(
                          title: 'Wirkung',
                          value: impact,
                          options: options.map((e) => e.title).toList(),
                          onSelect: (v) => setState(() => impact = v),
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) =>
                          const Text('Wirkungen konnten nicht geladen werden.'),
                    ),
                    const SizedBox(height: 12),
                    PrimaryButton(
                      label: 'Speichern',
                      onPressed: () async {
                        final repo = ref.read(missionRepositoryProvider);
                        final statement = _buildSentence(
                          template: selectedTemplate?.template ?? '',
                        );
                        final result = await repo.upsertUserMission(
                          userId: null,
                          statement: statement,
                          sourceTemplateId: selectedTemplate?.id,
                        );
                        if (result.isSuccess && mounted) {
                          ref.invalidate(userMissionStatementProvider);
                          setState(() => showBuilder = false);
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _initDefaults({
    required AsyncValue<List<MissionTemplate>> templatesAsync,
    required AsyncValue<List<CatalogItem>> strengthsAsync,
    required AsyncValue<List<CatalogItem>> valuesAsync,
    required AsyncValue<List<CatalogItem>> strengthsCatalogAsync,
    required AsyncValue<List<CatalogItem>> valuesCatalogAsync,
    required AsyncValue<List<CatalogItem>> driversCatalogAsync,
    required AsyncValue<List<CatalogItem>> personalityCatalogAsync,
    required AsyncValue<List<CatalogItem>> pillarsCatalogAsync,
  }) {
    if (_defaultsInitialized) return;
    if (templatesAsync.isLoading ||
        strengthsAsync.isLoading ||
        valuesAsync.isLoading ||
        strengthsCatalogAsync.isLoading ||
        valuesCatalogAsync.isLoading ||
        driversCatalogAsync.isLoading ||
        personalityCatalogAsync.isLoading ||
        pillarsCatalogAsync.isLoading) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _defaultsInitialized) return;
      final strengths = strengthsAsync.asData?.value ?? const <CatalogItem>[];
      final values = valuesAsync.asData?.value ?? const <CatalogItem>[];
      final strengthFallbacks = strengthsCatalogAsync.asData?.value ?? const <CatalogItem>[];
      final valueFallbacks = valuesCatalogAsync.asData?.value ?? const <CatalogItem>[];
      final driverFallbacks = driversCatalogAsync.asData?.value ?? const <CatalogItem>[];
      final personalityFallbacks = personalityCatalogAsync.asData?.value ?? const <CatalogItem>[];
      final pillarFallbacks = pillarsCatalogAsync.asData?.value ?? const <CatalogItem>[];
      final templates = templatesAsync.asData?.value ?? const <MissionTemplate>[];

      setState(() {
        if (selectedTemplate == null && templates.isNotEmpty) {
          selectedTemplate = templates.first;
        }
        if (strength == null) {
          strength = strengths.isNotEmpty
              ? strengths.first.title
              : (strengthFallbacks.isNotEmpty ? strengthFallbacks.first.title : null);
        }
        if (value == null) {
          value = values.isNotEmpty
              ? values.first.title
              : (valueFallbacks.isNotEmpty ? valueFallbacks.first.title : null);
        }
        if (value2 == null) {
          value2 = values.length > 1
              ? values[1].title
              : (valueFallbacks.length > 1 ? valueFallbacks[1].title : value);
        }
        if (target == null && pillarFallbacks.isNotEmpty) {
          target = pillarFallbacks.first.title;
        }
        if (activity == null && personalityFallbacks.isNotEmpty) {
          activity = personalityFallbacks.first.title;
        }
        if (impact == null && driverFallbacks.isNotEmpty) {
          impact = driverFallbacks.first.title;
        }
        _defaultsInitialized = true;
      });
    });
  }

  String _buildSentence({required String template}) {
    final v1 = value ?? value2 ?? 'Klarheit';
    final v2 = value2 ?? value ?? v1;
    return template
        .replaceAll('{{strength}}', strength ?? 'Klarheit')
        .replaceAll('{{value}}', v1)
        .replaceAll('{{value2}}', v2)
        .replaceAll('{{activity}}', activity ?? 'Handeln')
        .replaceAll('{{target}}', target ?? 'mein System')
        .replaceAll('{{impact}}', impact ?? 'Ruhe');
  }

  Widget _buildOptionSection(
    BuildContext context, {
    required String title,
    required String? value,
    required AsyncValue<List<CatalogItem>> catalogAsync,
    required AsyncValue<List<CatalogItem>> selectionAsync,
    required String emptyText,
    required ValueChanged<String> onSelect,
  }) {
    final catalog = catalogAsync.asData?.value ?? const <CatalogItem>[];
    final selections = selectionAsync.asData?.value ?? const <CatalogItem>[];
    final options = catalog.isNotEmpty ? catalog : selections;

    if (options.isNotEmpty) {
      return _buildChipSection(
        title: title,
        value: value,
        options: options.map((e) => e.title).toList(),
        onSelect: onSelect,
      );
    }

    if (catalogAsync.isLoading && selectionAsync.isLoading) {
      return const SizedBox.shrink();
    }

    if (catalogAsync.hasError && selectionAsync.hasError) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        child: Text('$title konnte nicht geladen werden.'),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Text(emptyText),
    );
  }
}

class _TemplateCarousel extends StatelessWidget {
  const _TemplateCarousel({
    required this.templates,
    required this.selectedId,
    required this.onSelect,
  });

  final List<MissionTemplate> templates;
  final String? selectedId;
  final ValueChanged<MissionTemplate> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 170,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemBuilder: (_, i) {
          final t = templates[i];
          final selected = t.id == selectedId;
          return GestureDetector(
            onTap: () => onSelect(t),
            child: Container(
              width: 260,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: selected
                    ? Theme.of(context).colorScheme.primary.withOpacity(0.15)
                    : Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.transparent),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.tone.isEmpty ? 'Ton' : t.tone,
                      style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Text(
                    t.template,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemCount: templates.length,
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.sentence,
    this.savedSentence,
    this.onEdit,
    this.onCopy,
  });

  final String sentence;
  final String? savedSentence;
  final VoidCallback? onEdit;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            scheme.primary.withOpacity(0.22),
            scheme.secondary.withOpacity(0.22),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Vorschau', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 10),
          Text(
            sentence,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          if (savedSentence != null) ...[
            const SizedBox(height: 12),
            Text('Gespeichert',
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            Text(savedSentence!),
            const SizedBox(height: 12),
            Row(
              children: [
                SecondaryButton(
                  label: 'Bearbeiten',
                  onPressed: onEdit,
                ),
                const SizedBox(width: 12),
                SecondaryButton(
                  label: 'Kopieren',
                  onPressed: onCopy,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SelectionBox extends StatelessWidget {
  const _SelectionBox({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            scheme.primary.withOpacity(0.12),
            scheme.secondary.withOpacity(0.12),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: child,
    );
  }
}

Widget _buildChipSection({
  required String title,
  required String? value,
  required List<String> options,
  required ValueChanged<String> onSelect,
}) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < options.length; i++)
              ChoiceChip(
                label: Text(options[i]),
                selected: options[i] == value,
                selectedColor: _chipColor(i).withOpacity(0.35),
                backgroundColor: _chipColor(i).withOpacity(0.18),
                onSelected: (_) => onSelect(options[i]),
              ),
          ],
        ),
      ],
    ),
  );
}

Color _chipColor(int index) {
  const palette = [
    Color(0xFFF2B544),
    Color(0xFFE8DFF5),
    Color(0xFFDDEEEA),
    Color(0xFFF4D9DF),
    Color(0xFFD9E7F5),
    Color(0xFFE7E1D8),
  ];
  return palette[index % palette.length];
}
