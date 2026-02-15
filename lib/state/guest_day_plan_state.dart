import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/dayflow/planner/planning_item.dart';
import 'user_state.dart';

class GuestDayPlanEntry {
  final List<PlanningItem> items;
  final Set<String> completedItemIds;

  const GuestDayPlanEntry({
    this.items = const [],
    this.completedItemIds = const {},
  });

  GuestDayPlanEntry copyWith({
    List<PlanningItem>? items,
    Set<String>? completedItemIds,
  }) {
    return GuestDayPlanEntry(
      items: items ?? this.items,
      completedItemIds: completedItemIds ?? this.completedItemIds,
    );
  }
}

class GuestDayPlanState {
  final Map<String, GuestDayPlanEntry> byDate;

  const GuestDayPlanState({this.byDate = const {}});

  GuestDayPlanEntry entryFor(DateTime date) {
    return byDate[dateKey(date)] ?? const GuestDayPlanEntry();
  }
}

class GuestDayPlanNotifier extends StateNotifier<GuestDayPlanState> {
  GuestDayPlanNotifier() : super(const GuestDayPlanState());

  void upsertItem(DateTime date, PlanningItem item, {required bool completed}) {
    final key = dateKey(date);
    final current = state.byDate[key] ?? const GuestDayPlanEntry();
    final items = List<PlanningItem>.from(current.items);
    final index = items.indexWhere((i) => i.id == item.id);
    if (index == -1) {
      items.add(item);
    } else {
      items[index] = item;
    }
    final completedIds = Set<String>.from(current.completedItemIds);
    if (completed) {
      completedIds.add(item.id);
    } else {
      completedIds.remove(item.id);
    }
    _setEntry(
      key,
      current.copyWith(items: items, completedItemIds: completedIds),
    );
  }

  void removeItem(DateTime date, String itemId) {
    final key = dateKey(date);
    final current = state.byDate[key];
    if (current == null) return;
    final items =
        List<PlanningItem>.from(current.items)..removeWhere((i) => i.id == itemId);
    final completedIds = Set<String>.from(current.completedItemIds)
      ..remove(itemId);
    _setEntry(
      key,
      current.copyWith(items: items, completedItemIds: completedIds),
    );
  }

  void setCompleted(DateTime date, String itemId, bool completed) {
    final key = dateKey(date);
    final current = state.byDate[key];
    if (current == null) return;
    final completedIds = Set<String>.from(current.completedItemIds);
    if (completed) {
      completedIds.add(itemId);
    } else {
      completedIds.remove(itemId);
    }
    _setEntry(key, current.copyWith(completedItemIds: completedIds));
  }

  void _setEntry(String key, GuestDayPlanEntry entry) {
    final next = Map<String, GuestDayPlanEntry>.from(state.byDate);
    next[key] = entry;
    state = GuestDayPlanState(byDate: next);
  }
}

final guestDayPlanProvider =
    StateNotifierProvider<GuestDayPlanNotifier, GuestDayPlanState>(
  (ref) => GuestDayPlanNotifier(),
);









