import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

bool _loggedOutNoted = false;

String? requireUser(SupabaseClient client, {bool logOnce = true}) {
  final uid = client.auth.currentUser?.id;
  if (uid != null) return uid;
  if (logOnce && !_loggedOutNoted) {
    _loggedOutNoted = true;
    debugPrint('Auth: no user session (queries skipped).');
  }
  return null;
}

