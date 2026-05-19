import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thu_chi_viet_nam/app.dart';
import 'package:thu_chi_viet_nam/features/auth/presentation/providers/auth_provider.dart';
import 'package:thu_chi_viet_nam/features/auth/presentation/providers/auth_state.dart';

void main() {
  testWidgets('hiển thị màn hình đăng nhập khi chưa có phiên', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            (ref) => AuthController.testing(AuthState.unauthenticated()),
          ),
        ],
        child: const ThuChiApp(),
      ),
    );

    await tester.pump();

    expect(find.text('Đăng nhập'), findsWidgets);
    expect(find.text('Chưa có tài khoản? Đăng ký'), findsOneWidget);
  });
}
