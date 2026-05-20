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
      debugPrint('PROFILES STREAM PROVIDER SUBSCRIBED: householdId=$householdId');
      ref.onDispose(
        () => debugPrint('PROFILES STREAM PROVIDER DISPOSED: householdId=$householdId'),
      );

      return ref
          .watch(profileRepositoryProvider)
          .watchProfiles(householdId);
    });

/// Map of userId -> UserProfile for easy lookup.
/// Rebuilds automatically on realtime profile changes.
final profilesByIdProvider = Provider.autoDispose
    .family<Map<String, UserProfile>, String>((ref, householdId) {
      final profilesAsync = ref.watch(householdProfilesStreamProvider(householdId));
      final profiles = profilesAsync.valueOrNull ?? const <UserProfile>[];

      return {for (final profile in profiles) profile.id: profile};
    });

/// Current user ID from auth state.
final currentUserIdProvider = Provider<String?>((ref) {
  final authState = ref.watch(authControllerProvider);
  return authState.user?.id ?? authState.profile?.id;
});
