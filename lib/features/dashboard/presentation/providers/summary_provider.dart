import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/models.dart';

class DashboardSummary {
  final double income;
  final double expense;
  final double balance;

  const DashboardSummary({
    required this.income,
    required this.expense,
    required this.balance,
  });
}

final dashboardCurrentMonthTransactionsProvider =
    Provider.family<List<Transaction>, List<Transaction>>((ref, transactions) {
      final now = DateTime.now();
      return transactions.where((transaction) {
        final date = transaction.transactionDate;
        return date.year == now.year && date.month == now.month;
      }).toList();
    });

final dashboardSummaryProvider =
    Provider.family<DashboardSummary, List<Transaction>>((ref, transactions) {
      final income = transactions
          .where((transaction) => transaction.type == TransactionType.income)
          .fold<double>(0, (sum, transaction) => sum + transaction.amount);

      final expense = transactions
          .where((transaction) => transaction.type == TransactionType.expense)
          .fold<double>(0, (sum, transaction) => sum + transaction.amount);

      final balance = income - expense;
      debugPrint('DASHBOARD INCOME: $income');
      debugPrint('DASHBOARD EXPENSE: $expense');
      debugPrint('DASHBOARD BALANCE: $balance');

      return DashboardSummary(
        income: income,
        expense: expense,
        balance: balance,
      );
    });
