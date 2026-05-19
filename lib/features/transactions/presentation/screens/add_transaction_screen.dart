import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/app_constants.dart';
import '../../../../core/models/models.dart';
import '../../../../core/router/app_routes.dart';
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

  bool get _isEditing => widget.transaction != null;

  @override
  void initState() {
    super.initState();

    final transaction = widget.transaction;
    _type = transaction?.type ?? TransactionType.expense;
    _transactionDate = transaction?.transactionDate ?? DateTime.now();
    _selectedCategoryId = transaction?.categoryId;

    if (transaction != null) {
      _amountController.text = transaction.amount.round().toString();
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
    final categoriesAsync = ref.watch(categoryListProvider);
    final actionState = ref.watch(transactionActionProvider);

    final householdId = authState.profile?.householdId;
    final userId = authState.user?.id ?? authState.profile?.id;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Sửa giao dịch' : 'Thêm giao dịch'),
      ),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            _FormLoadError(onRetry: () => ref.invalidate(categoryListProvider)),
        data: (categories) {
          final typedCategories = categories
              .where((category) => category.type == _type)
              .toList();
          final selectedCategory = _selectedCategory(
            typedCategories,
            _selectedCategoryId,
          );

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                if (actionState.errorMessage != null) ...[
                  _TransactionFormError(message: actionState.errorMessage!),
                  const SizedBox(height: AppSpacing.md),
                ],
                TextFormField(
                  controller: _amountController,
                  enabled: !actionState.isLoading,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(12),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Số tiền',
                    prefixIcon: Icon(Icons.payments_outlined),
                    suffixText: 'đ',
                  ),
                  validator: _validateAmount,
                  onChanged: (_) {
                    ref.read(transactionActionProvider.notifier).clearError();
                  },
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
                          });
                          ref
                              .read(transactionActionProvider.notifier)
                              .clearError();
                        },
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  key: ValueKey('${_type.value}-${selectedCategory?.id}'),
                  initialValue: selectedCategory?.id,
                  items: [
                    for (final category in typedCategories)
                      DropdownMenuItem(
                        value: category.id,
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: CategoryVisuals.colorFromHex(
                                category.color,
                              ).withValues(alpha: 0.14),
                              child: Icon(
                                CategoryVisuals.iconFromName(category.icon),
                                size: 16,
                                color: CategoryVisuals.colorFromHex(
                                  category.color,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(child: Text(category.name)),
                          ],
                        ),
                      ),
                  ],
                  onChanged: actionState.isLoading
                      ? null
                      : (value) {
                          _setLocalState(() => _selectedCategoryId = value);
                          ref
                              .read(transactionActionProvider.notifier)
                              .clearError();
                        },
                  decoration: InputDecoration(
                    labelText: 'Danh mục',
                    prefixIcon: const Icon(Icons.category_outlined),
                    helperText: typedCategories.isEmpty
                        ? 'Chưa có danh mục ${_typeLabel(_type).toLowerCase()}'
                        : null,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Vui lòng chọn danh mục.';
                    }
                    return null;
                  },
                ),
                if (typedCategories.isEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: actionState.isLoading
                          ? null
                          : () => context.push(AppRoutes.categories),
                      icon: const Icon(Icons.add),
                      label: const Text('Tạo danh mục'),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                _DatePickerField(
                  label: _dateFormat.format(_transactionDate),
                  enabled: !actionState.isLoading,
                  onTap: _pickDate,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _noteController,
                  enabled: !actionState.isLoading,
                  minLines: 3,
                  maxLines: 5,
                  maxLength: 240,
                  textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration(
                    labelText: 'Ghi chú',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                  onChanged: (_) {
                    ref.read(transactionActionProvider.notifier).clearError();
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  onPressed:
                      actionState.isLoading ||
                          householdId == null ||
                          userId == null
                      ? null
                      : () => _submit(
                          householdId: householdId,
                          userId: userId,
                          categories: typedCategories,
                        ),
                  icon: actionState.isLoading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(_isEditing ? Icons.save_outlined : Icons.add),
                  label: Text(_isEditing ? 'Lưu giao dịch' : 'Thêm giao dịch'),
                ),
              ],
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
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (!mounted) {
      return;
    }

    final category = _selectedCategory(categories, _selectedCategoryId);
    if (category == null) {
      return;
    }

    FocusScope.of(context).unfocus();
    final router = GoRouter.of(context);
    final amount = _parseAmount(_amountController.text)!;
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
    final cleanValue = value.trim();
    if (cleanValue.isEmpty) {
      return null;
    }
    return double.tryParse(cleanValue);
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

class _FormLoadError extends StatelessWidget {
  const _FormLoadError({required this.onRetry});

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
