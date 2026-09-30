enum UserRole {
  patient,
  doctor,
  admin;

  static UserRole fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'doctor':
        return UserRole.doctor;
      case 'admin':
        return UserRole.admin;
      case 'patient':
      default:
        return UserRole.patient;
    }
  }

  String toDbValue() => name;
}

class UserProfile {
  final String id;
  final String email;
  final String? phone;
  final String fullName;
  final UserRole role;
  final DateTime createdAt;

  const UserProfile({
    required this.id,
    required this.email,
    this.phone,
    required this.fullName,
    required this.role,
    required this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String?,
      fullName: json['full_name'] as String? ?? '',
      role: UserRole.fromString(json['role'] as String?),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'phone': phone,
      'full_name': fullName,
      'role': role.toDbValue(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  UserProfile copyWith({
    String? email,
    String? phone,
    String? fullName,
    UserRole? role,
  }) {
    return UserProfile(
      id: id,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      createdAt: createdAt,
    );
  }
}
