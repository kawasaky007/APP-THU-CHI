import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/models.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/category_repository.dart';

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository(ref.watch(supabaseServiceProvider));
});

final categoryListProvider = StreamProvider.autoDispose<List<Category>>((ref) {
  final householdId = ref.watch(currentHouseholdIdProvider);

  if (householdId == null) {
    return Stream.value(const []);
  }

  return ref.watch(categoryRepositoryProvider).watchCategories(householdId);
});

final categoryActionProvider =
    StateNotifierProvider<CategoryActionController, CategoryActionState>((ref) {
      return CategoryActionController(
        repository: ref.watch(categoryRepositoryProvider),
        ref: ref,
      );
    });

class CategoryActionState {
  const CategoryActionState({this.isLoading = false, this.errorMessage});

  final bool isLoading;
  final String? errorMessage;

  CategoryActionState copyWith({bool? isLoading, String? errorMessage}) {
    return CategoryActionState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class CategoryActionController extends StateNotifier<CategoryActionState> {
  CategoryActionController({
    required CategoryRepository repository,
    required Ref ref,
  }) : _repository = repository,
       _ref = ref,
       super(const CategoryActionState());

  final CategoryRepository _repository;
  final Ref _ref;

  Future<bool> createCategory({
    required String name,
    required TransactionType type,
    required String color,
    required String icon,
  }) {
    return _runAction(() async {
      final householdId = _requireCurrentHouseholdId();
      await _repository.createCategory(
        householdId: householdId,
        name: name,
        type: type,
        color: color,
        icon: icon,
      );
    });
  }

  Future<bool> updateCategory({
    required Category category,
    required String name,
    required TransactionType type,
    required String color,
    required String icon,
  }) {
    return _runAction(() async {
      _ensureCategoryBelongsToCurrentHousehold(category);
      await _repository.updateCategory(
        category: category,
        name: name,
        type: type,
        color: color,
        icon: icon,
      );
    });
  }

  Future<bool> deleteCategory(Category category) {
    return _runAction(() async {
      _ensureCategoryBelongsToCurrentHousehold(category);
      await _repository.deleteCategory(category);
    });
  }

  void clearError() {
    if (state.errorMessage != null) {
      _setState(const CategoryActionState());
    }
  }

  Future<bool> _runAction(Future<void> Function() action) async {
    _setState(const CategoryActionState(isLoading: true));

    try {
      await action();
      if (!mounted) {
        return false;
      }
      _setState(const CategoryActionState());
      _ref.invalidate(categoryListProvider);
      return true;
    } catch (error) {
      _setState(CategoryActionState(errorMessage: _errorMessage(error)));
      return false;
    }
  }

  String _errorMessage(Object error) {
    if (error is CategoryRepositoryException) {
      return error.message;
    }
    return 'Không thể xử lý danh mục. Vui lòng thử lại.';
  }

  String _requireCurrentHouseholdId() {
    final householdId = _ref.read(currentHouseholdIdProvider);
    if (householdId == null) {
      throw const CategoryRepositoryException(
        message: 'Bạn cần tạo hoặc tham gia household trước khi thêm danh mục.',
        actionName: 'Kiểm tra household hiện tại',
      );
    }
    return householdId;
  }

  void _ensureCategoryBelongsToCurrentHousehold(Category category) {
    final householdId = _requireCurrentHouseholdId();
    if (category.householdId.trim() != householdId) {
      throw const CategoryRepositoryException(
        message: 'Danh mục không thuộc household hiện tại.',
        actionName: 'Kiểm tra household hiện tại',
      );
    }
  }

  void _setState(CategoryActionState nextState) {
    if (mounted) {
      state = nextState;
    }
  }
}
