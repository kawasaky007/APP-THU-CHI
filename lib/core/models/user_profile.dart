class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.fullName,
    this.householdId,
    this.avatarUrl,
    this.phoneNumber,
    this.role = UserProfileRole.member,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String email;
  final String fullName;
  final String? householdId;
  final String? avatarUrl;
  final String? phoneNumber;
  final UserProfileRole role;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Role lưu trong bảng profiles là role tài khoản chung của app.
  // Vai trò trong household như owner/partner được suy ra từ households.owner_id.
  static const databaseRole = 'user';

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: _readRequiredString(json, 'id'),
      email: _readRequiredString(json, 'email'),
      fullName: _readRequiredString(json, 'full_name'),
      householdId: _readNullableString(json, 'household_id'),
      avatarUrl: _readNullableString(json, 'avatar_url'),
      phoneNumber: _readNullableString(json, 'phone_number'),
      role: UserProfileRole.fromJson(json['role']),
      createdAt: _readDateTime(json['created_at']),
      updatedAt: _readDateTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    final createdAt = this.createdAt;
    final updatedAt = this.updatedAt;
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'role': databaseRole,
      if (householdId != null) 'household_id': householdId,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (phoneNumber != null) 'phone_number': phoneNumber,
      if (createdAt != null) 'created_at': createdAt.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt.toIso8601String(),
    };
  }

  UserProfile copyWith({
    String? id,
    String? email,
    String? fullName,
    String? householdId,
    String? avatarUrl,
    String? phoneNumber,
    UserProfileRole? role,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      householdId: householdId ?? this.householdId,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

enum UserProfileRole {
  owner,
  partner,
  member;

  String get value {
    switch (this) {
      case UserProfileRole.owner:
        return 'owner';
      case UserProfileRole.partner:
        return 'partner';
      case UserProfileRole.member:
        return 'member';
    }
  }

  static UserProfileRole fromJson(Object? value) {
    switch (value?.toString().trim().toLowerCase()) {
      case 'owner':
        return UserProfileRole.owner;
      case 'partner':
        return UserProfileRole.partner;
      case 'user':
      case 'member':
      case null:
      case '':
        return UserProfileRole.member;
      default:
        throw FormatException("Role người dùng không hợp lệ: '$value'.");
    }
  }
}

String _readRequiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null || value.toString().trim().isEmpty) {
    throw FormatException("Thiếu trường bắt buộc '$key' trong UserProfile.");
  }
  return value.toString();
}

String? _readNullableString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null || value.toString().trim().isEmpty) {
    return null;
  }
  return value.toString();
}

DateTime? _readDateTime(Object? value) {
  if (value == null || value.toString().trim().isEmpty) {
    return null;
  }
  return DateTime.tryParse(value.toString());
}
