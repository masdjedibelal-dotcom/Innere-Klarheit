import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/repositories/user_profile_repository.dart';

class AuthBootstrap {
  AuthBootstrap({required SupabaseClient client}) : _client = client;

  final SupabaseClient _client;

  Future<void> ensureAnonymousSession() async {
    final session = _client.auth.currentSession;
    if (session == null) {
      return;
    }
    final profileRepo = UserProfileRepository(client: _client);
    await profileRepo.touchLastActive();
  }
}




