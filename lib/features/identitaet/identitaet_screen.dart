import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/identity_pillar.dart';
import '../../state/user_state.dart';
import '../../ui/components/screen_hero.dart';
import '../../widgets/bottom_sheet/bottom_card_sheet.dart';

class IdentitaetScreen extends ConsumerStatefulWidget {
  const IdentitaetScreen({super.key});

  @override
  ConsumerState<IdentitaetScreen> createState() => _IdentitaetScreenState();
}

class _IdentitaetScreenState extends ConsumerState<IdentitaetScreen> {
  @override
  Widget build(BuildContext context) {
    final pillarsAsync = ref.watch(identityPillarsProvider);
    final user = ref.watch(userStateProvider);

    return Scaffold(
      appBar: null,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            ScreenHero(
              title: 'Identität',
              subtitle:
                  'Deine Lebenssäulen zeigen, wo du stehst und was du tragen möchtest.',
            ),
            pillarsAsync.when(
              data: (pillars) {
                if (pillars.isEmpty) return const SizedBox.shrink();
                final colors = _pillarColors(context);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(30, 16, 30, 8),
                      child: Text('Lebenssäulen',
                          style: Theme.of(context).textTheme.titleLarge),
                    ),
                    ...pillars.asMap().entries.map((entry) {
                      final index = entry.key;
                      final p = entry.value;
                      final score = user.pillarScores[p.id] ?? 5.0;
                      final accent = colors[index % colors.length];
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(30, 4, 30, 4),
                        child: _PillarCard(
                          pillar: p,
                          score: score,
                          accent: accent,
                          onTap: () => _openPillarSheet(context, p),
                        ),
                      );
                    }),
                  ],
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  void _openPillarSheet(BuildContext context, IdentityPillar pillar) {
    final initialScore =
        ref.read(userStateProvider).pillarScores[pillar.id] ?? 5.0;
    double score = initialScore;
    showBottomCardSheet(
      context: context,
      child: StatefulBuilder(
        builder: (context, setLocalState) {
          return SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pillar.title,
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(pillar.desc),
                const SizedBox(height: 16),
                Text('Aktueller Stand',
                    style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 6),
                Slider(
                  value: score,
                  min: 0,
                  max: 10,
                  divisions: 10,
                  label: '${score.round()}',
                  onChanged: (v) {
                    setLocalState(() {
                      score = v;
                    });
                    ref
                        .read(userStateProvider.notifier)
                        .setPillarScore(pillar.id, v);
                  },
                ),
                if (pillar.reflectionQuestions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('Reflexionsfragen',
                      style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 6),
                  ...pillar.reflectionQuestions.map((q) => Text('• $q')),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PillarCard extends StatelessWidget {
  const _PillarCard({
    required this.pillar,
    required this.score,
    required this.accent,
    this.onTap,
  });

  final IdentityPillar pillar;
  final double score;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: accent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.transparent),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: scheme.onSurface.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.self_improvement,
                size: 20,
                color: scheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(pillar.title,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    pillar.desc,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurface.withOpacity(0.7),
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                const SizedBox(height: 8),
                Icon(
                  Icons.chevron_right,
                  color: scheme.onSurface.withOpacity(0.6),
                ),
              ],
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

List<Color> _pillarColors(BuildContext context) {
  return [
    const Color(0xFFEFF3F8),
    const Color(0xFFF3F0FA),
    const Color(0xFFEFF7F1),
    const Color(0xFFFFF3E9),
    const Color(0xFFF2F6EE),
  ];
}
