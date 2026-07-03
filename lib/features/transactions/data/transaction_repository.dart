import 'package:flutter/foundation.dart' hide Category;
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
    debugPrint('WATCH TRANSACTIONS STARTED: $householdId');

    return _client
        .from(SupabaseTables.transactions)
        .stream(primaryKey: ['id'])
        .eq('household_id', householdId)
        .order('transaction_date', ascending: false)
        .asyncMap((rows) {
          final deduplicatedRows = _dedupeRowsById(
            rows,
            entityName: 'TRANSACTIONS',
          );
          debugPrint(
            'TRANSACTIONS REALTIME UPDATE: ${deduplicatedRows.length}',
          );
          final transactions = deduplicatedRows
              .map(Transaction.fromJson)
              .toList();
          transactions.sort(_compareTransaction);
          return transactions;
        });
  }

  Stream<List<Transaction>> watchTransactionsByMonth({
    required String householdId,
    required DateTime month,
  }) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);
    final startIso = start.toIso8601String();
    final endIso = end.toIso8601String();

    debugPrint(
      'WATCH TRANSACTIONS BY MONTH: $householdId [$startIso, $endIso)',
    );

    return _client
        .from(SupabaseTables.transactions)
        .stream(primaryKey: ['id'])
        .eq('household_id', householdId)
        .order('transaction_date', ascending: false)
        .asyncMap((rows) {
          final deduplicatedRows = _dedupeRowsById(
            rows,
            entityName: 'TRANSACTIONS_MONTH',
          );
          final transactions = deduplicatedRows
              .map(Transaction.fromJson)
              .where(
                (t) =>
                    !t.transactionDate.isBefore(start) &&
                    t.transactionDate.isBefore(end),
              )
              .toList();
          transactions.sort(_compareTransaction);
          debugPrint(
            'TRANSACTIONS MONTH REALTIME UPDATE: ${transactions.length}',
          );
          return transactions;
        });
  }

  Future<List<Transaction>> fetchTransactionsPage({
    required String householdId,
    required int limit,
    required int offset,
  }) {
    return _guard('Lấy trang giao dịch', () async {
      final rows = await _client
          .from(SupabaseTables.transactions)
          .select()
          .eq('household_id', householdId)
          .order('transaction_date', ascending: false)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final transactions = _asJsonList(rows).map(Transaction.fromJson).toList();
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
      final cleanUserId = _normalizeId(userId, fieldName: 'người thực hiện');
      await _validateHouseholdMember(
        householdId: householdId,
        userId: cleanUserId,
      );

      final now = DateTime.now().toUtc();
      final draft = Transaction(
        id: _uuid.v4(),
        householdId: householdId,
        userId: cleanUserId,
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
    required String userId,
    required Category category,
    required double amount,
    required DateTime transactionDate,
    String? note,
  }) {
    return _guard('Cập nhật giao dịch', () async {
      _validateAmount(amount);
      _validateCategory(category, transaction.householdId);
      final cleanUserId = _normalizeId(userId, fieldName: 'người thực hiện');
      await _validateHouseholdMember(
        householdId: transaction.householdId,
        userId: cleanUserId,
      );

      final payload = {
        'user_id': cleanUserId,
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

  Future<void> deleteTransaction({
    required String transactionId,
    required String householdId,
  }) {
    return _guard('Xóa giao dịch', () async {
      final cleanTransactionId = _normalizeId(
        transactionId,
        fieldName: 'giao dịch',
      );
      final cleanHouseholdId = _normalizeId(
        householdId,
        fieldName: 'household',
      );

      final row = await _client
          .from(SupabaseTables.transactions)
          .delete()
          .eq('id', cleanTransactionId)
          .eq('household_id', cleanHouseholdId)
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

  Future<void> _validateHouseholdMember({
    required String householdId,
    required String userId,
  }) async {
    final row = await _client
        .from(SupabaseTables.userProfiles)
        .select('id, household_id')
        .eq('id', userId)
        .eq('household_id', householdId)
        .maybeSingle();

    if (row == null) {
      throw const TransactionRepositoryException(
        message: 'Người thực hiện không thuộc household hiện tại.',
        actionName: 'Kiểm tra giao dịch',
      );
    }
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

String _normalizeId(String value, {required String fieldName}) {
  final cleanValue = value.trim();
  if (cleanValue.isEmpty) {
    throw TransactionRepositoryException(
      message: 'Không tìm thấy $fieldName hợp lệ.',
      actionName: 'Kiểm tra giao dịch',
    );
  }
  return cleanValue;
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

List<Map<String, dynamic>> _dedupeRowsById(
  Iterable<Map<String, dynamic>> rows, {
  required String entityName,
}) {
  final latestRowsById = <String, Map<String, dynamic>>{};
  final rowsWithoutId = <Map<String, dynamic>>[];

  for (final row in rows) {
    final rawId = row['id'];
    final id = rawId is String ? rawId : rawId?.toString();
    if (id == null || id.isEmpty) {
      rowsWithoutId.add(row);
      continue;
    }
    latestRowsById[id] = row;
  }

  final deduplicatedRows = [...latestRowsById.values, ...rowsWithoutId];
  final duplicateCount = rows.length - deduplicatedRows.length;
  if (duplicateCount > 0) {
    debugPrint(
      '$entityName REALTIME DEDUPED: removed=$duplicateCount before=${rows.length} after=${deduplicatedRows.length}',
    );
  }

  return deduplicatedRows;
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
