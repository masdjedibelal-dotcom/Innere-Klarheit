import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/daily_usage_summary.dart';
import '../data/models/user_profile.dart';
import 'user_state.dart';

class UsageRange {
  final DateTime from;
  final DateTime to;

  const UsageRange({required this.from, required this.to});

  @override
  bool operator ==(Object other) {
    return other is UsageRange && other.from == from && other.to == to;
  }

  @override
  int get hashCode => Object.hash(from, to);
}

final userProfileProvider = FutureProvider<UserProfile>((ref) async {
  return ref.read(userProfileRepoProvider).getOrCreate();
});

final dailyUsageRangeProvider =
    FutureProvider.family<List<DailyUsageSummary>, UsageRange>((ref, range) {
  return ref.read(dailyUsageRepoProvider).listRange(range.from, range.to);
});




