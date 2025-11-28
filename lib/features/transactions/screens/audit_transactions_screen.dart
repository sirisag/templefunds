import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:templefunds/core/models/account_model.dart';
import 'package:templefunds/core/utils/date_formatter.dart';
import 'package:templefunds/features/members/providers/members_provider.dart';
import 'package:templefunds/features/members/widgets/user_profile_avatar.dart';
import 'package:templefunds/features/settings/widgets/temple_avatar.dart';
import 'package:templefunds/features/transactions/providers/transactions_provider.dart';

class AuditTransactionsScreen extends ConsumerStatefulWidget {
  final Account account;
  final String title;

  const AuditTransactionsScreen({
    super.key,
    required this.account,
    required this.title,
  });

  @override
  ConsumerState<AuditTransactionsScreen> createState() =>
      _AuditTransactionsScreenState();
}

class _AuditTransactionsScreenState
    extends ConsumerState<AuditTransactionsScreen> {
  late int _selectedYear;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _selectedYear = DateTime.now().year;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _previousYear() {
    setState(() {
      _selectedYear--;
    });
  }

  void _nextYear() {
    if (_isNextYearDisabled()) return;
    setState(() {
      _selectedYear++;
    });
  }

  bool _isNextYearDisabled() {
    return _selectedYear >= DateTime.now().year;
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: _buildTransactionList(),
      bottomNavigationBar: _buildBottomControls(),
    );
  }

  Widget _buildTransactionList() {
    final filter = (accountId: widget.account.id!, year: _selectedYear);
    final auditedTransactionsAsync =
        ref.watch(auditedTransactionsProvider(filter));
    final allUsersAsync = ref.watch(membersProvider);

    if (auditedTransactionsAsync.isLoading || allUsersAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (auditedTransactionsAsync.hasError) {
      return Center(
          child: Text('เกิดข้อผิดพลาด: ${auditedTransactionsAsync.error}'));
    }

    if (allUsersAsync.hasError) {
      return Center(
          child: Text('เกิดข้อผิดพลาดในการโหลดผู้ใช้: ${allUsersAsync.error}'));
    }

    final transactions = auditedTransactionsAsync.requireValue;
    final users = allUsersAsync.requireValue;
    final userMap = {for (var u in users) u.id: u};

    if (transactions.isEmpty) {
      return Center(
        child: Text(
          'ไม่พบรายการบันทึกย้อนหลังในปีนี้',
          style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
        ),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    return ListView.builder(
      controller: _scrollController,
      itemCount: transactions.length,
      itemBuilder: (ctx, index) {
        final transaction = transactions[index];
        final isIncome = transaction.type == 'income';
        final amountColor =
            isIncome ? Colors.green.shade700 : Colors.red.shade700;
        final amountPrefix = isIncome ? '+' : '-';
        final creator = userMap[transaction.createdByUserId];
        final creatorName = creator?.nickname ?? 'ไม่ระบุ';

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: ListTile(
            onTap: (transaction.receiptImage?.isNotEmpty ?? false)
                ? () => _showReceiptImage(context, transaction.receiptImage!)
                : null,
            leading: widget.account.ownerUserId != null
                ? UserProfileAvatar(
                    userId: widget.account.ownerUserId!, radius: 28)
                : const TempleAvatar(radius: 28),
            title: Text(
              transaction.description ?? 'ไม่มีคำอธิบาย',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'วันที่เกิดเหตุการณ์:\n${DateFormatter.formatBE(transaction.transactionDate.toLocal(), "d MMM yyyy (HH:mm'น.')")}',
                ),
                Text(
                  '[เวลาที่บันทึก]:\n${DateFormatter.formatBE(transaction.createdAt.toLocal(), "d MMM yyyy (HH:mm'น.')")}',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                Text('[บันทึกโดย]: $creatorName'),
              ],
            ),
            isThreeLine: true,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (transaction.receiptImage?.isNotEmpty ?? false) ...[
                  Icon(Icons.receipt_long_outlined,
                      color: Colors.grey.shade500, size: 20),
                  const SizedBox(width: 8),
                ],
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
          ),
        );
      },
    );
  }

  Widget _buildBottomControls() {
    return BottomAppBar(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _previousYear,
            tooltip: 'ปีก่อนหน้า',
          ),
          TextButton(
            onPressed: null, // No picker for now, just display
            child: Text(
              'ปี พ.ศ. ${DateFormatter.formatBE(DateTime(_selectedYear), 'yyyy')}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _isNextYearDisabled() ? null : _nextYear,
            tooltip: 'ปีถัดไป',
          ),
        ],
      ),
    );
  }
}
