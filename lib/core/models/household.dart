class Household {
  const Household({
    required this.id,
    required this.name,
    required this.ownerId,
    this.currencyCode = 'VND',
    this.monthlyBudget,
    this.inviteCode,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String ownerId;
  final String currencyCode;
  final int? monthlyBudget;
  final String? inviteCode;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Household.fromJson(Map<String, dynamic> json) {
    return Household(
      id: _readRequiredString(json, 'id'),
      name: _readRequiredString(json, 'name'),
      ownerId: _readRequiredString(json, 'owner_id'),
      currencyCode: _readString(json, 'currency_code') ?? 'VND',
      monthlyBudget: _readInt(json['monthly_budget']),
      inviteCode: _readString(json, 'invite_code'),
      createdAt: _readDateTime(json['created_at']),
      updatedAt: _readDateTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    final createdAt = this.createdAt;
    final updatedAt = this.updatedAt;
    return {
      'id': id,
      'name': name,
      'owner_id': ownerId,
      'currency_code': currencyCode,
      if (monthlyBudget != null) 'monthly_budget': monthlyBudget,
      if (inviteCode != null) 'invite_code': inviteCode,
      if (createdAt != null) 'created_at': createdAt.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt.toIso8601String(),
    };
  }

  Household copyWith({
    String? id,
    String? name,
    String? ownerId,
    String? currencyCode,
    int? monthlyBudget,
    String? inviteCode,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Household(
      id: id ?? this.id,
      name: name ?? this.name,
      ownerId: ownerId ?? this.ownerId,
      currencyCode: currencyCode ?? this.currencyCode,
      monthlyBudget: monthlyBudget ?? this.monthlyBudget,
      inviteCode: inviteCode ?? this.inviteCode,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

String _readRequiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null || value.toString().trim().isEmpty) {
    throw FormatException("Thiếu trường bắt buộc '$key' trong Household.");
  }
  return value.toString();
}

String? _readString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null || value.toString().trim().isEmpty) {
    return null;
  }
  return value.toString();
}

int? _readInt(Object? value) {
  if (value == null || value.toString().trim().isEmpty) {
    return null;
  }
  if (value is num) {
    return value.floor();
  }
  final digitsOnly = value.toString().replaceAll(RegExp(r'\D'), '');
  if (digitsOnly.isEmpty) {
    return null;
  }
  return int.tryParse(digitsOnly);
}

DateTime? _readDateTime(Object? value) {
  if (value == null || value.toString().trim().isEmpty) {
    return null;
  }
  return DateTime.tryParse(value.toString());
}
