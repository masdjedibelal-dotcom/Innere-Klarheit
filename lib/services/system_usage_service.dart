import '../data/models/daily_usage_summary.dart';

enum UsageState {
  done,
  partial,
  missed,
  future,
}

class UsageSummary {
  final int blocks;
  final int methods;

  const UsageSummary({
    required this.blocks,
    required this.methods,
  });
}

class SystemUsageService {
  Map<DateTime, UsageState> buildUsageMap({
    required List<DailyUsageSummary> summaries,
    required DateTime from,
    required DateTime to,
  }) {
    final start = _dateOnly(from);
    final end = _dateOnly(to);
    final today = _dateOnly(DateTime.now());
    final days = end.difference(start).inDays;
    final map = <DateTime, UsageState>{};
    final lookup = {
      for (final s in summaries) _dateOnly(s.day): _stateFor(s)
    };
    for (var i = 0; i <= days; i++) {
      final date = start.add(Duration(days: i));
      if (date.isAfter(today)) {
        map[date] = UsageState.future;
      } else {
        map[date] = lookup[date] ?? UsageState.missed;
      }
    }
    return map;
  }

  UsageSummary summaryForDay(
    DateTime day,
    List<DailyUsageSummary> summaries,
  ) {
    final date = _dateOnly(day);
    final match = summaries.firstWhere(
      (s) => _dateOnly(s.day) == date,
      orElse: () => DailyUsageSummary(
        day: DateTime(2000, 1, 1),
        blocksCount: 0,
        methodsCount: 0,
      ),
    );
    return UsageSummary(blocks: match.blocksCount, methods: match.methodsCount);
  }

  UsageState _stateFor(DailyUsageSummary summary) {
    if (summary.blocksCount > 0 && summary.methodsCount > 0) {
      return UsageState.done;
    }
    if (summary.blocksCount > 0) return UsageState.partial;
    return UsageState.missed;
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }
}

