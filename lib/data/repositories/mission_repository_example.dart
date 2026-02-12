import 'package:supabase_flutter/supabase_flutter.dart';

import 'mission_repository.dart';

Future<void> missionRepositoryExample() async {
  final repo = MissionRepository(client: Supabase.instance.client);

  final templatesResult = await repo.fetchTemplates();
  final templates = templatesResult.data ?? const [];
  if (templatesResult.isSuccess && templates.isNotEmpty) {
    // Example: pick the first template and upsert for current user.
    await repo.upsertUserMission(
        userId: null,
        statement: templates.first.template,
        sourceTemplateId: templates.first.id);
  }

  final userStatementResult = await repo.getUserMission(userId: null);
  final userStatement = userStatementResult.data;
  // ignore: avoid_print
  print(userStatement?.statement ?? 'No statement found');
}

