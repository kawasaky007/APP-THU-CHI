import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_constants.dart';
import '../../../../core/router/app_routes.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/widgets/auth_screen_layout.dart';

class InviteCodeScreen extends ConsumerStatefulWidget {
  const InviteCodeScreen({super.key});

  @override
  ConsumerState<InviteCodeScreen> createState() => _InviteCodeScreenState();
}

class _InviteCodeScreenState extends ConsumerState<InviteCodeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _inviteCodeController = TextEditingController();

  @override
  void dispose() {
    _inviteCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    return AuthScreenLayout(
      title: 'Nhập mã mời',
      subtitle: 'Dùng mã mời để tham gia household đã có.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (authState.errorMessage != null) ...[
              AuthErrorBanner(message: authState.errorMessage!),
              const SizedBox(height: AppSpacing.md),
            ],
            TextFormField(
              controller: _inviteCodeController,
              enabled: !authState.isLoading,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9-]')),
                LengthLimitingTextInputFormatter(8),
                _UpperCaseTextFormatter(),
              ],
              decoration: const InputDecoration(
                labelText: 'Mã mời',
                prefixIcon: Icon(Icons.key_outlined),
              ),
              validator: _validateInviteCode,
              onFieldSubmitted: (_) => _submit(),
              onChanged: (_) =>
                  ref.read(authControllerProvider.notifier).clearError(),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: authState.isLoading ? null : _submit,
              icon: authState.isLoading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.group_add_outlined),
              label: const Text('Tham gia household'),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: authState.isLoading
                  ? null
                  : () => context.go(AppRoutes.createHousehold),
              icon: const Icon(Icons.add_home_outlined),
              label: const Text('Tạo household mới'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: authState.isLoading
                  ? null
                  : () => ref.read(authControllerProvider.notifier).logout(),
              child: const Text('Đăng xuất'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (!mounted) {
      return;
    }

    FocusScope.of(context).unfocus();
    final inviteCode = _inviteCodeController.text;

    await ref
        .read(authControllerProvider.notifier)
        .joinHouseholdByInviteCode(inviteCode);
  }

  String? _validateInviteCode(String? value) {
    final inviteCode = value?.trim().replaceAll('-', '') ?? '';
    if (inviteCode.length < 6) {
      return 'Mã mời cần tối thiểu 6 ký tự.';
    }
    return null;
  }
}

class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
