import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/app_constants.dart';
import '../../../../core/models/models.dart';
import '../../../../shared/formatters/currency_input_formatter.dart';
import '../../../../shared/widgets/app_feedback.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final profile = authState.profile;
    final household = authState.household;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hồ sơ'),
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            onPressed: authState.isLoading ? null : () => _refresh(ref),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.xl,
          ),
          children: [
            _ProfileHeader(profile: profile),
            const SizedBox(height: AppSpacing.md),
            _PersonalInfoCard(profile: profile),
            const SizedBox(height: AppSpacing.md),
            _HouseholdCard(
              household: household,
              role: profile?.role,
              onCopyInviteCode: household?.inviteCode == null
                  ? null
                  : () => _copyInviteCode(household!.inviteCode!),
              onRenameHousehold: household == null
                  ? null
                  : () => _renameHousehold(context, ref, household),
              onUpdateMonthlyBudget: household == null
                  ? null
                  : () => _updateMonthlyBudget(context, ref, household),
              onLeaveHousehold:
                  household == null || profile?.role == UserProfileRole.owner
                  ? null
                  : () => _leaveHousehold(context, ref, household),
              onDeleteHousehold:
                  household == null || profile?.role != UserProfileRole.owner
                  ? null
                  : () => _deleteHousehold(context, ref, household),
            ),
            const SizedBox(height: AppSpacing.md),
            _AppModeCard(),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.tonalIcon(
              onPressed: authState.isLoading
                  ? null
                  : () => _confirmLogout(context, ref),
              icon: const Icon(Icons.logout),
              label: const Text('Đăng xuất'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _refresh(WidgetRef ref) {
    return ref.read(authControllerProvider.notifier).refreshSession();
  }

  Future<void> _copyInviteCode(String inviteCode) async {
    await Clipboard.setData(ClipboardData(text: inviteCode));
    AppFeedback.showSnackBar('Đã sao chép mã mời.');
  }

  Future<void> _renameHousehold(
    BuildContext context,
    WidgetRef ref,
    Household household,
  ) async {
    final newName = await _showRenameDialog(context, household.name);
    if (!context.mounted || newName == null) {
      return;
    }

    final success = await ref
        .read(authControllerProvider.notifier)
        .renameHousehold(newName);
    if (!context.mounted) {
      return;
    }

    if (success) {
      AppFeedback.showSnackBar('Đã đổi tên household.');
      return;
    }

    final message =
        ref.read(authControllerProvider).errorMessage ??
        'Không thể đổi tên household. Vui lòng thử lại.';
    await AppFeedback.showErrorDialog(
      title: 'Không thể đổi tên',
      message: message,
    );
    if (context.mounted) {
      ref.read(authControllerProvider.notifier).clearError();
    }
  }

  Future<String?> _showRenameDialog(
    BuildContext context,
    String currentName,
  ) async {
    return showDialog<String>(
      context: context,
      builder: (_) => _RenameHouseholdDialog(currentName: currentName),
    );
  }

  Future<void> _updateMonthlyBudget(
    BuildContext context,
    WidgetRef ref,
    Household household,
  ) async {
    final monthlyBudget = await _showBudgetDialog(
      context,
      household.monthlyBudget,
    );
    if (!context.mounted || monthlyBudget == null) {
      return;
    }

    final success = await ref
        .read(authControllerProvider.notifier)
        .updateMonthlyBudget(monthlyBudget);
    if (!context.mounted) {
      return;
    }

    if (success) {
      AppFeedback.showSnackBar('Đã cập nhật ngân sách tháng.');
      return;
    }

    final message =
        ref.read(authControllerProvider).errorMessage ??
        'Không thể cập nhật ngân sách tháng. Vui lòng thử lại.';
    await AppFeedback.showErrorDialog(
      title: 'Không thể cập nhật ngân sách',
      message: message,
    );
    if (context.mounted) {
      ref.read(authControllerProvider.notifier).clearError();
    }
  }

  Future<int?> _showBudgetDialog(
    BuildContext context,
    int? currentBudget,
  ) async {
    return showDialog<int>(
      context: context,
      builder: (_) => _MonthlyBudgetDialog(currentBudget: currentBudget),
    );
  }

  Future<void> _leaveHousehold(
    BuildContext context,
    WidgetRef ref,
    Household household,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Thoát household?'),
          content: Text(
            'Bạn sẽ rời khỏi "${household.name}" và không còn thấy dữ liệu thu chi chung.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Hủy'),
            ),
            FilledButton.tonalIcon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.exit_to_app_outlined),
              label: const Text('Thoát'),
            ),
          ],
        );
      },
    );

    if (!context.mounted || confirmed != true) {
      return;
    }

    final success = await ref
        .read(authControllerProvider.notifier)
        .leaveHousehold();
    if (!context.mounted) {
      return;
    }
    if (success) {
      AppFeedback.showSnackBar('Đã thoát household.');
      return;
    }

    final message =
        ref.read(authControllerProvider).errorMessage ??
        'Không thể thoát household. Vui lòng thử lại.';
    await AppFeedback.showErrorDialog(
      title: 'Không thể thoát household',
      message: message,
    );
    if (context.mounted) {
      ref.read(authControllerProvider.notifier).clearError();
    }
  }

  Future<void> _deleteHousehold(
    BuildContext context,
    WidgetRef ref,
    Household household,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;

        return AlertDialog(
          title: const Text('Xóa household?'),
          content: Text(
            'Household "${household.name}" cùng giao dịch và danh mục bên trong sẽ bị xóa. Thao tác này không thể hoàn tác.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Hủy'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.errorContainer,
                foregroundColor: colorScheme.onErrorContainer,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Xóa'),
            ),
          ],
        );
      },
    );

    if (!context.mounted || confirmed != true) {
      return;
    }

    final success = await ref
        .read(authControllerProvider.notifier)
        .deleteHousehold();
    if (!context.mounted) {
      return;
    }
    if (success) {
      AppFeedback.showSnackBar('Đã xóa household.');
      return;
    }

    final message =
        ref.read(authControllerProvider).errorMessage ??
        'Không thể xóa household. Vui lòng thử lại.';
    await AppFeedback.showErrorDialog(
      title: 'Không thể xóa household',
      message: message,
    );
    if (context.mounted) {
      ref.read(authControllerProvider.notifier).clearError();
    }
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Đăng xuất?'),
          content: const Text(
            'Bạn sẽ cần đăng nhập lại để tiếp tục quản lý thu chi.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Hủy'),
            ),
            FilledButton.tonalIcon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.logout),
              label: const Text('Đăng xuất'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      if (!context.mounted) {
        return;
      }
      await ref.read(authControllerProvider.notifier).logout();
    }
  }
}

class _RenameHouseholdDialog extends StatefulWidget {
  const _RenameHouseholdDialog({required this.currentName});

  final String currentName;

  @override
  State<_RenameHouseholdDialog> createState() => _RenameHouseholdDialogState();
}

class _RenameHouseholdDialogState extends State<_RenameHouseholdDialog> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Đổi tên household'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        inputFormatters: [
          LengthLimitingTextInputFormatter(60),
          FilteringTextInputFormatter.deny(RegExp(r'^\s+')),
        ],
        decoration: InputDecoration(
          labelText: 'Tên household',
          prefixIcon: const Icon(Icons.home_outlined),
          errorText: _errorText,
        ),
        onChanged: (_) {
          if (_errorText != null) {
            _setLocalState(() => _errorText = null);
          }
        },
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () {
            if (mounted) {
              Navigator.of(context).pop();
            }
          },
          child: const Text('Hủy'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Lưu'),
        ),
      ],
    );
  }

  void _submit() {
    final validationError = _validateHouseholdName(_controller.text);
    if (validationError != null) {
      _setLocalState(() => _errorText = validationError);
      return;
    }

    if (mounted) {
      Navigator.of(context).pop(_normalizeHouseholdName(_controller.text));
    }
  }

  void _setLocalState(VoidCallback update) {
    if (!mounted) {
      return;
    }
    setState(update);
  }
}

class _MonthlyBudgetDialog extends StatefulWidget {
  const _MonthlyBudgetDialog({required this.currentBudget});

  final int? currentBudget;

  @override
  State<_MonthlyBudgetDialog> createState() => _MonthlyBudgetDialogState();
}

class _MonthlyBudgetDialogState extends State<_MonthlyBudgetDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.currentBudget == null
          ? ''
          : CurrencyInputFormatter.formatNumber(widget.currentBudget!),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cập nhật ngân sách tháng'),
      content: TextFormField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        inputFormatters: const [CurrencyInputFormatter()],
        decoration: const InputDecoration(
          labelText: 'Ngân sách tháng',
          prefixIcon: Icon(Icons.savings_outlined),
          suffixText: 'đ',
        ),
        onFieldSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () {
            if (mounted) {
              Navigator.of(context).pop();
            }
          },
          child: const Text('Hủy'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Lưu'),
        ),
      ],
    );
  }

  void _submit() {
    if (mounted) {
      Navigator.of(context).pop(_parseBudget(_controller.text));
    }
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile});

  final UserProfile? profile;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fullName = profile?.fullName.trim().isNotEmpty == true
        ? profile!.fullName
        : 'Người dùng';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: colorScheme.primary,
            child: Text(
              _initials(fullName),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: colorScheme.onPrimary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  profile?.email ?? 'Chưa có email',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onPrimaryContainer.withValues(
                      alpha: 0.76,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonalInfoCard extends StatelessWidget {
  const _PersonalInfoCard({required this.profile});

  final UserProfile? profile;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(
              icon: Icons.account_circle_outlined,
              title: 'Thông tin cá nhân',
            ),
            const SizedBox(height: AppSpacing.sm),
            _InfoRow(
              icon: Icons.badge_outlined,
              label: 'Họ tên',
              value: profile?.fullName ?? 'Chưa cập nhật',
            ),
            _InfoRow(
              icon: Icons.email_outlined,
              label: 'Email',
              value: profile?.email ?? 'Chưa cập nhật',
            ),
            _InfoRow(
              icon: Icons.verified_user_outlined,
              label: 'Vai trò',
              value: _roleLabel(profile?.role),
            ),
          ],
        ),
      ),
    );
  }
}

class _HouseholdCard extends StatelessWidget {
  const _HouseholdCard({
    required this.household,
    required this.role,
    required this.onCopyInviteCode,
    required this.onRenameHousehold,
    required this.onUpdateMonthlyBudget,
    required this.onLeaveHousehold,
    required this.onDeleteHousehold,
  });

  final Household? household;
  final UserProfileRole? role;
  final VoidCallback? onCopyInviteCode;
  final VoidCallback? onRenameHousehold;
  final VoidCallback? onUpdateMonthlyBudget;
  final VoidCallback? onLeaveHousehold;
  final VoidCallback? onDeleteHousehold;

  @override
  Widget build(BuildContext context) {
    final inviteCode = household?.inviteCode;
    final isOwner = role == UserProfileRole.owner;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: _SectionTitle(
                    icon: Icons.home_outlined,
                    title: 'Household',
                  ),
                ),
                IconButton.outlined(
                  tooltip: 'Đổi tên household',
                  onPressed: onRenameHousehold,
                  icon: const Icon(Icons.edit_outlined),
                ),
                const SizedBox(width: AppSpacing.xs),
                IconButton.outlined(
                  tooltip: 'Cập nhật ngân sách tháng',
                  onPressed: onUpdateMonthlyBudget,
                  icon: const Icon(Icons.savings_outlined),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            _InfoRow(
              icon: Icons.home_work_outlined,
              label: 'Tên household',
              value: household?.name ?? 'Chưa có household',
            ),
            _InfoRow(
              icon: Icons.group_outlined,
              label: 'Quyền trong household',
              value: _roleLabel(role),
            ),
            _InfoRow(
              icon: Icons.savings_outlined,
              label: 'Ngân sách tháng',
              value: _formatCurrency(household?.monthlyBudget),
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.key_outlined),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mã mời',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        SelectableText(
                          inviteCode ?? 'Chưa sẵn sàng',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Sao chép mã mời',
                    onPressed: onCopyInviteCode,
                    icon: const Icon(Icons.copy_outlined),
                  ),
                ],
              ),
            ),
            if (household != null) ...[
              const SizedBox(height: AppSpacing.md),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.sm),
              if (isOwner)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.errorContainer,
                      foregroundColor: colorScheme.onErrorContainer,
                    ),
                    onPressed: onDeleteHousehold,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Xóa household'),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onLeaveHousehold,
                    icon: const Icon(Icons.exit_to_app_outlined),
                    label: const Text('Thoát household'),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AppModeCard extends StatelessWidget {
  const _AppModeCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: const [
          ListTile(
            leading: Icon(Icons.dark_mode_outlined),
            title: Text('Giao diện theo hệ thống'),
            subtitle: Text('Tự động dùng sáng hoặc tối theo thiết bị'),
          ),
          Divider(height: 1),
          ListTile(
            leading: Icon(Icons.cloud_done_outlined),
            title: Text('Kết nối Supabase'),
            subtitle: Text('Cấu hình qua file .env'),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String? _validateHouseholdName(String? value) {
  final cleanName = _normalizeHouseholdName(value ?? '');
  if (cleanName.length < 2) {
    return 'Tên household cần tối thiểu 2 ký tự.';
  }
  return null;
}

String _normalizeHouseholdName(String value) {
  return value.trim().replaceAll(RegExp(r'\s+'), ' ');
}

int _parseBudget(String value) {
  final digitsOnly = CurrencyInputFormatter.digitsOnly(value);
  return int.tryParse(digitsOnly) ?? 0;
}

String _formatCurrency(int? amount) {
  if (amount == null) {
    return 'Chưa đặt';
  }

  return NumberFormat.currency(
    locale: 'vi_VN',
    symbol: 'đ',
    decimalDigits: 0,
  ).format(amount);
}

String _roleLabel(UserProfileRole? role) {
  switch (role) {
    case UserProfileRole.owner:
      return 'Chủ household';
    case UserProfileRole.partner:
      return 'Thành viên';
    case UserProfileRole.member:
      return 'Thành viên';
    case null:
      return 'Chưa xác định';
  }
}

String _initials(String fullName) {
  final parts = fullName
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) {
    return 'U';
  }
  if (parts.length == 1) {
    return parts.first.characters.first.toUpperCase();
  }
  return '${parts.first.characters.first}${parts.last.characters.first}'
      .toUpperCase();
}
