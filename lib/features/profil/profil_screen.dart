import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/user_state.dart';
import '../../state/profile_state.dart';
import '../../services/system_usage_service.dart';
import '../../widgets/bottom_sheet/bottom_card_sheet.dart';
import '../../data/models/daily_usage_summary.dart';
import '../../data/models/system_block.dart';
import '../../data/models/method_v2.dart';

class ProfilScreen extends ConsumerStatefulWidget {
  const ProfilScreen({super.key});

  @override
  ConsumerState<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends ConsumerState<ProfilScreen> {
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userStateProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Zurück',
        ),
        title: const Text('Profil'),
        centerTitle: false,
      ),
      body: SafeArea(
        child: _ProfileDashboard(user: user),
      ),
    );
  }
}

class _ProfileDashboard extends ConsumerStatefulWidget {
  const _ProfileDashboard({required this.user});
  final UserState user;

  @override
  ConsumerState<_ProfileDashboard> createState() =>
      _ProfileDashboardState();
}

class _ProfileDashboardState extends ConsumerState<_ProfileDashboard> {
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final profileAsync = ref.watch(userProfileProvider);
    final name = profileAsync.asData?.value.displayName.isNotEmpty == true
        ? profileAsync.asData!.value.displayName
        : 'Du';
    final initials = name.trim().isEmpty ? 'C' : name.trim()[0].toUpperCase();
    final today = _dateOnly(DateTime.now());
    final monthStart = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final monthEnd =
        DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0);
    final usageAsync = ref.watch(
      dailyUsageRangeProvider(UsageRange(from: monthStart, to: monthEnd)),
    );
    final service = SystemUsageService();
    final summaries = usageAsync.asData?.value ?? const <DailyUsageSummary>[];
    final usageMap = service.buildUsageMap(
      summaries: summaries,
      from: monthStart,
      to: monthEnd,
    );
    final todayState = usageMap[today] ?? UsageState.missed;
    final activeDays = _countActiveDays(usageMap);
    final streak = _currentStreak(usageMap, today);
    final topBlock = _topBlockLabel(user);
    final motivation = _motivationFor(activeDays, streak, todayState);

    final blocksAsync = ref.watch(systemBlocksProvider);
    final methodsAsync = ref.watch(systemMethodsProvider);
    final blockTitleById = {
      for (final b in blocksAsync.asData?.value ?? const <SystemBlock>[])
        b.id: b.title
    };
    final methodTitleById = {
      for (final m in methodsAsync.asData?.value ?? const <MethodV2>[])
        m.id: m.title
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(30, 16, 30, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor:
                      Theme.of(context).colorScheme.surfaceVariant,
                  child: Text(
                    initials,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  Text('Hallo, $name',
                      style: Theme.of(context).textTheme.titleLarge),
                    Text('Dein System in Zahlen.',
                        style: Theme.of(context).textTheme.bodySmall),
                  if (profileAsync.asData?.value.lastActiveAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Zuletzt aktiv: ${_formatShortDate(profileAsync.asData!.value.lastActiveAt)}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.6),
                          ),
                    ),
                  ],
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(30, 8, 30, 6),
            child: _CalendarHeader(
              month: _visibleMonth,
              onPrev: () => setState(() {
                _visibleMonth =
                    DateTime(_visibleMonth.year, _visibleMonth.month - 1);
              }),
              onNext: () => setState(() {
                _visibleMonth =
                    DateTime(_visibleMonth.year, _visibleMonth.month + 1);
              }),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(30, 0, 30, 10),
            child: _MonthCalendarGrid(
              month: _visibleMonth,
              usageMap: usageMap,
              onTap: (date) => _showDayDetails(
                context,
                date: date,
                state: usageMap[date] ?? UsageState.missed,
                summary: service.summaryForDay(date, summaries),
                blocks: _blocksForDate(
                  date,
                  user: user,
                  blockTitleById: blockTitleById,
                ),
                methods: _methodsForDate(
                  date,
                  user: user,
                  methodTitleById: methodTitleById,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(30, 0, 30, 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: const [
                _LegendItem(label: 'Grün = System genutzt', state: UsageState.done),
                _LegendItem(label: 'Gelb = gestartet', state: UsageState.partial),
                _LegendItem(label: 'Grau = nicht genutzt', state: UsageState.missed),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(30, 6, 30, 10),
            child: Row(
              children: [
                Expanded(
                  child: _KpiCard(
                    label: 'Aktive Tage',
                    value: '$activeDays',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _KpiCard(
                    label: 'Streak',
                    value: '$streak',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _KpiCard(
                    label: 'Top Block',
                    value: topBlock,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(30, 6, 30, 20),
            child: Text(
              motivation,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.75),
                  ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(30, 0, 30, 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => context.go('/system'),
                child: Text(
                  todayState == UsageState.done
                      ? 'Für morgen vorbereiten'
                      : 'Tag jetzt strukturieren',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarHeader extends StatelessWidget {
  const _CalendarHeader({
    required this.month,
    required this.onPrev,
    required this.onNext,
  });

  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          _monthTitle(month),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const Spacer(),
        IconButton(
          onPressed: onPrev,
          icon: const Icon(Icons.chevron_left),
          iconSize: 20,
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          tooltip: 'Vorheriger Monat',
        ),
        IconButton(
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
          iconSize: 20,
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          tooltip: 'Nächster Monat',
        ),
      ],
    );
  }
}

class _MonthCalendarGrid extends StatelessWidget {
  const _MonthCalendarGrid({
    required this.month,
    required this.usageMap,
    required this.onTap,
  });

  final DateTime month;
  final Map<DateTime, UsageState> usageMap;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final days = _daysInMonth(month);
    final leading = _leadingEmptySlots(month);
    final total = leading + days;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: _weekdayLabels
              .map(
                (d) => Expanded(
                  child: Text(
                    d,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.6),
                        ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 1,
          ),
          itemCount: total,
          itemBuilder: (_, i) {
            if (i < leading) {
              return const SizedBox.shrink();
            }
            final day = i - leading + 1;
            final date = DateTime(month.year, month.month, day);
            final state = usageMap[date] ?? UsageState.missed;
            return InkWell(
              onTap: () => onTap(date),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _stateColor(context, state),
                  borderRadius: BorderRadius.circular(6),
                  border: state == UsageState.future
                      ? Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .outline
                              .withOpacity(0.2),
                        )
                      : null,
                ),
                child: Text(
                  '$day',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.75),
                      ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.7),
                ),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.label, required this.state});

  final String label;
  final UsageState state;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            color: _stateColor(context, state),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color:
                    Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
        ),
      ],
    );
  }
}

Color _stateColor(BuildContext context, UsageState state) {
  final scheme = Theme.of(context).colorScheme;
  switch (state) {
    case UsageState.done:
      return const Color(0xFF66B18A);
    case UsageState.partial:
      return const Color(0xFFE6C86E);
    case UsageState.missed:
      return scheme.surfaceVariant.withOpacity(0.7);
    case UsageState.future:
      return Colors.transparent;
  }
}

int _countActiveDays(Map<DateTime, UsageState> usageMap) {
  return usageMap.values
      .where((s) => s == UsageState.done || s == UsageState.partial)
      .length;
}

int _currentStreak(Map<DateTime, UsageState> usageMap, DateTime today) {
  var streak = 0;
  for (var i = 0; i < 365; i++) {
    final date = today.subtract(Duration(days: i));
    final state = usageMap[date];
    if (state == UsageState.done) {
      streak += 1;
    } else {
      break;
    }
  }
  return streak;
}

String _topBlockLabel(UserState user) {
  // TODO: Map blockId to actual block title via repository/cache.
  if (user.todayPlan.isEmpty) return '–';
  return '–';
}

String _motivationFor(
  int activeDays,
  int streak,
  UsageState todayState,
) {
  if (streak >= 3) return 'Wenn du startest, bleibst du meist dran.';
  if (activeDays >= 8) return 'Dein System wirkt durch Wiederholung.';
  if (todayState == UsageState.partial) {
    return 'Ein kurzer Start reicht, um dranzubleiben.';
  }
  return 'Ein ruhiger Start macht den Unterschied.';
}

void _showDayDetails(
  BuildContext context, {
  required DateTime date,
  required UsageState state,
  required UsageSummary summary,
  required List<String> blocks,
  required List<String> methods,
}) {
  showBottomCardSheet(
    context: context,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_formatMediumDate(date),
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        Text(
          _usageLabel(state),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color:
                    Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
        ),
        const SizedBox(height: 12),
        Text(
          'Methoden: ${summary.methods} · Blöcke: ${summary.blocks}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color:
                    Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
        ),
        const SizedBox(height: 12),
        _DetailAccordion(
          blocks: blocks,
          methods: methods,
        ),
      ],
    ),
  );
}

String _usageLabel(UsageState state) {
  switch (state) {
    case UsageState.done:
      return 'System genutzt';
    case UsageState.partial:
      return 'Gestartet';
    case UsageState.missed:
      return 'Nicht genutzt';
    case UsageState.future:
      return 'Zukünftig';
  }
}

DateTime _dateOnly(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

String _formatShortDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}.'
      '${date.month.toString().padLeft(2, '0')}.'
      '${date.year}';
}

String _formatMediumDate(DateTime date) {
  return _formatShortDate(date);
}

class _DetailAccordion extends StatelessWidget {
  const _DetailAccordion({
    required this.blocks,
    required this.methods,
  });

  final List<String> blocks;
  final List<String> methods;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _AccordionSection(
          title: 'Blöcke',
          items: blocks,
          emptyText: 'Keine Blöcke für diesen Tag.',
        ),
        const SizedBox(height: 8),
        _AccordionSection(
          title: 'Methoden',
          items: methods,
          emptyText: 'Keine Methoden für diesen Tag.',
        ),
      ],
    );
  }
}

class _AccordionSection extends StatelessWidget {
  const _AccordionSection({
    required this.title,
    required this.items,
    required this.emptyText,
  });

  final String title;
  final List<String> items;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 6),
      title: Text(title, style: Theme.of(context).textTheme.labelLarge),
      children: [
        if (items.isEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              emptyText,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.65),
                  ),
            ),
          )
        else
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '• $item',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
      ],
    );
  }
}

const _weekdayLabels = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

int _daysInMonth(DateTime month) {
  final next = DateTime(month.year, month.month + 1, 1);
  return next.subtract(const Duration(days: 1)).day;
}

int _leadingEmptySlots(DateTime month) {
  final first = DateTime(month.year, month.month, 1);
  return (first.weekday + 6) % 7;
}

String _monthTitle(DateTime month) {
  const names = [
    'Januar',
    'Februar',
    'März',
    'April',
    'Mai',
    'Juni',
    'Juli',
    'August',
    'September',
    'Oktober',
    'November',
    'Dezember',
  ];
  return '${names[month.month - 1]} ${month.year}';
}

List<String> _blocksForDate(
  DateTime date, {
  required UserState user,
  required Map<String, String> blockTitleById,
}) {
  final today = _dateOnly(DateTime.now());
  if (!_isSameDay(date, today)) return const [];
  return user.todayPlan.keys
      .map((id) => blockTitleById[id] ?? 'Block')
      .toList();
}

List<String> _methodsForDate(
  DateTime date, {
  required UserState user,
  required Map<String, String> methodTitleById,
}) {
  final today = _dateOnly(DateTime.now());
  if (!_isSameDay(date, today)) return const [];
  final ids = user.todayPlan.values
      .expand((b) => b.methodIds)
      .toSet()
      .toList();
  return ids.map((id) => methodTitleById[id] ?? 'Methode').toList();
}

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
