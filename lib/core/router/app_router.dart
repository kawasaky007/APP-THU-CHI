import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/providers/auth_state.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/categories/presentation/screens/category_list_screen.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/household/presentation/screens/create_household_screen.dart';
import '../../features/household/presentation/screens/invite_code_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/transactions/presentation/screens/add_transaction_screen.dart';
import '../../features/transactions/presentation/pages/transactions_page.dart';
import '../../shared/widgets/app_feedback.dart';
import '../../shared/widgets/app_shell.dart';
import 'app_routes.dart';

final _routerRefreshProvider = Provider<_RouterRefreshNotifier>((ref) {
  final notifier = _RouterRefreshNotifier(ref);
  ref.onDispose(notifier.dispose);
  return notifier;
});

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = ref.watch(_routerRefreshProvider);

  final router = GoRouter(
    navigatorKey: AppFeedback.navigatorKey,
    initialLocation: AppRoutes.splash,
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      final path = state.uri.path;

      final isAuthRoute = path == AppRoutes.login || path == AppRoutes.register;
      final isSplashRoute = path == AppRoutes.splash;
      final isHouseholdSetupRoute =
          path == AppRoutes.createHousehold || path == AppRoutes.inviteCode;

      if (authState.status == AuthStatus.initial) {
        return path == AppRoutes.splash ? null : AppRoutes.splash;
      }

      if (!authState.isSignedIn) {
        return isAuthRoute ? null : AppRoutes.login;
      }

      if (authState.shouldSetupHousehold) {
        return isHouseholdSetupRoute ? null : AppRoutes.createHousehold;
      }

      if (isAuthRoute || isSplashRoute || isHouseholdSetupRoute) {
        return AppRoutes.dashboard;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        name: AppRouteNames.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        name: AppRouteNames.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        name: AppRouteNames.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.createHousehold,
        name: AppRouteNames.createHousehold,
        builder: (context, state) => const CreateHouseholdScreen(),
      ),
      GoRoute(
        path: AppRoutes.inviteCode,
        name: AppRouteNames.inviteCode,
        builder: (context, state) => const InviteCodeScreen(),
      ),
      GoRoute(
        path: AppRoutes.addTransaction,
        name: AppRouteNames.addTransaction,
        builder: (context, state) => const AddTransactionScreen(),
      ),
      GoRoute(
        path: AppRoutes.editTransaction,
        name: AppRouteNames.editTransaction,
        builder: (context, state) {
          final transaction = state.extra;
          if (transaction is Transaction) {
            return AddTransactionScreen(transaction: transaction);
          }

          return const Scaffold(
            body: Center(child: Text('Không tìm thấy giao dịch để sửa.')),
          );
        },
      ),
      ShellRoute(
        builder: (context, state, child) {
          return AppShell(currentPath: state.uri.path, child: child);
        },
        routes: [
          GoRoute(
            path: AppRoutes.dashboard,
            name: AppRouteNames.dashboard,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: DashboardPage()),
          ),
          GoRoute(
            path: AppRoutes.transactions,
            name: AppRouteNames.transactions,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: TransactionsPage()),
          ),
          GoRoute(
            path: AppRoutes.categories,
            name: AppRouteNames.categories,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: CategoryListScreen()),
          ),
          GoRoute(
            path: AppRoutes.profile,
            name: AppRouteNames.profile,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ProfileScreen()),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) {
      return Scaffold(
        appBar: AppBar(title: const Text('Không tìm thấy trang')),
        body: Center(child: Text('Đường dẫn không hợp lệ: ${state.uri}')),
      );
    },
  );

  ref.onDispose(router.dispose);
  return router;
});

class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    ref.listen<AuthState>(
      authControllerProvider,
      (previous, next) => _scheduleRefresh(),
    );
  }

  bool _isDisposed = false;
  bool _refreshScheduled = false;

  void _scheduleRefresh() {
    if (_isDisposed || _refreshScheduled) {
      return;
    }

    _refreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshScheduled = false;
      if (!_isDisposed) {
        notifyListeners();
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
