import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../content/app_copy.dart';
import '../../debug/dev_panel_screen.dart';
import '../../widgets/common/section_header.dart';
import '../../widgets/common/tag_chip.dart';
import '../../widgets/common/carousel_tile.dart';
import '../../widgets/bottom_sheet/bottom_card_sheet.dart';
import '../../widgets/common/generated_media.dart';
import '../../widgets/common/knowledge_snack_sheet.dart';
import '../../state/user_state.dart';
import '../../state/mission_state.dart';
import '../../state/user_selections_state.dart';
import '../../data/models/catalog_item.dart';
import '../../data/models/method_v2.dart';
import '../../data/models/system_block.dart';
import '../../data/models/identity_pillar.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(userStateProvider.notifier).markActive(DateTime.now());
    });

    final knowledgeAsync = ref.watch(knowledgeProvider);
    final blocksAsync = ref.watch(systemBlocksProvider);
    final methodsAsync = ref.watch(systemMethodsProvider);
    final user = ref.watch(userStateProvider);
    final missionAsync = ref.watch(userMissionStatementProvider);
    final selectedValuesAsync = ref.watch(userSelectedValuesProvider);
    final selectedStrengthsAsync = ref.watch(userSelectedStrengthsProvider);
    final selectedDriversAsync = ref.watch(userSelectedDriversProvider);
    final selectedPersonalityAsync = ref.watch(userSelectedPersonalityProvider);
    final pillarsAsync = ref.watch(identityPillarsProvider);
    final isLoggedIn = true;

    final hero = copy('home.hero');

    return Scaffold(
      appBar: AppBar(
        title: _DevLongPressTitle(
          child: const Text('Clarity'),
          onTriggered: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DevPanelScreen()),
            );
          },
        ),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: () => context.push('/profil'),
            icon: const Icon(Icons.person_outline),
            tooltip: 'Profil',
          ),
        ],
      ),
      body: ListView(
        children: [
          _HeroSection(hero: hero),
          missionAsync.when(
            data: (mission) {
              final hasMission = mission != null && mission.statement.isNotEmpty;
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: InkWell(
                  onTap: () => context.push('/mission'),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary.withOpacity(0.25),
                          Theme.of(context).colorScheme.secondary.withOpacity(0.25),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.transparent),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Leitbild',
                            style: Theme.of(context).textTheme.labelLarge),
                        const SizedBox(height: 8),
                        Text(
                          hasMission ? mission.statement : 'Leitbild erstellen',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.95),
                              ),
                        ),
                        if (!hasMission) ...[
                          const SizedBox(height: 6),
                          Text(
                            'In Ruhe zusammensetzen und speichern.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.7),
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Text(
                'Mission konnte nicht geladen werden.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.7),
                    ),
              ),
            ),
          ),
          knowledgeAsync.when(
            data: (items) {
              final limit = items.length > 5 ? 5 : items.length;
              return _CarouselSection(
                title: 'Wissenssnacks',
                trailing: TextButton(
                  onPressed: () => context.push('/wissen'),
                  child: const Text('Alle'),
                ),
                height: 210,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  itemBuilder: (_, i) {
                    final snack = items[i];
                    return _KnowledgeTile(
                      seed: snack.id,
                      title: snack.title,
                      preview: snack.preview,
                      readTime: '${snack.readTimeMinutes} Min',
                      tag: snack.tags.isNotEmpty ? snack.tags.first : '',
                      onTap: () => showKnowledgeSnackSheet(
                        context: context,
                        snack: snack,
                      ),
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemCount: limit,
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const _EmptyState('Noch kein Inhalt verfügbar.'),
          ),
          _InnerSummaryCarousel(
            isLoggedIn: isLoggedIn,
            valuesAsync: selectedValuesAsync,
            strengthsAsync: selectedStrengthsAsync,
            driversAsync: selectedDriversAsync,
            personalityAsync: selectedPersonalityAsync,
          ),
          _IdentitySummaryCarousel(
            isLoggedIn: isLoggedIn,
            pillarsAsync: pillarsAsync,
            pillarScores: user.pillarScores,
          ),
          blocksAsync.when(
            data: (blocks) {
              return methodsAsync.when(
                data: (methods) {
                  final byBlock = _groupMethods(methods, blocks);
                  return _CarouselSection(
                    title: 'Tagesblöcke',
                    height: 140,
                    child: blocks.isEmpty
                        ? const _EmptyState('Noch keine Blöcke verfügbar.')
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            scrollDirection: Axis.horizontal,
                            itemBuilder: (_, i) {
                              final block = blocks[i];
                              final list = byBlock[block.id] ?? const [];
                              return _BlockTodoTile(
                                block: block,
                                methods: list,
                                doneIds: user.todayPlan[block.id]?.doneMethodIds ??
                                    const [],
                                selectedIds:
                                    user.todayPlan[block.id]?.methodIds ?? const [],
                                onTap: () => _showBlockActions(
                                  context,
                                  block,
                                  list,
                                ),
                                onOpenMore: () => _showBlockMethodPicker(
                                  context,
                                  ref,
                                  block,
                                  list,
                                ),
                              );
                            },
                            separatorBuilder: (_, __) => const SizedBox(width: 12),
                            itemCount: blocks.length,
                          ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const _EmptyState('Noch kein Inhalt verfügbar.'),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const _EmptyState('Noch kein Inhalt verfügbar.'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _DevLongPressTitle extends StatefulWidget {
  const _DevLongPressTitle({
    required this.child,
    required this.onTriggered,
  });

  final Widget child;
  final VoidCallback onTriggered;

  @override
  State<_DevLongPressTitle> createState() => _DevLongPressTitleState();
}

class _DevLongPressTitleState extends State<_DevLongPressTitle> {
  Timer? _timer;
  bool _triggered = false;

  void _startTimer() {
    _timer?.cancel();
    _triggered = false;
    _timer = Timer(const Duration(seconds: 2), () {
      _triggered = true;
      widget.onTriggered();
    });
  }

  void _cancelTimer() {
    _timer?.cancel();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) => _startTimer(),
      onLongPressEnd: (_) => _cancelTimer(),
      onLongPressCancel: _cancelTimer,
      onTap: () {
        if (_triggered) return;
      },
      child: widget.child,
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.hero,
  });

  final AppCopyItem hero;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hero.title.isNotEmpty) ...[
            Text(hero.title, style: Theme.of(context).textTheme.headlineLarge),
            if (hero.subtitle.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                hero.subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.85),
                    ),
              ),
            ],
            if (hero.body.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                hero.body,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.75),
                    ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _CarouselSection extends StatelessWidget {
  const _CarouselSection({
    required this.title,
    required this.child,
    required this.height,
    this.trailing,
  });

  final String title;
  final Widget child;
  final double height;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: title, trailing: trailing),
        SizedBox(
          height: height,
          child: child,
        ),
        const Divider(),
      ],
    );
  }
}

class _KnowledgeTile extends StatelessWidget {
  const _KnowledgeTile({
    required this.seed,
    required this.title,
    required this.preview,
    required this.readTime,
    required this.tag,
    this.onTap,
  });

  final String seed;
  final String title;
  final String preview;
  final String readTime;
  final String tag;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 250,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.transparent),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GeneratedMedia(
              seed: seed,
              height: 48,
              borderRadius: 12,
              icon: Icons.chrome_reader_mode_outlined,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Text(
                preview,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.75),
                    ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                if (tag.isNotEmpty) TagChip(label: tag),
                const SizedBox(width: 8),
                Text(
                  readTime,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.7),
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgeGroupTile extends StatelessWidget {
  const _BadgeGroupTile({
    required this.title,
    required this.items,
    this.onTap,
  });

  final String title;
  final List<CatalogItem> items;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final show = items.take(6).toList();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 200,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.transparent),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            if (show.isEmpty)
              Text(
                'Noch wählen',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.7),
                    ),
              )
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: show
                    .map(
                      (item) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceVariant,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          item.title,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class _PillarScoreTile extends StatelessWidget {
  const _PillarScoreTile({
    required this.title,
    required this.score,
    this.onTap,
  });

  final String title;
  final double score;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = _scoreColor(score);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 200,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.16),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.transparent),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.labelLarge),
            const Spacer(),
            Row(
              children: [
                Text(
                  '${score.round()}/10',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const Spacer(),
                Icon(Icons.circle, size: 10, color: color),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BlockTodoTile extends StatelessWidget {
  const _BlockTodoTile({
    required this.block,
    required this.methods,
    required this.doneIds,
    required this.selectedIds,
    this.onTap,
    this.onOpenMore,
  });

  final SystemBlock block;
  final List<MethodV2> methods;
  final List<String> doneIds;
  final List<String> selectedIds;
  final VoidCallback? onTap;
  final VoidCallback? onOpenMore;

  @override
  Widget build(BuildContext context) {
    final visible = methods
        .where((m) => selectedIds.contains(m.id))
        .take(2)
        .toList();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 250,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.transparent),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(block.title, style: Theme.of(context).textTheme.titleMedium),
            if (block.timeHint.isNotEmpty || block.desc.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                block.timeHint.isEmpty
                    ? block.desc
                    : '${block.timeHint} · ${block.desc}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.7),
                    ),
              ),
            ],
            const SizedBox(height: 8),
            if (visible.isEmpty)
              Text(
                'Noch keine Methoden.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.7),
                    ),
              )
            else
              ...visible.map((m) {
                final isDone = doneIds.contains(m.id);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Icon(
                        isDone
                            ? Icons.check_circle
                            : Icons.circle_outlined,
                        size: 14,
                        color: isDone
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).iconTheme.color,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          m.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.75),
                                  ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            if (methods.length > visible.length)
              TextButton(
                onPressed: onOpenMore,
                child: Text(
                  'Weitere anzeigen (${methods.length - visible.length})',
                  style: Theme.of(context).textTheme.labelSmall,
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

class _EmptyState extends StatelessWidget {
  const _EmptyState(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withOpacity(0.7),
            ),
      ),
    );
  }
}

class _InnerSummaryCarousel extends StatelessWidget {
  const _InnerSummaryCarousel({
    required this.isLoggedIn,
    required this.valuesAsync,
    required this.strengthsAsync,
    required this.driversAsync,
    required this.personalityAsync,
  });

  final bool isLoggedIn;
  final AsyncValue<List<CatalogItem>> valuesAsync;
  final AsyncValue<List<CatalogItem>> strengthsAsync;
  final AsyncValue<List<CatalogItem>> driversAsync;
  final AsyncValue<List<CatalogItem>> personalityAsync;

  @override
  Widget build(BuildContext context) {
    if (!isLoggedIn) {
      return _CarouselSection(
        title: 'Innen',
        height: 140,
        child: _PlaceholderCarousel(
          text: 'Login, um Auswahlen zu speichern.',
          onTap: () => context.push('/profil'),
        ),
      );
    }

    final values = valuesAsync.asData?.value ?? const <CatalogItem>[];
    final strengths = strengthsAsync.asData?.value ?? const <CatalogItem>[];
    final drivers = driversAsync.asData?.value ?? const <CatalogItem>[];
    final personality = personalityAsync.asData?.value ?? const <CatalogItem>[];

    final hasAny = values.isNotEmpty ||
        strengths.isNotEmpty ||
        drivers.isNotEmpty ||
        personality.isNotEmpty;

    if (!hasAny &&
        (valuesAsync.isLoading ||
            strengthsAsync.isLoading ||
            driversAsync.isLoading ||
            personalityAsync.isLoading)) {
      return const SizedBox.shrink();
    }

    if (!hasAny) {
      return _CarouselSection(
        title: 'Innen',
        height: 140,
        child: _PlaceholderCarousel(
          text: 'Auswahl in Innen setzen.',
          onTap: () => context.push('/innen'),
        ),
      );
    }

    final tiles = <Widget>[
      _BadgeGroupTile(
        title: 'Stärken',
        items: strengths,
        onTap: () => _showInnerList(context, 'Stärken', strengths),
      ),
      _BadgeGroupTile(
        title: 'Persönlichkeit',
        items: personality,
        onTap: () => _showInnerList(context, 'Persönlichkeit', personality),
      ),
      _BadgeGroupTile(
        title: 'Werte',
        items: values,
        onTap: () => _showInnerList(context, 'Werte', values),
      ),
      _BadgeGroupTile(
        title: 'Antreiber',
        items: drivers,
        onTap: () => _showInnerList(context, 'Antreiber', drivers),
      ),
    ];

    return _CarouselSection(
      title: 'Innen',
      height: 150,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemBuilder: (_, i) => tiles[i],
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemCount: tiles.length,
      ),
    );
  }
}

class _IdentitySummaryCarousel extends StatelessWidget {
  const _IdentitySummaryCarousel({
    required this.isLoggedIn,
    required this.pillarsAsync,
    required this.pillarScores,
  });

  final bool isLoggedIn;
  final AsyncValue<List<IdentityPillar>> pillarsAsync;
  final Map<String, double> pillarScores;

  @override
  Widget build(BuildContext context) {
    if (!isLoggedIn) {
      return _CarouselSection(
        title: 'Identität',
        height: 140,
        child: _PlaceholderCarousel(
          text: 'Login, um Rollen zu speichern.',
          onTap: () => context.push('/profil'),
        ),
      );
    }

    return pillarsAsync.when(
      data: (pillars) {
        if (pillars.isEmpty) {
          return _CarouselSection(
            title: 'Identität',
            height: 140,
            child: _PlaceholderCarousel(
              text: 'Lebensbereiche auswählen.',
              onTap: () => context.push('/identitaet'),
            ),
          );
        }
        return _CarouselSection(
          title: 'Identität',
          height: 140,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemBuilder: (_, i) {
              final pillar = pillars[i];
              final score = pillarScores[pillar.id] ?? 5.0;
              return _PillarScoreTile(
                title: pillar.title,
                score: score,
                onTap: () => context.push('/identitaet'),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemCount: pillars.length,
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const _EmptyState('Identität konnte nicht geladen werden.'),
    );
  }
}

class _PlaceholderCarousel extends StatelessWidget {
  const _PlaceholderCarousel({
    required this.text,
    this.onTap,
  });

  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      scrollDirection: Axis.horizontal,
      children: [
        CarouselTile(
          title: text,
          subtitle: 'Öffnen',
          onTap: onTap,
        ),
      ],
    );
  }
}


void _showInnerList(
  BuildContext context,
  String title,
  List<CatalogItem> items,
) {
  showBottomCardSheet(
    context: context,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('• ${item.title}'),
            )),
      ],
    ),
  );
}

void _showBlockDetails(
  BuildContext context,
  SystemBlock block,
  List<MethodV2> methods,
) {
  showBottomCardSheet(
    context: context,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(block.title, style: Theme.of(context).textTheme.titleLarge),
        if (block.desc.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(block.desc),
        ],
        const SizedBox(height: 12),
        Text('Methoden', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        if (methods.isEmpty)
          const Text('Noch keine Methoden für diesen Block.')
        else
          ...methods.map((m) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('• ${m.title}'),
              )),
      ],
    ),
  );
}

void _showBlockActions(
  BuildContext context,
  SystemBlock block,
  List<MethodV2> methods,
) {
  showBottomCardSheet(
    context: context,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(block.title, style: Theme.of(context).textTheme.titleLarge),
        if (block.timeHint.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            block.timeHint,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.7),
                ),
          ),
        ],
        if (block.desc.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(block.desc),
        ],
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => context.push('/system'),
          child: const Text('Methoden hinzufügen'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => _showBlockDetails(context, block, methods),
          child: const Text('Details ansehen'),
        ),
      ],
    ),
  );
}

void _showBlockMethodPicker(
  BuildContext context,
  WidgetRef ref,
  SystemBlock block,
  List<MethodV2> methods,
) {
  final user = ref.read(userStateProvider);
  final plan = user.todayPlan[block.id];
  final selectedId =
      plan?.methodIds.isNotEmpty == true ? plan!.methodIds.first : null;
  showBottomCardSheet(
    context: context,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(block.title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (methods.isEmpty)
          const Text('Noch keine Methoden für diesen Block.')
        else
          ...methods.map((m) {
            final isSelected = selectedId == m.id;
            return ListTile(
              title: Text(m.title),
              subtitle: m.shortDesc.isEmpty ? null : Text(m.shortDesc),
              trailing: Icon(
                isSelected
                    ? Icons.check_circle_outline
                    : Icons.add_circle_outline,
              ),
              onTap: () {
                final notifier = ref.read(userStateProvider.notifier);
                final doneIds = plan?.doneMethodIds ?? const [];
                notifier.setDayPlanBlock(
                  DayPlanBlock(
                    blockId: block.id,
                    outcome: plan?.outcome,
                    methodIds: [m.id],
                    doneMethodIds: doneIds.contains(m.id) ? [m.id] : const [],
                    done: plan?.done ?? false,
                  ),
                );
                Navigator.pop(context);
              },
            );
          }),
      ],
    ),
  );
}
Map<String, List<MethodV2>> _groupMethods(
  List<MethodV2> methods,
  List<SystemBlock> blocks,
) {
  final map = <String, List<MethodV2>>{};
  for (final block in blocks) {
    final list =
        methods.where((m) => m.contexts.contains(block.key)).toList();
    map[block.id] = list;
  }
  return map;
}

