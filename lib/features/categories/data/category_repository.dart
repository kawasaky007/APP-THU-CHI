import 'package:flutter/foundation.dart' hide Category;
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:uuid/uuid.dart';

import '../../../core/models/models.dart';
import '../../../core/services/supabase_service.dart';

class CategoryRepository {
  CategoryRepository(this._supabaseService);

  final SupabaseService _supabaseService;
  final _uuid = const Uuid();

  supabase.SupabaseClient get _client => _supabaseService.client;

  Stream<List<Category>> watchCategories(String householdId) {
    final cleanHouseholdId = _normalizeHouseholdId(householdId);
    debugPrint('WATCH CATEGORIES STARTED: $cleanHouseholdId');

    return _client
        .from(SupabaseTables.categories)
        .stream(primaryKey: ['id'])
        .eq('household_id', cleanHouseholdId)
        .order('sort_order', ascending: true)
        .asyncMap((rows) {
          final deduplicatedRows = _dedupeRowsById(
            rows,
            entityName: 'CATEGORIES',
          );
          debugPrint('CATEGORIES REALTIME UPDATE: ${deduplicatedRows.length}');
          final categories = deduplicatedRows.map(Category.fromJson).toList();
          categories.sort(_compareCategory);
          return categories;
        });
  }

  Future<List<Category>> fetchCategories(String householdId) {
    return _guard('Lấy danh sách danh mục', () async {
      final cleanHouseholdId = _normalizeHouseholdId(householdId);
      final rows = await _client
          .from(SupabaseTables.categories)
          .select()
          .eq('household_id', cleanHouseholdId)
          .order('sort_order', ascending: true)
          .order('name', ascending: true);

      final categories = _asJsonList(rows).map(Category.fromJson).toList();
      categories.sort(_compareCategory);
      return categories;
    });
  }

  Future<Category> createCategory({
    required String householdId,
    required String name,
    required TransactionType type,
    required String color,
    required String icon,
  }) {
    return _guard('Tạo danh mục', () async {
      final cleanHouseholdId = _normalizeHouseholdId(householdId);
      final cleanName = _normalizeName(name);
      await _ensureUniqueName(
        householdId: cleanHouseholdId,
        name: cleanName,
        type: type,
      );

      final now = DateTime.now().toUtc();
      final sortOrder = await _nextSortOrder(cleanHouseholdId, type);
      final draft = Category(
        id: _uuid.v4(),
        householdId: cleanHouseholdId,
        name: cleanName,
        type: type,
        color: color,
        icon: icon,
        sortOrder: sortOrder,
        createdAt: now,
        updatedAt: now,
      );

      final row = await _client
          .from(SupabaseTables.categories)
          .insert(_categoryInsertPayload(draft))
          .select();

      return Category.fromJson(
        _requireSingleJsonMap(
          row,
          actionName: 'Tạo danh mục',
          emptyMessage:
              'Không thể tạo danh mục. Vui lòng kiểm tra quyền ghi dữ liệu.',
          multipleMessage:
              'Tạo danh mục trả về nhiều dòng bất thường. Vui lòng kiểm tra database.',
        ),
      );
    });
  }

  Future<Category> updateCategory({
    required Category category,
    required String name,
    required TransactionType type,
    required String color,
    required String icon,
  }) {
    return _guard('Cập nhật danh mục', () async {
      final cleanHouseholdId = _normalizeHouseholdId(category.householdId);
      final cleanName = _normalizeName(name);
      await _ensureUniqueName(
        householdId: cleanHouseholdId,
        name: cleanName,
        type: type,
        exceptCategoryId: category.id,
      );

      final updatedCategory = category.copyWith(
        householdId: cleanHouseholdId,
        name: cleanName,
        type: type,
        color: color,
        icon: icon,
        updatedAt: DateTime.now().toUtc(),
      );

      final row = await _client
          .from(SupabaseTables.categories)
          .update(_categoryUpdatePayload(updatedCategory))
          .eq('id', category.id)
          .eq('household_id', cleanHouseholdId)
          .select();

      return Category.fromJson(
        _requireSingleJsonMap(
          row,
          actionName: 'Cập nhật danh mục',
          emptyMessage:
              'Không thể cập nhật danh mục. Vui lòng kiểm tra quyền truy cập.',
          multipleMessage:
              'Dữ liệu danh mục bị trùng khi cập nhật. Vui lòng kiểm tra database.',
        ),
      );
    });
  }

  Future<void> deleteCategory(Category category) {
    return _guard('Xóa danh mục', () async {
      final cleanHouseholdId = _normalizeHouseholdId(category.householdId);
      final row = await _client
          .from(SupabaseTables.categories)
          .delete()
          .eq('id', category.id)
          .eq('household_id', cleanHouseholdId)
          .select('id');

      _requireSingleJsonMap(
        row,
        actionName: 'Xóa danh mục',
        emptyMessage:
            'Không thể xóa danh mục. Danh mục không tồn tại hoặc bạn không có quyền.',
        multipleMessage:
            'Dữ liệu danh mục bị trùng khi xóa. Vui lòng kiểm tra database.',
      );
    });
  }

  Future<void> _ensureUniqueName({
    required String householdId,
    required String name,
    required TransactionType type,
    String? exceptCategoryId,
  }) async {
    final cleanHouseholdId = _normalizeHouseholdId(householdId);
    dynamic query = _client
        .from(SupabaseTables.categories)
        .select('id')
        .eq('household_id', cleanHouseholdId)
        .eq('type', type.value)
        .ilike('name', name);

    if (exceptCategoryId != null) {
      query = query.neq('id', exceptCategoryId);
    }

    final rows = await query.limit(1);
    if (_asJsonList(rows).isNotEmpty) {
      throw const CategoryRepositoryException(
        message: 'Tên danh mục này đã tồn tại trong cùng loại thu/chi.',
        actionName: 'Kiểm tra danh mục',
      );
    }
  }

  Future<int> _nextSortOrder(String householdId, TransactionType type) async {
    final cleanHouseholdId = _normalizeHouseholdId(householdId);
    final rows = await _client
        .from(SupabaseTables.categories)
        .select('sort_order')
        .eq('household_id', cleanHouseholdId)
        .eq('type', type.value)
        .order('sort_order', ascending: false)
        .limit(1);

    final firstRow = _asJsonList(rows).firstOrNull;
    final currentMax = firstRow?['sort_order'];
    if (currentMax is num) {
      return currentMax.toInt() + 1;
    }
    return 0;
  }

  Future<T> _guard<T>(String actionName, Future<T> Function() action) async {
    try {
      return await action();
    } catch (error, stackTrace) {
      if (error is CategoryRepositoryException) {
        rethrow;
      }
      throw _mapException(error, stackTrace, actionName: actionName);
    }
  }

  CategoryRepositoryException _mapException(
    Object error,
    StackTrace stackTrace, {
    required String actionName,
  }) {
    if (error is supabase.PostgrestException) {
      return CategoryRepositoryException(
        message: _friendlyPostgrestMessage(error),
        actionName: actionName,
        code: error.code,
        details: error.details,
        cause: error,
        stackTrace: stackTrace,
      );
    }

    if (error is supabase.AuthException) {
      return CategoryRepositoryException(
        message: error.message,
        actionName: actionName,
        code: error.code ?? error.statusCode,
        cause: error,
        stackTrace: stackTrace,
      );
    }

    if (error is FormatException) {
      return CategoryRepositoryException(
        message: error.message,
        actionName: actionName,
        cause: error,
        stackTrace: stackTrace,
      );
    }

    return CategoryRepositoryException(
      message: 'Không thể xử lý danh mục. Vui lòng thử lại.',
      actionName: actionName,
      cause: error,
      stackTrace: stackTrace,
    );
  }
}

class CategoryRepositoryException implements Exception {
  const CategoryRepositoryException({
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
    return 'CategoryRepositoryException$codeText: $actionName - $message';
  }
}

String _friendlyPostgrestMessage(supabase.PostgrestException error) {
  final lowerMessage = error.message.toLowerCase();
  if (lowerMessage.contains('row-level security')) {
    return 'Không thể lưu danh mục vì household hiện tại không hợp lệ hoặc RLS không cho phép.';
  }

  switch (error.code) {
    case '23503':
      return 'Household của danh mục không hợp lệ hoặc danh mục đang được dùng trong giao dịch.';
    case '23505':
      return 'Danh mục này đã tồn tại.';
    case '42501':
      return 'Bạn không có quyền xử lý danh mục này. Vui lòng kiểm tra household hiện tại và RLS.';
    case 'PGRST116':
      return 'Không tìm thấy đúng một danh mục phù hợp.';
    default:
      return error.message;
  }
}

String _normalizeHouseholdId(String value) {
  final cleanHouseholdId = value.trim();
  if (cleanHouseholdId.isEmpty) {
    throw const CategoryRepositoryException(
      message: 'Bạn cần tạo hoặc tham gia household trước khi thêm danh mục.',
      actionName: 'Kiểm tra household hiện tại',
    );
  }
  return cleanHouseholdId;
}

String _normalizeName(String value) {
  final cleanName = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (cleanName.length < 2) {
    throw const CategoryRepositoryException(
      message: 'Tên danh mục cần tối thiểu 2 ký tự.',
      actionName: 'Kiểm tra danh mục',
    );
  }
  return cleanName;
}

Map<String, dynamic> _categoryInsertPayload(Category category) {
  final payload = category.toJson();
  final householdId = _normalizeHouseholdId(category.householdId);
  payload['household_id'] = householdId;
  return payload;
}

Map<String, dynamic> _categoryUpdatePayload(Category category) {
  final updatedAt = category.updatedAt;
  return {
    'household_id': _normalizeHouseholdId(category.householdId),
    'name': category.name,
    'type': category.type.value,
    'color': category.color,
    'icon': category.icon,
    'sort_order': category.sortOrder,
    if (updatedAt != null) 'updated_at': updatedAt.toIso8601String(),
  };
}

int _compareCategory(Category a, Category b) {
  final typeCompare = a.type.index.compareTo(b.type.index);
  if (typeCompare != 0) {
    return typeCompare;
  }

  final sortCompare = a.sortOrder.compareTo(b.sortOrder);
  if (sortCompare != 0) {
    return sortCompare;
  }

  return a.name.toLowerCase().compareTo(b.name.toLowerCase());
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
    throw CategoryRepositoryException(
      message: emptyMessage,
      actionName: actionName,
    );
  }
  throw CategoryRepositoryException(
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
