import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:templefunds/core/utils/date_formatter.dart';
import 'package:flutter_rounded_date_picker/flutter_rounded_date_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:templefunds/core/models/account_model.dart';
import 'package:templefunds/core/models/transaction_model.dart';
import 'package:templefunds/core/models/user_model.dart';
import 'package:templefunds/core/services/pdf_export_service.dart';
import 'package:templefunds/features/auth/providers/auth_provider.dart';
import 'package:templefunds/features/settings/providers/settings_provider.dart';
import 'package:templefunds/features/members/providers/members_provider.dart';
import 'package:templefunds/features/transactions/providers/accounts_provider.dart';
import 'package:templefunds/features/transactions/providers/transactions_provider.dart';
import 'package:templefunds/features/transactions/screens/add_single_transaction_screen.dart';
import 'package:printing/printing.dart';

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
    final picked = await showRoundedDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale("th","TH"),
      era: EraMode.BUDDHIST_YEAR,
      initialDatePickerMode: DatePickerMode.year,
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

  Future<void> _exportToPdf(
    BuildContext context,
    String templeName,
    User? adminUser,
    User? masterUser,
    Account templeAccount,
    List<Transaction> transactions,
    double totalBalance,
    double startingBalance,
  ) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('กำลังสร้างไฟล์ PDF...')),
    );

    try {
      final pdfService = PdfExportService();

      final monthlyIncome = transactions
          .where((t) => t.type == 'income')
          .fold(0.0, (sum, t) => sum + t.amount);
      final monthlyExpense = transactions
          .where((t) => t.type == 'expense')
          .fold(0.0, (sum, t) => sum + t.amount);

      final pdfData = await pdfService.generateTempleMonthlyReport(
        templeName: templeName,
        adminUser: adminUser,
        masterUser: masterUser,
        accountName: templeAccount.name,
        month: _selectedMonth,
        transactions: transactions,
        monthlyIncome: monthlyIncome,
        monthlyExpense: monthlyExpense,
        totalBalance: totalBalance,
        startingBalance: startingBalance,
      );

      await Printing.layoutPdf(
        onLayout: (format) async => pdfData,
        name:
            'report_${templeName.replaceAll(' ', '_')}_${DateFormatter.formatBE(_selectedMonth, 'yyyy-MM')}.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาดในการสร้าง PDF: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(allAccountsProvider);
    final templeAccount = accountsAsync.asData?.value
        .firstWhereOrNull((acc) => acc.ownerUserId == null);

    return Scaffold(
      appBar: AppBar(
        title: const Text('รายการบัญชีวัด'),
        actions: [
          if (templeAccount != null)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              tooltip: 'ส่งออกเป็น PDF',
              onPressed: () {
                final templeName = ref.read(templeNameProvider).asData?.value;                
                final allTransactions = ref.read(transactionsProvider).asData?.value;

                // Get user info for the report
                final adminUser = ref.read(authProvider).user;
                final allMembers = ref.read(membersProvider).asData?.value;
                final masterUser =
                    allMembers?.firstWhereOrNull((u) => u.role == UserRole.Master);
                
                if (allTransactions != null && templeName != null && allMembers != null) {
                  // Filter for monthly transactions
                  final monthlyTransactions = allTransactions.where((t) {
                      final transactionDate = t.transactionDate.toLocal();
                      return t.accountId == templeAccount.id! &&
                          transactionDate.year == _selectedMonth.year &&
                          transactionDate.month == _selectedMonth.month;
                  }).toList();
                  monthlyTransactions.sort((a, b) => a.transactionDate.compareTo(b.transactionDate));

                  // Calculate starting balance (balance before the first day of the selected month)
                  final firstDayOfSelectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
                  final startingBalance = allTransactions
                      .where((t) => t.accountId == templeAccount.id! && t.transactionDate.isBefore(firstDayOfSelectedMonth))
                      .fold(0.0, (sum, t) => sum + (t.type == 'income' ? t.amount : -t.amount));

                  // Calculate ending balance
                  final monthlyIncome = monthlyTransactions.where((t) => t.type == 'income').fold(0.0, (sum, t) => sum + t.amount);
                  final monthlyExpense = monthlyTransactions.where((t) => t.type == 'expense').fold(0.0, (sum, t) => sum + t.amount);
                  final endingBalance = startingBalance + monthlyIncome - monthlyExpense;

                  _exportToPdf(context, templeName, adminUser, masterUser,
                      templeAccount, monthlyTransactions, endingBalance, startingBalance);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                            Text('ไม่สามารถส่งออกได้เนื่องจากข้อมูลยังไม่พร้อม')),
                  );
                }
              },
            ),
        ],
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
    final totalBalance = ref.watch(filteredBalanceProvider(templeAccount.id!));

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

    double monthlyBalance = 0;
    for (final t in transactions) {
      monthlyBalance += t.type == 'income' ? t.amount : -t.amount;
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'สรุปยอดเดือนนี้:',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    '฿${NumberFormat("#,##0").format(monthlyBalance)}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: monthlyBalance >= 0
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'ยอดคงเหลือทั้งหมด:',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    '฿${NumberFormat("#,##0").format(totalBalance)}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: totalBalance >= 0
                              ? Colors.blue.shade800
                              : Colors.orange.shade800,
                        ),
                  ),
                ],
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
                  '${DateFormatter.formatBE(transaction.transactionDate.toLocal(), "d MMM yyyy (HH:mm'น.')")} \n[ผู้บันทึก: $creatorName]',
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
              DateFormatter.formatBE(_selectedMonth, 'MMM yyyy'),
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
