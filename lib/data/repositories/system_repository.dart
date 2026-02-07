import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/method_day_block.dart';
import '../models/method_v2.dart';
import '../models/system_block.dart';
import '../result.dart';
import '../supabase/supabase_parsers.dart';

class SystemRepository {
  final SupabaseClient _client;

  SystemRepository({required SupabaseClient client}) : _client = client;

  Future<Result<List<SystemBlock>>> fetchDayBlocks() async {
    try {
      final rows = await _selectDayBlocks();
      _logTableRows('day_blocks', rows);
      return Result.ok(rows.map(_mapBlock).toList());
    } on PostgrestException catch (e) {
      _logRlsIfNeeded(e, 'day_blocks');
      return Result.fail(_toError(e));
    } catch (e) {
      return Result.fail(DataError(message: 'day_blocks failed', cause: e));
    }
  }

  Future<Result<List<MethodV2>>> fetchMethods() async {
    try {
      final methodRows = await _selectMethodsSimple();
      final linkRows = await _selectMethodDayBlocks();
      final links = _groupMethodDayBlocks(linkRows);
      _logTableRows('methods_simple', methodRows);
      _logTableRows('method_day_blocks', linkRows);
      return Result.ok(
          methodRows.map((row) => _mapMethod(row, links)).toList());
    } on PostgrestException catch (e) {
      _logRlsIfNeeded(e, 'methods_simple');
      return Result.fail(_toError(e));
    } catch (e) {
      return Result.fail(DataError(message: 'methods_simple failed', cause: e));
    }
  }

  Future<Result<List<MethodV2>>> fetchHabits() async {
    try {
      final methodRows = await _selectMethodsSimple(methodType: 'habit');
      final linkRows = await _selectMethodDayBlocks();
      final links = _groupMethodDayBlocks(linkRows);
      _logTableRows('methods_simple (habits)', methodRows);
      return Result.ok(
          methodRows.map((row) => _mapMethod(row, links)).toList());
    } on PostgrestException catch (e) {
      _logRlsIfNeeded(e, 'methods_simple');
      return Result.fail(_toError(e));
    } catch (e) {
      return Result.fail(DataError(message: 'methods_simple failed', cause: e));
    }
  }

  Future<Result<List<MethodV2>>> fetchHabitContent(String habitKey) async {
    try {
      final methodRows = await _selectMethodsSimple(
        methodType: 'habit_content',
        habitKey: habitKey,
      );
      _logTableRows('methods_simple (habit_content)', methodRows);
      return Result.ok(
          methodRows.map((row) => _mapMethod(row, const {})).toList());
    } on PostgrestException catch (e) {
      _logRlsIfNeeded(e, 'methods_simple');
      return Result.fail(_toError(e));
    } catch (e) {
      return Result.fail(DataError(message: 'methods_simple failed', cause: e));
    }
  }

  Future<Result<List<MethodDayBlock>>> fetchMethodDayBlocks() async {
    try {
      final rows = await _selectMethodDayBlocks();
      _logTableRows('method_day_blocks', rows);
      return Result.ok(rows.map(_mapMethodDayBlock).toList());
    } on PostgrestException catch (e) {
      _logRlsIfNeeded(e, 'method_day_blocks');
      return Result.fail(_toError(e));
    } catch (e) {
      return Result.fail(
          DataError(message: 'method_day_blocks failed', cause: e));
    }
  }

  SystemBlock _mapBlock(Map<String, dynamic> row) {
    return SystemBlock(
      id: parseString(row['id']),
      key: parseString(row['key']),
      title: parseString(row['title']),
      desc:
          parseString(row['description'], fallback: parseString(row['desc'])),
      outcomes: parseList(row['outcomes']),
      timeHint: parseString(row['time_hint']),
      icon: parseString(row['icon']),
      sortRank: parseInt(row['sort_rank']),
      isActive: parseBool(row['is_active']),
    );
  }

  MethodV2 _mapMethod(
      Map<String, dynamic> row, Map<String, List<String>> dayBlocks) {
    final pillarKey = parseString(row['pillar_key']);
    final category = parseString(row['category']);
    final methodId = parseString(row['id']);
    return MethodV2(
      id: methodId,
      key: parseString(row['key'], fallback: category),
      pillarKey: pillarKey,
      methodLevel: parseString(row['method_level']),
      blockRole: parseString(row['block_role']),
      defaultSelected: parseBool(row['default_selected']),
      habitKey: parseString(row['habit_key']),
      habitContent: parseString(row['habit_content']),
      methodType: parseString(row['method_type']),
      contentType: parseString(row['content_type']),
      category: category,
      title: parseString(row['title']),
      shortDesc: parseString(row['description']),
      examples: const [],
      steps: parseList(row['steps']),
      durationMinutes: parseInt(row['duration_minutes']),
      benefit: parseString(row['benefit']),
      pitfalls: parseList(row['pitfalls']),
      impactTags: const [],
      contexts: dayBlocks[methodId] ?? const [],
      isActive: parseBool(row['is_active']),
      sortRank: parseInt(row['sort_rank']),
    );
  }

  MethodDayBlock _mapMethodDayBlock(Map<String, dynamic> row) {
    return MethodDayBlock(
      methodId: parseString(row['method_id']),
      dayBlockKey: parseString(row['day_block_key']),
      sortRank: parseInt(row['sort_rank']),
      isActive: parseBool(row['is_active']),
      blockRole: parseString(row['block_role']),
      defaultSelected: parseBool(row['default_selected']),
    );
  }

  Future<List<Map<String, dynamic>>> _selectDayBlocks() async {
    try {
      final response = await _client
          .from('day_blocks')
          .select()
          .eq('is_active', true)
          .order('sort_rank', ascending: true);
      return (response as List).cast<Map<String, dynamic>>();
    } on PostgrestException catch (e) {
      if (_isMissingColumn(e)) {
        final response = await _client
            .from('day_blocks')
            .select()
            .order('sort_rank', ascending: true);
        return (response as List).cast<Map<String, dynamic>>();
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> _selectMethodsSimple({
    String? methodType,
    String? habitKey,
  }) async {
    try {
      var query = _client
          .from('methods_simple')
          .select(
              'id,key,pillar_key,method_type,content_type,method_level,block_role,default_selected,habit_key,habit_content,category,title,description,duration_minutes,sort_rank,is_active');
      query = query.eq('is_active', true);
      if (methodType != null && methodType.isNotEmpty) {
        query = query.eq('method_type', methodType);
      }
      if (habitKey != null && habitKey.isNotEmpty) {
        query = query.eq('habit_key', habitKey);
      }
      final response = await query.order('sort_rank', ascending: true);
      return (response as List).cast<Map<String, dynamic>>();
    } on PostgrestException catch (e) {
      if (_isMissingColumn(e)) {
        final response =
            await _client.from('methods_simple').select().order('sort_rank', ascending: true);
        final rows = (response as List).cast<Map<String, dynamic>>();
        return rows.where((row) {
          if (methodType != null && methodType.isNotEmpty) {
            if (parseString(row['method_type']) != methodType) return false;
          }
          if (habitKey != null && habitKey.isNotEmpty) {
            if (parseString(row['habit_key']) != habitKey) return false;
          }
          return true;
        }).toList();
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> _selectMethodDayBlocks() async {
    try {
      final response = await _client
          .from('method_day_blocks')
          .select('method_id,day_block_key,sort_rank,is_active,block_role,default_selected')
          .eq('is_active', true)
          .order('sort_rank', ascending: true);
      return (response as List).cast<Map<String, dynamic>>();
    } on PostgrestException catch (e) {
      if (_isMissingColumn(e)) {
        final response = await _client
            .from('method_day_blocks')
            .select('method_id,day_block_key');
        return (response as List).cast<Map<String, dynamic>>();
      }
      rethrow;
    }
  }

  Map<String, List<String>> _groupMethodDayBlocks(
      List<Map<String, dynamic>> rows) {
    final map = <String, List<_ExampleItem>>{};
    for (final row in rows) {
      final methodId = parseString(row['method_id']);
      final dayBlockKey = parseString(row['day_block_key']);
      if (methodId.isEmpty || dayBlockKey.isEmpty) continue;
      final key = methodId;
      final list = map.putIfAbsent(key, () => []);
      list.add(_ExampleItem(
        rank: parseInt(row['sort_rank']),
        text: dayBlockKey,
      ));
    }
    final result = <String, List<String>>{};
    for (final entry in map.entries) {
      final sorted = entry.value..sort((a, b) => a.rank.compareTo(b.rank));
      result[entry.key] = sorted.map((e) => e.text).toList();
    }
    return result;
  }

  bool _isMissingColumn(PostgrestException e) {
    final msg = e.message.toLowerCase();
    return msg.contains('does not exist') && msg.contains('column');
  }
}

void _logRlsIfNeeded(PostgrestException e, String table) {
  final msg = e.message.toLowerCase();
  if (msg.contains('permission') || msg.contains('rls')) {
    // ignore: avoid_print
    print(
        'RLS WARN: SELECT blocked. Please verify RLS SELECT policy for $table.');
  }
}

void _logTableRows(String table, List<Map<String, dynamic>> rows) {
  final keys = rows.isNotEmpty ? rows.first.keys.toList() : const [];
  // ignore: avoid_print
  print('Loaded ${rows.length} $table, keys: $keys');
}

DataError _toError(PostgrestException e) {
  return DataError(
    message: e.message,
    details: e.details?.toString(),
    hint: e.hint?.toString(),
    code: e.code,
  );
}

class _ExampleItem {
  final int rank;
  final String text;

  const _ExampleItem({required this.rank, required this.text});
}
