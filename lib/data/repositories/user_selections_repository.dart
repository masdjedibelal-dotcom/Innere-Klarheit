import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/catalog_item.dart';
import '../result.dart';
import '../supabase/auth_helpers.dart';
import '../supabase/supabase_parsers.dart';

class UserSelectionsRepository {
  final SupabaseClient _client;

  UserSelectionsRepository({required SupabaseClient client}) : _client = client;

  Future<Result<List<CatalogItem>>> fetchUserSelectedValues() async {
    return _fetchUserSelections(
      table: 'user_inner_values',
      joinTable: 'inner_values',
    );
  }

  Future<Result<List<CatalogItem>>> fetchUserSelectedStrengths() async {
    return _fetchUserSelections(
      table: 'user_inner_strengths',
      joinTable: 'inner_strengths',
    );
  }

  Future<Result<List<CatalogItem>>> fetchUserSelectedDrivers() async {
    return _fetchUserSelections(
      table: 'user_inner_drivers',
      joinTable: 'inner_drivers',
    );
  }

  Future<Result<List<CatalogItem>>> fetchUserSelectedPersonality() async {
    return _fetchUserSelections(
      table: 'user_inner_personality',
      joinTable: 'inner_personality_dimensions',
    );
  }

  Future<Result<int>> upsertSelectedValues(List<String> valueIds) async {
    return _upsertSelections(
      table: 'user_inner_values',
      itemIdColumn: 'inner_value_id',
      itemIds: valueIds,
    );
  }

  Future<Result<int>> upsertSelectedStrengths(List<String> strengthIds) async {
    return _upsertSelections(
      table: 'user_inner_strengths',
      itemIdColumn: 'inner_strength_id',
      itemIds: strengthIds,
    );
  }

  Future<Result<int>> upsertSelectedDrivers(List<String> driverIds) async {
    return _upsertSelections(
      table: 'user_inner_drivers',
      itemIdColumn: 'inner_driver_id',
      itemIds: driverIds,
    );
  }

  Future<Result<int>> upsertSelectedPersonality(
      List<String> dimensionIds) async {
    return _upsertSelections(
      table: 'user_inner_personality',
      itemIdColumn: 'inner_personality_dimension_id',
      itemIds: dimensionIds,
    );
  }

  Future<Result<List<CatalogItem>>> _fetchUserSelections({
    required String table,
    required String joinTable,
  }) async {
    final uid = requireUser(_client);
    if (uid == null) {
      return Result.fail(DataError(message: 'Not logged in'));
    }

    try {
      final response = await _client
          .from(table)
          .select('$joinTable(id,title,sort_rank)')
          .eq('user_id', uid);
      final rows = (response as List).cast<Map<String, dynamic>>();
      _logTableRows(table, rows);
      final items = rows
          .map((row) => row[joinTable] as Map<String, dynamic>?)
          .whereType<Map<String, dynamic>>()
          .map(
            (row) => CatalogItem(
              id: parseString(row['id']),
              title: parseString(row['title']),
              sortRank: parseInt(row['sort_rank']),
            ),
          )
          .toList();
      return Result.ok(items);
    } on PostgrestException catch (e) {
      _logRlsIfNeeded(e, table);
      return Result.fail(_toError(e));
    } catch (e) {
      return Result.fail(DataError(message: '$table failed', cause: e));
    }
  }

  Future<Result<int>> _upsertSelections({
    required String table,
    required String itemIdColumn,
    required List<String> itemIds,
  }) async {
    final uid = requireUser(_client);
    if (uid == null) {
      return Result.fail(DataError(message: 'Not logged in'));
    }

    try {
      final rows = itemIds
          .map((id) => {'user_id': uid, itemIdColumn: id})
          .toList();
      final response = await _client.from(table).upsert(rows).select();
      final list = (response as List).cast<Map<String, dynamic>>();
      final inserted = list.length;
      _logTableRows(table, list);
      return Result.ok(inserted);
    } on PostgrestException catch (e) {
      _logRlsIfNeeded(e, table);
      return Result.fail(_toError(e));
    } catch (e) {
      return Result.fail(DataError(message: '$table upsert failed', cause: e));
    }
  }
}

void _logRlsIfNeeded(PostgrestException e, String table) {
  final msg = e.message.toLowerCase();
  if (msg.contains('permission') || msg.contains('rls')) {
    // ignore: avoid_print
    print('RLS WARN: SELECT blocked. Verify RLS policy for $table.');
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

