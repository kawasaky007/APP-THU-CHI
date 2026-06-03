class Budget {
  const Budget({
    required this.id,
    required this.householdId,
    required this.categoryId,
    required this.month,
    required this.year,
    required this.amount,
    this.displayOrder = 0,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String householdId;
  final String categoryId;
  final int month;
  final int year;
  final double amount;
  final int displayOrder;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Budget.fromJson(Map<String, dynamic> json) {
    return Budget(
      id: _readRequiredString(json, 'id'),
      householdId: _readRequiredString(json, 'household_id'),
      categoryId: _readRequiredString(json, 'category_id'),
      month: _readRequiredInt(json['month'], 'month'),
      year: _readRequiredInt(json['year'], 'year'),
      amount: _readRequiredDouble(json['amount'], 'amount'),
      displayOrder: _readOptionalInt(json['display_order']) ?? 0,
      createdBy: _readString(json, 'created_by'),
      createdAt: _readDateTime(json['created_at']),
      updatedAt: _readDateTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    final createdAt = this.createdAt;
    final updatedAt = this.updatedAt;
    return {
      'id': id,
      'household_id': householdId,
      'category_id': categoryId,
      'month': month,
      'year': year,
      'amount': amount,
      'display_order': displayOrder,
      if (createdBy != null) 'created_by': createdBy,
      if (createdAt != null) 'created_at': createdAt.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt.toIso8601String(),
    };
  }

  Budget copyWith({
    String? id,
    String? householdId,
    String? categoryId,
    int? month,
    int? year,
    double? amount,
    int? displayOrder,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Budget(
      id: id ?? this.id,
      householdId: householdId ?? this.householdId,
      categoryId: categoryId ?? this.categoryId,
      month: month ?? this.month,
      year: year ?? this.year,
      amount: amount ?? this.amount,
      displayOrder: displayOrder ?? this.displayOrder,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

String _readRequiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null || value.toString().trim().isEmpty) {
    throw FormatException("Thiếu trường bắt buộc '$key' trong Budget.");
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

int _readRequiredInt(Object? value, String key) {
  if (value == null || value.toString().trim().isEmpty) {
    throw FormatException("Trường '$key' không hợp lệ.");
  }
  if (value is num) {
    return value.toInt();
  }
  final parsedValue = int.tryParse(value.toString());
  if (parsedValue == null) {
    throw FormatException("Trường '$key' không hợp lệ.");
  }
  return parsedValue;
}

double _readRequiredDouble(Object? value, String key) {
  if (value == null || value.toString().trim().isEmpty) {
    throw FormatException("Trường '$key' không hợp lệ.");
  }
  if (value is num) {
    return value.toDouble();
  }
  final parsedValue = double.tryParse(value.toString());
  if (parsedValue == null) {
    throw FormatException("Trường '$key' không hợp lệ.");
  }
  return parsedValue;
}

DateTime? _readDateTime(Object? value) {
  if (value == null || value.toString().trim().isEmpty) {
    return null;
  }
  return DateTime.tryParse(value.toString());
}

int? _readOptionalInt(Object? value) {
  if (value == null || value.toString().trim().isEmpty) {
    return null;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value.toString());
}
