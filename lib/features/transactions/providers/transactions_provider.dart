import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/models/transaction_model.dart';

class TransactionsNotifier extends AsyncNotifier<List<Transaction>> {
  late DatabaseHelper _dbHelper;

  @override
  Future<List<Transaction>> build() async {
    _dbHelper = DatabaseHelper.instance;
    return _dbHelper.getAllTransactions();
  }

  Future<void> addTransaction(Transaction transaction) async {
    await _dbHelper.addTransaction(transaction);
    ref.invalidateSelf();
    await future;
  }

  Future<void> addMultipleTransactions(List<Transaction> transactions) async {
    // ใช้เมธอดใหม่ที่ทำงานแบบ Batch และ Atomic จาก database helper
    await _dbHelper.addMultipleTransactionsInBatch(transactions);
    ref.invalidateSelf();
    await future;
  }

  Future<void> deleteTransaction(String transactionId) async {
    final previousState = await future;
    try {
      // Optimistically update the state to remove the item immediately
      state = AsyncValue.data(
          previousState.where((t) => t.id != transactionId).toList());
      await _dbHelper.deleteTransaction(transactionId);
    } catch (e) {
      // If deletion fails, revert to the original list.
      state = AsyncValue.data(previousState);
      rethrow;
    }
  }
}

final transactionsProvider =
    AsyncNotifierProvider<TransactionsNotifier, List<Transaction>>(() {
  return TransactionsNotifier();
});

/// A provider that filters the main transaction list based on an account ID.
/// This is more efficient than re-fetching from the DB as it reuses the
/// already loaded data from [transactionsProvider].
final filteredTransactionsProvider = Provider.autoDispose
    .family<AsyncValue<List<Transaction>>, int>((ref, accountId) {
  final allTransactionsAsync = ref.watch(transactionsProvider);

  return allTransactionsAsync.when(
    data: (transactions) {
      final filtered =
          transactions.where((t) => t.accountId == accountId).toList();
      return AsyncValue.data(filtered);
    },
    loading: () => const AsyncValue.loading(),
    error: (err, stack) => AsyncValue.error(err, stack),
  );
});

/// A provider to get the total balance for a filtered list of transactions.
final filteredBalanceProvider =
    Provider.autoDispose.family<double, int>((ref, accountId) {
  // Watch the main provider and select the calculated value.
  // This is more efficient as it only rebuilds if the calculated sum changes.
  return ref.watch(transactionsProvider).when(
        data: (transactions) => transactions
            .where((t) => t.accountId == accountId)
            .fold(0.0,
                (sum, t) => sum + (t.type == 'income' ? t.amount : -t.amount)),
        loading: () => 0.0, // Return 0 while loading
        error: (e, s) => 0.0, // Return 0 on error
      );
});
