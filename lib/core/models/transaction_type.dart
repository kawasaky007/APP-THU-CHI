enum TransactionType {
  income,
  expense;

  String get value {
    switch (this) {
      case TransactionType.income:
        return 'income';
      case TransactionType.expense:
        return 'expense';
    }
  }

  bool get isIncome => this == TransactionType.income;
  bool get isExpense => this == TransactionType.expense;

  static TransactionType fromJson(Object? value) {
    switch (value?.toString().trim().toLowerCase()) {
      case 'income':
        return TransactionType.income;
      case 'expense':
        return TransactionType.expense;
      default:
        throw FormatException(
          "Giá trị transaction type không hợp lệ: '$value'. "
          "Chỉ chấp nhận 'income' hoặc 'expense'.",
        );
    }
  }
}
