import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:templefunds/core/models/account_model.dart';
import 'package:templefunds/core/models/transaction_model.dart';
import 'package:templefunds/core/models/user_model.dart';
import 'package:templefunds/core/widgets/app_dialogs.dart';
import 'package:templefunds/core/widgets/navigation_tile.dart';
import 'package:templefunds/features/auth/providers/auth_provider.dart';
import 'package:templefunds/core/services/db_export_service.dart';
import 'package:templefunds/features/members/screens/member_management_screen.dart';
import 'package:templefunds/features/members/providers/members_provider.dart';
import 'package:templefunds/features/settings/providers/settings_provider.dart';
import 'package:templefunds/features/transactions/providers/accounts_provider.dart';
import 'package:templefunds/features/transactions/providers/balance_provider.dart';
import 'package:templefunds/features/transactions/providers/transactions_provider.dart';
import 'package:templefunds/features/transactions/screens/add_multi_transaction_screen.dart';
import 'package:templefunds/features/transactions/screens/temple_transactions_screen.dart';
import 'package:templefunds/features/transactions/screens/members_transactions_screen.dart';

class AdminHomeScreen extends ConsumerWidget {
  const AdminHomeScreen({super.key});

  // Helper method to show an export confirmation dialog
  Future<void> _showDbExportDialog(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('สำรองข้อมูล'),
        content: const Text(
            'คุณต้องการส่งออกไฟล์ฐานข้อมูลปัจจุบันหรือไม่? แนะนำให้ทำเป็นประจำ'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('ส่งออกไฟล์'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Show a "processing" snackbar immediately
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กำลังประมวลผลเพื่อส่งออกไฟล์...'),
          duration: Duration(seconds: 3),
        ),
      );
      try {
        // Await the export process
        final success =
            await ref.read(dbExportServiceProvider).exportDatabaseFile();
        // Show result snackbar
        _showExportResultSnackBar(context, success);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('เกิดข้อผิดพลาด: ${e.toString()}'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  void _showExportResultSnackBar(BuildContext context, bool success) {
    if (!context.mounted) return;
    final message =
        success ? 'ส่งออกข้อมูลสำเร็จ' : 'ส่งออกข้อมูลไม่สำเร็จ';
    final backgroundColor =
        success ? Colors.green : Theme.of(context).colorScheme.error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: backgroundColor),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final transactionsAsync = ref.watch(transactionsProvider);
    final accountsAsync = ref.watch(allAccountsProvider);
    final membersAsync = ref.watch(membersProvider);
    final templeNameAsync = ref.watch(templeNameProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            templeNameAsync.when(
              data: (name) => Text(
                name ?? 'หน้าหลัก',
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              loading: () => const Text('กำลังโหลด...',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              error: (e, s) => const Text('หน้าหลัก',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Text(
              'ไวยาวัจกรณ์: ${user?.name ?? ''} (ID: ${user?.userId1 ?? ''})',
              style: TextStyle(
                  fontSize: 14,
                  color: const Color.fromARGB(255, 20, 20, 20)
                      .withOpacity(0.9)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'ออกจากระบบ',
            onPressed: () => showLogoutConfirmationDialog(context, ref),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('ธุรกรรมล่าสุด',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: _buildRecentTransactionsList(
                context, transactionsAsync, accountsAsync, membersAsync),
          ),
          _buildMainMenu(context),
          _buildControlPanel(context, ref),
        ],
      ),
    );
  }

  Widget _buildMainMenu(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('เมนูหลัก',
              style:
                  TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          NavigationTile(
            icon: Icons.account_balance_outlined,
            title: 'รายการบัญชีวัด',
            subtitle: 'ดูธุรกรรมทั้งหมดของกองกลางวัด',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const TempleTransactionsScreen())),
          ),
          const SizedBox(height: 5),
          NavigationTile(
            icon: Icons.wallet_outlined,
            title: 'รายการบัญชีพระ',
            subtitle: 'ดูธุรกรรมทั้งหมดของสมาชิก',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const MembersTransactionsScreen())),
          ),
        ],
      ),
    );
  }

  Widget _buildControlPanel(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final lastExportDate = authState.lastDbExport;
    final balanceSummaryAsync = ref.watch(balanceSummaryProvider);

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // First Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left: Temple Balance
              Expanded(
                flex: 3,
                child: balanceSummaryAsync.when(
                  loading: () => const Center(
                      child: SizedBox(
                          height: 40,
                          child: CircularProgressIndicator(strokeWidth: 2))),
                  error: (err, stack) =>
                      const Center(child: Icon(Icons.error_outline, color: Colors.red)),
                  data: (summary) => _buildBalanceDisplay(
                    context,
                    label: 'ยอดเงินวัด',
                    amount: summary.templeBalance,
                    color: Colors.blue.shade800,
                  ),
                ),
              ),
              // Center: Last Export Info
              Expanded(
                flex: 3,
                child: _buildLastExportInfo(context, lastExportDate),
              ),
              // Right: Action Buttons
              Expanded(
                flex: 5,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const MemberManagementScreen())),
                    icon: const Icon(Icons.groups_2_outlined, size: 32),
                    label: const Text('จัดการสมาชิก'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      side: BorderSide(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.5),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Second Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left: Members Balance
              Expanded(
                flex: 3,
                child: balanceSummaryAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (err, stack) => const SizedBox.shrink(),
                  data: (summary) => _buildBalanceDisplay(
                    context,
                    label: 'ยอดรวมพระ',
                    amount: summary.membersBalance,
                    color: Colors.purple.shade800,
                  ),
                ),
              ),
              // Center: Empty
              Expanded(
                flex: 3,
                child: Center(
                  child: OutlinedButton.icon(
                    onPressed: () => _showDbExportDialog(context, ref),
                    icon: const Icon(Icons.backup_outlined, size: 32),
                    label: const Text('ส่งออกไฟล์'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal:8),
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                      ),
                    ),
                  ),
                ),
              ),
              // Right: Add Transaction Button
              Expanded(
                flex: 4,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const AddMultiTransactionScreen())),
                    icon: const Icon(Icons.add_card_outlined,size: 32,),
                    label: const Text('ทำธุรกรรม'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLastExportInfo(BuildContext context, DateTime? lastExportDate) {
    if (lastExportDate == null) {
      return const Center(
        child: Text(
          'ยังไม่เคยสำรองข้อมูล',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Color.fromARGB(255, 172, 171, 171)),
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('สำรองล่าสุด:', style: Theme.of(context).textTheme.labelSmall),
          Text(
            DateFormat('dd/MM/yy HH:mm', 'th').format(lastExportDate.toLocal()),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: const Color.fromARGB(255, 129, 129, 129),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactionsList(
    BuildContext context,
    AsyncValue<List<Transaction>> transactionsAsync,
    AsyncValue<List<Account>> accountsAsync,
    AsyncValue<List<User>> membersAsync,
  ) {
    // Combine async states
    if (transactionsAsync.isLoading ||
        accountsAsync.isLoading ||
        membersAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (transactionsAsync.hasError ||
        accountsAsync.hasError ||
        membersAsync.hasError) {
      return const Center(child: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล'));
    }

    final transactions = transactionsAsync.requireValue;
    final accounts = accountsAsync.requireValue;
    final members = membersAsync.requireValue;

    if (transactions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Text('ยังไม่มีธุรกรรม'),
        ),
      );
    }

    // Create a map for easy account lookup
    final accountMap = {for (var acc in accounts) acc.id: acc};
    final userMap = {for (var member in members) member.id: member};
    final limitedTransactions = transactions.take(15).toList();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: limitedTransactions.length,
      itemBuilder: (context, index) {
        final transaction = limitedTransactions[index];
        final account = accountMap[transaction.accountId];
        final isIncome = transaction.type == 'income';
        final amountColor =
            isIncome ? Colors.green.shade700 : Colors.red.shade700;
        final amountPrefix = isIncome ? '+' : '-';

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: amountColor.withOpacity(0.1),
              child: Icon(
                  isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                  color: amountColor,
                  size: 20),
            ),
            title: Text(
              transaction.description ?? 'ไม่มีคำอธิบาย',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: RichText(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: Theme.of(context).textTheme.bodySmall,
                children: [
                  if (account != null)
                    if (account.ownerUserId != null) ...[
                      // Member account: "Name:ID2"
                      TextSpan(
                        text:
                            userMap[account.ownerUserId]?.name ?? account.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      TextSpan(
                          text:
                              ':${userMap[account.ownerUserId]?.userId2 ?? ''}'),
                    ] else
                      // Temple account
                      TextSpan(
                        text: account.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                      )
                  else
                    const TextSpan(text: 'ไม่พบบัญชี'),
                  TextSpan(text: ' ${DateFormat.yMd('th').add_Hm().format(transaction.transactionDate.toLocal())}'),
                ],
              ),
            ),
            trailing: Text(
                '฿${NumberFormat("#,##0", "th_TH").format(transaction.amount)}',
                style:
                    TextStyle(color: amountColor, fontWeight: FontWeight.bold)),
          ),
        );
      },
    );
  }

  Widget _buildBalanceDisplay(
    BuildContext context, {
    required String label,
    required double amount,
    required Color color,
  }) {
    final formatter = NumberFormat("#,##0", "th_TH");
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          Text(
            '฿${formatter.format(amount)}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
