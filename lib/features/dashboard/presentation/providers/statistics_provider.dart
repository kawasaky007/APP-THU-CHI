import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/models.dart';
import '../../../categories/presentation/widgets/category_visuals.dart';

class DashboardCategoryChartItem {
  const DashboardCategoryChartItem({
    required this.name,
    required this.value,
    required this.color,
    required this.percent,
  });

  final String name;
  final double value;
  final Color color;
  final double percent;
}

class DashboardMemberTotal {
  const DashboardMemberTotal({required this.userId, required this.amount});

  final String userId;
  final double amount;
}

class DashboardStatisticsInput {
  const DashboardStatisticsInput({
    required this.transactions,
    required this.monthlyTransactions,
    required this.categories,
    required this.chartType,
  });

  final List<Transaction> transactions;
  final List<Transaction> monthlyTransactions;
  final List<Category> categories;
  final TransactionType chartType;
}

class DashboardStatistics {
  const DashboardStatistics({
    required this.recentTransactions,
    required this.chartItems,
    required this.chartTotal,
    required this.categoriesById,
    required this.expenseByMember,
    required this.incomeByMember,
    required this.topSpender,
  });

  final List<Transaction> recentTransactions;
  final List<DashboardCategoryChartItem> chartItems;
  final double chartTotal;
  final Map<String, Category> categoriesById;
  final Map<String, double> expenseByMember;
  final Map<String, double> incomeByMember;
  final DashboardMemberTotal? topSpender;
}

final dashboardStatisticsProvider =
    Provider.family<DashboardStatistics, DashboardStatisticsInput>((
      ref,
      input,
    ) {
      final categoriesById = {
        for (final category in input.categories) category.id: category,
      };

      final recentTransactions = [...input.transactions]
        ..sort(_compareTransactionNewestFirst);

      final categoryTotals = <String, double>{};
      final expenseByMember = <String, double>{};
      final incomeByMember = <String, double>{};
      for (final transaction in input.monthlyTransactions) {
        final memberTotals = transaction.type == TransactionType.expense
            ? expenseByMember
            : incomeByMember;
        memberTotals.update(
          transaction.userId,
          (value) => value + transaction.amount,
          ifAbsent: () => transaction.amount,
        );

        if (transaction.type != input.chartType) {
          continue;
        }
        categoryTotals.update(
          transaction.categoryId,
          (value) => value + transaction.amount,
          ifAbsent: () => transaction.amount,
        );
      }

      final chartTotal = categoryTotals.values.fold<double>(
        0,
        (total, value) => total + value,
      );

      final chartItems = categoryTotals.entries.map((entry) {
        final category = categoriesById[entry.key];
        final color = category == null
            ? CategoryVisuals.toneForType(input.chartType)
            : CategoryVisuals.colorFromHex(category.color);

        return DashboardCategoryChartItem(
          name: category?.name ?? 'Danh mục đã xóa',
          value: entry.value,
          color: color,
          percent: chartTotal == 0 ? 0 : entry.value / chartTotal,
        );
      }).toList()..sort((a, b) => b.value.compareTo(a.value));
      final topSpender = _topMemberTotal(expenseByMember);

      return DashboardStatistics(
        recentTransactions: recentTransactions.take(5).toList(),
        chartItems: chartItems,
        chartTotal: chartTotal,
        categoriesById: categoriesById,
        expenseByMember: Map.unmodifiable(expenseByMember),
        incomeByMember: Map.unmodifiable(incomeByMember),
        topSpender: topSpender,
      );
    });

DashboardMemberTotal? _topMemberTotal(Map<String, double> totalsByMember) {
  if (totalsByMember.isEmpty) {
    return null;
  }

  var topEntry = totalsByMember.entries.first;
  for (final entry in totalsByMember.entries.skip(1)) {
    if (entry.value > topEntry.value) {
      topEntry = entry;
    }
  }

  return DashboardMemberTotal(userId: topEntry.key, amount: topEntry.value);
}

int _compareTransactionNewestFirst(Transaction a, Transaction b) {
  final dateCompare = b.transactionDate.compareTo(a.transactionDate);
  if (dateCompare != 0) {
    return dateCompare;
  }

  final createdAtA = a.createdAt;
  final createdAtB = b.createdAt;
  if (createdAtA != null && createdAtB != null) {
    return createdAtB.compareTo(createdAtA);
  }

  return b.id.compareTo(a.id);
}
