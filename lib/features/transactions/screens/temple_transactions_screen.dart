import 'package:collection/collection.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_rounded_date_picker/flutter_rounded_date_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:templefunds/core/models/account_model.dart';
import 'package:templefunds/features/auth/providers/auth_provider.dart';
import 'package:templefunds/core/models/user_model.dart';
import 'package:templefunds/core/models/transaction_model.dart';
import 'package:templefunds/core/services/report_generation_service.dart';
import 'package:templefunds/features/members/providers/members_provider.dart';
import 'package:templefunds/core/utils/date_formatter.dart';
import 'package:templefunds/features/transactions/providers/accounts_provider.dart';
import 'package:templefunds/features/settings/widgets/temple_avatar.dart';
import 'package:templefunds/features/transactions/providers/transactions_provider.dart';
import 'package:templefunds/features/transactions/screens/add_single_transaction_screen.dart';

class TempleTransactionsScreen extends ConsumerStatefulWidget {
  const TempleTransactionsScreen({super.key});

  @override
  ConsumerState<TempleTransactionsScreen> createState() =>
      _TempleTransactionsScreenState();
}

class _TempleTransactionsScreenState
    extends ConsumerState<TempleTransactionsScreen> {
  late DateTime _selectedMonth;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Initialize to the first day of the current month
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month, 1);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
      locale: const Locale("th", "TH"),
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

  void _showReceiptImage(BuildContext context, String imagePath) {
    final file = File(imagePath);
    if (!file.existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่พบไฟล์รูปภาพ')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: InteractiveViewer(
          panEnabled: true,
          minScale: 0.5,
          maxScale: 4,
          child: Image.file(file),
        ),
      ),
    );
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
              onPressed: () async {
                final reportService = ref.read(reportGenerationServiceProvider);
                await reportService.generateAndShowTempleReport(
                    context, _selectedMonth);
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
      floatingActionButton:
          ref.watch(authProvider).user?.role == UserRole.Admin &&
                  templeAccount != null
              ? FloatingActionButton(
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => AddSingleTransactionScreen(
                          preselectedAccount: templeAccount),
                    ));
                  },
                  child: const Icon(Icons.add),
                )
              : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildTransactionList(Account templeAccount) {
    final filter = (accountId: templeAccount.id!, month: _selectedMonth);
    final monthlyTransactionsAsync =
        ref.watch(monthlyTransactionsProvider(filter));
    final allUsersAsync = ref.watch(membersProvider);

    // Calculate the end of the selected month to get the balance up to that point.
    final endOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    final balanceFilter = (accountId: templeAccount.id!, date: endOfMonth);
    final balanceAtMonthEnd = ref.watch(balanceUpToDateProvider(balanceFilter));

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

    // Scroll to the bottom after the frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

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
                    'ยอดคงเหลือ ณ สิ้นเดือน:',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    '฿${NumberFormat("#,##0").format(balanceAtMonthEnd)}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: balanceAtMonthEnd >= 0
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
            controller: _scrollController,
            // reverse: true, // This was causing the issue
            itemCount: transactions.length,
            itemBuilder: (ctx, index) {
              final transaction = transactions[index];
              final isIncome = transaction.type == 'income';
              final amountColor =
                  isIncome ? Colors.green.shade700 : Colors.red.shade700;
              final amountPrefix = isIncome ? '+' : '-';
              final creator = userMap[transaction.createdByUserId];
              final creatorName = creator?.nickname ?? 'ไม่ระบุ';

              return ListTile(
                onTap: (transaction.receiptImage?.isNotEmpty ?? false)
                    ? () => _showReceiptImage(
                          context,
                          transaction.receiptImage!,
                        )
                    : null,
                leading: const TempleAvatar(radius: 28),
                title: RichText(
                  text: TextSpan(
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium, // Default style for the entire RichText
                    children: [
                      TextSpan(
                          text: transaction.description ?? 'ไม่มีคำอธิบาย',
                          style: const TextStyle(
                              fontWeight:
                                  FontWeight.bold)), // Bold for description
                      if (transaction.remark?.isNotEmpty ?? false)
                        TextSpan(
                            text: ' (${transaction.remark})',
                            style: TextStyle(
                                color: Colors.grey.shade600,
                                fontWeight:
                                    FontWeight.normal)), // Normal for remark
                    ],
                  ),
                ),
                subtitle: Text(
                  '${DateFormatter.formatBE(transaction.transactionDate.toLocal(), "d MMM yyyy (HH:mm'น.')")} \n[บันทึกโดย]: $creatorName',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (transaction.receiptImage?.isNotEmpty ?? false)
                      Icon(Icons.receipt_long_outlined,
                          color: Colors.grey.shade500, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '$amountPrefix฿${NumberFormat("#,##0").format(transaction.amount)}',
                      style: TextStyle(
                        color: amountColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
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
