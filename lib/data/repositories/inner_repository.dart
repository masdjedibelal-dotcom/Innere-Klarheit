import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/catalog_item.dart';
import '../models/inner_catalog_detail.dart';
import '../models/inner_item.dart';
import '../result.dart';
import '../supabase/supabase_parsers.dart';

class InnerRepository {
  final SupabaseClient _client;

  InnerRepository({required SupabaseClient client}) : _client = client;

  Future<Result<List<InnerItem>>> fetchInnerItems() async {
    try {
      final response = await _client
          .from('inner_items')
          .select(
              'id,type,title,short_desc,long_desc,questions,pitfalls,tags,sort_rank,is_active')
          .eq('is_active', true)
          .order('sort_rank', ascending: true);

      final rows = (response as List).cast<Map<String, dynamic>>();
      _logTableRows('inner_items', rows);
      final items = rows.map(_mapRow).toList();
      return Result.ok(items);
    } on PostgrestException catch (e) {
      _logRlsIfNeeded(e, 'inner_items');
      return Result.fail(_toError(e));
    } catch (e) {
      return Result.fail(DataError(message: 'inner_items failed', cause: e));
    }
  }

  Future<Result<List<CatalogItem>>> fetchValues() async {
    return _fetchCatalog('inner_values');
  }

  Future<Result<List<CatalogItem>>> fetchStrengths() async {
    return _fetchCatalog('inner_strengths');
  }

  Future<Result<List<CatalogItem>>> fetchDrivers() async {
    return _fetchCatalog('inner_drivers');
  }

  Future<Result<List<CatalogItem>>> fetchPersonalityDims() async {
    return _fetchCatalog('inner_personality_dimensions');
  }

  Future<Result<List<InnerCatalogDetail>>> fetchStrengthDetails() async {
    return _fetchStrengthDetails();
  }

  Future<Result<List<InnerCatalogDetail>>> fetchValueDetails() async {
    return _fetchValueDetails();
  }

  Future<Result<List<InnerCatalogDetail>>> fetchDriverDetails() async {
    return _fetchDriverDetails();
  }

  Future<Result<List<InnerCatalogDetail>>> fetchPersonalityDetails() async {
    return _fetchPersonalityDetails();
  }

  InnerItem _mapRow(Map<String, dynamic> row) {
    return InnerItem(
      id: parseString(row['id']),
      type: _parseInnerType(row['type']),
      title: parseString(row['title']),
      shortDesc: parseString(row['short_desc']),
      longDesc: parseString(row['long_desc']),
      questions: parseList(row['questions']),
      pitfalls: parseList(row['pitfalls']),
      tags: parseList(row['tags']),
      sortRank: parseInt(row['sort_rank']),
      isActive: parseBool(row['is_active']),
    );
  }

  Future<Result<List<CatalogItem>>> _fetchCatalog(String table) async {
    try {
      final response = await _client
          .from(table)
          .select('id,title,sort_rank')
          .order('sort_rank', ascending: true);
      final rows = (response as List).cast<Map<String, dynamic>>();
      _logTableRows(table, rows);
      final items = rows
          .map((row) => CatalogItem(
                id: parseString(row['id']),
                title: parseString(row['title']),
                sortRank: parseInt(row['sort_rank']),
              ))
          .toList();
      return Result.ok(items);
    } on PostgrestException catch (e) {
      _logRlsIfNeeded(e, table);
      return Result.fail(_toError(e));
    } catch (e) {
      return Result.fail(DataError(message: '$table failed', cause: e));
    }
  }

  Future<Result<List<InnerCatalogDetail>>> _fetchStrengthDetails() async {
    try {
      final response = await _client
          .from('inner_strengths')
          .select(
              'id,key,title,description,examples,use_cases,reflection_question,sort_rank,is_active')
          .eq('is_active', true)
          .order('sort_rank', ascending: true);
      final rows = (response as List).cast<Map<String, dynamic>>();
      _logTableRows('inner_strengths', rows);
      final items = rows
          .map((row) => InnerCatalogDetail(
                id: parseString(row['id']),
                key: parseString(row['key']),
                title: parseString(row['title']),
                description: parseString(row['description']),
                examples: parseList(row['examples']),
                useCases: parseList(row['use_cases']),
                reflectionQuestion: parseString(row['reflection_question']),
                reflectionQuestions: const [],
                protectionFunction: '',
                shadowSide: '',
                reframe: '',
                helpsWith: const [],
                watchOutFor: const [],
                sortRank: parseInt(row['sort_rank']),
                isActive: parseBool(row['is_active']),
              ))
          .toList();
      return Result.ok(items);
    } on PostgrestException catch (e) {
      _logRlsIfNeeded(e, 'inner_strengths');
      return Result.fail(_toError(e));
    } catch (e) {
      return Result.fail(
          DataError(message: 'inner_strengths failed', cause: e));
    }
  }

  Future<Result<List<InnerCatalogDetail>>> _fetchValueDetails() async {
    try {
      final response = await _client
          .from('inner_values')
          .select(
              'id,key,title,description,examples,reflection_question,sort_rank,is_active')
          .eq('is_active', true)
          .order('sort_rank', ascending: true);
      final rows = (response as List).cast<Map<String, dynamic>>();
      _logTableRows('inner_values', rows);
      final items = rows
          .map((row) => InnerCatalogDetail(
                id: parseString(row['id']),
                key: parseString(row['key']),
                title: parseString(row['title']),
                description: parseString(row['description']),
                examples: parseList(row['examples']),
                useCases: const [],
                reflectionQuestion: parseString(row['reflection_question']),
                reflectionQuestions: const [],
                protectionFunction: '',
                shadowSide: '',
                reframe: '',
                helpsWith: const [],
                watchOutFor: const [],
                sortRank: parseInt(row['sort_rank']),
                isActive: parseBool(row['is_active']),
              ))
          .toList();
      return Result.ok(items);
    } on PostgrestException catch (e) {
      _logRlsIfNeeded(e, 'inner_values');
      return Result.fail(_toError(e));
    } catch (e) {
      return Result.fail(DataError(message: 'inner_values failed', cause: e));
    }
  }

  Future<Result<List<InnerCatalogDetail>>> _fetchDriverDetails() async {
    try {
      final response = await _client
          .from('inner_drivers')
          .select(
              'id,key,title,description,protection_function,shadow_side,reframe,examples,reflection_questions,sort_rank,is_active')
          .eq('is_active', true)
          .order('sort_rank', ascending: true);
      final rows = (response as List).cast<Map<String, dynamic>>();
      _logTableRows('inner_drivers', rows);
      final items = rows
          .map((row) => InnerCatalogDetail(
                id: parseString(row['id']),
                key: parseString(row['key']),
                title: parseString(row['title']),
                description: parseString(row['description']),
                examples: parseList(row['examples']),
                useCases: const [],
                reflectionQuestion: '',
                reflectionQuestions: parseList(row['reflection_questions']),
                protectionFunction: parseString(row['protection_function']),
                shadowSide: parseString(row['shadow_side']),
                reframe: parseString(row['reframe']),
                helpsWith: const [],
                watchOutFor: const [],
                sortRank: parseInt(row['sort_rank']),
                isActive: parseBool(row['is_active']),
              ))
          .toList();
      return Result.ok(items);
    } on PostgrestException catch (e) {
      _logRlsIfNeeded(e, 'inner_drivers');
      return Result.fail(_toError(e));
    } catch (e) {
      return Result.fail(DataError(message: 'inner_drivers failed', cause: e));
    }
  }

  Future<Result<List<InnerCatalogDetail>>> _fetchPersonalityDetails() async {
    try {
      final response = await _client
          .from('inner_personality_dimensions')
          .select(
              'id,key,title,description,helps_with,watch_out_for,reflection_question,sort_rank,is_active')
          .eq('is_active', true)
          .order('sort_rank', ascending: true);
      final rows = (response as List).cast<Map<String, dynamic>>();
      _logTableRows('inner_personality_dimensions', rows);
      final items = rows
          .map((row) => InnerCatalogDetail(
                id: parseString(row['id']),
                key: parseString(row['key']),
                title: parseString(row['title']),
                description: parseString(row['description']),
                examples: const [],
                useCases: const [],
                reflectionQuestion: parseString(row['reflection_question']),
                reflectionQuestions: const [],
                protectionFunction: '',
                shadowSide: '',
                reframe: '',
                helpsWith: parseList(row['helps_with']),
                watchOutFor: parseList(row['watch_out_for']),
                sortRank: parseInt(row['sort_rank']),
                isActive: parseBool(row['is_active']),
              ))
          .toList();
      return Result.ok(items);
    } on PostgrestException catch (e) {
      _logRlsIfNeeded(e, 'inner_personality_dimensions');
      return Result.fail(_toError(e));
    } catch (e) {
      return Result.fail(DataError(
          message: 'inner_personality_dimensions failed', cause: e));
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

InnerType _parseInnerType(dynamic value) {
  final s = value?.toString().toLowerCase() ?? '';
  if (s.contains('staer') || s.contains('stärk') || s.contains('strength')) {
    return InnerType.staerken;
  }
  if (s.contains('pers') || s.contains('personality')) {
    return InnerType.persoenlichkeit;
  }
  if (s.contains('werte') || s.contains('values')) {
    return InnerType.werte;
  }
  if (s.contains('antreib') || s.contains('driver')) {
    return InnerType.antreiber;
  }
  return InnerType.staerken;
}
