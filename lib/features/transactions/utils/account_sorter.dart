import 'package:collection/collection.dart';
import 'package:templefunds/core/models/account_model.dart';
import 'package:templefunds/core/models/transaction_model.dart';
import 'package:templefunds/core/models/user_model.dart';

/// Sorts accounts for the multi-transaction screen with a specific order.
///
/// The sorting order is:
/// 1. Temple Account (if it exists).
/// 2. Master Account (if it exists).
/// 3. Other member accounts, sorted by the most recent transaction date.
List<Account> sortAccountsForTransaction(
  List<Account> accounts,
  List<User> members,
  List<Transaction> allTransactions,
) {
  final Account? templeAccount =
      accounts.firstWhereOrNull((acc) => acc.ownerUserId == null);

  final userMap = {for (var user in members) user.id: user};

  // Create a map of accountId to the latest transaction date
  final latestTransactionDates = <int, DateTime>{};
  for (final transaction in allTransactions) {
    final accountId = transaction.accountId;
    final transactionDate = transaction.transactionDate;
    if (!latestTransactionDates.containsKey(accountId) ||
        transactionDate.isAfter(latestTransactionDates[accountId]!)) {
      latestTransactionDates[accountId] = transactionDate;
    }
  }

  final memberAccounts =
      accounts.where((acc) => acc.ownerUserId != null).toList();

  memberAccounts.sort((a, b) {
    final userA = userMap[a.ownerUserId];
    final userB = userMap[b.ownerUserId];

    if (userA == null) return 1;
    if (userB == null) return -1;

    // Master always comes first among members
    if (userA.role == 'Master' && userB.role != 'Master') return -1;
    if (userB.role == 'Master' && userA.role != 'Master') return 1;

    // Sort by latest transaction date (descending)
    final dateA = latestTransactionDates[a.id];
    final dateB = latestTransactionDates[b.id];

    if (dateA != null && dateB != null) {
      final dateComparison = dateB.compareTo(dateA);
      if (dateComparison != 0) return dateComparison;
    }
    if (dateA != null && dateB == null) return -1;
    if (dateA == null && dateB != null) return 1;

    return a.name.compareTo(b.name);
  });

  return [
    if (templeAccount != null) templeAccount,
    ...memberAccounts,
  ];
}