import 'transaction_type.dart';

class Category {
  const Category({
    required this.id,
    required this.householdId,
    required this.name,
    required this.type,
    required this.color,
    required this.icon,
    this.description,
    this.isDefault = false,
    this.sortOrder = 0,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String householdId;
  final String name;
  final TransactionType type;

  /// Màu lưu dạng hex, ví dụ: #0F8B6F.
  final String color;

  /// Tên icon lưu trong database, ví dụ: food, salary, home.
  final String icon;
  final String? description;
  final bool isDefault;
  final int sortOrder;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: _readRequiredString(json, 'id'),
      householdId: _readRequiredString(json, 'household_id'),
      name: _readRequiredString(json, 'name'),
      type: TransactionType.fromJson(json['type']),
      color: _readRequiredString(json, 'color'),
      icon: _readRequiredString(json, 'icon'),
      description: _readString(json, 'description'),
      isDefault: _readBool(json['is_default']),
      sortOrder: _readInt(json['sort_order']) ?? 0,
      createdAt: _readDateTime(json['created_at']),
      updatedAt: _readDateTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'household_id': householdId,
      'name': name,
      'type': type.value,
      'color': color,
      'icon': icon,
      'is_default': isDefault,
      'sort_order': sortOrder,
      if (description != null) 'description': description,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  Category copyWith({
    String? id,
    String? householdId,
    String? name,
    TransactionType? type,
    String? color,
    String? icon,
    String? description,
    bool? isDefault,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Category(
      id: id ?? this.id,
      householdId: householdId ?? this.householdId,
      name: name ?? this.name,
      type: type ?? this.type,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      description: description ?? this.description,
      isDefault: isDefault ?? this.isDefault,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

String _readRequiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null || value.toString().trim().isEmpty) {
    throw FormatException("Thiếu trường bắt buộc '$key' trong Category.");
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

bool _readBool(Object? value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  return value?.toString().trim().toLowerCase() == 'true';
}

int? _readInt(Object? value) {
  if (value == null || value.toString().trim().isEmpty) {
    return null;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value.toString());
}

DateTime? _readDateTime(Object? value) {
  if (value == null || value.toString().trim().isEmpty) {
    return null;
  }
  return DateTime.tryParse(value.toString());
}
