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

  Future<Result<KnowledgeSnackPage>> fetchSnacksPage({
    required int offset,
    required int limit,
    String? tag,
    List<String>? ids,
  }) async {
    try {
      var query = _client
          .from('knowledge_snacks')
          .select(
              'id,title,preview,content,tags,read_time_minutes,sort_rank,is_published,created_at')
          .eq('is_published', true);

      if (tag != null && tag.isNotEmpty) {
        query = query.filter('tags', 'cs', '{$tag}');
      }

      if (ids != null) {
        query = query.filter('id', 'in', _toInFilter(ids));
      }

      final response = await query
          .order('sort_rank', ascending: true)
          .range(offset, offset + limit);
      final rows = (response as List).cast<Map<String, dynamic>>();
      final hasMore = rows.length > limit;
      final pageRows = hasMore ? rows.sublist(0, limit) : rows;
      final items = pageRows.map(_mapRow).toList();
      return Result.ok(KnowledgeSnackPage(items: items, hasMore: hasMore));
    } on PostgrestException catch (e) {
      _logRlsIfNeeded(e);
      return Result.fail(_toError(e));
    } catch (e) {
      return Result.fail(
        DataError(message: 'knowledge_snacks page failed', cause: e),
      );
    }
  }

  Future<Result<List<String>>> fetchSnackTags() async {
    try {
      final response = await _client
          .from('knowledge_snacks')
          .select('tags')
          .eq('is_published', true);
      final rows = (response as List).cast<Map<String, dynamic>>();
      final tags = <String>{};
      for (final row in rows) {
        final rowTags = parseList(row['tags']);
        tags.addAll(rowTags.map((e) => e.toString()));
      }
      final list = tags.toList()..sort();
      return Result.ok(list);
    } on PostgrestException catch (e) {
      _logRlsIfNeeded(e);
      return Result.fail(_toError(e));
    } catch (e) {
      return Result.fail(
        DataError(message: 'knowledge_snacks tags failed', cause: e),
      );
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

class KnowledgeSnackPage {
  final List<KnowledgeSnack> items;
  final bool hasMore;

  const KnowledgeSnackPage({
    required this.items,
    required this.hasMore,
  });
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

String _toInFilter(List<String> ids) {
  final quoted = ids.map((id) => '"$id"').join(',');
  return '($quoted)';
}
