import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/inner_item.dart';
import '../data/models/knowledge_snack.dart';
import '../data/models/identity_pillar.dart';
import '../data/models/identity_role.dart';
import '../data/models/method_v2.dart';
import '../data/models/system_block.dart';
import '../data/repositories/knowledge_repository.dart';
import '../data/repositories/inner_repository.dart';
import '../data/repositories/identity_repository.dart';
import '../data/repositories/system_repository.dart';
import '../data/repositories/user_profile_repository.dart';
import '../data/repositories/daily_usage_repository.dart';
import '../data/supabase/supabase_client_provider.dart';

class DayPlanBlock {
  final String blockId;
  final String? outcome;
  final List<String> methodIds;
  final List<String> doneMethodIds;
  final bool done;

  const DayPlanBlock({
    required this.blockId,
    required this.outcome,
    required this.methodIds,
    required this.doneMethodIds,
    required this.done,
  });

  DayPlanBlock copyWith({
    String? outcome,
    List<String>? methodIds,
    List<String>? doneMethodIds,
    bool? done,
  }) {
    return DayPlanBlock(
      blockId: blockId,
      outcome: outcome ?? this.outcome,
      methodIds: methodIds ?? this.methodIds,
      doneMethodIds: doneMethodIds ?? this.doneMethodIds,
      done: done ?? this.done,
    );
  }
}

class UserState {
  final Set<String> savedKnowledgeSnackIds;
  final Set<String> savedInnerItemIds;
  final Set<String> workingInnerItemIds;
  final Map<String, Set<String>> identitySelections;
  final List<String> favoriteIdentitySentences;
  final Map<String, DayPlanBlock> todayPlan;
  final Map<String, double> pillarScores;
  final Set<String> loginDates;
  final Map<String, String> dayCloseoutAnswers;
  final String dayCloseoutNote;
  final bool isLoggedIn;
  final String profileName;
  final DateTime? lastActiveAt;
  final bool remindersEnabled;
  final String reminderTime;

  const UserState({
    required this.savedKnowledgeSnackIds,
    required this.savedInnerItemIds,
    required this.workingInnerItemIds,
    required this.identitySelections,
    required this.favoriteIdentitySentences,
    required this.todayPlan,
    required this.pillarScores,
    required this.loginDates,
    required this.dayCloseoutAnswers,
    required this.dayCloseoutNote,
    required this.isLoggedIn,
    required this.profileName,
    required this.lastActiveAt,
    required this.remindersEnabled,
    required this.reminderTime,
  });

  UserState copyWith({
    Set<String>? savedKnowledgeSnackIds,
    Set<String>? savedInnerItemIds,
    Set<String>? workingInnerItemIds,
    Map<String, Set<String>>? identitySelections,
    List<String>? favoriteIdentitySentences,
    Map<String, DayPlanBlock>? todayPlan,
    Map<String, double>? pillarScores,
    Set<String>? loginDates,
    Map<String, String>? dayCloseoutAnswers,
    String? dayCloseoutNote,
    bool? isLoggedIn,
    String? profileName,
    DateTime? lastActiveAt,
    bool? remindersEnabled,
    String? reminderTime,
  }) {
    return UserState(
      savedKnowledgeSnackIds:
          savedKnowledgeSnackIds ?? this.savedKnowledgeSnackIds,
      savedInnerItemIds: savedInnerItemIds ?? this.savedInnerItemIds,
      workingInnerItemIds: workingInnerItemIds ?? this.workingInnerItemIds,
      identitySelections: identitySelections ?? this.identitySelections,
      favoriteIdentitySentences:
          favoriteIdentitySentences ?? this.favoriteIdentitySentences,
      todayPlan: todayPlan ?? this.todayPlan,
      pillarScores: pillarScores ?? this.pillarScores,
      loginDates: loginDates ?? this.loginDates,
      dayCloseoutAnswers: dayCloseoutAnswers ?? this.dayCloseoutAnswers,
      dayCloseoutNote: dayCloseoutNote ?? this.dayCloseoutNote,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      profileName: profileName ?? this.profileName,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      remindersEnabled: remindersEnabled ?? this.remindersEnabled,
      reminderTime: reminderTime ?? this.reminderTime,
    );
  }
}

class UserStateNotifier extends StateNotifier<UserState> {
  UserStateNotifier(this._ref)
      : super(const UserState(
          savedKnowledgeSnackIds: {},
          savedInnerItemIds: {},
          workingInnerItemIds: {},
          identitySelections: {},
          favoriteIdentitySentences: [],
          todayPlan: {},
          pillarScores: {},
          loginDates: {},
          dayCloseoutAnswers: {},
          dayCloseoutNote: '',
          isLoggedIn: true,
          profileName: '',
          lastActiveAt: null,
          remindersEnabled: false,
          reminderTime: '20:30',
        ));

  final Ref _ref;

  void toggleSnackSaved(String id) {
    final next = Set<String>.from(state.savedKnowledgeSnackIds);
    if (!next.add(id)) {
      next.remove(id);
    }
    state = state.copyWith(savedKnowledgeSnackIds: next);
  }

  void toggleInnerWorking(String id) {
    final next = Set<String>.from(state.workingInnerItemIds);
    if (!next.add(id)) {
      next.remove(id);
    }
    state = state.copyWith(workingInnerItemIds: next);
  }

  void commitInnerSelection() {
    state = state.copyWith(
      savedInnerItemIds: Set<String>.from(state.workingInnerItemIds),
    );
  }

  void toggleIdentityRole(String domain, String roleId, {int max = 3}) {
    final map = Map<String, Set<String>>.from(state.identitySelections);
    final set = Set<String>.from(map[domain] ?? {});
    if (set.contains(roleId)) {
      set.remove(roleId);
    } else {
      if (set.length >= max) return;
      set.add(roleId);
    }
    map[domain] = set;
    state = state.copyWith(identitySelections: map);
  }

  void toggleFavoriteSentence(String sentence) {
    final list = List<String>.from(state.favoriteIdentitySentences);
    if (list.contains(sentence)) {
      list.remove(sentence);
    } else {
      if (list.length >= 2) return;
      list.add(sentence);
    }
    state = state.copyWith(favoriteIdentitySentences: list);
  }

  void setDayPlanBlock(DayPlanBlock block) {
    final map = Map<String, DayPlanBlock>.from(state.todayPlan);
    map[block.blockId] = block;
    state = state.copyWith(todayPlan: map);
    _syncDailyUsage();
  }

  void setPillarScore(String pillarId, double score) {
    final next = Map<String, double>.from(state.pillarScores);
    next[pillarId] = score;
    state = state.copyWith(pillarScores: next);
  }

  void setDayCloseoutAnswer(String questionKey, String answer) {
    final map = Map<String, String>.from(state.dayCloseoutAnswers);
    map[questionKey] = answer;
    state = state.copyWith(dayCloseoutAnswers: map);
  }

  void setDayCloseoutNote(String note) {
    state = state.copyWith(dayCloseoutNote: note);
  }

  void setProfileName(String name) {
    state = state.copyWith(profileName: name);
  }

  void setLoggedIn(bool value) {
    if (value) {
      final next = Set<String>.from(state.loginDates);
      next.add(_dateKey(DateTime.now()));
      state = state.copyWith(isLoggedIn: true, loginDates: next);
    } else {
      state = state.copyWith(isLoggedIn: false);
    }
  }

  void markActive(DateTime timestamp) {
    state = state.copyWith(lastActiveAt: timestamp);
  }

  void setRemindersEnabled(bool value) {
    state = state.copyWith(remindersEnabled: value);
  }

  void setReminderTime(String value) {
    state = state.copyWith(reminderTime: value);
  }

  void _syncDailyUsage() {
    final blocksCount = state.todayPlan.length;
    final methodsCount = state.todayPlan.values
        .map((b) => b.methodIds.length)
        .fold<int>(0, (a, b) => a + b);
    final repo = _ref.read(dailyUsageRepoProvider);
    () async {
      await repo.upsertDailySummary(
        day: DateTime.now(),
        blocksCount: blocksCount,
        methodsCount: methodsCount,
      );
    }();
  }
}

String _dateKey(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

final userStateProvider =
    StateNotifierProvider<UserStateNotifier, UserState>(
        (ref) => UserStateNotifier(ref));

final knowledgeRepoProvider = Provider<KnowledgeRepository>((ref) =>
    KnowledgeRepository(client: ref.read(supabaseClientProvider)));
final innerRepoProvider = Provider<InnerRepository>(
    (ref) => InnerRepository(client: ref.read(supabaseClientProvider)));
final identityRepoProvider = Provider<IdentityRepository>(
    (ref) => IdentityRepository(client: ref.read(supabaseClientProvider)));
final systemRepoProvider = Provider<SystemRepository>(
    (ref) => SystemRepository(client: ref.read(supabaseClientProvider)));
final userProfileRepoProvider = Provider<UserProfileRepository>(
    (ref) => UserProfileRepository(client: ref.read(supabaseClientProvider)));
final dailyUsageRepoProvider = Provider<DailyUsageRepository>(
    (ref) => DailyUsageRepository(client: ref.read(supabaseClientProvider)));

final knowledgeProvider =
    FutureProvider<List<KnowledgeSnack>>((ref) async {
  final result = await ref.read(knowledgeRepoProvider).fetchSnacks();
  if (result.isSuccess) return result.data!;
  throw result.error!;
});

final innerProvider = FutureProvider<List<InnerItem>>((ref) async {
  final result = await ref.read(innerRepoProvider).fetchInnerItems();
  if (result.isSuccess) return result.data!;
  throw result.error!;
});

final identityProvider = FutureProvider<List<IdentityRole>>((ref) async {
  final result = await ref.read(identityRepoProvider).fetchRoles();
  if (result.isSuccess) return result.data!;
  throw result.error!;
});

final identityPillarsProvider =
    FutureProvider<List<IdentityPillar>>((ref) async {
  final result = await ref.read(identityRepoProvider).fetchPillars();
  if (result.isSuccess) return result.data!;
  throw result.error!;
});

final systemBlocksProvider = FutureProvider<List<SystemBlock>>((ref) async {
  final result = await ref.read(systemRepoProvider).fetchDayBlocks();
  if (result.isSuccess) return result.data!;
  throw result.error!;
});

final systemMethodsProvider = FutureProvider<List<MethodV2>>((ref) async {
  final result = await ref.read(systemRepoProvider).fetchMethods();
  if (result.isSuccess) return result.data!;
  throw result.error!;
});
