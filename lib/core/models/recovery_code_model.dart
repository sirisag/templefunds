class RecoveryCode {
  final int id;
  final int userId;
  final String code;
  final bool isUsed;
  final DateTime createdAt;
  final bool isTagged;
  final DateTime? usedAt;

  RecoveryCode({
    required this.id,
    required this.userId,
    required this.code,
    required this.isUsed,
    required this.createdAt,
    required this.isTagged,
    this.usedAt,
  });

  factory RecoveryCode.fromMap(Map<String, dynamic> map) {
    return RecoveryCode(
      id: map['id'] as int,
      userId: map['user_id'] as int,
      code: map['code'] as String,
      isUsed: (map['is_used'] as int) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      isTagged: (map['is_tagged'] as int? ?? 0) == 1,
      usedAt: map['used_at'] != null
          ? DateTime.parse(map['used_at'] as String)
          : null,
    );
  }
}
