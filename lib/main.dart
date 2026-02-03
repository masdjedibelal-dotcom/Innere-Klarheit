import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'services/auth_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await _loadEnv();
  debugPrint(
      'Supabase project url: ${dotenv.get('SUPABASE_URL', fallback: 'MISSING')}');
  debugPrint(
      'SUPABASE_ANON_KEY length: ${dotenv.get('SUPABASE_ANON_KEY', fallback: '').length}');
  await Supabase.initialize(
    url: dotenv.get('SUPABASE_URL'),
    anonKey: dotenv.get('SUPABASE_ANON_KEY'),
  );
  await AuthBootstrap(client: Supabase.instance.client)
      .ensureAnonymousSession();
  try {
    await _smokeTest();
  } catch (e) {
    debugPrint('SMOKE TEST ERROR (caught in main): $e');
  }

  runApp(const ProviderScope(child: ClarityApp()));
}

Future<void> _loadEnv() async {
  try {
    await dotenv.load(fileName: 'assets/env');
    debugPrint('dotenv: loaded assets/env');
  } catch (_) {
    await dotenv.load(fileName: 'assets/env.example');
    debugPrint('dotenv: loaded assets/env.example');
  }
}

Future<void> _smokeTest() async {
  try {
    final dynamic response = await Supabase.instance.client
        .from('knowledge_snacks')
        .select('id,title,is_published')
        .limit(3);
    debugPrint('SMOKE TEST knowledge_snacks: $response');
    if (response == null || response is! List) {
      debugPrint('SMOKE TEST WARN: response is not a List (check init/env).');
      return;
    }
    if (response.isEmpty) {
      debugPrint(
          'SMOKE TEST WARN: knowledge_snacks returned empty list (check data or RLS).');
    }
  } on PostgrestException catch (e) {
    debugPrint('SMOKE TEST ERROR: ${e.message}');
  } catch (e) {
    debugPrint('SMOKE TEST ERROR: $e');
  }
}
