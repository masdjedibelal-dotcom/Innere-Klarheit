import 'package:supabase_flutter/supabase_flutter.dart';

import '../result.dart';
import '../supabase/auth_helpers.dart';

class UserSnacksRepository {
  final SupabaseClient _client;

  UserSnacksRepository({required SupabaseClient client}) : _client = client;

  Future<Result<Set<String>>> fetchSavedSnackIds() async {
    final uid = requireUser(_client);
    if (uid == null) {
      return Result.fail(const DataError(message: 'Not logged in'));
    }

    try {
      final response = await _client
          .from('user_saved_snacks')
          .select('snack_id')
          .eq('user_id', uid);
      final rows = (response as List).cast<Map<String, dynamic>>();
      final ids = rows
          .map((row) => row['snack_id']?.toString())
          .whereType<String>()
          .toSet();
      return Result.ok(ids);
    } on PostgrestException catch (e) {
      return Result.fail(_toError(e));
    } catch (e) {
      return Result.fail(
        DataError(message: 'user_saved_snacks failed', cause: e),
      );
    }
  }

  Future<Result<void>> saveSnack(String snackId) async {
    final uid = requireUser(_client);
    if (uid == null) {
      return Result.fail(const DataError(message: 'Not logged in'));
    }

    try {
      await _client.from('user_saved_snacks').upsert({
        'user_id': uid,
        'snack_id': snackId,
      });
      return Result.ok(null);
    } on PostgrestException catch (e) {
      return Result.fail(_toError(e));
    } catch (e) {
      return Result.fail(
        DataError(message: 'user_saved_snacks save failed', cause: e),
      );
    }
  }

  Future<Result<void>> unsaveSnack(String snackId) async {
    final uid = requireUser(_client);
    if (uid == null) {
      return Result.fail(const DataError(message: 'Not logged in'));
    }

    try {
      await _client
          .from('user_saved_snacks')
          .delete()
          .eq('user_id', uid)
          .eq('snack_id', snackId);
      return Result.ok(null);
    } on PostgrestException catch (e) {
      return Result.fail(_toError(e));
    } catch (e) {
      return Result.fail(
        DataError(message: 'user_saved_snacks delete failed', cause: e),
      );
    }
  }
}

DataError _toError(PostgrestException e) {
  return DataError(
    message: e.message,
    details: e.details?.toString(),
    hint: e.hint?.toString(),
    code: e.code,
  );
}

