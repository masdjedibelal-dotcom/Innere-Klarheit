import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/catalog_item.dart';

enum GuestSelectionKind { strength, value, driver, personality }

class GuestSelectionsState {
  final List<CatalogItem> strengths;
  final List<CatalogItem> values;
  final List<CatalogItem> drivers;
  final List<CatalogItem> personality;

  const GuestSelectionsState({
    this.strengths = const [],
    this.values = const [],
    this.drivers = const [],
    this.personality = const [],
  });

  GuestSelectionsState copyWith({
    List<CatalogItem>? strengths,
    List<CatalogItem>? values,
    List<CatalogItem>? drivers,
    List<CatalogItem>? personality,
  }) {
    return GuestSelectionsState(
      strengths: strengths ?? this.strengths,
      values: values ?? this.values,
      drivers: drivers ?? this.drivers,
      personality: personality ?? this.personality,
    );
  }
}

class GuestSelectionsNotifier extends StateNotifier<GuestSelectionsState> {
  GuestSelectionsNotifier() : super(const GuestSelectionsState());

  void toggle(GuestSelectionKind kind, CatalogItem item) {
    final next = List<CatalogItem>.from(_listFor(kind));
    final index = next.indexWhere((e) => e.id == item.id);
    if (index >= 0) {
      next.removeAt(index);
    } else {
      next.add(item);
    }
    next.sort((a, b) => a.sortRank.compareTo(b.sortRank));
    state = _update(kind, next);
  }

  List<CatalogItem> _listFor(GuestSelectionKind kind) {
    switch (kind) {
      case GuestSelectionKind.strength:
        return state.strengths;
      case GuestSelectionKind.value:
        return state.values;
      case GuestSelectionKind.driver:
        return state.drivers;
      case GuestSelectionKind.personality:
        return state.personality;
    }
  }

  GuestSelectionsState _update(
    GuestSelectionKind kind,
    List<CatalogItem> list,
  ) {
    switch (kind) {
      case GuestSelectionKind.strength:
        return state.copyWith(strengths: list);
      case GuestSelectionKind.value:
        return state.copyWith(values: list);
      case GuestSelectionKind.driver:
        return state.copyWith(drivers: list);
      case GuestSelectionKind.personality:
        return state.copyWith(personality: list);
    }
  }
}

final guestSelectionsProvider =
    StateNotifierProvider<GuestSelectionsNotifier, GuestSelectionsState>(
  (ref) => GuestSelectionsNotifier(),
);









