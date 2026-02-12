class UserMissionStatement {
  final String id;
  final String userId;
  final String statement;
  final String? sourceTemplateId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserMissionStatement({
    required this.id,
    required this.userId,
    required this.statement,
    required this.sourceTemplateId,
    required this.createdAt,
    required this.updatedAt,
  });
}

