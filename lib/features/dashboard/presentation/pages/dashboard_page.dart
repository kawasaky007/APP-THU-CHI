import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/app_constants.dart';
import '../../../../core/models/models.dart';
import '../../../../core/router/app_routes.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../budgets/presentation/providers/budget_provider.dart';
import '../../../budgets/presentation/providers/budget_summary_provider.dart';
import '../../../categories/presentation/providers/category_provider.dart';
import '../../../categories/presentation/widgets/category_visuals.dart';
import '../../../transactions/presentation/providers/transaction_provider.dart';
import '../providers/statistics_provider.dart';
import '../providers/summary_provider.dart';

class DashboardPage extends DashboardScreen {
  const DashboardPage({super.key});
}

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  TransactionType _chartType = TransactionType.expense;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final householdId = ref.watch(currentHouseholdIdProvider);
    final userId = authState.user?.id ?? authState.profile?.id;
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);

    if (householdId == null) {
      return const Scaffold(
        body: Center(child: Text('Bạn chưa tham gia household nào.')),
      );
    }

    debugPrint(
      'DASHBOARD REALTIME UI: householdId=$householdId userId=$userId',
    );
    final transactionsAsync = ref.watch(
      transactionsStreamProvider(householdId),
    );
    final budgetParams = BudgetMonthParams(
      householdId: householdId,
      month: currentMonth.month,
      year: currentMonth.year,
    );

    return transactionsAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) => _DashboardErrorView(
        onRetry: () => ref.invalidate(transactionsStreamProvider(householdId)),
      ),
      data: (transactions) {
        debugPrint('DASHBOARD REALTIME TRANSACTIONS: ${transactions.length}');

        final monthlyTransactions = ref.watch(
          dashboardCurrentMonthTransactionsProvider(transactions),
        );
        final summary = ref.watch(
          dashboardSummaryProvider(monthlyTransactions),
        );
        final categoriesAsync = ref.watch(
          categoriesStreamProvider(householdId),
        );

        return categoriesAsync.when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (error, stackTrace) => _DashboardErrorView(
            onRetry: () =>
                ref.invalidate(categoriesStreamProvider(householdId)),
          ),
          data: (categories) {
            final budgetsAsync = ref.watch(
              budgetsByMonthProvider(budgetParams),
            );

            return budgetsAsync.when(
              loading: () => const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stackTrace) => _DashboardErrorView(
                onRetry: () =>
                    ref.invalidate(budgetsByMonthProvider(budgetParams)),
              ),
              data: (budgets) {
                final budgetSummary = ref.watch(
                  monthlyBudgetSummaryProvider(
                    BudgetSummaryInput(
                      categories: categories,
                      transactions: monthlyTransactions,
                      budgets: budgets,
                    ),
                  ),
                );
                final statistics = ref.watch(
                  dashboardStatisticsProvider(
                    DashboardStatisticsInput(
                      transactions: transactions,
                      monthlyTransactions: monthlyTransactions,
                      categories: categories,
                      chartType: _chartType,
                    ),
                  ),
                );

                return Scaffold(
                  appBar: AppBar(title: const Text('Tổng quan')),
                  body: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.sm,
                      AppSpacing.md,
                      AppSpacing.lg,
                    ),
                    children: [
                      _BalanceHero(balance: summary.balance),
                      const SizedBox(height: AppSpacing.md),
                      _MonthlySummaryRow(
                        income: summary.income,
                        expense: summary.expense,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _BudgetProgressCard(
                        month: currentMonth,
                        summary: budgetSummary,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _CategoryPieCard(
                        chartType: _chartType,
                        items: statistics.chartItems,
                        total: statistics.chartTotal,
                        onTypeChanged: (type) =>
                            _setLocalState(() => _chartType = type),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _RecentTransactionsSection(
                        transactions: statistics.recentTransactions,
                        categoriesById: statistics.categoriesById,
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _setLocalState(VoidCallback update) {
    if (!mounted) {
      return;
    }
    setState(update);
  }
}

class _BalanceHero extends StatelessWidget {
  _BalanceHero({required this.balance});

  final double balance;
  final _currencyFormat = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: 'đ',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final balanceColor = balance >= 0
        ? const Color(0xFF0F8B6F)
        : colorScheme.error;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            'Cân đối tháng này',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _currencyFormat.format(balance),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: balanceColor,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Tự động cập nhật khi có giao dịch mới',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onPrimaryContainer.withValues(alpha: 0.78),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthlySummaryRow extends StatelessWidget {
  const _MonthlySummaryRow({required this.income, required this.expense});

  final double income;
  final double expense;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MonthlySummaryCard(
            title: 'Tổng thu tháng này',
            value: income,
            icon: Icons.trending_up,
            color: const Color(0xFF0F8B6F),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _MonthlySummaryCard(
            title: 'Tổng chi tháng này',
            value: expense,
            icon: Icons.trending_down,
            color: const Color(0xFFC2410C),
          ),
        ),
      ],
    );
  }
}

class _MonthlySummaryCard extends StatelessWidget {
  _MonthlySummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final double value;
  final IconData icon;
  final Color color;
  final _currencyFormat = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: 'đ',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                _currencyFormat.format(value),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetProgressCard extends StatelessWidget {
  _BudgetProgressCard({required this.month, required this.summary});

  final DateTime month;
  final MonthlyBudgetSummary summary;
  final _currencyFormat = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: 'đ',
    decimalDigits: 0,
  );
  final _monthFormat = DateFormat('MM/yyyy', 'vi_VN');

  @override
  Widget build(BuildContext context) {
    final hasBudget = summary.totalBudget > 0;
    final ratio = hasBudget ? summary.usedPercent.clamp(0.0, 1.0) : 0.0;
    final colorScheme = Theme.of(context).colorScheme;
    final progressColor = !hasBudget
        ? colorScheme.primary
        : summary.remainingBudget < 0
        ? colorScheme.error
        : ratio >= 0.8
        ? const Color(0xFFCA8A04)
        : const Color(0xFF0F8B6F);
    final overBudgetStatuses = summary.overBudgetStatuses;
    final warningStatuses = summary.warningStatuses;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.savings_outlined, color: progressColor),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Ngân sách tháng',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    if (context.mounted) {
                      context.go(AppRoutes.budgets);
                    }
                  },
                  child: const Text('Quản lý'),
                ),
              ],
            ),
            Text(
              'Tháng ${_monthFormat.format(month)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: _BudgetMetric(
                    label: 'Tổng ngân sách',
                    value: _currencyFormat.format(summary.totalBudget),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _BudgetMetric(
                    label: 'Đã chi',
                    value: _currencyFormat.format(summary.totalExpense),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _BudgetMetric(
                    label: 'Còn lại',
                    value: hasBudget
                        ? _currencyFormat.format(summary.remainingBudget)
                        : 'Chưa đặt',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 10,
                value: ratio,
                color: progressColor,
                backgroundColor: colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              hasBudget
                  ? 'Đã dùng ${(summary.usedPercent * 100).round()}% ngân sách.'
                  : 'Ngân sách tổng được tính từ ngân sách từng danh mục chi.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (overBudgetStatuses.isNotEmpty ||
                warningStatuses.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              for (final status in overBudgetStatuses.take(3))
                _BudgetAlertRow(
                  color: colorScheme.error,
                  icon: Icons.warning_amber_outlined,
                  text:
                      '${status.category.name} đã vượt ${_currencyFormat.format(status.spentAmount - status.budgetAmount)}',
                ),
              for (final status in warningStatuses.take(3))
                _BudgetAlertRow(
                  color: const Color(0xFFCA8A04),
                  icon: Icons.info_outline,
                  text:
                      '${status.category.name} đã dùng ${(status.usedPercent * 100).round()}%',
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BudgetAlertRow extends StatelessWidget {
  const _BudgetAlertRow({
    required this.color,
    required this.icon,
    required this.text,
  });

  final Color color;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetMetric extends StatelessWidget {
  const _BudgetMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: AppSpacing.xs),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}

class _CategoryPieCard extends StatelessWidget {
  const _CategoryPieCard({
    required this.chartType,
    required this.items,
    required this.total,
    required this.onTypeChanged,
  });

  final TransactionType chartType;
  final List<DashboardCategoryChartItem> items;
  final double total;
  final ValueChanged<TransactionType> onTypeChanged;

  @override
  Widget build(BuildContext context) {
    final typeLabel = CategoryVisuals.labelForType(chartType).toLowerCase();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Cơ cấu $typeLabel theo danh mục',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                SegmentedButton<TransactionType>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: TransactionType.expense,
                      label: Text('Chi'),
                    ),
                    ButtonSegment(
                      value: TransactionType.income,
                      label: Text('Thu'),
                    ),
                  ],
                  selected: {chartType},
                  onSelectionChanged: (selectedValues) {
                    onTypeChanged(selectedValues.first);
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (items.isEmpty)
              _EmptyPieChart(type: chartType)
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 520;
                  final chart = SizedBox(
                    height: compact ? 220 : 240,
                    child: PieChart(
                      PieChartData(
                        centerSpaceRadius: compact ? 48 : 58,
                        sectionsSpace: 3,
                        sections: [
                          for (final item in items)
                            PieChartSectionData(
                              value: item.value,
                              color: item.color,
                              radius: compact ? 72 : 84,
                              title: item.percent >= 0.07
                                  ? '${(item.percent * 100).round()}%'
                                  : '',
                              titleStyle: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );

                  final legend = _ChartLegend(items: items, total: total);

                  if (compact) {
                    return Column(
                      children: [
                        chart,
                        const SizedBox(height: AppSpacing.md),
                        legend,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: chart),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(child: legend),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _ChartLegend extends StatelessWidget {
  _ChartLegend({required this.items, required this.total});

  final List<DashboardCategoryChartItem> items;
  final double total;
  final _currencyFormat = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: 'đ',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: item.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  _currencyFormat.format(item.value),
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        const Divider(height: AppSpacing.lg),
        Row(
          children: [
            const Expanded(child: Text('Tổng')),
            Text(
              _currencyFormat.format(total),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ],
    );
  }
}

class _EmptyPieChart extends StatelessWidget {
  const _EmptyPieChart({required this.type});

  final TransactionType type;

  @override
  Widget build(BuildContext context) {
    final label = CategoryVisuals.labelForType(type).toLowerCase();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(
            Icons.pie_chart_outline,
            size: 44,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('Chưa có giao dịch $label trong tháng này'),
        ],
      ),
    );
  }
}

class _RecentTransactionsSection extends StatelessWidget {
  const _RecentTransactionsSection({
    required this.transactions,
    required this.categoriesById,
  });

  final List<Transaction> transactions;
  final Map<String, Category> categoriesById;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '5 giao dịch gần nhất',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            TextButton(
              onPressed: () {
                if (context.mounted) {
                  context.go(AppRoutes.transactions);
                }
              },
              child: const Text('Xem tất cả'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (transactions.isEmpty)
          _EmptyRecentTransactions()
        else
          for (final transaction in transactions) ...[
            _RecentTransactionTile(
              transaction: transaction,
              category: categoriesById[transaction.categoryId],
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
      ],
    );
  }
}

class _RecentTransactionTile extends StatelessWidget {
  _RecentTransactionTile({required this.transaction, required this.category});

  final Transaction transaction;
  final Category? category;
  final _currencyFormat = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: 'đ',
    decimalDigits: 0,
  );
  final _dateFormat = DateFormat('dd/MM/yyyy', 'vi_VN');

  @override
  Widget build(BuildContext context) {
    final category = this.category;
    final color = category == null
        ? CategoryVisuals.toneForType(transaction.type)
        : CategoryVisuals.colorFromHex(category.color);
    final icon = category == null
        ? Icons.category_outlined
        : CategoryVisuals.iconFromName(category.icon);
    final prefix = transaction.type == TransactionType.income ? '+' : '-';

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.14),
          child: Icon(icon, color: color),
        ),
        title: Text(category?.name ?? transaction.title),
        subtitle: Text(_dateFormat.format(transaction.transactionDate)),
        trailing: Text(
          '$prefix${_currencyFormat.format(transaction.amount)}',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _EmptyRecentTransactions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 42,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text('Chưa có giao dịch nào'),
          const SizedBox(height: AppSpacing.sm),
          FilledButton.icon(
            onPressed: () {
              if (context.mounted) {
                context.push(AppRoutes.addTransaction);
              }
            },
            icon: const Icon(Icons.add),
            label: const Text('Thêm giao dịch'),
          ),
        ],
      ),
    );
  }
}

class _DashboardErrorView extends StatelessWidget {
  const _DashboardErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: AppSpacing.md),
              const Text('Không thể tải dữ liệu tổng quan.'),
              const SizedBox(height: AppSpacing.md),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
