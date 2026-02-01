import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/identity_pillar.dart';
import '../models/identity_role.dart';
import '../result.dart';
import '../supabase/supabase_parsers.dart';

class IdentityRepository {
  final SupabaseClient _client;

  IdentityRepository({required SupabaseClient client}) : _client = client;

  static const List<String> _identityRoleIds = [
    'd8d2cb9a-917e-4f7f-b08b-c1a8a257aa42',
    'cd7cc8cf-4bda-4274-bda3-60ba2c0c5b21',
    '8e816919-5b8a-4923-8069-8d52cc929e4a',
    '2132b6fb-85aa-4e4d-bfef-f1746470ad00',
    '18852623-40eb-47bc-8690-4400facfa4b5',
    '1ddcbe12-0610-44da-9e79-32f76ad8c703',
    '93fecfbb-4ff2-4c60-895b-9dc770cf7f1d',
    '60e5ae8e-580e-4203-905d-9686069e457b',
    'ddd7218b-1c01-4ea1-994a-968d4e92569d',
  ];

  static const List<String> _identityPillarIds = [
    '1645de87-71be-5379-bbaa-a5c321e1b3ac',
    '3cbea0fe-477c-5403-beed-889e6ca7e701',
    '64fc66ff-1a07-5057-a579-0e5c2d356c96',
    'a692e6b5-2f28-519f-bebe-795fd8ab2d43',
    'ecaeb3c3-0293-5672-8648-459da3db4e86',
  ];

  Future<Result<List<IdentityRole>>> fetchRoles() async {
    try {
      final response = await _client
          .from('identity_roles')
          .select('id,domain,title,description,tags,sort_rank,is_active')
          .eq('is_active', true)
          .filter('id', 'in', _toInFilter(_identityRoleIds))
          .order('sort_rank', ascending: true);

      final rows = (response as List).cast<Map<String, dynamic>>();
      _logTableRows('identity_roles', rows);
      final items = rows.map(_mapRow).toList();
      return Result.ok(items);
    } on PostgrestException catch (e) {
      _logRlsIfNeeded(e, 'identity_roles');
      return Result.fail(_toError(e));
    } catch (e) {
      return Result.fail(DataError(message: 'identity_roles failed', cause: e));
    }
  }

  Future<Result<List<IdentityPillar>>> fetchPillars() async {
    try {
      final response = await _client
          .from('identity_pillars')
          .select(
              'id,title,description,reflection_questions,sort_rank,is_active')
          .eq('is_active', true)
          .filter('id', 'in', _toInFilter(_identityPillarIds))
          .order('sort_rank', ascending: true);
      final rows = (response as List).cast<Map<String, dynamic>>();
      _logTableRows('identity_pillars', rows);
      final items = rows
          .map(
            (row) => IdentityPillar(
              id: parseString(row['id']),
              title: parseString(row['title']),
              desc: parseString(row['description'],
                  fallback: parseString(row['desc'])),
              reflectionQuestions: parseList(row['reflection_questions']),
              sortRank: parseInt(row['sort_rank']),
              isActive: parseBool(row['is_active']),
            ),
          )
          .toList();
      return Result.ok(items);
    } on PostgrestException catch (e) {
      _logRlsIfNeeded(e, 'identity_pillars');
      return Result.fail(_toError(e));
    } catch (e) {
      return Result.fail(DataError(message: 'identity_pillars failed', cause: e));
    }
  }

  IdentityRole _mapRow(Map<String, dynamic> row) {
    return IdentityRole(
      id: parseString(row['id']),
      domain: parseString(row['domain']),
      title: parseString(row['title']),
      desc:
          parseString(row['description'], fallback: parseString(row['desc'])),
      tags: parseList(row['tags']),
      sortRank: parseInt(row['sort_rank']),
      isActive: parseBool(row['is_active']),
    );
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

String _toInFilter(List<String> ids) {
  final quoted = ids.map((id) => '"$id"').join(',');
  return '($quoted)';
}
