import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_profile.dart';
import '../supabase/auth_helpers.dart';

class UserProfileRepository {
  UserProfileRepository({required SupabaseClient client}) : _client = client;

  final SupabaseClient _client;
  static const _nameColumns = ['display_name', 'name', 'full_name'];

  Future<UserProfile> getOrCreate() async {
    final uid = requireUser(_client) ?? (throw Exception('No auth user'));
    for (final nameColumn in _nameColumns) {
      try {
        return await _getOrCreate(uid, nameColumn: nameColumn);
      } on PostgrestException catch (e) {
        if (_isMissingColumn(e)) {
          continue;
        }
        rethrow;
      }
    }
    return _getOrCreate(uid);
  }

  Future<void> updateDisplayName(String name) async {
    final uid = requireUser(_client) ?? (throw Exception('No auth user'));
    for (final column in _nameColumns) {
      try {
        await _client
            .from('user_profile')
            .update({column: name})
            .eq('user_id', uid);
        return;
      } on PostgrestException catch (e) {
        if (_isMissingColumn(e)) {
          continue;
        }
        rethrow;
      }
    }
  }

  Future<void> touchLastActive() async {
    final uid = requireUser(_client) ?? (throw Exception('No auth user'));
    try {
      await _client
          .from('user_profile')
          .update({'last_active_at': DateTime.now().toIso8601String()})
          .eq('user_id', uid);
    } on PostgrestException catch (e) {
      if (_isMissingColumn(e)) {
        return;
      }
      rethrow;
    }
  }

  Future<UserProfile> _getOrCreate(
    String uid, {
    String? nameColumn,
  }) async {
    try {
      return await _getOrCreateWithColumns(
        uid,
        nameColumn: nameColumn,
        includeLastActive: true,
      );
    } on PostgrestException catch (e) {
      if (_isMissingColumn(e)) {
        return _getOrCreateWithColumns(
          uid,
          nameColumn: nameColumn,
          includeLastActive: false,
        );
      }
      rethrow;
    }
  }

  Future<UserProfile> _getOrCreateWithColumns(
    String uid, {
    required String? nameColumn,
    required bool includeLastActive,
  }) async {
    final selectColumns = [
      'user_id',
      if (nameColumn != null) nameColumn,
      'created_at',
      if (includeLastActive) 'last_active_at',
    ].join(',');
    final response = await _client
        .from('user_profile')
        .select(selectColumns)
        .eq('user_id', uid)
        .maybeSingle();
    if (response == null) {
      final now = DateTime.now().toIso8601String();
      final insert = {
        'user_id': uid,
        'created_at': now,
        if (includeLastActive) 'last_active_at': now,
      };
      final inserted = await _client
          .from('user_profile')
          .insert(insert)
          .select(selectColumns)
          .single();
      return _mapRow(inserted, nameColumn: nameColumn);
    }
    return _mapRow(response, nameColumn: nameColumn);
  }

  UserProfile _mapRow(Map<String, dynamic> row, {String? nameColumn}) {
    final createdAt = DateTime.parse(row['created_at'].toString());
    return UserProfile(
      id: row['user_id']?.toString() ?? '',
      displayName: nameColumn == null ? '' : row[nameColumn]?.toString() ?? '',
      createdAt: createdAt,
      lastActiveAt: row['last_active_at'] == null
          ? createdAt
          : DateTime.parse(row['last_active_at'].toString()),
    );
  }

  bool _isMissingColumn(PostgrestException e) {
    final msg = e.message.toLowerCase();
    return e.code == 'PGRST204' ||
        (msg.contains('does not exist') && msg.contains('column')) ||
        msg.contains('schema cache');
  }
}

