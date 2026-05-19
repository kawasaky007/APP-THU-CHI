import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/models.dart';
import '../../../transactions/presentation/providers/transaction_provider.dart';

final dashboardTransactionsProvider =
    StreamProvider.family<List<Transaction>, String>((ref, householdId) {
      return ref
          .read(transactionRepositoryProvider)
          .watchTransactions(householdId);
    });
