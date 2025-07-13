import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:intl/intl.dart';
import 'package:templefunds/core/models/account_model.dart';
import 'package:templefunds/core/models/transaction_model.dart';
import 'package:templefunds/core/models/user_model.dart';
import 'package:templefunds/core/widgets/app_dialogs.dart';
import 'package:templefunds/core/widgets/navigation_tile.dart';
import 'package:templefunds/features/auth/providers/auth_provider.dart';
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
        title: const Text('สำรองข้อมูล (.db)'),
        content: const Text(
            'คุณต้องการส่งออกไฟล์ฐานข้อมูล (.db) ปัจจุบันหรือไม่? แนะนำให้ทำเป็นประจำ'),
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
      try {
        await ref.read(authProvider.notifier).exportDatabaseFile();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString()),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final lastExportDate = authState.lastDbExport;
    final balanceSummaryAsync = ref.watch(balanceSummaryProvider);
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
              loading: () => const Text('กำลังโหลด...', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              error: (e, s) => const Text('หน้าหลัก', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Text(
              'ไวยาวัจกรณ์: ${user?.name ?? ''} (ID: ${user?.userId1 ?? ''})',
              style: TextStyle(fontSize: 14, color: const Color.fromARGB(255, 20, 20, 20).withOpacity(0.9)),
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
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('เมนูหลัก',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                NavigationTile(
                  icon: Icons.account_balance_outlined,
                  title: 'รายการบัญชีวัด',
                  subtitle: 'ดูธุรกรรมทั้งหมดของกองกลางวัด',
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const TempleTransactionsScreen()));
                  },
                ),
                const SizedBox(height:5),
                NavigationTile(
                  icon: Icons.wallet_outlined,
                  title: 'รายการบัญชีพระ',
                  subtitle: 'ดูธุรกรรมทั้งหมดของสมาชิก',
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const MembersTransactionsScreen()));
                  },
                ),
              ],
            ),
          ),
          // This SizedBox creates a buffer at the bottom of the screen.
          // It prevents the fixed menu items above from being obscured by the
          // floating action buttons on devices with shorter screens.
          const SizedBox(height: 140),
        ],
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Balance Summary on the left
          Padding(
            padding: const EdgeInsets.only(left: 32.0), // Adjust for FAB margin
            child: balanceSummaryAsync.when(
              loading: () => const SizedBox(
                width: 120,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2.0)),
              ),
              error: (err, stack) =>
                  const Icon(Icons.error_outline, color: Colors.red, size: 32),
              data: (summary) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBalanceDisplay(
                    context,
                    label: 'ยอดเงินวัด',
                    amount: summary.templeBalance,
                    color: Colors.blue.shade800,
                  ),
                  const SizedBox(height: 8),
                  _buildBalanceDisplay(
                    context,
                    label: 'ยอดรวมพระ',
                    amount: summary.membersBalance,
                    color: Colors.purple.shade800,
                  ),
                  const SizedBox(height: 16), // Space below balances
                ],
              ),
            ),
          ),

          // Action Buttons on the right
          Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (lastExportDate != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Text(
                        'สำรองล่าสุด:\n${DateFormat('(HH:mm) dd/MM/yy', 'th').format(lastExportDate.toLocal())}',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),

                  SpeedDial(
                    icon: Icons.ios_share,
                    activeIcon: Icons.close,
                    tooltip: 'สำรอง / ส่งออกข้อมูล',
                    heroTag: 'export_fab',
                    buttonSize: const Size(56.0, 56.0),
                    childrenButtonSize: const Size(60.0, 60.0),
                    children: [
                      SpeedDialChild(
                        child: const Icon(Icons.picture_as_pdf_outlined),
                        label: 'ส่งออกเป็น PDF',
                        onTap: () {
                          // TODO: Implement PDF export screen navigation
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('ฟังก์ชันพิมพ์รายงานจะถูกเพิ่มในอนาคต')),
                          );
                        },
                      ), 
                      SpeedDialChild(
                        child: const Icon(Icons.storage_outlined),
                        label: 'สำรองข้อมูล (.db)',
                        onTap: () => _showDbExportDialog(context, ref),
                      ),
                    ],
                  ),
                    Padding(
                    padding: const EdgeInsets.only(left: 15.0),
                    child: FloatingActionButton(
                      heroTag: 'manage_members_fab',
                      tooltip: 'จัดการสมาชิก', // Fixed tooltip
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const MemberManagementScreen(),
                          ),
                        );
                      },
                      child: const Icon(Icons.groups_2_outlined),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FloatingActionButton.extended(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AddMultiTransactionScreen(),
                    ),
                  );
                },
                label: const Text('ทำรายการบัญชี'),
                icon: const Icon(Icons.add_card_outlined),
                heroTag: 'add_transaction_fab',
              ),
            ],
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
                        text: userMap[account.ownerUserId]?.name ?? account.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      TextSpan(text: ':${userMap[account.ownerUserId]?.userId2 ?? ''}'),
                    ] else
                      // Temple account
                      TextSpan(
                        text: account.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      )
                  else
                    const TextSpan(text: 'ไม่พบบัญชี'),
                  TextSpan(
                      text:
                          ' ${DateFormat('(HH:mm) dd/MM/yy', 'th').format(transaction.transactionDate.toLocal())}'),
                ],
              ),
            ),
            trailing: Text(
                '$amountPrefix฿${NumberFormat("#,##0", "th_TH").format(transaction.amount)}',
                style: TextStyle(
                    color: amountColor, fontWeight: FontWeight.bold)),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        Text(
          '฿${formatter.format(amount)}',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
