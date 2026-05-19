import 'package:supabase_flutter/supabase_flutter.dart' show User;

import '../../../../core/models/models.dart';
import '../../data/auth_repository.dart';

enum AuthStatus { initial, unauthenticated, authenticated, needsHousehold }

class AuthState {
  const AuthState({
    required this.status,
    required this.isLoading,
    this.user,
    this.profile,
    this.household,
    this.errorMessage,
  });

  final AuthStatus status;
  final bool isLoading;
  final User? user;
  final UserProfile? profile;
  final Household? household;
  final String? errorMessage;

  bool get isInitial => status == AuthStatus.initial;
  bool get isSignedIn =>
      status == AuthStatus.authenticated || status == AuthStatus.needsHousehold;
  bool get hasHousehold => status == AuthStatus.authenticated;
  bool get shouldSetupHousehold => status == AuthStatus.needsHousehold;

  factory AuthState.initial() {
    return const AuthState(status: AuthStatus.initial, isLoading: true);
  }

  factory AuthState.unauthenticated({String? errorMessage}) {
    return AuthState(
      status: AuthStatus.unauthenticated,
      isLoading: false,
      errorMessage: errorMessage,
    );
  }

  factory AuthState.fromSession(AuthSessionData session) {
    return AuthState(
      status: session.hasHousehold
          ? AuthStatus.authenticated
          : AuthStatus.needsHousehold,
      isLoading: false,
      user: session.user,
      profile: session.profile,
      household: session.household,
    );
  }

  AuthState asLoading() {
    return AuthState(
      status: status,
      isLoading: true,
      user: user,
      profile: profile,
      household: household,
    );
  }

  AuthState withError(String message) {
    return AuthState(
      status: status == AuthStatus.initial
          ? AuthStatus.unauthenticated
          : status,
      isLoading: false,
      user: user,
      profile: profile,
      household: household,
      errorMessage: message,
    );
  }

  AuthState clearError() {
    return AuthState(
      status: status,
      isLoading: isLoading,
      user: user,
      profile: profile,
      household: household,
    );
  }
}
