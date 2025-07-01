import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/models/transaction_model.dart';

class TransactionsNotifier extends StateNotifier<AsyncValue<List<Transaction>>> {
  final DatabaseHelper _dbHelper;

  TransactionsNotifier(this._dbHelper) : super(const AsyncValue.loading()) {
    loadTransactions();
  }

  Future<void> loadTransactions() async {
    try {
      state = const AsyncValue.loading();
      final transactions = await _dbHelper.getAllTransactions();
      state = AsyncValue.data(transactions);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addTransaction(Transaction transaction) async {
    await _dbHelper.addTransaction(transaction);
    // Refresh the list to show the new transaction at the top.
    // Using loadTransactions() is simpler than trying to insert it into the state manually.
    await loadTransactions();
  }

  Future<void> addMultipleTransactions(List<Transaction> transactions) async {
    // ใช้เมธอดใหม่ที่ทำงานแบบ Batch และ Atomic จาก database helper
    await _dbHelper.addMultipleTransactionsInBatch(transactions);
    await loadTransactions();
  }

  Future<void> deleteTransaction(String transactionId) async {
    try {
      await _dbHelper.deleteTransaction(transactionId);
      // Optimistically update the state to remove the item immediately
      // for a better user experience.
      state = state.whenData((transactions) =>
          transactions.where((t) => t.id != transactionId).toList());
    } catch (e) {
      // If deletion fails, reload the original list to be safe.
      loadTransactions();
      rethrow;
    }
  }
}

final transactionsProvider =
    StateNotifierProvider<TransactionsNotifier, AsyncValue<List<Transaction>>>((ref) {
  return TransactionsNotifier(DatabaseHelper.instance);
});

/// A provider that filters the main transaction list based on an account ID.
/// This is more efficient than re-fetching from the DB as it reuses the
/// already loaded data from [transactionsProvider].
final filteredTransactionsProvider =
    Provider.autoDispose.family<AsyncValue<List<Transaction>>, int>((ref, accountId) {
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
  final filteredTransactionsAsync = ref.watch(filteredTransactionsProvider(accountId));

  return filteredTransactionsAsync.when(
    data: (transactions) => transactions.fold(
        0.0, (sum, t) => sum + (t.type == 'income' ? t.amount : -t.amount)),
    loading: () => 0.0,
    error: (err, stack) => 0.0,
  );
});