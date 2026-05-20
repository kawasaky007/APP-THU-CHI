import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/models.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/budget_repository.dart';

class BudgetMonthParams {
  const BudgetMonthParams({
    required this.householdId,
    required this.month,
    required this.year,
  });

  final String householdId;
  final int month;
  final int year;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is BudgetMonthParams &&
            other.householdId == householdId &&
            other.month == month &&
            other.year == year;
  }

  @override
  int get hashCode => Object.hash(householdId, month, year);
}

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  return BudgetRepository(ref.watch(supabaseServiceProvider));
});

final budgetsByMonthProvider = StreamProvider.autoDispose
    .family<List<Budget>, BudgetMonthParams>((ref, params) {
      final userId = ref.watch(
        authControllerProvider.select(
          (state) => state.user?.id ?? state.profile?.id,
        ),
      );
      debugPrint(
        'BUDGETS STREAM PROVIDER SUBSCRIBED: householdId=${params.householdId} month=${params.month} year=${params.year} userId=$userId',
      );
      ref.onDispose(
        () => debugPrint(
          'BUDGETS STREAM PROVIDER DISPOSED: householdId=${params.householdId} month=${params.month} year=${params.year}',
        ),
      );

      return ref
          .watch(budgetRepositoryProvider)
          .watchBudgetsByMonth(
            householdId: params.householdId,
            month: params.month,
            year: params.year,
          );
    });

final budgetActionProvider =
    StateNotifierProvider<BudgetActionController, BudgetActionState>((ref) {
      return BudgetActionController(
        repository: ref.watch(budgetRepositoryProvider),
      );
    });

class BudgetActionState {
  const BudgetActionState({this.isLoading = false, this.errorMessage});

  final bool isLoading;
  final String? errorMessage;
}

class BudgetActionController extends StateNotifier<BudgetActionState> {
  BudgetActionController({required BudgetRepository repository})
    : _repository = repository,
      super(const BudgetActionState());

  final BudgetRepository _repository;

  Future<bool> upsertBudget({
    required String householdId,
    required String categoryId,
    required int month,
    required int year,
    required double amount,
  }) {
    return _runAction(() async {
      await _repository.upsertBudget(
        householdId: householdId,
        categoryId: categoryId,
        month: month,
        year: year,
        amount: amount,
      );
    });
  }

  Future<bool> deleteBudget(Budget budget) {
    return _runAction(() async {
      await _repository.deleteBudget(budget);
    });
  }

  void clearError() {
    if (state.errorMessage != null) {
      _setState(const BudgetActionState());
    }
  }

  Future<bool> _runAction(Future<void> Function() action) async {
    _setState(const BudgetActionState(isLoading: true));

    try {
      await action();
      if (!mounted) {
        return false;
      }
      _setState(const BudgetActionState());
      return true;
    } catch (error) {
      _setState(BudgetActionState(errorMessage: _errorMessage(error)));
      return false;
    }
  }

  String _errorMessage(Object error) {
    if (error is BudgetRepositoryException) {
      return error.message;
    }
    return 'Không thể xử lý ngân sách. Vui lòng thử lại.';
  }

  void _setState(BudgetActionState nextState) {
    if (mounted) {
      state = nextState;
    }
  }
}
