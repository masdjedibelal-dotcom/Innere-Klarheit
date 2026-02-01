import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../content/app_copy.dart';
import '../../data/models/identity_pillar.dart';
import '../../state/user_state.dart';
import '../../widgets/bottom_sheet/bottom_card_sheet.dart';
import '../../widgets/common/chip_group.dart';
import '../../widgets/common/generated_media.dart';

class IdentitaetScreen extends ConsumerStatefulWidget {
  const IdentitaetScreen({super.key});

  @override
  ConsumerState<IdentitaetScreen> createState() => _IdentitaetScreenState();
}

class _IdentitaetScreenState extends ConsumerState<IdentitaetScreen> {
  final valuesPool = ['Integrität', 'Tiefe', 'Fokus', 'Balance'];
  final buildPool = ['Struktur', 'Routinen', 'Klarheit', 'Ruhe'];
  final protectPool = ['Grenzen', 'Energie', 'Zeit', 'Wahrheit'];
  final deliverPool = ['Fortschritt', 'Verbindlichkeit', 'Qualität', 'Mut'];

  final Set<String> chosenValues = {};
  final Set<String> chosenBuild = {};
  final Set<String> chosenProtect = {};
  final Set<String> chosenDeliver = {};

  bool showEditor = false;
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pillarsAsync = ref.watch(identityPillarsProvider);
    final user = ref.watch(userStateProvider);
    final intro = copy('identity.intro');
    final missionCopy = copy('identity.mission');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Identität'),
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
          if (intro.title.isNotEmpty) _IntroBlock(copy: intro),
          pillarsAsync.when(
            data: (pillars) {
              if (pillars.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Text('Lebenssäulen',
                        style: Theme.of(context).textTheme.titleLarge),
                  ),
                      ...pillars.map((p) {
                        final score = user.pillarScores[p.id] ?? 5.0;
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
                          child: _PillarCard(
                            pillar: p,
                            score: score,
                            onScoreChanged: (v) =>
                                ref.read(userStateProvider.notifier).setPillarScore(p.id, v),
                            onTap: () => _openPillarSheet(context, p),
                          ),
                        );
                      }),
                  const Divider(),
                ],
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          if (missionCopy.title.isNotEmpty) _IntroBlock(copy: missionCopy),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: _MissionPreviewCard(text: _missionPreview()),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: TextButton(
              onPressed: () => setState(() => showEditor = !showEditor),
              child: Text(
                  showEditor ? 'Optional ausblenden' : 'Optional bearbeiten'),
            ),
          ),
          if (showEditor)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: TextField(
                controller: _controller,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Dein eigener Satz …',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ChipGroup(
            title: 'Ich stehe für …',
            children: valuesPool
                .map((e) => _selectableChip(e, chosenValues))
                .toList(),
          ),
          ChipGroup(
            title: 'Ich baue …',
            children:
                buildPool.map((e) => _selectableChip(e, chosenBuild)).toList(),
          ),
          ChipGroup(
            title: 'Ich schütze …',
            children: protectPool
                .map((e) => _selectableChip(e, chosenProtect))
                .toList(),
          ),
          ChipGroup(
            title: 'Ich liefere …',
            children: deliverPool
                .map((e) => _selectableChip(e, chosenDeliver))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _selectableChip(String label, Set<String> picked) {
    final selected = picked.contains(label);
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() {
          if (selected) {
            picked.remove(label);
          } else {
            if (picked.length < 2) picked.add(label);
          }
        });
      },
    );
  }

  void _openPillarSheet(BuildContext context, IdentityPillar pillar) {
    showBottomCardSheet(
      context: context,
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(pillar.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(pillar.desc),
            if (pillar.reflectionQuestions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Reflexionsfragen',
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 6),
              ...pillar.reflectionQuestions.map((q) => Text('• $q')),
            ],
          ],
        ),
      ),
    );
  }

  String _missionPreview() {
    if (_controller.text.trim().isNotEmpty) return _controller.text.trim();

    final values = chosenValues.join(' & ');
    final build = chosenBuild.join(' & ');
    final protect = chosenProtect.join(' & ');
    final deliver = chosenDeliver.join(' & ');

    if (values.isEmpty && build.isEmpty && protect.isEmpty && deliver.isEmpty) {
      return 'Wähle 1–2 Begriffe pro Zeile. Die Vorschau aktualisiert sich live.';
    }

    return 'Ich stehe für $values. Ich baue $build. Ich schütze $protect. Ich liefere $deliver.'
        .replaceAll('  ', ' ')
        .replaceAll('. Ich baue .', '.')
        .replaceAll('. Ich schütze .', '.')
        .replaceAll('. Ich liefere .', '.');
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

class _MissionPreviewCard extends StatelessWidget {
  const _MissionPreviewCard({required this.text});
  final String text;

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
            text,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _PillarCard extends StatelessWidget {
  const _PillarCard({
    required this.pillar,
    required this.score,
    required this.onScoreChanged,
    this.onTap,
  });

  final IdentityPillar pillar;
  final double score;
  final ValueChanged<double> onScoreChanged;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: scheme.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.transparent),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GeneratedMedia(
                  seed: pillar.id,
                  height: 52,
                  borderRadius: 18,
                  icon: Icons.self_improvement,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(pillar.title,
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 6),
                      Text(
                        pillar.desc,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurface.withOpacity(0.75),
                            ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _scoreColor(score).withOpacity(0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${score.round()}/10',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: _scoreColor(score),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right),
              ],
            ),
            const SizedBox(height: 12),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                activeTrackColor: _scoreColor(score),
                inactiveTrackColor: scheme.outline.withOpacity(0.2),
                thumbColor: _scoreColor(score),
                overlayColor: _scoreColor(score).withOpacity(0.2),
              ),
              child: Slider(
                value: score,
                min: 0,
                max: 10,
                divisions: 10,
                label: '${score.round()}',
                onChanged: onScoreChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _scoreColor(double score) {
  final clamped = score.clamp(0, 10) / 10;
  if (clamped <= 0.5) {
    return Color.lerp(const Color(0xFFE16B5C), const Color(0xFFF2B544),
            clamped / 0.5) ??
        const Color(0xFFF2B544);
  }
  return Color.lerp(const Color(0xFFF2B544), const Color(0xFF4CAF50),
          (clamped - 0.5) / 0.5) ??
      const Color(0xFF4CAF50);
}
