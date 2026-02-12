import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/catalog_item.dart';
import '../../data/models/mission_template.dart';
import '../../state/mission_state.dart';
import '../../state/user_selections_state.dart';
import '../../widgets/common/primary_button.dart';
import '../../widgets/common/secondary_button.dart';

void openLeitbildSheet(BuildContext context) {
  final theme = Theme.of(context);
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: theme.colorScheme.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => LeitbildSheet(rootContext: context),
  );
}

class LeitbildSheet extends ConsumerStatefulWidget {
  const LeitbildSheet({super.key, required this.rootContext});

  final BuildContext rootContext;

  @override
  ConsumerState<LeitbildSheet> createState() => _LeitbildSheetState();
}

class _LeitbildSheetState extends ConsumerState<LeitbildSheet> {
  String? _selectedTemplateId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final valuesAsync = ref.watch(userSelectedValuesProvider);
    final strengthsAsync = ref.watch(userSelectedStrengthsProvider);
    final driversAsync = ref.watch(userSelectedDriversProvider);
    final personalityAsync = ref.watch(userSelectedPersonalityProvider);
    final templatesAsync = ref.watch(missionTemplatesProvider);
    final savedAsync = ref.watch(userMissionStatementProvider);

    final asyncs = [
      valuesAsync,
      strengthsAsync,
      driversAsync,
      personalityAsync,
      templatesAsync,
      savedAsync,
    ];
    if (asyncs.any((a) => a.isLoading)) {
      return const SafeArea(
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (asyncs.any((a) => a.hasError)) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
          child: Text(
            'Leitbild konnte nicht geladen werden.',
            style: theme.textTheme.bodyLarge,
          ),
        ),
      );
    }

    final values = valuesAsync.asData?.value ?? const <CatalogItem>[];
    final strengths = strengthsAsync.asData?.value ?? const <CatalogItem>[];
    final drivers = driversAsync.asData?.value ?? const <CatalogItem>[];
    final personality = personalityAsync.asData?.value ?? const <CatalogItem>[];
    final templates = templatesAsync.asData?.value ?? const <MissionTemplate>[];
    final saved = savedAsync.asData?.value;

    _initSelectedTemplate(saved, templates);

    final valuesCount = values.length;
    final strengthsCount = strengths.length;
    final driversCount = drivers.length;
    final personalityCount = personality.length;

    final isEmpty = valuesCount == 0 &&
        strengthsCount == 0 &&
        driversCount == 0 &&
        personalityCount == 0;
    final isComplete = valuesCount >= 3 &&
        strengthsCount >= 3 &&
        driversCount >= 1 &&
        personalityCount >= 3;
    final state = isEmpty
        ? _LeitbildState.empty
        : (isComplete ? _LeitbildState.complete : _LeitbildState.partial);

    final selectedTemplate =
        templates.firstWhere((t) => t.id == _selectedTemplateId,
            orElse: () => templates.isNotEmpty ? templates.first : _fallbackTemplate);
    final previewText = _buildLeitbildText(
      template: selectedTemplate.template,
      values: values,
      strengths: strengths,
      drivers: drivers,
      personality: personality,
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Leitbild', style: theme.textTheme.headlineLarge),
            const SizedBox(height: 10),
            Text(
              'Ein Satz, der dich ruhig state-based ausrichtet.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 24),
            if (state == _LeitbildState.empty)
              _EmptyStateCard(onStart: _goToInnen)
            else if (state == _LeitbildState.partial)
              _PartialStateCard(
                valuesCount: valuesCount,
                strengthsCount: strengthsCount,
                driversCount: driversCount,
                personalityCount: personalityCount,
                onComplete: _goToInnen,
              )
            else
              _CompleteState(
                previewText: previewText,
                values: values,
                strengths: strengths,
                drivers: drivers,
                templates: templates,
                selectedTemplateId: _selectedTemplateId,
                onSelectTemplate: (id) => setState(() {
                  _selectedTemplateId = id;
                }),
                onApply: () => _saveSelection(
                  templateId: selectedTemplate.id,
                  statement: previewText,
                ),
                onEditInnen: _goToInnen,
              ),
          ],
        ),
      ),
    );
  }

  void _initSelectedTemplate(
      dynamic saved, List<MissionTemplate> templates) {
    if (_selectedTemplateId != null || templates.isEmpty) return;
    final savedTemplateId = saved?.sourceTemplateId as String?;
    final hasSaved = savedTemplateId != null &&
        templates.any((t) => t.id == savedTemplateId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _selectedTemplateId != null) return;
      setState(() {
        _selectedTemplateId =
            hasSaved ? savedTemplateId : templates.first.id;
      });
    });
  }

  void _goToInnen() {
    Navigator.of(context).pop();
    GoRouter.of(widget.rootContext).go('/innen');
  }

  Future<void> _saveSelection({
    required String templateId,
    required String statement,
  }) async {
    final result = await ref.read(missionRepositoryProvider).upsertUserMission(
          userId: null,
          statement: statement,
          sourceTemplateId: templateId,
        );
    if (!mounted) return;
    if (result.isSuccess) {
      ref.invalidate(userMissionStatementProvider);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Leitbild gespeichert.')));
    } else {
      final msg = result.error?.message == 'Not logged in'
          ? 'Bitte anmelden, um zu speichern.'
          : 'Leitbild konnte nicht gespeichert werden.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    }
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dein Leitbild entsteht aus deinen inneren Entscheidungen.',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Sobald du Werte, Stärken, Antreiber und Persönlichkeit auswählst, '
            'formt sich dein Leitbild automatisch.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          PrimaryButton(label: 'Innen beginnen', onPressed: onStart),
        ],
      ),
    );
  }
}

class _PartialStateCard extends StatelessWidget {
  const _PartialStateCard({
    required this.valuesCount,
    required this.strengthsCount,
    required this.driversCount,
    required this.personalityCount,
    required this.onComplete,
  });

  final int valuesCount;
  final int strengthsCount;
  final int driversCount;
  final int personalityCount;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Leitbild im Aufbau',
              style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Dein Leitbild basiert bereits auf Teilen deiner Innen-Auswahl.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          _ChecklistRow(label: 'Werte', value: '$valuesCount / 3'),
          _ChecklistRow(label: 'Stärken', value: '$strengthsCount / 3'),
          _ChecklistRow(label: 'Antreiber', value: '$driversCount / 1'),
          _ChecklistRow(
              label: 'Persönlichkeit', value: '$personalityCount / 3'),
          const SizedBox(height: 16),
          PrimaryButton(label: 'Innen vervollständigen', onPressed: onComplete),
          const SizedBox(height: 10),
          Text(
            'Du kannst dein Leitbild auch mit unvollständiger Grundlage ansehen.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.65),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompleteState extends StatelessWidget {
  const _CompleteState({
    required this.previewText,
    required this.values,
    required this.strengths,
    required this.drivers,
    required this.templates,
    required this.selectedTemplateId,
    required this.onSelectTemplate,
    required this.onApply,
    required this.onEditInnen,
  });

  final String previewText;
  final List<CatalogItem> values;
  final List<CatalogItem> strengths;
  final List<CatalogItem> drivers;
  final List<MissionTemplate> templates;
  final String? selectedTemplateId;
  final ValueChanged<String> onSelectTemplate;
  final VoidCallback onApply;
  final VoidCallback onEditInnen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Dein aktuelles Leitbild',
                  style: theme.textTheme.labelLarge),
              const SizedBox(height: 10),
              Text(
                previewText,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Basiert auf deinen Innen-Entscheidungen.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.65),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text('Ton & Ausrichtung', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (templates.isEmpty)
          Text('Keine Leitbild-Vorlagen verfügbar.',
              style: theme.textTheme.bodySmall)
        else
          SizedBox(
            height: 46,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemBuilder: (_, i) {
                final t = templates[i];
                final selected = t.id == selectedTemplateId;
                final scheme = Theme.of(context).colorScheme;
                return ChoiceChip(
                  label: Text(t.tone.isEmpty ? t.key : t.tone),
                  selected: selected,
                  onSelected: (_) => onSelectTemplate(t.id),
                  backgroundColor: scheme.surfaceVariant,
                  selectedColor: scheme.primary.withOpacity(0.16),
                  labelStyle: theme.textTheme.labelSmall?.copyWith(
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
              itemCount: templates.length,
            ),
          ),
        const SizedBox(height: 12),
        PrimaryButton(label: 'Übernehmen', onPressed: onApply),
        const SizedBox(height: 20),
        Text('Grundlage', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Text(
          'Werte: ${_join(values)}',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        Text(
          'Stärken: ${_join(strengths)}',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        Text(
          'Antreiber: ${_join(drivers)}',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        SecondaryButton(label: 'In Innen anpassen', onPressed: onEditInnen),
      ],
    );
  }

  String _join(List<CatalogItem> items) {
    if (items.isEmpty) return '–';
    return items.take(4).map((e) => e.title).join(', ');
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: Theme.of(context).textTheme.labelLarge),
        ],
      ),
    );
  }
}

String _buildLeitbildText({
  required String template,
  required List<CatalogItem> values,
  required List<CatalogItem> strengths,
  required List<CatalogItem> drivers,
  required List<CatalogItem> personality,
}) {
  final value1 = values.isNotEmpty ? values.first.title : 'Klarheit';
  final value2 =
      values.length > 1 ? values[1].title : (values.isNotEmpty ? values.first.title : value1);
  final strength = strengths.isNotEmpty ? strengths.first.title : 'Fokus';
  final driver = drivers.isNotEmpty ? drivers.first.title : 'Balance';
  final personalityHint =
      personality.isNotEmpty ? personality.first.title : 'Stabilität';

  String sentence;
  if (template.trim().isEmpty) {
    sentence = 'Ich lebe $value1 und $value2 mit $strength, getragen von $driver.';
  } else if (template.contains('{{')) {
    sentence = template
        .replaceAll('{{strength}}', strength)
        .replaceAll('{{value}}', value1)
        .replaceAll('{{value2}}', value2)
        .replaceAll('{{activity}}', personalityHint)
        .replaceAll('{{target}}', value1)
        .replaceAll('{{impact}}', driver);
  } else {
    sentence = '$template, getragen von $value1 und $strength.';
  }

  sentence = sentence.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (sentence.length > 180) {
    sentence = '${sentence.substring(0, 177).trimRight()}…';
  }
  return sentence;
}

final _fallbackTemplate = MissionTemplate(
  id: 'fallback',
  key: 'ruhig',
  template: 'Ich richte mich an {{value}} aus und handle mit {{strength}}.',
  tone: 'Ruhig & stabil',
  sortRank: 0,
  isActive: true,
  createdAt: DateTime(1970),
);

enum _LeitbildState { empty, partial, complete }

