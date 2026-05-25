import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/app_constants.dart';
import '../../../../core/models/models.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../shared/formatters/currency_input_formatter.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../categories/presentation/providers/category_provider.dart';
import '../../../categories/presentation/widgets/category_visuals.dart';
import '../providers/transaction_provider.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({this.transaction, super.key});

  final Transaction? transaction;

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _dateFormat = DateFormat('dd/MM/yyyy', 'vi_VN');

  late TransactionType _type;
  late DateTime _transactionDate;
  String? _selectedCategoryId;
  String? _categoryErrorMessage;

  bool get _isEditing => widget.transaction != null;

  @override
  void initState() {
    super.initState();

    final transaction = widget.transaction;
    _type = transaction?.type ?? TransactionType.expense;
    _transactionDate = transaction?.transactionDate ?? DateTime.now();
    _selectedCategoryId = transaction?.categoryId;

    if (transaction != null) {
      _amountController.text = CurrencyInputFormatter.formatNumber(
        transaction.amount,
      );
      _noteController.text = transaction.note ?? '';
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final actionState = ref.watch(transactionActionProvider);

    final householdId = ref.watch(currentHouseholdIdProvider);
    final userId = authState.user?.id ?? authState.profile?.id;
    final categoriesAsync = householdId == null
        ? const AsyncValue<List<Category>>.data([])
        : ref.watch(categoriesStreamProvider(householdId));

    debugPrint(
      'ADD TRANSACTION REALTIME UI: householdId=$householdId userId=$userId',
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Sửa giao dịch' : 'Thêm giao dịch'),
      ),
      resizeToAvoidBottomInset: true,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: FilledButton.icon(
            onPressed: actionState.isLoading || householdId == null || userId == null
                ? null
                : () => _submit(
                    householdId: householdId,
                    userId: userId,
                    categories: categoriesAsync.valueOrNull ?? const [],
                  ),
            icon: actionState.isLoading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(_isEditing ? Icons.save_outlined : Icons.check_circle_outline),
            label: Text(_isEditing ? 'Lưu thay đổi' : 'Lưu giao dịch'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
            ),
          ),
        ),
      ),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _FormLoadError(
          onRetry: householdId == null
              ? null
              : () => _retryCategories(householdId),
        ),
        data: (categories) {
          /// Lấy chiều cao bàn phím để form scroll khi keyboard mở
          final viewInsets = MediaQuery.viewInsetsOf(context);
          final theme = Theme.of(context);
          final colorScheme = theme.colorScheme;
          final typedCategories = categories
              .where((category) => category.type == _type)
              .toList();
          final selectedCategory = _selectedCategory(
            typedCategories,
            _selectedCategoryId,
          );

          if (_selectedCategoryId != null && selectedCategory == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _setLocalState(() => _selectedCategoryId = null);
            });
          }

          return Form(
            key: _formKey,
            child: GestureDetector(
              /// Ấn ra ngoài form → tắt bàn phím
              onTap: () {
                FocusScope.of(context).unfocus();
              },
              child: SingleChildScrollView(
                /// Cho phép scroll khi keyboard xuất hiện
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  /// Padding dưới cùng để tránh nội dung bị che bởi bàn phím
                  AppSpacing.xl + viewInsets.bottom,
                ),
                child: Column(
                  children: [
                if (actionState.errorMessage case final errorMessage?) ...[
                  _TransactionFormError(message: errorMessage),
                  const SizedBox(height: AppSpacing.md),
                ],
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Số tiền',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        TextFormField(
                          controller: _amountController,
                          enabled: !actionState.isLoading,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                          inputFormatters: const [CurrencyInputFormatter()],
                          decoration: InputDecoration(
                            hintText: '0',
                            suffixText: 'đ',
                            suffixStyle: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: colorScheme.onSurface,
                            height: 1.1,
                          ),
                          validator: _validateAmount,
                          onChanged: (_) {
                            ref.read(transactionActionProvider.notifier).clearError();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                SegmentedButton<TransactionType>(
                  segments: const [
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
                  selected: {_type},
                  onSelectionChanged: actionState.isLoading
                      ? null
                      : (selectedValues) {
                          _setLocalState(() {
                            _type = selectedValues.first;
                            _selectedCategoryId = null;
                            _categoryErrorMessage = null;
                          });
                          ref.read(transactionActionProvider.notifier).clearError();
                        },
                ),
                const SizedBox(height: AppSpacing.md),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Chọn danh mục ${_typeLabel(_type).toLowerCase()}',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (typedCategories.isEmpty)
                              TextButton.icon(
                                onPressed: actionState.isLoading
                                    ? null
                                    : () {
                                        if (context.mounted) {
                                          context.push(AppRoutes.categories);
                                        }
                                      },
                                icon: const Icon(Icons.add),
                                label: const Text('Tạo mới'),
                              ),
                          ],
                        ),
                        if (typedCategories.isEmpty) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Chưa có danh mục ${_typeLabel(_type).toLowerCase()}. Hãy tạo danh mục để tiếp tục.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: AppSpacing.sm),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final width = constraints.maxWidth;
                              final crossAxisCount = width >= 520
                                  ? 4
                                  : width >= 360
                                  ? 3
                                  : 2;

                              return GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: typedCategories.length,
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  mainAxisSpacing: AppSpacing.sm,
                                  crossAxisSpacing: AppSpacing.sm,
                                  childAspectRatio: 1.18,
                                ),
                                itemBuilder: (context, index) {
                                  final category = typedCategories[index];
                                  return _CategoryGridItem(
                                    category: category,
                                    selected: _selectedCategoryId == category.id,
                                    enabled: !actionState.isLoading,
                                    onTap: () {
                                      _setLocalState(() {
                                        _selectedCategoryId = category.id;
                                        _categoryErrorMessage = null;
                                      });
                                      ref
                                          .read(transactionActionProvider.notifier)
                                          .clearError();
                                    },
                                  );
                                },
                              );
                            },
                          ),
                          if (_categoryErrorMessage != null) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              _categoryErrorMessage!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _DatePickerCard(
                  label: _dateFormat.format(_transactionDate),
                  enabled: !actionState.isLoading,
                  onTap: _pickDate,
                ),
                const SizedBox(height: AppSpacing.md),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: TextFormField(
                      controller: _noteController,
                      enabled: !actionState.isLoading,
                      minLines: 3,
                      maxLines: 5,
                      maxLength: 240,
                      textInputAction: TextInputAction.newline,
                      decoration: const InputDecoration(
                        labelText: 'Ghi chú',
                        alignLabelWithHint: true,
                        hintText: 'Ví dụ: Mua đồ ăn cuối tuần',
                        border: InputBorder.none,
                        prefixIcon: Icon(Icons.notes_outlined),
                      ),
                      onChanged: (_) {
                        ref.read(transactionActionProvider.notifier).clearError();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
            ),
        );
      },
    ),
    );
  }

  Future<void> _pickDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _transactionDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: AppConstants.vietnameseLocale,
    );

    if (!mounted) {
      return;
    }

    if (selectedDate != null) {
      _setLocalState(() => _transactionDate = selectedDate);
    }
  }

  Future<void> _submit({
    required String householdId,
    required String userId,
    required List<Category> categories,
  }) async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }
    if (!mounted) {
      return;
    }

    if (_selectedCategoryId == null || _selectedCategoryId!.isEmpty) {
      _setLocalState(() {
        _categoryErrorMessage = 'Vui lòng chọn danh mục.';
      });
      return;
    }

    final typedCategories = categories
        .where((category) => category.type == _type)
        .toList();

    final category = _selectedCategory(typedCategories, _selectedCategoryId);
    if (category == null) {
      _setLocalState(() {
        _categoryErrorMessage = 'Danh mục đã chọn không hợp lệ. Vui lòng chọn lại.';
      });
      return;
    }

    FocusScope.of(context).unfocus();
    final router = GoRouter.of(context);
    final amount = _parseAmount(_amountController.text);
    if (amount == null) {
      return;
    }
    final note = _noteController.text;
    final notifier = ref.read(transactionActionProvider.notifier);
    final transaction = widget.transaction;

    final success = transaction == null
        ? await notifier.createTransaction(
            householdId: householdId,
            userId: userId,
            category: category,
            amount: amount,
            transactionDate: _transactionDate,
            note: note,
          )
        : await notifier.updateTransaction(
            transaction: transaction,
            category: category,
            amount: amount,
            transactionDate: _transactionDate,
            note: note,
          );

    if (success && mounted) {
      router.pop();
    }
  }

  String? _validateAmount(String? value) {
    final amount = _parseAmount(value ?? '');
    if (amount == null) {
      return 'Vui lòng nhập số tiền.';
    }
    if (amount <= 0) {
      return 'Số tiền phải lớn hơn 0.';
    }
    return null;
  }

  double? _parseAmount(String value) {
    final cleanValue = CurrencyInputFormatter.digitsOnly(value);
    if (cleanValue.isEmpty) {
      return null;
    }
    return double.tryParse(cleanValue);
  }

  void _retryCategories(String householdId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref.invalidate(categoriesStreamProvider(householdId));
    });
  }

  void _setLocalState(VoidCallback update) {
    if (!mounted) {
      return;
    }
    setState(update);
  }
}

class _DatePickerField extends StatelessWidget {
  const _DatePickerField({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Ngày',
          prefixIcon: Icon(Icons.calendar_today_outlined),
          suffixIcon: Icon(Icons.expand_more),
        ),
        child: Text(label),
      ),
    );
  }
}

class _DatePickerCard extends StatelessWidget {
  const _DatePickerCard({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: _DatePickerField(
          label: label,
          enabled: enabled,
          onTap: onTap,
        ),
      ),
    );
  }
}

class _TransactionFormError extends StatelessWidget {
  const _TransactionFormError({required this.message});

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
        crossAxisAlignment: CrossAxisAlignment.start,
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

class _CategoryGridItem extends StatelessWidget {
  const _CategoryGridItem({
    required this.category,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final Category category;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = CategoryVisuals.colorFromHex(category.color);
    final icon = CategoryVisuals.iconFromName(category.icon);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.14)
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.36),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? color : colorScheme.outlineVariant,
              width: selected ? 1.8 : 1,
            ),
          ),
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: AnimatedOpacity(
                  opacity: selected ? 1 : 0,
                  duration: const Duration(milliseconds: 160),
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, size: 12, color: Colors.white),
                  ),
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: color.withValues(alpha: 0.18),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    category.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormLoadError extends StatelessWidget {
  const _FormLoadError({required this.onRetry});

  final VoidCallback? onRetry;

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
            const Text('Không thể tải danh mục. Vui lòng thử lại.'),
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

Category? _selectedCategory(List<Category> categories, String? categoryId) {
  if (categoryId == null) {
    return null;
  }

  for (final category in categories) {
    if (category.id == categoryId) {
      return category;
    }
  }
  return null;
}

String _typeLabel(TransactionType type) {
  switch (type) {
    case TransactionType.income:
      return 'Thu';
    case TransactionType.expense:
      return 'Chi';
  }
}
