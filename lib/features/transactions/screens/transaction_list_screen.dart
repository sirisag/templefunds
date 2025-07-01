import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';
import 'package:templefunds/features/transactions/providers/accounts_provider.dart';
import 'package:templefunds/features/transactions/providers/transactions_provider.dart';
import 'package:templefunds/features/transactions/screens/add_multi_transaction_screen.dart';
import 'package:templefunds/features/transactions/screens/add_single_transaction_screen.dart';

class TransactionListScreen extends ConsumerWidget {
  const TransactionListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionsProvider);
    final accountsAsync = ref.watch(allAccountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('จัดการธุรกรรม'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(transactionsProvider.notifier).loadTransactions(),
          ),
        ],
      ),
      body: transactionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('เกิดข้อผิดพลาด: $err')),
        data: (transactions) {
          if (transactions.isEmpty) {
            return const Center(
              child: Text(
                'ยังไม่มีธุรกรรม\nกดปุ่ม + เพื่อเพิ่มรายการใหม่',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }
          return ListView.builder(
            itemCount: transactions.length,
            itemBuilder: (ctx, index) {
              final transaction = transactions[index];
              final isIncome = transaction.type == 'income';
              final amountColor = isIncome ? Colors.green : Colors.red;
              final amountPrefix = isIncome ? '+' : '-';

              return Card(
                margin:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: amountColor.withOpacity(0.1),
                    child: Icon(
                      isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                      color: amountColor,
                    ),
                  ),
                  title: Text(transaction.description ?? 'ไม่มีคำอธิบาย'),
                  subtitle: Text(
                    DateFormat('d MMM yyyy, HH:mm')
                        .format(transaction.transactionDate.toLocal()),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$amountPrefix ฿${transaction.amount.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: amountColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline,
                            color: Colors.grey.shade600),
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('ยืนยันการลบ'),
                              content:
                                  const Text('คุณต้องการลบรายการนี้ใช่หรือไม่?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(false),
                                  child: const Text('ยกเลิก'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(true),
                                  child: const Text('ลบ'),
                                  style: TextButton.styleFrom(
                                      foregroundColor: Colors.red),
                                ),
                              ],
                            ),
                          );

                          if (confirmed == true) {
                            await ref.read(transactionsProvider.notifier).deleteTransaction(transaction.id);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: SpeedDial(
        icon: Icons.add,
        activeIcon: Icons.close,
        children: [
          SpeedDialChild(
            child: const Icon(Icons.account_balance_outlined),
            label: 'ธุรกรรมวัด',
            onTap: () {
              final templeAccount = accountsAsync.asData?.value
                  .firstWhereOrNull((acc) => acc.ownerUserId == null);
              if (templeAccount != null) {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) =>
                      AddSingleTransactionScreen(preselectedAccount: templeAccount),
                ));
              }
            },
          ),
          SpeedDialChild(
            child: const Icon(Icons.groups_outlined),
            label: 'หลายบัญชี',
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const AddMultiTransactionScreen(),
              ));
            },
          ),
          SpeedDialChild(
            child: const Icon(Icons.person_outline),
            label: 'บัญชีเดี่ยว',
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const AddSingleTransactionScreen(),
              ));
            },
          ),
        ],
      ),
    );
  }
}