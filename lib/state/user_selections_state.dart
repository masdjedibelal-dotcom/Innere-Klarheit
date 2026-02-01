import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/catalog_item.dart';
import '../data/models/user_identity_role.dart';
import '../data/models/user_identity_sentence.dart';
import '../data/repositories/user_identity_repository.dart';
import '../data/repositories/user_selections_repository.dart';
import '../data/supabase/supabase_client_provider.dart';

final userSelectionsRepoProvider = Provider<UserSelectionsRepository>(
    (ref) => UserSelectionsRepository(client: ref.read(supabaseClientProvider)));

final userIdentityRepoProvider = Provider<UserIdentityRepository>(
    (ref) => UserIdentityRepository(client: ref.read(supabaseClientProvider)));

final userSelectedValuesProvider = FutureProvider<List<CatalogItem>>((ref) {
  return ref
      .read(userSelectionsRepoProvider)
      .fetchUserSelectedValues()
      .then(_unwrapOrEmpty);
});

final userSelectedStrengthsProvider = FutureProvider<List<CatalogItem>>((ref) {
  return ref
      .read(userSelectionsRepoProvider)
      .fetchUserSelectedStrengths()
      .then(_unwrapOrEmpty);
});

final userSelectedDriversProvider = FutureProvider<List<CatalogItem>>((ref) {
  return ref
      .read(userSelectionsRepoProvider)
      .fetchUserSelectedDrivers()
      .then(_unwrapOrEmpty);
});

final userSelectedPersonalityProvider = FutureProvider<List<CatalogItem>>((ref) {
  return ref
      .read(userSelectionsRepoProvider)
      .fetchUserSelectedPersonality()
      .then(_unwrapOrEmpty);
});

final userIdentityRolesProvider = FutureProvider<List<UserIdentityRole>>((ref) {
  return ref
      .read(userIdentityRepoProvider)
      .fetchSelectedRoles()
      .then(_unwrapOrEmpty);
});

final userIdentitySentencesProvider =
    FutureProvider<List<UserIdentitySentence>>((ref) {
  return ref
      .read(userIdentityRepoProvider)
      .fetchSentences()
      .then(_unwrapOrEmpty);
});

List<T> _unwrapOrEmpty<T>(dynamic result) {
  if (result.isSuccess) return (result.data as List<T>);
  if (result.error?.message == 'Not logged in') return const [];
  throw result.error!;
}

