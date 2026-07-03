import 'package:flutter_test/flutter_test.dart';
import 'package:thu_chi_viet_nam/core/models/models.dart';
import 'package:thu_chi_viet_nam/features/transactions/presentation/models/transaction_view_data.dart';

void main() {
  group('TransactionViewData.resolveMemberName', () {
    test('uses household member full name', () {
      final name = TransactionViewData.resolveMemberName(
        memberUserId: 'mom',
        profilesById: const {
          'mom': UserProfile(
            id: 'mom',
            email: 'mom@example.com',
            fullName: 'Mẹ',
          ),
        },
      );

      expect(name, 'Mẹ');
    });

    test('falls back to email when full name is blank', () {
      final name = TransactionViewData.resolveMemberName(
        memberUserId: 'member-1',
        profilesById: const {
          'member-1': UserProfile(
            id: 'member-1',
            email: 'member@example.com',
            fullName: ' ',
          ),
        },
      );

      expect(name, 'member@example.com');
    });

    test('returns unknown label for missing profile', () {
      final name = TransactionViewData.resolveMemberName(
        memberUserId: 'missing',
        profilesById: const {},
      );

      expect(name, 'Không rõ');
    });
  });
}
