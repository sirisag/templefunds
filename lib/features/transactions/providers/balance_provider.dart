import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:templefunds/features/transactions/providers/accounts_provider.dart';
import 'package:templefunds/features/transactions/providers/transactions_provider.dart';

/// A simple class to hold the calculated balances.
class BalanceSummary {
  final double templeBalance;
  final double membersBalance;

  BalanceSummary({
    required this.templeBalance,
    required this.membersBalance,
  });
}

/// A provider that calculates the balance summary for the temple and all members.
/// It watches both transactions and accounts providers and recalculates when they change.
final balanceSummaryProvider =
    Provider.autoDispose<AsyncValue<BalanceSummary>>((ref) {
  final transactionsAsync = ref.watch(transactionsProvider);
  final accountsAsync = ref.watch(allAccountsProvider);

  // If either provider is loading, the summary is also loading.
  if (transactionsAsync.isLoading || accountsAsync.isLoading) {
    return const AsyncValue.loading();
  }

  // Propagate any errors.
  if (transactionsAsync.hasError) {
    return AsyncValue.error(transactionsAsync.error!, transactionsAsync.stackTrace!);
  }
  if (accountsAsync.hasError) {
    return AsyncValue.error(accountsAsync.error!, accountsAsync.stackTrace!);
  }

  try {
    final transactions = transactionsAsync.requireValue;
    final accounts = accountsAsync.requireValue;

    final templeAccountId =
        accounts.firstWhereOrNull((acc) => acc.ownerUserId == null)?.id;

    final memberAccountIds =
        accounts.where((acc) => acc.ownerUserId != null).map((acc) => acc.id).toSet();

    double templeBalance = 0.0;
    double membersBalance = 0.0;

    for (final transaction in transactions) {
      final amount =
          transaction.type == 'income' ? transaction.amount : -transaction.amount;

      if (transaction.accountId == templeAccountId) {
        templeBalance += amount;
      } else if (memberAccountIds.contains(transaction.accountId)) {
        membersBalance += amount;
      }
    }

    return AsyncValue.data(BalanceSummary(
      templeBalance: templeBalance,
      membersBalance: membersBalance,
    ));
  } catch (e, st) {
    return AsyncValue.error(e, st);
  }
});