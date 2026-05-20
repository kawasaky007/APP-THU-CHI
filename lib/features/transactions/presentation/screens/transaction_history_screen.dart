import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/app_constants.dart';
import '../../../../core/models/models.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../shared/widgets/app_feedback.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../categories/presentation/providers/category_provider.dart';
import '../../../categories/presentation/widgets/category_visuals.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../models/transaction_view_data.dart';
import '../providers/transaction_provider.dart';

class TransactionHistoryScreen extends ConsumerStatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  ConsumerState<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState
    extends ConsumerState<TransactionHistoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late DateTime _selectedMonth;

  final _currencyFormat = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: 'đ',
    decimalDigits: 0,
  );
  final _monthFormat = DateFormat('MM/yyyy', 'vi_VN');

  // Pagination state for "Tất cả" tab
  static const _pageSize = 30;
  final List<Transaction> _allTransactions = [];
  bool _isLoadingMore = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
    _tabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging && _tabController.index == 1) {
      if (_allTransactions.isEmpty && !_isLoadingMore) {
        _loadFirstPage();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final householdId = ref.watch(currentHouseholdIdProvider);

    if (householdId == null) {
      return const Scaffold(
        body: Center(child: Text('Bạn chưa tham gia household nào.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử giao dịch'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Theo tháng'),
            Tab(text: 'Tất cả'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _MonthlyTab(
            householdId: householdId,
            selectedMonth: _selectedMonth,
            currencyFormat: _currencyFormat,
            monthFormat: _monthFormat,
            onPreviousMonth: _goToPreviousMonth,
            onNextMonth: _goToNextMonth,
            onPickMonth: _pickMonth,
          ),
          _AllTransactionsTab(
            householdId: householdId,
            transactions: _allTransactions,
            isLoadingMore: _isLoadingMore,
            hasMore: _hasMore,
            onLoadMore: _loadMore,
            onRefresh: _refreshAll,
            currencyFormat: _currencyFormat,
          ),
        ],
      ),
    );
  }

  void _goToPreviousMonth() {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month - 1,
      );
    });
  }

  void _goToNextMonth() {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + 1,
      );
    });
  }

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1, 12, 31),
      locale: AppConstants.vietnameseLocale,
      helpText: 'Chọn tháng',
    );

    if (!mounted || selectedDate == null) return;

    setState(() {
      _selectedMonth = DateTime(selectedDate.year, selectedDate.month);
    });
  }

  Future<void> _loadFirstPage() async {
    final householdId = ref.read(currentHouseholdIdProvider);
    if (householdId == null) return;

    setState(() {
      _isLoadingMore = true;
      _allTransactions.clear();
      _hasMore = true;
    });

    try {
      final transactions = await ref
          .read(transactionRepositoryProvider)
          .fetchTransactionsPage(
            householdId: householdId,
            limit: _pageSize,
            offset: 0,
          );

      if (!mounted) return;
      setState(() {
        _allTransactions.addAll(transactions);
        _hasMore = transactions.length >= _pageSize;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
      AppFeedback.showSnackBar(
        'Không thể tải giao dịch. Vui lòng thử lại.',
        isError: true,
      );
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;

    final householdId = ref.read(currentHouseholdIdProvider);
    if (householdId == null) return;

    setState(() => _isLoadingMore = true);

    try {
      final transactions = await ref
          .read(transactionRepositoryProvider)
          .fetchTransactionsPage(
            householdId: householdId,
            limit: _pageSize,
            offset: _allTransactions.length,
          );

      if (!mounted) return;
      setState(() {
        _allTransactions.addAll(transactions);
        _hasMore = transactions.length >= _pageSize;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
      AppFeedback.showSnackBar(
        'Không thể tải thêm giao dịch.',
        isError: true,
      );
    }
  }

  Future<void> _refreshAll() async {
    final householdId = ref.read(currentHouseholdIdProvider);
    if (householdId == null) return;

    setState(() {
      _allTransactions.clear();
      _hasMore = true;
    });

    await _loadFirstPage();
  }
}

// ---------------------------------------------------------------------------
// Monthly Tab (Realtime)
// ---------------------------------------------------------------------------

class _MonthlyTab extends ConsumerWidget {
  const _MonthlyTab({
    required this.householdId,
    required this.selectedMonth,
    required this.currencyFormat,
    required this.monthFormat,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onPickMonth,
  });

  final String householdId;
  final DateTime selectedMonth;
  final NumberFormat currencyFormat;
  final DateFormat monthFormat;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onPickMonth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = TransactionMonthParams(
      householdId: householdId,
      month: selectedMonth,
    );
    final transactionsAsync = ref.watch(
      transactionsByMonthStreamProvider(params),
    );
    final categoriesAsync = ref.watch(categoriesStreamProvider(householdId));
    final categories = categoriesAsync.valueOrNull ?? const <Category>[];
    final profilesById = ref.watch(profilesByIdProvider(householdId));
    final currentUserId = ref.watch(currentUserIdProvider) ?? '';

    return Column(
      children: [
        _MonthNavigationBar(
          selectedMonth: selectedMonth,
          monthFormat: monthFormat,
          onPrevious: onPreviousMonth,
          onNext: onNextMonth,
          onPickMonth: onPickMonth,
        ),
        Expanded(
          child: transactionsAsync.when(
            skipLoadingOnRefresh: true,
            skipLoadingOnReload: true,
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => _HistoryErrorView(
              onRetry: () => ref.invalidate(
                transactionsByMonthStreamProvider(params),
              ),
            ),
            data: (transactions) {
              final visibleTransactions = transactions
                  .where(_hasStableTransactionId)
                  .toList();
              final summary = _HistorySummary.from(visibleTransactions);

              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(transactionsByMonthStreamProvider(params));
                  await Future<void>.delayed(
                    const Duration(milliseconds: 250),
                  );
                },
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          AppSpacing.md,
                          AppSpacing.md,
                          AppSpacing.sm,
                        ),
                        child: _MonthlySummaryCard(
                          income: summary.income,
                          expense: summary.expense,
                          balance: summary.income - summary.expense,
                          currencyFormat: currencyFormat,
                        ),
                      ),
                    ),
                    if (visibleTransactions.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _EmptyMonthView(onPickMonth: onPickMonth),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          0,
                          AppSpacing.md,
                          96,
                        ),
                        sliver: SliverList.separated(
                          itemCount: visibleTransactions.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (context, index) {
                            final transaction = visibleTransactions[index];
                            final category = _findCategory(
                              categories,
                              transaction.categoryId,
                            );
                            final creatorName =
                                TransactionViewData.resolveCreatorName(
                              creatorUserId: transaction.userId,
                              currentUserId: currentUserId,
                              profilesById: profilesById,
                            );
                            return _TransactionHistoryTile(
                              key: ValueKey(transaction.id.trim()),
                              transaction: transaction,
                              category: category,
                              householdId: householdId,
                              creatorName: creatorName,
                            );
                          },
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// All Transactions Tab (Pagination)
// ---------------------------------------------------------------------------

class _AllTransactionsTab extends ConsumerWidget {
  const _AllTransactionsTab({
    required this.householdId,
    required this.transactions,
    required this.isLoadingMore,
    required this.hasMore,
    required this.onLoadMore,
    required this.onRefresh,
    required this.currencyFormat,
  });

  final String householdId;
  final List<Transaction> transactions;
  final bool isLoadingMore;
  final bool hasMore;
  final VoidCallback onLoadMore;
  final Future<void> Function() onRefresh;
  final NumberFormat currencyFormat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesStreamProvider(householdId));
    final categories = categoriesAsync.valueOrNull ?? const <Category>[];
    final profilesById = ref.watch(profilesByIdProvider(householdId));
    final currentUserId = ref.watch(currentUserIdProvider) ?? '';

    if (transactions.isEmpty && isLoadingMore) {
      return const Center(child: CircularProgressIndicator());
    }

    if (transactions.isEmpty && !isLoadingMore) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: AppSpacing.md),
            const Text('Chưa có giao dịch nào'),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: onLoadMore,
              icon: const Icon(Icons.refresh),
              label: const Text('Tải lại'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: NotificationListener<ScrollNotification>(
        onNotification: (scrollNotification) {
          if (scrollNotification is ScrollEndNotification &&
              scrollNotification.metrics.extentAfter < 200 &&
              hasMore &&
              !isLoadingMore) {
            onLoadMore();
          }
          return false;
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                0,
              ),
              sliver: SliverList.separated(
                itemCount: transactions.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final transaction = transactions[index];
                  final category = _findCategory(
                    categories,
                    transaction.categoryId,
                  );
                  final creatorName =
                      TransactionViewData.resolveCreatorName(
                    creatorUserId: transaction.userId,
                    currentUserId: currentUserId,
                    profilesById: profilesById,
                  );
                  return _TransactionHistoryTile(
                    key: ValueKey(transaction.id.trim()),
                    transaction: transaction,
                    category: category,
                    householdId: householdId,
                    creatorName: creatorName,
                  );
                },
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: isLoadingMore
                    ? const Center(child: CircularProgressIndicator())
                    : hasMore
                        ? Center(
                            child: OutlinedButton(
                              onPressed: onLoadMore,
                              child: const Text('Tải thêm'),
                            ),
                          )
                        : Center(
                            child: Text(
                              'Đã hiển thị tất cả ${transactions.length} giao dịch',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared Widgets
// ---------------------------------------------------------------------------

class _MonthNavigationBar extends StatelessWidget {
  const _MonthNavigationBar({
    required this.selectedMonth,
    required this.monthFormat,
    required this.onPrevious,
    required this.onNext,
    required this.onPickMonth,
  });

  final DateTime selectedMonth;
  final DateFormat monthFormat;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPickMonth;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Tháng trước',
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: GestureDetector(
              onTap: onPickMonth,
              child: Text(
                'Tháng ${monthFormat.format(selectedMonth)}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Tháng sau',
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

class _MonthlySummaryCard extends StatelessWidget {
  const _MonthlySummaryCard({
    required this.income,
    required this.expense,
    required this.balance,
    required this.currencyFormat,
  });

  final double income;
  final double expense;
  final double balance;
  final NumberFormat currencyFormat;

  @override
  Widget build(BuildContext context) {
    final balanceColor = balance >= 0
        ? const Color(0xFF0F8B6F)
        : Theme.of(context).colorScheme.error;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _SummaryMetric(
                    label: 'Thu',
                    value: '+${currencyFormat.format(income)}',
                    color: const Color(0xFF0F8B6F),
                    icon: Icons.trending_up,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _SummaryMetric(
                    label: 'Chi',
                    value: '-${currencyFormat.format(expense)}',
                    color: const Color(0xFFC2410C),
                    icon: Icons.trending_down,
                  ),
                ),
              ],
            ),
            const Divider(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.account_balance_wallet_outlined,
                    color: balanceColor, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Số dư: ${currencyFormat.format(balance)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: balanceColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TransactionHistoryTile extends ConsumerWidget {
  _TransactionHistoryTile({
    super.key,
    required this.transaction,
    required this.category,
    required this.householdId,
    required this.creatorName,
  });

  final Transaction transaction;
  final Category? category;
  final String householdId;
  final String creatorName;

  final _currencyFormat = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: 'đ',
    decimalDigits: 0,
  );
  final _dateFormat = DateFormat('dd/MM/yyyy', 'vi_VN');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category = this.category;
    final color = category == null
        ? CategoryVisuals.toneForType(transaction.type)
        : CategoryVisuals.colorFromHex(category.color);
    final icon = category == null
        ? Icons.category_outlined
        : CategoryVisuals.iconFromName(category.icon);
    final prefix = transaction.type == TransactionType.income ? '+' : '-';
    final amountColor = transaction.type == TransactionType.income
        ? const Color(0xFF0F8B6F)
        : const Color(0xFFC2410C);
    final note = transaction.note?.trim();
    final textTheme = Theme.of(context).textTheme;

    return Card(
      key: ValueKey(transaction.id),
      elevation: 0,
      color: const Color(0xFFFAFCFA),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(
            alpha: 0.5,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category?.name ?? transaction.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_dateFormat.format(transaction.transactionDate)} · $creatorName',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (note != null && note.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      note,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: Text(
                    '$prefix${_currencyFormat.format(transaction.amount)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: amountColor,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 32,
                  width: 32,
                  child: PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    iconSize: 18,
                    icon: Icon(
                      Icons.more_vert,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    onSelected: (value) {
                      if (value == 'edit') {
                        _editTransaction(context);
                      } else if (value == 'delete') {
                        _confirmDelete(context, ref);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit_outlined, size: 18),
                            SizedBox(width: 8),
                            Text('Sửa'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.delete_outline, size: 18),
                            SizedBox(width: 8),
                            Text('Xóa'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _editTransaction(BuildContext context) {
    if (!context.mounted || transaction.id.trim().isEmpty) return;
    context.push(AppRoutes.editTransaction, extra: transaction);
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final transactionId = transaction.id.trim();
    if (!context.mounted) return;
    if (transactionId.isEmpty || householdId.trim().isEmpty) {
      AppFeedback.showSnackBar(
        'Không thể xóa giao dịch vì thiếu dữ liệu định danh.',
        isError: true,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Xóa giao dịch?'),
          content: const Text(
            'Giao dịch này sẽ bị xóa khỏi household hiện tại.',
          ),
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

    if (!context.mounted || confirmed != true) return;

    final success = await ref
        .read(transactionActionProvider.notifier)
        .deleteTransaction(
          transactionId: transactionId,
          householdId: householdId,
        );

    if (!context.mounted) return;

    final message = success
        ? 'Đã xóa giao dịch.'
        : ref.read(transactionActionProvider).errorMessage ??
              'Không thể xóa giao dịch.';

    AppFeedback.showSnackBar(message, isError: !success);
  }
}

class _EmptyMonthView extends StatelessWidget {
  const _EmptyMonthView({required this.onPickMonth});

  final VoidCallback onPickMonth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Chưa có giao dịch trong tháng này',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: onPickMonth,
              icon: const Icon(Icons.calendar_month_outlined),
              label: const Text('Chọn tháng khác'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryErrorView extends StatelessWidget {
  const _HistoryErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
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
            const Text('Không thể tải lịch sử giao dịch.'),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistorySummary {
  const _HistorySummary({required this.income, required this.expense});

  final double income;
  final double expense;

  factory _HistorySummary.from(List<Transaction> transactions) {
    var income = 0.0;
    var expense = 0.0;

    for (final transaction in transactions) {
      if (transaction.type == TransactionType.income) {
        income += transaction.amount;
      } else {
        expense += transaction.amount;
      }
    }

    return _HistorySummary(income: income, expense: expense);
  }
}

bool _hasStableTransactionId(Transaction transaction) {
  return transaction.id.trim().isNotEmpty;
}

Category? _findCategory(List<Category> categories, String categoryId) {
  for (final category in categories) {
    if (category.id == categoryId) {
      return category;
    }
  }
  return null;
}
