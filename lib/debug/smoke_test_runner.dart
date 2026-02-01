import 'package:supabase_flutter/supabase_flutter.dart';

class SmokeTestResult {
  final String table;
  final int count;
  final String? firstTitle;
  final String? error;

  const SmokeTestResult({
    required this.table,
    required this.count,
    required this.firstTitle,
    required this.error,
  });

  bool get isSuccess => error == null;

  factory SmokeTestResult.error(String table, String message) {
    return SmokeTestResult(
      table: table,
      count: 0,
      firstTitle: null,
      error: message,
    );
  }
}

class SmokeTestRunner {
  final SupabaseClient client;

  SmokeTestRunner({required this.client});

  Future<List<SmokeTestResult>> run() async {
    final results = <SmokeTestResult>[];
    results.add(await _testTable('knowledge_snacks'));
    results.add(await _testTable('day_blocks'));
    results.add(await _testTable('methods_simple'));
    results.add(await _testTable('method_day_blocks'));
    results.add(await _testTable('identity_roles'));
    results.add(await _testTable('inner_items'));
    results.add(await _testTable('inner_strengths'));
    results.add(await _testTable('inner_values'));
    results.add(await _testTable('inner_drivers'));
    results.add(await _testTable('inner_personality_dimensions'));
    return results;
  }

  Future<SmokeTestResult> _testTable(String table) async {
    try {
      final response = await client
          .from(table)
          .select('id,title')
          .order('sort_rank', ascending: true)
          .limit(50);
      final rows = (response as List).cast<Map<String, dynamic>>();
      final count = rows.length;
      final firstTitle =
          rows.isNotEmpty ? rows.first['title']?.toString() : null;
      return SmokeTestResult(
        table: table,
        count: count,
        firstTitle: firstTitle,
        error: null,
      );
    } on PostgrestException catch (e) {
      final details = e.details?.toString();
      final hint = e.hint?.toString();
      final parts = [
        e.message,
        if (details != null && details.isNotEmpty) details,
        if (hint != null && hint.isNotEmpty) hint,
      ];
      return SmokeTestResult.error(table, parts.join(' | '));
    } catch (e) {
      return SmokeTestResult.error(table, e.toString());
    }
  }
}

