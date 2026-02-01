import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/mission_template.dart';
import '../models/user_mission_statement.dart';
import '../result.dart';
import '../supabase/auth_helpers.dart';
import '../supabase/supabase_parsers.dart';

class MissionRepository {
  final SupabaseClient _client;

  MissionRepository({required SupabaseClient client}) : _client = client;

  Future<Result<List<MissionTemplate>>> fetchTemplates() async {
    try {
      final rows = await _selectTemplates();
      _logTableRows('mission_statement_templates', rows);
      return Result.ok(rows.map(_mapTemplate).toList());
    } on PostgrestException catch (e) {
      _logRlsIfNeeded(e, 'mission_statement_templates');
      return Result.fail(_toError(e));
    } catch (e) {
      return Result.fail(
          DataError(message: 'mission_statement_templates failed', cause: e));
    }
  }

  Future<Result<UserMissionStatement?>> getUserMission(
      {required String? userId}) async {
    final uid = _resolveUserId(userId);
    if (uid == null) {
      return Result.fail(DataError(message: 'Not logged in'));
    }

    try {
      final response = await _client
          .from('user_mission_statement')
          .select()
          .eq('user_id', uid)
          .maybeSingle();

      if (response == null) return Result.ok(null);
      _logSingleRow('user_mission_statement', response);
      return Result.ok(_mapUserStatement(response));
    } on PostgrestException catch (e) {
      _logRlsIfNeeded(e, 'user_mission_statement');
      return Result.fail(_toError(e));
    } catch (e) {
      return Result.fail(
          DataError(message: 'user_mission_statement failed', cause: e));
    }
  }

  Future<Result<UserMissionStatement>> upsertUserMission({
    required String? userId,
    required String statement,
    String? sourceTemplateId,
  }) async {
    final uid = _resolveUserId(userId);
    if (uid == null) {
      return Result.fail(DataError(message: 'Not logged in'));
    }

    final payload = <String, dynamic>{
      'user_id': uid,
      'statement': statement,
      'source_template_id': sourceTemplateId,
    };

    try {
      final response = await _client
          .from('user_mission_statement')
          .upsert(payload)
          .select()
          .single();

      _logSingleRow('user_mission_statement upsert', response);
      return Result.ok(_mapUserStatement(response));
    } on PostgrestException catch (e) {
      _logRlsIfNeeded(e, 'user_mission_statement');
      return Result.fail(_toError(e));
    } catch (e) {
      return Result.fail(DataError(
          message: 'user_mission_statement upsert failed', cause: e));
    }
  }

  String? _resolveUserId(String? userId) {
    if (userId != null && userId.isNotEmpty) return userId;
    return requireUser(_client);
  }

  MissionTemplate _mapTemplate(Map<String, dynamic> row) {
    return MissionTemplate(
      id: parseString(row['id']),
      key: parseString(row['key']),
      template: parseString(row['template']),
      tone: parseString(row['tone']),
      sortRank: parseInt(row['sort_rank']),
      isActive: row['is_active'] == true,
      createdAt: parseDateTime(row['created_at']),
    );
  }

  UserMissionStatement _mapUserStatement(Map<String, dynamic> row) {
    return UserMissionStatement(
      id: parseString(row['id']),
      userId: parseString(row['user_id']),
      statement: parseString(row['statement']),
      sourceTemplateId:
          row['source_template_id'] == null ? null : row['source_template_id'].toString(),
      createdAt: parseDateTime(row['created_at']),
      updatedAt: parseDateTime(row['updated_at']),
    );
  }

  void _logRlsIfNeeded(PostgrestException e, String table) {
    final msg = e.message.toLowerCase();
    if (msg.contains('permission') || msg.contains('rls')) {
      // ignore: avoid_print
      print(
          'RLS WARN: SELECT blocked. Please verify RLS SELECT policy for $table.');
    }
  }

  Future<List<Map<String, dynamic>>> _selectTemplates() async {
    try {
      final response = await _client
          .from('mission_statement_templates')
          .select()
          .eq('is_active', true)
          .order('sort_rank', ascending: true);
      return (response as List).cast<Map<String, dynamic>>();
    } on PostgrestException catch (e) {
      if (_isMissingColumn(e)) {
        final response = await _client
            .from('mission_statement_templates')
            .select()
            .order('sort_rank', ascending: true);
        return (response as List).cast<Map<String, dynamic>>();
      }
      rethrow;
    }
  }

  bool _isMissingColumn(PostgrestException e) {
    final msg = e.message.toLowerCase();
    return msg.contains('does not exist') && msg.contains('column');
  }
}

void _logTableRows(String table, List<Map<String, dynamic>> rows) {
  final keys = rows.isNotEmpty ? rows.first.keys.toList() : const [];
  // ignore: avoid_print
  print('Loaded ${rows.length} $table, keys: $keys');
}

void _logSingleRow(String table, Map<String, dynamic> row) {
  // ignore: avoid_print
  print('Loaded 1 $table, keys: ${row.keys.toList()}');
}

DataError _toError(PostgrestException e) {
  return DataError(
    message: e.message,
    details: e.details?.toString(),
    hint: e.hint?.toString(),
    code: e.code,
  );
}

