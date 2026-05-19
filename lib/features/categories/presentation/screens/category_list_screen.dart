import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_constants.dart';
import '../../../../core/models/models.dart';
import '../../../../shared/widgets/app_feedback.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/category_provider.dart';
import '../widgets/category_form_bottom_sheet.dart';
import '../widgets/category_visuals.dart';

class CategoryListScreen extends ConsumerStatefulWidget {
  const CategoryListScreen({super.key});

  @override
  ConsumerState<CategoryListScreen> createState() => _CategoryListScreenState();
}

class _CategoryListScreenState extends ConsumerState<CategoryListScreen> {
  TransactionType _selectedType = TransactionType.expense;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final householdId = ref.watch(currentHouseholdIdProvider);
    final userId = authState.user?.id ?? authState.profile?.id;
    final categoriesAsync = householdId == null
        ? const AsyncValue<List<Category>>.data([])
        : ref.watch(categoriesStreamProvider(householdId));

    debugPrint('CATEGORY REALTIME UI: householdId=$householdId userId=$userId');

    return Scaffold(
      appBar: AppBar(title: const Text('Danh mục thu/chi')),
      floatingActionButton: householdId == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                final categories = categoriesAsync.valueOrNull ?? const [];
                _showCategoryForm(
                  existingCategories: categories,
                  initialType: _selectedType,
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Thêm'),
            ),
      body: householdId == null
          ? const _NoHouseholdView()
          : categoriesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) {
                return _CategoryErrorView(
                  message: 'Không thể tải danh mục. Vui lòng thử lại.',
                  onRetry: () =>
                      ref.invalidate(categoriesStreamProvider(householdId)),
                );
              },
              data: (categories) {
                final filteredCategories = categories
                    .where((category) => category.type == _selectedType)
                    .toList();

                return RefreshIndicator(
                  onRefresh: () => _refresh(householdId),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(0, 0, 0, 96),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: SegmentedButton<TransactionType>(
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
                          selected: {_selectedType},
                          onSelectionChanged: (selectedValues) {
                            _setLocalState(
                              () => _selectedType = selectedValues.first,
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        child: _CategorySummary(
                          type: _selectedType,
                          count: filteredCategories.length,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      if (filteredCategories.isEmpty)
                        SizedBox(
                          height: MediaQuery.sizeOf(context).height * 0.42,
                          child: _EmptyCategoryView(
                            type: _selectedType,
                            onCreate: () => _showCategoryForm(
                              existingCategories: categories,
                              initialType: _selectedType,
                            ),
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                          ),
                          child: Column(
                            children: [
                              for (
                                var index = 0;
                                index < filteredCategories.length;
                                index++
                              ) ...[
                                _CategoryTile(
                                  category: filteredCategories[index],
                                  onEdit: () => _showCategoryForm(
                                    existingCategories: categories,
                                    category: filteredCategories[index],
                                  ),
                                  onDelete: () => _confirmDeleteCategory(
                                    filteredCategories[index],
                                  ),
                                ),
                                if (index != filteredCategories.length - 1)
                                  const SizedBox(height: AppSpacing.sm),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Future<void> _refresh(String householdId) async {
    ref.invalidate(categoriesStreamProvider(householdId));
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }

  Future<void> _showCategoryForm({
    required List<Category> existingCategories,
    Category? category,
    TransactionType initialType = TransactionType.expense,
  }) async {
    if (!mounted) {
      return;
    }

    ref.read(categoryActionProvider.notifier).clearError();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return CategoryFormBottomSheet(
          existingCategories: existingCategories,
          category: category,
          initialType: initialType,
        );
      },
    );
  }

  Future<void> _confirmDeleteCategory(Category category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Xóa danh mục?'),
          content: Text(
            'Danh mục "${category.name}" sẽ bị xóa khỏi household hiện tại.',
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
        .read(categoryActionProvider.notifier)
        .deleteCategory(category);
    if (!mounted) {
      return;
    }

    final message = success
        ? 'Đã xóa danh mục "${category.name}".'
        : ref.read(categoryActionProvider).errorMessage ??
              'Không thể xóa danh mục.';

    AppFeedback.showSnackBar(message, isError: !success);
  }

  void _setLocalState(VoidCallback update) {
    if (!mounted) {
      return;
    }
    setState(update);
  }
}

class _CategorySummary extends StatelessWidget {
  const _CategorySummary({required this.type, required this.count});

  final TransactionType type;
  final int count;

  @override
  Widget build(BuildContext context) {
    final color = CategoryVisuals.toneForType(type);
    final label = CategoryVisuals.labelForType(type).toLowerCase();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          Icon(
            type == TransactionType.income
                ? Icons.trending_up
                : Icons.trending_down,
            color: color,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '$count danh mục $label',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
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

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.onEdit,
    required this.onDelete,
  });

  final Category category;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final color = CategoryVisuals.colorFromHex(category.color);
    final typeLabel = CategoryVisuals.labelForType(category.type);

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.14),
          child: Icon(
            CategoryVisuals.iconFromName(category.icon),
            color: color,
          ),
        ),
        title: Text(category.name),
        subtitle: Text(
          category.isDefault ? '$typeLabel - Mặc định' : typeLabel,
        ),
        trailing: MenuAnchor(
          builder: (context, controller, child) {
            return IconButton(
              tooltip: 'Tùy chọn',
              onPressed: () {
                if (controller.isOpen) {
                  controller.close();
                } else {
                  controller.open();
                }
              },
              icon: const Icon(Icons.more_vert),
            );
          },
          menuChildren: [
            MenuItemButton(
              onPressed: onEdit,
              leadingIcon: const Icon(Icons.edit_outlined),
              child: const Text('Sửa'),
            ),
            MenuItemButton(
              onPressed: onDelete,
              leadingIcon: const Icon(Icons.delete_outline),
              child: const Text('Xóa'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCategoryView extends StatelessWidget {
  const _EmptyCategoryView({required this.type, required this.onCreate});

  final TransactionType type;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final label = CategoryVisuals.labelForType(type).toLowerCase();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.category_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Chưa có danh mục $label',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.sm),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Thêm danh mục'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryErrorView extends StatelessWidget {
  const _CategoryErrorView({required this.message, required this.onRetry});

  final String message;
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
            Text(message, textAlign: TextAlign.center),
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

class _NoHouseholdView extends StatelessWidget {
  const _NoHouseholdView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Text('Bạn cần tạo hoặc tham gia household trước.'),
      ),
    );
  }
}
