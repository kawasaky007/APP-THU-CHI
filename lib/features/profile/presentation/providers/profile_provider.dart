import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/models.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/profile_repository.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(supabaseServiceProvider));
});

final householdProfilesStreamProvider = StreamProvider.autoDispose
    .family<List<UserProfile>, String>((ref, householdId) {
      debugPrint(
        'PROFILES STREAM PROVIDER SUBSCRIBED: householdId=$householdId',
      );
      ref.onDispose(
        () => debugPrint(
          'PROFILES STREAM PROVIDER DISPOSED: householdId=$householdId',
        ),
      );

      return ref.watch(profileRepositoryProvider).watchProfiles(householdId);
    });

/// Map of userId -> UserProfile for easy lookup.
/// Rebuilds automatically on realtime profile changes.
final profilesByIdProvider = Provider.autoDispose
    .family<Map<String, UserProfile>, String>((ref, householdId) {
      final profilesAsync = ref.watch(
        householdProfilesStreamProvider(householdId),
      );
      final profiles = profilesAsync.valueOrNull ?? const <UserProfile>[];

      return {for (final profile in profiles) profile.id: profile};
    });

/// Current user ID from auth state.
final currentUserIdProvider = Provider<String?>((ref) {
  final authState = ref.watch(authControllerProvider);
  return authState.user?.id ?? authState.profile?.id;
});

final profileActionProvider =
    StateNotifierProvider<ProfileActionController, ProfileActionState>((ref) {
      return ProfileActionController(
        repository: ref.watch(profileRepositoryProvider),
        ref: ref,
      );
    });

class ProfileActionState {
  const ProfileActionState({this.isLoading = false, this.errorMessage});

  final bool isLoading;
  final String? errorMessage;
}

class ProfileActionController extends StateNotifier<ProfileActionState> {
  ProfileActionController({
    required ProfileRepository repository,
    required Ref ref,
  }) : _repository = repository,
       _ref = ref,
       super(const ProfileActionState());

  final ProfileRepository _repository;
  final Ref _ref;

  Future<bool> updateUserProfileName(String fullName) async {
    final cleanName = _normalizeDisplayName(fullName);
    if (cleanName == null) {
      _setState(
        const ProfileActionState(
          errorMessage: 'Tên hiển thị không được để trống.',
        ),
      );
      return false;
    }
    if (cleanName.length > 50) {
      _setState(
        const ProfileActionState(errorMessage: 'Tên hiển thị tối đa 50 ký tự.'),
      );
      return false;
    }

    final authState = _ref.read(authControllerProvider);
    final previousProfile = authState.profile;
    if (previousProfile == null) {
      _setState(
        const ProfileActionState(
          errorMessage: 'Không tìm thấy hồ sơ người dùng hiện tại.',
        ),
      );
      return false;
    }

    final authController = _ref.read(authControllerProvider.notifier);
    final optimisticProfile = previousProfile.copyWith(
      fullName: cleanName,
      updatedAt: DateTime.now().toUtc(),
    );

    _setState(const ProfileActionState(isLoading: true));
    authController.replaceProfile(optimisticProfile);

    try {
      final updatedProfile = await _repository.updateUserProfileName(cleanName);
      if (!mounted) {
        return false;
      }

      authController.replaceProfile(
        updatedProfile.copyWith(role: previousProfile.role),
      );

      final householdId = updatedProfile.householdId;
      if (householdId != null && householdId.trim().isNotEmpty) {
        _ref.invalidate(householdProfilesStreamProvider(householdId));
      }

      _setState(const ProfileActionState());
      return true;
    } catch (error) {
      authController.replaceProfile(previousProfile);
      _setState(ProfileActionState(errorMessage: _errorMessage(error)));
      return false;
    }
  }

  void clearError() {
    if (state.errorMessage != null) {
      _setState(const ProfileActionState());
    }
  }

  String _errorMessage(Object error) {
    if (error is ProfileRepositoryException) {
      return error.message;
    }
    return 'Không thể cập nhật hồ sơ. Vui lòng thử lại.';
  }

  void _setState(ProfileActionState nextState) {
    if (mounted) {
      state = nextState;
    }
  }
}

String? _normalizeDisplayName(String value) {
  final cleanName = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (cleanName.isEmpty) {
    return null;
  }
  return cleanName;
}
