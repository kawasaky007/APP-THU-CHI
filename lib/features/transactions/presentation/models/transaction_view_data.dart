import '../../../../core/models/models.dart';

class TransactionViewData {
  const TransactionViewData({
    required this.transaction,
    required this.creatorName,
    required this.isCurrentUser,
  });

  final Transaction transaction;
  final String creatorName;
  final bool isCurrentUser;

  static String resolveCreatorName({
    required String creatorUserId,
    required String currentUserId,
    required Map<String, UserProfile> profilesById,
  }) {
    if (creatorUserId == currentUserId) {
      return 'Bạn';
    }

    final profile = profilesById[creatorUserId];
    if (profile == null) {
      return 'Không rõ';
    }

    final fullName = profile.fullName.trim();
    if (fullName.isEmpty) {
      return 'Thành viên';
    }

    return fullName;
  }

  static String resolveMemberName({
    required String memberUserId,
    required Map<String, UserProfile> profilesById,
  }) {
    final profile = profilesById[memberUserId];
    if (profile == null) {
      return 'Không rõ';
    }

    final fullName = profile.fullName.trim();
    if (fullName.isNotEmpty) {
      return fullName;
    }

    final email = profile.email.trim();
    if (email.isNotEmpty) {
      return email;
    }

    return 'Thành viên';
  }

  static List<TransactionViewData> fromTransactions({
    required List<Transaction> transactions,
    required Map<String, UserProfile> profilesById,
    required String currentUserId,
  }) {
    return transactions.map((transaction) {
      final isCurrentUser = transaction.userId == currentUserId;
      final creatorName = resolveCreatorName(
        creatorUserId: transaction.userId,
        currentUserId: currentUserId,
        profilesById: profilesById,
      );

      return TransactionViewData(
        transaction: transaction,
        creatorName: creatorName,
        isCurrentUser: isCurrentUser,
      );
    }).toList();
  }
}
