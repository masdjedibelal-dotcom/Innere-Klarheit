import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../content/app_copy.dart';
import '../../debug/dev_panel_screen.dart';
import '../../widgets/common/section_header.dart';
import '../../widgets/common/carousel_tile.dart';
import '../../widgets/bottom_sheet/bottom_card_sheet.dart';
import '../../widgets/common/knowledge_snack_sheet.dart';
import '../../widgets/bottom_sheet/method_catalog_sheet.dart';
import '../../widgets/common/tag_chip.dart';
import '../../state/user_state.dart';
import '../../state/mission_state.dart';
import '../../state/user_selections_state.dart';
import '../mission/leitbild_sheet.dart';
import '../../data/models/catalog_item.dart';
import '../../data/models/method_v2.dart';
import '../../data/models/system_block.dart';
import '../../data/models/identity_pillar.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(userStateProvider.notifier).markActive(DateTime.now());
    });
  }

  @override
  Widget build(BuildContext context) {

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
                  onTap: () => openLeitbildSheet(context),
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
                            'Öffne dein Leitbild und wähle den Ton.',
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
                'Leitbild konnte nicht geladen werden.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.7),
                    ),
              ),
            ),
          ),
          blocksAsync.when(
            data: (blocks) {
              return methodsAsync.when(
                data: (methods) {
                  final byBlock = _groupMethods(methods, blocks);
                  return _CarouselSection(
                    title: 'Tagesblöcke',
                    height: 180,
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
                                selectedIds:
                                    user.todayPlan[block.id]?.methodIds ?? const [],
                                outcome: user.todayPlan[block.id]?.outcome,
                                onTap: () => _showBlockDetails(
                                  context,
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
          knowledgeAsync.when(
            data: (items) {
              final limit = items.length > 5 ? 5 : items.length;
              return _CarouselSection(
                title: 'Wissenssnacks',
                trailing: TextButton.icon(
                  onPressed: () => context.push('/wissen'),
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  label: const Text('Alle'),
                  style: TextButton.styleFrom(
                    textStyle: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                height: 170,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  itemBuilder: (_, i) {
                    final snack = items[i];
                    return _KnowledgeTile(
                      title: snack.title,
                      preview: snack.preview,
                      badgeText:
                          snack.tags.isNotEmpty ? snack.tags.first : 'Wissenssnack',
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
    final theme = Theme.of(context);
    final baseTitle = theme.textTheme.headlineMedium ??
        theme.textTheme.displaySmall ??
        const TextStyle(fontSize: 42);
    final baseFontSize = baseTitle.fontSize ?? 42;
    final titleStyle = baseTitle.copyWith(
      fontSize: baseFontSize < 40 ? 42 : baseFontSize,
      fontWeight: FontWeight.bold,
      height: 1.1,
    );
    final subtitleStyle = (theme.textTheme.bodyLarge ?? const TextStyle())
        .copyWith(
          fontSize: 18,
          height: 1.6,
          color: theme.colorScheme.onSurface.withOpacity(0.65),
        );
    final bodyStyle = (theme.textTheme.bodyMedium ?? const TextStyle()).copyWith(
      height: 1.6,
      color: theme.colorScheme.onSurface.withOpacity(0.7),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 60, 30, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hero.title.isNotEmpty) ...[
            Text(hero.title, style: titleStyle),
            if (hero.subtitle.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                hero.subtitle,
                style: subtitleStyle,
              ),
            ],
            if (hero.body.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                hero.body,
                style: bodyStyle,
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
        const SizedBox(height: 16),
      ],
    );
  }
}

class _KnowledgeTile extends StatelessWidget {
  const _KnowledgeTile({
    required this.title,
    required this.preview,
    required this.badgeText,
    this.onTap,
  });

  final String title;
  final String preview;
  final String badgeText;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 260,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.transparent),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TagChip(label: badgeText),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
            ),
            const SizedBox(height: 3),
            Text(
              preview,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.75),
                    height: 1.5,
                  ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.bottomRight,
              child: Icon(
                Icons.arrow_forward,
                size: 15,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
              ),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 160,
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.transparent),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            Text(
              '${score.round()} von 10',
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
  }
}

class _BlockTodoTile extends StatelessWidget {
  const _BlockTodoTile({
    required this.block,
    required this.methods,
    required this.selectedIds,
    required this.outcome,
    this.onTap,
  });

  final SystemBlock block;
  final List<MethodV2> methods;
  final List<String> selectedIds;
  final String? outcome;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final visible = methods
        .where((m) => selectedIds.contains(m.id))
        .take(3)
        .toList();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 250,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.transparent),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(block.title, style: Theme.of(context).textTheme.titleMedium),
            if (outcome != null && outcome!.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                outcome!.trim(),
                maxLines: 1,
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
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_box_outline_blank,
                        size: 14,
                        color: Theme.of(context).iconTheme.color,
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
          ],
        ),
      ),
    );
  }
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

    final goTarget = '/innen';
    return GestureDetector(
      onTap: () => context.push(goTarget),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Innen', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (!hasAny) ...[
              Text(
                'Deine innere Basis ist noch leer.',
                textAlign: TextAlign.left,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'Stärken, Werte, Antreiber & Persönlichkeit helfen dem System zu tragen.',
                textAlign: TextAlign.left,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.75),
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Jetzt starten',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ] else ...[
              _InnerBadgeRow(label: 'Stärken', items: strengths),
              const SizedBox(height: 6),
              _InnerBadgeRow(label: 'Werte', items: values),
              const SizedBox(height: 6),
              _InnerBadgeRow(label: 'Antreiber', items: drivers),
              const SizedBox(height: 6),
              _InnerBadgeRow(label: 'Persönlichkeit', items: personality),
            ],
          ],
        ),
      ),
    );
  }
}

class _InnerBadgeRow extends StatelessWidget {
  const _InnerBadgeRow({required this.label, required this.items});

  final String label;
  final List<CatalogItem> items;

  @override
  Widget build(BuildContext context) {
    final show = items.take(4).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        if (show.isEmpty)
          Text(
            '–',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.65),
                ),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: show.map((item) => TagChip(label: item.title)).toList(),
          ),
      ],
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
    child: MethodCatalogSheet(
      block: block,
      methods: methods,
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

