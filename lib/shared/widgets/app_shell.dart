import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.currentPath, required this.child, super.key});

  final String currentPath;
  final Widget child;

  static const _tabs = [
    _NavigationTab(
      path: AppRoutes.dashboard,
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      label: 'Dashboard',
    ),
    _NavigationTab(
      path: AppRoutes.transactions,
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long,
      label: 'Giao dịch',
    ),
    _NavigationTab(
      path: AppRoutes.categories,
      icon: Icons.category_outlined,
      selectedIcon: Icons.category,
      label: 'Danh mục',
    ),
    _NavigationTab(
      path: AppRoutes.profile,
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
      label: 'Hồ sơ',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _selectedIndex;

    return Scaffold(
      body: SafeArea(child: child),
      floatingActionButton: _showQuickAddButton
          ? FloatingActionButton.extended(
              tooltip: 'Thêm giao dịch nhanh',
              onPressed: () => context.push(AppRoutes.addTransaction),
              icon: const Icon(Icons.add),
              label: const Text('Thêm'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          final nextPath = _tabs[index].path;
          if (nextPath != currentPath) {
            context.go(nextPath);
          }
        },
        destinations: [
          for (final tab in _tabs)
            NavigationDestination(
              icon: Icon(tab.icon),
              selectedIcon: Icon(tab.selectedIcon),
              label: tab.label,
            ),
        ],
      ),
    );
  }

  int get _selectedIndex {
    final index = _tabs.indexWhere((tab) {
      if (tab.path == AppRoutes.dashboard) {
        return currentPath == AppRoutes.dashboard;
      }
      return currentPath.startsWith(tab.path);
    });

    return index == -1 ? 0 : index;
  }

  bool get _showQuickAddButton => currentPath == AppRoutes.transactions;
}

class _NavigationTab {
  const _NavigationTab({
    required this.path,
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final String path;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}
