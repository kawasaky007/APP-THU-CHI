import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_constants.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../shared/formatters/currency_input_formatter.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/widgets/auth_screen_layout.dart';

class CreateHouseholdScreen extends ConsumerStatefulWidget {
  const CreateHouseholdScreen({super.key});

  @override
  ConsumerState<CreateHouseholdScreen> createState() =>
      _CreateHouseholdScreenState();
}

class _CreateHouseholdScreenState extends ConsumerState<CreateHouseholdScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _budgetController = TextEditingController();

  @override
  void initState() {
    super.initState();

    final profile = ref.read(authControllerProvider).profile;
    final fullName = profile?.fullName.trim();
    _nameController.text = fullName == null || fullName.isEmpty
        ? 'Gia đình của tôi'
        : 'Gia đình của $fullName';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    return AuthScreenLayout(
      title: 'Tạo household',
      subtitle: 'Thiết lập không gian thu chi chung cho hai vợ chồng.',
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
              controller: _nameController,
              enabled: !authState.isLoading,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Tên household',
                prefixIcon: Icon(Icons.home_outlined),
              ),
              validator: _validateName,
              onChanged: (_) =>
                  ref.read(authControllerProvider.notifier).clearError(),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _budgetController,
              enabled: !authState.isLoading,
              keyboardType: TextInputType.number,
              inputFormatters: const [CurrencyInputFormatter()],
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Ngân sách tháng',
                prefixIcon: Icon(Icons.savings_outlined),
                suffixText: 'đ',
              ),
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
                  : const Icon(Icons.add_home_outlined),
              label: const Text('Tạo household mới'),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: authState.isLoading
                  ? null
                  : () {
                      if (context.mounted) {
                        context.go(AppRoutes.inviteCode);
                      }
                    },
              icon: const Icon(Icons.group_add_outlined),
              label: const Text('Tôi có mã mời'),
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
    if (_formKey.currentState?.validate() != true) {
      return;
    }
    if (!mounted) {
      return;
    }

    FocusScope.of(context).unfocus();
    final name = _nameController.text;
    final monthlyBudget = _parseBudget(_budgetController.text);

    await ref
        .read(authControllerProvider.notifier)
        .createHousehold(name: name, monthlyBudget: monthlyBudget);
  }

  String? _validateName(String? value) {
    if ((value?.trim() ?? '').length < 2) {
      return 'Vui lòng nhập tên household.';
    }
    return null;
  }

  int _parseBudget(String value) {
    final digitsOnly = CurrencyInputFormatter.digitsOnly(value);
    return int.tryParse(digitsOnly) ?? 0;
  }
}
