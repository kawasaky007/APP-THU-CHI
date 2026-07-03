import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_constants.dart';
import '../../../../core/models/models.dart';
import '../../../../shared/widgets/app_feedback.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../categories/presentation/providers/category_provider.dart';
import '../../../transactions/presentation/providers/transaction_provider.dart';
import '../providers/profile_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late final TextEditingController _nameController;
  bool _isEditingName = false;
  String? _nameErrorText;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final profileActionState = ref.watch(profileActionProvider);
    final profile = authState.profile;
    final household = authState.household;
    final inviteCode = household?.inviteCode;
    final householdMembersAsync = household == null
        ? const AsyncValue<List<UserProfile>>.data([])
        : ref.watch(householdProfilesStreamProvider(household.id));

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
            _ProfileHeader(
              profile: profile,
              onEditName: profile == null || profileActionState.isLoading
                  ? null
                  : () => _startEditName(profile),
            ),
            const SizedBox(height: AppSpacing.md),
            _PersonalInfoCard(
              profile: profile,
              isEditingName: _isEditingName,
              isSavingName: profileActionState.isLoading,
              nameController: _nameController,
              nameErrorText: _nameErrorText ?? profileActionState.errorMessage,
              onEditName: profile == null || profileActionState.isLoading
                  ? null
                  : () => _startEditName(profile),
              onCancelEditName: profileActionState.isLoading
                  ? null
                  : _cancelEditName,
              onSaveName: profileActionState.isLoading ? null : _saveName,
              onNameChanged: (_) {
                if (_nameErrorText != null ||
                    profileActionState.errorMessage != null) {
                  _setLocalState(() => _nameErrorText = null);
                  ref.read(profileActionProvider.notifier).clearError();
                }
              },
            ),
            const SizedBox(height: AppSpacing.md),
            _HouseholdCard(
              household: household,
              role: profile?.role,
              onCopyInviteCode: inviteCode == null
                  ? null
                  : () => _copyInviteCode(inviteCode),
              onRenameHousehold: household == null
                  ? null
                  : () => _renameHousehold(context, ref, household),
              transferCandidates: _transferCandidates(
                householdMembersAsync.valueOrNull ?? const <UserProfile>[],
                household: household,
              ),
              isLoadingMembers:
                  householdMembersAsync.valueOrNull == null &&
                  householdMembersAsync.isLoading,
              onTransferOwnership:
                  household == null ||
                      profile?.role != UserProfileRole.owner ||
                      authState.isLoading
                  ? null
                  : (members) =>
                        _transferOwnership(context, ref, household, members),
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

  void _startEditName(UserProfile profile) {
    _setLocalState(() {
      _isEditingName = true;
      _nameErrorText = null;
      _nameController.text = profile.fullName;
      _nameController.selection = TextSelection.collapsed(
        offset: _nameController.text.length,
      );
    });
    ref.read(profileActionProvider.notifier).clearError();
  }

  void _cancelEditName() {
    _setLocalState(() {
      _isEditingName = false;
      _nameErrorText = null;
      _nameController.clear();
    });
    ref.read(profileActionProvider.notifier).clearError();
  }

  Future<void> _saveName() async {
    final validationError = _validateProfileName(_nameController.text);
    if (validationError != null) {
      _setLocalState(() => _nameErrorText = validationError);
      return;
    }

    final cleanName = _normalizeProfileName(_nameController.text);
    final success = await ref
        .read(profileActionProvider.notifier)
        .updateUserProfileName(cleanName);
    if (!mounted) {
      return;
    }

    if (success) {
      _setLocalState(() {
        _isEditingName = false;
        _nameErrorText = null;
        _nameController.text = cleanName;
      });
      AppFeedback.showSnackBar('Đã cập nhật tên hiển thị.');
      return;
    }

    final message =
        ref.read(profileActionProvider).errorMessage ??
        'Không thể cập nhật tên hiển thị. Vui lòng thử lại.';
    _setLocalState(() => _nameErrorText = message);
    AppFeedback.showSnackBar(message, isError: true);
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

  Future<void> _transferOwnership(
    BuildContext context,
    WidgetRef ref,
    Household household,
    List<UserProfile> candidates,
  ) async {
    if (candidates.isEmpty) {
      AppFeedback.showSnackBar(
        'Không có thành viên khác để chuyển quyền.',
        isError: true,
      );
      return;
    }

    final selectedMember = await showDialog<UserProfile>(
      context: context,
      builder: (_) => _TransferOwnershipDialog(members: candidates),
    );
    if (!context.mounted || selectedMember == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final memberName = _memberDisplayName(selectedMember);
        return AlertDialog(
          title: Text('Transfer ownership to "$memberName"?'),
          content: Text(
            'This action will make $memberName the new Household Owner.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Hủy'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.admin_panel_settings_outlined),
              label: const Text('Chuyển quyền'),
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
        .transferHouseholdOwnership(selectedMember.id);
    if (!context.mounted) {
      return;
    }

    if (success) {
      _refreshHouseholdProviders(ref, household.id);
      AppFeedback.showSnackBar('Đã chuyển quyền chủ household.');
      return;
    }

    final message =
        ref.read(authControllerProvider).errorMessage ??
        'Không thể chuyển quyền chủ household. Vui lòng thử lại.';
    await AppFeedback.showErrorDialog(
      title: 'Không thể chuyển quyền',
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

  void _setLocalState(VoidCallback update) {
    if (!mounted) {
      return;
    }
    setState(update);
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

class _TransferOwnershipDialog extends StatefulWidget {
  const _TransferOwnershipDialog({required this.members});

  final List<UserProfile> members;

  @override
  State<_TransferOwnershipDialog> createState() =>
      _TransferOwnershipDialogState();
}

class _TransferOwnershipDialogState extends State<_TransferOwnershipDialog> {
  String? _selectedMemberId;

  @override
  void initState() {
    super.initState();
    _selectedMemberId = widget.members.isEmpty ? null : widget.members.first.id;
  }

  @override
  Widget build(BuildContext context) {
    final selectedMember = _selectedMember(widget.members, _selectedMemberId);

    return AlertDialog(
      title: const Text('Transfer Household Ownership'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final member in widget.members)
              ListTile(
                onTap: () => setState(() => _selectedMemberId = member.id),
                leading: Icon(
                  member.id == _selectedMemberId
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                title: Text(
                  _memberDisplayName(member),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  member.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        FilledButton.icon(
          onPressed: selectedMember == null
              ? null
              : () => Navigator.of(context).pop(selectedMember),
          icon: const Icon(Icons.arrow_forward),
          label: const Text('Tiếp tục'),
        ),
      ],
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile, required this.onEditName});

  final UserProfile? profile;
  final VoidCallback? onEditName;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final profile = this.profile;
    final fullName = profile == null || profile.fullName.trim().isEmpty
        ? 'Người dùng'
        : profile.fullName;
    final avatarUrl = profile?.avatarUrl?.trim();

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
            foregroundImage: avatarUrl == null || avatarUrl.isEmpty
                ? null
                : NetworkImage(avatarUrl),
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
          const SizedBox(width: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: onEditName,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Sửa'),
          ),
        ],
      ),
    );
  }
}

class _PersonalInfoCard extends StatelessWidget {
  const _PersonalInfoCard({
    required this.profile,
    required this.isEditingName,
    required this.isSavingName,
    required this.nameController,
    required this.nameErrorText,
    required this.onEditName,
    required this.onCancelEditName,
    required this.onSaveName,
    required this.onNameChanged,
  });

  final UserProfile? profile;
  final bool isEditingName;
  final bool isSavingName;
  final TextEditingController nameController;
  final String? nameErrorText;
  final VoidCallback? onEditName;
  final VoidCallback? onCancelEditName;
  final VoidCallback? onSaveName;
  final ValueChanged<String> onNameChanged;

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
            if (isEditingName)
              _EditProfileNameForm(
                controller: nameController,
                errorText: nameErrorText,
                isSaving: isSavingName,
                onCancel: onCancelEditName,
                onSave: onSaveName,
                onChanged: onNameChanged,
              )
            else
              _InfoRow(
                icon: Icons.badge_outlined,
                label: 'Họ tên',
                value: profile?.fullName ?? 'Chưa cập nhật',
                trailing: IconButton.outlined(
                  tooltip: 'Sửa tên hiển thị',
                  onPressed: onEditName,
                  icon: const Icon(Icons.edit_outlined),
                ),
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
    required this.transferCandidates,
    required this.isLoadingMembers,
    required this.onTransferOwnership,
    required this.onLeaveHousehold,
    required this.onDeleteHousehold,
  });

  final Household? household;
  final UserProfileRole? role;
  final VoidCallback? onCopyInviteCode;
  final VoidCallback? onRenameHousehold;
  final List<UserProfile> transferCandidates;
  final bool isLoadingMembers;
  final ValueChanged<List<UserProfile>>? onTransferOwnership;
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
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed:
                            onTransferOwnership == null || isLoadingMembers
                            ? null
                            : () => onTransferOwnership!(transferCandidates),
                        icon: isLoadingMembers
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.admin_panel_settings_outlined),
                        label: const Text('Transfer Household Ownership'),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
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
                    ),
                  ],
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

class _EditProfileNameForm extends StatelessWidget {
  const _EditProfileNameForm({
    required this.controller,
    required this.errorText,
    required this.isSaving,
    required this.onCancel,
    required this.onSave,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String? errorText;
  final bool isSaving;
  final VoidCallback? onCancel;
  final VoidCallback? onSave;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            enabled: !isSaving,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            maxLength: 50,
            inputFormatters: [LengthLimitingTextInputFormatter(50)],
            decoration: InputDecoration(
              labelText: 'Họ tên',
              prefixIcon: const Icon(Icons.badge_outlined),
              errorText: errorText,
              counterText: '',
            ),
            onChanged: onChanged,
            onSubmitted: (_) {
              if (onSave != null) {
                onSave!();
              }
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onCancel,
                  icon: const Icon(Icons.close),
                  label: const Text('Hủy'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onSave,
                  icon: isSaving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(isSaving ? 'Đang lưu' : 'Lưu'),
                ),
              ),
            ],
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
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;

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
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.sm),
            trailing!,
          ],
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

String? _validateProfileName(String? value) {
  final cleanName = _normalizeProfileName(value ?? '');
  if (cleanName.isEmpty) {
    return 'Tên hiển thị không được để trống.';
  }
  if (cleanName.length > 50) {
    return 'Tên hiển thị tối đa 50 ký tự.';
  }
  return null;
}

String _normalizeHouseholdName(String value) {
  return value.trim().replaceAll(RegExp(r'\s+'), ' ');
}

String _normalizeProfileName(String value) {
  return value.trim().replaceAll(RegExp(r'\s+'), ' ');
}

List<UserProfile> _transferCandidates(
  List<UserProfile> members, {
  required Household? household,
}) {
  if (household == null) {
    return const [];
  }

  final candidates = members
      .where(
        (member) =>
            member.id != household.ownerId &&
            member.householdId == household.id,
      )
      .toList();
  candidates.sort(
    (a, b) => _memberDisplayName(
      a,
    ).toLowerCase().compareTo(_memberDisplayName(b).toLowerCase()),
  );
  return candidates;
}

UserProfile? _selectedMember(List<UserProfile> members, String? memberId) {
  if (memberId == null) {
    return null;
  }
  for (final member in members) {
    if (member.id == memberId) {
      return member;
    }
  }
  return null;
}

String _memberDisplayName(UserProfile member) {
  final fullName = member.fullName.trim();
  if (fullName.isNotEmpty) {
    return fullName;
  }

  final email = member.email.trim();
  if (email.isNotEmpty) {
    return email;
  }

  return 'Thành viên';
}

void _refreshHouseholdProviders(WidgetRef ref, String householdId) {
  ref.invalidate(householdProfilesStreamProvider(householdId));
  ref.invalidate(profilesByIdProvider(householdId));
  ref.invalidate(categoriesStreamProvider(householdId));
  ref.invalidate(transactionsStreamProvider(householdId));
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
