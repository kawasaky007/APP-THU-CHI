import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../../core/providers/supabase_provider.dart';
import '../../../household/presentation/providers/household_provider.dart';
import '../../data/auth_repository.dart';
import 'auth_state.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    supabaseService: ref.watch(supabaseServiceProvider),
    householdRepository: ref.watch(householdRepositoryProvider),
  );
});

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) {
    return AuthController(ref.watch(authRepositoryProvider));
  },
);

final currentHouseholdIdProvider = Provider<String?>((ref) {
  final householdId = ref.watch(
    authControllerProvider.select(
      (state) => state.profile?.householdId?.trim(),
    ),
  );

  if (householdId == null || householdId.isEmpty) {
    return null;
  }
  return householdId;
});

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repository) : super(AuthState.initial()) {
    _authSubscription = _repo.authStateChanges.listen(_handleAuthChange);
    _runAfterBuild(() {
      if (mounted) {
        unawaited(bootstrap());
      }
    });
  }

  AuthController.testing(super.initialState) : _repository = null;

  final AuthRepository? _repository;
  StreamSubscription<supabase.AuthState>? _authSubscription;

  AuthRepository get _repo {
    final repository = _repository;
    if (repository == null) {
      throw StateError('AuthController testing không có AuthRepository.');
    }
    return repository;
  }

  Future<void> bootstrap() async {
    if (!state.isLoading) {
      _setState(state.asLoading());
    }

    try {
      final session = await _repo.restoreSession();
      if (!mounted) {
        return;
      }
      _setState(
        session == null
            ? AuthState.unauthenticated()
            : AuthState.fromSession(session),
      );
    } catch (error) {
      _setState(AuthState.unauthenticated(errorMessage: _errorMessage(error)));
    }
  }

  Future<void> login({required String email, required String password}) async {
    await _runSessionAction(
      () => _repo.signInWithEmail(email: email, password: password),
    );
  }

  Future<void> register({
    required String email,
    required String password,
    required String fullName,
  }) async {
    await _runSessionAction(
      () => _repo.registerWithEmail(
        email: email,
        password: password,
        fullName: fullName,
      ),
    );
  }

  Future<void> createHousehold({
    required String name,
    int? monthlyBudget,
  }) async {
    await _runSessionAction(
      () => _repo.createHouseholdForCurrentUser(
        name: name,
        monthlyBudget: monthlyBudget,
      ),
    );
  }

  Future<void> joinHouseholdByInviteCode(String inviteCode) async {
    await _runSessionAction(() => _repo.joinHouseholdByInviteCode(inviteCode));
  }

  Future<void> refreshSession() async {
    final previousState = state;
    _setState(state.asLoading());

    try {
      final session = await _repo.refreshCurrentSession();
      if (!mounted) {
        return;
      }
      _setState(AuthState.fromSession(session));
    } catch (error) {
      _setState(previousState.withError(_errorMessage(error)));
    }
  }

  Future<bool> renameHousehold(String name) async {
    final previousState = state;
    _setState(state.asLoading());

    try {
      final session = await _repo.updateCurrentHouseholdName(name);
      if (!mounted) {
        return false;
      }
      _setState(AuthState.fromSession(session));
      return true;
    } catch (error) {
      _setState(previousState.withError(_errorMessage(error)));
      return false;
    }
  }

  Future<bool> updateMonthlyBudget(int monthlyBudget) async {
    final previousState = state;
    _setState(state.asLoading());

    try {
      final session = await _repo.updateCurrentHouseholdBudget(monthlyBudget);
      if (!mounted) {
        return false;
      }
      _setState(AuthState.fromSession(session));
      return true;
    } catch (error) {
      _setState(previousState.withError(_errorMessage(error)));
      return false;
    }
  }

  Future<bool> leaveHousehold() async {
    final previousState = state;
    _setState(state.asLoading());

    try {
      final session = await _repo.leaveCurrentHousehold();
      if (!mounted) {
        return false;
      }
      _setState(AuthState.fromSession(session));
      return true;
    } catch (error) {
      _setState(previousState.withError(_errorMessage(error)));
      return false;
    }
  }

  Future<bool> deleteHousehold() async {
    final previousState = state;
    _setState(state.asLoading());

    try {
      final session = await _repo.deleteCurrentHousehold();
      if (!mounted) {
        return false;
      }
      _setState(AuthState.fromSession(session));
      return true;
    } catch (error) {
      _setState(previousState.withError(_errorMessage(error)));
      return false;
    }
  }

  Future<void> logout() async {
    final previousState = state;
    _setState(state.asLoading());

    try {
      await _repo.signOut();
      _setState(AuthState.unauthenticated());
    } catch (error) {
      _setState(previousState.withError(_errorMessage(error)));
    }
  }

  void clearError() {
    if (state.errorMessage != null) {
      _setState(state.clearError());
    }
  }

  Future<void> _runSessionAction(
    Future<AuthSessionData> Function() action,
  ) async {
    final previousState = state;
    _setState(state.asLoading());

    try {
      final session = await action();
      if (!mounted) {
        return;
      }
      _setState(AuthState.fromSession(session));
    } catch (error) {
      _setState(previousState.withError(_errorMessage(error)));
    }
  }

  void _handleAuthChange(supabase.AuthState authState) {
    if (authState.event == supabase.AuthChangeEvent.signedOut) {
      _runAfterBuild(() => _setState(AuthState.unauthenticated()));
    }
  }

  String _errorMessage(Object error) {
    if (error is AuthRepositoryException) {
      return error.message;
    }
    return 'Có lỗi xảy ra. Vui lòng thử lại.';
  }

  void _setState(AuthState nextState) {
    if (mounted) {
      state = nextState;
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}

void _runAfterBuild(VoidCallback callback) {
  final binding = WidgetsBinding.instance;
  binding.addPostFrameCallback((_) => callback());
  binding.ensureVisualUpdate();
}
