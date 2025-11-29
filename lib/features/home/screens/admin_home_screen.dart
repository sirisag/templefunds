import 'package:flutter/material.dart';
import 'dart:io';
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
import 'package:templefunds/features/members/providers/members_provider.dart';
import 'package:templefunds/features/settings/providers/settings_provider.dart';
import 'package:templefunds/features/transactions/providers/accounts_provider.dart';
import 'package:templefunds/features/transactions/providers/transactions_provider.dart';
import 'package:templefunds/features/home/widgets/admin_control_panel.dart';
import 'package:templefunds/features/transactions/screens/temple_transactions_screen.dart';
import 'package:templefunds/features/settings/widgets/temple_avatar.dart';
import 'package:templefunds/features/members/widgets/user_profile_avatar.dart';
import 'package:templefunds/features/transactions/screens/members_transactions_screen.dart';
import 'package:templefunds/features/settings/screens/settings_screen.dart';

class AdminHomeScreen extends ConsumerStatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  ConsumerState<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends ConsumerState<AdminHomeScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กำลังประมวลผลเพื่อส่งออกไฟล์...'),
          duration: Duration(seconds: 3),
        ),
      );
      try {
        final success =
            await ref.read(dbExportServiceProvider).exportDatabaseFile();
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
    ref.listen<AsyncValue<List<Transaction>>>(transactionsProvider,
        (previous, next) {
      if (!next.isLoading && next.hasValue) {
        Future.delayed(const Duration(milliseconds: 50), () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });

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
              'ไวยาวัจกรณ์: ${user?.nickname ?? ''} (ID: ${user?.userId1 ?? ''})',
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
              onExport: () => _showDbExportDialog(context, ref),
            ),
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
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const MembersTransactionsScreen()));
            },
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
  ) =>
      Consumer(
        builder: (context, ref, child) {
          // Combine multiple async values into one.
          final combinedAsync = (
            transactions: ref.watch(transactionsProvider),
            accounts: ref.watch(allAccountsProvider),
            members: ref.watch(membersProvider),
          );

          return switch (combinedAsync) {
            // Loading state
            (transactions: AsyncLoading(), accounts: _, members: _) ||
            (transactions: _, accounts: AsyncLoading(), members: _) ||
            (transactions: _, accounts: _, members: AsyncLoading()) =>
              const Center(child: CircularProgressIndicator()),

            // Error state
            (transactions: AsyncError(:final error), accounts: _, members: _) ||
            (transactions: _, accounts: AsyncError(:final error), members: _) ||
            (transactions: _, accounts: _, members: AsyncError(:final error)) =>
              Center(child: Text('เกิดข้อผิดพลาด: $error')),

            // Data state
            (
              transactions: AsyncData(value: final transactions),
              accounts: AsyncData(value: final accounts),
              members: AsyncData(value: final members)
            ) =>
              _buildTransactionListView(
                  context, transactions, accounts, members),

            // Default case (should not happen)
            _ => const Center(child: Text('สถานะไม่ถูกต้อง')),
          };
        },
      );

  Widget _buildTransactionListView(
    BuildContext context,
    List<Transaction> transactions,
    List<Account> accounts,
    List<User> members,
  ) {
    if (transactions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Text('ยังไม่มีธุรกรรม'),
        ),
      );
    }

    final accountMap = {for (var acc in accounts) acc.id: acc};
    final userMap = {for (var member in members) member.id: member};

    // Sort transactions by 'createdAt' in ascending order (oldest first)
    transactions.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    // Take the last 15 transactions (the newest ones)
    final limitedTransactions = transactions.length > 15
        ? transactions.sublist(transactions.length - 15)
        : transactions;

    return ListView.builder(
      controller: _scrollController, // Ensure controller is passed here
      itemCount: limitedTransactions.length,
      itemBuilder: (context, index) {
        final transaction = limitedTransactions[index];
        final account = accountMap[transaction.accountId];
        final isIncome = transaction.type == 'income';
        final amountColor =
            isIncome ? Colors.green.shade700 : Colors.red.shade700;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: ListTile(
            onTap: (transaction.receiptImage?.isNotEmpty ?? false)
                ? () => _showReceiptImage(context, transaction.receiptImage!)
                : null,
            leading: account?.ownerUserId != null
                ? UserProfileAvatar(userId: account!.ownerUserId!, radius: 28)
                : const TempleAvatar(radius: 28),
            title: RichText(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
                children: [
                  TextSpan(text: transaction.description ?? 'ไม่มีคำอธิบาย'),
                  if (transaction.remark?.isNotEmpty ?? false)
                    TextSpan(
                      text: ' (${transaction.remark})',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontWeight:
                            FontWeight.normal, // Remark should not be bold
                      ),
                    ),
                ],
              ),
            ),
            subtitle: RichText(
              maxLines: 2,
              text: TextSpan(
                style: Theme.of(context).textTheme.bodySmall,
                children: [
                  if (account?.ownerUserId != null) ...[
                    TextSpan(
                      text: userMap[account!.ownerUserId]?.nickname ??
                          account.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w500, fontSize: 14),
                    ),
                    TextSpan(text: ' (ID: '),
                    TextSpan(text: userMap[account.ownerUserId]?.userId1 ?? ''),
                    const TextSpan(text: ')'),
                  ] else if (account != null)
                    TextSpan(
                      text: account.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w500, fontSize: 14),
                    )
                  else
                    const TextSpan(text: 'ไม่พบบัญชี'),
                  TextSpan(
                    text:
                        '\n${DateFormatter.formatBE(transaction.transactionDate.toLocal(), "d MMM yyyy (HH:mm'น.')")}',
                  ),
                ],
              ),
            ),
            isThreeLine:
                true, // Allows subtitle to have more than one line and adjusts spacing
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (transaction.receiptImage?.isNotEmpty ?? false) ...[
                  Icon(Icons.receipt_long_outlined,
                      color: Colors.grey.shade500, size: 20),
                  const SizedBox(width: 8),
                ],
                Text(
                    '฿${NumberFormat("#,##0", "th_TH").format(transaction.amount)}',
                    style: TextStyle(
                        color: amountColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 20)),
              ],
            ),
          ),
        );
      },
    );
  }
}
