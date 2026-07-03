import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../core/models/models.dart';
import '../../../core/services/supabase_service.dart';

class ProfileRepository {
  ProfileRepository(this._supabaseService);

  final SupabaseService _supabaseService;

  supabase.SupabaseClient get _client => _supabaseService.client;

  Stream<List<UserProfile>> watchProfiles(String householdId) {
    debugPrint('WATCH PROFILES STARTED: $householdId');

    return _client
        .from(SupabaseTables.userProfiles)
        .stream(primaryKey: ['id'])
        .eq('household_id', householdId)
        .asyncMap((rows) {
          final deduplicatedRows = _dedupeRowsById(
            rows,
            entityName: 'PROFILES',
          );
          debugPrint('PROFILES REALTIME UPDATE: ${deduplicatedRows.length}');
          return deduplicatedRows.map(UserProfile.fromJson).toList();
        });
  }

  Future<List<UserProfile>> fetchProfiles(String householdId) async {
    final rows = await _client
        .from(SupabaseTables.userProfiles)
        .select()
        .eq('household_id', householdId);

    return rows.map((row) => UserProfile.fromJson(row)).toList();
  }

  Future<UserProfile> updateUserProfileName(String fullName) {
    return _guard('Cập nhật tên hiển thị', () async {
      final userId = _client.auth.currentUser?.id;
      if (userId == null || userId.trim().isEmpty) {
        throw const ProfileRepositoryException(
          message: 'Bạn cần đăng nhập để cập nhật hồ sơ.',
          actionName: 'Cập nhật tên hiển thị',
        );
      }

      final cleanName = _normalizeFullName(fullName);
      final row = await _client
          .from(SupabaseTables.users)
          .update({
            'full_name': cleanName,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', userId)
          .select();

      return UserProfile.fromJson(
        _requireSingleJsonMap(
          row,
          actionName: 'Cập nhật tên hiển thị',
          emptyMessage:
              'Không thể cập nhật tên. Hồ sơ không tồn tại hoặc bạn không có quyền.',
          multipleMessage:
              'Dữ liệu hồ sơ bị trùng khi cập nhật. Vui lòng kiểm tra database.',
        ),
      );
    });
  }

  Future<T> _guard<T>(String actionName, Future<T> Function() action) async {
    try {
      return await action();
    } catch (error, stackTrace) {
      if (error is ProfileRepositoryException) {
        rethrow;
      }
      throw _mapException(error, stackTrace, actionName: actionName);
    }
  }

  ProfileRepositoryException _mapException(
    Object error,
    StackTrace stackTrace, {
    required String actionName,
  }) {
    if (error is supabase.PostgrestException) {
      return ProfileRepositoryException(
        message: _friendlyPostgrestMessage(error),
        actionName: actionName,
        code: error.code,
        details: error.details,
        cause: error,
        stackTrace: stackTrace,
      );
    }

    if (error is supabase.AuthException) {
      return ProfileRepositoryException(
        message: error.message,
        actionName: actionName,
        code: error.code ?? error.statusCode,
        cause: error,
        stackTrace: stackTrace,
      );
    }

    if (error is FormatException) {
      return ProfileRepositoryException(
        message: error.message,
        actionName: actionName,
        cause: error,
        stackTrace: stackTrace,
      );
    }

    return ProfileRepositoryException(
      message: 'Không thể cập nhật hồ sơ. Vui lòng thử lại.',
      actionName: actionName,
      cause: error,
      stackTrace: stackTrace,
    );
  }
}

class ProfileRepositoryException implements Exception {
  const ProfileRepositoryException({
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
    return 'ProfileRepositoryException$codeText: $actionName - $message';
  }
}

String _normalizeFullName(String value) {
  final cleanName = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (cleanName.isEmpty) {
    throw const ProfileRepositoryException(
      message: 'Tên hiển thị không được để trống.',
      actionName: 'Kiểm tra tên hiển thị',
    );
  }
  if (cleanName.length > 50) {
    throw const ProfileRepositoryException(
      message: 'Tên hiển thị tối đa 50 ký tự.',
      actionName: 'Kiểm tra tên hiển thị',
    );
  }
  return cleanName;
}

String _friendlyPostgrestMessage(supabase.PostgrestException error) {
  switch (error.code) {
    case '42501':
      return 'Bạn không có quyền cập nhật hồ sơ này. Vui lòng kiểm tra RLS.';
    case 'PGRST116':
      return 'Không tìm thấy đúng một hồ sơ phù hợp.';
    default:
      return error.message;
  }
}

List<Map<String, dynamic>> _dedupeRowsById(
  Iterable<Map<String, dynamic>> rows, {
  required String entityName,
}) {
  final latestRowsById = <String, Map<String, dynamic>>{};
  final rowsWithoutId = <Map<String, dynamic>>[];

  for (final row in rows) {
    final id = row['id']?.toString();
    if (id == null || id.isEmpty) {
      rowsWithoutId.add(row);
      continue;
    }
    latestRowsById[id] = row;
  }

  final deduplicatedRows = [...latestRowsById.values, ...rowsWithoutId];
  final removed = rows.length - deduplicatedRows.length;
  if (removed > 0) {
    debugPrint('$entityName REALTIME DEDUPED: removed=$removed');
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
    throw ProfileRepositoryException(
      message: emptyMessage,
      actionName: actionName,
    );
  }
  throw ProfileRepositoryException(
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
