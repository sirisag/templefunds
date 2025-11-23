/// Defines the possible roles for a user in the system.
enum UserRole { Admin, Master, Monk }

/// Represents the User entity from the database.
class User {
  final int? id; // Nullable for new users that don't have an ID yet.
  final String userId1;
  final String userId2;
  final String? firstName;
  final String? lastName;
  final String nickname;
  final String? ordinationName;
  final String? specialTitle;
  final String? phoneNumber;
  final String? email;
  final String? profileImage;
  final UserRole role;
  final DateTime createdAt;
  final String status; // 'active' or 'inactive'

  User({
    this.id,
    required this.userId1,
    required this.userId2,
    this.firstName,
    this.lastName,
    required this.nickname,
    this.ordinationName,
    this.specialTitle,
    this.phoneNumber,
    this.email,
    this.profileImage,
    required this.role,
    required this.createdAt,
    this.status = 'active',
  });

  User copyWith({
    int? id,
    String? userId1,
    String? userId2,
    String? firstName,
    String? lastName,
    String? nickname,
    String? ordinationName,
    String? specialTitle,
    String? phoneNumber,
    String? email,
    String? profileImage,
    UserRole? role,
    DateTime? createdAt,
    String? status,
  }) {
    return User(
      id: id ?? this.id,
      userId1: userId1 ?? this.userId1,
      userId2: userId2 ?? this.userId2,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      nickname: nickname ?? this.nickname,
      ordinationName: ordinationName ?? this.ordinationName,
      specialTitle: specialTitle ?? this.specialTitle,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      profileImage: profileImage ?? this.profileImage,
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
      'first_name': firstName,
      'last_name': lastName,
      'nickname': nickname,
      'ordination_name': ordinationName,
      'special_title': specialTitle,
      'phone_number': phoneNumber,
      'email': email,
      'profile_image': profileImage,
      'role': role.name, // Store the enum's name as a string
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
      firstName: map['first_name'] as String?,
      lastName: map['last_name'] as String?,
      // nickname is required, but we provide a fallback from the old 'name' field for migration
      nickname: map['nickname'] as String? ?? map['name'] as String? ?? '',
      ordinationName: map['ordination_name'] as String?,
      specialTitle: map['special_title'] as String?,
      phoneNumber: map['phone_number'] as String?,
      email: map['email'] as String?,
      profileImage: map['profile_image'] as String?,
      // Convert string from DB back to enum, default to Monk if invalid
      role: UserRole.values.byName(map['role'] as String? ?? 'Monk'),
      createdAt: DateTime.parse(map['created_at'] as String),
      status: map['status'] as String? ?? 'active',
    );
  }
}
