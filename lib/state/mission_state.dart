import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/catalog_item.dart';
import '../data/models/mission_template.dart';
import '../data/models/user_mission_statement.dart';
import '../data/repositories/identity_repository.dart';
import '../data/repositories/inner_repository.dart';
import '../data/repositories/mission_repository.dart';
import '../data/repositories/user_selections_repository.dart';
import '../data/supabase/supabase_client_provider.dart';

final missionRepositoryProvider = Provider<MissionRepository>((ref) =>
    MissionRepository(client: ref.read(supabaseClientProvider)));

final innerCatalogRepositoryProvider = Provider<InnerRepository>(
    (ref) => InnerRepository(client: ref.read(supabaseClientProvider)));

final identityCatalogRepositoryProvider = Provider<IdentityRepository>(
    (ref) => IdentityRepository(client: ref.read(supabaseClientProvider)));

final userSelectionsRepositoryProvider = Provider<UserSelectionsRepository>(
    (ref) => UserSelectionsRepository(client: ref.read(supabaseClientProvider)));

final missionTemplatesProvider = FutureProvider<List<MissionTemplate>>((ref) {
  return ref
      .read(missionRepositoryProvider)
      .fetchTemplates()
      .then(_unwrap);
});

final userMissionStatementProvider =
    FutureProvider<UserMissionStatement?>((ref) {
  return ref
      .read(missionRepositoryProvider)
      .getUserMission(userId: null)
      .then(_unwrapOrNull);
});

final userStrengthsProvider = FutureProvider<List<CatalogItem>>((ref) {
  return ref
      .read(userSelectionsRepositoryProvider)
      .fetchUserSelectedStrengths()
      .then(_unwrapOrEmpty);
});

final userValuesProvider = FutureProvider<List<CatalogItem>>((ref) {
  return ref
      .read(userSelectionsRepositoryProvider)
      .fetchUserSelectedValues()
      .then(_unwrapOrEmpty);
});

final innerStrengthsCatalogProvider =
    FutureProvider<List<CatalogItem>>((ref) {
  return ref
      .read(innerCatalogRepositoryProvider)
      .fetchStrengths()
      .then(_unwrap);
});

final innerValuesCatalogProvider =
    FutureProvider<List<CatalogItem>>((ref) {
  return ref.read(innerCatalogRepositoryProvider).fetchValues().then(_unwrap);
});

final innerDriversCatalogProvider =
    FutureProvider<List<CatalogItem>>((ref) {
  return ref.read(innerCatalogRepositoryProvider).fetchDrivers().then(_unwrap);
});

final innerPersonalityCatalogProvider =
    FutureProvider<List<CatalogItem>>((ref) {
  return ref
      .read(innerCatalogRepositoryProvider)
      .fetchPersonalityDims()
      .then(_unwrap);
});

final identityPillarsCatalogProvider =
    FutureProvider<List<CatalogItem>>((ref) {
  return ref
      .read(identityCatalogRepositoryProvider)
      .fetchPillars()
      .then(_unwrapPillarsToCatalog);
});

T _unwrap<T>(dynamic result) {
  if (result.isSuccess) return result.data as T;
  throw result.error!;
}

T? _unwrapOrNull<T>(dynamic result) {
  if (result.isSuccess) return result.data as T?;
  if (result.error?.message == 'Not logged in') return null;
  throw result.error!;
}

List<T> _unwrapOrEmpty<T>(dynamic result) {
  if (result.isSuccess) return (result.data as List<T>);
  if (result.error?.message == 'Not logged in') return const [];
  throw result.error!;
}

List<CatalogItem> _unwrapPillarsToCatalog(dynamic result) {
  if (result.isSuccess) {
    return (result.data as List)
        .map((p) => CatalogItem(id: p.id, title: p.title, sortRank: p.sortRank))
        .toList();
  }
  throw result.error!;
}
