import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_constants.dart';
import '../models/models.dart';

class SupabaseService {
  SupabaseService._();

  static final SupabaseService instance = SupabaseService._();

  final ValueNotifier<bool> _loadingNotifier = ValueNotifier(false);
  final ValueNotifier<SupabaseServiceException?> _errorNotifier = ValueNotifier(
    null,
  );

  int _runningRequests = 0;
  bool _isInitialized = false;

  SupabaseClient get client => Supabase.instance.client;

  bool get isInitialized => _isInitialized;
  bool get isLoading => _loadingNotifier.value;
  SupabaseServiceException? get lastError => _errorNotifier.value;

  ValueListenable<bool> get loadingListenable => _loadingNotifier;
  ValueListenable<SupabaseServiceException?> get errorListenable =>
      _errorNotifier;

  /// Load .env và khởi tạo Supabase. Gọi một lần ở main.dart.
  Future<void> initialize({
    String envFileName = AppConstants.envFileName,
  }) async {
    if (_isInitialized) {
      return;
    }

    _startLoading();
    try {
      if (!dotenv.isInitialized) {
        await dotenv.load(fileName: envFileName);
      }

      AppConstants.validateEnvironment();

      await Supabase.initialize(
        url: AppConstants.supabaseUrl,
        anonKey: AppConstants.supabaseAnonKey,
      );

      _isInitialized = true;
      _clearError();
    } catch (error, stackTrace) {
      final exception = _mapException(
        error,
        stackTrace,
        actionName: 'Khởi tạo Supabase',
      );
      _setError(exception);
      throw exception;
    } finally {
      _stopLoading();
    }
  }

  /// User id hiện tại từ Supabase Auth. Trả về null nếu chưa đăng nhập.
  String? getCurrentUserId() {
    return client.auth.currentUser?.id;
  }

  /// Household id hiện tại lấy từ bảng profiles.
  Future<String?> getCurrentHouseholdId() async {
    final result = await getCurrentHouseholdIdResult();
    final error = result.error;
    if (error != null) {
      throw error;
    }
    return result.data;
  }

  Future<ServiceResult<String?>> getCurrentHouseholdIdResult() async {
    return execute<String?>(
      actionName: 'Lấy household hiện tại',
      action: (client) async {
        final userId = getCurrentUserId();
        if (userId == null) {
          return null;
        }

        final row = await client
            .from(SupabaseTables.userProfiles)
            .select('household_id')
            .eq('id', userId)
            .maybeSingle();

        return row?['household_id']?.toString();
      },
    );
  }

  Future<ServiceResult<UserProfile?>> getCurrentUserProfile() async {
    return execute<UserProfile?>(
      actionName: 'Lấy hồ sơ người dùng hiện tại',
      action: (client) async {
        final userId = getCurrentUserId();
        if (userId == null) {
          return null;
        }

        final row = await client
            .from(SupabaseTables.userProfiles)
            .select()
            .eq('id', userId)
            .maybeSingle();

        if (row == null) {
          return null;
        }
        return UserProfile.fromJson(_asJsonMap(row));
      },
    );
  }

  Future<ServiceResult<UserProfile>> upsertUserProfile(
    UserProfile profile,
  ) async {
    return execute<UserProfile>(
      actionName: 'Lưu hồ sơ người dùng',
      action: (client) async {
        final row = await client
            .from(SupabaseTables.userProfiles)
            .upsert(profile.toJson())
            .select();

        return UserProfile.fromJson(
          _requireSingleJsonMap(
            row,
            actionName: 'Lưu hồ sơ người dùng',
            emptyMessage:
                'Không thể lưu hồ sơ người dùng. Vui lòng kiểm tra RLS profiles.',
            multipleMessage:
                'Dữ liệu hồ sơ người dùng bị trùng. Vui lòng kiểm tra database.',
          ),
        );
      },
    );
  }

  Future<ServiceResult<Household?>> getHouseholdById(String householdId) async {
    return execute<Household?>(
      actionName: 'Lấy thông tin household',
      action: (client) async {
        final row = await client
            .from(SupabaseTables.households)
            .select()
            .eq('id', householdId)
            .maybeSingle();

        if (row == null) {
          return null;
        }
        return Household.fromJson(_asJsonMap(row));
      },
    );
  }

  Future<ServiceResult<Household?>> getCurrentHousehold() async {
    final householdId = await getCurrentHouseholdId();
    if (householdId == null) {
      return ServiceResult.success(null);
    }
    return getHouseholdById(householdId);
  }

  Future<ServiceResult<List<Category>>> getCategories({
    String? householdId,
    TransactionType? type,
  }) async {
    return execute<List<Category>>(
      actionName: 'Lấy danh mục thu chi',
      action: (client) async {
        final resolvedHouseholdId =
            householdId ?? await _getCurrentHouseholdIdWithoutLoading();
        if (resolvedHouseholdId == null) {
          return const [];
        }

        dynamic query = client
            .from(SupabaseTables.categories)
            .select()
            .eq('household_id', resolvedHouseholdId);

        if (type != null) {
          query = query.eq('type', type.value);
        }

        final rows = await query.order('sort_order').order('name');
        return _asJsonList(rows).map(Category.fromJson).toList();
      },
    );
  }

  Future<ServiceResult<Category>> upsertCategory(Category category) async {
    return execute<Category>(
      actionName: 'Lưu danh mục',
      action: (client) async {
        final payload = _categoryUpsertPayload(category);
        final row = await client
            .from(SupabaseTables.categories)
            .upsert(payload)
            .select();

        return Category.fromJson(
          _requireSingleJsonMap(
            row,
            actionName: 'Lưu danh mục',
            emptyMessage:
                'Không thể lưu danh mục. Vui lòng kiểm tra quyền truy cập.',
            multipleMessage:
                'Dữ liệu danh mục bị trùng. Vui lòng kiểm tra database.',
          ),
        );
      },
    );
  }

  Future<ServiceResult<List<Transaction>>> getTransactions({
    String? householdId,
    DateTime? fromDate,
    DateTime? toDate,
    TransactionType? type,
  }) async {
    return execute<List<Transaction>>(
      actionName: 'Lấy danh sách giao dịch',
      action: (client) async {
        final resolvedHouseholdId =
            householdId ?? await _getCurrentHouseholdIdWithoutLoading();
        if (resolvedHouseholdId == null) {
          return const [];
        }

        dynamic query = client
            .from(SupabaseTables.transactions)
            .select()
            .eq('household_id', resolvedHouseholdId);

        if (fromDate != null) {
          query = query.gte('transaction_date', fromDate.toIso8601String());
        }
        if (toDate != null) {
          query = query.lte('transaction_date', toDate.toIso8601String());
        }
        if (type != null) {
          query = query.eq('type', type.value);
        }

        final rows = await query.order('transaction_date', ascending: false);

        return _asJsonList(rows).map(Transaction.fromJson).toList();
      },
    );
  }

  Future<ServiceResult<Transaction>> createTransaction(
    Transaction transaction,
  ) async {
    return execute<Transaction>(
      actionName: 'Tạo giao dịch',
      action: (client) async {
        final row = await client
            .from(SupabaseTables.transactions)
            .insert(transaction.toJson())
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
      },
    );
  }

  Future<ServiceResult<Transaction>> updateTransaction(
    Transaction transaction,
  ) async {
    return execute<Transaction>(
      actionName: 'Cập nhật giao dịch',
      action: (client) async {
        final row = await client
            .from(SupabaseTables.transactions)
            .update(transaction.toJson())
            .eq('id', transaction.id)
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
      },
    );
  }

  Future<ServiceResult<void>> deleteTransaction(String transactionId) async {
    return execute<void>(
      actionName: 'Xóa giao dịch',
      action: (client) async {
        final row = await client
            .from(SupabaseTables.transactions)
            .delete()
            .eq('id', transactionId)
            .select('id');

        _requireSingleJsonMap(
          row,
          actionName: 'Xóa giao dịch',
          emptyMessage:
              'Không thể xóa giao dịch. Giao dịch không tồn tại hoặc bạn không có quyền.',
          multipleMessage:
              'Dữ liệu giao dịch bị trùng khi xóa. Vui lòng kiểm tra database.',
        );
      },
    );
  }

  /// Wrapper dùng chung cho repository/service để có loading + error đồng nhất.
  Future<ServiceResult<T>> execute<T>({
    required String actionName,
    required Future<T> Function(SupabaseClient client) action,
  }) async {
    _startLoading();
    _clearError();

    try {
      final data = await action(client);
      return ServiceResult.success(data);
    } catch (error, stackTrace) {
      final exception = _mapException(
        error,
        stackTrace,
        actionName: actionName,
      );
      _setError(exception);
      return ServiceResult.failure(exception);
    } finally {
      _stopLoading();
    }
  }

  Future<String?> _getCurrentHouseholdIdWithoutLoading() async {
    final userId = getCurrentUserId();
    if (userId == null) {
      return null;
    }

    final row = await client
        .from(SupabaseTables.userProfiles)
        .select('household_id')
        .eq('id', userId)
        .maybeSingle();

    return row?['household_id']?.toString();
  }

  void _startLoading() {
    _runningRequests++;
    _loadingNotifier.value = true;
  }

  void _stopLoading() {
    if (_runningRequests > 0) {
      _runningRequests--;
    }
    _loadingNotifier.value = _runningRequests > 0;
  }

  void _clearError() {
    _errorNotifier.value = null;
  }

  void _setError(SupabaseServiceException exception) {
    _errorNotifier.value = exception;
  }

  SupabaseServiceException _mapException(
    Object error,
    StackTrace stackTrace, {
    required String actionName,
  }) {
    if (error is SupabaseServiceException) {
      return error;
    }

    if (error is AuthException) {
      return SupabaseServiceException(
        message: error.message,
        actionName: actionName,
        code: error.code ?? error.statusCode,
        cause: error,
        stackTrace: stackTrace,
      );
    }

    if (error is PostgrestException) {
      return SupabaseServiceException(
        message: _friendlyPostgrestMessage(error),
        actionName: actionName,
        code: error.code,
        details: error.details,
        cause: error,
        stackTrace: stackTrace,
      );
    }

    if (error is StorageException) {
      return SupabaseServiceException(
        message: error.message,
        actionName: actionName,
        code: error.error ?? error.statusCode,
        cause: error,
        stackTrace: stackTrace,
      );
    }

    if (error is FormatException) {
      return SupabaseServiceException(
        message: error.message,
        actionName: actionName,
        cause: error,
        stackTrace: stackTrace,
      );
    }

    return SupabaseServiceException(
      message: 'Có lỗi không xác định. Vui lòng thử lại.',
      actionName: actionName,
      cause: error,
      stackTrace: stackTrace,
    );
  }
}

class ServiceResult<T> {
  const ServiceResult._({
    required this.data,
    required this.error,
    required this.isLoading,
  });

  final T? data;
  final SupabaseServiceException? error;
  final bool isLoading;

  bool get hasError => error != null;
  bool get isSuccess => error == null && !isLoading;

  factory ServiceResult.loading() {
    return const ServiceResult._(data: null, error: null, isLoading: true);
  }

  factory ServiceResult.success(T data) {
    return ServiceResult._(data: data, error: null, isLoading: false);
  }

  factory ServiceResult.failure(SupabaseServiceException error) {
    return ServiceResult._(data: null, error: error, isLoading: false);
  }

  T requireData() {
    final error = this.error;
    if (error != null) {
      throw error;
    }
    return data as T;
  }
}

class SupabaseServiceException implements Exception {
  const SupabaseServiceException({
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
    return 'SupabaseServiceException$codeText: $actionName - $message';
  }
}

class SupabaseTables {
  SupabaseTables._();

  static const userProfiles = 'profiles';
  static const users = userProfiles;
  static const households = 'households';
  static const categories = 'categories';
  static const transactions = 'transactions';
  static const budgets = 'budgets';
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
    throw SupabaseServiceException(
      message: emptyMessage,
      actionName: actionName,
    );
  }
  throw SupabaseServiceException(
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

String _friendlyPostgrestMessage(PostgrestException error) {
  final lowerMessage = error.message.toLowerCase();
  if (lowerMessage.contains('row-level security')) {
    return 'Không thể lưu dữ liệu vì household hiện tại không hợp lệ hoặc RLS không cho phép.';
  }

  switch (error.code) {
    case '23503':
      return 'Dữ liệu liên kết không hợp lệ.';
    case '23505':
      return 'Dữ liệu này đã tồn tại.';
    case '42501':
      return 'Bạn không có quyền truy cập dữ liệu này. Vui lòng kiểm tra RLS.';
    case 'PGRST116':
      return 'Không tìm thấy đúng một dòng dữ liệu phù hợp.';
    default:
      return error.message;
  }
}

Map<String, dynamic> _categoryUpsertPayload(Category category) {
  final payload = category.toJson();
  payload['household_id'] = _normalizeRequiredId(
    category.householdId,
    emptyMessage: 'Bạn cần tạo hoặc tham gia household trước khi lưu danh mục.',
  );
  return payload;
}

String _normalizeRequiredId(String value, {required String emptyMessage}) {
  final cleanValue = value.trim();
  if (cleanValue.isEmpty) {
    throw SupabaseServiceException(
      message: emptyMessage,
      actionName: 'Kiểm tra dữ liệu',
    );
  }
  return cleanValue;
}
