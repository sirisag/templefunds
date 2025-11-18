import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:templefunds/core/utils/date_formatter.dart';
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
import 'package:templefunds/features/transactions/providers/transactions_provider.dart';
import 'package:templefunds/features/home/widgets/admin_control_panel.dart';
import 'package:templefunds/features/transactions/screens/add_multi_transaction_screen.dart';
import 'package:templefunds/features/transactions/screens/temple_transactions_screen.dart';
import 'package:templefunds/features/transactions/screens/members_transactions_screen.dart';
import 'package:templefunds/features/settings/screens/settings_screen.dart';

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
    final message = success ? 'ส่งออกข้อมูลสำเร็จ' : 'ส่งออกข้อมูลไม่สำเร็จ';
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
                  color:
                      const Color.fromARGB(255, 20, 20, 20).withOpacity(0.9)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'ตั้งค่า',
            onPressed: () {
              Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'ออกจากระบบ',
            onPressed: () => showLogoutConfirmationDialog(context, ref),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
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
            AdminControlPanel(
                onExport: () => _showDbExportDialog(context, ref)),
          ],
        ),
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
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
              child: Icon(isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                  color: amountColor, size: 20),
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
                  TextSpan(
                      text:
                          ' ${DateFormatter.formatBE(transaction.transactionDate.toLocal(), "d MMM yyyy (HH:mm'น.')")}'),
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
}
