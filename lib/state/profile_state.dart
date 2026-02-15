import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/daily_usage_summary.dart';
import '../data/models/user_profile.dart';
import 'user_state.dart';
import '../data/supabase/supabase_client_provider.dart';

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
  final client = ref.read(supabaseClientProvider);
  final email = client.auth.currentUser?.email ?? '';
  if (email.isEmpty) {
    final now = DateTime.now();
    return UserProfile(
      id: '',
      displayName: '',
      createdAt: now,
      lastActiveAt: now,
    );
  }
  return ref.read(userProfileRepoProvider).getOrCreate();
});

final dailyUsageRangeProvider =
    FutureProvider.family<List<DailyUsageSummary>, UsageRange>((ref, range) {
  final client = ref.read(supabaseClientProvider);
  final email = client.auth.currentUser?.email ?? '';
  if (email.isEmpty) return Future.value(const <DailyUsageSummary>[]);
  return ref.read(dailyUsageRepoProvider).listRange(range.from, range.to);
});




