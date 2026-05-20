class AppRoutes {
  AppRoutes._();

  static const splash = '/splash';
  static const login = '/login';
  static const register = '/register';
  static const createHousehold = '/household/create';
  static const inviteCode = '/household/invite';
  static const dashboard = '/';
  static const transactions = '/transactions';
  static const addTransaction = '/transactions/add';
  static const editTransaction = '/transactions/edit';
  static const categories = '/categories';
  static const budgets = '/budgets';
  static const profile = '/profile';

  // Giữ lại hằng số cũ để các màn hình đã viết trước đó không bị gãy import.
  static const reports = '/reports';
  static const settings = profile;
}

class AppRouteNames {
  AppRouteNames._();

  static const splash = 'splash';
  static const login = 'login';
  static const register = 'register';
  static const createHousehold = 'create-household';
  static const inviteCode = 'invite-code';
  static const dashboard = 'dashboard';
  static const transactions = 'transactions';
  static const addTransaction = 'add-transaction';
  static const editTransaction = 'edit-transaction';
  static const categories = 'categories';
  static const budgets = 'budgets';
  static const profile = 'profile';

  // Alias cũ cho các chỗ còn dùng tên settings.
  static const reports = 'reports';
  static const settings = profile;
}
