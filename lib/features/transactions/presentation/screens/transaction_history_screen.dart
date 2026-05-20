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
import '../providers/transaction_provider.dart';

class TransactionHistoryScreen extends ConsumerStatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  ConsumerState<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState
    extends ConsumerState<TransactionHistoryScreen> {
  static const _allCategoryValue = '__all_categories__';

  final _searchController = TextEditingController();
  final _currencyFormat = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: 'đ',
    decimalDigits: 0,
  );

  DateTime? _selectedMonth;
  TransactionType? _selectedType;
  String? _selectedCategoryId;
  String _searchQuery = '';

  bool get _hasActiveFilters =>
      _selectedMonth != null ||
      _selectedType != null ||
      _selectedCategoryId != null ||
      _searchQuery.trim().isNotEmpty;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final householdId = ref.watch(currentHouseholdIdProvider);
    final userId = authState.user?.id ?? authState.profile?.id;

    if (householdId == null) {
      return const Scaffold(
        body: Center(child: Text('Bạn chưa tham gia household nào.')),
      );
    }

    debugPrint('HISTORY REALTIME UI: householdId=$householdId userId=$userId');
    final transactionsAsync = ref.watch(
      transactionsStreamProvider(householdId),
    );
    final categoriesAsync = ref.watch(categoriesStreamProvider(householdId));
    final categories = categoriesAsync.valueOrNull ?? const <Category>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử giao dịch'),
        actions: [
          if (_hasActiveFilters)
            IconButton(
              tooltip: 'Xóa bộ lọc',
              onPressed: _clearFilters,
              icon: const Icon(Icons.filter_alt_off_outlined),
            ),
        ],
      ),
      body: transactionsAsync.when(
        skipLoadingOnRefresh: true,
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) {
          return _HistoryErrorView(onRetry: () => _refresh(householdId));
        },
        data: (transactions) {
          final availableCategories = _availableCategories(categories);
          final effectiveCategoryId = _effectiveCategoryId(availableCategories);
          final filteredTransactions = _filterTransactions(
            transactions,
            effectiveCategoryId: effectiveCategoryId,
          );
          final visibleTransactions = filteredTransactions
              .where(_hasStableTransactionId)
              .toList();
          final summary = _HistorySummary.from(visibleTransactions);

          return RefreshIndicator(
            onRefresh: () => _refresh(householdId),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SearchField(
                          controller: _searchController,
                          onChanged: (value) {
                            _setLocalState(() => _searchQuery = value);
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _FilterPanel(
                          selectedMonth: _selectedMonth,
                          selectedType: _selectedType,
                          selectedCategoryId: effectiveCategoryId,
                          categories: availableCategories,
                          onPickMonth: _pickMonth,
                          onClearMonth: () {
                            _setLocalState(() => _selectedMonth = null);
                          },
                          onTypeChanged: (type) {
                            _setLocalState(() {
                              _selectedType = type;
                              _selectedCategoryId = null;
                            });
                          },
                          onCategoryChanged: (categoryId) {
                            _setLocalState(() {
                              _selectedCategoryId =
                                  categoryId == _allCategoryValue
                                  ? null
                                  : categoryId;
                            });
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _SummaryStrip(
                          count: visibleTransactions.length,
                          income: summary.income,
                          expense: summary.expense,
                          currencyFormat: _currencyFormat,
                        ),
                      ],
                    ),
                  ),
                ),
                if (visibleTransactions.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyHistoryView(
                      hasFilters: _hasActiveFilters,
                      onClearFilters: _clearFilters,
                    ),
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
                        final transactionId = transaction.id.trim();

                        return _TransactionHistoryTile(
                          key: ValueKey(transactionId),
                          transaction: transaction,
                          category: category,
                          onEdit: () => _editTransaction(transaction),
                          onDelete: () => _confirmDelete(
                            transactionId: transactionId,
                            householdId: householdId,
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Category> _availableCategories(List<Category> categories) {
    final filteredCategories = _selectedType == null
        ? [...categories]
        : categories
              .where((category) => category.type == _selectedType)
              .toList();

    filteredCategories.sort((a, b) {
      final typeCompare = a.type.index.compareTo(b.type.index);
      if (typeCompare != 0) {
        return typeCompare;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return filteredCategories;
  }

  String? _effectiveCategoryId(List<Category> availableCategories) {
    final categoryId = _selectedCategoryId;
    if (categoryId == null) {
      return null;
    }

    final stillAvailable = availableCategories.any(
      (category) => category.id == categoryId,
    );
    return stillAvailable ? categoryId : null;
  }

  List<Transaction> _filterTransactions(
    List<Transaction> transactions, {
    required String? effectiveCategoryId,
  }) {
    final query = _searchQuery.trim().toLowerCase();

    return transactions.where((transaction) {
      final selectedMonth = _selectedMonth;
      if (selectedMonth != null &&
          !_isSameMonth(transaction.transactionDate, selectedMonth)) {
        return false;
      }

      final selectedType = _selectedType;
      if (selectedType != null && transaction.type != selectedType) {
        return false;
      }

      if (effectiveCategoryId != null &&
          transaction.categoryId != effectiveCategoryId) {
        return false;
      }

      if (query.isNotEmpty) {
        final note = transaction.note?.toLowerCase() ?? '';
        if (!note.contains(query)) {
          return false;
        }
      }

      return true;
    }).toList()..sort(_compareTransactionNewestFirst);
  }

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    final initialDate = _selectedMonth ?? now;

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1, 12, 31),
      locale: AppConstants.vietnameseLocale,
      helpText: 'Chọn tháng',
    );

    if (!mounted) {
      return;
    }

    if (selectedDate != null) {
      _setLocalState(() {
        _selectedMonth = DateTime(selectedDate.year, selectedDate.month);
      });
    }
  }

  void _editTransaction(Transaction transaction) {
    if (!mounted || transaction.id.trim().isEmpty) {
      return;
    }

    context.push(AppRoutes.editTransaction, extra: transaction);
  }

  Future<void> _refresh(String householdId) async {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref.invalidate(transactionsStreamProvider(householdId));
      ref.invalidate(categoriesStreamProvider(householdId));
    });
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }

  void _clearFilters() {
    if (!mounted) {
      return;
    }

    _searchController.clear();
    _setLocalState(() {
      _selectedMonth = null;
      _selectedType = null;
      _selectedCategoryId = null;
      _searchQuery = '';
    });
  }

  Future<void> _confirmDelete({
    required String transactionId,
    required String householdId,
  }) async {
    if (!mounted) {
      return;
    }
    if (transactionId.trim().isEmpty || householdId.trim().isEmpty) {
      _showSnackBarAfterFrame(
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

    if (!mounted || confirmed != true) {
      return;
    }

    final success = await ref
        .read(transactionActionProvider.notifier)
        .deleteTransaction(
          transactionId: transactionId,
          householdId: householdId,
        );
    if (!mounted) {
      return;
    }

    final message = success
        ? 'Đã xóa giao dịch.'
        : ref.read(transactionActionProvider).errorMessage ??
              'Không thể xóa giao dịch.';

    if (success) {
      _invalidateTransactionsAfterFrame(householdId);
    }
    _showSnackBarAfterFrame(message, isError: !success);
  }

  void _invalidateTransactionsAfterFrame(String householdId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      Future<void>.delayed(const Duration(milliseconds: 120), () {
        if (!mounted) {
          return;
        }
        ref.invalidate(transactionsStreamProvider(householdId));
      });
    });
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

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      decoration: const InputDecoration(
        labelText: 'Tìm kiếm theo ghi chú',
        prefixIcon: Icon(Icons.search),
      ),
      onChanged: onChanged,
    );
  }
}

class _FilterPanel extends StatelessWidget {
  const _FilterPanel({
    required this.selectedMonth,
    required this.selectedType,
    required this.selectedCategoryId,
    required this.categories,
    required this.onPickMonth,
    required this.onClearMonth,
    required this.onTypeChanged,
    required this.onCategoryChanged,
  });

  final DateTime? selectedMonth;
  final TransactionType? selectedType;
  final String? selectedCategoryId;
  final List<Category> categories;
  final VoidCallback onPickMonth;
  final VoidCallback onClearMonth;
  final ValueChanged<TransactionType?> onTypeChanged;
  final ValueChanged<String?> onCategoryChanged;

  @override
  Widget build(BuildContext context) {
    final monthFormat = DateFormat('MM/yyyy', 'vi_VN');
    final selectedMonth = this.selectedMonth;
    final selectedMonthLabel = selectedMonth == null
        ? 'Tất cả tháng'
        : monthFormat.format(selectedMonth);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: onPickMonth,
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text(selectedMonthLabel),
                ),
                if (selectedMonth != null)
                  IconButton.outlined(
                    tooltip: 'Bỏ lọc tháng',
                    onPressed: onClearMonth,
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            SegmentedButton<TransactionType?>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: null, label: Text('Tất cả')),
                ButtonSegment(
                  value: TransactionType.expense,
                  icon: Icon(Icons.trending_down),
                  label: Text('Chi'),
                ),
                ButtonSegment(
                  value: TransactionType.income,
                  icon: Icon(Icons.trending_up),
                  label: Text('Thu'),
                ),
              ],
              selected: {selectedType},
              onSelectionChanged: (selectedValues) {
                onTypeChanged(selectedValues.first);
              },
            ),
            const SizedBox(height: AppSpacing.md),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Danh mục',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value:
                      selectedCategoryId ??
                      _TransactionHistoryScreenState._allCategoryValue,
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem(
                      value: _TransactionHistoryScreenState._allCategoryValue,
                      child: Text('Tất cả danh mục'),
                    ),
                    for (final category in categories)
                      DropdownMenuItem(
                        value: category.id,
                        child: _CategoryFilterDropdownLabel(category: category),
                      ),
                  ],
                  onChanged: onCategoryChanged,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({
    required this.count,
    required this.income,
    required this.expense,
    required this.currencyFormat,
  });

  final int count;
  final double income;
  final double expense;
  final NumberFormat currencyFormat;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryChip(
            label: '$count giao dịch',
            icon: Icons.receipt_long_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _SummaryChip(
            label: '+${currencyFormat.format(income)}',
            icon: Icons.trending_up,
            color: const Color(0xFF0F8B6F),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _SummaryChip(
            label: '-${currencyFormat.format(expense)}',
            icon: Icons.trending_down,
            color: const Color(0xFFC2410C),
          ),
        ),
      ],
    );
  }
}

class _CategoryFilterDropdownLabel extends StatelessWidget {
  const _CategoryFilterDropdownLabel({required this.category});

  final Category category;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          CategoryVisuals.iconFromName(category.icon),
          color: CategoryVisuals.colorFromHex(category.color),
          size: 20,
        ),
        const SizedBox(width: AppSpacing.sm),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: Text(
            category.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color.withValues(alpha: 0.22)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionHistoryTile extends StatelessWidget {
  _TransactionHistoryTile({
    super.key,
    required this.transaction,
    required this.category,
    required this.onEdit,
    required this.onDelete,
  });

  final Transaction transaction;
  final Category? category;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

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
    final note = transaction.note?.trim();

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.14),
          child: Icon(icon, color: color),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                category?.name ?? transaction.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '$prefix${_currencyFormat.format(transaction.amount)}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_dateFormat.format(transaction.transactionDate)),
              if (note != null && note.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(note, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ],
          ),
        ),
        trailing: SizedBox(
          width: 96,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                tooltip: 'Sửa giao dịch',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'Xóa giao dịch',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyHistoryView extends StatelessWidget {
  const _EmptyHistoryView({
    required this.hasFilters,
    required this.onClearFilters,
  });

  final bool hasFilters;
  final VoidCallback onClearFilters;

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
              hasFilters
                  ? 'Không có giao dịch phù hợp'
                  : 'Chưa có giao dịch nào',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (hasFilters)
              OutlinedButton.icon(
                onPressed: onClearFilters,
                icon: const Icon(Icons.filter_alt_off_outlined),
                label: const Text('Xóa bộ lọc'),
              )
            else
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
      ),
    );
  }
}

class _HistoryErrorView extends StatelessWidget {
  const _HistoryErrorView({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRetry,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.24),
          Icon(
            Icons.cloud_off_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: AppSpacing.md),
          const Center(child: Text('Không thể tải lịch sử giao dịch.')),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
            ),
          ),
        ],
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

bool _isSameMonth(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month;
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

Category? _findCategory(List<Category> categories, String categoryId) {
  for (final category in categories) {
    if (category.id == categoryId) {
      return category;
    }
  }
  return null;
}

bool _hasStableTransactionId(Transaction transaction) {
  return transaction.id.trim().isNotEmpty;
}
