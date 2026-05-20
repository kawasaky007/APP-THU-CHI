import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_constants.dart';
import '../../../../core/models/models.dart';
import '../providers/category_provider.dart';
import 'category_visuals.dart';

class CategoryFormBottomSheet extends ConsumerStatefulWidget {
  const CategoryFormBottomSheet({
    required this.existingCategories,
    this.category,
    this.initialType = TransactionType.expense,
    super.key,
  });

  final List<Category> existingCategories;
  final Category? category;
  final TransactionType initialType;

  @override
  ConsumerState<CategoryFormBottomSheet> createState() =>
      _CategoryFormBottomSheetState();
}

class _CategoryFormBottomSheetState
    extends ConsumerState<CategoryFormBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  late TransactionType _type;
  late String _selectedColor;
  late String _selectedIcon;

  bool get _isEditing => widget.category != null;

  @override
  void initState() {
    super.initState();

    final category = widget.category;
    _nameController.text = category?.name ?? '';
    _type = category?.type ?? widget.initialType;
    _selectedColor = category?.color ?? _defaultColorForType(_type);
    _selectedIcon = category?.icon ?? _defaultIconForType(_type);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(categoryActionProvider);
    final viewInsets = MediaQuery.viewInsetsOf(context);

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.lg,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _isEditing ? 'Sửa danh mục' : 'Thêm danh mục',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Đóng',
                      onPressed: actionState.isLoading
                          ? null
                          : () {
                              if (context.mounted) {
                                Navigator.of(context).pop();
                              }
                            },
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                if (actionState.errorMessage case final errorMessage?) ...[
                  _FormErrorBanner(message: errorMessage),
                  const SizedBox(height: AppSpacing.md),
                ],
                TextFormField(
                  controller: _nameController,
                  enabled: !actionState.isLoading,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(40),
                    FilteringTextInputFormatter.deny(RegExp(r'^\s+')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Tên danh mục',
                    prefixIcon: Icon(Icons.label_outline),
                  ),
                  validator: _validateName,
                  onChanged: (_) =>
                      ref.read(categoryActionProvider.notifier).clearError(),
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: AppSpacing.md),
                SegmentedButton<TransactionType>(
                  segments: const [
                    ButtonSegment(
                      value: TransactionType.income,
                      icon: Icon(Icons.trending_up),
                      label: Text('Thu'),
                    ),
                    ButtonSegment(
                      value: TransactionType.expense,
                      icon: Icon(Icons.trending_down),
                      label: Text('Chi'),
                    ),
                  ],
                  selected: {_type},
                  onSelectionChanged: actionState.isLoading
                      ? null
                      : (selectedValues) {
                          _setLocalState(() {
                            _type = selectedValues.first;
                            _selectedColor = _defaultColorForType(_type);
                            _selectedIcon = _defaultIconForType(_type);
                          });
                          ref
                              .read(categoryActionProvider.notifier)
                              .clearError();
                        },
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Màu sắc', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final colorHex in CategoryVisuals.colorOptions)
                      _ColorSwatchButton(
                        colorHex: colorHex,
                        selected: _selectedColor == colorHex,
                        enabled: !actionState.isLoading,
                        onTap: () {
                          _setLocalState(() => _selectedColor = colorHex);
                          ref
                              .read(categoryActionProvider.notifier)
                              .clearError();
                        },
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Icon', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: AppSpacing.sm),
                GridView.count(
                  crossAxisCount: 6,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: AppSpacing.sm,
                  crossAxisSpacing: AppSpacing.sm,
                  children: [
                    for (final option in CategoryVisuals.iconOptions)
                      _IconOptionButton(
                        option: option,
                        selected: _selectedIcon == option.name,
                        colorHex: _selectedColor,
                        enabled: !actionState.isLoading,
                        onTap: () {
                          _setLocalState(() => _selectedIcon = option.name);
                          ref
                              .read(categoryActionProvider.notifier)
                              .clearError();
                        },
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  onPressed: actionState.isLoading ? null : _submit,
                  icon: actionState.isLoading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(_isEditing ? Icons.save_outlined : Icons.add),
                  label: Text(_isEditing ? 'Lưu thay đổi' : 'Thêm danh mục'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }
    if (!mounted) {
      return;
    }

    FocusScope.of(context).unfocus();
    final navigator = Navigator.of(context);
    final notifier = ref.read(categoryActionProvider.notifier);
    final category = widget.category;
    final name = _nameController.text;

    final success = category == null
        ? await notifier.createCategory(
            name: name,
            type: _type,
            color: _selectedColor,
            icon: _selectedIcon,
          )
        : await notifier.updateCategory(
            category: category,
            name: name,
            type: _type,
            color: _selectedColor,
            icon: _selectedIcon,
          );

    if (success && mounted) {
      navigator.pop();
    }
  }

  String? _validateName(String? value) {
    final cleanName = value?.trim().replaceAll(RegExp(r'\s+'), ' ') ?? '';
    if (cleanName.length < 2) {
      return 'Tên danh mục cần tối thiểu 2 ký tự.';
    }

    final duplicated = widget.existingCategories.any((category) {
      final isCurrentCategory = category.id == widget.category?.id;
      return !isCurrentCategory &&
          category.type == _type &&
          category.name.trim().toLowerCase() == cleanName.toLowerCase();
    });

    if (duplicated) {
      return 'Tên danh mục này đã tồn tại trong cùng loại thu/chi.';
    }

    return null;
  }

  String _defaultColorForType(TransactionType type) {
    return type == TransactionType.income ? '#0F8B6F' : '#C2410C';
  }

  String _defaultIconForType(TransactionType type) {
    return type == TransactionType.income ? 'salary' : 'food';
  }

  void _setLocalState(VoidCallback update) {
    if (!mounted) {
      return;
    }
    setState(update);
  }
}

class _ColorSwatchButton extends StatelessWidget {
  const _ColorSwatchButton({
    required this.colorHex,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String colorHex;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = CategoryVisuals.colorFromHex(colorHex);

    return Tooltip(
      message: colorHex,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.onSurface
                  : Colors.transparent,
              width: 3,
            ),
          ),
          child: selected
              ? const Icon(Icons.check, color: Colors.white, size: 20)
              : null,
        ),
      ),
    );
  }
}

class _IconOptionButton extends StatelessWidget {
  const _IconOptionButton({
    required this.option,
    required this.selected,
    required this.colorHex,
    required this.enabled,
    required this.onTap,
  });

  final CategoryIconOption option;
  final bool selected;
  final String colorHex;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = CategoryVisuals.colorFromHex(colorHex);
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: option.name,
      child: IconButton.filledTonal(
        onPressed: enabled ? onTap : null,
        style: IconButton.styleFrom(
          backgroundColor: selected
              ? color.withValues(alpha: 0.18)
              : colorScheme.surfaceContainerHighest,
          foregroundColor: selected ? color : colorScheme.onSurfaceVariant,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: Icon(option.icon),
      ),
    );
  }
}

class _FormErrorBanner extends StatelessWidget {
  const _FormErrorBanner({required this.message});

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
