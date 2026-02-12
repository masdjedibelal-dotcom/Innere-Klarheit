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
import '../../widgets/bottom_sheet/habit_sheet.dart';
import '../../widgets/common/tag_chip.dart';
import '../../state/user_state.dart';
import '../../state/mission_state.dart';
import '../../state/user_selections_state.dart';
import '../mission/leitbild_sheet.dart';
import '../../data/models/catalog_item.dart';
import '../../data/models/method_v2.dart';
import '../../data/models/method_day_block.dart';
import '../../data/models/system_block.dart';
import '../../data/models/identity_pillar.dart';
import '../../data/repositories/day_plan_repository.dart';
import '../system/system_habits.dart';
import '../dayflow/planner/day_block.dart';
import '../dayflow/planner/planner_engine.dart';
import '../dayflow/planner/planning_item.dart';
import '../dayflow/planner/rules/rule_batching.dart';
import '../dayflow/planner/rules/rule_chrono.dart';
import '../dayflow/planner/rules/rule_context_block_routing.dart';
import '../dayflow/planner/rules/rule_fixed_appointments.dart';
import '../dayflow/planner/rules/rule_frog.dart';
import '../dayflow/planner/rules/rule_limit_135.dart';

final _homeDayPlanProvider = FutureProvider<DayPlanSnapshot>((ref) async {
  final repo = ref.read(dayPlanRepoProvider);
  final result = await repo.fetchDayPlan(DateTime.now());
  if (result.isSuccess) return result.data!;
  return const DayPlanSnapshot(
    blocks: {},
    items: [],
    completedItemIds: {},
    blockOrder: [],
  );
});

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
    final methodsAsync = ref.watch(systemHabitsProvider);
    final methodDayBlocksAsync = ref.watch(systemMethodDayBlocksProvider);
    final user = ref.watch(userStateProvider);
    final dayPlanAsync = ref.watch(_homeDayPlanProvider);
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
                  return methodDayBlocksAsync.when(
                    data: (links) {
                      final activeBlocks = _buildHomeActiveBlocks(
                        blocks,
                        user.todayPlan,
                        user.blockOrderFor(DateTime.now()),
                      );
                      final dayPlan = dayPlanAsync.asData?.value ??
                          const DayPlanSnapshot(
                            blocks: {},
                            items: [],
                            completedItemIds: {},
                            blockOrder: [],
                          );
                      final appointmentMap = _mapAppointmentsToBlocks(
                        dayPlan,
                        activeBlocks,
                      );
                      final plannedAssignments = _planAssignments(
                        dayPlan.items,
                        activeBlocks,
                      );
                      final byBlock = _groupHabits(
                        methods,
                        links,
                        activeBlocks,
                      );
                      return _CarouselSection(
                        title: 'Tagesblöcke',
                        height: 180,
                        headerBottom: const _HomeTimelineBar(),
                        child: activeBlocks.isEmpty
                            ? const _EmptyState('Noch keine Blöcke verfügbar.')
                            : ListView.separated(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 20),
                                scrollDirection: Axis.horizontal,
                                itemBuilder: (_, i) {
                                  final block = activeBlocks[i];
                                  final list = byBlock[block.id] ?? const [];
                                  final todos = (plannedAssignments[block.id] ??
                                          const <PlanningItem>[])
                                      .where(
                                        (item) => item.type == PlanningType.todo,
                                      )
                                      .toList();
                                  return _BlockTodoTile(
                                    block: block,
                                    methods: list,
                                    selectedIds: user
                                            .todayPlan[block.id]?.methodIds ??
                                        const [],
                                    hasPlan: user.todayPlan[block.id]?.blockId.isNotEmpty ??
                                        false,
                                    appointments:
                                        appointmentMap[block.id] ?? const [],
                                    todos: todos,
                                    outcome:
                                        user.todayPlan[block.id]?.outcome,
                                    onTap: () => _showBlockDetails(
                                      context,
                                      block,
                                      methods,
                                      links,
                                    ),
                                  );
                                },
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 12),
                                itemCount: activeBlocks.length,
                              ),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) =>
                        const _EmptyState('Noch kein Inhalt verfügbar.'),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) =>
                    const _EmptyState('Noch kein Inhalt verfügbar.'),
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
    this.headerBottom,
    this.trailing,
  });

  final String title;
  final Widget child;
  final double height;
  final Widget? headerBottom;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: title, trailing: trailing),
        if (headerBottom != null) ...[
          const SizedBox(height: 6),
          headerBottom!,
        ],
        SizedBox(
          height: height,
          child: child,
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _HomeTimelineBar extends StatelessWidget {
  const _HomeTimelineBar();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        height: 12,
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            Container(
              height: 3,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: theme.colorScheme.onSurface.withOpacity(0.12),
              ),
            ),
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.35),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
    required this.hasPlan,
    required this.appointments,
    required this.todos,
    required this.outcome,
    this.onTap,
  });

  final SystemBlock block;
  final List<MethodV2> methods;
  final List<String> selectedIds;
  final bool hasPlan;
  final List<PlanningItem> appointments;
  final List<PlanningItem> todos;
  final String? outcome;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final visibleMethods = methods
        .where((m) =>
            m.blockRole == 'required' ||
            selectedIds.contains(m.id) ||
            (!hasPlan && m.defaultSelected))
        .toList();
    final items = [
      ...visibleMethods.map(
        (m) => _BlockListItem(
          title: m.title,
          icon: Icons.check_box_outline_blank,
        ),
      ),
      ...todos.map(
        (item) => _BlockListItem(
          title: item.title,
          icon: Icons.task_alt_outlined,
        ),
      ),
      ...appointments.map(
        (item) => _BlockListItem(
          title: item.title,
          icon: Icons.event,
        ),
      ),
    ];
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
            _BlockItemsList(items: items),
          ],
        ),
      ),
    );
  }
}

class _BlockItemsList extends StatefulWidget {
  const _BlockItemsList({required this.items});

  final List<_BlockListItem> items;

  @override
  State<_BlockItemsList> createState() => _BlockItemsListState();
}

class _BlockItemsListState extends State<_BlockItemsList> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (widget.items.isEmpty) {
      return Text(
        'Noch keine Methoden.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withOpacity(0.7),
        ),
      );
    }
    final showToggle = widget.items.length > 3;
    final visible =
        _expanded ? widget.items : widget.items.take(3).toList();
    final listContent = Column(
      children: visible.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Icon(
                item.icon,
                size: 14,
                color: theme.iconTheme.color,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.75),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        listContent,
        if (showToggle)
          TextButton(
            onPressed: () => setState(() => _expanded = !_expanded),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(_expanded ? 'Weniger anzeigen' : 'Mehr anzeigen'),
          ),
      ],
    );
  }
}

class _BlockListItem {
  const _BlockListItem({
    required this.title,
    required this.icon,
  });

  final String title;
  final IconData icon;
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
  List<MethodDayBlock> links,
) {
  final blockMethods = _methodsForBlock(methods, links, block.key);
  final habits = blockMethods.where((m) {
    if (m.blockRole == 'meta_hidden') return false;
    if (isSystemLogicMethod(m)) return false;
    return isHabitMethod(m);
  }).toList();
  showBottomCardSheet(
    context: context,
    child: HabitBlockSheet(
      block: block,
      habits: habits,
      onHabitTap: (habit) {
        final habitKey = habitKeyForMethod(habit) ?? habit.key;
        showBottomCardSheet(
          context: context,
          child: Consumer(
            builder: (context, ref, _) {
              final async = ref.watch(systemHabitContentProvider(habitKey));
              return async.when(
                data: (items) => HabitSheet(
                  habit: habit,
                  contentItems: items,
                ),
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (_, __) =>
                    const Text('Inhalt konnte nicht geladen werden.'),
              );
            },
          ),
        );
      },
    ),
  );
}


Map<String, List<MethodV2>> _groupHabits(
  List<MethodV2> methods,
  List<MethodDayBlock> links,
  List<SystemBlock> blocks,
) {
  final map = <String, List<MethodV2>>{};
  for (final block in blocks) {
    final list = _methodsForBlock(methods, links, block.key).where((m) {
      if (m.blockRole == 'meta_hidden') return false;
      if (isSystemLogicMethod(m)) return false;
      return isHabitMethod(m);
    }).toList();
    map[block.id] = list;
  }
  return map;
}

const _homeDefaultBlockKeys = {
  'morning_reset',
  'deep_work',
  'work_pomodoro',
  'evening_shutdown',
};

const _homeFixedHabitBlockKeys = [
  'morning_reset',
  'midday_reset',
  'evening_shutdown',
];

const _homeWakeItemId = 'wake_up';
const _homeSleepItemId = 'sleep';
const _homeDefaultWakeTime = TimeOfDay(hour: 8, minute: 0);
const _homeDefaultSleepTime = TimeOfDay(hour: 0, minute: 0);

List<SystemBlock> _buildHomeActiveBlocks(
  List<SystemBlock> blocks,
  Map<String, DayPlanBlock> todayPlan,
  List<String> orderedIds,
) {
  if (blocks.isEmpty) return const [];
  final byId = {for (final block in blocks) block.id: block};
  final byKey = {for (final block in blocks) block.key: block};
  final fixedBlocks = _homeFixedHabitBlockKeys
      .map((key) => byKey[key])
      .whereType<SystemBlock>()
      .toList();
  final fixedIds = fixedBlocks.map((b) => b.id).toSet();
  final activeIds = <String>{
    ...todayPlan.keys,
    ...fixedIds,
    ..._homeDefaultBlockKeys
        .map((key) => byKey[key]?.id)
        .whereType<String>(),
  };
  if (orderedIds.isNotEmpty) {
    final seen = <String>{};
    final ordered = <SystemBlock>[];
    for (final id in orderedIds) {
      final block = byId[id];
      if (block == null) continue;
      ordered.add(block);
      seen.add(id);
    }
    final missing = activeIds
        .where((id) => !seen.contains(id))
        .map((id) => byId[id])
        .whereType<SystemBlock>()
        .toList()
      ..sort((a, b) => a.sortRank.compareTo(b.sortRank));
    return [...ordered, ...missing];
  }
  final nonFixedBlocks = activeIds
      .where((id) => !fixedIds.contains(id))
      .map((id) => byId[id])
      .whereType<SystemBlock>()
      .toList()
    ..sort((a, b) => a.sortRank.compareTo(b.sortRank));
  final morningBlock = byKey['morning_reset'];
  final middayBlock = byKey['midday_reset'];
  final eveningBlock = byKey['evening_shutdown'];
  final morningSegment = nonFixedBlocks
      .where((b) => _homeSegmentForBlock(b) == _HomeDaySegment.morning)
      .toList();
  final middaySegment = nonFixedBlocks
      .where((b) => _homeSegmentForBlock(b) == _HomeDaySegment.midday)
      .toList();
  final eveningSegment = nonFixedBlocks
      .where((b) => _homeSegmentForBlock(b) == _HomeDaySegment.evening)
      .toList();
  return [
    if (morningBlock != null) morningBlock,
    ...morningSegment,
    if (middayBlock != null) middayBlock,
    ...middaySegment,
    if (eveningBlock != null) eveningBlock,
    ...eveningSegment,
  ];
}

enum _HomeDaySegment { morning, midday, evening }

_HomeDaySegment _homeSegmentForBlock(SystemBlock block) {
  final key = block.key.toLowerCase();
  final hint = block.timeHint.toLowerCase();
  if (key.contains('deep_work')) {
    return _HomeDaySegment.morning;
  }
  if (key.contains('pomodoro')) {
    return _HomeDaySegment.midday;
  }
  if (key.contains('morning') || hint.contains('morgen')) {
    return _HomeDaySegment.morning;
  }
  if (hint.contains('vormittag')) {
    return _HomeDaySegment.morning;
  }
  if (key.contains('midday') || hint.contains('mittag')) {
    return _HomeDaySegment.midday;
  }
  if (hint.contains('nachmittag')) {
    return _HomeDaySegment.midday;
  }
  if (key.contains('evening') || hint.contains('abend')) {
    return _HomeDaySegment.evening;
  }
  if (hint.contains('nacht')) {
    return _HomeDaySegment.evening;
  }
  return _HomeDaySegment.midday;
}

class _HomeTimelineSlot {
  const _HomeTimelineSlot({
    required this.block,
    required this.start,
    required this.end,
  });

  final SystemBlock block;
  final DateTime start;
  final DateTime end;
}

Map<String, List<PlanningItem>> _mapAppointmentsToBlocks(
  DayPlanSnapshot snapshot,
  List<SystemBlock> blocks,
) {
  final items = snapshot.items.where((item) {
    if (item.type != PlanningType.appointment) return false;
    return item.id != _homeWakeItemId && item.id != _homeSleepItemId;
  }).toList()
    ..sort((a, b) {
      final aTime = a.fixedStart ?? DateTime(2100);
      final bTime = b.fixedStart ?? DateTime(2100);
      return aTime.compareTo(bTime);
    });
  if (items.isEmpty || blocks.isEmpty) return {};
  final wake = _homeMarkerTime(
    snapshot,
    _homeWakeItemId,
    _homeDefaultWakeTime,
  );
  final sleep = _homeMarkerTime(
    snapshot,
    _homeSleepItemId,
    _homeDefaultSleepTime,
  );
  final today = DateTime.now();
  final slots = _buildHomeBlockSlots(blocks, today, wake, sleep);
  final map = <String, List<PlanningItem>>{};
  for (final item in items) {
    final time = item.fixedStart;
    _HomeTimelineSlot? target;
    if (time != null) {
      for (final slot in slots) {
        if (!time.isBefore(slot.start) && time.isBefore(slot.end)) {
          target = slot;
          break;
        }
      }
    }
    target ??= slots.isNotEmpty ? slots.first : null;
    if (target == null) continue;
    map.putIfAbsent(target.block.id, () => []).add(item);
  }
  return map;
}

TimeOfDay _homeMarkerTime(
  DayPlanSnapshot snapshot,
  String markerId,
  TimeOfDay fallback,
) {
  for (final item in snapshot.items) {
    if (item.id != markerId) continue;
    final dt = item.fixedStart;
    if (dt == null) continue;
    return TimeOfDay(hour: dt.hour, minute: dt.minute);
  }
  return fallback;
}

List<_HomeTimelineSlot> _buildHomeBlockSlots(
  List<SystemBlock> blocks,
  DateTime date,
  TimeOfDay wake,
  TimeOfDay sleep,
) {
  final slots = <_HomeTimelineSlot>[];
  var cursor = DateTime(date.year, date.month, date.day, wake.hour, wake.minute);
  for (final block in blocks) {
    final duration = _homeBlockDurationMin(block);
    DateTime start;
    DateTime end;
    if (block.key == 'evening_shutdown') {
      final sleepAt =
          DateTime(date.year, date.month, date.day, sleep.hour, sleep.minute);
      final adjustedSleep =
          sleepAt.isAfter(cursor) ? sleepAt : sleepAt.add(const Duration(days: 1));
      end = adjustedSleep;
      start = end.subtract(Duration(minutes: duration));
    } else if (block.key == 'midday_reset') {
      final midday = DateTime(date.year, date.month, date.day, 12, 0);
      start = cursor.isAfter(midday) ? cursor : midday;
      end = start.add(Duration(minutes: duration));
    } else {
      start = cursor;
      end = start.add(Duration(minutes: duration));
    }
    slots.add(_HomeTimelineSlot(block: block, start: start, end: end));
    cursor = end;
  }
  return slots;
}

int _homeBlockDurationMin(SystemBlock block) {
  if (_homeFixedHabitBlockKeys.contains(block.key)) return 60;
  if (block.key == 'deep_work' || block.key == 'work_pomodoro') {
    return 90;
  }
  return 60;
}

PlannerEngine _buildPlannerEngine() {
  return const PlannerEngine([
    Limit135Rule(),
    ContextBlockRoutingRule(),
    FixedAppointmentRule(),
    FrogRule(),
    ChronoRule(),
    BatchingRule(),
  ]);
}

Map<String, List<PlanningItem>> _planAssignments(
  List<PlanningItem> items,
  List<SystemBlock> blocks,
) {
  if (items.isEmpty || blocks.isEmpty) return {};
  final engine = _buildPlannerEngine();
  final dayBlocks = blocks.map(_toDayBlock).whereType<DayBlock>().toList();
  final planned = engine.plan(items: items, blocks: dayBlocks);
  return planned.assignments;
}

DayBlock? _toDayBlock(SystemBlock block) {
  final type = _dayBlockTypeForKey(block.key);
  if (type == null) return null;
  return DayBlock(
    id: block.id,
    type: type,
    fixed: type == DayBlockType.morningFixed ||
        type == DayBlockType.middayFixed ||
        type == DayBlockType.eveningFixed,
    start: null,
    end: null,
  );
}

DayBlockType? _dayBlockTypeForKey(String key) {
  switch (key) {
    case 'morning_reset':
      return DayBlockType.morningFixed;
    case 'deep_work':
      return DayBlockType.deepWork;
    case 'work_pomodoro':
      return DayBlockType.pomodoro;
    case 'midday_reset':
      return DayBlockType.middayFixed;
    case 'evening_shutdown':
      return DayBlockType.eveningFixed;
    default:
      return null;
  }
}

List<MethodV2> _methodsForBlock(
  List<MethodV2> methods,
  List<MethodDayBlock> links,
  String blockKey,
) {
  final byId = {for (final m in methods) m.id: m};
  final matching = links
      .where((l) => l.dayBlockKey == blockKey)
      .toList()
    ..sort((a, b) => a.sortRank.compareTo(b.sortRank));
  final joined = <MethodV2>[];
  for (final link in matching) {
    final method = byId[link.methodId];
    if (method != null) {
      final role = link.blockRole.trim().isEmpty ? 'optional' : link.blockRole;
      joined.add(method.copyWith(
        blockRole: role,
        defaultSelected: link.defaultSelected,
      ));
    }
  }
  return joined;
}

