import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/catalog_item.dart';
import '../data/models/inner_catalog_detail.dart';
import '../data/repositories/inner_repository.dart';
import '../data/repositories/user_selections_repository.dart';
import '../data/supabase/supabase_client_provider.dart';

final innerCatalogRepositoryProvider = Provider<InnerRepository>(
    (ref) => InnerRepository(client: ref.read(supabaseClientProvider)));

final innerSelectionsRepositoryProvider = Provider<UserSelectionsRepository>(
    (ref) => UserSelectionsRepository(client: ref.read(supabaseClientProvider)));

final innerStrengthsDetailProvider =
    FutureProvider<List<InnerCatalogDetail>>((ref) async {
  final result =
      await ref.read(innerCatalogRepositoryProvider).fetchStrengthDetails();
  return _unwrap(result);
});

final innerValuesDetailProvider =
    FutureProvider<List<InnerCatalogDetail>>((ref) async {
  final result =
      await ref.read(innerCatalogRepositoryProvider).fetchValueDetails();
  return _unwrap(result);
});

final innerDriversDetailProvider =
    FutureProvider<List<InnerCatalogDetail>>((ref) async {
  final result =
      await ref.read(innerCatalogRepositoryProvider).fetchDriverDetails();
  return _unwrap(result);
});

final innerPersonalityDetailProvider =
    FutureProvider<List<InnerCatalogDetail>>((ref) async {
  final result = await ref
      .read(innerCatalogRepositoryProvider)
      .fetchPersonalityDetails();
  return _unwrap(result);
});

final userSelectedStrengthsProvider =
    FutureProvider<List<CatalogItem>>((ref) async {
  final result = await ref
      .read(innerSelectionsRepositoryProvider)
      .fetchUserSelectedStrengths();
  return _unwrapOrEmpty(result);
});

final userSelectedValuesProvider =
    FutureProvider<List<CatalogItem>>((ref) async {
  final result = await ref
      .read(innerSelectionsRepositoryProvider)
      .fetchUserSelectedValues();
  return _unwrapOrEmpty(result);
});

final userSelectedDriversProvider =
    FutureProvider<List<CatalogItem>>((ref) async {
  final result = await ref
      .read(innerSelectionsRepositoryProvider)
      .fetchUserSelectedDrivers();
  return _unwrapOrEmpty(result);
});

final userSelectedPersonalityProvider =
    FutureProvider<List<CatalogItem>>((ref) async {
  final result = await ref
      .read(innerSelectionsRepositoryProvider)
      .fetchUserSelectedPersonality();
  return _unwrapOrEmpty(result);
});

T _unwrap<T>(dynamic result) {
  if (result.isSuccess) return result.data as T;
  throw result.error!;
}

List<T> _unwrapOrEmpty<T>(dynamic result) {
  if (result.isSuccess) return (result.data as List<T>);
  if (result.error?.message == 'Not logged in') return const [];
  throw result.error!;
}








