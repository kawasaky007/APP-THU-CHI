import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../core/models/models.dart';
import '../../../core/services/supabase_service.dart';
import '../../household/data/household_repository.dart';

class AuthSessionData {
  const AuthSessionData({
    required this.user,
    required this.profile,
    required this.household,
  });

  final supabase.User user;
  final UserProfile profile;
  final Household? household;

  bool get hasHousehold => household != null && profile.householdId != null;
}

class AuthRepository {
  AuthRepository({
    required SupabaseService supabaseService,
    required HouseholdRepository householdRepository,
  }) : _supabaseService = supabaseService,
       _householdRepository = householdRepository;

  final SupabaseService _supabaseService;
  final HouseholdRepository _householdRepository;

  supabase.SupabaseClient get _client => _supabaseService.client;

  Stream<supabase.AuthState> get authStateChanges {
    return _client.auth.onAuthStateChange;
  }

  supabase.User? get currentUser => _client.auth.currentUser;

  Future<AuthSessionData?> restoreSession() {
    return _guard('Khôi phục phiên đăng nhập', () async {
      final user = currentUser;
      if (user == null) {
        return null;
      }
      return _buildSession(user);
    });
  }

  Future<AuthSessionData> refreshCurrentSession() {
    return _guard('Làm mới phiên đăng nhập', () async {
      final user = _requireCurrentUser();
      return _buildSession(user);
    });
  }

  Future<AuthSessionData> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _guard('Đăng nhập', () async {
      final response = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      final user = response.user ?? currentUser;
      if (user == null) {
        throw const AuthRepositoryException(
          message: 'Không thể lấy thông tin người dùng sau khi đăng nhập.',
          actionName: 'Đăng nhập',
        );
      }

      return _buildSession(user);
    });
  }

  Future<AuthSessionData> registerWithEmail({
    required String email,
    required String password,
    required String fullName,
  }) {
    return _guard('Đăng ký tài khoản', () async {
      final cleanEmail = email.trim();
      final cleanFullName = fullName.trim();

      final response = await _client.auth.signUp(
        email: cleanEmail,
        password: password,
        data: {'full_name': cleanFullName},
      );

      final user = response.user ?? currentUser;
      if (user == null) {
        throw const AuthRepositoryException(
          message: 'Không thể lấy thông tin người dùng sau khi đăng ký.',
          actionName: 'Đăng ký tài khoản',
        );
      }

      // Khi Supabase bật xác nhận email, session có thể chưa được tạo.
      // Khi đó không thể ghi profile dưới RLS của user hiện tại.
      if (_client.auth.currentSession == null) {
        throw const AuthRepositoryException(
          message:
              'Tài khoản đã được tạo. Vui lòng xác nhận email rồi đăng nhập để hoàn tất household.',
          actionName: 'Đăng ký tài khoản',
        );
      }

      final profile = await _upsertProfileForUser(
        user: user,
        fullName: cleanFullName,
      );

      return AuthSessionData(user: user, profile: profile, household: null);
    });
  }

  Future<AuthSessionData> createHouseholdForCurrentUser({
    required String name,
  }) {
    return _guard('Tạo household mới', () async {
      final user = _requireCurrentUser();
      final profile = await _getOrCreateProfileForUser(user);

      final membership = await _householdRepository.createHouseholdForProfile(
        profile: profile,
        name: name,
      );

      return AuthSessionData(
        user: user,
        profile: membership.profile,
        household: membership.household,
      );
    });
  }

  Future<AuthSessionData> joinHouseholdByInviteCode(String inviteCode) {
    return _guard('Tham gia household', () async {
      final user = _requireCurrentUser();
      final profile = await _getOrCreateProfileForUser(user);

      final membership = await _householdRepository.joinByInviteCode(
        profile: profile,
        inviteCode: inviteCode,
      );

      return AuthSessionData(
        user: user,
        profile: membership.profile,
        household: membership.household,
      );
    });
  }

  Future<AuthSessionData> updateCurrentHouseholdName(String name) {
    return _guard('Đổi tên household', () async {
      final user = _requireCurrentUser();
      final profile = await _getOrCreateProfileForUser(user);
      final householdId = profile.householdId;

      if (householdId == null || householdId.isEmpty) {
        throw const AuthRepositoryException(
          message: 'Bạn chưa tham gia household nào.',
          actionName: 'Đổi tên household',
        );
      }

      final household = await _householdRepository.getById(householdId);
      if (household == null) {
        throw const AuthRepositoryException(
          message: 'Không tìm thấy household hiện tại.',
          actionName: 'Đổi tên household',
        );
      }

      final updatedHousehold = await _householdRepository.updateHouseholdName(
        household: household,
        name: name,
      );

      return AuthSessionData(
        user: user,
        profile: _profileWithHouseholdRole(
          profile: profile,
          household: updatedHousehold,
        ),
        household: updatedHousehold,
      );
    });
  }

  Future<AuthSessionData> leaveCurrentHousehold() {
    return _guard('Thoát household', () async {
      final user = _requireCurrentUser();
      final profile = await _getOrCreateProfileForUser(user);
      final householdId = profile.householdId;

      if (householdId == null || householdId.isEmpty) {
        throw const AuthRepositoryException(
          message: 'Bạn chưa tham gia household nào.',
          actionName: 'Thoát household',
        );
      }

      final household = await _householdRepository.getById(householdId);
      if (household?.ownerId == user.id) {
        throw const AuthRepositoryException(
          message:
              'Chủ household không thể thoát. Hãy xóa household nếu muốn dừng dùng không gian này.',
          actionName: 'Thoát household',
        );
      }

      final updatedProfile = await _householdRepository.leaveHousehold(
        profile: profile,
      );

      return AuthSessionData(
        user: user,
        profile: updatedProfile,
        household: null,
      );
    });
  }

  Future<AuthSessionData> deleteCurrentHousehold() {
    return _guard('Xóa household', () async {
      final user = _requireCurrentUser();
      final profile = await _getOrCreateProfileForUser(user);
      final householdId = profile.householdId;

      if (householdId == null || householdId.isEmpty) {
        throw const AuthRepositoryException(
          message: 'Bạn chưa tham gia household nào.',
          actionName: 'Xóa household',
        );
      }

      final household = await _householdRepository.getById(householdId);
      if (household == null) {
        throw const AuthRepositoryException(
          message: 'Không tìm thấy household hiện tại.',
          actionName: 'Xóa household',
        );
      }

      if (household.ownerId != user.id) {
        throw const AuthRepositoryException(
          message: 'Chỉ chủ household mới có quyền xóa household.',
          actionName: 'Xóa household',
        );
      }

      final updatedProfile = await _householdRepository.deleteHousehold(
        household: household,
        ownerProfile: profile,
      );

      return AuthSessionData(
        user: user,
        profile: updatedProfile,
        household: null,
      );
    });
  }

  Future<void> signOut() {
    return _guard('Đăng xuất', () async {
      await _client.auth.signOut();
    });
  }

  Future<AuthSessionData> _buildSession(supabase.User user) async {
    final profile = await _getOrCreateProfileForUser(user);
    Household? household;

    final householdId = profile.householdId;
    if (householdId != null && householdId.isNotEmpty) {
      household = await _householdRepository.getById(householdId);
    }

    return AuthSessionData(
      user: user,
      profile: _profileWithHouseholdRole(
        profile: profile,
        household: household,
      ),
      household: household,
    );
  }

  Future<UserProfile> _getOrCreateProfileForUser(supabase.User user) async {
    final existingProfile = await _loadProfile(user.id);
    return _upsertProfileForUser(user: user, existingProfile: existingProfile);
  }

  Future<UserProfile?> _loadProfile(String userId) async {
    final row = await _client
        .from(SupabaseTables.userProfiles)
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (row == null) {
      return null;
    }
    return UserProfile.fromJson(_asJsonMap(row));
  }

  Future<UserProfile> _upsertProfileForUser({
    required supabase.User user,
    String? fullName,
    UserProfile? existingProfile,
  }) async {
    final resolvedProfile = existingProfile ?? await _loadProfile(user.id);
    final resolvedName = _resolveFullName(
      user: user,
      explicitFullName: fullName,
      fallbackFullName: resolvedProfile?.fullName,
    );

    final profile = UserProfile(
      id: user.id,
      email: user.email ?? resolvedProfile?.email ?? '${user.id}@unknown.local',
      fullName: resolvedName,
      householdId: resolvedProfile?.householdId,
      avatarUrl: resolvedProfile?.avatarUrl,
      phoneNumber: resolvedProfile?.phoneNumber,
      role: resolvedProfile?.role ?? UserProfileRole.member,
      createdAt: resolvedProfile?.createdAt,
      updatedAt: DateTime.now().toUtc(),
    );

    final row = await _client
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
  }

  supabase.User _requireCurrentUser() {
    final user = currentUser;
    if (user == null) {
      throw const AuthRepositoryException(
        message: 'Bạn cần đăng nhập để tiếp tục.',
        actionName: 'Kiểm tra phiên đăng nhập',
      );
    }
    return user;
  }

  Future<T> _guard<T>(String actionName, Future<T> Function() action) async {
    try {
      return await action();
    } catch (error, stackTrace) {
      if (error is AuthRepositoryException) {
        rethrow;
      }
      if (error is HouseholdRepositoryException) {
        throw AuthRepositoryException(
          message: error.message,
          actionName: error.actionName,
          code: error.code,
          details: error.details,
          cause: error,
          stackTrace: error.stackTrace ?? stackTrace,
        );
      }
      throw _mapException(error, stackTrace, actionName: actionName);
    }
  }

  AuthRepositoryException _mapException(
    Object error,
    StackTrace stackTrace, {
    required String actionName,
  }) {
    if (error is supabase.AuthException) {
      return AuthRepositoryException(
        message: _friendlyAuthMessage(error.message),
        actionName: actionName,
        code: error.code ?? error.statusCode,
        cause: error,
        stackTrace: stackTrace,
      );
    }

    if (error is supabase.PostgrestException) {
      return AuthRepositoryException(
        message: _friendlyPostgrestMessage(error),
        actionName: actionName,
        code: error.code,
        details: error.details,
        cause: error,
        stackTrace: stackTrace,
      );
    }

    if (error is FormatException) {
      return AuthRepositoryException(
        message: error.message,
        actionName: actionName,
        cause: error,
        stackTrace: stackTrace,
      );
    }

    return AuthRepositoryException(
      message: 'Có lỗi xảy ra. Vui lòng thử lại.',
      actionName: actionName,
      cause: error,
      stackTrace: stackTrace,
    );
  }
}

class AuthRepositoryException implements Exception {
  const AuthRepositoryException({
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
    return 'AuthRepositoryException$codeText: $actionName - $message';
  }
}

UserProfile _profileWithHouseholdRole({
  required UserProfile profile,
  required Household? household,
}) {
  if (household == null || profile.householdId != household.id) {
    return profile.copyWith(role: UserProfileRole.member);
  }

  final role = household.ownerId == profile.id
      ? UserProfileRole.owner
      : UserProfileRole.partner;
  return profile.copyWith(role: role);
}

String _resolveFullName({
  required supabase.User user,
  String? explicitFullName,
  String? fallbackFullName,
}) {
  final cleanExplicitName = explicitFullName?.trim();
  if (cleanExplicitName != null && cleanExplicitName.isNotEmpty) {
    return cleanExplicitName;
  }

  final metadataName = user.userMetadata?['full_name']?.toString().trim();
  if (metadataName != null && metadataName.isNotEmpty) {
    return metadataName;
  }

  final cleanFallbackName = fallbackFullName?.trim();
  if (cleanFallbackName != null && cleanFallbackName.isNotEmpty) {
    return cleanFallbackName;
  }

  final email = user.email;
  if (email != null && email.contains('@')) {
    return email.split('@').first;
  }

  return 'Người dùng';
}

String _friendlyAuthMessage(String message) {
  final lowerMessage = message.toLowerCase();
  if (lowerMessage.contains('invalid login credentials')) {
    return 'Email hoặc mật khẩu không đúng.';
  }
  if (lowerMessage.contains('email not confirmed')) {
    return 'Email chưa được xác nhận.';
  }
  if (lowerMessage.contains('user already registered')) {
    return 'Email này đã được đăng ký.';
  }
  return message;
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
    throw AuthRepositoryException(
      message: emptyMessage,
      actionName: actionName,
    );
  }
  throw AuthRepositoryException(
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

String _friendlyPostgrestMessage(supabase.PostgrestException error) {
  switch (error.code) {
    case '23503':
      return 'Hồ sơ hoặc household không hợp lệ.';
    case '23505':
      return 'Hồ sơ người dùng đã tồn tại với dữ liệu bị trùng.';
    case '42501':
      return 'Bạn không có quyền truy cập dữ liệu này. Vui lòng kiểm tra RLS.';
    case 'PGRST116':
      return 'Không tìm thấy đúng một dòng dữ liệu phù hợp.';
    default:
      return error.message;
  }
}
