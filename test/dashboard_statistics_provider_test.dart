import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thu_chi_viet_nam/core/models/models.dart';
import 'package:thu_chi_viet_nam/features/dashboard/presentation/providers/statistics_provider.dart';

void main() {
  group('dashboardStatisticsProvider member totals', () {
    test('calculates expense, income, and top spender by member', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final stats = container.read(
        dashboardStatisticsProvider(
          DashboardStatisticsInput(
            transactions: const [],
            monthlyTransactions: [
              _transaction(
                id: 't1',
                userId: 'mom',
                categoryId: 'food',
                type: TransactionType.expense,
                amount: 500000,
              ),
              _transaction(
                id: 't2',
                userId: 'dad',
                categoryId: 'food',
                type: TransactionType.expense,
                amount: 200000,
              ),
              _transaction(
                id: 't3',
                userId: 'mom',
                categoryId: 'market',
                type: TransactionType.expense,
                amount: 300000,
              ),
              _transaction(
                id: 't4',
                userId: 'dad',
                categoryId: 'salary',
                type: TransactionType.income,
                amount: 10000000,
              ),
            ],
            categories: _categories,
            chartType: TransactionType.expense,
          ),
        ),
      );

      expect(stats.expenseByMember, {'mom': 800000, 'dad': 200000});
      expect(stats.incomeByMember, {'dad': 10000000});
      expect(stats.topSpender?.userId, 'mom');
      expect(stats.topSpender?.amount, 800000);
    });

    test('top spender is null when there are no monthly expenses', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final stats = container.read(
        dashboardStatisticsProvider(
          DashboardStatisticsInput(
            transactions: const [],
            monthlyTransactions: [
              _transaction(
                id: 't1',
                userId: 'mom',
                categoryId: 'salary',
                type: TransactionType.income,
                amount: 7000000,
              ),
            ],
            categories: _categories,
            chartType: TransactionType.income,
          ),
        ),
      );

      expect(stats.expenseByMember, isEmpty);
      expect(stats.incomeByMember, {'mom': 7000000});
      expect(stats.topSpender, isNull);
    });
  });
}

const _categories = [
  Category(
    id: 'food',
    householdId: 'h1',
    name: 'Ăn uống',
    type: TransactionType.expense,
    color: '#C2410C',
    icon: 'food',
  ),
  Category(
    id: 'market',
    householdId: 'h1',
    name: 'Đi chợ',
    type: TransactionType.expense,
    color: '#0F8B6F',
    icon: 'shopping',
  ),
  Category(
    id: 'salary',
    householdId: 'h1',
    name: 'Lương',
    type: TransactionType.income,
    color: '#0F8B6F',
    icon: 'salary',
  ),
];

Transaction _transaction({
  required String id,
  required String userId,
  required String categoryId,
  required TransactionType type,
  required double amount,
}) {
  return Transaction(
    id: id,
    householdId: 'h1',
    userId: userId,
    categoryId: categoryId,
    type: type,
    amount: amount,
    title: categoryId,
    transactionDate: DateTime(2026, 6, 1),
  );
}
