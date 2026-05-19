import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/models.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/transaction_repository.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(ref.watch(supabaseServiceProvider));
});

final transactionListProvider = StreamProvider.autoDispose<List<Transaction>>((
  ref,
) {
  final householdId = ref.watch(currentHouseholdIdProvider);

  if (householdId == null) {
    return Stream.value(const []);
  }

  return ref
      .watch(transactionRepositoryProvider)
      .watchTransactions(householdId);
});

final transactionActionProvider =
    StateNotifierProvider<TransactionActionController, TransactionActionState>((
      ref,
    ) {
      return TransactionActionController(
        repository: ref.watch(transactionRepositoryProvider),
        ref: ref,
      );
    });

class TransactionActionState {
  const TransactionActionState({this.isLoading = false, this.errorMessage});

  final bool isLoading;
  final String? errorMessage;
}

class TransactionActionController
    extends StateNotifier<TransactionActionState> {
  TransactionActionController({
    required TransactionRepository repository,
    required Ref ref,
  }) : _repository = repository,
       _ref = ref,
       super(const TransactionActionState());

  final TransactionRepository _repository;
  final Ref _ref;

  Future<bool> createTransaction({
    required String householdId,
    required String userId,
    required Category category,
    required double amount,
    required DateTime transactionDate,
    String? note,
  }) {
    return _runAction(() async {
      await _repository.createTransaction(
        householdId: householdId,
        userId: userId,
        category: category,
        amount: amount,
        transactionDate: transactionDate,
        note: note,
      );
    });
  }

  Future<bool> updateTransaction({
    required Transaction transaction,
    required Category category,
    required double amount,
    required DateTime transactionDate,
    String? note,
  }) {
    return _runAction(() async {
      await _repository.updateTransaction(
        transaction: transaction,
        category: category,
        amount: amount,
        transactionDate: transactionDate,
        note: note,
      );
    });
  }

  Future<bool> deleteTransaction(Transaction transaction) {
    return _runAction(() async {
      await _repository.deleteTransaction(transaction);
    });
  }

  void clearError() {
    if (state.errorMessage != null) {
      _setState(const TransactionActionState());
    }
  }

  Future<bool> _runAction(Future<void> Function() action) async {
    _setState(const TransactionActionState(isLoading: true));

    try {
      await action();
      if (!mounted) {
        return false;
      }
      _setState(const TransactionActionState());
      _ref.invalidate(transactionListProvider);
      return true;
    } catch (error) {
      _setState(TransactionActionState(errorMessage: _errorMessage(error)));
      return false;
    }
  }

  String _errorMessage(Object error) {
    if (error is TransactionRepositoryException) {
      return error.message;
    }
    return 'Không thể xử lý giao dịch. Vui lòng thử lại.';
  }

  void _setState(TransactionActionState nextState) {
    if (mounted) {
      state = nextState;
    }
  }
}
