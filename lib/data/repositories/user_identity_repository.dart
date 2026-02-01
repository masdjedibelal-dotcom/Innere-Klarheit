import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_identity_role.dart';
import '../models/user_identity_sentence.dart';
import '../result.dart';
import '../supabase/auth_helpers.dart';
import '../supabase/supabase_parsers.dart';

class UserIdentityRepository {
  final SupabaseClient _client;

  UserIdentityRepository({required SupabaseClient client}) : _client = client;

  Future<Result<List<UserIdentityRole>>> fetchSelectedRoles() async {
    final uid = requireUser(_client);
    if (uid == null) {
      return Result.fail(const DataError(message: 'Not logged in'));
    }

    try {
      final response = await _client
          .from('user_identity_selections')
          .select('identity_roles(id,domain,title)')
          .eq('user_id', uid);
      final rows = (response as List).cast<Map<String, dynamic>>();
      _logTableRows('user_identity_selections', rows);
      final items = rows
          .map((row) => row['identity_roles'] as Map<String, dynamic>?)
          .whereType<Map<String, dynamic>>()
          .map((row) => UserIdentityRole(
                id: parseString(row['id']),
                domain: parseString(row['domain']),
                title: parseString(row['title']),
              ))
          .toList();
      return Result.ok(items);
    } on PostgrestException catch (e) {
      _logRlsIfNeeded(e, 'user_identity_selections');
      return Result.fail(_toError(e));
    } catch (e) {
      return Result.fail(
          DataError(message: 'user_identity_selections failed', cause: e));
    }
  }

  Future<Result<List<UserIdentitySentence>>> fetchSentences() async {
    final uid = requireUser(_client);
    if (uid == null) {
      return Result.fail(const DataError(message: 'Not logged in'));
    }

    try {
      final response = await _client
          .from('user_identity_sentences')
          .select('id,sentence')
          .eq('user_id', uid);
      final rows = (response as List).cast<Map<String, dynamic>>();
      _logTableRows('user_identity_sentences', rows);
      final items = rows
          .map((row) => UserIdentitySentence(
                id: parseString(row['id']),
                sentence: parseString(row['sentence']),
              ))
          .toList();
      return Result.ok(items);
    } on PostgrestException catch (e) {
      _logRlsIfNeeded(e, 'user_identity_sentences');
      return Result.fail(_toError(e));
    } catch (e) {
      return Result.fail(
          DataError(message: 'user_identity_sentences failed', cause: e));
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

