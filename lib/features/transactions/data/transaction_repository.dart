import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:uuid/uuid.dart';

import '../../../core/models/models.dart';
import '../../../core/services/supabase_service.dart';

class TransactionRepository {
  TransactionRepository(this._supabaseService);

  final SupabaseService _supabaseService;
  final _uuid = const Uuid();

  supabase.SupabaseClient get _client => _supabaseService.client;

  Stream<List<Transaction>> watchTransactions(String householdId) {
    return _client
        .from(SupabaseTables.transactions)
        .stream(primaryKey: ['id'])
        .eq('household_id', householdId)
        .order('transaction_date', ascending: false)
        .asyncMap((rows) {
          final transactions = rows.map(Transaction.fromJson).toList();
          transactions.sort(_compareTransaction);
          return transactions;
        });
  }

  Future<List<Transaction>> fetchTransactions(String householdId) {
    return _guard('Lấy danh sách giao dịch', () async {
      final rows = await _client
          .from(SupabaseTables.transactions)
          .select()
          .eq('household_id', householdId)
          .order('transaction_date', ascending: false)
          .order('created_at', ascending: false);

      final transactions = _asJsonList(rows).map(Transaction.fromJson).toList();
      transactions.sort(_compareTransaction);
      return transactions;
    });
  }

  Future<Transaction> createTransaction({
    required String householdId,
    required String userId,
    required Category category,
    required double amount,
    required DateTime transactionDate,
    String? note,
  }) {
    return _guard('Tạo giao dịch', () async {
      _validateAmount(amount);
      _validateCategory(category, householdId);

      final now = DateTime.now().toUtc();
      final draft = Transaction(
        id: _uuid.v4(),
        householdId: householdId,
        userId: userId,
        categoryId: category.id,
        type: category.type,
        amount: amount,
        title: category.name,
        note: _normalizeNote(note),
        transactionDate: _normalizeTransactionDate(transactionDate),
        createdAt: now,
        updatedAt: now,
      );

      final row = await _client
          .from(SupabaseTables.transactions)
          .insert(draft.toJson())
          .select();

      return Transaction.fromJson(
        _requireSingleJsonMap(
          row,
          actionName: 'Tạo giao dịch',
          emptyMessage:
              'Không thể tạo giao dịch. Vui lòng kiểm tra quyền ghi dữ liệu.',
          multipleMessage:
              'Tạo giao dịch trả về nhiều dòng bất thường. Vui lòng kiểm tra database.',
        ),
      );
    });
  }

  Future<Transaction> updateTransaction({
    required Transaction transaction,
    required Category category,
    required double amount,
    required DateTime transactionDate,
    String? note,
  }) {
    return _guard('Cập nhật giao dịch', () async {
      _validateAmount(amount);
      _validateCategory(category, transaction.householdId);

      final payload = {
        'category_id': category.id,
        'type': category.type.value,
        'amount': amount,
        'title': category.name,
        'transaction_date': _normalizeTransactionDate(
          transactionDate,
        ).toIso8601String(),
        'note': _normalizeNote(note),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      final row = await _client
          .from(SupabaseTables.transactions)
          .update(payload)
          .eq('id', transaction.id)
          .eq('household_id', transaction.householdId)
          .select();

      return Transaction.fromJson(
        _requireSingleJsonMap(
          row,
          actionName: 'Cập nhật giao dịch',
          emptyMessage:
              'Không thể cập nhật giao dịch. Giao dịch không tồn tại hoặc bạn không có quyền.',
          multipleMessage:
              'Dữ liệu giao dịch bị trùng khi cập nhật. Vui lòng kiểm tra database.',
        ),
      );
    });
  }

  Future<void> deleteTransaction(Transaction transaction) {
    return _guard('Xóa giao dịch', () async {
      final row = await _client
          .from(SupabaseTables.transactions)
          .delete()
          .eq('id', transaction.id)
          .eq('household_id', transaction.householdId)
          .select('id');

      _requireSingleJsonMap(
        row,
        actionName: 'Xóa giao dịch',
        emptyMessage:
            'Không thể xóa giao dịch. Giao dịch không tồn tại hoặc bạn không có quyền.',
        multipleMessage:
            'Dữ liệu giao dịch bị trùng khi xóa. Vui lòng kiểm tra database.',
      );
    });
  }

  Future<T> _guard<T>(String actionName, Future<T> Function() action) async {
    try {
      return await action();
    } catch (error, stackTrace) {
      if (error is TransactionRepositoryException) {
        rethrow;
      }
      throw _mapException(error, stackTrace, actionName: actionName);
    }
  }

  TransactionRepositoryException _mapException(
    Object error,
    StackTrace stackTrace, {
    required String actionName,
  }) {
    if (error is supabase.PostgrestException) {
      return TransactionRepositoryException(
        message: _friendlyPostgrestMessage(error),
        actionName: actionName,
        code: error.code,
        details: error.details,
        cause: error,
        stackTrace: stackTrace,
      );
    }

    if (error is supabase.AuthException) {
      return TransactionRepositoryException(
        message: error.message,
        actionName: actionName,
        code: error.code ?? error.statusCode,
        cause: error,
        stackTrace: stackTrace,
      );
    }

    if (error is FormatException) {
      return TransactionRepositoryException(
        message: error.message,
        actionName: actionName,
        cause: error,
        stackTrace: stackTrace,
      );
    }

    return TransactionRepositoryException(
      message: 'Không thể xử lý giao dịch. Vui lòng thử lại.',
      actionName: actionName,
      cause: error,
      stackTrace: stackTrace,
    );
  }
}

class TransactionRepositoryException implements Exception {
  const TransactionRepositoryException({
    required this.message,
    required this.actionName,
    this.code,
    this.details,
    this.cause,
    this.stackTrace,
  });

  final String message;
  final String actionName;
  final String? code;
  final Object? details;
  final Object? cause;
  final StackTrace? stackTrace;

  @override
  String toString() {
    final codeText = code == null ? '' : ' [$code]';
    return 'TransactionRepositoryException$codeText: $actionName - $message';
  }
}

void _validateAmount(double amount) {
  if (amount <= 0) {
    throw const TransactionRepositoryException(
      message: 'Số tiền phải lớn hơn 0.',
      actionName: 'Kiểm tra giao dịch',
    );
  }
}

void _validateCategory(Category category, String householdId) {
  if (category.id.trim().isEmpty) {
    throw const TransactionRepositoryException(
      message: 'Vui lòng chọn danh mục.',
      actionName: 'Kiểm tra giao dịch',
    );
  }
  if (category.householdId != householdId) {
    throw const TransactionRepositoryException(
      message: 'Danh mục không thuộc household hiện tại.',
      actionName: 'Kiểm tra giao dịch',
    );
  }
}

DateTime _normalizeTransactionDate(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

String? _normalizeNote(String? value) {
  final cleanValue = value?.trim();
  if (cleanValue == null || cleanValue.isEmpty) {
    return null;
  }
  return cleanValue;
}

String _friendlyPostgrestMessage(supabase.PostgrestException error) {
  switch (error.code) {
    case '23503':
      return 'Danh mục hoặc household không hợp lệ.';
    case '42501':
      return 'Bạn không có quyền xử lý giao dịch này. Vui lòng kiểm tra RLS.';
    case 'PGRST116':
      return 'Không tìm thấy đúng một giao dịch phù hợp.';
    default:
      return error.message;
  }
}

int _compareTransaction(Transaction a, Transaction b) {
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

Map<String, dynamic> _asJsonMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  throw FormatException('Dữ liệu Supabase không phải JSON object: $value');
}

Map<String, dynamic> _requireSingleJsonMap(
  Object? value, {
  required String actionName,
  required String emptyMessage,
  required String multipleMessage,
}) {
  final rows = _asJsonList(value);
  if (rows.length == 1) {
    return rows.single;
  }
  if (rows.isEmpty) {
    throw TransactionRepositoryException(
      message: emptyMessage,
      actionName: actionName,
    );
  }
  throw TransactionRepositoryException(
    message: multipleMessage,
    actionName: actionName,
  );
}

List<Map<String, dynamic>> _asJsonList(Object? value) {
  if (value is! List) {
    throw FormatException('Dữ liệu Supabase không phải JSON list: $value');
  }
  return value.map(_asJsonMap).toList();
}
