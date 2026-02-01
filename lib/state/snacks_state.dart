import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/knowledge_snack.dart';
import '../data/repositories/knowledge_repository.dart';
import '../data/repositories/user_snacks_repository.dart';
import '../data/supabase/supabase_client_provider.dart';

final snacksRepoProvider = Provider<KnowledgeRepository>((ref) =>
    KnowledgeRepository(client: ref.read(supabaseClientProvider)));

final userSnacksRepoProvider = Provider<UserSnacksRepository>((ref) =>
    UserSnacksRepository(client: ref.read(supabaseClientProvider)));

final snacksProvider = FutureProvider<List<KnowledgeSnack>>((ref) async {
  final result = await ref.read(snacksRepoProvider).fetchSnacks();
  if (result.isSuccess) return result.data!;
  throw result.error!;
});

final savedSnackIdsProvider = FutureProvider<Set<String>>((ref) async {
  final result = await ref.read(userSnacksRepoProvider).fetchSavedSnackIds();
  if (result.isSuccess) return result.data!;
  if (result.error?.message == 'Not logged in') return <String>{};
  throw result.error!;
});

