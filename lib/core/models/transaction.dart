import 'transaction_type.dart';

class Transaction {
  const Transaction({
    required this.id,
    required this.householdId,
    required this.userId,
    required this.categoryId,
    required this.type,
    required this.amount,
    required this.title,
    required this.transactionDate,
    this.note,
    this.paymentMethod,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String householdId;
  final String userId;
  final String categoryId;
  final TransactionType type;
  final double amount;
  final String title;
  final String? note;
  final String? paymentMethod;
  final DateTime transactionDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: _readRequiredString(json, 'id'),
      householdId: _readRequiredString(json, 'household_id'),
      userId: _readRequiredString(json, 'user_id'),
      categoryId: _readRequiredString(json, 'category_id'),
      type: TransactionType.fromJson(json['type']),
      amount: _readRequiredDouble(json['amount']),
      title: _readRequiredString(json, 'title'),
      note: _readString(json, 'note'),
      paymentMethod: _readString(json, 'payment_method'),
      transactionDate: _readRequiredDateTime(json, 'transaction_date'),
      createdAt: _readDateTime(json['created_at']),
      updatedAt: _readDateTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'household_id': householdId,
      'user_id': userId,
      'category_id': categoryId,
      'type': type.value,
      'amount': amount,
      'title': title,
      'transaction_date': transactionDate.toIso8601String(),
      if (note != null) 'note': note,
      if (paymentMethod != null) 'payment_method': paymentMethod,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  Transaction copyWith({
    String? id,
    String? householdId,
    String? userId,
    String? categoryId,
    TransactionType? type,
    double? amount,
    String? title,
    String? note,
    String? paymentMethod,
    DateTime? transactionDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Transaction(
      id: id ?? this.id,
      householdId: householdId ?? this.householdId,
      userId: userId ?? this.userId,
      categoryId: categoryId ?? this.categoryId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      title: title ?? this.title,
      note: note ?? this.note,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      transactionDate: transactionDate ?? this.transactionDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

String _readRequiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null || value.toString().trim().isEmpty) {
    throw FormatException("Thiếu trường bắt buộc '$key' trong Transaction.");
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

double _readRequiredDouble(Object? value) {
  final parsedValue = _readDouble(value);
  if (parsedValue == null) {
    throw const FormatException("Trường 'amount' không hợp lệ.");
  }
  return parsedValue;
}

double? _readDouble(Object? value) {
  if (value == null || value.toString().trim().isEmpty) {
    return null;
  }
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value.toString());
}

DateTime _readRequiredDateTime(Map<String, dynamic> json, String key) {
  final parsedValue = _readDateTime(json[key]);
  if (parsedValue == null) {
    throw FormatException("Trường '$key' không phải datetime hợp lệ.");
  }
  return parsedValue;
}

DateTime? _readDateTime(Object? value) {
  if (value == null || value.toString().trim().isEmpty) {
    return null;
  }
  return DateTime.tryParse(value.toString());
}
