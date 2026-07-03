import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:uuid/uuid.dart';

import '../../../core/models/models.dart';
import '../../../core/services/supabase_service.dart';

class HouseholdMembership {
  const HouseholdMembership({required this.profile, required this.household});

  final UserProfile profile;
  final Household household;
}

class HouseholdRepository {
  HouseholdRepository(this._supabaseService);

  final SupabaseService _supabaseService;
  final _uuid = const Uuid();

  supabase.SupabaseClient get _client => _supabaseService.client;

  Future<Household?> getById(String householdId) {
    return _guard('Lấy household', () async {
      final row = await _client
          .from(SupabaseTables.households)
          .select()
          .eq('id', householdId)
          .maybeSingle();

      if (row == null) {
        return null;
      }
      return Household.fromJson(_asJsonMap(row));
    });
  }

  Future<Household> updateHouseholdName({
    required Household household,
    required String name,
  }) {
    return _guard('Đổi tên household', () async {
      final cleanName = _normalizeHouseholdName(name);

      final row = await _client
          .from(SupabaseTables.households)
          .update({
            'name': cleanName,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', household.id)
          .select();

      return Household.fromJson(
        _requireSingleJsonMap(
          row,
          actionName: 'Đổi tên household',
          emptyMessage:
              'Không thể đổi tên household. Vui lòng kiểm tra quyền truy cập.',
          multipleMessage:
              'Dữ liệu household bị trùng khi đổi tên. Vui lòng kiểm tra database.',
        ),
      );
    });
  }

  Future<Household> transferOwnership({
    required Household household,
    required UserProfile currentOwnerProfile,
    required String newOwnerId,
  }) {
    return _guard('Chuyển quyền chủ household', () async {
      final cleanNewOwnerId = newOwnerId.trim();
      if (cleanNewOwnerId.isEmpty) {
        throw const HouseholdRepositoryException(
          message: 'Vui lòng chọn chủ household mới.',
          actionName: 'Chuyển quyền chủ household',
        );
      }
      if (household.ownerId != currentOwnerProfile.id) {
        throw const HouseholdRepositoryException(
          message: 'Chỉ chủ household hiện tại mới có quyền chuyển quyền.',
          actionName: 'Chuyển quyền chủ household',
        );
      }
      if (cleanNewOwnerId == currentOwnerProfile.id) {
        throw const HouseholdRepositoryException(
          message: 'Không thể chuyển quyền cho chính bạn.',
          actionName: 'Chuyển quyền chủ household',
        );
      }

      final memberRow = await _client
          .from(SupabaseTables.userProfiles)
          .select('id, household_id')
          .eq('id', cleanNewOwnerId)
          .eq('household_id', household.id)
          .maybeSingle();

      if (memberRow == null) {
        throw const HouseholdRepositoryException(
          message: 'Thành viên được chọn không còn thuộc household hiện tại.',
          actionName: 'Chuyển quyền chủ household',
        );
      }

      final now = DateTime.now().toUtc().toIso8601String();
      final row = await _client
          .from(SupabaseTables.households)
          .update({'owner_id': cleanNewOwnerId, 'updated_at': now})
          .eq('id', household.id)
          .eq('owner_id', currentOwnerProfile.id)
          .select();

      return Household.fromJson(
        _requireSingleJsonMap(
          row,
          actionName: 'Chuyển quyền chủ household',
          emptyMessage:
              'Không thể chuyển quyền. Household không tồn tại hoặc quyền đã thay đổi.',
          multipleMessage:
              'Dữ liệu household bị trùng khi chuyển quyền. Vui lòng kiểm tra database.',
        ),
      );
    });
  }

  Future<HouseholdMembership> createHouseholdForProfile({
    required UserProfile profile,
    required String name,
  }) {
    return _guard('Tạo household mới', () async {
      final cleanName = name.trim();
      if (cleanName.isEmpty) {
        throw const HouseholdRepositoryException(
          message: 'Vui lòng nhập tên household.',
          actionName: 'Tạo household mới',
        );
      }

      final now = DateTime.now().toUtc();
      final householdDraft = Household(
        id: _uuid.v4(),
        name: cleanName,
        ownerId: profile.id,
        inviteCode: _generateInviteCode(),
        createdAt: now,
        updatedAt: now,
      );

      final householdRow = await _client
          .from(SupabaseTables.households)
          .insert(householdDraft.toJson())
          .select();

      final household = Household.fromJson(
        _requireSingleJsonMap(
          householdRow,
          actionName: 'Tạo household mới',
          emptyMessage:
              'Không thể tạo household. Vui lòng kiểm tra quyền ghi dữ liệu.',
          multipleMessage:
              'Tạo household trả về nhiều dòng bất thường. Vui lòng kiểm tra database.',
        ),
      );
      final updatedProfile = await _updateProfileHousehold(
        profile: profile,
        householdId: household.id,
        role: UserProfileRole.owner,
      );

      return HouseholdMembership(profile: updatedProfile, household: household);
    });
  }

  Future<HouseholdMembership> joinByInviteCode({
    required UserProfile profile,
    required String inviteCode,
  }) {
    return _guard('Tham gia household bằng mã mời', () async {
      final cleanCode = _normalizeInviteCode(inviteCode);
      if (cleanCode.isEmpty) {
        throw const HouseholdRepositoryException(
          message: 'Vui lòng nhập mã mời.',
          actionName: 'Tham gia household bằng mã mời',
        );
      }

      final householdRows = await _client
          .from(SupabaseTables.households)
          .select()
          .eq('invite_code', cleanCode)
          .limit(2);

      final household = Household.fromJson(
        _requireSingleJsonMap(
          householdRows,
          actionName: 'Tham gia household bằng mã mời',
          emptyMessage: 'Mã mời không tồn tại hoặc đã hết hạn.',
          multipleMessage:
              'Mã mời đang bị trùng trong database. Vui lòng tạo mã mời mới.',
        ),
      );
      final updatedProfile = await _updateProfileHousehold(
        profile: profile,
        householdId: household.id,
        role: UserProfileRole.partner,
      );

      return HouseholdMembership(profile: updatedProfile, household: household);
    });
  }

  Future<UserProfile> leaveHousehold({required UserProfile profile}) {
    return _guard('Thoát household', () async {
      final householdId = profile.householdId;
      if (householdId == null || householdId.isEmpty) {
        throw const HouseholdRepositoryException(
          message: 'Bạn chưa tham gia household nào.',
          actionName: 'Thoát household',
        );
      }

      final row = await _client
          .from(SupabaseTables.userProfiles)
          .update({
            'household_id': null,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', profile.id)
          .eq('household_id', householdId)
          .select();

      return UserProfile.fromJson(
        _requireSingleJsonMap(
          row,
          actionName: 'Thoát household',
          emptyMessage:
              'Không thể thoát household. Hồ sơ hiện tại không còn thuộc household này.',
          multipleMessage:
              'Dữ liệu hồ sơ bị trùng khi thoát household. Vui lòng kiểm tra database.',
        ),
      ).copyWith(role: UserProfileRole.member);
    });
  }

  Future<UserProfile> deleteHousehold({
    required Household household,
    required UserProfile ownerProfile,
  }) {
    return _guard('Xóa household', () async {
      if (household.ownerId != ownerProfile.id) {
        throw const HouseholdRepositoryException(
          message: 'Chỉ chủ household mới có quyền xóa household.',
          actionName: 'Xóa household',
        );
      }

      final now = DateTime.now().toUtc().toIso8601String();

      await _client
          .from(SupabaseTables.transactions)
          .delete()
          .eq('household_id', household.id);

      await _client
          .from(SupabaseTables.categories)
          .delete()
          .eq('household_id', household.id);

      await _client
          .from(SupabaseTables.userProfiles)
          .update({'household_id': null, 'updated_at': now})
          .eq('household_id', household.id);

      final deletedHousehold = await _client
          .from(SupabaseTables.households)
          .delete()
          .eq('id', household.id)
          .eq('owner_id', ownerProfile.id)
          .select('id')
          .maybeSingle();

      if (deletedHousehold == null) {
        throw const HouseholdRepositoryException(
          message: 'Không thể xóa household. Vui lòng kiểm tra quyền truy cập.',
          actionName: 'Xóa household',
        );
      }

      return _profileWithoutHousehold(ownerProfile);
    });
  }

  Future<UserProfile> _updateProfileHousehold({
    required UserProfile profile,
    required String householdId,
    required UserProfileRole role,
  }) async {
    final updatedProfile = profile.copyWith(
      householdId: householdId,
      role: role,
      updatedAt: DateTime.now().toUtc(),
    );

    final row = await _client
        .from(SupabaseTables.userProfiles)
        .upsert(updatedProfile.toJson())
        .select();

    return UserProfile.fromJson(
      _requireSingleJsonMap(
        row,
        actionName: 'Cập nhật household cho hồ sơ',
        emptyMessage:
            'Không thể cập nhật household cho hồ sơ. Vui lòng kiểm tra RLS profiles.',
        multipleMessage:
            'Dữ liệu hồ sơ bị trùng khi cập nhật household. Vui lòng kiểm tra database.',
      ),
    ).copyWith(role: role);
  }

  Future<T> _guard<T>(String actionName, Future<T> Function() action) async {
    try {
      return await action();
    } catch (error, stackTrace) {
      if (error is HouseholdRepositoryException) {
        rethrow;
      }
      throw _mapException(error, stackTrace, actionName: actionName);
    }
  }

  HouseholdRepositoryException _mapException(
    Object error,
    StackTrace stackTrace, {
    required String actionName,
  }) {
    if (error is supabase.AuthException) {
      return HouseholdRepositoryException(
        message: error.message,
        actionName: actionName,
        code: error.code ?? error.statusCode,
        cause: error,
        stackTrace: stackTrace,
      );
    }

    if (error is supabase.PostgrestException) {
      return HouseholdRepositoryException(
        message: _friendlyPostgrestMessage(error),
        actionName: actionName,
        code: error.code,
        details: error.details,
        cause: error,
        stackTrace: stackTrace,
      );
    }

    if (error is FormatException) {
      return HouseholdRepositoryException(
        message: error.message,
        actionName: actionName,
        cause: error,
        stackTrace: stackTrace,
      );
    }

    return HouseholdRepositoryException(
      message: 'Có lỗi khi xử lý household. Vui lòng thử lại.',
      actionName: actionName,
      cause: error,
      stackTrace: stackTrace,
    );
  }
}

class HouseholdRepositoryException implements Exception {
  const HouseholdRepositoryException({
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
    return 'HouseholdRepositoryException$codeText: $actionName - $message';
  }
}

String _generateInviteCode() {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final raw = const Uuid().v4().replaceAll('-', '').toUpperCase();
  final buffer = StringBuffer();

  for (final codeUnit in raw.codeUnits) {
    buffer.write(alphabet[codeUnit % alphabet.length]);
    if (buffer.length == 6) {
      break;
    }
  }

  return buffer.toString();
}

String _normalizeInviteCode(String value) {
  return value.trim().replaceAll(RegExp(r'\s+|-'), '').toUpperCase();
}

String _normalizeHouseholdName(String value) {
  final cleanName = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (cleanName.length < 2) {
    throw const HouseholdRepositoryException(
      message: 'Tên household cần tối thiểu 2 ký tự.',
      actionName: 'Kiểm tra household',
    );
  }
  if (cleanName.length > 60) {
    throw const HouseholdRepositoryException(
      message: 'Tên household tối đa 60 ký tự.',
      actionName: 'Kiểm tra household',
    );
  }
  return cleanName;
}

UserProfile _profileWithoutHousehold(UserProfile profile) {
  return UserProfile(
    id: profile.id,
    email: profile.email,
    fullName: profile.fullName,
    avatarUrl: profile.avatarUrl,
    phoneNumber: profile.phoneNumber,
    role: UserProfileRole.member,
    createdAt: profile.createdAt,
    updatedAt: DateTime.now().toUtc(),
  );
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
    throw HouseholdRepositoryException(
      message: emptyMessage,
      actionName: actionName,
    );
  }
  throw HouseholdRepositoryException(
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
      return 'Household hoặc hồ sơ người dùng không hợp lệ.';
    case '23505':
      return 'Dữ liệu household bị trùng. Vui lòng thử mã hoặc tên khác.';
    case '42501':
      return 'Bạn không có quyền thực hiện thao tác này. Vui lòng kiểm tra RLS.';
    case 'PGRST116':
      return 'Không tìm thấy đúng một dòng dữ liệu phù hợp.';
    default:
      return error.message;
  }
}
