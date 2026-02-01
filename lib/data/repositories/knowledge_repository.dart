import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/knowledge_snack.dart';
import '../result.dart';
import '../supabase/supabase_parsers.dart';

class KnowledgeRepository {
  final SupabaseClient _client;

  KnowledgeRepository({required SupabaseClient client}) : _client = client;

  Future<Result<List<KnowledgeSnack>>> fetchSnacks() async {
    try {
      final response = await _client
          .from('knowledge_snacks')
          .select('id,title,preview,content,tags,read_time_minutes,sort_rank,is_published,created_at')
          .eq('is_published', true)
          .order('sort_rank', ascending: true);

      final rows = (response as List).cast<Map<String, dynamic>>();
      _logTableRows('knowledge_snacks', rows);
      final items = rows.map(_mapRow).toList();
      return Result.ok(items);
    } on PostgrestException catch (e) {
      _logRlsIfNeeded(e);
      return Result.fail(_toError(e));
    } catch (e) {
      return Result.fail(DataError(message: 'knowledge_snacks failed', cause: e));
    }
  }

  Future<Result<KnowledgeSnack?>> getById(String id) async {
    try {
      final response = await _client
          .from('knowledge_snacks')
          .select('id,title,preview,content,tags,read_time_minutes,sort_rank,is_published,created_at')
          .eq('id', id)
          .limit(1);

      final rows = (response as List).cast<Map<String, dynamic>>();
      _logTableRows('knowledge_snacks[id]', rows);
      if (rows.isEmpty) return Result.ok(null);
      return Result.ok(_mapRow(rows.first));
    } on PostgrestException catch (e) {
      _logRlsIfNeeded(e);
      return Result.fail(_toError(e));
    } catch (e) {
      return Result.fail(
        DataError(message: 'knowledge_snacks[id] failed', cause: e),
      );
    }
  }

  KnowledgeSnack _mapRow(Map<String, dynamic> row) {
    return KnowledgeSnack(
      id: parseString(row['id']),
      title: parseString(row['title']),
      preview: parseString(row['preview']),
      content: parseString(row['content']),
      tags: parseList(row['tags']),
      readTimeMinutes: parseInt(row['read_time_minutes']),
      sortRank: parseInt(row['sort_rank']),
      isPublished: parseBool(row['is_published']),
      createdAt: parseDateTime(row['created_at']),
    );
  }
}

void _logRlsIfNeeded(PostgrestException e) {
  final msg = e.message.toLowerCase();
  if (msg.contains('permission') || msg.contains('rls')) {
    // ignore: avoid_print
    print(
        'RLS WARN: SELECT blocked. Please verify RLS SELECT policy for knowledge_snacks.');
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
