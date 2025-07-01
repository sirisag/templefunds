import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:month_year_picker/month_year_picker.dart';
import 'package:templefunds/core/models/account_model.dart';
import 'package:templefunds/core/models/transaction_model.dart';
import 'package:templefunds/features/members/providers/members_provider.dart';
import 'package:templefunds/features/transactions/providers/accounts_provider.dart';
import 'package:templefunds/features/transactions/providers/transactions_provider.dart';
import 'package:templefunds/features/transactions/screens/add_single_transaction_screen.dart';

// A record to hold the parameters for the family provider
typedef MonthlyFilter = ({int accountId, DateTime month});

/// A provider that filters transactions for a specific account and a specific month.
final monthlyTransactionsProvider =
    Provider.autoDispose.family<AsyncValue<List<Transaction>>, MonthlyFilter>(
        (ref, filter) {
  final allTransactionsAsync = ref.watch(transactionsProvider);

  return allTransactionsAsync.when(
    data: (transactions) {
      final filtered = transactions.where((t) {
        final transactionDate = t.transactionDate.toLocal();
        return t.accountId == filter.accountId &&
            transactionDate.year == filter.month.year &&
            transactionDate.month == filter.month.month;
      }).toList();
      return AsyncValue.data(filtered);
    },
    loading: () => const AsyncValue.loading(),
    error: (err, stack) => AsyncValue.error(err, stack),
  );
});

class TempleTransactionsScreen extends ConsumerStatefulWidget {
  const TempleTransactionsScreen({super.key});

  @override
  ConsumerState<TempleTransactionsScreen> createState() =>
      _TempleTransactionsScreenState();
}

class _TempleTransactionsScreenState
    extends ConsumerState<TempleTransactionsScreen> {
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    // Initialize to the first day of the current month
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month, 1);
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth =
          DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    // Prevent going into the future
    if (_isNextMonthDisabled()) return;
    setState(() {
      _selectedMonth =
          DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
    });
  }

  Future<void> _pickMonth(BuildContext context) async {
    final picked = await showMonthYearPicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('th'),
    );
    if (picked != null) {
      setState(() {
        _selectedMonth = picked;
      });
    }
  }

  bool _isNextMonthDisabled() {
    final now = DateTime.now();
    return _selectedMonth.year == now.year && _selectedMonth.month == now.month;
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(allAccountsProvider);
    final templeAccount = accountsAsync.asData?.value
        .firstWhereOrNull((acc) => acc.ownerUserId == null);

    return Scaffold(
      appBar: AppBar(
        title: const Text('รายการบัญชีวัด'),
      ),
      body: templeAccount == null
          ? accountsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => const Center(child: Text('ไม่พบบัญชีวัด')),
              data: (_) => const Center(child: Text('ไม่พบบัญชีวัด')),
            )
          : _buildTransactionList(templeAccount),
      bottomNavigationBar: _buildBottomControls(),
      floatingActionButton: templeAccount == null
          ? null
          : FloatingActionButton(
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => AddSingleTransactionScreen(
                      preselectedAccount: templeAccount),
                ));
              },
              child: const Icon(Icons.add),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildTransactionList(Account templeAccount) {
    final filter = (accountId: templeAccount.id!, month: _selectedMonth);
    final monthlyTransactionsAsync =
        ref.watch(monthlyTransactionsProvider(filter));
    final allUsersAsync = ref.watch(membersProvider);

    // Handle combined loading/error states first
    if (monthlyTransactionsAsync.isLoading || allUsersAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (monthlyTransactionsAsync.hasError) {
      return Center(
          child: Text('เกิดข้อผิดพลาด: ${monthlyTransactionsAsync.error}'));
    }

    if (allUsersAsync.hasError) {
      return Center(
          child: Text('เกิดข้อผิดพลาดในการโหลดผู้ใช้: ${allUsersAsync.error}'));
    }

    final transactions = monthlyTransactionsAsync.requireValue;
    final users = allUsersAsync.requireValue;
    final userMap = {for (var u in users) u.id: u};

    if (transactions.isEmpty) {
      return const Center(
        child: Text(
          'ไม่มีธุรกรรมในเดือนนี้',
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
                'สรุปยอดเดือนนี้:',
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
              final isIncome = transaction.type == 'income';
              final amountColor =
                  isIncome ? Colors.green.shade700 : Colors.red.shade700;
              final amountPrefix = isIncome ? '+' : '-';
              final creator = userMap[transaction.createdByUserId];
              final creatorName = creator?.name ?? 'ไม่ระบุ';

              return ListTile(
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
                subtitle: Text(
                  '${DateFormat('d/MM/yyyy, (HH:mm น.)').format(transaction.transactionDate.toLocal())} \n[ผู้บันทึก: $creatorName]',
                ),
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
            onPressed: _previousMonth,
            tooltip: 'เดือนก่อนหน้า',
          ),
          TextButton(
            onPressed: () => _pickMonth(context),
            child: Text(
              DateFormat.yMMM('th').format(_selectedMonth),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _isNextMonthDisabled() ? null : _nextMonth,
            tooltip: 'เดือนถัดไป',
          ),
        ],
              ),
    );
  }
}