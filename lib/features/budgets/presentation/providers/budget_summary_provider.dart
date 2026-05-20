import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/models.dart';

class BudgetSummaryInput {
  const BudgetSummaryInput({
    required this.categories,
    required this.transactions,
    required this.budgets,
  });

  final List<Category> categories;
  final List<Transaction> transactions;
  final List<Budget> budgets;
}

class MonthlyBudgetSummary {
  const MonthlyBudgetSummary({
    required this.totalBudget,
    required this.totalExpense,
    required this.remainingBudget,
    required this.usedPercent,
    required this.categoryStatuses,
  });

  final double totalBudget;
  final double totalExpense;
  final double remainingBudget;
  final double usedPercent;
  final List<CategoryBudgetStatus> categoryStatuses;

  List<CategoryBudgetStatus> get overBudgetStatuses {
    return categoryStatuses.where((status) => status.isOverBudget).toList();
  }

  List<CategoryBudgetStatus> get warningStatuses {
    return categoryStatuses
        .where((status) => status.isNearLimit && !status.isOverBudget)
        .toList();
  }
}

class CategoryBudgetStatus {
  const CategoryBudgetStatus({
    required this.category,
    required this.budget,
    required this.budgetAmount,
    required this.spentAmount,
    required this.remainingAmount,
    required this.usedPercent,
    required this.isOverBudget,
    required this.hasBudget,
  });

  final Category category;
  final Budget? budget;
  final double budgetAmount;
  final double spentAmount;
  final double remainingAmount;
  final double usedPercent;
  final bool isOverBudget;
  final bool hasBudget;

  bool get isNearLimit {
    return hasBudget && !isOverBudget && usedPercent >= 0.8;
  }

  bool get hasSpendingWithoutBudget {
    return !hasBudget && spentAmount > 0;
  }
}

final monthlyBudgetSummaryProvider =
    Provider.family<MonthlyBudgetSummary, BudgetSummaryInput>((ref, input) {
      final expenseCategories =
          input.categories
              .where((category) => category.type == TransactionType.expense)
              .toList()
            ..sort((a, b) {
              final sortCompare = a.sortOrder.compareTo(b.sortOrder);
              if (sortCompare != 0) {
                return sortCompare;
              }
              return a.name.toLowerCase().compareTo(b.name.toLowerCase());
            });

      final expenseCategoryIds = expenseCategories
          .map((category) => category.id)
          .toSet();
      final expenseBudgets = input.budgets.where((budget) {
        return expenseCategoryIds.contains(budget.categoryId);
      });
      final budgetsByCategoryId = {
        for (final budget in expenseBudgets) budget.categoryId: budget,
      };

      final spentByCategoryId = <String, double>{};
      for (final transaction in input.transactions) {
        if (transaction.type != TransactionType.expense) {
          continue;
        }
        spentByCategoryId.update(
          transaction.categoryId,
          (value) => value + transaction.amount,
          ifAbsent: () => transaction.amount,
        );
      }

      final statuses = [
        for (final category in expenseCategories)
          _buildCategoryStatus(
            category: category,
            budget: budgetsByCategoryId[category.id],
            spentAmount: spentByCategoryId[category.id] ?? 0,
          ),
      ];

      final totalBudget = statuses.fold<double>(
        0,
        (sum, status) => sum + _finiteAmount(status.budgetAmount),
      );
      final totalExpense = statuses.fold<double>(
        0,
        (sum, status) => sum + _finiteAmount(status.spentAmount),
      );
      final remainingBudget = totalBudget - totalExpense;
      final usedPercent = totalBudget <= 0 ? 0.0 : totalExpense / totalBudget;

      return MonthlyBudgetSummary(
        totalBudget: totalBudget,
        totalExpense: totalExpense,
        remainingBudget: remainingBudget,
        usedPercent: usedPercent,
        categoryStatuses: statuses,
      );
    });

CategoryBudgetStatus _buildCategoryStatus({
  required Category category,
  required Budget? budget,
  required double spentAmount,
}) {
  final budgetAmount = _finiteAmount(budget?.amount ?? 0);
  final cleanSpentAmount = _finiteAmount(spentAmount);
  final remainingAmount = budgetAmount - cleanSpentAmount;
  final usedPercent = budgetAmount <= 0 ? 0.0 : cleanSpentAmount / budgetAmount;
  final cleanUsedPercent = usedPercent.isFinite ? usedPercent : 0.0;
  final isOverBudget = budgetAmount > 0 && cleanSpentAmount > budgetAmount;

  return CategoryBudgetStatus(
    category: category,
    budget: budget,
    budgetAmount: budgetAmount,
    spentAmount: cleanSpentAmount,
    remainingAmount: remainingAmount,
    usedPercent: cleanUsedPercent,
    isOverBudget: isOverBudget,
    hasBudget: budget != null,
  );
}

double _finiteAmount(double value) {
  return value.isFinite ? value : 0.0;
}
