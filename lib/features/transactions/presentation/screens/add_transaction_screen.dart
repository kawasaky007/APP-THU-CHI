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
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../data/amount_calculator_service.dart';
import '../providers/transaction_provider.dart';
import '../widgets/amount_expression_input.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({this.transaction, super.key});

  final Transaction? transaction;

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  static const _collapsedCategoryLimit = 9;

  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _dateFormat = DateFormat('dd/MM/yyyy', 'vi_VN');

  late TransactionType _type;
  late DateTime _transactionDate;
  String? _selectedCategoryId;
  String? _selectedMemberId;
  String? _categoryErrorMessage;
  String? _memberErrorMessage;
  late AmountCalculationResult _amountCalculation;
  bool _showAllCategories = false;

  bool get _isEditing => widget.transaction != null;

  @override
  void initState() {
    super.initState();

    final transaction = widget.transaction;
    _type = transaction?.type ?? TransactionType.expense;
    _transactionDate = transaction?.transactionDate ?? DateTime.now();
    _selectedCategoryId = transaction?.categoryId;
    _selectedMemberId = transaction?.userId;

    if (transaction != null) {
      _amountController.text = _formatInitialAmount(transaction.amount);
      _noteController.text = transaction.note ?? '';
    }
    _amountCalculation = _calculateAmountResult(_amountController.text);
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
    final profilesAsync = householdId == null
        ? const AsyncValue<List<UserProfile>>.data([])
        : ref.watch(householdProfilesStreamProvider(householdId));
    final transactionsAsync = householdId == null
        ? const AsyncValue<List<Transaction>>.data([])
        : ref.watch(transactionsStreamProvider(householdId));
    final profilesUnavailable =
        profilesAsync.valueOrNull == null &&
        (profilesAsync.isLoading || profilesAsync.hasError);
    final amountValue = _amountCalculation.value;
    final amountInvalid =
        !_amountCalculation.isValid || amountValue == null || amountValue <= 0;

    if (_selectedMemberId == null && userId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _selectedMemberId != null) return;
        _setLocalState(() => _selectedMemberId = userId);
      });
    }

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
            onPressed:
                actionState.isLoading ||
                    householdId == null ||
                    userId == null ||
                    categoriesAsync.isLoading ||
                    profilesUnavailable ||
                    amountInvalid
                ? null
                : () => _submit(
                    householdId: householdId,
                    userId: userId,
                    categories: categoriesAsync.valueOrNull ?? const [],
                    members: profilesAsync.valueOrNull ?? const [],
                  ),
            icon: actionState.isLoading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    _isEditing
                        ? Icons.save_outlined
                        : Icons.check_circle_outline,
                  ),
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
              : () => _retryFormData(householdId),
        ),
        data: (categories) {
          /// Lấy chiều cao bàn phím để form scroll khi keyboard mở
          final viewInsets = MediaQuery.viewInsetsOf(context);
          final theme = Theme.of(context);
          final colorScheme = theme.colorScheme;
          final profilesLoading =
              profilesAsync.valueOrNull == null && profilesAsync.isLoading;
          final profileLoadErrorMessage =
              profilesAsync.valueOrNull == null && profilesAsync.hasError
              ? 'Không thể tải thành viên household.'
              : null;
          final members = _sortedMembers(
            profilesAsync.valueOrNull ?? const <UserProfile>[],
            currentUserId: userId,
          );
          final selectedMember = _selectedMember(members, _selectedMemberId);
          final typedCategories = categories
              .where((category) => category.type == _type)
              .toList();
          final categoryUsageCounts = _categoryUsageCounts(
            transactionsAsync.valueOrNull ?? const <Transaction>[],
          );
          final orderedCategories = _orderedCategoriesByUsage(
            typedCategories,
            usageCounts: categoryUsageCounts,
          );
          final visibleCategories =
              _showAllCategories ||
                  orderedCategories.length <= _collapsedCategoryLimit
              ? orderedCategories
              : orderedCategories.take(_collapsedCategoryLimit).toList();
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
          if (!_showAllCategories &&
              selectedCategory != null &&
              !visibleCategories.any(
                (category) => category.id == selectedCategory.id,
              )) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted || _showAllCategories) return;
              _setLocalState(() => _showAllCategories = true);
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
                    AmountExpressionInput(
                      controller: _amountController,
                      result: _amountCalculation,
                      enabled: !actionState.isLoading,
                      onChanged: _onAmountExpressionChanged,
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
                                _showAllCategories = false;
                              });
                              ref
                                  .read(transactionActionProvider.notifier)
                                  .clearError();
                            },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _MemberPickerCard(
                      members: members,
                      selectedMemberId: _selectedMemberId,
                      selectedMember: selectedMember,
                      hasSelectedMissingMember:
                          _selectedMemberId != null && selectedMember == null,
                      enabled:
                          !actionState.isLoading &&
                          members.isNotEmpty &&
                          !profilesLoading,
                      isLoading: profilesLoading,
                      loadErrorMessage: profileLoadErrorMessage,
                      errorMessage: _memberErrorMessage,
                      onChanged: (memberId) {
                        if (memberId == null) {
                          return;
                        }
                        _setLocalState(() {
                          _selectedMemberId = memberId;
                          _memberErrorMessage = null;
                        });
                        ref
                            .read(transactionActionProvider.notifier)
                            .clearError();
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
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                ),
                                if (typedCategories.isEmpty)
                                  TextButton.icon(
                                    onPressed: actionState.isLoading
                                        ? null
                                        : () {
                                            if (context.mounted) {
                                              context.push(
                                                AppRoutes.categories,
                                              );
                                            }
                                          },
                                    icon: const Icon(Icons.add),
                                    label: const Text('Tạo mới'),
                                  ),
                              ],
                            ),
                            if (orderedCategories.isEmpty) ...[
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
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: visibleCategories.length,
                                    gridDelegate:
                                        SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: crossAxisCount,
                                          mainAxisSpacing: AppSpacing.sm,
                                          crossAxisSpacing: AppSpacing.sm,
                                          childAspectRatio: 1.18,
                                        ),
                                    itemBuilder: (context, index) {
                                      final category = visibleCategories[index];
                                      return _CategoryGridItem(
                                        category: category,
                                        selected:
                                            _selectedCategoryId == category.id,
                                        enabled: !actionState.isLoading,
                                        onTap: () {
                                          _setLocalState(() {
                                            _selectedCategoryId = category.id;
                                            _categoryErrorMessage = null;
                                          });
                                          ref
                                              .read(
                                                transactionActionProvider
                                                    .notifier,
                                              )
                                              .clearError();
                                        },
                                      );
                                    },
                                  );
                                },
                              ),
                              if (orderedCategories.length >
                                  _collapsedCategoryLimit) ...[
                                const SizedBox(height: AppSpacing.sm),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: actionState.isLoading
                                        ? null
                                        : () {
                                            _setLocalState(
                                              () => _showAllCategories =
                                                  !_showAllCategories,
                                            );
                                          },
                                    icon: Icon(
                                      _showAllCategories
                                          ? Icons.expand_less
                                          : Icons.expand_more,
                                    ),
                                    label: Text(
                                      _showAllCategories
                                          ? 'Thu gọn'
                                          : 'Xem thêm ${orderedCategories.length - _collapsedCategoryLimit} danh mục',
                                    ),
                                  ),
                                ),
                              ],
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
                            ref
                                .read(transactionActionProvider.notifier)
                                .clearError();
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
    required List<UserProfile> members,
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

    final selectedMemberId = _selectedMemberId ?? userId;
    final selectedMember = _selectedMember(members, selectedMemberId);
    if (selectedMember == null) {
      _setLocalState(() {
        _memberErrorMessage = 'Vui lòng chọn người thực hiện.';
      });
      return;
    }

    final typedCategories = categories
        .where((category) => category.type == _type)
        .toList();

    final category = _selectedCategory(typedCategories, _selectedCategoryId);
    if (category == null) {
      _setLocalState(() {
        _categoryErrorMessage =
            'Danh mục đã chọn không hợp lệ. Vui lòng chọn lại.';
      });
      return;
    }

    FocusScope.of(context).unfocus();
    final router = GoRouter.of(context);
    final amountCalculation = _calculateAmountResult(_amountController.text);
    if (!amountCalculation.isValid || amountCalculation.value == null) {
      _setLocalState(() => _amountCalculation = amountCalculation);
      return;
    }
    final amount = amountCalculation.value!;
    final note = _noteController.text;
    final notifier = ref.read(transactionActionProvider.notifier);
    final transaction = widget.transaction;

    final success = transaction == null
        ? await notifier.createTransaction(
            householdId: householdId,
            userId: selectedMember.id,
            category: category,
            amount: amount,
            transactionDate: _transactionDate,
            note: note,
          )
        : await notifier.updateTransaction(
            transaction: transaction,
            userId: selectedMember.id,
            category: category,
            amount: amount,
            transactionDate: _transactionDate,
            note: note,
          );

    if (success && mounted) {
      router.pop();
    }
  }

  void _onAmountExpressionChanged(String value) {
    _setLocalState(() {
      _amountCalculation = _calculateAmountResult(value);
    });
    ref.read(transactionActionProvider.notifier).clearError();
  }

  void _retryFormData(String householdId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref.invalidate(categoriesStreamProvider(householdId));
      ref.invalidate(householdProfilesStreamProvider(householdId));
    });
  }

  void _setLocalState(VoidCallback update) {
    if (!mounted) {
      return;
    }
    setState(update);
  }

  AmountCalculationResult _calculateAmountResult(String value) {
    final result = ref.read(amountCalculatorServiceProvider).evaluate(value);
    final amount = result.value;
    if (result.isValid && amount != null && amount <= 0) {
      return AmountCalculationResult.error(
        expression: result.expression,
        message: 'Số tiền phải lớn hơn 0.',
      );
    }
    return result;
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
        child: _DatePickerField(label: label, enabled: enabled, onTap: onTap),
      ),
    );
  }
}

class _MemberPickerCard extends StatelessWidget {
  const _MemberPickerCard({
    required this.members,
    required this.selectedMemberId,
    required this.selectedMember,
    required this.hasSelectedMissingMember,
    required this.enabled,
    required this.isLoading,
    required this.loadErrorMessage,
    required this.errorMessage,
    required this.onChanged,
  });

  final List<UserProfile> members;
  final String? selectedMemberId;
  final UserProfile? selectedMember;
  final bool hasSelectedMissingMember;
  final bool enabled;
  final bool isLoading;
  final String? loadErrorMessage;
  final String? errorMessage;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final member = selectedMember;
    final value = members.any((member) => member.id == selectedMemberId)
        ? selectedMemberId
        : null;
    final hintText = isLoading
        ? 'Đang tải thành viên...'
        : loadErrorMessage != null
        ? 'Không thể tải thành viên'
        : hasSelectedMissingMember
        ? 'Thành viên không còn trong household'
        : members.isEmpty
        ? 'Chưa có thành viên'
        : 'Chọn thành viên';
    final fieldErrorText = errorMessage ?? loadErrorMessage;
    final helperText = member == null
        ? hasSelectedMissingMember
              ? 'Hãy chọn lại một thành viên hiện có.'
              : 'Danh sách thành viên household'
        : member.email;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: DropdownButtonFormField<String>(
          key: ValueKey(value),
          initialValue: value,
          items: [
            for (final member in members)
              DropdownMenuItem(
                value: member.id,
                child: Text(
                  _memberDisplayName(member),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          selectedItemBuilder: members.isEmpty
              ? null
              : (context) {
                  return [
                    for (final member in members)
                      Text(
                        _memberDisplayName(member),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ];
                },
          onChanged: enabled ? onChanged : null,
          decoration: InputDecoration(
            labelText: 'Người thực hiện',
            hintText: hintText,
            helperText: fieldErrorText == null ? helperText : null,
            errorText: fieldErrorText,
            prefixIcon: Padding(
              padding: const EdgeInsets.all(10),
              child: _MemberAvatar(member: member, radius: 12),
            ),
          ),
          icon: isLoading
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.expand_more),
          isExpanded: true,
          menuMaxHeight: 320,
          dropdownColor: Theme.of(context).colorScheme.surface,
        ),
      ),
    );
  }
}

class _MemberAvatar extends StatelessWidget {
  const _MemberAvatar({required this.member, this.radius = 20});

  final UserProfile? member;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final member = this.member;
    final avatarUrl = member?.avatarUrl?.trim();
    final initials = member == null ? '?' : _memberInitials(member);

    return CircleAvatar(
      radius: radius,
      foregroundImage: avatarUrl == null || avatarUrl.isEmpty
          ? null
          : NetworkImage(avatarUrl),
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      child: Text(
        initials,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w800,
          fontSize: radius <= 12 ? 10 : null,
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
                    child: const Icon(
                      Icons.check,
                      size: 12,
                      color: Colors.white,
                    ),
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
            const Text('Không thể tải dữ liệu biểu mẫu. Vui lòng thử lại.'),
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

Map<String, int> _categoryUsageCounts(List<Transaction> transactions) {
  final counts = <String, int>{};
  for (final transaction in transactions) {
    counts.update(
      transaction.categoryId,
      (count) => count + 1,
      ifAbsent: () => 1,
    );
  }
  return counts;
}

List<Category> _orderedCategoriesByUsage(
  List<Category> categories, {
  required Map<String, int> usageCounts,
}) {
  final orderedCategories = [...categories];
  orderedCategories.sort((a, b) {
    final usageCompare = (usageCounts[b.id] ?? 0).compareTo(
      usageCounts[a.id] ?? 0,
    );
    if (usageCompare != 0) {
      return usageCompare;
    }

    final sortOrderCompare = a.sortOrder.compareTo(b.sortOrder);
    if (sortOrderCompare != 0) {
      return sortOrderCompare;
    }

    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return orderedCategories;
}

UserProfile? _selectedMember(List<UserProfile> members, String? memberId) {
  if (memberId == null) {
    return null;
  }

  for (final member in members) {
    if (member.id == memberId) {
      return member;
    }
  }
  return null;
}

List<UserProfile> _sortedMembers(
  List<UserProfile> members, {
  required String? currentUserId,
}) {
  final sortedMembers = [...members];
  sortedMembers.sort((a, b) {
    if (a.id == currentUserId && b.id != currentUserId) {
      return -1;
    }
    if (b.id == currentUserId && a.id != currentUserId) {
      return 1;
    }

    return _memberDisplayName(
      a,
    ).toLowerCase().compareTo(_memberDisplayName(b).toLowerCase());
  });
  return sortedMembers;
}

String _memberDisplayName(UserProfile member) {
  final fullName = member.fullName.trim();
  if (fullName.isNotEmpty) {
    return fullName;
  }

  final email = member.email.trim();
  if (email.isNotEmpty) {
    return email;
  }

  return 'Thành viên';
}

String _memberInitials(UserProfile member) {
  final name = _memberDisplayName(member);
  final words = name
      .split(RegExp(r'\s+'))
      .where((word) => word.trim().isNotEmpty)
      .toList();
  if (words.isEmpty) {
    return '?';
  }
  if (words.length == 1) {
    return words.first.characters.first.toUpperCase();
  }

  return '${words.first.characters.first}${words.last.characters.first}'
      .toUpperCase();
}

String _formatInitialAmount(double amount) {
  return CurrencyInputFormatter.formatNumber(amount);
}

String _typeLabel(TransactionType type) {
  switch (type) {
    case TransactionType.income:
      return 'Thu';
    case TransactionType.expense:
      return 'Chi';
  }
}
