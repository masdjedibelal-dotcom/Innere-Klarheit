import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/user_mission_statement.dart';

class GuestMissionState {
  final UserMissionStatement? statement;

  const GuestMissionState({this.statement});
}

class GuestMissionNotifier extends StateNotifier<GuestMissionState> {
  GuestMissionNotifier() : super(const GuestMissionState());

  void save({
    required String statement,
    required String? sourceTemplateId,
  }) {
    final now = DateTime.now();
    state = GuestMissionState(
      statement: UserMissionStatement(
        id: '',
        userId: '',
        statement: statement,
        sourceTemplateId: sourceTemplateId,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }
}

final guestMissionProvider =
    StateNotifierProvider<GuestMissionNotifier, GuestMissionState>(
  (ref) => GuestMissionNotifier(),
);













