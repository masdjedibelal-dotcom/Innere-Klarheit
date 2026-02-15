import 'dart:async';
import 'dart:math' as math;

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
import '../../state/inner_catalog_state.dart';
import '../../data/models/inner_catalog_detail.dart';
import '../mission/leitbild_sheet.dart';
import '../../data/models/catalog_item.dart';
import '../../data/models/method_v2.dart';
import '../../data/models/method_day_block.dart';
import '../../data/models/system_block.dart';
import '../../data/models/identity_pillar.dart';
import '../../data/models/user_mission_statement.dart';
import '../../data/repositories/day_plan_repository.dart';
import '../../data/supabase/supabase_client_provider.dart';
import '../../state/guest_day_plan_state.dart';
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
  final client = ref.read(supabaseClientProvider);
  final email = client.auth.currentUser?.email ?? '';
  if (email.isEmpty) {
    final user = ref.watch(userStateProvider);
    final entry = ref.watch(guestDayPlanProvider).entryFor(DateTime.now());
    return DayPlanSnapshot(
      blocks: user.dayPlansByDate[dateKey(DateTime.now())] ?? const {},
      items: entry.items,
      completedItemIds: entry.completedItemIds,
      blockOrder: user.blockOrderFor(DateTime.now()),
    );
  }
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

const double _homeCardMinHeight = 200;
const double _homeTutorialMinHeight = 160;
const double _homeSectionGap = 12;

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _showTutorial = true;
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
    final strengthsDetailsAsync = ref.watch(innerStrengthsDetailProvider);
    final valuesDetailsAsync = ref.watch(innerValuesDetailProvider);
    final driversDetailsAsync = ref.watch(innerDriversDetailProvider);
    final selectedPersonalityAsync = ref.watch(userSelectedPersonalityProvider);
    final personalityDetailsAsync = ref.watch(innerPersonalityDetailProvider);
    final pillarsAsync = ref.watch(identityPillarsProvider);
    final isLoggedIn = user.isLoggedIn;
    final values = selectedValuesAsync.asData?.value ?? const <CatalogItem>[];
    final strengths =
        selectedStrengthsAsync.asData?.value ?? const <CatalogItem>[];
    final drivers = selectedDriversAsync.asData?.value ?? const <CatalogItem>[];
    final personalities =
        selectedPersonalityAsync.asData?.value ?? const <CatalogItem>[];
    final dayPlan = dayPlanAsync.asData?.value;
    final onboardingStep = _resolveOnboardingStep(
      values: values,
      strengths: strengths,
      drivers: drivers,
      personalities: personalities,
      dayPlan: dayPlan,
      hasQuickPlan: user.todayPlan.isNotEmpty,
    );
    final hero = copy('home.hero');
    final tutorialSteps = _tutorialSteps(
      context,
      hasOnboarding: onboardingStep != null,
    );

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
          if (onboardingStep != null && _showTutorial)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, _homeSectionGap),
              child: _TutorialCard(
                steps: tutorialSteps,
                onClose: () => setState(() => _showTutorial = false),
              ),
            ),
          missionAsync.when(
            data: (mission) {
              final hasMission = mission != null && mission.statement.isNotEmpty;
              final shouldReview = hasMission &&
                  _shouldShowMissionReview(
                    mission,
                    user.dayCloseoutAnswers['mission_review_last'],
                  );
              return Column(
                children: [
                  if (shouldReview)
                    Padding(
                      padding:
                          const EdgeInsets.fromLTRB(20, 0, 20, _homeSectionGap),
                      child: SizedBox(
                        width: double.infinity,
                        child: _MissionReviewCard(
                          lastReviewedAt: _missionReviewDate(
                            mission,
                            user.dayCloseoutAnswers['mission_review_last'],
                          ),
                          onReview: () {
                            ref
                                .read(userStateProvider.notifier)
                                .setDayCloseoutAnswer(
                                  'mission_review_last',
                                  dateKey(DateTime.now()),
                                );
                            openLeitbildSheet(context);
                          },
                        ),
                      ),
                    ),
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(20, 0, 20, _homeSectionGap),
                    child: InkWell(
                      onTap: () => openLeitbildSheet(context),
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        width: double.infinity,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight: _homeCardMinHeight,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: _missionCardDecoration(context),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Leitbild',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelLarge
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  hasMission
                                      ? mission.statement
                                      : 'Leitbild erstellen',
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                      ),
                                ),
                                if (!hasMission) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                'Wird automatisch aus deiner Innen-Auswahl erstellt.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
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
                      ),
                    ),
                  ),
                ],
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, _homeSectionGap),
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
                      final seededMethods =
                          withMiddayResetDefaultHabit(methods);
                      final seededLinks =
                          withMiddayResetDefaultHabitLink(links, seededMethods);
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
                        seededMethods,
                        seededLinks,
                        activeBlocks,
                      );
                      return _CarouselSection(
                        title: 'Tagesblöcke',
                        height: 180,
                        headerBottom: const _HomeTimelineBar(),
                        child: activeBlocks.isEmpty
                            ? const _EmptyState('Noch keine Blöcke verfügbar.')
                            : ListView.separated(
                                padding: EdgeInsets.zero,
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
            personalityDetailsAsync: personalityDetailsAsync,
            strengthsDetailsAsync: strengthsDetailsAsync,
            valuesDetailsAsync: valuesDetailsAsync,
            driversDetailsAsync: driversDetailsAsync,
            personalityLevels: user.personalityLevels,
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
                wrapInCard: false,
                child: ListView.separated(
                  padding: EdgeInsets.zero,
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
    this.padding = const EdgeInsets.fromLTRB(20, 24, 20, 16),
  });

  final AppCopyItem hero;
  final EdgeInsets padding;

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
      padding: padding,
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
    this.wrapInCard = true,
  });

  final String title;
  final Widget child;
  final double height;
  final Widget? headerBottom;
  final Widget? trailing;
  final bool wrapInCard;

  @override
  Widget build(BuildContext context) {
    final minHeight = math.max(
      _homeCardMinHeight,
      height + (headerBottom != null ? 58 : 46) + 24,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, _homeSectionGap),
          child: wrapInCard
              ? ConstrainedBox(
                  constraints: BoxConstraints(minHeight: minHeight),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    decoration: _cardDecoration(context),
                    child: Column(
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
                      ],
                    ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(title: title, trailing: trailing),
                    const SizedBox(height: 8),
                    if (headerBottom != null) ...[
                      headerBottom!,
                      const SizedBox(height: 6),
                    ],
                    SizedBox(
                      height: height,
                      child: child,
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _HomeTimelineBar extends StatelessWidget {
  const _HomeTimelineBar();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
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
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
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
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TagChip(label: badgeText),
            const SizedBox(height: 4),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              preview,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.75),
                    height: 1.5,
                  ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.bottomRight,
              child: Icon(
                Icons.arrow_forward,
                size: 14,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IdentityTrendGrid extends StatelessWidget {
  const _IdentityTrendGrid({
    required this.pillars,
    required this.pillarScores,
  });

  final List<IdentityPillar> pillars;
  final Map<String, double> pillarScores;

  @override
  Widget build(BuildContext context) {
    final left = pillars.take(3).toList();
    final right = pillars.length > 3
        ? pillars.skip(3).take(2).toList()
        : <IdentityPillar>[];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _IdentityTrendColumn(
            pillars: left,
            pillarScores: pillarScores,
            startIndex: 0,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _IdentityTrendColumn(
            pillars: right,
            pillarScores: pillarScores,
            startIndex: left.length,
          ),
        ),
      ],
    );
  }
}

class _IdentityTrendColumn extends StatelessWidget {
  const _IdentityTrendColumn({
    required this.pillars,
    required this.pillarScores,
    required this.startIndex,
  });

  final List<IdentityPillar> pillars;
  final Map<String, double> pillarScores;
  final int startIndex;

  @override
  Widget build(BuildContext context) {
    if (pillars.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < pillars.length; i++) ...[
          _IdentityTrendRow(
            pillar: pillars[i],
            score: pillarScores[pillars[i].id] ?? 5.0,
            index: startIndex + i,
          ),
          if (i != pillars.length - 1) const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _IdentityTrendRow extends StatelessWidget {
  const _IdentityTrendRow({
    required this.pillar,
    required this.score,
    required this.index,
  });

  final IdentityPillar pillar;
  final double score;
  final int index;

  @override
  Widget build(BuildContext context) {
    final colors = _identityColors();
    final accent = colors[index % colors.length];
    final icon = _identityIconFor(pillar.title, index);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: accent.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: accent),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(pillar.title, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 2),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${score.round()} von 10',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.65),
                      ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

List<Color> _identityColors() {
  return const [
    Color(0xFF5AC8FA),
    Color(0xFFB8E986),
    Color(0xFFFF2D55),
    Color(0xFFFFCC00),
    Color(0xFF4CD964),
  ];
}

IconData _identityIconFor(String title, int index) {
  final t = title.toLowerCase();
  if (t.contains('gesund') || t.contains('fitness')) {
    return Icons.favorite_outline;
  }
  if (t.contains('arbeit') || t.contains('karriere') || t.contains('beruf')) {
    return Icons.work_outline;
  }
  if (t.contains('famil') || t.contains('freunde') || t.contains('sozial')) {
    return Icons.people_outline;
  }
  if (t.contains('lernen') || t.contains('wissen') || t.contains('bildung')) {
    return Icons.school_outlined;
  }
  if (t.contains('spirit') || t.contains('sinn') || t.contains('inner')) {
    return Icons.self_improvement;
  }
  return _identityFallbackIcons[index % _identityFallbackIcons.length];
}

const _identityFallbackIcons = [
  Icons.self_improvement,
  Icons.work_outline,
  Icons.favorite_outline,
  Icons.people_outline,
  Icons.school_outlined,
];

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
      padding: const EdgeInsets.fromLTRB(20, 0, 20, _homeSectionGap),
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

class _InnerSummaryCarousel extends StatefulWidget {
  const _InnerSummaryCarousel({
    required this.isLoggedIn,
    required this.valuesAsync,
    required this.strengthsAsync,
    required this.driversAsync,
    required this.personalityAsync,
    required this.personalityDetailsAsync,
    required this.strengthsDetailsAsync,
    required this.valuesDetailsAsync,
    required this.driversDetailsAsync,
    required this.personalityLevels,
  });

  final bool isLoggedIn;
  final AsyncValue<List<CatalogItem>> valuesAsync;
  final AsyncValue<List<CatalogItem>> strengthsAsync;
  final AsyncValue<List<CatalogItem>> driversAsync;
  final AsyncValue<List<CatalogItem>> personalityAsync;
  final AsyncValue<List<InnerCatalogDetail>> personalityDetailsAsync;
  final AsyncValue<List<InnerCatalogDetail>> strengthsDetailsAsync;
  final AsyncValue<List<InnerCatalogDetail>> valuesDetailsAsync;
  final AsyncValue<List<InnerCatalogDetail>> driversDetailsAsync;
  final Map<String, int> personalityLevels;

  @override
  State<_InnerSummaryCarousel> createState() => _InnerSummaryCarouselState();
}

class _InnerSummaryCarouselState extends State<_InnerSummaryCarousel> {
  int _activeIndex = 0;

  @override
  Widget build(BuildContext context) {
    final values = widget.valuesAsync.asData?.value ?? const <CatalogItem>[];
    final strengths =
        widget.strengthsAsync.asData?.value ?? const <CatalogItem>[];
    final drivers = widget.driversAsync.asData?.value ?? const <CatalogItem>[];
    final personality =
        widget.personalityAsync.asData?.value ?? const <CatalogItem>[];
    final personalityDetails =
        widget.personalityDetailsAsync.asData?.value ??
            const <InnerCatalogDetail>[];
    final strengthsDetails =
        widget.strengthsDetailsAsync.asData?.value ??
            const <InnerCatalogDetail>[];
    final valuesDetails =
        widget.valuesDetailsAsync.asData?.value ??
            const <InnerCatalogDetail>[];
    final driversDetails =
        widget.driversDetailsAsync.asData?.value ??
            const <InnerCatalogDetail>[];

    final hasAny = values.isNotEmpty ||
        strengths.isNotEmpty ||
        drivers.isNotEmpty ||
        personality.isNotEmpty;

    if (!hasAny &&
        (widget.valuesAsync.isLoading ||
            widget.strengthsAsync.isLoading ||
            widget.driversAsync.isLoading ||
            widget.personalityAsync.isLoading)) {
      return const SizedBox.shrink();
    }

    final categories = <_InnerCategory>[
      _InnerCategory(
        label: 'Persönlichkeit',
        items: personality,
        kind: _InnerCategoryKind.personality,
      ),
      _InnerCategory(
        label: 'Stärken',
        items: strengths,
        kind: _InnerCategoryKind.strength,
      ),
      _InnerCategory(
        label: 'Werte',
        items: values,
        kind: _InnerCategoryKind.value,
      ),
      _InnerCategory(
        label: 'Antreiber',
        items: drivers,
        kind: _InnerCategoryKind.driver,
      ),
    ];

    if (_activeIndex >= categories.length) {
      _activeIndex = 0;
    }

    final selected = categories[_activeIndex];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, _homeSectionGap),
      child: InkWell(
        onTap: () => context.push('/innen'),
        borderRadius: BorderRadius.circular(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _homeCardMinHeight),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: _cardDecoration(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Innen', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                _InnerFilterBar(
                  categories: categories,
                  activeIndex: _activeIndex,
                  onSelect: (i) => setState(() => _activeIndex = i),
                ),
                const SizedBox(height: 10),
              if (selected.kind == _InnerCategoryKind.personality)
                _PersonalityBigFiveCard(
                  details: personalityDetails,
                  personalityLevels: widget.personalityLevels,
                )
                else if (selected.items.isEmpty)
                  Text(
                    'Noch nichts ausgewählt.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.7),
                        ),
                  )
                else
                  _InnerListSummary(
                    items: selected.items,
                    descriptions: _detailDescriptionMap(
                      selected.kind == _InnerCategoryKind.strength
                          ? strengthsDetails
                          : selected.kind == _InnerCategoryKind.value
                              ? valuesDetails
                              : driversDetails,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InnerCategory {
  const _InnerCategory({
    required this.label,
    required this.items,
    required this.kind,
  });

  final String label;
  final List<CatalogItem> items;
  final _InnerCategoryKind kind;
}

enum _InnerCategoryKind { personality, strength, value, driver }

class _InnerFilterBar extends StatelessWidget {
  const _InnerFilterBar({
    required this.categories,
    required this.activeIndex,
    required this.onSelect,
  });

  final List<_InnerCategory> categories;
  final int activeIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final selected = i == activeIndex;
          final scheme = Theme.of(context).colorScheme;
          return ChoiceChip(
            label: Text(categories[i].label),
            selected: selected,
            onSelected: (_) => onSelect(i),
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
      ),
    );
  }
}

class _InnerListSummary extends StatelessWidget {
  const _InnerListSummary({
    required this.items,
    required this.descriptions,
  });

  final List<CatalogItem> items;
  final Map<String, String> descriptions;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          Text(items[i].title, style: Theme.of(context).textTheme.bodyMedium),
          if ((descriptions[items[i].id] ?? '').isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              descriptions[items[i].id]!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface.withOpacity(0.7),
                  ),
            ),
          ],
          if (i != items.length - 1) ...[
            const SizedBox(height: 10),
            Container(
              height: 1,
              color: scheme.onSurface.withOpacity(0.08),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ],
    );
  }
}

class _PersonalityBigFiveCard extends StatelessWidget {
  const _PersonalityBigFiveCard({
    required this.details,
    required this.personalityLevels,
  });

  final List<InnerCatalogDetail> details;
  final Map<String, int> personalityLevels;

  @override
  Widget build(BuildContext context) {
    final sortedDetails = List<InnerCatalogDetail>.from(details)
      ..sort((a, b) => a.sortRank.compareTo(b.sortRank));
    final ranked = _topPersonalityDetails(
      sortedDetails,
      personalityLevels,
    );
    final topDetails = ranked.take(5).toList();
    final labels = _buildSpiderLabels(topDetails);
    final levels = _buildSpiderLevels(topDetails, personalityLevels);
    final allMedium = levels.every((v) => (v - 0.5).abs() < 0.01);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 180,
          child: Center(
            child: _PersonalitySpiderDiagram(
              labels: labels,
              levels: levels,
              showCircle: allMedium,
            ),
          ),
        ),
      ],
    );
  }
}

class _PersonalitySpiderDiagram extends StatelessWidget {
  const _PersonalitySpiderDiagram({
    required this.labels,
    required this.levels,
    required this.showCircle,
  });

  final List<String> labels;
  final List<double> levels;
  final bool showCircle;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth < 180 ? constraints.maxWidth : 180.0;
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _SpiderChartPainter(
              labels: labels,
              levels: levels,
              showCircle: showCircle,
              labelStyle: Theme.of(context).textTheme.labelSmall ??
                  const TextStyle(fontSize: 11),
              axisColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
              dotColor: Theme.of(context).colorScheme.primary,
            ),
          ),
        );
      },
    );
  }
}

class _SpiderChartPainter extends CustomPainter {
  _SpiderChartPainter({
    required this.labels,
    required this.levels,
    required this.showCircle,
    required this.labelStyle,
    required this.axisColor,
    required this.dotColor,
  });

  final List<String> labels;
  final List<double> levels;
  final bool showCircle;
  final TextStyle labelStyle;
  final Color axisColor;
  final Color dotColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final outer = radius * 0.85;
    final inner = radius * 0.45;
    final axisPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final radarStroke = Paint()
      ..color = dotColor.withOpacity(0.7)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    final radarFill = Paint()
      ..color = dotColor.withOpacity(0.18)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, inner, axisPaint);
    canvas.drawCircle(center, outer, axisPaint);
    final angleStep = (2 * math.pi) / labels.length;
    for (var i = 0; i < labels.length; i++) {
      final angle = -math.pi / 2 + (angleStep * i);
      final axisEnd = Offset(
        center.dx + outer * math.cos(angle),
        center.dy + outer * math.sin(angle),
      );
      canvas.drawLine(center, axisEnd, axisPaint);
    }
    final dotPaint = Paint()..color = dotColor;
    final radarPath = Path();
    for (var i = 0; i < labels.length; i++) {
      final angle = -math.pi / 2 + (angleStep * i);
      final level = levels.length > i ? levels[i] : 0.5;
      final point = Offset(
        center.dx + outer * level * math.cos(angle),
        center.dy + outer * level * math.sin(angle),
      );
      if (i == 0) {
        radarPath.moveTo(point.dx, point.dy);
      } else {
        radarPath.lineTo(point.dx, point.dy);
      }
      canvas.drawCircle(point, 4.2, dotPaint);
    }
    if (labels.isNotEmpty) {
      if (showCircle) {
        final radius = outer * 0.5;
        canvas.drawCircle(center, radius, radarFill);
        canvas.drawCircle(center, radius, radarStroke);
      } else {
        radarPath.close();
        canvas.drawPath(radarPath, radarFill);
        canvas.drawPath(radarPath, radarStroke);
      }
    }
    for (var i = 0; i < labels.length; i++) {
      final angle = -math.pi / 2 + (angleStep * i);
      final labelRadius = outer + 12;
      final pos = Offset(
        center.dx + labelRadius * math.cos(angle),
        center.dy + labelRadius * math.sin(angle),
      );
      final textPainter = TextPainter(
        text: TextSpan(text: labels[i], style: labelStyle),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();
      final offset = Offset(
        pos.dx - textPainter.width / 2,
        pos.dy - textPainter.height / 2,
      );
      textPainter.paint(canvas, offset);
    }
  }

  @override
  bool shouldRepaint(_SpiderChartPainter oldDelegate) {
    return oldDelegate.levels != levels ||
        oldDelegate.labels != labels ||
        oldDelegate.showCircle != showCircle ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.dotColor != dotColor;
  }
}

List<double> _buildSpiderLevels(
  List<InnerCatalogDetail> details,
  Map<String, int> personalityLevels,
) {
  final levels = details
      .map((detail) =>
          _levelToRadius(personalityLevels[detail.id] ?? 1))
      .toList();
  while (levels.length < 5) {
    levels.add(_levelToRadius(1));
  }
  return levels.take(5).toList();
}

double _levelToRadius(int level) {
  switch (level) {
    case 0:
      return 0.25;
    case 2:
      return 1.0;
    case 1:
    default:
      return 0.5;
  }
}

List<String> _buildSpiderLabels(List<InnerCatalogDetail> details) {
  final labels = details.map((detail) => detail.title).toList();
  var i = labels.length + 1;
  while (labels.length < 5) {
    labels.add('Dimension $i');
    i += 1;
  }
  return labels.take(5).toList();
}

List<InnerCatalogDetail> _topPersonalityDetails(
  List<InnerCatalogDetail> details,
  Map<String, int> personalityLevels,
) {
  final ranked = List<InnerCatalogDetail>.from(details)
    ..sort((a, b) {
      final aLevel = personalityLevels[a.id] ?? 1;
      final bLevel = personalityLevels[b.id] ?? 1;
      if (aLevel != bLevel) return bLevel.compareTo(aLevel);
      return a.sortRank.compareTo(b.sortRank);
    });
  return ranked;
}

Map<String, String> _detailDescriptionMap(List<InnerCatalogDetail> details) {
  return {
    for (final detail in details)
      detail.id: detail.description.trim(),
  };
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
        final preview = pillars.take(5).toList();
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, _homeSectionGap),
          child: InkWell(
            onTap: () => context.push('/identitaet'),
            borderRadius: BorderRadius.circular(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: _homeCardMinHeight),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: _cardDecoration(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Identität',
                            style: Theme.of(context).textTheme.titleMedium),
                        const Spacer(),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (pillars.isEmpty)
                      Text(
                        'Lebensbereiche auswählen.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.7),
                            ),
                      )
                    else
                      _IdentityTrendGrid(
                        pillars: preview,
                        pillarScores: pillarScores,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) =>
          const _EmptyState('Identität konnte nicht geladen werden.'),
    );
  }
}

class _OnboardingStepData {
  const _OnboardingStepData({
    required this.step,
    required this.title,
    required this.body,
    required this.ctaLabel,
    required this.route,
  });

  final int step;
  final String title;
  final String body;
  final String ctaLabel;
  final String route;
}

class _TutorialStepData {
  const _TutorialStepData({
    required this.title,
    required this.hint,
    required this.body,
    required this.ctaLabel,
    required this.onAction,
  });

  final String title;
  final String hint;
  final String body;
  final String ctaLabel;
  final VoidCallback onAction;
}

_OnboardingStepData? _resolveOnboardingStep({
  required List<CatalogItem> values,
  required List<CatalogItem> strengths,
  required List<CatalogItem> drivers,
  required List<CatalogItem> personalities,
  required DayPlanSnapshot? dayPlan,
  required bool hasQuickPlan,
}) {
  final hasInnenBasis = values.isNotEmpty &&
      strengths.isNotEmpty &&
      drivers.isNotEmpty &&
      personalities.isNotEmpty;
  final hasDayPlan = (dayPlan?.items.isNotEmpty ?? false) ||
      (dayPlan?.blocks.isNotEmpty ?? false) ||
      hasQuickPlan;

  if (hasInnenBasis && hasDayPlan) {
    return null;
  }
  if (!hasInnenBasis) {
    return const _OnboardingStepData(
      step: 1,
      title: 'Innen-Basis wählen',
      body:
          'Wähle je 1 Stärke, 1 Wert, 1 Antreiber, 1 Persönlichkeit.',
      ctaLabel: 'Innen öffnen',
      route: '/innen',
    );
  }
  return const _OnboardingStepData(
    step: 2,
    title: 'Tagesplan starten',
    body: 'Lege Blöcke an oder füge ein To-Do hinzu.',
    ctaLabel: 'Tagesplan öffnen',
    route: '/system',
  );
}

List<_TutorialStepData> _tutorialSteps(
  BuildContext context, {
  required bool hasOnboarding,
}) {
  if (!hasOnboarding) return const [];
  return [
    _TutorialStepData(
      title: 'Innen-Basis wählen',
      hint: 'Kurz: 1 Auswahl pro Bereich.',
      body: 'Wähle je 1 Stärke, 1 Wert, 1 Antreiber, 1 Persönlichkeit.',
      ctaLabel: 'Innen öffnen',
      onAction: () => context.push('/innen'),
    ),
    _TutorialStepData(
      title: 'Tagesplan starten',
      hint: 'Kurz: Blöcke + Aufgaben setzen.',
      body: 'Lege Blöcke an und plane die wichtigsten Aufgaben.',
      ctaLabel: 'Tagesplan öffnen',
      onAction: () => context.push('/system'),
    ),
    _TutorialStepData(
      title: 'Leitbild setzen',
      hint: 'Kurz: Richtung für den Tag.',
      body: 'Formuliere dein Leitbild als tägliche Richtung.',
      ctaLabel: 'Leitbild öffnen',
      onAction: () => openLeitbildSheet(context),
    ),
  ];
}

List<Color> _tutorialColors(ThemeData theme) {
  return [
    const Color(0xFFEFF6FF),
    const Color(0xFFF2FBEF),
    const Color(0xFFFFF4E9),
  ];
}

class _TutorialCard extends StatefulWidget {
  const _TutorialCard({
    required this.steps,
    required this.onClose,
  });

  final List<_TutorialStepData> steps;
  final VoidCallback onClose;

  @override
  State<_TutorialCard> createState() => _TutorialCardState();
}

class _TutorialCardState extends State<_TutorialCard> {
  late final PageController _controller;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = _tutorialColors(theme);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _tutorialCardDecoration(context).copyWith(
        color: colors[_index % colors.length],
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _homeTutorialMinHeight),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: theme.colorScheme.primary,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  'Tutorial',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: 'Tutorial schließen',
                ),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 92,
              child: PageView.builder(
                controller: _controller,
                itemCount: widget.steps.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) {
                  final step = widget.steps[i];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        step.hint,
                        style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        step.body,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            _TutorialDots(count: widget.steps.length, index: _index),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                onPressed: widget.steps[_index].onAction,
                style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  textStyle: theme.textTheme.labelSmall,
                ),
                child: Text(widget.steps[_index].ctaLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TutorialDots extends StatelessWidget {
  const _TutorialDots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: List.generate(count, (i) {
        final active = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(right: 6),
          width: active ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            color:
                active ? scheme.primary : scheme.onSurface.withOpacity(0.2),
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }
}

class _InnerCheckinCard extends StatelessWidget {
  const _InnerCheckinCard({
    required this.answer,
    required this.onSelect,
    required this.onOpenInnen,
  });

  final String? answer;
  final ValueChanged<String> onSelect;
  final VoidCallback onOpenInnen;

  @override
  Widget build(BuildContext context) {
    final hasAnswer = answer != null && answer!.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Innen-Check-in', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            'Passt dein Tag zu deinem Inneren?',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Passt'),
                selected: answer == 'Passt',
                onSelected: (_) => onSelect('Passt'),
              ),
              ChoiceChip(
                label: const Text('Unsicher'),
                selected: answer == 'Unsicher',
                onSelected: (_) => onSelect('Unsicher'),
              ),
              ChoiceChip(
                label: const Text('Nicht stimmig'),
                selected: answer == 'Nicht stimmig',
                onSelected: (_) => onSelect('Nicht stimmig'),
              ),
            ],
          ),
          if (hasAnswer) ...[
            const SizedBox(height: 8),
            Text(
              'Heute erledigt',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onOpenInnen,
              child: const Text('Innen öffnen'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MissionReviewCard extends StatelessWidget {
  const _MissionReviewCard({
    required this.onReview,
    required this.lastReviewedAt,
  });

  final VoidCallback onReview;
  final DateTime? lastReviewedAt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Leitbild-Review',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            'Passt dein Leitbild noch zur Woche?',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          if (lastReviewedAt != null) ...[
            const SizedBox(height: 6),
            Text(
              'Letzte Prüfung: ${_formatShortDate(lastReviewedAt!)}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6),
                  ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onReview,
              child: const Text('Leitbild prüfen'),
            ),
          ),
        ],
      ),
    );
  }
}

BoxDecoration _cardDecoration(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  return BoxDecoration(
    color: scheme.surface,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: Colors.transparent),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: 20,
        offset: const Offset(0, 10),
      ),
    ],
  );
}

BoxDecoration _tutorialCardDecoration(BuildContext context) {
  return _cardDecoration(context);
}

BoxDecoration _missionCardDecoration(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  return BoxDecoration(
    gradient: LinearGradient(
      colors: [
        scheme.primary.withOpacity(0.12),
        scheme.secondary.withOpacity(0.12),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: Colors.transparent),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: 20,
        offset: const Offset(0, 10),
      ),
    ],
  );
}

DateTime? _missionReviewDate(
  UserMissionStatement? mission,
  String? lastReviewKey,
) {
  if (lastReviewKey != null) {
    return _parseDateKey(lastReviewKey);
  }
  return mission?.updatedAt;
}

String _formatShortDate(DateTime date) {
  final d = date.day.toString().padLeft(2, '0');
  final m = date.month.toString().padLeft(2, '0');
  return '$d.$m';
}

bool _shouldShowMissionReview(
  UserMissionStatement mission,
  String? lastReviewKey,
) {
  final now = DateTime.now();
  final lastReview = lastReviewKey == null ? null : _parseDateKey(lastReviewKey);
  final reference = lastReview ?? mission.updatedAt;
  return now.difference(reference).inDays >= 7;
}

DateTime? _parseDateKey(String value) {
  final parts = value.split('-');
  if (parts.length != 3) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return null;
  return DateTime(year, month, day);
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
      padding: EdgeInsets.zero,
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
  final expandedBlocks = _expandBlocksWithInstances(
    blocks,
    [
      ...orderedIds,
      ...todayPlan.keys,
    ],
  );
  final byId = {for (final block in expandedBlocks) block.id: block};
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

List<SystemBlock> _expandBlocksWithInstances(
  List<SystemBlock> blocks,
  Iterable<String> activeIds,
) {
  final byId = {for (final block in blocks) block.id: block};
  final expanded = List<SystemBlock>.from(blocks);
  for (final id in activeIds) {
    if (byId.containsKey(id)) continue;
    final baseId = _homeBaseBlockId(id);
    final base = byId[baseId];
    if (base == null) continue;
    final clone = SystemBlock(
      id: id,
      key: base.key,
      title: base.title,
      desc: base.desc,
      outcomes: base.outcomes,
      timeHint: base.timeHint,
      icon: base.icon,
      sortRank: base.sortRank,
      isActive: base.isActive,
    );
    expanded.add(clone);
    byId[id] = clone;
  }
  return expanded;
}

String _homeBaseBlockId(String id) {
  const separator = '__';
  final index = id.indexOf(separator);
  if (index == -1) return id;
  return id.substring(0, index);
}

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

