import 'package:flutter/foundation.dart' hide Category;
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../core/models/models.dart';
import '../../../core/services/supabase_service.dart';

class BudgetRepository {
  BudgetRepository(this._supabaseService);

  final SupabaseService _supabaseService;

  supabase.SupabaseClient get _client => _supabaseService.client;

  Stream<List<Budget>> watchBudgetsByMonth({
    required String householdId,
    required int month,
    required int year,
  }) {
    final cleanHouseholdId = _normalizeHouseholdId(householdId);
    _validateMonthYear(month: month, year: year);
    debugPrint(
      'WATCH BUDGETS STARTED: householdId=$cleanHouseholdId month=$month year=$year',
    );

    return _client
        .from(SupabaseTables.budgets)
        .stream(primaryKey: ['id'])
        .eq('household_id', cleanHouseholdId)
        .asyncMap((rows) {
          final monthRows = rows.where((row) {
            return _readInt(row['month']) == month &&
                _readInt(row['year']) == year;
          }).toList();
          final deduplicatedRows = _dedupeRowsById(
            monthRows,
            entityName: 'BUDGETS',
          );
          debugPrint('BUDGETS REALTIME UPDATE: ${deduplicatedRows.length}');
          final budgets = _parseBudgetRows(deduplicatedRows);
          budgets.sort(_compareBudget);
          return budgets;
        });
  }

  Future<List<Budget>> fetchBudgetsByMonth({
    required String householdId,
    required int month,
    required int year,
  }) {
    return _guard('Lấy ngân sách tháng', () async {
      final cleanHouseholdId = _normalizeHouseholdId(householdId);
      _validateMonthYear(month: month, year: year);

      final rows = await _client
          .from(SupabaseTables.budgets)
          .select()
          .eq('household_id', cleanHouseholdId)
          .eq('month', month)
          .eq('year', year)
          .order('display_order', ascending: true);

      final budgets = _parseBudgetRows(_asJsonList(rows));
      budgets.sort(_compareBudget);
      return budgets;
    });
  }

  Future<Budget> upsertBudget({
    required String householdId,
    required String categoryId,
    required int month,
    required int year,
    required double amount,
  }) {
    return _guard('Lưu ngân sách danh mục', () async {
      final cleanHouseholdId = _normalizeHouseholdId(householdId);
      final cleanCategoryId = _normalizeCategoryId(categoryId);
      _validateMonthYear(month: month, year: year);
      _validateAmount(amount);

      await _requireExpenseCategory(
        householdId: cleanHouseholdId,
        categoryId: cleanCategoryId,
      );

      final currentUserId = _client.auth.currentUser?.id;
      final row = await _client.from(SupabaseTables.budgets).upsert({
        'household_id': cleanHouseholdId,
        'category_id': cleanCategoryId,
        'month': month,
        'year': year,
        'amount': amount,
        ...?(currentUserId == null ? null : {'created_by': currentUserId}),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'household_id,category_id,month,year').select();

      return Budget.fromJson(
        _requireSingleJsonMap(
          row,
          actionName: 'Lưu ngân sách danh mục',
          emptyMessage:
              'Không thể lưu ngân sách. Vui lòng kiểm tra quyền truy cập.',
          multipleMessage:
              'Dữ liệu ngân sách bị trùng. Vui lòng kiểm tra database.',
        ),
      );
    });
  }

  Future<void> deleteBudget(Budget budget) {
    return _guard('Xóa ngân sách danh mục', () async {
      final cleanHouseholdId = _normalizeHouseholdId(budget.householdId);
      final row = await _client
          .from(SupabaseTables.budgets)
          .delete()
          .eq('id', budget.id)
          .eq('household_id', cleanHouseholdId)
          .select('id');

      _requireSingleJsonMap(
        row,
        actionName: 'Xóa ngân sách danh mục',
        emptyMessage:
            'Không thể xóa ngân sách. Ngân sách không tồn tại hoặc bạn không có quyền.',
        multipleMessage:
            'Dữ liệu ngân sách bị trùng khi xóa. Vui lòng kiểm tra database.',
      );
    });
  }

  Future<void> updateDisplayOrders(List<Budget> budgets) {
    return _guard('Cập nhật thứ tự hiển thị', () async {
      if (budgets.isEmpty) return;

      final updates = budgets.map((budget) => {
        'id': budget.id,
        'household_id': budget.householdId,
        'category_id': budget.categoryId,
        'month': budget.month,
        'year': budget.year,
        'amount': budget.amount,
        'display_order': budget.displayOrder,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).toList();

      await _client
          .from(SupabaseTables.budgets)
          .upsert(updates, onConflict: 'household_id,category_id,month,year');
    });
  }

  /// Returns true if the given month already has at least one budget.
  Future<bool> hasBudgetsForMonth({
    required String householdId,
    required int month,
    required int year,
  }) {
    return _guard('Kiểm tra ngân sách tháng', () async {
      final cleanHouseholdId = _normalizeHouseholdId(householdId);
      _validateMonthYear(month: month, year: year);

      final rows = await _client
          .from(SupabaseTables.budgets)
          .select('id')
          .eq('household_id', cleanHouseholdId)
          .eq('month', month)
          .eq('year', year)
          .limit(1);

      final exists = _asJsonList(rows).isNotEmpty;
      debugPrint('[BudgetClone] hasBudgetsForMonth($month/$year): $exists');
      return exists;
    });
  }

  /// Finds the latest (month, year) that has budgets before the given target.
  /// Returns null if no previous budgets exist.
  Future<({int month, int year})?> findLatestBudgetMonthBefore({
    required String householdId,
    required int month,
    required int year,
  }) {
    return _guard('Tìm tháng ngân sách gần nhất', () async {
      final cleanHouseholdId = _normalizeHouseholdId(householdId);
      _validateMonthYear(month: month, year: year);

      // Strategy: query budgets from previous years first, then same year
      // with earlier months. This avoids complex or()/and() PostgREST syntax
      // that may not work across all Supabase versions.

      // 1. Try same year, earlier month
      var rows = await _client
          .from(SupabaseTables.budgets)
          .select('month, year')
          .eq('household_id', cleanHouseholdId)
          .eq('year', year)
          .lt('month', month)
          .order('month', ascending: false)
          .limit(1);

      var list = _asJsonList(rows);
      if (list.isNotEmpty) {
        final row = list.first;
        final foundMonth = _readInt(row['month']);
        final foundYear = _readInt(row['year']);
        if (foundMonth != null && foundYear != null) {
          debugPrint(
            '[BudgetClone] Found source in same year: $foundMonth/$foundYear',
          );
          return (month: foundMonth, year: foundYear);
        }
      }

      // 2. Try previous years
      rows = await _client
          .from(SupabaseTables.budgets)
          .select('month, year')
          .eq('household_id', cleanHouseholdId)
          .lt('year', year)
          .order('year', ascending: false)
          .order('month', ascending: false)
          .limit(1);

      list = _asJsonList(rows);
      if (list.isEmpty) {
        debugPrint('[BudgetClone] No previous budget months found');
        return null;
      }

      final row = list.first;
      final foundMonth = _readInt(row['month']);
      final foundYear = _readInt(row['year']);
      if (foundMonth == null || foundYear == null) return null;

      debugPrint(
        '[BudgetClone] Found source in previous year: $foundMonth/$foundYear',
      );
      return (month: foundMonth, year: foundYear);
    });
  }

  /// Inserts cloned budgets for a target month.
  Future<void> insertClonedBudgets(List<Budget> budgets) {
    return _guard('Sao chép ngân sách', () async {
      if (budgets.isEmpty) return;

      final inserts = budgets.map((budget) => {
        'household_id': budget.householdId,
        'category_id': budget.categoryId,
        'month': budget.month,
        'year': budget.year,
        'amount': budget.amount,
        'display_order': budget.displayOrder,
        if (budget.createdBy != null) 'created_by': budget.createdBy,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).toList();

      debugPrint('[BudgetClone] Insert payload: ${inserts.length} rows');
      debugPrint('[BudgetClone] First row: ${inserts.first}');

      await _client
          .from(SupabaseTables.budgets)
          .upsert(inserts, onConflict: 'household_id,category_id,month,year');

      debugPrint('[BudgetClone] Supabase upsert completed');
    });
  }

  Future<void> _requireExpenseCategory({
    required String householdId,
    required String categoryId,
  }) async {
    final rows = await _client
        .from(SupabaseTables.categories)
        .select('id, household_id, type')
        .eq('id', categoryId)
        .eq('household_id', householdId)
        .limit(2);

    final row = _requireSingleJsonMap(
      rows,
      actionName: 'Kiểm tra danh mục ngân sách',
      emptyMessage:
          'Danh mục không tồn tại hoặc không thuộc household hiện tại.',
      multipleMessage: 'Dữ liệu danh mục bị trùng. Vui lòng kiểm tra database.',
    );

    if (TransactionType.fromJson(row['type']) != TransactionType.expense) {
      throw const BudgetRepositoryException(
        message: 'Chỉ danh mục chi tiêu mới được đặt ngân sách.',
        actionName: 'Kiểm tra danh mục ngân sách',
      );
    }
  }

  Future<T> _guard<T>(String actionName, Future<T> Function() action) async {
    try {
      return await action();
    } catch (error, stackTrace) {
      if (error is BudgetRepositoryException) {
        rethrow;
      }
      throw _mapException(error, stackTrace, actionName: actionName);
    }
  }

  BudgetRepositoryException _mapException(
    Object error,
    StackTrace stackTrace, {
    required String actionName,
  }) {
    if (error is supabase.PostgrestException) {
      return BudgetRepositoryException(
        message: _friendlyPostgrestMessage(error),
        actionName: actionName,
        code: error.code,
        details: error.details,
        cause: error,
        stackTrace: stackTrace,
      );
    }

    if (error is supabase.AuthException) {
      return BudgetRepositoryException(
        message: error.message,
        actionName: actionName,
        code: error.code ?? error.statusCode,
        cause: error,
        stackTrace: stackTrace,
      );
    }

    if (error is FormatException) {
      return BudgetRepositoryException(
        message: error.message,
        actionName: actionName,
        cause: error,
        stackTrace: stackTrace,
      );
    }

    return BudgetRepositoryException(
      message: 'Không thể xử lý ngân sách. Vui lòng thử lại.',
      actionName: actionName,
      cause: error,
      stackTrace: stackTrace,
    );
  }
}

class BudgetRepositoryException implements Exception {
  const BudgetRepositoryException({
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
    return 'BudgetRepositoryException$codeText: $actionName - $message';
  }
}

String _friendlyPostgrestMessage(supabase.PostgrestException error) {
  final lowerMessage = error.message.toLowerCase();
  if (lowerMessage.contains('row-level security')) {
    return 'Không thể lưu ngân sách vì household hiện tại không hợp lệ hoặc RLS không cho phép.';
  }

  switch (error.code) {
    case '23503':
      return 'Household hoặc danh mục của ngân sách không hợp lệ.';
    case '23505':
      return 'Ngân sách danh mục này đã tồn tại trong tháng đã chọn.';
    case '42501':
      return 'Bạn không có quyền xử lý ngân sách này. Vui lòng kiểm tra household hiện tại và RLS.';
    case 'PGRST116':
      return 'Không tìm thấy đúng một ngân sách phù hợp.';
    default:
      return error.message;
  }
}

String _normalizeHouseholdId(String value) {
  final cleanHouseholdId = value.trim();
  if (cleanHouseholdId.isEmpty) {
    throw const BudgetRepositoryException(
      message:
          'Bạn cần tạo hoặc tham gia household trước khi quản lý ngân sách.',
      actionName: 'Kiểm tra household hiện tại',
    );
  }
  return cleanHouseholdId;
}

String _normalizeCategoryId(String value) {
  final cleanCategoryId = value.trim();
  if (cleanCategoryId.isEmpty) {
    throw const BudgetRepositoryException(
      message: 'Vui lòng chọn danh mục chi tiêu.',
      actionName: 'Kiểm tra danh mục ngân sách',
    );
  }
  return cleanCategoryId;
}

void _validateMonthYear({required int month, required int year}) {
  if (month < 1 || month > 12) {
    throw const BudgetRepositoryException(
      message: 'Tháng ngân sách không hợp lệ.',
      actionName: 'Kiểm tra ngân sách',
    );
  }
  if (year < 2000) {
    throw const BudgetRepositoryException(
      message: 'Năm ngân sách không hợp lệ.',
      actionName: 'Kiểm tra ngân sách',
    );
  }
}

void _validateAmount(double amount) {
  if (amount < 0) {
    throw const BudgetRepositoryException(
      message: 'Ngân sách phải lớn hơn hoặc bằng 0.',
      actionName: 'Kiểm tra ngân sách',
    );
  }
}

int? _readInt(Object? value) {
  if (value == null || value.toString().trim().isEmpty) {
    return null;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value.toString());
}

int _compareBudget(Budget a, Budget b) {
  final orderCompare = a.displayOrder.compareTo(b.displayOrder);
  if (orderCompare != 0) {
    return orderCompare;
  }
  final yearCompare = a.year.compareTo(b.year);
  if (yearCompare != 0) {
    return yearCompare;
  }
  final monthCompare = a.month.compareTo(b.month);
  if (monthCompare != 0) {
    return monthCompare;
  }
  return a.categoryId.compareTo(b.categoryId);
}

List<Budget> _parseBudgetRows(Iterable<Map<String, dynamic>> rows) {
  final budgets = <Budget>[];
  for (final row in rows) {
    try {
      budgets.add(Budget.fromJson(row));
    } catch (error) {
      debugPrint('BUDGET ROW SKIPPED: $error');
    }
  }
  return budgets;
}

List<Map<String, dynamic>> _dedupeRowsById(
  Iterable<Map<String, dynamic>> rows, {
  required String entityName,
}) {
  final latestRowsById = <String, Map<String, dynamic>>{};

  for (final row in rows) {
    final rawId = row['id'];
    final id = rawId is String ? rawId : rawId?.toString();
    if (id == null || id.isEmpty) {
      continue;
    }
    latestRowsById[id] = row;
  }

  final deduplicatedRows = [...latestRowsById.values];
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
    throw BudgetRepositoryException(
      message: emptyMessage,
      actionName: actionName,
    );
  }
  throw BudgetRepositoryException(
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
