import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/daily_usage_summary.dart';
import '../supabase/auth_helpers.dart';

class DailyUsageRepository {
  DailyUsageRepository({required SupabaseClient client}) : _client = client;

  final SupabaseClient _client;

  Future<DailyUsageSummary> upsertDailySummary({
    required DateTime day,
    required int blocksCount,
    required int methodsCount,
  }) async {
    final uid = requireUser(_client) ?? (throw Exception('No auth user'));
    final payload = {
      'user_id': uid,
      'day': _dateKey(day),
      'blocks_count': blocksCount,
      'methods_count': methodsCount,
    };
    final response = await _client
        .from('daily_usage')
        .upsert(payload, onConflict: 'user_id,day')
        .select('day,blocks_count,methods_count')
        .single();
    return _mapRow(response);
  }

  Future<List<DailyUsageSummary>> listRange(DateTime from, DateTime to) async {
    final uid = requireUser(_client) ?? (throw Exception('No auth user'));
    final response = await _client
        .from('daily_usage')
        .select('day,blocks_count,methods_count')
        .eq('user_id', uid)
        .gte('day', _dateKey(from))
        .lte('day', _dateKey(to))
        .order('day', ascending: true);
    final rows = (response as List).cast<Map<String, dynamic>>();
    return rows.map(_mapRow).toList();
  }

  DailyUsageSummary _mapRow(Map<String, dynamic> row) {
    final day = DateTime.parse(row['day'].toString());
    return DailyUsageSummary(
      day: DateTime(day.year, day.month, day.day),
      blocksCount: (row['blocks_count'] ?? 0) as int,
      methodsCount: (row['methods_count'] ?? 0) as int,
    );
  }

  String _dateKey(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return d.toIso8601String().split('T').first;
  }
}




