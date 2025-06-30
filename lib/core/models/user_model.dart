/// Represents the User entity from the database.
class User {
  final int? id; // Nullable for new users that don't have an ID yet.
  final String userId1;
  final String userId2;
  final String name;
  final String role;
  final DateTime createdAt;
  final String status; // 'active' or 'inactive'

  User({
    this.id,
    required this.userId1,
    required this.userId2,
    required this.name,
    required this.role,
    required this.createdAt,
    this.status = 'active',
  });

  User copyWith({
    int? id,
    String? userId1,
    String? userId2,
    String? name,
    String? role,
    DateTime? createdAt,
    String? status,
  }) {
    return User(
      id: id ?? this.id,
      userId1: userId1 ?? this.userId1,
      userId2: userId2 ?? this.userId2,
      name: name ?? this.name,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
    );
  }

  /// Converts a User instance into a Map.
  /// The keys must correspond to the names of the columns in the database.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id_1': userId1,
      'user_id_2': userId2,
      'name': name,
      'role': role,
      'created_at': createdAt.toIso8601String(),
      'status': status,
    };
  }

  /// Creates a User instance from a map.
  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as int?,
      userId1: map['user_id_1'] as String,
      userId2: map['user_id_2'] as String,
      name: map['name'] as String,
      role: map['role'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      status: map['status'] as String? ?? 'active',
    );
  }
}