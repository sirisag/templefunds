/// Represents the Account entity from the database.
class Account {
  final int? id;
  final String name;
  final int? ownerUserId; // Foreign key to the users table
  final DateTime createdAt;

  Account({
    this.id,
    required this.name,
    this.ownerUserId,
    required this.createdAt,
  });

  Account copyWith({
    int? id,
    String? name,
    int? ownerUserId,
    DateTime? createdAt,
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Converts an Account instance into a Map.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'owner_user_id': ownerUserId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Creates an Account instance from a map.
  factory Account.fromMap(Map<String, dynamic> map) {
    return Account(
      id: map['id'] as int?,
      name: map['name'] as String,
      ownerUserId: map['owner_user_id'] as int?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}