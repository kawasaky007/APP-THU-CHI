import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/app_constants.dart';
import '../../../../core/models/models.dart';
import '../../../../shared/formatters/currency_input_formatter.dart';
import '../../../../shared/widgets/app_feedback.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../categories/presentation/providers/category_provider.dart';
import '../../../categories/presentation/widgets/category_visuals.dart';
import '../../../transactions/presentation/providers/transaction_provider.dart';
import '../providers/budget_provider.dart';
import '../providers/budget_summary_provider.dart';

class BudgetScreen extends ConsumerStatefulWidget {
  const BudgetScreen({super.key});

  @override
  ConsumerState<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends ConsumerState<BudgetScreen> {
  late DateTime _selectedMonth;
  final _monthFormat = DateFormat('MM/yyyy', 'vi_VN');

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final householdId = ref.watch(currentHouseholdIdProvider);
    final userId = authState.user?.id ?? authState.profile?.id;
    final actionState = ref.watch(budgetActionProvider);

    if (householdId == null) {
      return const Scaffold(
        body: Center(child: Text('Bạn chưa tham gia household nào.')),
      );
    }

    final budgetParams = BudgetMonthParams(
      householdId: householdId,
      month: _selectedMonth.month,
      year: _selectedMonth.year,
    );

    debugPrint(
      'BUDGET SCREEN REALTIME UI: householdId=$householdId userId=$userId month=${budgetParams.month} year=${budgetParams.year}',
    );

    final categoriesAsync = ref.watch(categoriesStreamProvider(householdId));
    final transactionsAsync = ref.watch(
      transactionsStreamProvider(householdId),
    );
    final budgetsAsync = ref.watch(budgetsByMonthProvider(budgetParams));

    final categories = categoriesAsync.valueOrNull;
    final transactions = transactionsAsync.valueOrNull;
    final budgets = budgetsAsync.valueOrNull;

    // Trigger automatic budget cloning when month has no budgets.
    if (budgets != null && budgets.isEmpty) {
      final cloneAsync = ref.watch(budgetCloneProvider(budgetParams));
      if (cloneAsync.isLoading) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      // If cloning threw an error, log it and show empty state.
      if (cloneAsync.hasError) {
        debugPrint(
          '[BudgetClone] Error: ${cloneAsync.error}',
        );
      }
      // If cloning was performed, invalidate stream to force reload.
      if (cloneAsync.valueOrNull == true) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ref.invalidate(budgetsByMonthProvider(budgetParams));
          ref.invalidate(budgetCloneProvider(budgetParams));
        });
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
    }

    if (categoriesAsync.hasError && categories == null ||
        transactionsAsync.hasError && transactions == null ||
        budgetsAsync.hasError && budgets == null) {
      return _BudgetLoadError(
        onRetry: () => _refreshBudgetData(
          householdId: householdId,
          budgetParams: budgetParams,
        ),
      );
    }

    if (categories == null || transactions == null || budgets == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final monthlyTransactions = _transactionsForSelectedMonth(transactions);
    final summary = ref.watch(
      monthlyBudgetSummaryProvider(
        BudgetSummaryInput(
          categories: categories,
          transactions: monthlyTransactions,
          budgets: budgets,
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Ngân sách danh mục')),
      body: RefreshIndicator(
        onRefresh: () => _refreshBudgetData(
          householdId: householdId,
          budgetParams: budgetParams,
        ),
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                0,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _MonthSelector(
                    label: _monthFormat.format(_selectedMonth),
                    onPickMonth: _pickMonth,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _BudgetSummaryPanel(summary: summary),
                  const SizedBox(height: AppSpacing.md),
                  if (actionState.errorMessage case final errorMessage?) ...[
                    _BudgetErrorBanner(message: errorMessage),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  if (summary.categoryStatuses.isEmpty)
                    const _EmptyBudgetCategories(),
                ]),
              ),
            ),
            if (summary.categoryStatuses.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  96,
                ),
                sliver: SliverReorderableList(
                  itemCount: summary.categoryStatuses.length,
                  onReorder: (oldIndex, newIndex) => _onReorderBudgets(
                    oldIndex: oldIndex,
                    newIndex: newIndex,
                    statuses: summary.categoryStatuses,
                    householdId: householdId,
                  ),
                  itemBuilder: (context, index) {
                    final status = summary.categoryStatuses[index];
                    return Padding(
                      key: ValueKey(
                        'budget-${status.category.id}-${status.budget?.id ?? 'none'}',
                      ),
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _BudgetStatusTile(
                        index: index,
                        status: status,
                        enabled: !actionState.isLoading,
                        onEdit: () => _editBudget(
                          householdId: householdId,
                          status: status,
                        ),
                        onDelete: status.budget == null
                            ? null
                            : () => _deleteStatusBudget(status),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Transaction> _transactionsForSelectedMonth(
    List<Transaction> transactions,
  ) {
    return transactions.where((transaction) {
      final date = transaction.transactionDate;
      return date.year == _selectedMonth.year &&
          date.month == _selectedMonth.month;
    }).toList();
  }

  void _onReorderBudgets({
    required int oldIndex,
    required int newIndex,
    required List<CategoryBudgetStatus> statuses,
    required String householdId,
  }) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    if (oldIndex == newIndex) return;

    final reordered = List<CategoryBudgetStatus>.from(statuses);
    final item = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, item);

    // Build the list of budgets with updated display_order
    final updatedBudgets = <Budget>[];
    for (var i = 0; i < reordered.length; i++) {
      final budget = reordered[i].budget;
      if (budget != null) {
        updatedBudgets.add(budget.copyWith(displayOrder: i));
      }
    }

    if (updatedBudgets.isEmpty) return;

    ref.read(budgetActionProvider.notifier).reorderBudgets(updatedBudgets);
  }

  Future<void> _pickMonth() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2000),
      lastDate: DateTime(DateTime.now().year + 5, 12, 31),
      locale: AppConstants.vietnameseLocale,
      helpText: 'Chọn tháng ngân sách',
    );

    if (!mounted || selectedDate == null) {
      return;
    }

    _setLocalState(() {
      _selectedMonth = DateTime(selectedDate.year, selectedDate.month);
    });
  }

  Future<void> _editBudget({
    required String householdId,
    required CategoryBudgetStatus status,
  }) async {
    if (!mounted || status.category.id.trim().isEmpty) {
      return;
    }

    final amount = await showDialog<double>(
      context: context,
      builder: (_) => _BudgetAmountDialog(status: status),
    );
    if (!mounted || amount == null) {
      return;
    }

    final success = await ref
        .read(budgetActionProvider.notifier)
        .upsertBudget(
          householdId: householdId,
          categoryId: status.category.id,
          month: _selectedMonth.month,
          year: _selectedMonth.year,
          amount: amount,
        );
    if (!mounted) {
      return;
    }

    _showSnackBarAfterFrame(
      success
          ? 'Đã lưu ngân sách "${status.category.name}".'
          : ref.read(budgetActionProvider).errorMessage ??
                'Không thể lưu ngân sách.',
      isError: !success,
    );
  }

  Future<void> _deleteBudget(Budget budget) async {
    if (!mounted || budget.id.trim().isEmpty || budget.householdId.isEmpty) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Xóa ngân sách?'),
          content: const Text('Ngân sách danh mục trong tháng này sẽ bị xóa.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Hủy'),
            ),
            FilledButton.tonalIcon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Xóa'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) {
      return;
    }

    final success = await ref
        .read(budgetActionProvider.notifier)
        .deleteBudget(budget);
    if (!mounted) {
      return;
    }

    _showSnackBarAfterFrame(
      success
          ? 'Đã xóa ngân sách danh mục.'
          : ref.read(budgetActionProvider).errorMessage ??
                'Không thể xóa ngân sách.',
      isError: !success,
    );
  }

  Future<void> _deleteStatusBudget(CategoryBudgetStatus status) async {
    final budget = status.budget;
    if (budget == null) {
      return;
    }
    await _deleteBudget(budget);
  }

  Future<void> _refreshBudgetData({
    required String householdId,
    required BudgetMonthParams budgetParams,
  }) async {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref.invalidate(categoriesStreamProvider(householdId));
      ref.invalidate(transactionsStreamProvider(householdId));
      ref.invalidate(budgetsByMonthProvider(budgetParams));
    });
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }

  void _showSnackBarAfterFrame(String message, {required bool isError}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      AppFeedback.showSnackBar(message, isError: isError);
    });
  }

  void _setLocalState(VoidCallback update) {
    if (!mounted) {
      return;
    }
    setState(update);
  }
}

class _MonthSelector extends StatelessWidget {
  const _MonthSelector({required this.label, required this.onPickMonth});

  final String label;
  final VoidCallback onPickMonth;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.calendar_month_outlined),
        title: const Text('Tháng ngân sách'),
        subtitle: Text(label),
        trailing: IconButton.filledTonal(
          tooltip: 'Đổi tháng',
          onPressed: onPickMonth,
          icon: const Icon(Icons.edit_calendar_outlined),
        ),
      ),
    );
  }
}

class _BudgetSummaryPanel extends StatelessWidget {
  _BudgetSummaryPanel({required this.summary});

  final MonthlyBudgetSummary summary;
  final _currencyFormat = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: 'đ',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final ratio = summary.usedPercent.clamp(0.0, 1.0);
    final progressColor = summary.remainingBudget < 0
        ? colorScheme.error
        : ratio >= 0.8
        ? const Color(0xFFCA8A04)
        : const Color(0xFF0F8B6F);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tổng quan ngân sách',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: AppSpacing.md),
            _BudgetMetricGrid(
              metrics: [
                _BudgetMetricData(
                  label: 'Tổng ngân sách',
                  value: _currencyFormat.format(summary.totalBudget),
                ),
                _BudgetMetricData(
                  label: 'Đã chi',
                  value: _currencyFormat.format(summary.totalExpense),
                ),
                _BudgetMetricData(
                  label: 'Còn lại',
                  value: _currencyFormat.format(summary.remainingBudget),
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
              summary.totalBudget <= 0
                  ? 'Chưa đặt ngân sách cho tháng này.'
                  : 'Đã dùng ${(summary.usedPercent * 100).round()}% ngân sách.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetStatusTile extends StatelessWidget {
  _BudgetStatusTile({
    required this.index,
    required this.status,
    required this.enabled,
    required this.onEdit,
    required this.onDelete,
  });

  final int index;
  final CategoryBudgetStatus status;
  final bool enabled;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;
  final _currencyFormat = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: 'đ',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context) {
    final color = CategoryVisuals.colorFromHex(status.category.color);
    final progressColor = status.isOverBudget
        ? Theme.of(context).colorScheme.error
        : status.isNearLimit
        ? const Color(0xFFCA8A04)
        : color;
    final ratio = status.hasBudget ? status.usedPercent.clamp(0.0, 1.0) : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: const Icon(
                    Icons.drag_handle,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.14),
                  child: Icon(
                    CategoryVisuals.iconFromName(status.category.icon),
                    color: color,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        status.category.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(_statusText(status)),
                    ],
                  ),
                ),
                SizedBox(
                  width: 96,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        tooltip: status.hasBudget
                            ? 'Sửa ngân sách'
                            : 'Thêm ngân sách',
                        onPressed: enabled ? onEdit : null,
                        icon: Icon(
                          status.hasBudget
                              ? Icons.edit_outlined
                              : Icons.add_circle_outline,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Xóa ngân sách',
                        onPressed: enabled ? onDelete : null,
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _BudgetMetricGrid(
              metrics: [
                _BudgetMetricData(
                  label: 'Ngân sách',
                  value: status.hasBudget
                      ? _currencyFormat.format(status.budgetAmount)
                      : 'Chưa đặt',
                ),
                _BudgetMetricData(
                  label: 'Đã chi',
                  value: _currencyFormat.format(status.spentAmount),
                ),
                _BudgetMetricData(
                  label: 'Còn lại',
                  value: status.hasBudget
                      ? _currencyFormat.format(status.remainingAmount)
                      : '-',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: ratio,
                color: progressColor,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _statusText(CategoryBudgetStatus status) {
    if (!status.hasBudget) {
      return status.spentAmount > 0
          ? 'Chưa đặt ngân sách, đã có phát sinh chi.'
          : 'Chưa đặt ngân sách.';
    }
    if (status.isOverBudget) {
      return 'Vượt ngân sách ${_currencyFormat.format(status.spentAmount - status.budgetAmount)}';
    }
    if (status.isNearLimit) {
      return 'Sắp vượt ngân sách (${(status.usedPercent * 100).round()}%).';
    }
    return 'Bình thường (${(status.usedPercent * 100).round()}%).';
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
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}

class _BudgetMetricGrid extends StatelessWidget {
  const _BudgetMetricGrid({required this.metrics});

  final List<_BudgetMetricData> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final isWide = maxWidth.isFinite && maxWidth >= 360;
        final itemWidth = isWide
            ? (maxWidth - AppSpacing.sm * 2) / 3
            : maxWidth;

        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final metric in metrics)
              SizedBox(
                width: itemWidth,
                child: _BudgetMetric(label: metric.label, value: metric.value),
              ),
          ],
        );
      },
    );
  }
}

class _BudgetMetricData {
  const _BudgetMetricData({required this.label, required this.value});

  final String label;
  final String value;
}

class _BudgetAmountDialog extends StatefulWidget {
  const _BudgetAmountDialog({required this.status});

  final CategoryBudgetStatus status;

  @override
  State<_BudgetAmountDialog> createState() => _BudgetAmountDialogState();
}

class _BudgetAmountDialogState extends State<_BudgetAmountDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.status.hasBudget
          ? CurrencyInputFormatter.formatNumber(widget.status.budgetAmount)
          : '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.status.hasBudget ? 'Sửa ngân sách' : 'Thêm ngân sách'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          inputFormatters: const [CurrencyInputFormatter()],
          decoration: InputDecoration(
            labelText: widget.status.category.name,
            prefixIcon: const Icon(Icons.savings_outlined),
            suffixText: 'đ',
          ),
          validator: _validateAmount,
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Lưu'),
        ),
      ],
    );
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) {
      return;
    }
    final amount = _parseAmount(_controller.text);
    if (mounted) {
      Navigator.of(context).pop(amount);
    }
  }

  String? _validateAmount(String? value) {
    final amount = _parseAmount(value ?? '');
    if (amount == null) {
      return 'Vui lòng nhập ngân sách.';
    }
    if (amount < 0) {
      return 'Ngân sách phải lớn hơn hoặc bằng 0.';
    }
    return null;
  }

  double? _parseAmount(String value) {
    final digits = CurrencyInputFormatter.digitsOnly(value);
    if (digits.isEmpty) {
      return null;
    }
    return double.tryParse(digits);
  }
}

class _BudgetErrorBanner extends StatelessWidget {
  const _BudgetErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colorScheme.onErrorContainer),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyBudgetCategories extends StatelessWidget {
  const _EmptyBudgetCategories();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Text('Chưa có danh mục chi tiêu để đặt ngân sách.'),
      ),
    );
  }
}

class _BudgetLoadError extends StatelessWidget {
  const _BudgetLoadError({required this.onRetry});

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
              const Text('Không thể tải ngân sách. Vui lòng thử lại.'),
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
