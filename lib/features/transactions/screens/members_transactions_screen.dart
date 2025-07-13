import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:month_year_picker/month_year_picker.dart';
import 'package:templefunds/core/models/account_model.dart';
import 'package:templefunds/core/models/transaction_model.dart';
import 'package:templefunds/core/models/user_model.dart';
import 'package:templefunds/features/members/providers/members_provider.dart';
import 'package:templefunds/features/transactions/providers/accounts_provider.dart';
import 'package:templefunds/features/transactions/providers/transactions_provider.dart';
import 'package:templefunds/features/transactions/screens/add_multi_transaction_screen.dart';
import 'package:templefunds/features/transactions/screens/member_transactions_screen.dart';

/// A provider that filters transactions for ALL members for a specific day.
final dailyMembersTransactionsProvider =
    Provider.autoDispose.family<AsyncValue<List<Transaction>>, DateTime>((ref, day) {
  final allTransactionsAsync = ref.watch(transactionsProvider);
  final allAccountsAsync = ref.watch(allAccountsProvider);

  if (allTransactionsAsync.isLoading || allAccountsAsync.isLoading) {
    return const AsyncValue.loading();
  }
  if (allTransactionsAsync.hasError) {
    return AsyncValue.error(allTransactionsAsync.error!, allTransactionsAsync.stackTrace!);
  }
  if (allAccountsAsync.hasError) {
    return AsyncValue.error(allAccountsAsync.error!, allAccountsAsync.stackTrace!);
  }

  try {
    final transactions = allTransactionsAsync.requireValue;
    final accounts = allAccountsAsync.requireValue;

    final memberAccountIds =
        accounts.where((acc) => acc.ownerUserId != null).map((acc) => acc.id).whereNotNull().toSet();

    final filtered = transactions.where((t) {
      final transactionDate = t.transactionDate.toLocal();
      return memberAccountIds.contains(t.accountId) &&
          transactionDate.year == day.year &&
          transactionDate.month == day.month &&
          transactionDate.day == day.day;
    }).toList();

    return AsyncValue.data(filtered);
  } catch (e, st) {
    return AsyncValue.error(e, st);
  }
});

class MembersTransactionsScreen extends ConsumerStatefulWidget {
  const MembersTransactionsScreen({super.key});

  @override
  ConsumerState<MembersTransactionsScreen> createState() =>
      _MembersTransactionsScreenState();
}

class _MembersTransactionsScreenState
    extends ConsumerState<MembersTransactionsScreen> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  void _previousDay() {
    setState(() {
      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
    });
  }

  void _nextDay() {
    if (_isNextDayDisabled()) return;
    setState(() {
      _selectedDate = _selectedDate.add(const Duration(days: 1));
    });
  }

  Future<void> _pickDay(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('th'),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  bool _isNextDayDisabled() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _selectedDate.isAtSameMomentAs(today) || _selectedDate.isAfter(today);
  }

  String _getFormattedDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (date.isAtSameMomentAs(today)) {
      return 'วันนี้';
    }
    if (date.isAtSameMomentAs(yesterday)) {
      return 'เมื่อวาน';
    }
    return DateFormat.yMMMd('th').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('รายการบัญชีพระ'),
      ),
      body: _buildTransactionList(),
      bottomNavigationBar: _buildBottomControls(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const AddMultiTransactionScreen(),
          ));
        },
        tooltip: 'ทำรายการหลายบัญชี',
        child: const Icon(Icons.groups_outlined),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildTransactionList() {
    final dailyTransactionsAsync =
        ref.watch(dailyMembersTransactionsProvider(_selectedDate));
    final allUsersAsync = ref.watch(membersProvider);
    final allAccountsAsync = ref.watch(allAccountsProvider);

    if (dailyTransactionsAsync.isLoading ||
        allUsersAsync.isLoading ||
        allAccountsAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (dailyTransactionsAsync.hasError) {
      return Center(child: Text('เกิดข้อผิดพลาด: ${dailyTransactionsAsync.error}'));
    }
    if (allUsersAsync.hasError) {
      return Center(
          child: Text('เกิดข้อผิดพลาดในการโหลดผู้ใช้: ${allUsersAsync.error}'));
    }
    if (allAccountsAsync.hasError) {
      return Center(
          child: Text('เกิดข้อผิดพลาดในการโหลดบัญชี: ${allAccountsAsync.error}'));
    }

    final transactions = dailyTransactionsAsync.requireValue;
    final users = allUsersAsync.requireValue;
    final accounts = allAccountsAsync.requireValue;
    final userMap = {for (var u in users) u.id: u};
    final accountMap = {for (var a in accounts) a.id: a};

    if (transactions.isEmpty) {
      return const Center(
        child: Text(
          'ไม่มีธุรกรรมในวันนี้',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    double balance = 0;
    for (final t in transactions) {
      balance += t.type == 'income' ? t.amount : -t.amount;
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'สรุปยอดวันนี้:',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                '฿${NumberFormat("#,##0").format(balance)}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: balance >= 0
                          ? Colors.green.shade700
                          : Colors.red.shade700,
                    ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: transactions.length,
            itemBuilder: (ctx, index) {
              final transaction = transactions[index];
              final account = accountMap[transaction.accountId];
              final owner =
                  account != null ? userMap[account.ownerUserId] : null;

              final isIncome = transaction.type == 'income';
              final amountColor =
                  isIncome ? Colors.green.shade700 : Colors.red.shade700;
              final amountPrefix = isIncome ? '+' : '-';
              final creator = userMap[transaction.createdByUserId];
              final creatorName = creator?.name ?? 'ไม่ระบุ';

              return ListTile(
                onTap: owner == null
                    ? null
                    : () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) =>
                              MemberTransactionsScreen(userId: owner.id!),
                        ));
                      },
                leading: CircleAvatar(
                  backgroundColor: amountColor.withOpacity(0.1),
                  child: Icon(
                    isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                    color: amountColor,
                  ),
                ),
                title: Text(
                  transaction.description ?? 'ไม่มีคำอธิบาย',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: RichText(
                  text: TextSpan(
                    style: Theme.of(context).textTheme.bodySmall,
                    children: [
                      TextSpan(
                        text: owner?.name ?? 'ไม่ระบุชื่อ',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      TextSpan(
                        text:
                            ' (id:${owner?.userId1 ?? ''}) • \n${DateFormat('d/MM/yyyy (HH:mm น.)').format(transaction.transactionDate.toLocal())} \n[ ผู้บันทึก: $creatorName ]',
                      ),
                    ],
                  ),
                ),
                isThreeLine: true,
                trailing: Text(
                  '$amountPrefix฿${NumberFormat("#,##0").format(transaction.amount)}',
                  style: TextStyle(
                    color: amountColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBottomControls() {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8.0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _previousDay,
            tooltip: 'วันก่อนหน้า',
          ),
          TextButton(
            onPressed: () => _pickDay(context),
            child: Text(
              _getFormattedDate(_selectedDate),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _isNextDayDisabled() ? null : _nextDay,
            tooltip: 'วันถัดไป',
          ),
        ],
      ),
    );
  }
}